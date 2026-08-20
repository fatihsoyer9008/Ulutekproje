/// Yalnızca kullanıcıya gösterilmek üzere hazırlanmış hata türleri uygular.
abstract interface class UserFacingException implements Exception {
  String get userMessage;
}

/// Bilinmeyen exception metinlerinin arayüze sızmasını engeller.
String userFacingErrorMessage(Object error, {required String fallbackMessage}) {
  if (error is UserFacingException) {
    final message = error.userMessage.trim();
    if (message.isNotEmpty) return message;
  }
  return fallbackMessage;
}
