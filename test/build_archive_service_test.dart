import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/models/build_config_source.dart';
import 'package:project_manager/models/build_run_mode.dart';
import 'package:project_manager/models/project_build_config.dart';
import 'package:project_manager/services/build_archive_service.dart';

void main() {
  test('resolveBuildOutputPath parses Built line from flutter output', () {
    final tempDir = Directory.systemTemp.createTempSync('pm_archive_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final releaseDir = Directory(
      '${tempDir.path}/build/windows/x64/runner/Release',
    )..createSync(recursive: true);
    final exePath = File('${releaseDir.path}/project_manager.exe')
      ..createSync();
    final config = ProjectBuildConfig(
      id: 'windows',
      name: 'build windows',
      source: BuildConfigSource.flutterDefault,
      mode: BuildRunMode.build,
      shellCommand: 'flutter build windows',
    );

    final output = '''
Building Windows application...
√ Built build\\windows\\x64\\runner\\Release\\project_manager.exe
''';

    final resolved = resolveBuildOutputPath(
      projectRoot: tempDir.path,
      config: config,
      buildOutput: output,
    );

    expect(resolved, isNotNull);
    expect(p.equals(resolved!, exePath.path), isTrue);
  });

  test('resolveBuildOutputPath falls back to known windows output folder', () {
    final tempDir = Directory.systemTemp.createTempSync('pm_archive_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final releaseDir = Directory(
      '${tempDir.path}/build/windows/x64/runner/Release',
    )..createSync(recursive: true);
    File('${releaseDir.path}/project_manager.exe').createSync();

    final config = ProjectBuildConfig(
      id: 'windows',
      name: 'build windows',
      source: BuildConfigSource.flutterDefault,
      mode: BuildRunMode.build,
      shellCommand: 'flutter build windows',
    );

    final resolved = resolveBuildOutputPath(
      projectRoot: tempDir.path,
      config: config,
      buildOutput: 'Finished.',
    );

    expect(resolved, isNotNull);
    expect(p.equals(resolved!, releaseDir.path), isTrue);
  });

  test('readPubspecVersion reads version from pubspec.yaml', () async {
    final tempDir = Directory.systemTemp.createTempSync('pm_archive_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: demo
version: 1.2.3+45
''');

    expect(await readPubspecVersion(tempDir.path), '1.2.3+45');
  });
}
