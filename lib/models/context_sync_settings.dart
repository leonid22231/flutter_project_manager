class ContextSyncSettings {
  const ContextSyncSettings({
    this.enabled = false,
    this.repoUrl = '',
    this.syncIntervalMinutes = 5,
  });

  final bool enabled;
  final String repoUrl;
  final int syncIntervalMinutes;

  bool get hasRepoUrl => repoUrl.trim().isNotEmpty;

  bool get isActive => enabled && hasRepoUrl;

  Duration get syncInterval {
    final minutes = syncIntervalMinutes.clamp(1, 120);
    return Duration(minutes: minutes);
  }

  ContextSyncSettings copyWith({
    bool? enabled,
    String? repoUrl,
    int? syncIntervalMinutes,
  }) {
    return ContextSyncSettings(
      enabled: enabled ?? this.enabled,
      repoUrl: repoUrl ?? this.repoUrl,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'repoUrl': repoUrl,
        'syncIntervalMinutes': syncIntervalMinutes,
      };

  factory ContextSyncSettings.fromJson(Map<String, dynamic> json) {
    return ContextSyncSettings(
      enabled: json['enabled'] as bool? ?? false,
      repoUrl: json['repoUrl'] as String? ?? '',
      syncIntervalMinutes: json['syncIntervalMinutes'] as int? ?? 5,
    );
  }
}
