import '../domain/group_activity_models.dart';

class GroupActivityPage {
  const GroupActivityPage({required this.items, required this.nextCursor});

  final List<GroupActivityEntry> items;
  final String? nextCursor;
}

abstract interface class GroupActivityRepository {
  Future<GroupActivityPage> listActivity({int limit = 50, String? before});
}

/// Loads the complete feed while protecting the client from a malformed API
/// that repeats the same cursor forever.
Future<List<GroupActivityEntry>> loadAllGroupActivity(
  GroupActivityRepository repository,
) async {
  final itemsById = <String, GroupActivityEntry>{};
  final visitedCursors = <String>{};
  String? cursor;

  do {
    final page = await repository.listActivity(before: cursor);
    for (final item in page.items) {
      itemsById.putIfAbsent(item.id, () => item);
    }
    final nextCursor = page.nextCursor;
    if (nextCursor != null && !visitedCursors.add(nextCursor)) {
      throw const FormatException('Activity cursor repeated.');
    }
    cursor = nextCursor;
  } while (cursor != null);

  final items = itemsById.values.toList(growable: false)
    ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
  return List<GroupActivityEntry>.unmodifiable(items);
}
