import 'dart:async';

import 'package:app_main/src/app/finance_app.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('suggested question streams an answer and can be cancelled', (
    tester,
  ) async {
    final response = StreamController<String>();
    var wasCancelled = false;
    response.onCancel = () => wasCancelled = true;
    addTearDown(response.close);

    await tester.pumpWidget(
      FinanceApp(
        transactionStream: Stream.value(const <TransactionEntity>[]),
        aiAssistantMessageStream: (_) => response.stream,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kişisel Asistanın'));
    await tester.pumpAndSettle();

    expect(find.text('Hazır sorular'), findsOneWidget);
    expect(find.text('Bu ay en çok neye harcadım?'), findsOneWidget);

    await tester.tap(find.text('Bu ay en çok neye harcadım?'));
    await tester.pump();
    expect(find.byKey(const Key('ai_stop_button')), findsOneWidget);

    response.add('Market harcamaların ');
    await tester.pump();
    expect(find.text('Market harcamaların '), findsOneWidget);

    final stopButton = tester.widget<IconButton>(
      find.byKey(const Key('ai_stop_button')),
    );
    stopButton.onPressed!();
    await tester.pumpAndSettle();

    expect(wasCancelled, isTrue);
    expect(find.byKey(const Key('ai_send_button')), findsOneWidget);
  });

  testWidgets('a typed prompt is sent to the streaming backend contract', (
    tester,
  ) async {
    String? receivedPrompt;

    await tester.pumpWidget(
      FinanceApp(
        transactionStream: Stream.value(const <TransactionEntity>[]),
        aiAssistantMessageStream: (prompt) {
          receivedPrompt = prompt;
          return Stream.value('Yanıt tamamlandı.');
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kişisel Asistanın'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai_message_field')),
      '  Bütçemi incele  ',
    );
    await tester.tap(find.byKey(const Key('ai_send_button')));
    await tester.pumpAndSettle();

    expect(receivedPrompt, 'Bütçemi incele');
    expect(find.text('Yanıt tamamlandı.'), findsOneWidget);
  });
  testWidgets('investment disclaimer appears above the conversation', (
    tester,
  ) async {
    await tester.pumpWidget(
      FinanceApp(transactionStream: Stream.value(const <TransactionEntity>[])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kişisel Asistanın'));
    await tester.pumpAndSettle();

    final disclaimer = find.byKey(const Key('ai_investment_disclaimer'));
    final messageField = find.byKey(const Key('ai_message_field'));

    expect(disclaimer, findsOneWidget);
    expect(find.text('Bu bir yatırım tavsiyesi değildir.'), findsOneWidget);
    expect(
      tester.getTopLeft(disclaimer).dy,
      lessThan(tester.getTopLeft(messageField).dy),
    );
  });
}
