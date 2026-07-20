import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/models/media_asset_binding.dart';
import 'package:project_manager/models/media_usage_entry.dart';
import 'package:project_manager/models/project_media_entry.dart';
import 'package:project_manager/services/project_files_service.dart';

const supportedAssetsClassNames = {'AppAssets', 'AppAssetsDesigned'};

class MediaAnalysisResult {
  const MediaAnalysisResult({
    required this.bindings,
    required this.usagesByPath,
    required this.designedUsagesByFileName,
  });

  final List<MediaAssetBinding> bindings;
  final Map<String, List<MediaUsageEntry>> usagesByPath;
  final Map<String, List<MediaUsageEntry>> designedUsagesByFileName;
}

String normalizeMediaPath(String value) =>
    value.replaceAll(r'\', '/').replaceAll(RegExp(r'/+'), '/');

RegExp assetTemplateRegExp(String template) {
  final buffer = StringBuffer('^');
  for (var index = 0; index < template.length; index++) {
    final char = template[index];
    if (char == '{') {
      final end = template.indexOf('}', index + 1);
      if (end == -1) {
        throw FormatException('Unclosed template placeholder in $template');
      }
      buffer.write('([^/]+)');
      index = end;
      continue;
    }
    buffer.write(RegExp.escape(char));
  }
  buffer.write(r'$');
  return RegExp(buffer.toString());
}

bool matchesAssetTemplate(String template, String assetPath) {
  if (!template.contains('{')) {
    return normalizeMediaPath(template) == normalizeMediaPath(assetPath);
  }
  return assetTemplateRegExp(normalizeMediaPath(template))
      .hasMatch(normalizeMediaPath(assetPath));
}

bool isAssetsClassName(String className) {
  if (supportedAssetsClassNames.contains(className)) return true;
  return className.startsWith('AppAssets');
}

List<MediaAssetBinding> parseAssetsClassBindings({
  required String className,
  required String classBody,
  required String definitionFile,
  required int classStartIndex,
  required String fullContent,
}) {
  if (!isAssetsClassName(className)) return const [];

  final bindings = <MediaAssetBinding>[];
  final preloadMembers = _parsePreloadListMembers(classBody);

  final fieldPattern = RegExp(
    r'''static\s+(?:(?:const|final)\s+)?String\s+(\w+)\s*=\s*(?:'([^']*)'|"([^"]*)")''',
    multiLine: true,
  );

  for (final match in fieldPattern.allMatches(classBody)) {
    final constantName = match.group(1)!;
    final rawPath = match.group(2) ?? match.group(3)!;
    final path = normalizeMediaPath(rawPath);
    final isDesigned = !path.startsWith('assets/');

    bindings.add(
      MediaAssetBinding(
        className: className,
        constantName: constantName,
        assetPath: path,
        definitionFile: definitionFile,
        definitionLine: _lineNumberAt(fullContent, classStartIndex + match.start),
        inPreloadList: preloadMembers.contains(constantName),
        isDesigned: isDesigned,
      ),
    );
  }

  for (final member in preloadMembers) {
    final index = bindings.indexWhere(
      (binding) => binding.constantName == member,
    );
    if (index == -1) continue;
    final existing = bindings[index];
    bindings[index] = MediaAssetBinding(
      className: existing.className,
      constantName: existing.constantName,
      assetPath: existing.assetPath,
      definitionFile: existing.definitionFile,
      definitionLine: existing.definitionLine,
      inPreloadList: true,
      isDesigned: existing.isDesigned,
    );
  }

  return bindings;
}

Map<String, String> parseAssetsPathPrefixes(String classBody) {
  final prefixes = <String, String>{};
  final prefixPattern = RegExp(
    r'''static\s+(?:const|final)\s+(?:String\s+)?(\w+)\s*=\s*(?:'([^']*)'|"([^"]*)")''',
    multiLine: true,
  );

  for (final match in prefixPattern.allMatches(classBody)) {
    final name = match.group(1)!;
    final value = match.group(2) ?? match.group(3);
    if (value == null || value.isEmpty) continue;
    prefixes[name] = normalizeMediaPath(value);
  }

  return prefixes;
}

String? resolveAssetPathExpression(
  String raw,
  Map<String, String> prefixes,
) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final normalized = normalizeMediaPath(value);
  if (normalized.startsWith('assets/')) return normalized;

  final patterns = <RegExp>[
    RegExp(r'^\$_(\w+)/(.*)$'),
    RegExp(r'^\$\{(\w+)\}/(.*)$'),
    RegExp(r'^\$(\w+)/(.*)$'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(value);
    if (match == null) continue;
    final prefix = prefixes[match.group(1)!];
    if (prefix == null) continue;
    return normalizeMediaPath('${prefix}/${match.group(2)!}');
  }

  if (RegExp(
    r'\.(?:svg|png|jpe?g|gif|webp|bmp|ico|ttf|otf|woff2?)$',
    caseSensitive: false,
  ).hasMatch(value)) {
    return normalizeMediaPath(value);
  }

  return null;
}

Set<String> extractAssetPathsFromMethodBody(
  String methodBody,
  Map<String, String> prefixes,
) {
  final paths = <String>{};
  final stringPattern = RegExp(r'''['"]([^'"]+)['"]''');

  for (final match in stringPattern.allMatches(methodBody)) {
    final raw = match.group(1)!;
    if (!_looksLikeAssetExpression(raw)) continue;
    final resolved = resolveAssetPathExpression(raw, prefixes);
    if (resolved != null) {
      paths.add(resolved);
    }
  }

  return paths;
}

bool _looksLikeAssetExpression(String raw) {
  if (raw.startsWith('assets/')) return true;
  if (raw.contains(r'$_') || raw.contains(r'$')) return true;
  return RegExp(
    r'\.(?:svg|png|jpe?g|gif|webp|bmp|ico|ttf|otf|woff2?)$',
    caseSensitive: false,
  ).hasMatch(raw);
}

String? extractBalancedBody(String content, int openBraceIndex) {
  if (openBraceIndex < 0 || openBraceIndex >= content.length) return null;
  if (content[openBraceIndex] != '{') return null;

  var depth = 0;
  for (var index = openBraceIndex; index < content.length; index++) {
    final char = content[index];
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return content.substring(openBraceIndex + 1, index);
      }
    }
  }
  return null;
}

