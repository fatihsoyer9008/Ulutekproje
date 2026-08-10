import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const currentUserId = '00000000-0000-4000-8000-000000000001';
const secondUserId = '00000000-0000-4000-8000-000000000002';
const thirdUserId = '00000000-0000-4000-8000-000000000003';
const fourthUserId = '00000000-0000-4000-8000-000000000004';

const twoMemberGroupId = '10000000-0000-4000-8000-000000000001';
const fourMemberGroupId = '10000000-0000-4000-8000-000000000002';

const emptyGroupsResponse = GroupsResponse(groups: <Group>[]);

const twoMemberGroup = GroupDetail(
  id: twoMemberGroupId,
  name: 'Ev Arkadaşları',
  description: 'Ortak ev masrafları',
  currency: 'TRY',
  memberCount: 2,
  currentUserRole: GroupRole.owner,
  createdBy: currentUserId,
  createdAt: '2026-08-10T10:00:00Z',
  updatedAt: '2026-08-10T10:05:00Z',
  archivedAt: null,
  members: <GroupMember>[
    GroupMember(
      groupId: twoMemberGroupId,
      userId: currentUserId,
      displayName: 'Zafer Tuna',
      role: GroupRole.owner,
      joinedAt: '2026-08-10T10:00:00Z',
      leftAt: null,
    ),
    GroupMember(
      groupId: twoMemberGroupId,
      userId: secondUserId,
      displayName: 'Abdullah Seydi',
      role: GroupRole.member,
      joinedAt: '2026-08-10T10:05:00Z',
      leftAt: null,
    ),
  ],
);

const fourMemberGroup = GroupDetail(
  id: fourMemberGroupId,
  name: 'Ulutek Ekibi',
  description: 'Ekip içi ortak harcamalar',
  currency: 'TRY',
  memberCount: 4,
  currentUserRole: GroupRole.owner,
  createdBy: currentUserId,
  createdAt: '2026-08-10T11:00:00Z',
  updatedAt: '2026-08-10T11:15:00Z',
  archivedAt: null,
  members: <GroupMember>[
    GroupMember(
      groupId: fourMemberGroupId,
      userId: currentUserId,
      displayName: 'Zafer Tuna',
      role: GroupRole.owner,
      joinedAt: '2026-08-10T11:00:00Z',
      leftAt: null,
    ),
    GroupMember(
      groupId: fourMemberGroupId,
      userId: thirdUserId,
      displayName: 'Feyza',
      role: GroupRole.admin,
      joinedAt: '2026-08-10T11:05:00Z',
      leftAt: null,
    ),
    GroupMember(
      groupId: fourMemberGroupId,
      userId: secondUserId,
      displayName: 'Mine',
      role: GroupRole.member,
      joinedAt: '2026-08-10T11:10:00Z',
      leftAt: null,
    ),
    GroupMember(
      groupId: fourMemberGroupId,
      userId: fourthUserId,
      displayName: 'Elifnur',
      role: GroupRole.member,
      joinedAt: '2026-08-10T11:15:00Z',
      leftAt: null,
    ),
  ],
);

const currentUserDebtorDebtSummary = DebtSummary(
  groupId: twoMemberGroupId,
  currency: 'TRY',
  balances: <DebtBalance>[
    DebtBalance(
      userId: currentUserId,
      displayName: 'Zafer Tuna',
      netAmountInMinor: -6250,
    ),
    DebtBalance(
      userId: secondUserId,
      displayName: 'Abdullah Seydi',
      netAmountInMinor: 6250,
    ),
  ],
  suggestedTransfers: <DebtTransfer>[
    DebtTransfer(
      fromUserId: currentUserId,
      toUserId: secondUserId,
      amountInMinor: 6250,
    ),
  ],
  generatedAt: '2026-08-11T09:05:00Z',
);

const currentUserCreditorDebtSummary = DebtSummary(
  groupId: twoMemberGroupId,
  currency: 'TRY',
  balances: <DebtBalance>[
    DebtBalance(
      userId: currentUserId,
      displayName: 'Zafer Tuna',
      netAmountInMinor: 6250,
    ),
    DebtBalance(
      userId: secondUserId,
      displayName: 'Abdullah Seydi',
      netAmountInMinor: -6250,
    ),
  ],
  suggestedTransfers: <DebtTransfer>[
    DebtTransfer(
      fromUserId: secondUserId,
      toUserId: currentUserId,
      amountInMinor: 6250,
    ),
  ],
  generatedAt: '2026-08-11T09:05:00Z',
);

