import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/notification_navigation_controller.dart';
import '../../features/ai_assistant/data/ai_assistant_client.dart';
import '../../features/ai_assistant/domain/ai_assistant_message_stream.dart';
import '../../features/ai_assistant/presentation/assistant_access_gate.dart';
import '../../features/sync/application/sync_coordinator.dart';
import '../../features/categories/presentation/category_management_page.dart';
import '../../features/auth/presentation/controllers/auth_session_controller.dart';
import '../../features/auth/presentation/routing/auth_redirect.dart';
import '../../features/auth/presentation/views/forgot_password_page.dart';
import '../../features/auth/presentation/views/email_verification_page.dart';
import '../../features/auth/presentation/views/login_page.dart';
import '../../features/auth/presentation/views/profile_page.dart';
import '../../features/auth/presentation/views/register_page.dart';
import '../../features/auth/presentation/views/startup_page.dart';
import '../../features/auth/presentation/views/welcome_page.dart';
import '../../features/backup/data/transaction_json_import_service.dart';
import '../../core/database/database_providers.dart';
import '../../features/transaction_draft/data/receipt_parser_client.dart';
import '../screens/expense_screen.dart';
import '../../features/groups/application/group_expense_flow_controller.dart';
import '../../features/groups/data/group_providers.dart';
import '../../features/groups/domain/group_expense_draft.dart';
import '../../features/groups/domain/group_models.dart';
import '../../features/groups/presentation/fast_split_page.dart';
import '../../features/groups/presentation/itemized_split_page.dart';
import '../../features/groups/presentation/groups_page.dart';
import '../../features/groups/presentation/group_detail_page.dart';
import '../../features/groups/presentation/group_ocr_page.dart';
import '../../features/groups/presentation/group_expense_conflicts_page.dart';
import '../../features/pending_receipts/application/pending_receipts_controller.dart';
import '../../features/pending_receipts/presentation/pending_receipts_page.dart';

import 'finance_home.dart';