List<MediaAssetBinding> parseAssetsMethodBindings({
  required String className,
  required String classBody,
  required String definitionFile,
  required int classStartIndex,
  required String fullContent,
}) {
  if (!isAssetsClassName(className)) return const [];

  final prefixes = parseAssetsPathPrefixes(classBody);
  final bindings = <MediaAssetBinding>[];
  final methodPattern = RegExp(
    r'static\s+(?:[\w<>,\s?]*\bString\b[\w<>,\s?]*)\s+(\w+)\s*\([^)]*\)\s*(?:async\s*)?(?:\{|=>)',
    multiLine: true,
  );

  for (final match in methodPattern.allMatches(classBody)) {
    final methodName = match.group(1)!;
    String? body;
    if (classBody[match.end - 1] == '{') {
      body = extractBalancedBody(classBody, match.end - 1);
    } else {
      final arrowEnd = classBody.indexOf(';', match.end);
      if (arrowEnd == -1) continue;
      body = classBody.substring(match.end, arrowEnd);
    }
    if (body == null || body.isEmpty) continue;

    final resolvedPaths = extractAssetPathsFromMethodBody(body, prefixes);
    if (resolvedPaths.isEmpty) continue;

    final definitionLine =
        _lineNumberAt(fullContent, classStartIndex + match.start);
    for (final path in resolvedPaths) {
      bindings.add(
        MediaAssetBinding(
          className: className,
          constantName: methodName,
          assetPath: path,
          definitionFile: definitionFile,
          definitionLine: definitionLine,
          isDesigned: !path.startsWith('assets/'),
          isMethod: true,
        ),
      );
    }
  }

  return bindings;
}

