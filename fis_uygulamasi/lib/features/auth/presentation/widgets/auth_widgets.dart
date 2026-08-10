import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_session_controller.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 80, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/econbuddy_logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: 'Uygulama logosu',
  );
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBackButton = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: showBackButton
        ? AppBar(
            leading: const _AuthBackButton(),
            backgroundColor: Colors.transparent,
          )
        : null,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AppLogo(size: 64),
                ),
                const SizedBox(height: 24),
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 28),
                AppCard(child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AuthBackButton extends ConsumerWidget {
  const _AuthBackButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => BackButton(
    onPressed: () {
      final routerState = GoRouterState.of(context);
      switch (routerState.matchedLocation) {
        case '/verify-email':
          ref
              .read(authSessionControllerProvider.notifier)
              .leaveEmailVerification();
          final origin = routerState.uri.queryParameters['from'];
          context.go(origin == 'register' ? '/register' : '/login');
          return;
        case '/login':
        case '/register':
          context.go('/welcome');
          return;
        case '/forgot-password':
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/login');
          }
          return;
        default:
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/welcome');
          }
      }
    },
  );
}

class AuthMessage extends StatelessWidget {
  const AuthMessage({this.error, this.info, super.key});

  final String? error;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final message = error ?? info;
    if (message == null) return const SizedBox.shrink();
    final isError = error != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFECEE) : AppColors.mintLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isError ? AppColors.expense : AppColors.mint),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: isError ? AppColors.expense : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: isLoading ? null : onPressed,
    icon: isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon ?? Icons.arrow_forward_rounded),
    label: Text(isLoading ? 'Lütfen bekleyin…' : label),
  );
}
