import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/build_version_utils.dart';
import 'package:project_manager/core/utils/flutter_platform_utils.dart';
import 'package:project_manager/models/build_archive_entry.dart';
import 'package:project_manager/models/project_build_config.dart';
import 'package:project_manager/services/project_storage_service.dart';
import 'package:uuid/uuid.dart';

const _manifestFileName = 'manifest.json';

class BuildArchiveService {
  BuildArchiveService({
    ProjectStorageService? storage,
    Uuid? uuid,
  })  : _storage = storage ?? ProjectStorageService(),
        _uuid = uuid ?? const Uuid();

  final ProjectStorageService _storage;
  final Uuid _uuid;

  Future<List<BuildArchiveEntry>> listArchives(String projectId) async {
    final manifestFile = await _manifestFile(projectId);
    if (!manifestFile.existsSync()) return const [];

    try {
      final decoded = jsonDecode(await manifestFile.readAsString());
      if (decoded is! List) return const [];

      final entries = decoded
          .whereType<Map>()
          .map((item) => BuildArchiveEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } catch (_) {
      return const [];
    }
  }

  Future<BuildArchiveEntry?> archiveSuccessfulBuild({
    required String projectId,
    required String projectRoot,
    required ProjectBuildConfig config,
    required String buildOutput,
    int exitCode = 0,
  }) async {
    if (exitCode != 0) return null;

    final sourcePath = resolveBuildOutputPath(
      projectRoot: projectRoot,
      config: config,
      buildOutput: buildOutput,
    );
    if (sourcePath == null) return null;

    final sourceFile = File(sourcePath);
    final sourceDir = Directory(sourcePath);
    final isFile = sourceFile.existsSync();
    final isDir = !isFile && sourceDir.existsSync();
    if (!isFile && !isDir) return null;

    final buildsDir = await _storage.getBuildsDirectory(projectId);
    final entryId = _uuid.v4();
    final archiveDir = Directory(p.join(buildsDir.path, entryId));
    final artifactsDir = Directory(p.join(archiveDir.path, 'artifacts'));
    artifactsDir.createSync(recursive: true);

    if (isFile) {
      await sourceFile.copy(p.join(artifactsDir.path, p.basename(sourceFile.path)));
    } else {
      await _copyDirectory(sourceDir, artifactsDir);
    }

    final artifactFiles = _listRelativeFiles(artifactsDir.path);
    final entry = BuildArchiveEntry(
      id: entryId,
      createdAt: DateTime.now(),
      projectVersion: parseVersionFromBuildNames(artifactFiles) ??
          await readPubspecVersion(projectRoot) ??
          'unknown',
      configName: config.name,
      command: config.displayCommand,
      platform: _platformLabelForConfig(config),
      archivePath: archiveDir.path,
      sourceOutputPath: sourcePath,
      artifactFiles: artifactFiles,
      exitCode: exitCode,
    );

    await File(p.join(archiveDir.path, 'build.log')).writeAsString(buildOutput);
    await File(p.join(archiveDir.path, 'meta.json'))
        .writeAsString(jsonEncode(entry.toJson()));

    final entries = await listArchives(projectId);
    entries.insert(0, entry);
    await _saveManifest(projectId, entries);
    return entry;
  }

  Future<void> deleteArchive({
    required String projectId,
    required String archiveId,
  }) async {
    final buildsDir = await _storage.getBuildsDirectory(projectId);
    final archiveDir = Directory(p.join(buildsDir.path, archiveId));
    if (archiveDir.existsSync()) {
      archiveDir.deleteSync(recursive: true);
    }

    final entries = await listArchives(projectId);
    entries.removeWhere((entry) => entry.id == archiveId);
    await _saveManifest(projectId, entries);
  }

  Future<File> _manifestFile(String projectId) async {
    final buildsDir = await _storage.getBuildsDirectory(projectId);
    return File(p.join(buildsDir.path, _manifestFileName));
  }

  Future<void> _saveManifest(
    String projectId,
    List<BuildArchiveEntry> entries,
  ) async {
    final manifestFile = await _manifestFile(projectId);
    await manifestFile.writeAsString(
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }

    await for (final entity in source.list(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: source.path);
      final targetPath = p.join(destination.path, relative);
      if (entity is Directory) {
        Directory(targetPath).createSync(recursive: true);
      } else if (entity is File) {
        Directory(p.dirname(targetPath)).createSync(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }

  List<String> _listRelativeFiles(String rootPath) {
    final root = Directory(rootPath);
    if (!root.existsSync()) return const [];

    final files = <String>[];
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        files.add(p.relative(entity.path, from: rootPath));
      }
    }
    files.sort();
    return files;
  }

  String _platformLabelForConfig(ProjectBuildConfig config) {
    final command = config.displayCommand.toLowerCase();
    for (final entry in kFlutterPlatformFolders.entries) {
      if (command.contains('build ${entry.key}') ||
          command.contains('build ${entry.value.toLowerCase()}')) {
        return entry.value;
      }
    }
    if (command.contains('apk') || command.contains('appbundle')) {
      return 'Android';
    }
    return 'Other';
  }
}

Future<String?> readPubspecVersion(String projectRoot) async {
  final file = File(p.join(projectRoot, 'pubspec.yaml'));
  if (!file.existsSync()) return null;

  final content = await file.readAsString();
  final match = RegExp(r'^version:\s*([^\s#]+)', multiLine: true).firstMatch(content);
  return match?.group(1)?.trim();
}

String? resolveBuildOutputPath({
  required String projectRoot,
  required ProjectBuildConfig config,
  required String buildOutput,
}) {
  final fromOutput = _parseBuiltOutputPath(projectRoot, buildOutput);
  if (fromOutput != null) return fromOutput;

  final command = config.displayCommand.toLowerCase();
  final candidates = <String>[];

  if (command.contains('build windows')) {
    candidates.add(p.join(projectRoot, 'build', 'windows', 'x64', 'runner', 'Release'));
  } else if (command.contains('build web')) {
    candidates.add(p.join(projectRoot, 'build', 'web'));
  } else if (command.contains('build linux')) {
    candidates.add(p.join(projectRoot, 'build', 'linux', 'x64', 'release', 'bundle'));
  } else if (command.contains('build macos')) {
    candidates.add(
      p.join(projectRoot, 'build', 'macos', 'Build', 'Products', 'Release'),
    );
  } else if (command.contains('build ios')) {
    candidates.add(p.join(projectRoot, 'build', 'ios', 'iphoneos'));
  } else if (command.contains('build appbundle')) {
    candidates.add(p.join(projectRoot, 'build', 'app', 'outputs', 'bundle', 'release'));
    candidates.add(p.join(projectRoot, 'build', 'app', 'outputs', 'bundle'));
  } else if (command.contains('build apk')) {
    candidates.add(p.join(projectRoot, 'build', 'app', 'outputs', 'flutter-apk'));
    candidates.add(p.join(projectRoot, 'build', 'app', 'outputs', 'apk'));
  } else if (command.contains('build aab')) {
    candidates.add(p.join(projectRoot, 'build', 'app', 'outputs', 'bundle', 'release'));
  }

  for (final candidate in candidates) {
    if (File(candidate).existsSync() || Directory(candidate).existsSync()) {
      return candidate;
    }
  }

  for (final candidate in candidates) {
    final parent = Directory(p.dirname(candidate));
    if (parent.existsSync()) {
      final match = parent
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => _isLikelyArtifact(file.path))
          .toList();
      if (match.isNotEmpty) {
        return match.first.path;
      }
    }
  }

  return null;
}

String? _parseBuiltOutputPath(String projectRoot, String buildOutput) {
  final match = RegExp(
    r'Built\s+(.+)$',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(buildOutput);
  if (match == null) return null;

  var builtPath = match.group(1)!.trim();
  builtPath = builtPath.replaceAll('√', '').trim();
  final fullPath = p.isAbsolute(builtPath)
      ? p.normalize(builtPath)
      : p.normalize(p.join(projectRoot, builtPath));

  if (File(fullPath).existsSync()) {
    return fullPath;
  }
  if (Directory(fullPath).existsSync()) {
    return fullPath;
  }

  final parent = p.dirname(fullPath);
  if (Directory(parent).existsSync()) {
    return parent;
  }
  return null;
}

bool _isLikelyArtifact(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.exe') ||
      lower.endsWith('.apk') ||
      lower.endsWith('.aab') ||
      lower.endsWith('.app') ||
      lower.endsWith('.dmg') ||
      lower.endsWith('.ipa');
}
