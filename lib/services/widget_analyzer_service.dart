import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/core/constants/flutter_widget_names.dart';
import 'package:project_manager/core/utils/dart_constructor_parser.dart';
import 'package:project_manager/models/widget_constructor_param.dart';
import 'package:project_manager/models/widget_entry.dart';
import 'package:project_manager/models/widget_origin.dart';
import 'package:project_manager/models/widget_usage_entry.dart';
import 'package:project_manager/services/project_files_service.dart';

class _WidgetDefinitionDraft {
  _WidgetDefinitionDraft({
    required this.name,
    required this.filePath,
    required this.line,
    required this.superType,
    required this.constructorParams,
    this.description,
    this.isConstConstructor = false,
  });

  final String name;
  final String filePath;
  final int line;
  final String superType;
  final List<WidgetConstructorParam> constructorParams;
  final String? description;
  final bool isConstConstructor;
}

class WidgetAnalyzerService {
  static const _excludeCallNames = {
    'If', 'For', 'Switch', 'Return', 'Throw', 'Assert', 'Class', 'Enum',
    'Extension', 'Mixin', 'Import', 'Export', 'Part', 'Typedef', 'Abstract',
    'Await', 'Sync', 'Async', 'Try', 'Catch', 'Finally', 'Do', 'While',
    'Super', 'This', 'Null', 'True', 'False', 'Void', 'Dynamic', 'Static',
    'Late', 'Required', 'Override', 'Immutable', 'BuildContext', 'WidgetRef',
    'Future', 'Stream', 'List', 'Map', 'Set', 'String', 'int', 'double',
    'bool', 'Object', 'Function', 'Duration', 'DateTime', 'RegExp', 'Uri',
    'StateError', 'ArgumentError', 'UnimplementedError', 'FormatException',
  };

  static final _classExtendsPattern = RegExp(
    r'class\s+(\w+)\s+extends\s+([A-Za-z_]\w*(?:<[^>]+>)?)',
    multiLine: true,
  );

  static final _stateClassPattern = RegExp(
    r'class\s+(\w+)\s+extends\s+State<\s*(\w+)\s*>',
    multiLine: true,
  );

  static final _widgetCallPattern = RegExp(
    r'(?:^|[\s(,=\[{])([A-Z][A-Za-z0-9_]*)\s*(?:\(|<)',
    multiLine: true,
  );

