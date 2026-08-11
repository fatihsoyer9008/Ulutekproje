import 'package:app_main/features/groups/data/group_mock_data.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_main/features/groups/data/group_mock_data.dart';

const groupsLoading = AsyncLoading<GroupsResponse>();

final groupsApiError = AsyncError<GroupsResponse>(
  groupsApiErrorException,
  StackTrace.empty,
);
