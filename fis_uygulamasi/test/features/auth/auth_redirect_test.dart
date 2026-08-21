import 'package:app_main/features/auth/presentation/routing/auth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('safeGroupsRedirect', () {
    test('accepts only the protected group surface routes', () {
      expect(safeGroupsRedirect('/groups'), '/groups');
      expect(safeGroupsRedirect('/friends'), '/friends');
      expect(safeGroupsRedirect('/activity'), '/activity');
      expect(
        safeGroupsRedirect('/groups/550e8400-e29b-41d4-a716-446655440000'),
        '/groups/550e8400-e29b-41d4-a716-446655440000',
      );
    });

    test('rejects external and unrelated redirect values', () {
      expect(safeGroupsRedirect('https://example.com/groups'), isNull);
      expect(safeGroupsRedirect('//example.com/groups'), isNull);
      expect(safeGroupsRedirect('/home'), isNull);
      expect(safeGroupsRedirect('/groups/../home'), isNull);
      expect(safeGroupsRedirect('/groups?next=/home'), isNull);
    });
  });

  test('groupsLoginLocation safely encodes the destination', () {
    final location = Uri.parse(groupsLoginLocation('/groups/group-1'));

    expect(location.path, '/login');
    expect(location.queryParameters['redirect'], '/groups/group-1');
  });
}
