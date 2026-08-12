import uuid
from datetime import UTC, datetime
from decimal import Decimal

import pytest
import pytest_asyncio
from sqlalchemy import event
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models import (
    CloudReceipt,
    CloudReceiptLineItem,
    ExpenseExtraAmountType,
    ExpenseSplitType,
    User,
)
from app.repositories.group_expenses import GroupExpenseRepository
from app.repositories.groups import GroupRepository
from app.services.group_expense_service import (
    ExtraAmountInput,
    ExtraAmountShareInput,
    GroupExpenseService,
    ItemizedExpenseValidationError,
    LineItemAssignmentInput,
)


def _tax_extra(
    *shares: tuple[uuid.UUID, int],
) -> ExtraAmountInput:
    return ExtraAmountInput(
        type=ExpenseExtraAmountType.tax,
        label="KDV",
        amount_in_minor=sum(amount for _, amount in shares),
        shares=tuple(
            ExtraAmountShareInput(
                user_id=user_id,
                amount_in_minor=amount,
            )
            for user_id, amount in shares
        ),
    )


@pytest_asyncio.fixture
async def service_context():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
    )

    @event.listens_for(engine.sync_engine, "connect")
    def _enable_sqlite_foreign_keys(
        dbapi_connection,
        _connection_record,
    ) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async with session_factory() as session:
        owner = User(email="itemized-owner@example.com")
        member = User(email="itemized-member@example.com")
        outsider = User(email="itemized-outsider@example.com")
        session.add_all([owner, member, outsider])
        await session.flush()

        group_repository = GroupRepository(session)
        group = await group_repository.create(
            name="Kalem Bazlı Masraf Grubu",
            created_by=owner.id,
        )
        await group_repository.add_member(
            group_id=group.id,
            user_id=member.id,
        )

        now = datetime(2026, 8, 11, 12, 0, tzinfo=UTC)
        receipt = CloudReceipt(
            user_id=owner.id,
            client_record_id=uuid.uuid4(),
            installation_id_hash="a" * 64,
            total_amount_in_minor=12_500,
            client_created_at=now,
            client_updated_at=now,
        )
        milk = CloudReceiptLineItem(
            client_record_id=uuid.uuid4(),
            position=0,
            name="Süt",
            price_in_minor=6_000,
            quantity=Decimal("2.000"),
        )
        bread = CloudReceiptLineItem(
            client_record_id=uuid.uuid4(),
            position=1,
            name="Ekmek",
            price_in_minor=6_000,
            quantity=Decimal("1.000"),
        )
        receipt.line_items.extend([milk, bread])
        session.add(receipt)
        await session.commit()

        yield (
            session,
            GroupExpenseRepository(session),
            GroupExpenseService(session),
            group,
            owner,
            member,
            outsider,
            receipt,
            milk,
            bread,
        )

    await engine.dispose()


@pytest.mark.asyncio
async def test_service_creates_multi_member_itemized_expense(
    service_context,
) -> None:
    (
        session,
        repository,
        service,
        group,
        owner,
        member,
        _outsider,
        receipt,
        milk,
        bread,
    ) = service_context

    expense = await service.create_itemized(
        group_id=group.id,
        receipt_id=receipt.id,
        actor_user_id=owner.id,
        payer_user_id=owner.id,
        title="Market fişi",
        note=None,
        expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
        total_amount_in_minor=12_500,
        currency="try",
        assignments=[
            LineItemAssignmentInput(
                receipt_line_item_id=milk.id,
                user_id=owner.id,
                amount_in_minor=3_000,
                quantity_share_milli=1_000,
            ),
            LineItemAssignmentInput(
                receipt_line_item_id=milk.id,
                user_id=member.id,
                amount_in_minor=3_000,
                quantity_share_milli=1_000,
            ),
            LineItemAssignmentInput(
                receipt_line_item_id=bread.id,
                user_id=member.id,
                amount_in_minor=6_000,
                quantity_share_milli=1_000,
            ),
        ],
        extra_amounts=[
            _tax_extra(
                (owner.id, 250),
                (member.id, 250),
            )
        ],
    )
    await session.commit()

    stored = await repository.get_by_id(expense.id)
    assert stored is not None
    assert stored.split_type == ExpenseSplitType.itemized
    assert len(stored.line_item_assignments) == 3

    milk_assignments = [
        assignment
        for assignment in stored.line_item_assignments
        if assignment.receipt_line_item_id == milk.id
    ]
    assert len(milk_assignments) == 2
    assert sum(assignment.amount_in_minor for assignment in milk_assignments) == 6_000

    shares_by_user = {share.user_id: share.amount_in_minor for share in stored.shares}
    assert shares_by_user == {
        owner.id: 3_250,
        member.id: 9_250,
    }
    assert len(stored.extra_amounts) == 1
    stored_extra = stored.extra_amounts[0]
    assert stored_extra.type is ExpenseExtraAmountType.tax
    assert stored_extra.label == "KDV"
    assert stored_extra.amount_in_minor == 500
    assert {share.user_id: share.amount_in_minor for share in stored_extra.shares} == {
        owner.id: 250,
        member.id: 250,
    }


