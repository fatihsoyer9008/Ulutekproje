/// Produces a case-insensitive, ASCII-like representation for Turkish search.
///
/// This deliberately maps Turkish letters before lower-casing so that `I` and
/// `İ` are handled consistently across platforms and locales.
String normalizeTurkishText(String value) {
  const replacements = <String, String>{
    'I': 'i',
    'İ': 'i',
    'ı': 'i',
    'Ş': 's',
    'ş': 's',
    'Ğ': 'g',
    'ğ': 'g',
    'Ü': 'u',
    'ü': 'u',
    'Ö': 'o',
    'ö': 'o',
    'Ç': 'c',
    'ç': 'c',
  };

  final buffer = StringBuffer();
  for (final rune in value.trim().runes) {
    final character = String.fromCharCode(rune);
    buffer.write(replacements[character] ?? character.toLowerCase());
  }
  return buffer.toString();
}
