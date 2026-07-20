enum CursorCliMode {
  /// Full agent with write/shell tools. CLI default when `--mode` is omitted.
  agent,
  plan,
  ask;

  String get cliValue => name;

  /// Cursor CLI `--mode` only accepts `plan` | `ask`. Agent = omit the flag.
  List<String> get cliModeArgs => switch (this) {
        CursorCliMode.ask => const ['--mode', 'ask'],
        CursorCliMode.plan => const ['--mode', 'plan'],
        CursorCliMode.agent => const [],
      };

  static CursorCliMode fromString(String? value) {
    return CursorCliMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => CursorCliMode.agent,
    );
  }
}

class CursorCliSettings {
  const CursorCliSettings({
    this.enabled = false,
    this.cliCommand = 'agent',
    this.apiKey = '',
    this.useEnvironmentApiKey = true,
    this.defaultModel = 'composer-2.5',
    this.defaultMode = CursorCliMode.agent,
  });

  static const presetModels = [
    'composer-2.5',
    'composer-2.5-fast',
    'gpt-5.3-codex-high-fast',
    'gpt-5.5-medium',
  ];

  static const installDocsUrl = 'https://cursor.com/docs/cli/installation';
  static const overviewUrl = 'https://cursor.com/cli';
  static const authDocsUrl = 'https://cursor.com/docs/cli/reference/authentication';
  static const parametersDocsUrl = 'https://cursor.com/docs/cli/reference/parameters';

  final bool enabled;
  final String cliCommand;
  final String apiKey;
  final bool useEnvironmentApiKey;
  final String defaultModel;
  final CursorCliMode defaultMode;

  bool get usesPresetModel => presetModels.contains(defaultModel);

  CursorCliSettings copyWith({
    bool? enabled,
    String? cliCommand,
    String? apiKey,
    bool? useEnvironmentApiKey,
    String? defaultModel,
    CursorCliMode? defaultMode,
  }) {
    return CursorCliSettings(
      enabled: enabled ?? this.enabled,
      cliCommand: cliCommand ?? this.cliCommand,
      apiKey: apiKey ?? this.apiKey,
      useEnvironmentApiKey:
          useEnvironmentApiKey ?? this.useEnvironmentApiKey,
      defaultModel: defaultModel ?? this.defaultModel,
      defaultMode: defaultMode ?? this.defaultMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'cliCommand': cliCommand,
        'apiKey': apiKey,
        'useEnvironmentApiKey': useEnvironmentApiKey,
        'defaultModel': defaultModel,
        'defaultMode': defaultMode.name,
      };

  factory CursorCliSettings.fromJson(Map<String, dynamic> json) {
    return CursorCliSettings(
      enabled: json['enabled'] as bool? ?? false,
      cliCommand: json['cliCommand'] as String? ?? 'agent',
      apiKey: json['apiKey'] as String? ?? '',
      useEnvironmentApiKey: json['useEnvironmentApiKey'] as bool? ?? true,
      defaultModel: json['defaultModel'] as String? ?? 'composer-2.5',
      defaultMode: CursorCliMode.fromString(json['defaultMode'] as String?),
    );
  }
}