@pytest.mark.asyncio
async def test_service_reports_unassigned_line_items(
    service_context,
) -> None:
    (
        _session,
        _repository,
        service,
        group,
        owner,
        member,
        _outsider,
        receipt,
        milk,
        bread,
    ) = service_context

    with pytest.raises(ItemizedExpenseValidationError) as error_info:
        await service.create_itemized(
            group_id=group.id,
            receipt_id=receipt.id,
            actor_user_id=owner.id,
            payer_user_id=owner.id,
            title="Eksik market fişi",
            expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
            total_amount_in_minor=6_500,
            currency="TRY",
            assignments=[
                LineItemAssignmentInput(
                    receipt_line_item_id=milk.id,
                    user_id=owner.id,
                    amount_in_minor=3_000,
                    quantity_share_milli=1_000,
                ),
                LineItemAssignmentInput(
                    receipt_line_item_id=milk.id,
                    user_id=member.id,
                    amount_in_minor=3_000,
                    quantity_share_milli=1_000,
                ),
            ],
            extra_amounts=[
                _tax_extra(
                    (owner.id, 250),
                    (member.id, 250),
                )
            ],
        )

    assert error_info.value.code == "unassigned_line_items"
    assert error_info.value.unassigned_receipt_line_item_ids == (bread.id,)


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("extra_type", "label"),
    [
        (ExpenseExtraAmountType.tax, "KDV"),
        (ExpenseExtraAmountType.tip, "Bahşiş"),
        (ExpenseExtraAmountType.service_fee, "Servis bedeli"),
        (ExpenseExtraAmountType.other, "Ambalaj"),
    ],
)
async def test_service_persists_each_extra_amount_type(
    service_context,
    extra_type: ExpenseExtraAmountType,
    label: str,
) -> None:
    (
        session,
        _repository,
        service,
        group,
        owner,
        member,
        _outsider,
        receipt,
        milk,
        bread,
    ) = service_context

    expense = await service.create_itemized(
        group_id=group.id,
        receipt_id=receipt.id,
        actor_user_id=owner.id,
        payer_user_id=owner.id,
        title="Ek tutar türü testi",
        expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
        total_amount_in_minor=12_500,
        currency="TRY",
        assignments=[
            LineItemAssignmentInput(
                receipt_line_item_id=milk.id,
                user_id=owner.id,
                amount_in_minor=6_000,
                quantity_share_milli=2_000,
            ),
            LineItemAssignmentInput(
                receipt_line_item_id=bread.id,
                user_id=member.id,
                amount_in_minor=6_000,
                quantity_share_milli=1_000,
            ),
        ],
        extra_amounts=[
            ExtraAmountInput(
                type=extra_type,
                label=label,
                amount_in_minor=500,
                shares=(
                    ExtraAmountShareInput(
                        user_id=owner.id,
                        amount_in_minor=250,
                    ),
                    ExtraAmountShareInput(
                        user_id=member.id,
                        amount_in_minor=250,
                    ),
                ),
            )
        ],
    )
    await session.commit()

    assert expense.created_by == owner.id
    assert len(expense.extra_amounts) == 1
    assert expense.extra_amounts[0].type is extra_type
    assert expense.extra_amounts[0].label == label
    assert expense.extra_amounts[0].amount_in_minor == 500


