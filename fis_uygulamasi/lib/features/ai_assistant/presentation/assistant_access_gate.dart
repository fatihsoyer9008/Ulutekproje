import 'package:finance_database/finance_database.dart'
    show OfflineQueueSummary;
import 'package:flutter/material.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../data/ai_assistant_client.dart';

typedef AssistantSyncAction = Future<void> Function();
typedef AssistantQueueReader = Future<OfflineQueueSummary> Function();
typedef ClaimableTransactionCounter = Future<int> Function();
typedef LocalTransactionClaimer = Future<int> Function();

class AiAssistantAccessGate {
  const AiAssistantAccessGate({
    required this.client,
    required this.authStatus,
    required this.queueSummary,
    required this.syncPendingTasks,
    required this.retryFailedAndConflicted,
    required this.readQueueSummary,
    required this.countClaimableTransactions,
    required this.claimLocalTransactions,
  });

  final AiAssistantAccessClient client;
  final AuthStatus authStatus;
  final OfflineQueueSummary? queueSummary;
  final AssistantSyncAction syncPendingTasks;
  final AssistantSyncAction retryFailedAndConflicted;
  final AssistantQueueReader readQueueSummary;
  final ClaimableTransactionCounter countClaimableTransactions;
  final LocalTransactionClaimer claimLocalTransactions;

  Future<bool> ensureAccess(BuildContext context) async {
    if (authStatus != AuthStatus.authenticated) {
      await _showInformation(
        context,
        title: 'Giriş gerekli',
        message:
            'Finans asistanını kullanabilmek için doğrulanmış hesabınla giriş yapmalısın.',
      );
      return false;
    }

    AiAssistantStatus status;
    try {
      status = await client.fetchStatus();
    } on Object catch (error) {
      if (context.mounted) {
        await _showInformation(
          context,
          title: 'Asistana ulaşılamadı',
          message: _safeError(error),
        );
      }
      return false;
    }

    if (!context.mounted) return false;

    if (!status.enabled) {
      await _showInformation(
        context,
        title: 'Asistan kullanılamıyor',
        message: 'Finans asistanı şu anda sunucu tarafında kapalı.',
      );
      return false;
    }

    final currentQueue = queueSummary;
    if (currentQueue == null) {
      await _showInformation(
        context,
        title: 'Veriler kontrol ediliyor',
        message:
            'Yerel işlemlerin senkronizasyon durumu henüz yüklenmedi. Lütfen birkaç saniye sonra tekrar dene.',
      );
      return false;
    }

    if (!status.consentGranted) {
      final accepted = await _requestConsent(context);
      if (!accepted || !context.mounted) return false;

      try {
        status = await client.updateConsent(
          accepted: true,
          consentVersion: status.requiredConsentVersion,
        );
      } on Object catch (error) {
        if (context.mounted) {
          await _showInformation(
            context,
            title: 'Rıza kaydedilemedi',
            message: _safeError(error),
          );
        }
        return false;
      }

      if (!context.mounted || !status.consentGranted) {
        return false;
      }
    }

    final claimableCount = await countClaimableTransactions();
    if (!context.mounted) return false;
    if (claimableCount > 0) {
      final approved = await _requestLocalDataClaim(context, claimableCount);
      if (!approved || !context.mounted) return false;
      await claimLocalTransactions();
      if (!context.mounted) return false;
    }

    final refreshedQueue = await readQueueSummary();
    if (!context.mounted) return false;
    if (refreshedQueue.hasPending || refreshedQueue.retryableCount > 0) {
      return _synchronizeBeforeOpening(context, refreshedQueue);
    }

    return true;
  }

  Future<bool> _requestLocalDataClaim(BuildContext context, int count) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yerel işlemleri eşitle'),
        content: Text(
          '$count yerel işlemin finans asistanı analizine dahil edilebilmesi '
          'için hesabına güvenli biçimde aktarılacak. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Şimdi değil'),
          ),
          FilledButton(
            key: const Key('assistant_local_claim_confirm_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eşitle ve devam et'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _synchronizeBeforeOpening(
    BuildContext context,
    OfflineQueueSummary summary,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(minutes: 5),
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('Asistan açılmadan önce işlemler eşitleniyor…'),
              ),
            ],
          ),
        ),
      );

    try {
      if (summary.retryableCount > 0) {
        await retryFailedAndConflicted();
      } else {
        await syncPendingTasks();
      }

      final updatedSummary = await readQueueSummary();
      messenger.hideCurrentSnackBar();

      if (!context.mounted) return false;

      if (updatedSummary.hasPending ||
          updatedSummary.hasFailures ||
          updatedSummary.hasConflicts) {
        await _showInformation(
          context,
          title: 'Senkronizasyon tamamlanamadı',
          message:
              'Bazı yerel işlemler henüz buluta aktarılmadı. Eksik finansal analiz göstermemek için asistan açılmadı.',
        );
        return false;
      }

      return true;
    } on Object catch (error) {
      messenger.hideCurrentSnackBar();

      if (context.mounted) {
        await _showInformation(
          context,
          title: 'Senkronizasyon tamamlanamadı',
          message: _safeError(error),
        );
      }
      return false;
    }
  }

  Future<bool> _requestConsent(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finans asistanını etkinleştir'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Asistanın sorularını yanıtlayabilmesi için aşağıdaki finansal özetler yapay zekâ sağlayıcısına gönderilir:',
              ),
              SizedBox(height: 12),
              Text('• Gelir ve gider toplamları'),
              Text('• Kategori ve iş yeri özetleri'),
              Text('• En büyük harcamalar'),
              Text('• Seçilen tarih aralığı'),
              SizedBox(height: 12),
              Text(
                'Fiş görselleri ve işlem notları bu asistan isteğine eklenmez.',
              ),
              SizedBox(height: 12),
              Text(
                'Bu özellik yatırım tavsiyesi sunmaz. Kabul etmezsen asistan açılmaz.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Şimdi değil'),
          ),
          FilledButton(
            key: const Key('assistant_consent_accept_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kabul et ve devam et'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _showInformation(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  String _safeError(Object error) {
    return userFacingErrorMessage(
      error,
      fallbackMessage: 'İşlem tamamlanamadı. Lütfen tekrar deneyin.',
    );
  }
}