Set<String> _parsePreloadListMembers(String classBody) {
  final listPattern = RegExp(
    r'static\s+const\s+List<String>\s+\w+\s*=\s*\[([\s\S]*?)\];',
    multiLine: true,
  );
  final match = listPattern.firstMatch(classBody);
  if (match == null) return {};

  final members = <String>{};
  final itemPattern = RegExp(r'[A-Za-z_]\w*');
  for (final item in itemPattern.allMatches(match.group(1)!)) {
    members.add(item.group(0)!);
  }
  return members;
}

String? extractClassBody(String content, String className) {
  final startMatch = RegExp('class\\s+$className\\s*\\{').firstMatch(content);
  if (startMatch == null) return null;

  var depth = 0;
  var started = false;
  for (var index = startMatch.end - 1; index < content.length; index++) {
    final char = content[index];
    if (char == '{') {
      depth++;
      started = true;
    } else if (char == '}') {
      depth--;
      if (started && depth == 0) {
        return content.substring(startMatch.end, index);
      }
    }
  }
  return null; 
}

List<MediaUsageEntry> parseMediaUsagesInFile({
  required String content,
  required String relativePath,
  required Map<String, Map<String, MediaAssetBinding>> bindingsByClass,
}) {
  final usages = <MediaUsageEntry>[];

  final methodCallPattern = RegExp(r'\b((?:AppAssets\w*)\.(\w+))\s*\(');
  for (final match in methodCallPattern.allMatches(content)) {
    final reference = match.group(1)!;
    final className = reference.split('.').first;
    if (!isAssetsClassName(className)) continue;
    if (_isDefinitionLine(content, match.start)) continue;

    usages.add(
      MediaUsageEntry(
        filePath: relativePath,
        line: _lineNumberAt(content, match.start),
        snippet: _lineSnippet(content, _lineNumberAt(content, match.start)),
        reference: reference,
        kind: MediaUsageReferenceKind.appAssetsMethod,
      ),
    );
  }

  final appAssetsPattern = RegExp(r'\b((?:AppAssets\w*)\.(\w+))(?!\s*\()');
  for (final match in appAssetsPattern.allMatches(content)) {
    final reference = match.group(1)!;
    final className = reference.split('.').first;
    final constantName = match.group(2)!;
    if (!isAssetsClassName(className)) continue;
    if (_isDefinitionLine(content, match.start)) continue;

    final binding = bindingsByClass[className]?[constantName];
    usages.add(
      MediaUsageEntry(
        filePath: relativePath,
        line: _lineNumberAt(content, match.start),
        snippet: _lineSnippet(content, _lineNumberAt(content, match.start)),
        reference: reference,
        kind: MediaUsageReferenceKind.appAssetsConstant,
        resolvedPath: binding?.assetPath,
      ),
    );
  }

  final designedAssetPattern = RegExp(
    r'designedAsset\s*\(\s*(?:AppAssetsDesigned\.)?(\w+)',
  );
  for (final match in designedAssetPattern.allMatches(content)) {
    final constantName = match.group(1)!;
    final binding = bindingsByClass['AppAssetsDesigned']?[constantName];
    usages.add(
      MediaUsageEntry(
        filePath: relativePath,
        line: _lineNumberAt(content, match.start),
        snippet: _lineSnippet(content, _lineNumberAt(content, match.start)),
        reference: binding == null
            ? 'designedAsset($constantName)'
            : 'designedAsset(${binding.reference})',
        kind: MediaUsageReferenceKind.designedAssetCall,
        resolvedPath: binding?.assetPath,
      ),
    );
  }

  final literalPattern = RegExp(
    r'''['"](assets/[^'"]+\.(?:svg|png|jpe?g|gif|webp|bmp|ico|ttf|otf|woff2?))['"]''',
    caseSensitive: false,
  );
  for (final match in literalPattern.allMatches(content)) {
    if (_isDefinitionLine(content, match.start)) continue;
    final path = normalizeMediaPath(match.group(1)!);
    usages.add(
      MediaUsageEntry(
        filePath: relativePath,
        line: _lineNumberAt(content, match.start),
        snippet: _lineSnippet(content, _lineNumberAt(content, match.start)),
        reference: path,
        kind: MediaUsageReferenceKind.stringLiteral,
        resolvedPath: path,
      ),
    );
  }

  return usages;
}

