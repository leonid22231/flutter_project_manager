import 'package:project_manager/models/widget_constructor_param.dart';

/// Parses Dart constructor parameter lists into structured metadata.
class DartConstructorParser {
  const DartConstructorParser._();

  static List<WidgetConstructorParam> parse(String content, String className) {
    final ctor = _findConstructorCall(content, className);
    if (ctor == null) return const [];

    final openParen = content.indexOf('(', ctor.start);
    if (openParen == -1) return const [];

    final closeParen = _findMatchingParen(content, openParen);
    if (closeParen == null) return const [];

    final paramsText = content.substring(openParen + 1, closeParen).trim();
    if (paramsText.isEmpty) return const [];

    final params = _parseParamsBlock(paramsText);
    return _enrichWithFieldTypes(content, className, params);
  }

  static List<WidgetConstructorParam> _enrichWithFieldTypes(
    String content,
    String className,
    List<WidgetConstructorParam> params,
  ) {
    final fieldTypes = _parseFieldTypesForClass(content, className);
    return params
        .map((param) {
          if (param.type != null && param.type!.trim().isNotEmpty) {
            return param;
          }
          final fieldType = fieldTypes[param.name];
          if (fieldType != null) {
            return param.copyWith(type: fieldType);
          }
          if (param.name == 'key') {
            return param.copyWith(type: 'Key?');
          }
          return param;
        })
        .toList();
  }

  static Map<String, String> _parseFieldTypesForClass(
    String content,
    String className,
  ) {
    final classBody = _extractClassBody(content, className);
    if (classBody == null) return {};

    final types = <String, String>{};
    final fieldPattern = RegExp(
      r'^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:final|late\s+final|late|covariant)?\s*'
      r'([A-Za-z_][\w\.<>,\?\[\]\s]*?)\s+(\w+)\s*(?:=[^;]+)?;',
      multiLine: true,
    );

    for (final match in fieldPattern.allMatches(classBody)) {
      final type = match.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ');
      final name = match.group(2)!;
      if (name.isNotEmpty && type.isNotEmpty) {
        types[name] = type;
      }
    }
    return types;
  }

  static String? _extractClassBody(String content, String className) {
    final classMatch = RegExp(
      'class\\s+${RegExp.escape(className)}\\b[^{]*\\{',
      multiLine: true,
    ).firstMatch(content);
    if (classMatch == null) return null;

    final openBrace = classMatch.end - 1;
    final closeBrace = _findMatchingBrace(content, openBrace);
    if (closeBrace == -1) return null;

    return content.substring(openBrace + 1, closeBrace);
  }

  static RegExpMatch? _findConstructorCall(String content, String className) {
    final classPattern = RegExp(
      'class\\s+${RegExp.escape(className)}\\b',
      multiLine: true,
    );
    final classMatch = classPattern.firstMatch(content);
    if (classMatch == null) return null;

    final classLine = _lineNumberAt(content, classMatch.start);
    final ctorPattern = RegExp(
      '(?:const\\s+)?${RegExp.escape(className)}\\s*\\(',
      multiLine: true,
    );

    for (final match in ctorPattern.allMatches(content)) {
      final line = _lineNumberAt(content, match.start);
      if (line < classLine || line > classLine + 40) continue;
      if (_looksLikeWidgetUsage(content, match.start)) continue;
      return match;
    }
    return null;
  }

  /// Returns inclusive line range `[startLine, endLine]` for the class constructor.
  static ({int startLine, int endLine})? constructorLineRange(
    String content,
    String className,
  ) {
    final ctorMatch = _findConstructorCall(content, className);
    if (ctorMatch == null) return null;

    final openParen = content.indexOf('(', ctorMatch.end - 1);
    if (openParen == -1) return null;
    final closeParen = _findMatchingParen(content, openParen);
    if (closeParen == null) return null;

    return (
      startLine: _lineNumberAt(content, ctorMatch.start),
      endLine: _lineNumberAt(content, closeParen),
    );
  }

  static bool _looksLikeWidgetUsage(String content, int nameStart) {
    final lineStart = content.lastIndexOf('\n', nameStart - 1) + 1;
    final linePrefix = content.substring(lineStart, nameStart);
    final trimmed = linePrefix.trim();
    if (trimmed.contains('return ')) return true;
    if (trimmed.endsWith(':')) return true;
    if (RegExp(r'\bchild\s*$').hasMatch(trimmed)) return true;
    if (RegExp(r'\bchildren\s*$').hasMatch(trimmed)) return true;
    return false;
  }

