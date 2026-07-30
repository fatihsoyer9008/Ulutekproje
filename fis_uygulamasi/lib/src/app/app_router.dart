import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_session_controller.dart';
import '../../features/auth/presentation/views/forgot_password_page.dart';
import '../../features/auth/presentation/views/email_verification_page.dart';
import '../../features/auth/presentation/views/login_page.dart';
import '../../features/auth/presentation/views/profile_page.dart';
import '../../features/auth/presentation/views/register_page.dart';
import '../../features/auth/presentation/views/startup_page.dart';
import '../../features/auth/presentation/views/welcome_page.dart';
import '../../features/transaction_draft/data/receipt_parser_client.dart';
import '../screens/expense_screen.dart';
import 'finance_app.dart';

GoRouter createAppRouter({
  required WidgetRef ref,
  required Stream<List<TransactionEntity>> transactionStream,
  required Future<void> Function(TransactionEntity transaction)?
  saveTransaction,
  required ReceiptScanLauncher? scanReceipt,
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

      if (auth.status == AuthStatus.initializing) {
        return location == '/startup' || location == '/verify-email'
            ? null
            : '/startup';
      }
      if (auth.status == AuthStatus.emailVerificationRequired &&
          location != '/verify-email') {
        return '/verify-email';
      }
      if (auth.status == AuthStatus.unauthenticated &&
          (location == '/home' || location == '/profile')) {
        return '/welcome';
      }
      if ((auth.status == AuthStatus.authenticated ||
              auth.status == AuthStatus.guest) &&
          (isAuthPage || location == '/startup')) {
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
        builder: (_, state) => EmailVerificationPage(
          token: state.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final parser = ReceiptParserClient(
            apiClient: ref.read(apiClientProvider),
          );
          return _FinanceDataHost(
            transactionStream: transactionStream,
            saveTransaction: saveTransaction,
            scanReceipt: scanReceipt,
            parseReceipt: parser.parse,
          );
        },
      ),
      GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
    ],
  );
}

class _FinanceDataHost extends StatelessWidget {
  const _FinanceDataHost({
    required this.transactionStream,
    required this.saveTransaction,
    required this.scanReceipt,
    required this.parseReceipt,
  });

  final Stream<List<TransactionEntity>> transactionStream;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;
  final ReceiptParseHandler parseReceipt;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<TransactionEntity>>(
    stream: transactionStream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Scaffold(
          body: Center(child: Text('İşlemler yüklenemedi.')),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return FinanceHome(
        transactions: snapshot.requireData,
        saveTransaction: saveTransaction,
        scanReceipt: scanReceipt,
        parseReceipt: parseReceipt,
        onProfilePressed: () => context.push('/profile'),
      );
    },
  );
}
