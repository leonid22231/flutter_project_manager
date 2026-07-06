import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/core/utils/build_config_resolver.dart';
import 'package:project_manager/core/utils/vscode_variable_resolver.dart';
import 'package:project_manager/models/build_config_source.dart';
import 'package:project_manager/models/build_run_mode.dart';
import 'package:project_manager/models/project_build_config.dart';
import 'package:project_manager/services/git_service.dart';

void main() {
  test('VscodeVariableResolver replaces workspaceFolder', () {
    final resolver = VscodeVariableResolver(
      workspaceFolder: r'C:\Work\EvoSoft\kiosk',
    );

    expect(
      resolver.resolve(r'${workspaceFolder}\build'),
      r'C:\Work\EvoSoft\kiosk\build',
    );
    expect(
      resolver.resolve(r'${workspaceFolderBasename}'),
      'kiosk',
    );
  });

  test('resolveBuildConfigVariables resolves cwd and args', () {
    const config = ProjectBuildConfig(
      id: 'task',
      name: 'build android',
      source: BuildConfigSource.tasksJson,
      mode: BuildRunMode.build,
      cwd: r'${workspaceFolder}',
      executable: 'fvm',
      commandArgs: [
        'dart',
        'run',
        'build_tools/build_android_ci.dart',
        '--dart-define=CONFIG_KEY=Api-Key value',
      ],
    );

    final resolved = resolveBuildConfigVariables(
      config,
      r'C:\Work\EvoSoft\kiosk',
    );

    expect(resolved.cwd, r'C:\Work\EvoSoft\kiosk');
    expect(
      resolved.commandArgs.last,
      '--dart-define=CONFIG_KEY=Api-Key value',
    );
  });

  test('parseGitLabRemote accepts self-hosted host from settings', () {
    const baseUrl = 'https://git.evosoft.xyz';

    final remote = parseGitLabRemote(
      'git@git.evosoft.xyz:customer/kiosk.git',
      configuredGitLabBaseUrl: baseUrl,
    );

    expect(remote, isNotNull);
    expect(remote!.host, 'git.evosoft.xyz');
    expect(remote.projectPath, 'customer/kiosk');
  });

  test('parseGitLabRemote still accepts gitlab.com without settings', () {
    final remote = parseGitLabRemote('https://gitlab.com/group/project.git');
    expect(remote?.host, 'gitlab.com');
  });
}
