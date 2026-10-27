import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/app_version.dart';
import 'package:project_manager/services/workstation_settings_sync.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('pm_machine_settings_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('mcp.json token is copied unchanged and uuid folders stay', () async {
    const token = 'fixture-token-do-not-rewrite';
    const mcp = '{"mcpServers":{"demo":{"token":"$token"}}}\n';
    final home = Directory('${root.path}\\home\\.cursor')..createSync(recursive: true);
    Directory('${home.path}\\skills').createSync();
    File('${home.path}\\skills\\demo.md').writeAsStringSync('local skill\n');
    File('${home.path}\\memories.json').writeAsStringSync('{"items":["local"]}\n');
    File('${home.path}\\mcp.json').writeAsStringSync(mcp);
    File('${home.path}\\settings.json').writeAsStringSync('{"jdk":"C:\\\\local"}\n');

    final clone = Directory('${root.path}\\clone')..createSync();
    final uuid = Directory(
      '${clone.path}\\11111111-1111-4111-8111-111111111111',
    )..createSync();
    File('${uuid.path}\\keep.txt').writeAsStringSync('stay');
    final remoteCursor = Directory('${clone.path}\\settings\\cursor')
      ..createSync(recursive: true);
    Directory('${remoteCursor.path}\\skills\\remote').createSync(recursive: true);
    File('${remoteCursor.path}\\skills\\remote\\other.md')
        .writeAsStringSync('from the other machine\n');

    final sync = WorkstationSettingsSync();
    await sync.mirror(cursorHome: home, settingsCursor: remoteCursor);

    expect(File('${remoteCursor.path}\\mcp.json').readAsStringSync(), mcp);
    expect(File('${home.path}\\mcp.json').readAsStringSync(), mcp);
    expect(File('${uuid.path}\\keep.txt').readAsStringSync(), 'stay');
    expect(
      File('${remoteCursor.path}\\skills\\demo.md').readAsStringSync(),
      'local skill\n',
    );
    expect(
      File('${home.path}\\skills\\remote\\other.md').readAsStringSync(),
      'from the other machine\n',
    );
    expect(
      File('${clone.path}\\settings\\cursor\\settings.json').existsSync(),
      isFalse,
    );
    expect(WorkstationSettingsSync.commitMessage, 'sync: settings');
  });

  test('a newer version zip is newer than the running build', () {
    final current = AppVersion.parse(appVersion)!;
    final newer = AppVersion.parse('9.0.0+1')!;
    final same = AppVersion.parse(appVersion)!;
    final older = AppVersion.parse('0.1.0')!;
    expect(newer > current, isTrue);
    expect(same.compareTo(current), 0);
    expect(older > current, isFalse);
    expect(
      AppVersion.zipPattern.firstMatch('version_1.2.3+4.zip')?.group(1),
      '1.2.3+4',
    );
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: $appVersion'));
  });
}
