import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_session_controller.dart';
import '../widgets/auth_widgets.dart';

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const AppLogo(size: 112),
            const SizedBox(height: 28),
            Text(
              'Paranı daha akıllı yönet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Fişlerini tara, harcamalarını takip et ve bütçeni tek yerde gör.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            FilledButton(
              key: const Key('welcome_login_button'),
              onPressed: () => context.go('/login'),
              child: const Text('Giriş Yap'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                ref
                    .read(authSessionControllerProvider.notifier)
                    .continueAsGuest();
                context.go('/home');
              },
              child: const Text('Misafir Olarak Devam Et'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/register'),
              child: const Text('Yeni hesap oluştur'),
            ),
          ],
        ),
      ),
    ),
  );
}
