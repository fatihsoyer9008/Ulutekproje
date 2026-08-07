import 'package:app_main/features/savings/domain/savings_money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TL girişlerini kuruşa güvenli dönüştürür', () {
    expect(parseSavingsAmountInMinor('100,50'), 10050);
    expect(parseSavingsAmountInMinor('100.50'), 10050);
    expect(parseSavingsAmountInMinor('1.234,56'), 123456);
    expect(parseSavingsAmountInMinor('1,234.56'), 123456);
    expect(parseSavingsAmountInMinor('1.234'), 123400);
  });

  test('belirsiz veya geçersiz ondalıkları reddeder', () {
    expect(parseSavingsAmountInMinor('12,345'), isNull);
    expect(parseSavingsAmountInMinor('10,1234'), isNull);
    expect(parseSavingsAmountInMinor('1,2,3'), isNull);
    expect(parseSavingsAmountInMinor('-10'), isNull);
    expect(parseSavingsAmountInMinor('abc'), isNull);
  });
}
