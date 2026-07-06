import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/core/utils/flutter_platform_utils.dart';
import 'package:project_manager/models/build_config_source.dart';
import 'package:project_manager/models/build_run_mode.dart';
import 'package:project_manager/services/vscode_build_config_service.dart';

void main() {
  final service = VscodeBuildConfigService();

  test('scanProject uses defaults when tasks.json is missing', () async {
    final result = await service.scanProject(
      Directory.systemTemp.path,
      platforms: ['Windows'],
    );

    expect(result.tasksJsonExists, isFalse);
    expect(result.usingDefaultConfigs, isTrue);
    expect(result.configs, hasLength(1));
    expect(
      result.configs.every(
        (config) => config.source == BuildConfigSource.flutterDefault,
      ),
      isTrue,
    );
  });

  test('scanProject uses only tasks.json when it exists', () async {
    final tempDir = await Directory.systemTemp.createTemp('pm_build_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final vscodeDir = Directory('${tempDir.path}/.vscode')..createSync();
    File('${vscodeDir.path}/tasks.json').writeAsStringSync('''
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "build apk",
      "type": "flutter",
      "command": "build",
      "args": ["apk"]
    }
  ]
}
''');

    final result = await service.scanProject(tempDir.path);

    expect(result.tasksJsonExists, isTrue);
    expect(result.usingDefaultConfigs, isFalse);
    expect(result.configs, hasLength(1));
    expect(result.configs.single.source, BuildConfigSource.tasksJson);
    expect(result.configs.single.name, 'build apk');
  });

  test('defaultFlutterConfigs filters builds by project platforms', () {
    final windowsOnly = service.defaultFlutterConfigs(platforms: ['Windows']);

    expect(
      windowsOnly.where((item) => item.mode == BuildRunMode.build),
      hasLength(1),
    );
    expect(
      windowsOnly
          .firstWhere((item) => item.mode == BuildRunMode.build)
          .displayCommand,
      'flutter build windows',
    );
    expect(
      service.defaultFlutterConfigs(platforms: ['Android'])
          .any((item) => item.displayCommand.contains('build apk')),
      isTrue,
    );
    expect(
      service.defaultFlutterConfigs(platforms: ['Android'])
          .any((item) => item.displayCommand.contains('build windows')),
      isFalse,
    );
  });

  test('defaultFlutterConfigs only includes platform build commands', () {
    final configs = service.defaultFlutterConfigs(platforms: ['Web']);

    expect(configs, hasLength(1));
    expect(configs.single.displayCommand, 'flutter build web');
    expect(
      configs.any((item) => item.displayCommand == 'flutter test'),
      isFalse,
    );
  });

  test('scanProject passes project platforms to default builds', () async {
    final tempDir = await Directory.systemTemp.createTemp('pm_build_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final result = await service.scanProject(
      tempDir.path,
      platforms: ['Windows'],
    );

    expect(result.usingDefaultConfigs, isTrue);
    expect(result.resolvedPlatforms, ['Windows']);
    expect(result.configs, hasLength(1));
    expect(result.configs.single.displayCommand, 'flutter build windows');
  });

  test('resolveProjectPlatforms prefers project metadata over folders', () {
    final tempDir = Directory.systemTemp;
    final resolved = resolveProjectPlatforms(
      projectRoot: tempDir.path,
      projectPlatforms: ['Windows'],
    );

    expect(resolved, ['Windows']);
  });

  test('parseTasksJson reads flutter and shell tasks', () {
    const content = '''
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "flutter: build apk",
      "type": "flutter",
      "command": "build",
      "args": ["apk", "--release"],
      "group": "build"
    },
    {
      "label": "temp web build",
      "type": "shell",
      "command": "flutter build web --dart-define=TEMP=true"
    },
    {
      "label": "android ci",
      "type": "shell",
      "command": "fvm",
      "args": [
        "dart",
        "run",
        "build_tools/build_android_ci.dart",
        "--dart-define=CONFIG_KEY=Api-Key TJkyAd9L.3e3BkGxHAf2ieJw6Y5H6K3unVYQqC3xx"
      ]
    }
  ]
}
''';

    final configs = service.parseTasksJson(content, '.vscode/tasks.json');

    expect(configs, hasLength(3));
    expect(configs[0].displayCommand, 'flutter build apk --release');
    expect(configs[0].mode, BuildRunMode.build);
    expect(configs[1].shellCommand, contains('flutter build web'));
    expect(configs[1].mode, BuildRunMode.build);
    expect(configs[2].executable, 'fvm');
    expect(configs[2].commandArgs.first, 'dart');
    expect(configs[2].commandArgs.last, contains('CONFIG_KEY=Api-Key'));
    expect(configs[2].shellCommand, isNull);
  });

  test('quoteShellArgument wraps values with spaces', () {
    final command = quoteShellArguments([
      'fvm',
      'dart',
      'run',
      'script.dart',
      '--dart-define=CONFIG_KEY=Api-Key TJkyAd9L',
    ]);
    expect(command, contains('"--dart-define=CONFIG_KEY=Api-Key TJkyAd9L"'));
  });

  test('decodeJsonc supports trailing commas in task arrays', () {
    const content = '''
{
  "tasks": [
    {
      "label": "build apk",
      "type": "flutter",
      "command": "build",
      "args": ["apk"],
    },
  ],
}
''';

    final decoded = decodeJsonc(content) as Map;
    final tasks = decoded['tasks'] as List;
    expect(tasks, hasLength(1));
    expect(tasks.single['label'], 'build apk');
  });
}
