enum SyncStatus { idle, syncing, success, error }

class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.completedCount = 0,
    this.totalCount = 0,
    this.errorMessage,
  });

  final SyncStatus status;
  final int completedCount;
  final int totalCount;
  final String? errorMessage;

  double? get progress => totalCount == 0 ? null : completedCount / totalCount;
}
