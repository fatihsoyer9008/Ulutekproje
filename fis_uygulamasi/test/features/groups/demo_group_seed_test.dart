import 'package:app_main/features/groups/data/demo_group_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime demo seed exposes two and four member groups', () {
    const currentUserId = '90000000-0000-4000-8000-000000000001';
    final seed = createDemoGroupSeed(
      currentUserId: currentUserId,
      currentUserDisplayName: 'Fatih',
    );

    expect(seed.groups, hasLength(2));
    expect(seed.groups.map((group) => group.memberCount), containsAll([2, 4]));
    expect(
      seed.groups.every(
        (group) =>
            group.members.any((member) => member.userId == currentUserId),
      ),
      isTrue,
    );
    expect(seed.expensesByGroup[demoHomeGroupId], hasLength(1));
    expect(seed.debtSummariesByGroup[demoHomeGroupId], isNotNull);
  });
}
