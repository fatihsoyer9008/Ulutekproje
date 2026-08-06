import 'package:finance_database/finance_database.dart'
    show OfflineQueueSummary;
import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../data/ai_assistant_client.dart';

typedef AssistantSyncAction = Future<void> Function();
typedef AssistantQueueReader = Future<OfflineQueueSummary> Function();

class AiAssistantAccessGate {
  const AiAssistantAccessGate({
    required this.client,
    required this.authStatus,
    required this.queueSummary,
    required this.syncPendingTasks,
    required this.retryFailedAndConflicted,
    required this.readQueueSummary,
  });

  final AiAssistantAccessClient client;
  final AuthStatus authStatus;
  final OfflineQueueSummary? queueSummary;
  final AssistantSyncAction syncPendingTasks;
  final AssistantSyncAction retryFailedAndConflicted;
  final AssistantQueueReader readQueueSummary;

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

    if (currentQueue.hasPending || currentQueue.retryableCount > 0) {
      return _synchronizeBeforeOpening(context, currentQueue);
    }

    return true;
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
    final message = error.toString().trim();
    if (message.isEmpty) {
      return 'Beklenmeyen bir hata oluştu. Lütfen tekrar dene.';
    }

    return message
        .replaceFirst('Exception: ', '')
        .replaceFirst('FormatException: ', '');
  }
}
