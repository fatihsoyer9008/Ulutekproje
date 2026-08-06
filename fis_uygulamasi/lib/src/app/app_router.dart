import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/notification_navigation_controller.dart';
import '../../features/ai_assistant/domain/ai_assistant_message_stream.dart';
import '../../features/categories/presentation/category_management_page.dart';
import '../../features/auth/presentation/controllers/auth_session_controller.dart';
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
import 'finance_home.dart';

GoRouter createAppRouter({
  required WidgetRef ref,
  required Stream<List<TransactionEntity>> Function() transactionStreamFactory,
  required Future<void> Function(TransactionEntity transaction)?
  saveTransaction,
  required ReceiptScanLauncher? scanReceipt,
  TransactionJsonImportService? transactionImportService,
  AiAssistantMessageStream? aiAssistantMessageStream,
}) {
  return GoRouter(
    initialLocation: '/startup',
    redirect: (context, state) {
      final auth = ref.read(authSessionControllerProvider);
      final location = state.matchedLocation;
      final isAuthPage = {
        '/welcome',
        '/login',
        '/register',
        '/forgot-password',
        '/verify-email',
      }.contains(location);
      final isProtectedPage = {
        '/home',
        '/profile',
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
        return '/welcome';
      }
      if (auth.status == AuthStatus.authenticated &&
          (isAuthPage || location == '/startup')) {
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
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) =>
            EmailVerificationPage(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final parser = ReceiptParserClient(
            apiClient: ref.read(apiClientProvider),
          );
          return _FinanceDataHost(
            transactionStreamFactory: transactionStreamFactory,
            saveTransaction: saveTransaction,
            scanReceipt: scanReceipt,
            parseReceipt: parser.parse,
            parseReceiptImage: parser.parseImage,

            aiAssistantMessageStream: aiAssistantMessageStream,
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
        builder: (_, _) =>
            ProfilePage(transactionImportService: transactionImportService),
      ),
      GoRoute(
        path: '/categories',
        builder: (_, _) => const CategoryManagementPage(),
      ),
    ],
  );
}

class _FinanceDataHost extends ConsumerStatefulWidget {
  const _FinanceDataHost({
    required this.transactionStreamFactory,
    required this.saveTransaction,
    required this.scanReceipt,
    required this.parseReceipt,

    required this.parseReceiptImage,

    this.aiAssistantMessageStream,
  });

  final Stream<List<TransactionEntity>> Function() transactionStreamFactory;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;
  final ReceiptParseHandler parseReceipt;

  final ReceiptImageParseHandler parseReceiptImage;

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
    final pendingTaskCount =
        ref.watch(pendingOfflineTasksProvider).asData?.value.length ?? 0;
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
          pendingOfflineTaskCount: pendingTaskCount,
          enableAccountMenu: true,
          aiAssistantMessageStream: widget.aiAssistantMessageStream,
        );
      },
    );
  }
}