@pytest.mark.asyncio
async def test_service_rejects_amount_above_line_item_price(
    service_context,
) -> None:
    (
        _session,
        _repository,
        service,
        group,
        owner,
        member,
        _outsider,
        receipt,
        milk,
        bread,
    ) = service_context

    with pytest.raises(ItemizedExpenseValidationError) as error_info:
        await service.create_itemized(
            group_id=group.id,
            receipt_id=receipt.id,
            actor_user_id=owner.id,
            payer_user_id=owner.id,
            title="Aşan market fişi",
            expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
            total_amount_in_minor=12_500,
            currency="TRY",
            assignments=[
                LineItemAssignmentInput(
                    receipt_line_item_id=milk.id,
                    user_id=owner.id,
                    amount_in_minor=3_500,
                    quantity_share_milli=1_000,
                ),
                LineItemAssignmentInput(
                    receipt_line_item_id=milk.id,
                    user_id=member.id,
                    amount_in_minor=3_000,
                    quantity_share_milli=1_000,
                ),
                LineItemAssignmentInput(
                    receipt_line_item_id=bread.id,
                    user_id=member.id,
                    amount_in_minor=6_000,
                    quantity_share_milli=1_000,
                ),
            ],
        )

    assert error_info.value.code == "invalid_split_total"


@pytest.mark.asyncio
async def test_service_rejects_non_member_assignment(
    service_context,
) -> None:
    (
        _session,
        _repository,
        service,
        group,
        owner,
        _member,
        outsider,
        receipt,
        milk,
        bread,
    ) = service_context

    with pytest.raises(ItemizedExpenseValidationError) as error_info:
        await service.create_itemized(
            group_id=group.id,
            receipt_id=receipt.id,
            actor_user_id=owner.id,
            payer_user_id=owner.id,
            title="Geçersiz üyeli market fişi",
            expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
            total_amount_in_minor=12_500,
            currency="TRY",
            assignments=[
                LineItemAssignmentInput(
                    receipt_line_item_id=milk.id,
                    user_id=owner.id,
                    amount_in_minor=6_000,
                    quantity_share_milli=2_000,
                ),
                LineItemAssignmentInput(
                    receipt_line_item_id=bread.id,
                    user_id=outsider.id,
                    amount_in_minor=6_000,
                    quantity_share_milli=1_000,
                ),
            ],
            extra_amounts=[_tax_extra((owner.id, 500))],
        )

    assert error_info.value.code == "member_not_found"


@pytest.mark.asyncio
async def test_service_rejects_excess_quantity_share(
    service_context,
) -> None:
    (
        _session,
        _repository,
        service,
        group,
        owner,
        member,
        _outsider,
        receipt,
        milk,
        bread,
    ) = service_context

    with pytest.raises(ItemizedExpenseValidationError) as error_info:
        await service.create_itemized(
            group_id=group.id,
            receipt_id=receipt.id,
            actor_user_id=owner.id,
            payer_user_id=owner.id,
            title="Geçersiz miktarlı market fişi",
            expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
            total_amount_in_minor=12_500,
            currency="TRY",
            assignments=[
                LineItemAssignmentInput(
                    receipt_line_item_id=milk.id,
                    user_id=owner.id,
                    amount_in_minor=6_000,
                    quantity_share_milli=2_001,
                ),
                LineItemAssignmentInput(
                    receipt_line_item_id=bread.id,
                    user_id=member.id,
                    amount_in_minor=6_000,
                    quantity_share_milli=1_000,
                ),
            ],
            extra_amounts=[
                _tax_extra((owner.id, 500)),
            ],
        )

    assert error_info.value.code == "invalid_request"


