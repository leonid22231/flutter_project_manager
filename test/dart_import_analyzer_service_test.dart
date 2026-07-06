import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/models/dart_import_analysis.dart';
import 'package:project_manager/services/dart_import_analyzer_service.dart';

void main() {
  late Directory tempDir;
  late DartImportAnalyzerService analyzer;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pm_dart_import_test_');
    analyzer = DartImportAnalyzerService();

    await File(p.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: sample_app
''');

    await Directory(p.join(tempDir.path, 'lib', 'models')).create(recursive: true);
    await Directory(p.join(tempDir.path, 'lib', 'services')).create(recursive: true);

    await File(p.join(tempDir.path, 'lib', 'models', 'user.dart')).writeAsString('''
class User {}
''');

    await File(p.join(tempDir.path, 'lib', 'services', 'user_service.dart'))
        .writeAsString('''
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:sample_app/models/user.dart';
import '../models/user.dart';

part 'user_service.g.dart';
''');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('detects sdk, package, and project file imports', () async {
    final filePath = p.join(tempDir.path, 'lib', 'services', 'user_service.dart');
    final content = await File(filePath).readAsString();

    final analysis = await analyzer.analyze(
      content: content,
      absoluteFilePath: filePath,
      projectRoot: tempDir.path,
    );

    expect(analysis.projectPackageName, 'sample_app');
    expect(analysis.dartSdkImports, hasLength(1));
    expect(analysis.dartSdkImports.first.uri, 'dart:async');

    expect(analysis.externalPackages, hasLength(1));
    expect(analysis.externalPackages.first.packageName, 'provider');

    expect(analysis.projectFiles, hasLength(3));
    expect(
      analysis.projectFiles.map((entry) => entry.resolvedRelativePath),
      containsAll([
        'lib/models/user.dart',
        'lib/models/user.dart',
      ]),
    );
    expect(
      analysis.projectFiles.any((entry) => entry.kind == DartImportKind.part),
      isTrue,
    );
  });

  test('generates markdown sections', () async {
    final filePath = p.join(tempDir.path, 'lib', 'services', 'user_service.dart');
    final content = await File(filePath).readAsString();

    final analysis = await analyzer.analyze(
      content: content,
      absoluteFilePath: filePath,
      projectRoot: tempDir.path,
    );

    final markdown = analysis.toMarkdown();
    expect(markdown, contains('# Dependencies'));
    expect(markdown, contains('## Project files'));
    expect(markdown, contains('## Packages'));
    expect(markdown, contains('## Dart SDK'));
    expect(markdown, contains('`provider`'));
    expect(markdown, contains('`dart:async`'));
  });
}
