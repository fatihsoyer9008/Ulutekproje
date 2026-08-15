import 'dart:math';

import 'package:app_main/core/network/request_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newUuidV4 RFC 4122 v4 biçiminde benzersiz anahtarlar üretir', () {
    final first = newUuidV4(random: Random(1));
    final second = newUuidV4(random: Random(2));
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(first, matches(uuidV4));
    expect(second, matches(uuidV4));
    expect(second, isNot(first));
  });
}
