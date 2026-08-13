import '../domain/group_models.dart';

const demoSecondUserId = '00000000-0000-4000-8000-000000000002';
const demoFeyzaUserId = '00000000-0000-4000-8000-000000000006';
const demoMineUserId = '00000000-0000-4000-8000-000000000007';
const demoElifnurUserId = '00000000-0000-4000-8000-000000000005';

const demoHomeGroupId = '10000000-0000-4000-8000-000000000001';
const demoTeamGroupId = '10000000-0000-4000-8000-000000000004';

class DemoGroupSeed {
  const DemoGroupSeed({
    required this.groups,
    required this.expensesByGroup,
    required this.debtSummariesByGroup,
  });

  final List<GroupDetail> groups;
  final Map<String, List<GroupExpense>> expensesByGroup;
  final Map<String, DebtSummary> debtSummariesByGroup;
}

/// Runtime mock data used until the group endpoints are wired to the app.
///
/// Test fixtures intentionally stay under `test/`; the application uses this
/// separate seed so a development build can exercise the group screens.
DemoGroupSeed createDemoGroupSeed({
  required String currentUserId,
  required String currentUserDisplayName,
}) {
  final homeGroup = GroupDetail(
    id: demoHomeGroupId,
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
        groupId: demoHomeGroupId,
        userId: currentUserId,
        displayName: currentUserDisplayName,
        role: GroupRole.owner,
        joinedAt: '2026-08-10T10:00:00Z',
        leftAt: null,
      ),
      const GroupMember(
        groupId: demoHomeGroupId,
        userId: demoSecondUserId,
        displayName: 'Abdullah Seydi',
        role: GroupRole.member,
        joinedAt: '2026-08-10T10:05:00Z',
        leftAt: null,
      ),
    ],
  );

  final teamGroup = GroupDetail(
    id: demoTeamGroupId,
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
        groupId: demoTeamGroupId,
        userId: currentUserId,
        displayName: currentUserDisplayName,
        role: GroupRole.owner,
        joinedAt: '2026-08-10T11:00:00Z',
        leftAt: null,
      ),
      const GroupMember(
        groupId: demoTeamGroupId,
        userId: demoFeyzaUserId,
        displayName: 'Feyza',
        role: GroupRole.admin,
        joinedAt: '2026-08-10T11:05:00Z',
        leftAt: null,
      ),
      const GroupMember(
        groupId: demoTeamGroupId,
        userId: demoMineUserId,
        displayName: 'Mine',
        role: GroupRole.member,
        joinedAt: '2026-08-10T11:10:00Z',
        leftAt: null,
      ),
      const GroupMember(
        groupId: demoTeamGroupId,
        userId: demoElifnurUserId,
        displayName: 'Elifnur',
        role: GroupRole.member,
        joinedAt: '2026-08-10T11:15:00Z',
        leftAt: null,
      ),
    ],
  );

  final expense = GroupExpense(
    id: '40000000-0000-4000-8000-000000000001',
    groupId: demoHomeGroupId,
    receiptId: null,
    payerUserId: currentUserId,
    createdBy: currentUserId,
    title: 'Aylık market alışverişi',
    note: 'Geliştirme ortamı örnek masrafı',
    expenseDate: '2026-08-10T12:00:00Z',
    totalAmountInMinor: 12500,
    currency: 'TRY',
    splitType: SplitType.equal,
    isFinanciallyLocked: false,
    shares: <ExpenseShare>[
      ExpenseShare(
        expenseId: '40000000-0000-4000-8000-000000000001',
        userId: currentUserId,
        displayName: currentUserDisplayName,
        amountInMinor: 6250,
        status: ShareStatus.open,
        settledAt: null,
      ),
      const ExpenseShare(
        expenseId: '40000000-0000-4000-8000-000000000001',
        userId: demoSecondUserId,
        displayName: 'Abdullah Seydi',
        amountInMinor: 6250,
        status: ShareStatus.open,
        settledAt: null,
      ),
    ],
    lineItemAssignments: const <ReceiptLineItemAssignment>[],
    extraAmounts: const <ExpenseExtraAmount>[],
    createdAt: '2026-08-10T12:01:00Z',
    updatedAt: '2026-08-10T12:01:00Z',
    deletedAt: null,
  );

  final debtSummary = DebtSummary(
    groupId: demoHomeGroupId,
    currency: 'TRY',
    balances: <DebtBalance>[
      DebtBalance(
        userId: currentUserId,
        displayName: currentUserDisplayName,
        netAmountInMinor: -6250,
      ),
      const DebtBalance(
        userId: demoSecondUserId,
        displayName: 'Abdullah Seydi',
        netAmountInMinor: 6250,
      ),
    ],
    suggestedTransfers: <DebtTransfer>[
      DebtTransfer(
        fromUserId: currentUserId,
        toUserId: demoSecondUserId,
        amountInMinor: 6250,
      ),
    ],
    generatedAt: '2026-08-11T09:05:00Z',
  );

  return DemoGroupSeed(
    groups: <GroupDetail>[homeGroup, teamGroup],
    expensesByGroup: <String, List<GroupExpense>>{
      demoHomeGroupId: <GroupExpense>[expense],
    },
    debtSummariesByGroup: <String, DebtSummary>{demoHomeGroupId: debtSummary},
  );
}
