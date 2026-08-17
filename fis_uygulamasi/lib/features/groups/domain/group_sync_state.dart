enum GroupSyncStatus { idle, pending, syncing, success, failed, conflict }

/// Grup offline kuyruğunun Riverpod üzerinden gözlemlenen durumu.
class GroupSyncState {
  const GroupSyncState({
    this.status = GroupSyncStatus.idle,
    this.pendingCount = 0,
    this.completedCount = 0,
    this.totalCount = 0,
    this.failedCount = 0,
    this.conflictCount = 0,
    this.pulledCount = 0,
    this.errorMessage,
  });

  final GroupSyncStatus status;
  final int pendingCount;
  final int completedCount;
  final int totalCount;
  final int failedCount;
  final int conflictCount;
  final int pulledCount;
  final String? errorMessage;

  double? get progress => totalCount == 0 ? null : completedCount / totalCount;
  bool get isRunning =>
      status == GroupSyncStatus.pending || status == GroupSyncStatus.syncing;
}
