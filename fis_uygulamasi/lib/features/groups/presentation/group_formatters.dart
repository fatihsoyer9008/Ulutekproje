import '../../transaction_draft/model/turkish_money.dart';

String formatGroupMoney(int amountInMinor) =>
    '₺${formatMinorAsTurkishLira(amountInMinor)}';

String formatNetPosition(int amountInMinor) {
  if (amountInMinor > 0) {
    return '${formatGroupMoney(amountInMinor)} alacağın var';
  }
  if (amountInMinor < 0) {
    return '${formatGroupMoney(-amountInMinor)} borcun var';
  }
  return 'Borç veya alacak yok';
}

String formatGroupDate(String isoDate) {
  final date = DateTime.tryParse(isoDate)?.toLocal();
  if (date == null) return 'Tarih bilinmiyor';
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}
