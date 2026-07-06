import 'package:project_manager/core/utils/vscode_variable_resolver.dart';
import 'package:project_manager/models/project_build_config.dart';

ProjectBuildConfig resolveBuildConfigVariables(
  ProjectBuildConfig config,
  String projectRoot,
) {
  final resolver = VscodeVariableResolver(workspaceFolder: projectRoot);

  return ProjectBuildConfig(
    id: config.id,
    name: config.name,
    source: config.source,
    mode: config.mode,
    type: config.type,
    program: resolver.resolveNullable(config.program),
    deviceId: resolver.resolveNullable(config.deviceId),
    args: resolver.resolveList(config.args),
    toolArgs: resolver.resolveList(config.toolArgs),
    additionalArgs: resolver.resolveList(config.additionalArgs),
    preLaunchTask: resolver.resolveNullable(config.preLaunchTask),
    cwd: resolver.resolveNullable(config.cwd),
    executable: resolver.resolveNullable(config.executable),
    commandArgs: resolver.resolveList(config.commandArgs),
    shellCommand: resolver.resolveNullable(config.shellCommand),
    sourceFile: config.sourceFile,
    childConfigurationNames: config.childConfigurationNames,
    taskGroup: config.taskGroup,
    isBackground: config.isBackground,
  );
}
