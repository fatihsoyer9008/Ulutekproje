import 'package:app_main/src/screens/income_entry_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gelir kaynağından kategori belirler', () {
    expect(inferIncomeCategory('Ağustos maaş ödemesi'), 'Maaş');
    expect(inferIncomeCategory('Freelance mobil proje'), 'Freelance');
    expect(inferIncomeCategory('Yıllık performans primi'), 'Prim');
    expect(inferIncomeCategory('Hisse temettü ödemesi'), 'Yatırım Geliri');
    expect(inferIncomeCategory('İkinci el satış'), 'Satış Geliri');
    expect(inferIncomeCategory('Arkadaşımdan geldi'), 'Diğer Gelir');
  });
}