bool _isDefinitionLine(String content, int index) {
  final lineStart = content.lastIndexOf('\n', index) + 1;
  final lineEnd = content.indexOf('\n', index);
  final line = content
      .substring(lineStart, lineEnd == -1 ? content.length : lineEnd)
      .trim();
  return line.startsWith('static ');
}

int _lineNumberAt(String content, int index) {
  return content.substring(0, index).split('\n').length;
}

String _lineSnippet(String content, int line) {
  final lines = content.split('\n');
  if (line <= 0 || line > lines.length) return '';
  return lines[line - 1].trim();
}

class MediaAnalyzerService {
  Future<MediaAnalysisResult> analyzeProject(String projectRoot) async {
    final dartFiles = await _collectDartFiles(projectRoot);
    final bindings = <MediaAssetBinding>[];
    final bindingsByClass = <String, Map<String, MediaAssetBinding>>{};
    final usages = <MediaUsageEntry>[];

    for (final file in dartFiles) {
      final content = await file.readAsString();
      final relativePath =
          normalizeMediaPath(p.relative(file.path, from: projectRoot));

      final classPattern = RegExp(r'class\s+(AppAssets\w*)\s*\{');
      for (final match in classPattern.allMatches(content)) {
        final className = match.group(1)!;
        final classBody = extractClassBody(content, className);
        if (classBody == null) continue;

        final classBindings = [
          ...parseAssetsClassBindings(
            className: className,
            classBody: classBody,
            definitionFile: relativePath,
            classStartIndex: match.start,
            fullContent: content,
          ),
          ...parseAssetsMethodBindings(
            className: className,
            classBody: classBody,
            definitionFile: relativePath,
            classStartIndex: match.start,
            fullContent: content,
          ),
        ];
        bindings.addAll(classBindings);
        bindingsByClass.putIfAbsent(className, () => {});
        for (final binding in classBindings) {
          bindingsByClass[className]![binding.constantName] = binding;
        }
      }
    }

    for (final file in dartFiles) {
      final content = await file.readAsString();
      final relativePath =
          normalizeMediaPath(p.relative(file.path, from: projectRoot));
      usages.addAll(
        parseMediaUsagesInFile(
          content: content,
          relativePath: relativePath,
          bindingsByClass: bindingsByClass,
        ),
      );
    }

    final grouped = _groupUsagesByMediaPath(usages, bindings);

    return MediaAnalysisResult(
      bindings: bindings,
      usagesByPath: grouped.usagesByPath,
      designedUsagesByFileName: grouped.designedUsagesByFileName,
    );
  }

  List<ProjectMediaEntry> attachAnalysis({
    required List<ProjectMediaEntry> entries,
    required MediaAnalysisResult analysis,
  }) {
    final bindingsByPath = <String, List<MediaAssetBinding>>{};
    for (final binding in analysis.bindings) {
      if (binding.isDesigned) {
        continue;
      }
      if (binding.isTemplate) {
        continue;
      }
      if (binding.isMethod) {
        bindingsByPath.putIfAbsent(binding.assetPath, () => []).add(binding);
        continue;
      }
      bindingsByPath.putIfAbsent(binding.assetPath, () => []).add(binding);
    }
    for (final binding in analysis.bindings.where((item) => item.isDesigned)) {
      for (final entry in entries) {
        if (entry.fileName == binding.assetPath ||
            entry.relativePath.endsWith('/${binding.assetPath}')) {
          bindingsByPath
              .putIfAbsent(entry.relativePath, () => [])
              .add(binding);
        }
      }
    }

    return [
      for (final entry in entries)
        ProjectMediaEntry(
          path: entry.path,
          relativePath: entry.relativePath,
          fileName: entry.fileName,
          folder: entry.folder,
          kind: entry.kind,
          sizeBytes: entry.sizeBytes,
          declaredInPubspec: entry.declaredInPubspec,
          assetBindings: [
            ...bindingsByPath[entry.relativePath] ?? const [],
            ...analysis.bindings.where(
              (binding) =>
                  !binding.isDesigned &&
                  binding.isTemplate &&
                  matchesAssetTemplate(binding.assetPath, entry.relativePath),
            ),
          ],
          usages: [
            ..._usagesForMediaEntry(entry.relativePath, analysis),
            ...analysis.designedUsagesByFileName[entry.fileName] ?? const [],
          ],
        ),
    ];
  }

