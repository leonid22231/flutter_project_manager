import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/file_type_utils.dart';
import 'package:project_manager/models/media_asset_binding.dart';
import 'package:project_manager/models/project_media_entry.dart';
import 'package:project_manager/services/media_analyzer_service.dart';
import 'package:yaml/yaml.dart';

class ProjectMediaScanResult {
  const ProjectMediaScanResult({
    required this.entries,
    required this.assetsFolderExists,
    this.assetBindings = const [],
  });

  final List<ProjectMediaEntry> entries;
  final bool assetsFolderExists;
  final List<MediaAssetBinding> assetBindings;
}

Set<String> parsePubspecDeclaredAssets(String pubspecContent) {
  final pubspec = loadYaml(pubspecContent);
  if (pubspec is! Map) return {};

  final flutter = pubspec['flutter'];
  if (flutter is! Map) return {};

  final assets = flutter['assets'];
  if (assets is! YamlList && assets is! List) return {};

  final declared = <String>{};
  for (final item in assets) {
    final value = item?.toString().trim();
    if (value == null || value.isEmpty) continue;
    declared.add(_normalizeAssetPath(value));
  }
  return declared;
}

bool isAssetPathDeclared(String relativePath, Set<String> declaredAssets) {
  if (declaredAssets.isEmpty) return false;

  final path = _normalizeAssetPath(relativePath);
  for (final entry in declaredAssets) {
    if (path == entry) return true;

    final directoryPrefix = entry.endsWith('/') ? entry : '$entry/';
    if (path.startsWith(directoryPrefix)) return true;
  }
  return false;
}

String _normalizeAssetPath(String value) =>
    value.replaceAll(r'\', '/').replaceAll(RegExp(r'/+'), '/');

ProjectMediaKind _mediaKindForFile(String fileName) {
  if (isSvgFile(fileName)) return ProjectMediaKind.svg;
  if (isRasterImageFile(fileName)) return ProjectMediaKind.rasterImage;
  if (isFontFile(fileName)) return ProjectMediaKind.font;
  return ProjectMediaKind.other;
}

class ProjectMediaService {
  ProjectMediaService({MediaAnalyzerService? analyzer})
      : _analyzer = analyzer ?? MediaAnalyzerService();

  final MediaAnalyzerService _analyzer;

  Future<ProjectMediaScanResult> scanProjectMedia(String projectRoot) async {
    final assetsDir = Directory(p.join(projectRoot, 'assets'));
    if (!assetsDir.existsSync()) {
      return const ProjectMediaScanResult(
        entries: [],
        assetsFolderExists: false,
      );
    }

    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    final declared = pubspecFile.existsSync()
        ? parsePubspecDeclaredAssets(await pubspecFile.readAsString())
        : <String>{};

    final entries = <ProjectMediaEntry>[];
    await _scanDirectory(
      assetsDir,
      projectRoot,
      declared,
      entries,
    );

    entries.sort((a, b) => a.relativePath.compareTo(b.relativePath));

    final analysis = await _analyzer.analyzeProject(projectRoot);
    final enrichedEntries = _analyzer.attachAnalysis(
      entries: entries,
      analysis: analysis,
    );

    return ProjectMediaScanResult(
      entries: enrichedEntries,
      assetsFolderExists: true,
      assetBindings: analysis.bindings,
    );
  }

  Future<void> _scanDirectory(
    Directory directory,
    String projectRoot,
    Set<String> declaredAssets,
    List<ProjectMediaEntry> entries,
  ) async {
    final entities = directory
        .listSync(followLinks: false)
        .where((entity) {
          final name = p.basename(entity.path);
          return !name.startsWith('.');
        })
        .toList()
      ..sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
        return p.basename(a.path).toLowerCase().compareTo(
              p.basename(b.path).toLowerCase(),
            );
      });

    for (final entity in entities) {
      if (entity is Directory) {
        await _scanDirectory(entity, projectRoot, declaredAssets, entries);
        continue;
      }

      if (entity is! File) continue;

      final fileName = p.basename(entity.path);
      if (!isProjectMediaFile(fileName)) continue;

      final relativePath = p.relative(entity.path, from: projectRoot);
      final normalizedRelative = _normalizeAssetPath(relativePath);
      final folderPath = p.dirname(normalizedRelative);
      final folder = folderPath == '.' ? 'assets' : folderPath;

      entries.add(
        ProjectMediaEntry(
          path: entity.path,
          relativePath: normalizedRelative,
          fileName: fileName,
          folder: folder,
          kind: _mediaKindForFile(fileName),
          sizeBytes: entity.lengthSync(),
          declaredInPubspec:
              isAssetPathDeclared(normalizedRelative, declaredAssets),
        ),
      );
    }
  }
}
