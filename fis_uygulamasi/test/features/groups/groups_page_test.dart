import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/features/groups/data/fake_group_repository.dart';
import 'package:app_main/features/groups/presentation/groups_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  testWidgets('grup kartında ad ve üye sayısı gösterilir', (tester) async {
    final repository = FakeGroupRepository(
      groups: const [twoMemberGroup],
      debtSummariesByGroup: const {
        twoMemberGroupId: currentUserDebtorDebtSummary,
      },
    );

    await _pumpGroupsPage(tester, repository);

    expect(find.text('Ev Arkadaşları'), findsOneWidget);
    expect(find.text('2 üye'), findsOneWidget);
    expect(find.textContaining('borç'), findsOneWidget);
  });

  testWidgets('grup yoksa empty state gösterilir', (tester) async {
    await _pumpGroupsPage(tester, FakeGroupRepository());

    expect(find.text('Henüz grubunuz yok'), findsOneWidget);
    expect(find.byKey(const Key('create_group_button')), findsOneWidget);
  });

  testWidgets('yükleme sırasında progress göstergesi gösterilir', (
    tester,
  ) async {
    final repository = FakeGroupRepository(
      latency: const Duration(milliseconds: 100),
    );

    final controller = AuthSessionController(_GroupsAuthRepository());
    await controller.login('user@example.com', 'password');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith((ref) => controller),
          groupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: GroupsPage()),
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  });

  testWidgets('gruplar yüklenemezse hata durumu gösterilir', (tester) async {
    await _pumpGroupsPage(
      tester,
      FakeGroupRepository(error: groupsApiErrorException),
    );

    expect(find.text('Gruplar yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  testWidgets('boş grup adı için validasyon gösterilir', (tester) async {
    await _pumpGroupsPage(tester, FakeGroupRepository());

    await tester.tap(find.byKey(const Key('create_group_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create_group_submit_button')));
    await tester.pump();

    expect(find.text('Grup adı boş bırakılamaz.'), findsOneWidget);
  });

  testWidgets('yeni grup oluşturulunca liste yenilenir', (tester) async {
    await _pumpGroupsPage(tester, FakeGroupRepository());

    await tester.tap(find.byKey(const Key('create_group_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('group_name_field')),
      'Hafta Sonu Planı',
    );
    await tester.tap(find.byKey(const Key('create_group_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Hafta Sonu Planı'), findsOneWidget);
    expect(find.text('Grup oluşturuldu.'), findsOneWidget);
  });
}

Future<void> _pumpGroupsPage(
  WidgetTester tester,
  FakeGroupRepository repository,
) async {
  final controller = AuthSessionController(_GroupsAuthRepository());
  await controller.login('user@example.com', 'password');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith((ref) => controller),
        groupRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: GroupsPage()),
    ),
  );

  await tester.pumpAndSettle();
}

class _GroupsAuthRepository implements AuthRepositoryBase {
  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    return const AuthUser(
      id: currentUserId,
      email: 'user@example.com',
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthUser> signInWithGoogle() {
    return login(email: 'google@example.com', password: 'unused');
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser?> silentRefresh() async => null;

  @override
  Future<void> deleteAccount({String? currentPassword}) async {}

  @override
  Future<String> forgotPassword(String email) async => 'Sent';

  @override
  Future<String> register({
    required String email,
    required String password,
    String? displayName,
  }) async => 'Registered';

  @override
  Future<String> resendVerification(String email) async => 'Sent';

  @override
  Future<String> verifyEmail(String token) async => 'Verified';
}
