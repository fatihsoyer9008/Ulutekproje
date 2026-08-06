import 'package:app_main/features/ai_assistant/data/ai_assistant_client.dart';
import 'package:app_main/features/ai_assistant/presentation/assistant_consent_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    _FakeAssistantAccessClient client,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AssistantConsentCard(client: client),
          ),
        ),
      ),
    );
  }

  testWidgets('aktif izni gösterir ve kullanıcı onayıyla geri çeker', (
    tester,
  ) async {
    final client = _FakeAssistantAccessClient(
      const AiAssistantStatus(
        enabled: true,
        requiredConsentVersion: '2026-08-01',
        consentGranted: true,
      ),
    );

    await pumpCard(tester, client);
    await tester.pumpAndSettle();

    expect(find.text('AI veri izni açık'), findsOneWidget);
    expect(
      find.byKey(const Key('assistant_consent_revoke_button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('assistant_consent_revoke_button')));
    await tester.pumpAndSettle();

    expect(find.text('AI veri iznini geri çek?'), findsOneWidget);
    expect(client.acceptedValues, isEmpty);

    await tester.tap(
      find.byKey(const Key('assistant_consent_revoke_confirm_button')),
    );
    await tester.pumpAndSettle();

    expect(client.acceptedValues, [false]);
    expect(client.receivedConsentVersions, ['2026-08-01']);
    expect(find.text('AI veri izni kapalı'), findsOneWidget);
    expect(find.text('AI veri işleme izni geri çekildi.'), findsOneWidget);
  });

  testWidgets('kapalı izin durumunda geri çekme düğmesi göstermez', (
    tester,
  ) async {
    final client = _FakeAssistantAccessClient(
      const AiAssistantStatus(
        enabled: true,
        requiredConsentVersion: '2026-08-01',
        consentGranted: false,
      ),
    );

    await pumpCard(tester, client);
    await tester.pumpAndSettle();

    expect(find.text('AI veri izni kapalı'), findsOneWidget);
    expect(
      find.byKey(const Key('assistant_consent_revoke_button')),
      findsNothing,
    );
  });

  testWidgets('durum yükleme hatasından sonra yeniden dener', (tester) async {
    final client = _FakeAssistantAccessClient(
      const AiAssistantStatus(
        enabled: true,
        requiredConsentVersion: '2026-08-01',
        consentGranted: true,
      ),
    )..fetchError = StateError('offline');

    await pumpCard(tester, client);
    await tester.pumpAndSettle();

    expect(find.text('AI izin durumu alınamadı'), findsOneWidget);
    expect(client.fetchCalls, 1);

    client.fetchError = null;
    await tester.tap(find.byKey(const Key('assistant_consent_retry_button')));
    await tester.pumpAndSettle();

    expect(client.fetchCalls, 2);
    expect(find.text('AI veri izni açık'), findsOneWidget);
  });
}

class _FakeAssistantAccessClient implements AiAssistantAccessClient {
  _FakeAssistantAccessClient(this.status);

  AiAssistantStatus status;
  Object? fetchError;
  int fetchCalls = 0;
  final acceptedValues = <bool>[];
  final receivedConsentVersions = <String>[];

  @override
  Future<AiAssistantStatus> fetchStatus() async {
    fetchCalls++;

    final error = fetchError;
    if (error != null) throw error;

    return status;
  }

  @override
  Future<AiAssistantStatus> updateConsent({
    required bool accepted,
    required String consentVersion,
  }) async {
    acceptedValues.add(accepted);
    receivedConsentVersions.add(consentVersion);

    status = AiAssistantStatus(
      enabled: status.enabled,
      requiredConsentVersion: status.requiredConsentVersion,
      consentGranted: accepted,
      consentGrantedAt: accepted ? DateTime.utc(2026, 8, 6, 10, 30) : null,
      consentRevokedAt: accepted ? null : DateTime.utc(2026, 8, 6, 10, 30),
    );

    return status;
  }
}
