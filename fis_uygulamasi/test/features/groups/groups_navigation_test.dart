import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_main/features/ai_assistant/data/ai_assistant_client.dart';
import 'package:app_main/features/ai_assistant/presentation/assistant_consent_card.dart';
import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/groups/data/api_group_expense_repository.dart';
import 'package:app_main/features/groups/data/fake_group_repository.dart'
    show FakeGroupRepository;
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/data/group_repository.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/presentation/group_ocr_page.dart';
import 'package:app_main/features/groups/presentation/groups_page.dart';
import 'package:app_main/features/groups/presentation/fast_split_page.dart';
import 'package:app_main/features/groups/presentation/itemized_split_page.dart';
import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:app_main/src/app/finance_app.dart';
import 'package:app_main/src/screens/expense_screen.dart'
    show ReceiptParseHandler, ReceiptScanLauncher;
import 'package:finance_database/finance_database.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  testWidgets('authenticated user opens groups from the drawer', (
    tester,
  ) async {
    final controller = AuthSessionController(_NavigationAuthRepository());
    await controller.login('user@example.com', 'password');

    await _pumpApp(tester, controller);
    await _openGroupsFromDrawer(tester);

    expect(find.byType(GroupsPage), findsOneWidget);
  });

  testWidgets('grup detayındaki Fiş Tara ayrı grup OCR routeunu açar', (
    tester,
  ) async {
    final controller = AuthSessionController(_NavigationAuthRepository());
    await controller.login('user@example.com', 'password');

    await _pumpApp(tester, controller);
    await _openGroupsFromDrawer(tester);
    await tester.tap(find.text('Ev Arkadaşları'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_group_expense_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('select_scan_receipt_button')));
    await tester.pumpAndSettle();

    expect(find.byType(GroupOcrPage), findsOneWidget);
    final groupOcrPage = tester.widget<GroupOcrPage>(find.byType(GroupOcrPage));
    expect(groupOcrPage.group.id, '10000000-0000-4000-8000-000000000001');
    expect(groupOcrPage.group.name, 'Ev Arkadaşları');
    expect(find.text('Ev Arkadaşları'), findsOneWidget);
  });

  testWidgets(
    'OCR kontrolü Fast Split API kaydı sonrası grup detayı ve bakiyeyi yeniler',
    (tester) async {
      final repository = _TrackingGroupRepository();
      final api = _ExpenseApiHarness();
      addTearDown(api.close);
      final controller = AuthSessionController(_NavigationAuthRepository());
      await controller.login('user@example.com', 'password');

      await _pumpApp(
        tester,
        controller,
        groupRepository: repository,
        expenseRepository: api.repository,
        scanReceipt: (_) async => 'KİRA TOPLAM 120,00',
        parseReceipt: (_, {cancelToken}) async => const ReceiptParseResult(
          draft: TransactionDraft(
            institutionName: 'E2E Kira',
            category: 'Konut',
            amountInMinor: 12000,
          ),
          normalizedOcrText: 'KİRA TOPLAM 120,00',
          confidenceScore: .98,
          isParseSuccessful: true,
        ),
      );
      await _openGroupOcr(tester);
      await tester.tap(find.byKey(const Key('group_ocr_camera_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('share_with_group_button')));
      await tester.pumpAndSettle();
      expect(find.byType(FastSplitPage), findsOneWidget);
      final debtCallsBeforeSubmit = repository.debtSummaryCalls;

      await tester.drag(
        find.descendant(
          of: find.byType(FastSplitPage),
          matching: find.byType(ListView),
        ),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fast_split_submit')));
      await tester.pumpAndSettle();

      expect(api.createCalls, 1);
      expect(api.lastRequestBody?['split'], containsPair('type', 'equal'));
      expect(api.lastIdempotencyKey, matches(_uuidV4));
      expect(find.byKey(const Key('group_detail_name')), findsOneWidget);
      expect(find.text('E2E Kira'), findsOneWidget);
      expect(repository.debtSummaryCalls, greaterThan(debtCallsBeforeSubmit));
    },
  );

  testWidgets(
    'OCR kontrolü Itemized API kaydı ve ek tutar sonrası grup detayını yeniler',
    (tester) async {
      final repository = _TrackingGroupRepository();
      final api = _ExpenseApiHarness();
      addTearDown(api.close);
      final controller = AuthSessionController(_NavigationAuthRepository());
      await controller.login('user@example.com', 'password');

      await _pumpApp(
        tester,
        controller,
        groupRepository: repository,
        expenseRepository: api.repository,
        scanReceipt: (_) async => 'MARKET SÜT 60,00 TOPLAM 70,00',
        parseReceipt: (_, {cancelToken}) async => const ReceiptParseResult(
          draft: TransactionDraft(
            institutionName: 'E2E Market',
            category: 'Market',
            amountInMinor: 7000,
            receiptItems: [
              ReceiptItem(
                name: 'Süt',
                quantity: 1,
                unitPriceInMinor: 6000,
                totalAmountInMinor: 6000,
              ),
            ],
          ),
          normalizedOcrText: 'MARKET SÜT 60,00 TOPLAM 70,00',
          confidenceScore: .98,
          isParseSuccessful: true,
        ),
      );
      await _openGroupOcr(tester);
      await tester.tap(find.byKey(const Key('group_ocr_camera_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('share_with_group_button')));
      await tester.pumpAndSettle();
      expect(find.byType(ItemizedSplitPage), findsOneWidget);

      final itemizedList = find.byKey(const Key('itemized_split_scroll_view'));
      await tester.drag(itemizedList, const Offset(0, -450));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(Key('itemized_line_0_member_$currentUserId')),
      );
      await tester.pump();
      await tester.drag(itemizedList, const Offset(0, -650));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('itemized_split_submit')));
      await tester.pumpAndSettle();

      expect(api.createCalls, 1);
      final split = api.lastRequestBody?['split'] as Map;
      expect(split['type'], 'itemized');
      expect(
        (split['line_items'] as List).single,
        contains('receipt_line_item_position'),
      );
      expect((split['extra_amounts'] as List).single, {
        'type': 'other',
        'label': 'Fiş toplam farkı',
        'amount_in_minor': 1000,
        'shares': [
          {'user_id': currentUserId, 'amount_in_minor': 1000},
        ],
      });
      expect(api.lastIdempotencyKey, matches(_uuidV4));
      expect(find.byKey(const Key('group_detail_name')), findsOneWidget);
      expect(find.text('E2E Market'), findsOneWidget);
    },
  );
  testWidgets('OCR route state.extra olmadan grup bilgisini yükler', (
    tester,
  ) async {
    final controller = AuthSessionController(_NavigationAuthRepository());
    await controller.login('user@example.com', 'password');

    await _pumpApp(tester, controller);

    final routerContext = tester.element(
      find.byKey(const Key('app_menu_button')),
    );

    GoRouter.of(
      routerContext,
    ).go('/groups/10000000-0000-4000-8000-000000000001/ocr');

    await tester.pumpAndSettle();

    expect(find.byType(GroupOcrPage), findsOneWidget);

    final groupOcrPage = tester.widget<GroupOcrPage>(find.byType(GroupOcrPage));

    expect(groupOcrPage.group.id, '10000000-0000-4000-8000-000000000001');
    expect(groupOcrPage.group.name, 'Ev Arkadaşları');
    expect(find.text('Ev Arkadaşları'), findsOneWidget);
  });

  testWidgets('OCR route grup yükleme hatasında retry ile açılır', (
    tester,
  ) async {
    final controller = AuthSessionController(_NavigationAuthRepository());
    await controller.login('user@example.com', 'password');

    final repository = _RetryingOcrRouteRepository();

    await _pumpApp(tester, controller, groupRepository: repository);

    final routerContext = tester.element(
      find.byKey(const Key('app_menu_button')),
    );

    GoRouter.of(routerContext).go('/groups/$twoMemberGroupId/ocr');

    await tester.pumpAndSettle();

    expect(repository.getGroupCalls, 1);
    expect(find.byType(GroupOcrPage), findsNothing);
    expect(
      find.text(
        'Grup bilgisi yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tekrar Dene'), findsOneWidget);

    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();

    expect(repository.getGroupCalls, 2);
    expect(find.byType(GroupOcrPage), findsOneWidget);

    final groupOcrPage = tester.widget<GroupOcrPage>(find.byType(GroupOcrPage));

    expect(groupOcrPage.group.id, twoMemberGroupId);
    expect(groupOcrPage.group.name, 'Ev Arkadaşları');
  });

  testWidgets('guest returns to groups after email login', (tester) async {
    final controller = AuthSessionController(_NavigationAuthRepository())
      ..continueAsGuest();

    await _pumpApp(tester, controller);
    await _openGroupsFromDrawer(tester);

    expect(find.byKey(const Key('login_submit_button')), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byType(GroupsPage), findsOneWidget);
  });

  testWidgets('guest returns to groups after Google login', (tester) async {
    final controller = AuthSessionController(_NavigationAuthRepository())
      ..continueAsGuest();

    await _pumpApp(tester, controller);
    await _openGroupsFromDrawer(tester);
    final googleLoginButton = find.byKey(const Key('google_login_button'));
    await tester.ensureVisible(googleLoginButton);
    await tester.pumpAndSettle();
    await tester.tap(googleLoginButton);
    await tester.pumpAndSettle();

    expect(find.byType(GroupsPage), findsOneWidget);
  });

  testWidgets('expired API session redirects protected group route to login', (
    tester,
  ) async {
    final unauthorizedEvents = StreamController<void>();
    addTearDown(unauthorizedEvents.close);
    final controller = AuthSessionController(
      _NavigationAuthRepository(),
      unauthorizedEvents: unauthorizedEvents.stream,
    );
    await controller.login('user@example.com', 'password');

    await _pumpApp(tester, controller);
    await _openGroupsFromDrawer(tester);
    expect(find.byType(GroupsPage), findsOneWidget);

    unauthorizedEvents.add(null);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
    expect(find.textContaining('Oturum süreniz doldu'), findsOneWidget);
  });

  testWidgets('profile route keeps the AI assistant consent card', (
    tester,
  ) async {
    final controller = AuthSessionController(_NavigationAuthRepository());
    await controller.login('user@example.com', 'password');

    await _pumpApp(tester, controller);
    await tester.tap(find.byKey(const Key('app_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer_profile_tile')));
    await tester.pumpAndSettle();

    expect(find.byType(AssistantConsentCard), findsOneWidget);
    expect(find.byKey(const Key('assistant_consent_card')), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  AuthSessionController controller, {
  GroupRepository? groupRepository,
  GroupExpenseRepository? expenseRepository,
  ReceiptScanLauncher? scanReceipt,
  ReceiptParseHandler? parseReceipt,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith((ref) => controller),
        groupRepositoryProvider.overrideWithValue(
          groupRepository ??
              FakeGroupRepository(
                currentUserId: currentUserId,
                groups: const [twoMemberGroup],
                debtSummariesByGroup: const {
                  twoMemberGroupId: currentUserDebtorDebtSummary,
                },
              ),
        ),
        if (expenseRepository != null)
          groupExpenseRepositoryProvider.overrideWithValue(expenseRepository),
      ],
      child: FinanceApp(
        enableAuth: true,
        transactionStream: Stream.value(const <TransactionEntity>[]),
        profileAiAssistantClient: _FakeAssistantClient(),
        scanReceipt: scanReceipt,
        parseReceipt: parseReceipt,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openGroupOcr(WidgetTester tester) async {
  await _openGroupsFromDrawer(tester);
  await tester.tap(find.text('Ev Arkadaşları'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('add_group_expense_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('select_scan_receipt_button')));
  await tester.pumpAndSettle();
}

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

class _TrackingGroupRepository extends FakeGroupRepository {
  _TrackingGroupRepository()
    : super(
        currentUserId: currentUserId,
        groups: const [twoMemberGroup],
        debtSummariesByGroup: const {
          twoMemberGroupId: currentUserDebtorDebtSummary,
        },
      );

  int fastCreateCalls = 0;
  int itemizedCreateCalls = 0;
  int debtSummaryCalls = 0;
  String? lastIdempotencyKey;
  ItemizedExpenseRequest? lastItemizedRequest;

  @override
  Future<GroupExpense> createFastSplit(
    FastSplitExpenseRequest request, {
    required String idempotencyKey,
  }) {
    fastCreateCalls++;
    lastIdempotencyKey = idempotencyKey;
    return super.createFastSplit(request, idempotencyKey: idempotencyKey);
  }

  @override
  Future<GroupExpense> createItemizedSplit(
    ItemizedExpenseRequest request, {
    required String idempotencyKey,
  }) {
    itemizedCreateCalls++;
    lastIdempotencyKey = idempotencyKey;
    lastItemizedRequest = request;
    return super.createItemizedSplit(request, idempotencyKey: idempotencyKey);
  }

  @override
  Future<DebtSummary> getDebtSummary(String groupId) {
    debtSummaryCalls++;
    return super.getDebtSummary(groupId);
  }
}

class _ExpenseApiHarness {
  _ExpenseApiHarness() {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _ExpenseApiAdapter(this);
    _client = ApiClient(
      baseUrl: 'https://example.test',
      tokenStorage: _EmptyTokenStorage(),
      dio: dio,
      refreshDio: Dio(BaseOptions(baseUrl: 'https://example.test')),
    );
    repository = ApiGroupExpenseRepository(_client);
  }

  late final ApiClient _client;
  late final ApiGroupExpenseRepository repository;
  final List<Map<String, Object?>> _expenses = [];
  int createCalls = 0;
  String? lastIdempotencyKey;
  Map<String, Object?>? lastRequestBody;

  ResponseBody handle(RequestOptions options) {
    if (options.method == 'POST' && options.path.endsWith('/expenses')) {
      createCalls++;
      lastIdempotencyKey = options.headers['Idempotency-Key'] as String?;
      lastRequestBody = Map<String, Object?>.from(options.data as Map);
      final split = lastRequestBody!['split'] as Map;
      final template = split['type'] == 'itemized'
          ? itemizedMarketExpense
          : fastSplitTransferExpense;
      final expense = Map<String, Object?>.from(template.toJson())
        ..['title'] = lastRequestBody!['title']
        ..['total_amount_in_minor'] = lastRequestBody!['total_amount_in_minor']
        ..['currency'] = lastRequestBody!['currency'];
      _expenses.add(expense);
      return _jsonResponse({'expense': expense});
    }
    if (options.method == 'GET' && options.path.endsWith('/expenses')) {
      return _jsonResponse({'expenses': _expenses});
    }
    throw StateError(
      'Beklenmeyen API isteği: ${options.method} ${options.path}',
    );
  }

  void close() => _client.close();
}

class _ExpenseApiAdapter implements HttpClientAdapter {
  _ExpenseApiAdapter(this.harness);

  final _ExpenseApiHarness harness;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => harness.handle(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, Object?> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _EmptyTokenStorage implements TokenStorage {
  @override
  Future<void> deleteRefreshToken() async {}

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeRefreshToken(String token) async {}
}

Future<void> _openGroupsFromDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('app_menu_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('drawer_groups_tile')));
  await tester.pumpAndSettle();
}

class _RetryingOcrRouteRepository extends FakeGroupRepository {
  _RetryingOcrRouteRepository()
    : super(currentUserId: currentUserId, groups: const [twoMemberGroup]);

  var getGroupCalls = 0;
  var _shouldFail = true;

  @override
  Future<GroupDetail> getGroup(String groupId) async {
    getGroupCalls += 1;

    if (_shouldFail) {
      _shouldFail = false;
      throw groupsApiErrorException;
    }

    return super.getGroup(groupId);
  }
}

class _NavigationAuthRepository implements AuthRepositoryBase {
  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async => AuthUser(id: currentUserId, email: email, isEmailVerified: true);

  @override
  Future<AuthUser> signInWithGoogle() =>
      login(email: 'google@example.com', password: 'unused');

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

class _FakeAssistantClient implements AiAssistantAccessClient {
  @override
  Future<AiAssistantStatus> fetchStatus() async => const AiAssistantStatus(
    enabled: true,
    requiredConsentVersion: 'v1',
    consentGranted: false,
  );

  @override
  Future<AiAssistantStatus> updateConsent({
    required bool accepted,
    required String consentVersion,
  }) async => AiAssistantStatus(
    enabled: true,
    requiredConsentVersion: consentVersion,
    consentGranted: accepted,
  );
}
