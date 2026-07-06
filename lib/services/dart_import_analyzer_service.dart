import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/models/dart_import_analysis.dart';
import 'package:yaml/yaml.dart';

class DartImportAnalyzerService {
  static final _importPattern = RegExp(
    "^\\s*(import|export|part\\s+of|part)\\s+['\"]([^'\"]+)['\"]",
    multiLine: true,
  );

  final Map<String, String?> _projectPackageNameCache = {};

  Future<DartImportAnalysis> analyze({
    required String content,
    required String absoluteFilePath,
    required String projectRoot,
  }) async {
    final projectPackageName =
        await _readProjectPackageName(projectRoot);
    final imports = <DartImportEntry>[];

    for (final match in _importPattern.allMatches(content)) {
      final directiveKeyword = match.group(1)!;
      final uri = match.group(2)!;
      final directive = "$directiveKeyword '$uri'";

      final entry = _classifyImport(
        uri: uri,
        directive: directive,
        directiveKeyword: directiveKeyword,
        absoluteFilePath: absoluteFilePath,
        projectRoot: projectRoot,
        projectPackageName: projectPackageName,
      );
      imports.add(entry);
    }

    return DartImportAnalysis(
      imports: imports,
      projectPackageName: projectPackageName,
    );
  }

  DartImportEntry _classifyImport({
    required String uri,
    required String directive,
    required String directiveKeyword,
    required String absoluteFilePath,
    required String projectRoot,
    required String? projectPackageName,
  }) {
    if (uri.startsWith('dart:')) {
      return DartImportEntry(
        uri: uri,
        kind: DartImportKind.dartSdk,
        directive: directive,
      );
    }

    if (uri.startsWith('package:')) {
      final rest = uri.substring('package:'.length);
      final slashIndex = rest.indexOf('/');
      final packageName = slashIndex == -1 ? rest : rest.substring(0, slashIndex);
      final pathInPackage =
          slashIndex == -1 ? '' : rest.substring(slashIndex + 1);

      if (projectPackageName != null &&
          packageName == projectPackageName &&
          pathInPackage.isNotEmpty) {
        final resolved = _resolveProjectLibPath(projectRoot, pathInPackage);
        return DartImportEntry(
          uri: uri,
          kind: DartImportKind.projectFile,
          directive: directive,
          packageName: packageName,
          resolvedAbsolutePath: resolved,
          resolvedRelativePath: resolved != null
              ? _relativeProjectPath(projectRoot, resolved)
              : pathInPackage,
          targetExists: resolved != null,
        );
      }

      return DartImportEntry(
        uri: uri,
        kind: DartImportKind.package,
        directive: directive,
        packageName: packageName,
      );
    }

    final resolved = _resolveRelativeImport(
      importUri: uri,
      absoluteFilePath: absoluteFilePath,
    );
    final kind = switch (directiveKeyword) {
      'part of' => DartImportKind.partOf,
      'part' => DartImportKind.part,
      _ => DartImportKind.relative,
    };

    return DartImportEntry(
      uri: uri,
      kind: kind,
      directive: directive,
      resolvedAbsolutePath: resolved,
      resolvedRelativePath: resolved != null
          ? _relativeProjectPath(projectRoot, resolved)
          : uri,
      targetExists: resolved != null,
    );
  }

  String? _resolveRelativeImport({
    required String importUri,
    required String absoluteFilePath,
  }) {
    final baseDir = p.dirname(absoluteFilePath);
    final candidate = p.normalize(p.join(baseDir, importUri));
    return _resolveExistingDartFile(candidate);
  }

  String? _resolveProjectLibPath(String projectRoot, String pathInPackage) {
    final candidate = p.normalize(p.join(projectRoot, 'lib', pathInPackage));
    return _resolveExistingDartFile(candidate);
  }

  String? _resolveExistingDartFile(String candidate) {
    if (File(candidate).existsSync()) return candidate;

    if (!candidate.endsWith('.dart')) {
      final withExtension = '$candidate.dart';
      if (File(withExtension).existsSync()) return withExtension;
    }

    return null;
  }

  String? _relativeProjectPath(String projectRoot, String absolutePath) {
    return p.relative(absolutePath, from: projectRoot).replaceAll(r'\', '/');
  }

  Future<String?> _readProjectPackageName(String projectRoot) async {
    if (_projectPackageNameCache.containsKey(projectRoot)) {
      return _projectPackageNameCache[projectRoot];
    }

    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      _projectPackageNameCache[projectRoot] = null;
      return null;
    }

    try {
      final pubspec = loadYaml(await pubspecFile.readAsString());
      final name = pubspec is YamlMap ? pubspec['name']?.toString() : null;
      _projectPackageNameCache[projectRoot] = name;
      return name;
    } catch (_) {
      _projectPackageNameCache[projectRoot] = null;
      return null;
    }
  }
}
