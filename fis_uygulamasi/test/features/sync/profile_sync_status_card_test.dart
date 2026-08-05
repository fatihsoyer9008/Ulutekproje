import 'package:app_main/features/sync/domain/sync_state.dart';
import 'package:app_main/features/sync/presentation/widgets/profile_sync_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required SyncState state,
    bool isGuest = false,
    int pendingTaskCount = 0,
    VoidCallback? onRetry,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProfileSyncStatusCard(
          state: state,
          isGuest: isGuest,
          pendingTaskCount: pendingTaskCount,
          onRetry: onRetry,
        ),
      ),
    ),
  );

  testWidgets('senkronizasyon ilerlemesini gösterir', (tester) async {
    await pumpCard(
      tester,
      state: const SyncState(
        status: SyncStatus.syncing,
        completedCount: 2,
        totalCount: 5,
      ),
    );

    expect(find.text('Senkronize ediliyor'), findsOneWidget);
    expect(find.text('2/5 işlem tamamlandı.'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('profile_sync_progress')),
    );
    expect(progress.value, .4);
  });

  testWidgets('hata durumunda yeniden deneme sunar', (tester) async {
    var retryCount = 0;
    await pumpCard(
      tester,
      state: const SyncState(
        status: SyncStatus.error,
        errorMessage: 'Sunucuya ulaşılamadı.',
      ),
      onRetry: () => retryCount++,
    );

    expect(find.text('Senkronizasyon tamamlanamadı'), findsOneWidget);
    expect(find.text('Sunucuya ulaşılamadı.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile_sync_retry_button')));
    expect(retryCount, 1);
  });

  testWidgets(
    'yeni offline görev gelince tamamlandı yerine bekliyor gösterir',
    (tester) async {
      var syncCount = 0;
      await pumpCard(
        tester,
        state: const SyncState(status: SyncStatus.success),
        pendingTaskCount: 2,
        onRetry: () => syncCount++,
      );

      expect(find.text('Senkronizasyon bekliyor'), findsOneWidget);
      expect(
        find.text('2 işlem buluta gönderilmeyi bekliyor.'),
        findsOneWidget,
      );
      expect(find.text('Şimdi senkronize et'), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile_sync_retry_button')));
      expect(syncCount, 1);
    },
  );

  testWidgets('misafir kullanıcıya yerel veri durumunu gösterir', (
    tester,
  ) async {
    await pumpCard(
      tester,
      state: const SyncState(status: SyncStatus.error),
      isGuest: true,
    );

    expect(find.text('Yalnızca bu cihazda'), findsOneWidget);
    expect(find.byKey(const Key('profile_sync_retry_button')), findsNothing);
  });

  testWidgets('çakışan kayıt sayısını gösterir', (tester) async {
    await pumpCard(
      tester,
      state: const SyncState(status: SyncStatus.conflict, conflictCount: 3),
      onRetry: () {},
    );

    expect(find.text('Dikkat gereken kayıtlar var'), findsOneWidget);
    expect(
      find.text('3 kayıt çakışması yeniden denenmeyi bekliyor.'),
      findsOneWidget,
    );
  });
}
