import 'dart:async';

import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/src/app/finance_app.dart';
import 'package:app_main/src/app/finance_home.dart';
import 'package:app_main/src/screens/expense_screen.dart';
import 'package:app_main/src/screens/statistics_screen.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('dashboard and navigation render', (tester) async {
    final first = _transaction(
      amountInMinor: 250000,
      transactionType: TransactionType.income,
      merchantName: 'Maaş',
    );
    final second = _transaction(amountInMinor: 50000);
    await tester.pumpWidget(
      FinanceApp(transactionStream: Stream.value([first, second])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kontrol sende.'), findsOneWidget);
    expect(find.text('₺2.000,00'), findsOneWidget);

    expect(find.byType(StatisticsScreen, skipOffstage: false), findsNothing);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(StatisticsScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('Genel İstatistik'), findsOneWidget);
    expect(find.text('AI Asistan'), findsOneWidget);
    expect(find.text('Akıllı Özet'), findsNothing);

    await tester.tap(find.text('AI Asistan'));
    await tester.pumpAndSettle();

    expect(find.text('Akıllı Harcama Özeti'), findsOneWidget);
  });

  testWidgets('drawer and synchronization status use live application data', (
    tester,
  ) async {
    final authController = AuthSessionController(
      _AlwaysAuthenticatedRepository(),
    );
    await authController.login('user@example.com', 'password');
    var profilePageOpened = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith((ref) => authController),
        ],
        child: MaterialApp(
          home: FinanceHome(
            transactions: const [],
            greetingName: 'Ayşe',
            enableAccountMenu: true,
            pendingOfflineTaskCount: 2,
            onProfilePressed: () => profilePageOpened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Günaydın, Ayşe'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_menu_button')));
    await tester.pumpAndSettle();
    expect(find.text('user@example.com'), findsWidgets);
    expect(find.text('Tema Değiştir'), findsOneWidget);
    expect(find.text('Çıkış Yap'), findsNothing);

    await tester.tap(find.byKey(const Key('drawer_profile_tile')));
    await tester.pumpAndSettle();
    expect(profilePageOpened, isTrue);

    await tester.tap(find.byKey(const Key('notifications_button')));
    await tester.pumpAndSettle();
    expect(
      find.text('2 adet fiş senkronize edilmeyi bekliyor.'),
      findsOneWidget,
    );
  });

  testWidgets('transaction stream is recreated after logout and login', (
    tester,
  ) async {
    final authController = AuthSessionController(
      _AlwaysAuthenticatedRepository(),
    );
    await authController.login('user@example.com', 'password');
    var streamCreationCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith((ref) => authController),
        ],
        child: FinanceApp(
          enableAuth: true,
          transactionStreamFactory: () {
            streamCreationCount++;
            return Stream.value(const <TransactionEntity>[]);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(streamCreationCount, 1);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('app_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer_profile_tile')));
    await tester.pumpAndSettle();
    final logoutButton = find.byKey(const Key('logout_button'));
    await tester.scrollUntilVisible(
      logoutButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome_login_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(streamCreationCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest can open the login page from profile settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final authController = AuthSessionController(
      _AlwaysAuthenticatedRepository(),
    );
    authController.continueAsGuest();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith((ref) => authController),
        ],
        child: FinanceApp(
          enableAuth: true,
          transactionStream: Stream.value(const <TransactionEntity>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('app_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer_profile_tile')));
    await tester.pumpAndSettle();

    final loginButton = find.byKey(const Key('guest_login_button'));
    await tester.pump();
    await tester.ensureVisible(loginButton);
    await tester.pumpAndSettle();
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard expense action waits for the scanner choice', (
    tester,
  ) async {
    var scanLaunchCount = 0;

    await tester.pumpWidget(
      FinanceApp(
        transactionStream: Stream.value(const <TransactionEntity>[]),
        scanReceipt: (_) async {
          scanLaunchCount++;
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gider Gir'));
    await tester.pumpAndSettle();

    expect(scanLaunchCount, 0);
    expect(find.byType(ExpenseScreen), findsOneWidget);
    expect(find.byKey(const Key('ocr_camera_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ocr_camera_button')));
    await tester.pumpAndSettle();

    expect(scanLaunchCount, 1);
  });

  testWidgets('returning from the camera keeps the expense screen open', (
    tester,
  ) async {
    await tester.pumpWidget(
      FinanceApp(
        transactionStream: Stream.value(const <TransactionEntity>[]),
        scanReceipt: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gider Gir'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseScreen), findsOneWidget);
    expect(find.byKey(const Key('ocr_camera_button')), findsOneWidget);
    expect(find.text('Abonelikler'), findsOneWidget);
  });

  testWidgets('balance updates when transaction stream emits new data', (
    tester,
  ) async {
    final transactions = StreamController<List<TransactionEntity>>();
    addTearDown(transactions.close);
    final first = _transaction(amountInMinor: 10000);
    final second = _transaction(
      amountInMinor: 2500,
      transactionType: TransactionType.income,
      merchantName: 'Ek gelir',
    );

    await tester.pumpWidget(FinanceApp(transactionStream: transactions.stream));

    transactions.add([first]);
    await tester.pumpAndSettle();
    expect(find.text('-₺100,00'), findsOneWidget);

    transactions.add([first, second]);
    await tester.pumpAndSettle();
    expect(find.text('-₺75,00'), findsOneWidget);
    expect(find.text('-₺100,00'), findsNothing);
  });

  testWidgets('saving a manual expense updates the dashboard balance', (
    tester,
  ) async {
    final transactions = StreamController<List<TransactionEntity>>();
    addTearDown(transactions.close);
    final savedTransactions = <TransactionEntity>[];

    await tester.pumpWidget(
      FinanceApp(
        transactionStream: transactions.stream,
        scanReceipt: (_) async => null,
        saveTransaction: (transaction) async {
          savedTransactions.add(transaction);
          transactions.add(List.of(savedTransactions));
        },
      ),
    );
    transactions.add([]);
    await tester.pump();

    await tester.tap(find.text('Gider Gir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual_entry_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('institution_name_field')),
      'Market',
    );
    await _selectCategory(tester, 'Market');
    await tester.enterText(find.byKey(const Key('amount_field')), '100,00');
    await tester.tap(find.byKey(const Key('confirm_draft_button')));
    await tester.pumpAndSettle();

    expect(savedTransactions, hasLength(1));
    expect(savedTransactions.single.amountInMinor, 10000);
    expect(savedTransactions.single.source, TransactionSource.manual);
    expect(savedTransactions.single.transactionType, TransactionType.expense);
    expect(find.byKey(const Key('total_balance')), findsOneWidget);
    expect(find.text('-₺100,00'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.receipt_long_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Market'), findsOneWidget);
    expect(find.text('-₺100,00'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.insights_outlined),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Market'),
      50.0,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Market'), findsOneWidget);
    expect(find.text('₺100,00'), findsAtLeastNWidgets(1));
  });

  testWidgets('saving income increases balance and appears in movements', (
    tester,
  ) async {
    final transactions = StreamController<List<TransactionEntity>>();
    addTearDown(transactions.close);
    final savedTransactions = <TransactionEntity>[];

    await tester.pumpWidget(
      FinanceApp(
        transactionStream: transactions.stream,
        saveTransaction: (transaction) async {
          savedTransactions.add(transaction);
          transactions.add(List.of(savedTransactions));
        },
      ),
    );
    transactions.add([]);
    await tester.pump();

    await tester.tap(find.text('Gelir Gir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_income_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('income_source_field')),
      'Maaş',
    );
    await tester.pump();
    expect(find.text('Gelir kategorisi: Maaş'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('income_amount_field')),
      '1.000,00',
    );
    await tester.tap(find.byKey(const Key('save_income_button')));
    await tester.pumpAndSettle();

    expect(savedTransactions, hasLength(1));
    expect(savedTransactions.single.amountInMinor, 100000);
    expect(savedTransactions.single.transactionType, TransactionType.income);
    expect(savedTransactions.single.categoryName, 'Maaş');
    expect(find.text('₺1.000,00'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.receipt_long_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Maaş'), findsOneWidget);
    expect(find.text('+₺1.000,00'), findsOneWidget);
  });
}

Future<void> _selectCategory(WidgetTester tester, String category) async {
  await tester.tap(find.byKey(const Key('category_field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(category).last);
  await tester.pumpAndSettle();
}

TransactionEntity _transaction({
  required int amountInMinor,
  TransactionType transactionType = TransactionType.expense,
  TransactionCategory category = TransactionCategory.market,
  String merchantName = 'Market',
  DateTime? date,
}) {
  final effectiveDate = date ?? DateTime.now();
  return TransactionEntity()
    ..transactionType = transactionType
    ..amountInMinor = amountInMinor
    ..category = category
    ..date = effectiveDate
    ..merchantName = merchantName
    ..source = TransactionSource.manual
    ..createdAt = effectiveDate
    ..updatedAt = effectiveDate;
}

class _AlwaysAuthenticatedRepository implements AuthRepositoryBase {
  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async => AuthUser(id: 'user-id', email: email, isEmailVerified: true);

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
  Future<AuthUser> signInWithGoogle() =>
      login(email: 'user@example.com', password: 'password');

  @override
  Future<String> verifyEmail(String token) async => 'Verified';
}
