import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/group_repository.dart';
import '../../domain/group_models.dart';

class GroupListState {
  const GroupListState({
    this.groups = const AsyncLoading<List<Group>>(),
    this.isSubmitting = false,
  });

  final AsyncValue<List<Group>> groups;
  final bool isSubmitting;

  GroupListState copyWith({
    AsyncValue<List<Group>>? groups,
    bool? isSubmitting,
  }) {
    return GroupListState(
      groups: groups ?? this.groups,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class GroupListController extends StateNotifier<GroupListState> {
  GroupListController(this._repository) : super(const GroupListState()) {
    load();
  }

  final GroupRepository _repository;

  Future<void> load() async {
    state = state.copyWith(groups: const AsyncLoading<List<Group>>());
    try {
      final response = await _repository.listGroups();
      state = state.copyWith(groups: AsyncData(response.groups));
    } catch (error, stackTrace) {
      state = state.copyWith(
        groups: AsyncError<List<Group>>(error, stackTrace),
      );
    }
  }

  Future<GroupDetail?> createGroup({
    required String name,
    required String description,
    required String currency,
  }) async {
    if (state.isSubmitting) return null;
    state = state.copyWith(isSubmitting: true);
    try {
      final group = await _repository.createGroup(
        name: name,
        description: description.trim().isEmpty ? null : description.trim(),
        currency: currency,
      );
      final current = state.groups.asData?.value ?? const <Group>[];
      state = GroupListState(groups: AsyncData(<Group>[...current, group]));
      return group;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}

final groupListControllerProvider =
    StateNotifierProvider<GroupListController, GroupListState>((ref) {
      return GroupListController(ref.watch(groupRepositoryProvider));
    });
