import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../core/errors/user_facing_error.dart';
import '../data/ai_assistant_client.dart';

class AssistantConsentCard extends StatefulWidget {
  const AssistantConsentCard({required this.client, super.key});

  final AiAssistantAccessClient client;

  @override
  State<AssistantConsentCard> createState() => _AssistantConsentCardState();
}

class _AssistantConsentCardState extends State<AssistantConsentCard> {
  AiAssistantStatus? _status;
  String? _loadError;
  String? _actionError;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void didUpdateWidget(covariant AssistantConsentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.client, widget.client)) {
      _reloadStatus();
    }
  }

  Future<void> _loadStatus() async {
    try {
      final status = await widget.client.fetchStatus();
      if (!mounted) return;

      setState(() {
        _status = status;
        _loadError = null;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;

      setState(() {
        _loadError = _safeError(error);
        _isLoading = false;
      });
    }
  }

  void _reloadStatus() {
    setState(() {
      _status = null;
      _loadError = null;
      _actionError = null;
      _isLoading = true;
    });
    _loadStatus();
  }

  Future<void> _revokeConsent() async {
    final status = _status;
    if (status == null || !status.consentGranted || _isUpdating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AI veri iznini geri çek?'),
        content: const Text(
          'İzni geri çektiğinde yeni finansal özetler yapay zekâ '
          'sağlayıcısına gönderilmez ve finans asistanı yeniden izin '
          'verene kadar kullanılamaz. Bu işlem daha önce oluşturulmuş '
          'yanıtları geriye dönük olarak değiştirmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('assistant_consent_revoke_confirm_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('İzni geri çek'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isUpdating = true;
      _actionError = null;
    });

    try {
      final updatedStatus = await widget.client.updateConsent(
        accepted: false,
        consentVersion: status.requiredConsentVersion,
      );
      if (!mounted) return;

      setState(() {
        _status = updatedStatus;
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('AI veri işleme izni geri çekildi.')),
        );
    } on Object catch (error) {
      if (!mounted) return;

      setState(() {
        _actionError = _safeError(error);
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppCard(
        key: Key('assistant_consent_card'),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Expanded(child: Text('AI izin durumu yükleniyor…')),
          ],
        ),
      );
    }

    final loadError = _loadError;
    if (loadError != null) {
      return AppCard(
        key: const Key('assistant_consent_card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI izin durumu alınamadı',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(loadError),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('assistant_consent_retry_button'),
              onPressed: _reloadStatus,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      );
    }

    final status = _status;
    if (status == null) {
      return const SizedBox.shrink();
    }

    final permissionActive = status.enabled && status.consentGranted;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      key: const Key('assistant_consent_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: permissionActive
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                foregroundColor: permissionActive
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                child: Icon(
                  permissionActive
                      ? Icons.verified_user_outlined
                      : Icons.privacy_tip_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      permissionActive
                          ? 'AI veri izni açık'
                          : 'AI veri izni kapalı',
                      key: const Key('assistant_consent_status_text'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      !status.enabled
                          ? 'Finans asistanı şu anda sunucu tarafında kapalı.'
                          : permissionActive
                          ? 'Finansal özetler yalnızca asistan sorularını yanıtlamak için işlenebilir.'
                          : 'Asistanı açtığında veri işleme izni yeniden sorulur.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_actionError != null) ...[
            const SizedBox(height: 12),
            Text(
              _actionError!,
              key: const Key('assistant_consent_action_error'),
              style: TextStyle(color: scheme.error),
            ),
          ],
          if (permissionActive) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('assistant_consent_revoke_button'),
                onPressed: _isUpdating ? null : _revokeConsent,
                icon: _isUpdating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.block_outlined),
                label: Text(
                  _isUpdating ? 'İzin geri çekiliyor…' : 'İzni geri çek',
                ),
              ),
            ),
          ],
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
