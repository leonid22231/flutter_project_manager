import 'dart:io' show Platform;

class BuildArchiveEntry {
  const BuildArchiveEntry({
    required this.id,
    required this.createdAt,
    required this.projectVersion,
    required this.configName,
    required this.command,
    required this.platform,
    required this.archivePath,
    required this.sourceOutputPath,
    required this.artifactFiles,
    this.exitCode = 0,
  });

  final String id;
  final DateTime createdAt;
  final String projectVersion;
  final String configName;
  final String command;
  final String platform;
  final String archivePath;
  final String sourceOutputPath;
  final List<String> artifactFiles;
  final int exitCode;

  String get artifactsDirectory =>
      '$archivePath${Platform.pathSeparator}artifacts';

  int get artifactCount => artifactFiles.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'projectVersion': projectVersion,
        'configName': configName,
        'command': command,
        'platform': platform,
        'archivePath': archivePath,
        'sourceOutputPath': sourceOutputPath,
        'artifactFiles': artifactFiles,
        'exitCode': exitCode,
      };

  factory BuildArchiveEntry.fromJson(Map<String, dynamic> json) {
    return BuildArchiveEntry(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      projectVersion: json['projectVersion'] as String? ?? 'unknown',
      configName: json['configName'] as String? ?? '',
      command: json['command'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      archivePath: json['archivePath'] as String,
      sourceOutputPath: json['sourceOutputPath'] as String? ?? '',
      artifactFiles: (json['artifactFiles'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      exitCode: json['exitCode'] as int? ?? 0,
    );
  }
}
