import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    Future<void>(() async {
      await ref.read(authSessionControllerProvider.notifier).initialize();
      if (!mounted) return;
      final state = ref.read(authSessionControllerProvider);
      context.go(
        state.status == AuthStatus.authenticated ? '/home' : '/welcome',
      );
    });
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
