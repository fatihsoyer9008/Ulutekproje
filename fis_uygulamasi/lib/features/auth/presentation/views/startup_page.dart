import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../onboarding/data/onboarding_preferences.dart';
import '../controllers/auth_session_controller.dart';
import '../widgets/auth_widgets.dart';

class StartupPage extends ConsumerStatefulWidget {
  const StartupPage({super.key});

  @override
  ConsumerState<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends ConsumerState<StartupPage> {
  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final onboardingStatus = ref
        .read(onboardingPreferencesProvider)
        .isCompleted();
    await ref.read(authSessionControllerProvider.notifier).initialize();
    final onboardingCompleted = await onboardingStatus;
    if (!mounted) return;
    final state = ref.read(authSessionControllerProvider);
    if (state.status == AuthStatus.authenticated ||
        state.status == AuthStatus.guest) {
      context.go('/home');
      return;
    }
    context.go(onboardingCompleted ? '/welcome' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppLogo(size: 96),
          SizedBox(height: 24),
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Güvenli oturum kontrol ediliyor…'),
        ],
      ),
    ),
  );
}
