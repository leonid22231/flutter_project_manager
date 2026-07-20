enum ContextSyncPhase {
  idle,
  syncing,
  error,
}

class ContextSyncStatus {
  const ContextSyncStatus({
    this.phase = ContextSyncPhase.idle,
    this.lastSyncedAt,
    this.error,
    this.message,
    this.contextId,
  });

  static const idle = ContextSyncStatus();

  final ContextSyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? error;
  final String? message;
  final String? contextId;

  bool get isSyncing => phase == ContextSyncPhase.syncing;
  bool get hasError => phase == ContextSyncPhase.error;

  ContextSyncStatus copyWith({
    ContextSyncPhase? phase,
    DateTime? lastSyncedAt,
    String? error,
    String? message,
    String? contextId,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return ContextSyncStatus(
      phase: phase ?? this.phase,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
      contextId: contextId ?? this.contextId,
    );
  }
}
