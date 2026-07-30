import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../backup/data/transaction_json_import_service.dart';
import '../controllers/auth_session_controller.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({this.transactionImportService, super.key});

  final TransactionJsonImportService? transactionImportService;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
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
          if (widget.transactionImportService != null) ...[
            const SizedBox(height: 20),
            Text(
              'Veri yedekleme',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daha önce dışa aktarılan JSON yedeğini seçerek işlemlerini '
                    'bu cihaza geri yükleyebilirsin.',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('transaction_import_button'),
                      onPressed: _isImporting ? null : _importTransactions,
                      icon: _isImporting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.settings_backup_restore_rounded),
                      label: Text(
                        _isImporting
                            ? 'JSON yedeği okunuyor...'
                            : 'JSON Yedeğini İçe Aktar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              onPressed: state.isLoading ? null : () => _confirmDelete(context),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Hesabı Sil'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _importTransactions() async {
    final service = widget.transactionImportService;
    if (service == null || _isImporting) return;

    setState(() => _isImporting = true);
    try {
      final preview = await service.selectBackup();
      if (!mounted || preview == null) return;
      if (preview.transactions.isEmpty) {
        _showMessage('Seçilen yedekte içe aktarılacak işlem bulunamadı.');
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('JSON yedeği içe aktarılsın mı?'),
          content: Text(
            '${preview.fileName} dosyasında ${preview.transactions.length} '
            'işlem bulundu. Mevcut işlemler korunacak ve aynı kayıtlar tekrar '
            'eklenmeyecek.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              key: const Key('confirm_transaction_import_button'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('İçe Aktar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final result = await service.importBackup(preview);
      if (!mounted) return;
      final skippedText = result.skippedDuplicateCount == 0
          ? ''
          : ' ${result.skippedDuplicateCount} tekrar eden kayıt atlandı.';
      _showMessage('${result.importedCount} işlem içe aktarıldı.$skippedText');
    } on TransactionJsonImportException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Exception {
      if (mounted) {
        _showMessage(
          'JSON yedeği içe aktarılırken beklenmeyen bir hata oluştu.',
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDelete(BuildContext context) async {
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
