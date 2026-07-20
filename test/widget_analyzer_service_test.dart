import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/models/widget_origin.dart';
import 'package:project_manager/models/widget_constructor_param.dart';
import 'package:project_manager/services/widget_analyzer_service.dart';

void main() {
  late Directory tempDir;
  late WidgetAnalyzerService analyzer;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pm_widget_test_');
    analyzer = WidgetAnalyzerService();

    await Directory(p.join(tempDir.path, 'lib', 'ui')).create(recursive: true);

    await File(p.join(tempDir.path, 'lib', 'ui', 'primary_button.dart'))
        .writeAsString('''
import 'package:flutter/material.dart';

/// Primary action button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
''');

    await File(p.join(tempDir.path, 'lib', 'ui', 'home_screen.dart'))
        .writeAsString('''
import 'package:flutter/material.dart';
import 'primary_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.light();
    final size = Size(100, 200);
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: PrimaryButton(
        label: 'Save',
        onPressed: () {},
      ),
    );
  }
}
''');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('finds custom widget definitions and usages', () async {
    final widgets = await analyzer.scanProject(tempDir.path);

    final custom = widgets.firstWhere((w) => w.name == 'PrimaryButton');
    expect(custom.origin, WidgetOrigin.custom);
    expect(custom.filePath, 'lib/ui/primary_button.dart');
    expect(custom.constructorParams.map((p) => p.name), contains('label'));
    expect(custom.constructorParams.map((p) => p.name), contains('onPressed'));
    expect(
      custom.constructorParams.singleWhere((p) => p.name == 'label').kind,
      WidgetParamKind.named,
    );
    expect(custom.description, contains('Primary action button'));
    expect(custom.usages, isNotEmpty);
    expect(custom.usages.first.filePath, 'lib/ui/home_screen.dart');
    expect(custom.usages.any((u) => u.filePath == 'lib/ui/primary_button.dart'),
        isFalse);

    final text = widgets.firstWhere((w) => w.name == 'Text');
    expect(text.origin, WidgetOrigin.library);
    expect(text.usages, isNotEmpty);

    expect(widgets.any((w) => w.name == 'Size'), isFalse);
    expect(widgets.any((w) => w.name == 'ThemeData'), isFalse);
  });

  test('ignores all-caps identifiers like REQUEST', () async {
    await File(p.join(tempDir.path, 'lib', 'http_stub.dart')).writeAsString('''
class HttpStub {
  void call() {
    const REQUEST = 'GET';
    REQUEST('https://example.com');
  }
}
''');

    final widgets = await analyzer.scanProject(tempDir.path);
    expect(widgets.any((w) => w.name == 'REQUEST'), isFalse);
  });
}
