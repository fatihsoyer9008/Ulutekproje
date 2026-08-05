import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../domain/sync_state.dart';

class ProfileSyncStatusCard extends StatelessWidget {
  const ProfileSyncStatusCard({
    required this.state,
    required this.isGuest,
    this.pendingTaskCount = 0,
    this.onRetry,
    super.key,
  });

  final SyncState state;
  final bool isGuest;
  final int pendingTaskCount;
  final VoidCallback? onRetry;

  bool get _hasPendingTasks => pendingTaskCount > 0;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation;
    return AppCard(
      child: Column(
        key: const Key('profile_sync_status_card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: presentation.color.withValues(alpha: .14),
                foregroundColor: presentation.color,
                child: Icon(presentation.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulut senkronizasyonu',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      presentation.title,
                      key: const Key('profile_sync_status_title'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            presentation.description,
            key: const Key('profile_sync_status_description'),
          ),
          if (!isGuest && state.status == SyncStatus.syncing) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              key: const Key('profile_sync_progress'),
              value: state.progress,
              borderRadius: BorderRadius.circular(99),
            ),
          ],
          if (!isGuest &&
              (_hasPendingTasks ||
                  state.status == SyncStatus.error ||
                  state.status == SyncStatus.conflict) &&
              onRetry != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('profile_sync_retry_button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  _hasPendingTasks ? 'Şimdi senkronize et' : 'Tekrar dene',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _SyncPresentation get _presentation {
    if (isGuest) {
      return const _SyncPresentation(
        icon: Icons.cloud_off_outlined,
        color: AppColors.warning,
        title: 'Yalnızca bu cihazda',
        description:
            'Bulut senkronizasyonunu kullanmak için hesabına giriş yap.',
      );
    }

    if (_hasPendingTasks && state.status != SyncStatus.syncing) {
      return _SyncPresentation(
        icon: Icons.cloud_upload_outlined,
        color: AppColors.warning,
        title: 'Senkronizasyon bekliyor',
        description: '$pendingTaskCount işlem buluta gönderilmeyi bekliyor.',
      );
    }

    return switch (state.status) {
      SyncStatus.idle => const _SyncPresentation(
        icon: Icons.cloud_queue_outlined,
        color: AppColors.primary,
        title: 'Senkronizasyon hazır',
        description:
            'Bekleyen işlemler bağlantı kurulduğunda otomatik olarak eşitlenir.',
      ),
      SyncStatus.syncing => _SyncPresentation(
        icon: Icons.cloud_upload_outlined,
        color: AppColors.warning,
        title: 'Senkronize ediliyor',
        description: state.totalCount == 0
            ? 'Bekleyen işlemler buluta gönderiliyor.'
            : '${state.completedCount}/${state.totalCount} işlem tamamlandı.',
      ),
      SyncStatus.success => _SyncPresentation(
        icon: Icons.cloud_done_outlined,
        color: AppColors.primary,
        title: 'Senkronizasyon tamamlandı',
        description: state.totalCount == 0
            ? 'Tüm verilerin güncel.'
            : '${state.completedCount} işlem başarıyla eşitlendi.',
      ),
      SyncStatus.conflict => _SyncPresentation(
        icon: Icons.sync_problem_outlined,
        color: AppColors.warning,
        title: 'Dikkat gereken kayıtlar var',
        description: state.conflictCount == 0
            ? 'Bazı kayıtlar eşitlenemedi. Yeniden deneyebilirsin.'
            : '${state.conflictCount} kayıt çakışması yeniden denenmeyi bekliyor.',
      ),
      SyncStatus.error => _SyncPresentation(
        icon: Icons.cloud_off_outlined,
        color: AppColors.expense,
        title: 'Senkronizasyon tamamlanamadı',
        description:
            state.errorMessage ??
            'Bağlantını kontrol edip yeniden deneyebilirsin.',
      ),
    };
  }
}

class _SyncPresentation {
  const _SyncPresentation({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
}
