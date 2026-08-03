import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_mode_provider.dart';
import '../../features/auth/presentation/controllers/auth_session_controller.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({required this.onProfilePressed, super.key});

  final VoidCallback onProfilePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authSessionControllerProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final email = auth.user?.email ?? auth.pendingEmail;
    final displayName = auth.user?.displayName?.trim();
    final isGuest = auth.status == AuthStatus.guest;
    final identity = isGuest
        ? 'Misafir kullanıcı'
        : (displayName?.isNotEmpty ?? false)
        ? displayName!
        : (email ?? 'Finans kullanıcısı');
    final initial = identity.substring(0, 1).toUpperCase();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.mint,
                    foregroundColor: AppColors.primary,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          identity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email ?? 'Veriler yalnızca bu cihazda',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('drawer_profile_tile'),
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Profil ve Ayarlar'),
              subtitle: const Text('Hesap ve uygulama ayarlarını yönet'),
              onTap: () {
                Navigator.of(context).pop();
                onProfilePressed();
              },
            ),
            ListTile(
              key: const Key('drawer_theme_tile'),
              leading: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
              title: const Text('Tema Değiştir'),
              subtitle: Text(
                themeMode == ThemeMode.dark
                    ? 'Açık temaya geç'
                    : 'Koyu temaya geç',
              ),
              onTap: () {
                ref
                    .read(appThemeModeProvider.notifier)
                    .state = themeMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark;
              },
            ),
            const Spacer(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