  Future<List<WidgetEntry>> scanProject(String projectRoot) async {
    final dartFiles = await _collectDartFiles(projectRoot);
    final definitions = <String, _WidgetDefinitionDraft>{};
    final constructorRanges = <String, List<({String file, int start, int end})>>{};
    final stateClasses = <String, String>{};
    final usagesByName = <String, List<WidgetUsageEntry>>{};

    for (final file in dartFiles) {
      final content = await file.readAsString();
      final relativePath =
          p.relative(file.path, from: projectRoot).replaceAll(r'\', '/');
      _collectStateClasses(content, stateClasses);
      _collectDefinitions(content, relativePath, definitions);
      for (final definition in definitions.values) {
        if (definition.filePath != relativePath) continue;
        final range = DartConstructorParser.constructorLineRange(
          content,
          definition.name,
        );
        if (range == null) continue;
        constructorRanges
            .putIfAbsent(definition.name, () => [])
            .add((file: relativePath, start: range.startLine, end: range.endLine));
      }
    }

    for (final file in dartFiles) {
      final content = await file.readAsString();
      final relativePath =
          p.relative(file.path, from: projectRoot).replaceAll(r'\', '/');
      _collectUsages(
        content: content,
        relativePath: relativePath,
        knownCustomWidgets: definitions.keys.toSet(),
        constructorRanges: constructorRanges,
        usagesByName: usagesByName,
      );
    }

    final entries = <WidgetEntry>[];

    for (final definition in definitions.values) {
      final usages = usagesByName[definition.name] ?? const [];
      entries.add(
        _toEntry(
          name: definition.name,
          filePath: definition.filePath,
          definition: definition,
          stateClassName: stateClasses[definition.name],
          origin: WidgetOrigin.custom,
          usages: usages,
        ),
      );
      usagesByName.remove(definition.name);
    }

    for (final entry in usagesByName.entries) {
      final name = entry.key;
      if (!FlutterWidgetNames.isLikelyWidgetCall(name, definitions.keys.toSet())) {
        continue;
      }
      entries.add(
        _toEntry(
          name: name,
          filePath: '',
          definition: null,
          stateClassName: null,
          origin: WidgetOrigin.library,
          usages: entry.value,
        ),
      );
    }

    entries.sort((a, b) {
      final originCompare = a.origin.index.compareTo(b.origin.index);
      if (originCompare != 0) return originCompare;
      return a.name.compareTo(b.name);
    });

    return entries;
  }

  void _collectStateClasses(String content, Map<String, String> stateClasses) {
    for (final match in _stateClassPattern.allMatches(content)) {
      stateClasses[match.group(2)!] = match.group(1)!;
    }
  }

  void _collectDefinitions(
    String content,
    String relativePath,
    Map<String, _WidgetDefinitionDraft> definitions,
  ) {
    final lines = content.split('\n');

    for (final match in _classExtendsPattern.allMatches(content)) {
      final name = match.group(1)!;
      final superType = match.group(2)!;
      if (!_isWidgetSuperType(superType)) continue;

      final line = _lineNumberAt(content, match.start);
      final constructorParams =
          DartConstructorParser.parse(content, name);
      final description = _extractDocComment(lines, line);
      final isConst = _hasConstConstructor(content, name);

      definitions[name] = _WidgetDefinitionDraft(
        name: name,
        filePath: relativePath,
        line: line,
        superType: superType,
        constructorParams: constructorParams,
        description: description,
        isConstConstructor: isConst,
      );
    }
  }

  void _collectUsages({
    required String content,
    required String relativePath,
    required Set<String> knownCustomWidgets,
    required Map<String, List<({String file, int start, int end})>>
        constructorRanges,
    required Map<String, List<WidgetUsageEntry>> usagesByName,
  }) {
    for (final match in _widgetCallPattern.allMatches(content)) {
      final name = match.group(1)!;
      if (_excludeCallNames.contains(name)) continue;
      if (!FlutterWidgetNames.isLikelyWidgetCall(name, knownCustomWidgets)) {
        continue;
      }
      if (name.endsWith('State')) continue;

      final openParenIndex = content.indexOf('(', match.end - 1);
      if (openParenIndex == -1) continue;

      final parsed = _parseCallArguments(content, openParenIndex, match.start);
      if (parsed == null) continue;

      final line = _lineNumberAt(content, match.start);
      if (_isConstructorUsage(
        widgetName: name,
        filePath: relativePath,
        line: line,
        constructorRanges: constructorRanges,
      )) {
        continue;
      }

      final enclosing = _findEnclosingName(content, match.start);

      final usage = WidgetUsageEntry(
        filePath: relativePath,
        line: line,
        enclosingName: enclosing,
        positionalArgs: parsed.positional,
        namedArgs: parsed.named,
      );

      usagesByName.putIfAbsent(name, () => []).add(usage);
    }
  }

  bool _isConstructorUsage({
    required String widgetName,
    required String filePath,
    required int line,
    required Map<String, List<({String file, int start, int end})>>
        constructorRanges,
  }) {
    final ranges = constructorRanges[widgetName];
    if (ranges == null) return false;
    for (final range in ranges) {
      if (range.file == filePath &&
          line >= range.start &&
          line <= range.end) {
        return true;
      }
    }
    return false;
  }

  WidgetEntry _toEntry({
    required String name,
    required String filePath,
    required _WidgetDefinitionDraft? definition,
    required String? stateClassName,
    required WidgetOrigin origin,
    required List<WidgetUsageEntry> usages,
  }) {
    final line = definition?.line;
    return WidgetEntry(
      id: _widgetId(name, filePath, line),
      name: name,
      filePath: filePath,
      type: definition?.superType ?? 'Widget usage',
      origin: origin,
      description: definition?.description,
      constructorParams: definition?.constructorParams ?? const [],
      definitionLine: line,
      superType: definition?.superType,
      stateClassName: stateClassName,
      usages: usages,
      isConstConstructor: definition?.isConstConstructor ?? false,
    );
  }

  bool _isWidgetSuperType(String superType) {
    final base = superType.split('<').first;
    return base == 'StatelessWidget' ||
        base == 'StatefulWidget' ||
        base == 'Widget' ||
        base == 'InheritedWidget' ||
        base == 'RenderObjectWidget' ||
        base == 'ParentDataWidget' ||
        base == 'ProxyWidget' ||
        base == 'LeafRenderObjectWidget' ||
        base == 'SingleChildRenderObjectWidget' ||
        base == 'MultiChildRenderObjectWidget' ||
        base == 'SlottedRenderObjectWidget';
  }

  bool _hasConstConstructor(String content, String className) {
    return RegExp('const\\s+$className\\s*\\(').hasMatch(content);
  }

  String? _extractDocComment(List<String> lines, int lineNumber) {
    if (lineNumber <= 1) return null;
    final docs = <String>[];
    for (var i = lineNumber - 2; i >= 0; i--) {
      final line = lines[i].trimRight();
      if (line.trim().isEmpty) {
        if (docs.isNotEmpty) break;
        continue;
      }
      if (line.trim().startsWith('///')) {
        docs.insert(0, line.trim().substring(3).trim());
        continue;
      }
      if (line.trim().startsWith('/**') || line.trim().startsWith('*')) {
        docs.insert(0, line.trim().replaceAll(RegExp(r'^/[*]*\s?|\*/$'), ''));
        continue;
      }
      break;
    }
    if (docs.isEmpty) return null;
    return docs.join('\n').trim();
  }

  String? _findEnclosingName(String content, int index) {
    final before = content.substring(0, index);
    final buildMatch = RegExp(
      r'Widget\s+build\s*\(',
      multiLine: true,
    ).allMatches(before);
    if (buildMatch.isNotEmpty) return 'build';

    final methodMatches = RegExp(
      r'[\w<>]+\s+(\w+)\s*\([^\)]*\)\s*\{',
      multiLine: true,
    ).allMatches(before);
    if (methodMatches.isNotEmpty) {
      return methodMatches.last.group(1);
    }
    return null;
  }

  _ParsedCall? _parseCallArguments(
    String content,
    int openParenIndex,
    int nameStart,
  ) {
    var depth = 0;
    var inString = false;
    var stringQuote = '';
    for (var i = openParenIndex; i < content.length; i++) {
      final char = content[i];
      if (inString) {
        if (char == stringQuote && content[i - 1] != r'\') {
          inString = false;
        }
        continue;
      }
      if (char == '"' || char == "'") {
        inString = true;
        stringQuote = char;
        continue;
      }
      if (char == '(') depth++;
      if (char == ')') {
        depth--;
        if (depth == 0) {
          final argsText = content.substring(openParenIndex + 1, i).trim();
          final snippetStart = nameStart.clamp(0, content.length);
          final snippet = content.substring(snippetStart, i + 1).trim();
          return _ParsedCall.fromArgs(argsText, snippet);
        }
      }
    }
    return null;
  }

  int _lineNumberAt(String content, int index) {
    return content.substring(0, index).split('\n').length;
  }

  String _widgetId(String name, String filePath, int? line) {
    final bytes = utf8.encode('$name|$filePath|${line ?? 0}');
    return md5.convert(bytes).toString().substring(0, 12);
  }

  Future<List<File>> _collectDartFiles(String projectRoot) async {
    final result = <File>[];
    final libDir = Directory(p.join(projectRoot, 'lib'));
    final testDir = Directory(p.join(projectRoot, 'test'));

    if (libDir.existsSync()) {
      await _walk(libDir, projectRoot, result);
    }
    if (testDir.existsSync()) {
      await _walk(testDir, projectRoot, result);
    }
    if (result.isEmpty) {
      await _walk(Directory(projectRoot), projectRoot, result);
    }
    return result;
  }

  Future<void> _walk(
    Directory directory,
    String projectRoot,
    List<File> result,
  ) async {
    if (!directory.existsSync()) return;

    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        if (ProjectFilesService.ignoredDirNames.contains(name)) continue;
        await _walk(entity, projectRoot, result);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        final name = p.basename(entity.path);
        if (ProjectFilesService.ignoredFileNames.contains(name)) continue;
        result.add(entity);
      }
    }
  }
}

class _ParsedCall {
  _ParsedCall({
    required this.positional,
    required this.named,
    required this.snippet,
  });

  final List<String> positional;
  final Map<String, String> named;
  final String snippet;

  factory _ParsedCall.fromArgs(String argsText, String snippet) {
    if (argsText.isEmpty) {
      return _ParsedCall(positional: const [], named: const {}, snippet: snippet);
    }

    if (argsText.trimLeft().startsWith('{')) {
      final named = <String, String>{};
      final body = argsText.trim();
      final inner = body.startsWith('{') && body.endsWith('}')
          ? body.substring(1, body.length - 1)
          : body;
      for (final part in _splitTopLevel(inner)) {
        final colonIndex = part.indexOf(':');
        if (colonIndex == -1) continue;
        final key = part.substring(0, colonIndex).trim();
        final value = part.substring(colonIndex + 1).trim();
        if (key.isNotEmpty) named[key] = value;
      }
      return _ParsedCall(positional: const [], named: named, snippet: snippet);
    }

    return _ParsedCall(
      positional: _splitTopLevel(argsText),
      named: const {},
      snippet: snippet,
    );
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
}
