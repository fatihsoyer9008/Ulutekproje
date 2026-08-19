import 'package:app_main/core/errors/user_facing_error.dart';
import 'package:flutter_test/flutter_test.dart';

class _SafeFailure implements UserFacingException {
  const _SafeFailure(this.userMessage);

  @override
  final String userMessage;
}

void main() {
  test('bilinmeyen exception metnini kullanıcıya taşımaz', () {
    final message = userFacingErrorMessage(
      Exception('postgresql://admin:secret@internal-db:5432/app'),
      fallbackMessage: 'İşlem tamamlanamadı.',
    );

    expect(message, 'İşlem tamamlanamadı.');
    expect(message, isNot(contains('postgresql')));
    expect(message, isNot(contains('secret')));
  });

  test('yalnızca kullanıcı için hazırlanmış exception metnini gösterir', () {
    expect(
      userFacingErrorMessage(
        const _SafeFailure('Bağlantınızı kontrol edip tekrar deneyin.'),
        fallbackMessage: 'İşlem tamamlanamadı.',
      ),
      'Bağlantınızı kontrol edip tekrar deneyin.',
    );
  });
}
