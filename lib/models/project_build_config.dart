import 'package:project_manager/models/build_config_source.dart';
import 'package:project_manager/models/build_run_mode.dart';

class ProjectBuildConfig {
  const ProjectBuildConfig({
    required this.id,
    required this.name,
    required this.source,
    required this.mode,
    this.type,
    this.program,
    this.deviceId,
    this.args = const [],
    this.toolArgs = const [],
    this.additionalArgs = const [],
    this.preLaunchTask,
    this.cwd,
    this.executable,
    this.commandArgs = const [],
    this.shellCommand,
    this.sourceFile,
    this.childConfigurationNames = const [],
    this.taskGroup,
    this.isBackground = false,
  });

  final String id;
  final String name;
  final BuildConfigSource source;
  final BuildRunMode mode;
  final String? type;
  final String? program;
  final String? deviceId;
  final List<String> args;
  final List<String> toolArgs;
  final List<String> additionalArgs;
  final String? preLaunchTask;
  final String? cwd;
  final String? executable;
  final List<String> commandArgs;
  final String? shellCommand;
  final String? sourceFile;
  final List<String> childConfigurationNames;
  final String? taskGroup;
  final bool isBackground;

  String get displayCommand {
    if (shellCommand != null && shellCommand!.trim().isNotEmpty) {
      return shellCommand!.trim();
    }
    final parts = <String>[
      if (executable != null && executable!.isNotEmpty) executable!,
      ...commandArgs,
    ];
    return parts.join(' ');
  }

  bool get canRunDirectly =>
      source == BuildConfigSource.gitlabCi ||
      shellCommand != null ||
      (executable != null &&
          executable!.isNotEmpty &&
          commandArgs.isNotEmpty);

  bool get isGitLabCiJob => source == BuildConfigSource.gitlabCi;
}

class ProjectBuildScanResult {
  const ProjectBuildScanResult({
    required this.configs,
    required this.tasksJsonExists,
    required this.usingDefaultConfigs,
    this.tasksJsonPath,
    this.resolvedPlatforms = const [],
    this.errorMessage,
  });

  final List<ProjectBuildConfig> configs;
  final bool tasksJsonExists;
  final bool usingDefaultConfigs;
  final String? tasksJsonPath;
  final List<String> resolvedPlatforms;
  final String? errorMessage;
}