@pytest.mark.asyncio
async def test_service_rejects_actor_outside_group(
    service_context,
) -> None:
    (
        _session,
        _repository,
        service,
        group,
        owner,
        _member,
        outsider,
        receipt,
        _milk,
        _bread,
    ) = service_context

    with pytest.raises(ItemizedExpenseValidationError) as error_info:
        await service.create_itemized(
            group_id=group.id,
            receipt_id=receipt.id,
            actor_user_id=outsider.id,
            payer_user_id=owner.id,
            title="Yetkisiz masraf",
            expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
            total_amount_in_minor=12_500,
            currency="TRY",
            assignments=[],
        )

    assert error_info.value.code == "group_forbidden"


@pytest.mark.asyncio
async def test_service_hides_foreign_owned_receipt(
    service_context,
) -> None:
    (
        _session,
        _repository,
        service,
        group,
        owner,
        member,
        _outsider,
        receipt,
        _milk,
        _bread,
    ) = service_context

    with pytest.raises(ItemizedExpenseValidationError) as error_info:
        await service.create_itemized(
            group_id=group.id,
            receipt_id=receipt.id,
            actor_user_id=member.id,
            payer_user_id=owner.id,
            title="Başkasının fişi",
            expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
            total_amount_in_minor=12_500,
            currency="TRY",
            assignments=[],
        )

    assert error_info.value.code == "receipt_not_synced"


@pytest.mark.asyncio
async def test_service_rejects_soft_deleted_receipt(
    service_context,
) -> None:
    (
        session,
        _repository,
        service,
        group,
        owner,
        _member,
        _outsider,
        receipt,
        _milk,
        _bread,
    ) = service_context

    receipt.deleted_at = datetime(
        2026,
        8,
        11,
        13,
        0,
        tzinfo=UTC,
    )
    await session.commit()

    with pytest.raises(ItemizedExpenseValidationError) as error_info:
        await service.create_itemized(
            group_id=group.id,
            receipt_id=receipt.id,
            actor_user_id=owner.id,
            payer_user_id=owner.id,
            title="Silinmiş fiş",
            expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
            total_amount_in_minor=12_500,
            currency="TRY",
            assignments=[],
        )

    assert error_info.value.code == "receipt_not_synced"


@pytest.mark.asyncio
async def test_service_rejects_currency_mismatch(
    service_context,
) -> None:
    (
        _session,
        _repository,
        service,
        group,
        owner,
        _member,
        _outsider,
        receipt,
        _milk,
        _bread,
    ) = service_context

    with pytest.raises(ItemizedExpenseValidationError) as error_info:
        await service.create_itemized(
            group_id=group.id,
            receipt_id=receipt.id,
            actor_user_id=owner.id,
            payer_user_id=owner.id,
            title="Yanlış para birimi",
            expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
            total_amount_in_minor=12_500,
            currency="USD",
            assignments=[],
        )

    assert error_info.value.code == "currency_mismatch"


@pytest.mark.asyncio
async def test_service_rejects_zero_total(
    service_context,
) -> None:
    (
        _session,
        _repository,
        service,
        group,
        owner,
        _member,
        _outsider,
        receipt,
        _milk,
        _bread,
    ) = service_context

    with pytest.raises(ItemizedExpenseValidationError) as error_info:
        await service.create_itemized(
            group_id=group.id,
            receipt_id=receipt.id,
            actor_user_id=owner.id,
            payer_user_id=owner.id,
            title="Sıfır masraf",
            expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
            total_amount_in_minor=0,
            currency="TRY",
            assignments=[],
        )

    assert error_info.value.code == "invalid_request"


@pytest.mark.asyncio
async def test_service_rejects_archived_group(
    service_context,
) -> None:
    (
        session,
        _repository,
        service,
        group,
        owner,
        _member,
        _outsider,
        receipt,
        _milk,
        _bread,
    ) = service_context

    group.archived_at = datetime(
        2026,
        8,
        11,
        13,
        0,
        tzinfo=UTC,
    )
    await session.commit()

    with pytest.raises(ItemizedExpenseValidationError) as error_info:
        await service.create_itemized(
            group_id=group.id,
            receipt_id=receipt.id,
            actor_user_id=owner.id,
            payer_user_id=owner.id,
            title="Arşivlenmiş grup masrafı",
            expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
            total_amount_in_minor=12_500,
            currency="TRY",
            assignments=[],
        )

    assert error_info.value.code == "group_forbidden"


