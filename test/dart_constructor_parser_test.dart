import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/core/utils/dart_constructor_parser.dart';
import 'package:project_manager/models/widget_constructor_param.dart';

void main() {
  const sample = '''
class WidgetAppText14 extends StatelessWidget {
  const WidgetAppText14(
    this.text, {
    super.key,
    this.brandslug,
    this.height,
    this.maxLines,
    this.color,
    this.toUpperCase = true,
  });

  final String text;
  @override
  Widget build(BuildContext context) => Text(text);
}
''';

  test('parses positional and named constructor params', () {
    final params = DartConstructorParser.parse(sample, 'WidgetAppText14');

    expect(params.length, 7);

    expect(params[0].name, 'text');
    expect(params[0].kind, WidgetParamKind.positional);
    expect(params[0].isRequired, isTrue);

    expect(params[1].name, 'key');
    expect(params[1].kind, WidgetParamKind.named);
    expect(params[1].isRequired, isFalse);

    expect(params[2].name, 'brandslug');
    expect(params[2].kind, WidgetParamKind.named);
    expect(params[2].isRequired, isTrue);

    final toUpperCase = params.singleWhere((p) => p.name == 'toUpperCase');
    expect(toUpperCase.defaultValue, 'true');
    expect(toUpperCase.isRequired, isFalse);
  });

  test('detects constructor line range', () {
    final range = DartConstructorParser.constructorLineRange(
      sample,
      'WidgetAppText14',
    );

    expect(range, isNotNull);
    expect(range!.startLine, 2);
    expect(range.endLine, greaterThanOrEqualTo(9));
  });

  test('parses WidgetAppText14 constructor from real-world shape', () {
    const sample = '''
class WidgetAppText14 extends StatelessWidget {
  final String? brandSlug;
  final String text;
  final double? height;
  final TextAlign? textAlign;
  final int? maxLines;
  final Color? color;
  final Color? decorationColor;
  final bool toUpperCase;
  final Alignment? alignment;
  final TextOverflow? overflow;
  final TextDecoration? textDecoration;

  const WidgetAppText14(
    this.text, {
    super.key,
    this.brandSlug,
    this.height,
    this.textAlign,
    this.maxLines,
    this.color,
    this.toUpperCase = true,
    this.alignment,
    this.overflow,
    this.textDecoration,
    this.decorationColor,
  });
}
''';
    final params = DartConstructorParser.parse(sample, 'WidgetAppText14');
    expect(params.any((p) => p.name == '{' || p.name == '}'), isFalse);
    expect(params.first.name, 'text');
    expect(params.first.kind, WidgetParamKind.positional);
    expect(params.first.isRequired, isTrue);
    expect(params.singleWhere((p) => p.name == 'key').isRequired, isFalse);
    expect(params.singleWhere((p) => p.name == 'text').type, 'String');
    expect(params.singleWhere((p) => p.name == 'brandSlug').type, 'String?');
    expect(params.singleWhere((p) => p.name == 'height').type, 'double?');
    expect(params.singleWhere((p) => p.name == 'maxLines').type, 'int?');
    expect(params.singleWhere((p) => p.name == 'key').type, 'Key?');
  });

  test('resolves types from field declarations before constructor', () {
    final params = DartConstructorParser.parse(sample, 'WidgetAppText14');
    expect(params.singleWhere((p) => p.name == 'text').type, 'String');
  });
}
