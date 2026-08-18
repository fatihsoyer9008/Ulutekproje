import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ai_assistant/data/ai_assistant_client.dart';
import '../../../ai_assistant/presentation/assistant_consent_card.dart';
import '../../../../application/service/transaction_export_file_service.dart';
import '../../../../core/database/database_providers.dart';
import '../../../backup/data/transaction_json_import_service.dart';
import '../../../groups/application/group_sync_coordinator.dart';
import '../../../sync/application/sync_coordinator.dart';
import '../../../sync/presentation/widgets/profile_sync_status_card.dart';
import '../controllers/auth_session_controller.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({
    this.transactionImportService,
    this.aiAssistantClient,
    super.key,
  });

  final TransactionJsonImportService? transactionImportService;
  final AiAssistantAccessClient? aiAssistantClient;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isImporting = false;
  TransactionExportFormat? _exportingFormat;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authSessionControllerProvider);
    final syncState = ref.watch(syncCoordinatorProvider);
    final queueSummary = ref
        .watch(offlineQueueSummaryProvider)
        .maybeWhen(data: (summary) => summary, orElse: OfflineQueueSummary.new);
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
          ProfileSyncStatusCard(
            state: syncState,
            isGuest: isGuest,
            queueSummary: queueSummary,
            onSyncPending: isGuest
                ? null
                : () => Future.wait<void>(<Future<void>>[
                    ref
                        .read(syncCoordinatorProvider.notifier)
                        .syncPendingTasks(),
                    ref
                        .read(groupSyncCoordinatorProvider.notifier)
                        .syncPendingAndPull(),
                  ]),
            onRetry: isGuest
                ? null
                : () => Future.wait<void>(<Future<void>>[
                    ref
                        .read(syncCoordinatorProvider.notifier)
                        .retryFailedAndConflicted(),
                    ref
                        .read(groupSyncCoordinatorProvider.notifier)
                        .retryFailedAndConflicted(),
                  ]),
            onResolveConflicts: isGuest
                ? null
                : () => context.push('/sync-conflicts'),
          ),
          if (!isGuest && widget.aiAssistantClient != null) ...[
            const SizedBox(height: 20),
            Text(
              'Yapay zekâ ve gizlilik',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            AssistantConsentCard(client: widget.aiAssistantClient!),
          ],
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
                    'Daha önce dışa aktarılan JSON veya CSV yedeğini seçerek '
                    'işlemlerini '
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
                            ? 'Yedek okunuyor...'
                            : 'JSON / CSV Yedeğini İçe Aktar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verileri Dışa Aktar',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'İşlem geçmişini JSON veya CSV dosyası olarak dışa aktarabilirsin.',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('transaction_export_json_button'),
                    onPressed: _exportingFormat == null
                        ? () => _exportTransactions(
                            context,
                            ref,
                            TransactionExportFormat.json,
                          )
                        : null,
                    icon: _exportIcon(TransactionExportFormat.json),
                    label: Text(
                      _exportingFormat == TransactionExportFormat.json
                          ? 'JSON hazırlanıyor...'
                          : 'JSON Olarak Dışa Aktar',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('transaction_export_csv_button'),
                    onPressed: _exportingFormat == null
                        ? () => _exportTransactions(
                            context,
                            ref,
                            TransactionExportFormat.csv,
                          )
                        : null,
                    icon: _exportIcon(TransactionExportFormat.csv),
                    label: Text(
                      _exportingFormat == TransactionExportFormat.csv
                          ? 'CSV hazırlanıyor...'
                          : 'CSV Olarak Dışa Aktar',
                    ),
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
              key: const Key('guest_login_button'),
              onPressed: () => context.go('/login'),
              child: const Text('Hesaba Giriş Yap'),
            )
          else ...[
            OutlinedButton.icon(
              key: const Key('logout_button'),
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
          title: Text('${preview.format.label} yedeği içe aktarılsın mı?'),
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
        _showMessage('Yedek içe aktarılırken beklenmeyen bir hata oluştu.');
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

  Widget _exportIcon(TransactionExportFormat format) {
    if (_exportingFormat == format) {
      return const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return const Icon(Icons.ios_share_rounded);
  }

  Future<void> _exportTransactions(
    BuildContext context,
    WidgetRef ref,
    TransactionExportFormat format,
  ) async {
    if (_exportingFormat != null) return;
    setState(() => _exportingFormat = format);
    try {
      final auth = ref.read(authSessionControllerProvider);
      final service = TransactionExportFileService.fromIsar(
        ref.read(isarProvider),
        ownerKey: auth.status == AuthStatus.authenticated && auth.user != null
            ? 'user:${auth.user!.id}'
            : null,
      );
      final saveResult = await service.exportAndSave(format);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_exportSuccessMessage(saveResult))),
      );
    } on TransactionExportCancelledException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dışa aktarma iptal edildi.')),
      );
    } on TransactionExportFileException catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dosya dışa aktarılamadı.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dışa aktarma hazırlanamadı.')),
      );
    } finally {
      if (mounted) setState(() => _exportingFormat = null);
    }
  }

  String _exportSuccessMessage(TransactionExportSaveResult result) =>
      switch (result.destination) {
        TransactionExportSaveDestination.documents =>
          '${result.displayValue} Documents klasörüne kaydedildi.',
        TransactionExportSaveDestination.shareSheet =>
          '${result.displayValue} paylaşım işlemi tamamlandı.',
        TransactionExportSaveDestination.selectedLocation =>
          '${result.displayValue} konumuna kaydedildi.',
      };

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
