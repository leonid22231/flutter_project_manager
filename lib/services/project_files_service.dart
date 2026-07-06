import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/file_type_utils.dart';
import 'package:project_manager/models/project_file_node.dart';

class ProjectFilesService {
  static const ignoredDirNames = {
    '.git',
    '.dart_tool',
    '.idea',
    '.vscode',
    '.fvm',
    'build',
    '.pub-cache',
    'node_modules',
    '.gradle',
    'Pods',
    '.symlinks',
    'ephemeral',
  };

  static const ignoredFileNames = {'.DS_Store', 'Thumbs.db'};

  static const maxPreviewBytes = 512 * 1024;
  static const maxImagePreviewBytes = 20 * 1024 * 1024;

  Future<List<ProjectFileNode>> loadFileTree(String projectRoot) async {
    final root = Directory(projectRoot);
    if (!root.existsSync()) return [];

    final node = await _scanNode(root, projectRoot);
    return node?.children ?? [];
  }

  Future<ProjectFileNode?> _scanNode(
    Directory directory,
    String projectRoot,
  ) async {
    final name = p.basename(directory.path);
    if (name.isNotEmpty && ignoredDirNames.contains(name)) {
      return null;
    }

    final children = <ProjectFileNode>[];

    try {
      final entries = directory
          .listSync(followLinks: false)
          .where((entity) {
            final baseName = p.basename(entity.path);
            if (entity is Directory) {
              return !ignoredDirNames.contains(baseName);
            }
            if (entity is File) {
              return !ignoredFileNames.contains(baseName);
            }
            return true;
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

      for (final entry in entries) {
        if (entry is Directory) {
          final child = await _scanNode(entry, projectRoot);
          if (child != null) children.add(child);
        } else if (entry is File) {
          children.add(
            ProjectFileNode(
              name: p.basename(entry.path),
              path: entry.path,
              isDirectory: false,
              sizeBytes: entry.lengthSync(),
            ),
          );
        }
      }
    } on FileSystemException {
      return ProjectFileNode(
        name: name.isEmpty ? projectRoot : name,
        path: directory.path,
        isDirectory: true,
        children: const [],
      );
    }

    return ProjectFileNode(
      name: name.isEmpty ? p.basename(projectRoot) : name,
      path: directory.path,
      isDirectory: true,
      children: children,
    );
  }

  Future<FilePreviewResult> readFilePreview(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return FilePreviewResult.error('File not found.');
    }

    final size = file.lengthSync();
    final fileName = p.basename(filePath);

    if (isRasterImageFile(fileName)) {
      if (size > maxImagePreviewBytes) {
        return FilePreviewResult.tooLarge(size);
      }
      return FilePreviewResult.rasterImage(filePath, size);
    }

    if (isSvgFile(fileName)) {
      if (size > maxPreviewBytes) {
        return FilePreviewResult.tooLarge(size);
      }
      try {
        final content = await file.readAsString();
        return FilePreviewResult.svg(filePath, content, size);
      } catch (e) {
        return FilePreviewResult.error('Failed to read SVG: $e');
      }
    }

    if (isFontFile(fileName)) {
      if (size > maxImagePreviewBytes) {
        return FilePreviewResult.tooLarge(size);
      }
      return FilePreviewResult.font(filePath, size);
    }

    if (size > maxPreviewBytes) {
      return FilePreviewResult.tooLarge(size);
    }

    try {
      final content = await file.readAsString();
      return FilePreviewResult.text(content, size);
    } catch (_) {
      return FilePreviewResult.binary(size);
    }
  }

  String relativePath(String projectRoot, String filePath) {
    return p.relative(filePath, from: projectRoot);
  }
}

class FilePreviewResult {
  const FilePreviewResult._({
    required this.kind,
    this.content,
    this.filePath,
    this.sizeBytes,
    this.errorMessage,
  });

  final FilePreviewKind kind;
  final String? content;
  final String? filePath;
  final int? sizeBytes;
  final String? errorMessage;

  factory FilePreviewResult.text(String content, int sizeBytes) {
    return FilePreviewResult._(
      kind: FilePreviewKind.text,
      content: content,
      sizeBytes: sizeBytes,
    );
  }

  factory FilePreviewResult.rasterImage(String filePath, int sizeBytes) {
    return FilePreviewResult._(
      kind: FilePreviewKind.rasterImage,
      filePath: filePath,
      sizeBytes: sizeBytes,
    );
  }

  factory FilePreviewResult.svg(String filePath, String content, int sizeBytes) {
    return FilePreviewResult._(
      kind: FilePreviewKind.svg,
      filePath: filePath,
      content: content,
      sizeBytes: sizeBytes,
    );
  }

  factory FilePreviewResult.font(String filePath, int sizeBytes) {
    return FilePreviewResult._(
      kind: FilePreviewKind.font,
      filePath: filePath,
      sizeBytes: sizeBytes,
    );
  }

  factory FilePreviewResult.binary(int sizeBytes) {
    return FilePreviewResult._(
      kind: FilePreviewKind.binary,
      sizeBytes: sizeBytes,
    );
  }

  factory FilePreviewResult.tooLarge(int sizeBytes) {
    return FilePreviewResult._(
      kind: FilePreviewKind.tooLarge,
      sizeBytes: sizeBytes,
    );
  }

  factory FilePreviewResult.error(String message) {
    return FilePreviewResult._(
      kind: FilePreviewKind.error,
      errorMessage: message,
    );
  }
}

enum FilePreviewKind {
  text,
  rasterImage,
  svg,
  font,
  binary,
  tooLarge,
  error,
}