GoRouter createAppRouter({
  required WidgetRef ref,
  required bool enableDatabaseFeatures,
  required Stream<List<TransactionEntity>> Function() transactionStreamFactory,
  required Future<void> Function(TransactionEntity transaction)?
  saveTransaction,
  required ReceiptScanLauncher? scanReceipt,
  ReceiptParseHandler? parseReceipt,
  TransactionJsonImportService? transactionImportService,
  AiAssistantMessageStream? aiAssistantMessageStream,
  AiAssistantAccessClient? profileAiAssistantClient,
}) {
  return GoRouter(
    initialLocation: '/startup',
    redirect: (context, state) {
      final auth = ref.read(authSessionControllerProvider);
      final location = state.matchedLocation;
      final groupsLocation = isGroupsRoute(location);
      final isAuthPage = {
        '/welcome',
        '/login',
        '/register',
        '/forgot-password',
        '/verify-email',
      }.contains(location);
      final isProtectedPage =
          groupsLocation ||
          {
            '/home',
            '/profile',
            '/sync-conflicts',
            '/categories',
            NotificationNavigationController.expenseReceiptRoute,
          }.contains(location);

      if (auth.status == AuthStatus.initializing) {
        return location == '/startup' || location == '/verify-email'
            ? null
            : '/startup';
      }
      if (auth.status == AuthStatus.emailVerificationRequired &&
          location != '/verify-email') {
        return '/verify-email';
      }
      if (auth.status == AuthStatus.unauthenticated && isProtectedPage) {
        if (auth.sessionExpired) {
          return groupsLocation ? groupsLoginLocation(location) : '/login';
        }
        return '/welcome';
      }
      if (auth.status == AuthStatus.guest && groupsLocation) {
        return groupsLoginLocation(location);
      }
      if (auth.status == AuthStatus.authenticated &&
          (isAuthPage || location == '/startup')) {
        final redirect = safeGroupsRedirect(
          state.uri.queryParameters['redirect'],
        );
        if (redirect != null) return redirect;
        return '/home';
      }
      if (auth.status == AuthStatus.guest &&
          (location == '/welcome' || location == '/startup')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/startup', builder: (_, _) => const StartupPage()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(
        path: '/login',
        builder: (_, state) => LoginPage(
          redirectLocation: safeGroupsRedirect(
            state.uri.queryParameters['redirect'],
          ),
        ),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => EmailVerificationPage(
          token: state.uri.queryParameters['token'],
          redirectLocation: safeGroupsRedirect(
            state.uri.queryParameters['redirect'],
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final apiClient = ref.read(apiClientProvider);
          final parser = ReceiptParserClient(apiClient: apiClient);
          final assistantClient = AiAssistantClient(apiClient);
          final assistantMessageStream =
              aiAssistantMessageStream ?? assistantClient.streamAnswer;

          return _FinanceDataHost(
            enableDatabaseFeatures: enableDatabaseFeatures,
            transactionStreamFactory: transactionStreamFactory,
            saveTransaction: saveTransaction,
            scanReceipt: scanReceipt,
            parseReceipt: parser.parse,
            parseReceiptImage: parser.parseImage,
            aiAssistantClient: assistantClient,
            aiAssistantMessageStream: assistantMessageStream,
          );
        },
      ),
      GoRoute(
        path: NotificationNavigationController.expenseReceiptRoute,
        builder: (context, state) {
          final parser = ReceiptParserClient(
            apiClient: ref.read(apiClientProvider),
          );

          return ExpenseScreen(
            saveTransaction: saveTransaction,
            scanReceipt: scanReceipt,
            parseReceipt: parser.parse,
            parseReceiptImage: parser.parseImage,
            openScannerOnStart: true,
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => ProfilePage(
          transactionImportService: transactionImportService,
          aiAssistantClient:
              profileAiAssistantClient ??
              AiAssistantClient(ref.read(apiClientProvider)),
        ),
      ),
      GoRoute(
        path: '/sync-conflicts',
        builder: (_, _) => const GroupExpenseConflictsPage(),
      ),
      GoRoute(
        path: '/categories',
        builder: (_, _) => const CategoryManagementPage(),
      ),
      GoRoute(path: '/groups', builder: (_, _) => const GroupsPage()),
      GoRoute(
        path: '/groups/:groupId',
        builder: (_, state) =>
            GroupDetailPage(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: '/groups/:groupId/ocr',
        builder: (_, state) {
          final groupId = state.pathParameters['groupId']!;
          final selectedGroup = state.extra;

          return _GroupOcrRoutePage(
            groupId: groupId,
            initialGroup:
                selectedGroup is GroupDetail && selectedGroup.id == groupId
                ? selectedGroup
                : null,
            scanReceipt: scanReceipt,
            parseReceipt: parseReceipt,
          );
        },
      ),
    ],
  );
}

Future<void> _createOcrFastSplit(
  WidgetRef ref,
  GroupDetail group,
  GroupExpenseDraft draft,
  FastSplitFormValue value,
  String idempotencyKey,
) async {
  final activeUserId = ref.read(currentGroupUserIdProvider);
  if (activeUserId == null) {
    throw StateError('Grup masrafı için aktif kullanıcı oturumu gerekli.');
  }
  final controller = ref.read(groupExpenseFlowControllerProvider.notifier);
  controller.start(
    group: group,
    activeUserId: activeUserId,
    draft: _submissionDraft(
      draft,
      title: value.title,
      payerUserId: value.payerUserId,
      totalAmountInMinor: value.calculation.totalAmountInMinor,
    ),
  );
  controller.setFastSplit(
    value.calculation,
    percentageBasisPoints: value.percentageBasisPoints,
  );
  await controller.submitFastSplit(idempotencyKey: idempotencyKey);
  _requireSuccessfulGroupExpenseSubmission(ref, controller);

  _invalidateGroupExpenseData(ref, draft.groupId);
}

Future<void> _createOcrItemizedSplit(
  WidgetRef ref,
  GroupDetail group,
  GroupExpenseDraft draft,
  ItemizedSplitFormValue value,
  String idempotencyKey,
) async {
  final activeUserId = ref.read(currentGroupUserIdProvider);
  if (activeUserId == null) {
    throw StateError('Grup masrafı için aktif kullanıcı oturumu gerekli.');
  }
  final controller = ref.read(groupExpenseFlowControllerProvider.notifier);
  controller.start(
    group: group,
    activeUserId: activeUserId,
    draft: _submissionDraft(
      draft,
      title: value.title,
      payerUserId: value.payerUserId,
      totalAmountInMinor: value.calculation.receiptTotalInMinor,
    ),
  );
  controller.setItemizedSplit(
    receiptId: value.receiptId,
    calculation: value.calculation,
  );
  await controller.submitItemizedSplit(idempotencyKey: idempotencyKey);
  _requireSuccessfulGroupExpenseSubmission(ref, controller);

  _invalidateGroupExpenseData(ref, draft.groupId);
}

GroupExpenseDraft _submissionDraft(
  GroupExpenseDraft source, {
  required String title,
  required String payerUserId,
  required int totalAmountInMinor,
}) => GroupExpenseDraft(
  groupId: source.groupId,
  payerUserId: payerUserId,
  merchantName: title,
  category: source.category,
  totalAmountInMinor: totalAmountInMinor,
  expenseDate: source.expenseDate ?? DateTime.now().toUtc(),
  currency: source.currency,
  rawOcrText: source.rawOcrText,
  items: source.items,
);

void _requireSuccessfulGroupExpenseSubmission(
  WidgetRef ref,
  GroupExpenseFlowController controller,
) {
  final state = ref.read(groupExpenseFlowControllerProvider);
  if (state.status == GroupExpenseFlowStatus.error) {
    throw state.error ?? StateError('Grup masrafı kuyruğa eklenemedi.');
  }
  if (state.status != GroupExpenseFlowStatus.success) {
    throw StateError('Grup masrafı kaydı tamamlanamadı.');
  }
  controller.clear();
}

void _invalidateGroupExpenseData(WidgetRef ref, String groupId) {
  ref.invalidate(groupExpensesProvider(groupId));
  ref.invalidate(groupDebtSummaryProvider(groupId));
  ref.invalidate(groupsProvider);
}

class _GroupOcrRoutePage extends ConsumerWidget {
  const _GroupOcrRoutePage({
    required this.groupId,
    required this.initialGroup,
    required this.scanReceipt,
    this.parseReceipt,
  });

  final String groupId;
  final GroupDetail? initialGroup;
  final ReceiptScanLauncher? scanReceipt;
  final ReceiptParseHandler? parseReceipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(groupExpenseFlowControllerProvider);
    final cachedGroup = initialGroup;

    if (cachedGroup != null && cachedGroup.id == groupId) {
      return _buildOcrPage(ref, cachedGroup);
    }

    final groupState = ref.watch(groupDetailProvider(groupId));

    return groupState.when(
      data: (group) => _buildOcrPage(ref, group),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Grup Fişi Tara')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Grup Fişi Tara')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Grup bilgisi yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(groupDetailProvider(groupId));
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOcrPage(WidgetRef ref, GroupDetail group) {
    final parser = ReceiptParserClient(apiClient: ref.read(apiClientProvider));

    return GroupOcrPage(
      group: group,
      scanReceipt: scanReceipt,
      parseReceipt: parseReceipt ?? parser.parse,
      onFastSplitSubmit: (draft, value, idempotencyKey) =>
          _createOcrFastSplit(ref, group, draft, value, idempotencyKey),
      onItemizedSplitSubmit: (draft, value, idempotencyKey) =>
          _createOcrItemizedSplit(ref, group, draft, value, idempotencyKey),
    );
  }
}

class _FinanceDataHost extends ConsumerStatefulWidget {
  const _FinanceDataHost({
    required this.enableDatabaseFeatures,
    required this.transactionStreamFactory,
    required this.saveTransaction,
    required this.scanReceipt,
    required this.parseReceipt,

    required this.parseReceiptImage,

    required this.aiAssistantClient,
    this.aiAssistantMessageStream,
  });

  final bool enableDatabaseFeatures;
  final Stream<List<TransactionEntity>> Function() transactionStreamFactory;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;
  final ReceiptParseHandler parseReceipt;

  final ReceiptImageParseHandler parseReceiptImage;

  final AiAssistantClient aiAssistantClient;
  final AiAssistantMessageStream? aiAssistantMessageStream;

  @override
  ConsumerState<_FinanceDataHost> createState() => _FinanceDataHostState();
}

class _FinanceDataHostState extends ConsumerState<_FinanceDataHost> {
  late final Stream<List<TransactionEntity>> _transactionStream;

  @override
  void initState() {
    super.initState();
    _transactionStream = widget.transactionStreamFactory();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authSessionControllerProvider);
    final queueSummary = widget.enableDatabaseFeatures
        ? ref.watch(offlineQueueSummaryProvider).asData?.value
        : const OfflineQueueSummary();
    final pendingTaskCount = queueSummary?.pendingCount ?? 0;
    final pendingReceiptCount = widget.enableDatabaseFeatures
        ? ref.watch(pendingReceiptCountProvider)
        : 0;
    final displayName = auth.user?.displayName?.trim();
    final email = auth.user?.email.trim();
    final greetingName = displayName != null && displayName.isNotEmpty
        ? displayName.split(RegExp(r'\s+')).first
        : (email != null && email.isNotEmpty
              ? email.split('@').first
              : 'Misafir');
    return StreamBuilder<List<TransactionEntity>>(
      stream: _transactionStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('İşlemler yüklenemedi.')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return FinanceHome(
          transactions: snapshot.requireData,
          greetingName: greetingName,
          saveTransaction: widget.saveTransaction,
          scanReceipt: widget.scanReceipt,
          parseReceipt: widget.parseReceipt,
          parseReceiptImage: widget.parseReceiptImage,
          onProfilePressed: () => context.push('/profile'),
          onGroupsPressed: () => context.push('/groups'),
          onGuestGroupsPressed: () => context.go(groupsLoginLocation()),
          pendingOfflineTaskCount: pendingTaskCount,
          pendingReceiptCount: pendingReceiptCount,
          onPendingReceiptsPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PendingReceiptsPage(saveTransaction: widget.saveTransaction),
            ),
          ),
          enableAccountMenu: true,
          enablePersistentSavings: widget.enableDatabaseFeatures,
          aiAssistantMessageStream: widget.aiAssistantMessageStream,
          aiAssistantAccessGate: AiAssistantAccessGate(
            client: widget.aiAssistantClient,
            authStatus: auth.status,
            queueSummary: queueSummary,
            syncPendingTasks: widget.enableDatabaseFeatures
                ? ref.read(syncCoordinatorProvider.notifier).syncPendingTasks
                : () async {},
            retryFailedAndConflicted: widget.enableDatabaseFeatures
                ? ref
                      .read(syncCoordinatorProvider.notifier)
                      .retryFailedAndConflicted
                : () async {},
            readQueueSummary: widget.enableDatabaseFeatures
                ? () =>
                      ref.read(offlineTaskRepositoryProvider).getQueueSummary()
                : () async => const OfflineQueueSummary(),
            countClaimableTransactions: widget.enableDatabaseFeatures
                ? ref.read(localTransactionClaimServiceProvider).countClaimable
                : () async => 0,
            claimLocalTransactions: widget.enableDatabaseFeatures
                ? () => ref
                      .read(localTransactionClaimServiceProvider)
                      .claimForUser(auth.user!.id)
                : () async => 0,
          ),
        );
      },
    );
  }
}
