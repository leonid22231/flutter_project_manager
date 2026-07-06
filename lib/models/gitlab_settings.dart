class GitLabSettings {
  const GitLabSettings({
    this.enabled = false,
    this.baseUrl = 'https://gitlab.com',
    this.personalAccessToken = '',
    this.useEnvironmentToken = true,
  });

  static const docsUrl = 'https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html';
  static const defaultBaseUrl = 'https://gitlab.com';

  final bool enabled;
  final String baseUrl;
  final String personalAccessToken;
  final bool useEnvironmentToken;

  String get normalizedBaseUrl {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return defaultBaseUrl;
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  GitLabSettings copyWith({
    bool? enabled,
    String? baseUrl,
    String? personalAccessToken,
    bool? useEnvironmentToken,
  }) {
    return GitLabSettings(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      personalAccessToken: personalAccessToken ?? this.personalAccessToken,
      useEnvironmentToken: useEnvironmentToken ?? this.useEnvironmentToken,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'baseUrl': baseUrl,
        'personalAccessToken': personalAccessToken,
        'useEnvironmentToken': useEnvironmentToken,
      };

  factory GitLabSettings.fromJson(Map<String, dynamic> json) {
    return GitLabSettings(
      enabled: json['enabled'] as bool? ?? false,
      baseUrl: json['baseUrl'] as String? ?? defaultBaseUrl,
      personalAccessToken: json['personalAccessToken'] as String? ?? '',
      useEnvironmentToken: json['useEnvironmentToken'] as bool? ?? true,
    );
  }
}