  List<MediaUsageEntry> _usagesForMediaEntry(
    String relativePath,
    MediaAnalysisResult analysis,
  ) {
    final usages = <MediaUsageEntry>[];
    final fileName = p.basename(relativePath);
    for (final entry in analysis.usagesByPath.entries) {
      final key = entry.key;
      if (key.contains('{')) {
        if (matchesAssetTemplate(key, relativePath)) {
          usages.addAll(entry.value);
        }
      } else if (key == relativePath || key == fileName) {
        usages.addAll(entry.value);
      }
    }
    return usages;
  }

  _GroupedUsages _groupUsagesByMediaPath(
    List<MediaUsageEntry> usages,
    List<MediaAssetBinding> bindings,
  ) {
    final bindingsByReference = <String, List<MediaAssetBinding>>{};
    for (final binding in bindings) {
      bindingsByReference
          .putIfAbsent(binding.reference, () => [])
          .add(binding);
    }
    final bindingByConstant = <String, MediaAssetBinding>{
      for (final binding in bindings.where((item) => item.isDesigned))
        binding.constantName: binding,
    };
    final usagesByPath = <String, List<MediaUsageEntry>>{};
    final designedUsagesByFileName = <String, List<MediaUsageEntry>>{};

    void addPathUsage(String path, MediaUsageEntry usage) {
      usagesByPath.putIfAbsent(path, () => []).add(usage);
    }

    void addDesignedUsage(String fileName, MediaUsageEntry usage) {
      designedUsagesByFileName.putIfAbsent(fileName, () => []).add(usage);
    }

    void addBindingsUsage(List<MediaAssetBinding> memberBindings, MediaUsageEntry usage) {
      for (final binding in memberBindings) {
        if (binding.isDesigned) {
          addDesignedUsage(binding.assetPath, usage);
        } else {
          addPathUsage(binding.assetPath, usage);
        }
      }
    }

    for (final usage in usages) {
      switch (usage.kind) {
        case MediaUsageReferenceKind.stringLiteral:
          final path = usage.resolvedPath;
          if (path != null) addPathUsage(path, usage);
        case MediaUsageReferenceKind.appAssetsConstant:
        case MediaUsageReferenceKind.appAssetsMethod:
          final memberBindings = bindingsByReference[usage.reference];
          if (memberBindings == null || memberBindings.isEmpty) break;
          addBindingsUsage(memberBindings, usage);
        case MediaUsageReferenceKind.designedAssetCall:
          final constantName = usage.reference
              .replaceFirst(RegExp(r'^designedAsset\('), '')
              .replaceFirst(RegExp(r'\)$'), '')
              .replaceFirst('AppAssetsDesigned.', '');
          final binding = bindingByConstant[constantName];
          if (binding != null) {
            addDesignedUsage(binding.assetPath, usage);
          }
      }
    }

    return _GroupedUsages(
      usagesByPath: usagesByPath,
      designedUsagesByFileName: designedUsagesByFileName,
    );
  }

  Future<List<File>> _collectDartFiles(String projectRoot) async {
    final result = <File>[];
    await _walk(Directory(projectRoot), projectRoot, result);
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

class _GroupedUsages {
  const _GroupedUsages({
    required this.usagesByPath,
    required this.designedUsagesByFileName,
  });

  final Map<String, List<MediaUsageEntry>> usagesByPath;
  final Map<String, List<MediaUsageEntry>> designedUsagesByFileName;
}
