import '../domain/group_activity_models.dart';
import 'demo_group_activity_seed.dart';
import 'group_activity_repository.dart';

class DemoGroupActivityRepository implements GroupActivityRepository {
  DemoGroupActivityRepository({DateTime? now})
    : _items = createDemoGroupActivitySeed(now: now);

  final List<GroupActivityEntry> _items;

  @override
  Future<GroupActivityPage> listActivity({
    int limit = 50,
    String? before,
  }) async {
    if (before != null) {
      return const GroupActivityPage(items: [], nextCursor: null);
    }
    return GroupActivityPage(
      items: List<GroupActivityEntry>.unmodifiable(_items.take(limit)),
      nextCursor: null,
    );
  }
}
