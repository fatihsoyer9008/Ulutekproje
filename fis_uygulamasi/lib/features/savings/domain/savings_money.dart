/// Kullanıcı tarafından girilen TL değerini kuruşa dönüştürür.
///
/// Türkçe biçimde virgül, uluslararası biçimde nokta ondalık ayırıcı olabilir.
/// Binlik ayırıcı yalnızca karşı ayırıcıyla birlikte veya üçlü gruplar halinde
/// kullanıldığında kabul edilir.
int? parseSavingsAmountInMinor(String input) {
  final value = input.trim().replaceAll(RegExp(r'[₺\s]'), '');
  if (value.isEmpty || !RegExp(r'^\d+(?:[.,]\d+)*$').hasMatch(value)) {
    return null;
  }

  final comma = value.lastIndexOf(',');
  final dot = value.lastIndexOf('.');
  String whole;
  String fraction = '';

  if (comma >= 0 && dot >= 0) {
    final decimalIndex = comma > dot ? comma : dot;
    whole = value.substring(0, decimalIndex).replaceAll(RegExp(r'[.,]'), '');
    fraction = value.substring(decimalIndex + 1);
  } else {
    final separator = comma >= 0
        ? ','
        : dot >= 0
        ? '.'
        : null;
    if (separator == null) {
      whole = value;
    } else {
      final pieces = value.split(separator);
      if (pieces.length == 2 && pieces.last.length <= 2) {
        whole = pieces.first;
        fraction = pieces.last;
      } else if (separator == '.' &&
          pieces.length > 1 &&
          pieces.skip(1).every((piece) => piece.length == 3)) {
        whole = pieces.join();
      } else {
        return null;
      }
    }
  }

  if (fraction.length > 2 || whole.isEmpty) return null;
  final major = int.tryParse(whole);
  final minor = fraction.isEmpty ? 0 : int.tryParse(fraction.padRight(2, '0'));
  if (major == null || minor == null) return null;
  return major * 100 + minor;
}