@pytest.mark.asyncio
async def test_service_rejects_reusing_assigned_line_items(
    service_context,
) -> None:
    (
        session,
        _repository,
        service,
        group,
        owner,
        member,
        _outsider,
        receipt,
        milk,
        bread,
    ) = service_context

    assignments = [
        LineItemAssignmentInput(
            receipt_line_item_id=milk.id,
            user_id=owner.id,
            amount_in_minor=3_000,
            quantity_share_milli=1_000,
        ),
        LineItemAssignmentInput(
            receipt_line_item_id=milk.id,
            user_id=member.id,
            amount_in_minor=3_000,
            quantity_share_milli=1_000,
        ),
        LineItemAssignmentInput(
            receipt_line_item_id=bread.id,
            user_id=member.id,
            amount_in_minor=6_000,
            quantity_share_milli=1_000,
        ),
    ]
    extra_amounts = [
        _tax_extra(
            (owner.id, 250),
            (member.id, 250),
        )
    ]

    await service.create_itemized(
        group_id=group.id,
        receipt_id=receipt.id,
        actor_user_id=owner.id,
        payer_user_id=owner.id,
        title="İlk market masrafı",
        expense_date=datetime(2026, 8, 11, 12, 0, tzinfo=UTC),
        total_amount_in_minor=12_500,
        currency="TRY",
        assignments=assignments,
        extra_amounts=extra_amounts,
    )
    await session.commit()

    with pytest.raises(ItemizedExpenseValidationError) as error_info:
        await service.create_itemized(
            group_id=group.id,
            receipt_id=receipt.id,
            actor_user_id=owner.id,
            payer_user_id=owner.id,
            title="Yinelenen market masrafı",
            expense_date=datetime(2026, 8, 11, 12, 5, tzinfo=UTC),
            total_amount_in_minor=12_500,
            currency="TRY",
            assignments=assignments,
            extra_amounts=extra_amounts,
        )

    assert error_info.value.code == "invalid_request"


@pytest.mark.asyncio
async def test_service_rejects_extra_amount_share_total_mismatch(
    service_context,
) -> None:
    (
        _session,
        _repository,
        service,
        group,
        owner,
        member,
        _outsider,
        receipt,
        milk,
        bread,
    ) = service_context

    with pytest.raises(ItemizedExpenseValidationError) as error_info:
        await service.create_itemized(
            group_id=group.id,
            receipt_id=receipt.id,
            actor_user_id=owner.id,
            payer_user_id=owner.id,
            title="Hatalı KDV dağılımı",
            expense_date=datetime(
                2026,
                8,
                11,
                12,
                0,
                tzinfo=UTC,
            ),
            total_amount_in_minor=12_500,
            currency="TRY",
            assignments=[
                LineItemAssignmentInput(
                    receipt_line_item_id=milk.id,
                    user_id=owner.id,
                    amount_in_minor=6_000,
                    quantity_share_milli=2_000,
                ),
                LineItemAssignmentInput(
                    receipt_line_item_id=bread.id,
                    user_id=member.id,
                    amount_in_minor=6_000,
                    quantity_share_milli=1_000,
                ),
            ],
            extra_amounts=[
                ExtraAmountInput(
                    type=ExpenseExtraAmountType.tax,
                    label="KDV",
                    amount_in_minor=500,
                    shares=(
                        ExtraAmountShareInput(
                            user_id=owner.id,
                            amount_in_minor=200,
                        ),
                        ExtraAmountShareInput(
                            user_id=member.id,
                            amount_in_minor=200,
                        ),
                    ),
                )
            ],
        )

    assert error_info.value.code == "invalid_split_total"
