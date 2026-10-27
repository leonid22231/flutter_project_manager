class WindowsLaunchSettings {
  const WindowsLaunchSettings({
    this.launchAtLogon = false,
    this.exePath = '',
  });

  final bool launchAtLogon;

  /// Empty means the exe next to the current process.
  final String exePath;

  WindowsLaunchSettings copyWith({
    bool? launchAtLogon,
    String? exePath,
  }) {
    return WindowsLaunchSettings(
      launchAtLogon: launchAtLogon ?? this.launchAtLogon,
      exePath: exePath ?? this.exePath,
    );
  }

  /// Uses [fallbackExePath] when [exePath] was not stored yet.
  WindowsLaunchSettings withDefaultExe(String fallbackExePath) {
    if (exePath.trim().isNotEmpty) return this;
    final fallback = fallbackExePath.trim();
    if (fallback.isEmpty) return this;
    return copyWith(exePath: fallback);
  }

  Map<String, dynamic> toJson() => {
        'launchAtLogon': launchAtLogon,
        'exePath': exePath,
      };

  factory WindowsLaunchSettings.fromJson(Map<String, dynamic> json) {
    return WindowsLaunchSettings(
      launchAtLogon: json['launchAtLogon'] as bool? ?? false,
      exePath: json['exePath'] as String? ?? '',
    );
  }
}
