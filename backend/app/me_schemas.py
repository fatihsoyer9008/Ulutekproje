from pydantic import BaseModel

from app.domain.debts import OverallBalance


class OverallBalanceEntry(BaseModel):
    currency: str
    net_amount_in_minor: int
    status: str

    @classmethod
    def from_domain(cls, balance: OverallBalance) -> "OverallBalanceEntry":
        if balance.net_amount_in_minor > 0:
            status = "you_are_owed"
        elif balance.net_amount_in_minor < 0:
            status = "you_owe"
        else:
            status = "settled_up"
        return cls(
            currency=balance.currency,
            net_amount_in_minor=balance.net_amount_in_minor,
            status=status,
        )


class BalanceSummaryResponse(BaseModel):
    overall_balances: list[OverallBalanceEntry]

    @classmethod
    def from_domain(
        cls,
        balances: tuple[OverallBalance, ...],
    ) -> "BalanceSummaryResponse":
        return cls(
            overall_balances=[
                OverallBalanceEntry.from_domain(balance) for balance in balances
            ]
        )