  static List<WidgetConstructorParam> _parseParamsBlock(String paramsText) {
    final result = <WidgetConstructorParam>[];
    final namedStart = paramsText.indexOf('{');

    if (namedStart != -1) {
      final positionalPart = paramsText.substring(0, namedStart).trim();
      if (positionalPart.isNotEmpty) {
        for (final part in _splitTopLevel(positionalPart)) {
          final parsed = _parseSingleParam(part, WidgetParamKind.positional);
          if (parsed != null) result.add(parsed);
        }
      }

      final namedEnd = _findMatchingBrace(paramsText, namedStart);
      if (namedEnd != -1) {
        final namedBody = paramsText.substring(namedStart + 1, namedEnd).trim();
        for (final part in _splitTopLevel(namedBody)) {
          final parsed = _parseSingleParam(part, WidgetParamKind.named);
          if (parsed != null) result.add(parsed);
        }
      }
      return result;
    }

    if (paramsText.trimLeft().startsWith('{')) {
      final namedEnd = _findMatchingBrace(paramsText, paramsText.indexOf('{'));
      if (namedEnd != -1) {
        final namedBody =
            paramsText.substring(paramsText.indexOf('{') + 1, namedEnd).trim();
        for (final part in _splitTopLevel(namedBody)) {
          final parsed = _parseSingleParam(part, WidgetParamKind.named);
          if (parsed != null) result.add(parsed);
        }
      }
      return result;
    }

    for (final part in _splitTopLevel(paramsText)) {
      final parsed = _parseSingleParam(part, WidgetParamKind.positional);
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  static WidgetConstructorParam? _parseSingleParam(
    String raw,
    WidgetParamKind kind,
  ) {
    var text = raw.trim();
    if (text.isEmpty || text == '{' || text == '}') return null;

    var isRequired = false;
    if (text.startsWith('required ')) {
      isRequired = true;
      text = text.substring(9).trim();
    }

    text = text.replaceFirst(RegExp(r'^@\w+(?:\([^)]*\))?\s*'), '');

    String? defaultValue;
    final defaultMatch = RegExp(r'\s*=\s*(.+)$').firstMatch(text);
    if (defaultMatch != null) {
      defaultValue = defaultMatch.group(1)!.trim();
      text = text.substring(0, defaultMatch.start).trim();
    }

    String name;
    String? type;

    if (text.startsWith('super.')) {
      name = text.substring(6).trim();
      type = null;
      // super.key and similar are optional unless explicitly required.
    } else if (text.startsWith('this.')) {
      name = text.substring(5).trim();
      type = null;
      if (!isRequired && defaultValue == null) {
        isRequired = true;
      }
    } else {
      text = text.replaceFirst(RegExp(r'^(?:final|covariant)\s+'), '');
      final parts = text.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        type = parts.sublist(0, parts.length - 1).join(' ');
        name = parts.last;
      } else {
        name = parts.last;
        type = null;
      }
      if (kind == WidgetParamKind.positional && defaultValue == null) {
        isRequired = true;
      }
    }

    name = name.split(RegExp(r'[,\s{]')).first;
    if (name.isEmpty) return null;

    return WidgetConstructorParam(
      name: name,
      type: type,
      isRequired: isRequired,
      kind: kind,
      defaultValue: defaultValue,
    );
  }

  static int? _findMatchingParen(String content, int openIndex) {
    var depth = 0;
    var inString = false;
    var quote = '';
    for (var i = openIndex; i < content.length; i++) {
      final char = content[i];
      if (inString) {
        if (char == quote && content[i - 1] != r'\') inString = false;
        continue;
      }
      if (char == '"' || char == "'") {
        inString = true;
        quote = char;
        continue;
      }
      if (char == '(') depth++;
      if (char == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  static int _findMatchingBrace(String content, int openIndex) {
    var depth = 0;
    var inString = false;
    var quote = '';
    for (var i = openIndex; i < content.length; i++) {
      final char = content[i];
      if (inString) {
        if (char == quote && content[i - 1] != r'\') inString = false;
        continue;
      }
      if (char == '"' || char == "'") {
        inString = true;
        quote = char;
        continue;
      }
      if (char == '{') depth++;
      if (char == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static List<String> _splitTopLevel(String input) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    var inString = false;
    var quote = '';

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (inString) {
        buffer.write(char);
        if (char == quote && input[i - 1] != r'\') inString = false;
        continue;
      }
      if (char == '"' || char == "'") {
        inString = true;
        quote = char;
        buffer.write(char);
        continue;
      }
      if (char == '(' || char == '{' || char == '[') depth++;
      if (char == ')' || char == '}' || char == ']') depth--;
      if (char == ',' && depth == 0) {
        final part = buffer.toString().trim();
        if (part.isNotEmpty) parts.add(part);
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }

    final last = buffer.toString().trim();
    if (last.isNotEmpty) parts.add(last);
    return parts;
  }

  static int _lineNumberAt(String content, int index) {
    return content.substring(0, index).split('\n').length;
  }
}
