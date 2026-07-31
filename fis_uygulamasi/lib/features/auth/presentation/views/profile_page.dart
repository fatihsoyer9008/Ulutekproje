import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_session_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authSessionControllerProvider);
    final user = state.user;
    final isGuest = state.status == AuthStatus.guest;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil ve Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.mint,
                  child: Icon(Icons.person_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGuest
                            ? 'Misafir kullanıcı'
                            : (user?.displayName ?? 'Finans kullanıcısı'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(user?.email ?? 'Veriler yalnızca bu cihazda'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: ListTile(
              key: const Key('category_management_tile'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.category_outlined),
              title: const Text('Kategoriler'),
              subtitle: const Text('Kategori, renk ve ikonlarını yönet'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/categories'),
            ),
          ),
          const SizedBox(height: 20),
          if (isGuest)
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Hesaba Giriş Yap'),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      await ref
                          .read(authSessionControllerProvider.notifier)
                          .logout();
                      if (context.mounted) context.go('/welcome');
                    },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Çıkış Yap'),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
              onPressed: state.isLoading
                  ? null
                  : () => _confirmDelete(context, ref),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Hesabı Sil'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hesabı kalıcı olarak sil?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Buluttaki hesap ve finans verileri silinecektir. Bu işlem geri alınamaz.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre (e-posta hesabı için)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      password.dispose();
      return;
    }
    final success = await ref
        .read(authSessionControllerProvider.notifier)
        .deleteAccount(
          currentPassword: password.text.isEmpty ? null : password.text,
        );
    password.dispose();
    if (success && context.mounted) context.go('/welcome');
  }
}
