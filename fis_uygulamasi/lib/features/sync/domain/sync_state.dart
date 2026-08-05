enum SyncStatus { idle, syncing, success, conflict, error }

class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.completedCount = 0,
    this.totalCount = 0,
    this.conflictCount = 0,
    this.errorMessage,
  });

  final SyncStatus status;
  final int completedCount;
  final int totalCount;
  final int conflictCount;
  final String? errorMessage;

  double? get progress => totalCount == 0 ? null : completedCount / totalCount;
}