const fastSplitTransferExpense = GroupExpense(
  id: '40000000-0000-4000-8000-000000000001',
  groupId: twoMemberGroupId,
  receiptId: null,
  payerUserId: currentUserId,
  createdBy: currentUserId,
  title: 'Aylık market alışverişi',
  note: null,
  expenseDate: '2026-08-10T12:00:00Z',
  totalAmountInMinor: 12500,
  currency: 'TRY',
  splitType: SplitType.equal,
  isFinanciallyLocked: false,
  shares: <ExpenseShare>[
    ExpenseShare(
      expenseId: '40000000-0000-4000-8000-000000000001',
      userId: currentUserId,
      displayName: 'Zafer Tuna',
      amountInMinor: 6250,
      status: ShareStatus.open,
      settledAt: null,
    ),
    ExpenseShare(
      expenseId: '40000000-0000-4000-8000-000000000001',
      userId: secondUserId,
      displayName: 'Abdullah Seydi',
      amountInMinor: 6250,
      status: ShareStatus.open,
      settledAt: null,
    ),
  ],
  lineItemAssignments: <ReceiptLineItemAssignment>[],
  createdAt: '2026-08-10T12:01:00Z',
  updatedAt: '2026-08-10T12:01:00Z',
  deletedAt: null,
);

const itemizedMarketExpense = GroupExpense(
  id: '40000000-0000-4000-8000-000000000002',
  groupId: twoMemberGroupId,
  receiptId: '20000000-0000-4000-8000-000000000001',
  payerUserId: currentUserId,
  createdBy: currentUserId,
  title: 'Market fişi',
  note: null,
  expenseDate: '2026-08-10T12:00:00Z',
  totalAmountInMinor: 12500,
  currency: 'TRY',
  splitType: SplitType.itemized,
  isFinanciallyLocked: false,
  shares: <ExpenseShare>[
    ExpenseShare(
      expenseId: '40000000-0000-4000-8000-000000000002',
      userId: currentUserId,
      displayName: 'Zafer Tuna',
      amountInMinor: 3250,
      status: ShareStatus.open,
      settledAt: null,
    ),
    ExpenseShare(
      expenseId: '40000000-0000-4000-8000-000000000002',
      userId: secondUserId,
      displayName: 'Abdullah Seydi',
      amountInMinor: 9250,
      status: ShareStatus.open,
      settledAt: null,
    ),
  ],
  lineItemAssignments: <ReceiptLineItemAssignment>[
    ReceiptLineItemAssignment(
      expenseId: '40000000-0000-4000-8000-000000000002',
      receiptLineItemId: '30000000-0000-4000-8000-000000000001',
      userId: currentUserId,
      amountInMinor: 3000,
      quantityShareMilli: 1000,
    ),
    ReceiptLineItemAssignment(
      expenseId: '40000000-0000-4000-8000-000000000002',
      receiptLineItemId: '30000000-0000-4000-8000-000000000001',
      userId: secondUserId,
      amountInMinor: 3000,
      quantityShareMilli: 1000,
    ),
    ReceiptLineItemAssignment(
      expenseId: '40000000-0000-4000-8000-000000000002',
      receiptLineItemId: '30000000-0000-4000-8000-000000000002',
      userId: secondUserId,
      amountInMinor: 6000,
      quantityShareMilli: 1000,
    ),
  ],
  createdAt: '2026-08-10T12:01:00Z',
  updatedAt: '2026-08-10T12:01:00Z',
  deletedAt: null,
);

const sampleSettlement = Settlement(
  id: '50000000-0000-4000-8000-000000000001',
  groupId: twoMemberGroupId,
  fromUserId: secondUserId,
  toUserId: currentUserId,
  amountInMinor: 2500,
  currency: 'TRY',
  settledAt: '2026-08-11T09:00:00Z',
  note: 'Havale ile ödendi',
  createdAt: '2026-08-11T09:01:00Z',
);

const groupsApiErrorException = GroupApiException(
  statusCode: 503,
  error: GroupApiError(
    detail: GroupApiErrorDetail(
      code: 'service_unavailable',
      message: 'Grup bilgileri şu anda alınamıyor.',
      fieldErrors: <GroupApiFieldError>[],
    ),
  ),
);

const groupsLoading = AsyncLoading<GroupsResponse>();

final groupsApiError = AsyncError<GroupsResponse>(
  groupsApiErrorException,
  StackTrace.empty,
);
