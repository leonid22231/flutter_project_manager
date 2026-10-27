import 'dart:io';

import 'package:path/path.dart' as p;

/// Windows paths longer than 260 characters need the `\\?\` prefix.
///
/// Do not ask the OS to resolve the path first: `File.absolute` fails with
/// "path not found" once the path is already past MAX_PATH.
String windowsLongPath(String path) {
  if (!Platform.isWindows) return path;
  var normalized = p.normalize(stripWindowsLongPath(path));
  if (!p.isAbsolute(normalized)) {
    normalized = p.normalize(p.join(p.current, normalized));
  }
  if (normalized.startsWith(r'\\')) {
    return '\\\\?\\UNC\\${normalized.substring(2)}';
  }
  return '\\\\?\\$normalized';
}

String stripWindowsLongPath(String path) {
  if (path.startsWith(r'\\?\UNC\')) return '\\${path.substring(8)}';
  if (path.startsWith(r'\\?\')) return path.substring(4);
  return path;
}

String plainAbsolute(String path) {
  final stripped = stripWindowsLongPath(path);
  if (p.isAbsolute(stripped)) return p.normalize(stripped);
  return p.normalize(p.join(p.current, stripped));
}

File longFile(String path) => File(windowsLongPath(path));

Directory longDir(String path) => Directory(windowsLongPath(path));

void ensureParent(String filePath) {
  longDir(p.dirname(filePath)).createSync(recursive: true);
}

/// Lists files under [root]. A directory that cannot be opened is skipped.
void walkFiles(
  Directory root,
  void Function(File file, String relative) onFile, {
  bool skipGit = false,
}) {
  if (!root.existsSync()) return;
  final rootPlain = plainAbsolute(root.path);

  void visit(String plainDir) {
    final List<FileSystemEntity> children;
    try {
      children = longDir(plainDir).listSync(followLinks: false);
    } catch (_) {
      return;
    }
    for (final entity in children) {
      final plain = _childPlain(plainDir, entity.path);
      if (entity is Directory) {
        if (skipGit && p.basename(plain) == '.git') continue;
        visit(plain);
      } else if (entity is File) {
        final relative = _relativeInside(rootPlain, plain);
        if (relative == null) continue;
        onFile(longFile(plain), relative);
      }
    }
  }

  visit(rootPlain);
}

/// Deletes [root] including children whose paths exceed MAX_PATH.
void deleteTree(Directory root) {
  if (!root.existsSync()) return;
  final rootPlain = plainAbsolute(root.path);

  void visit(String plainDir) {
    final List<FileSystemEntity> children;
    try {
      children = longDir(plainDir).listSync(followLinks: false);
    } catch (_) {
      return;
    }
    for (final entity in children) {
      final plain = _childPlain(plainDir, entity.path);
      if (entity is Directory) {
        visit(plain);
        try {
          longDir(plain).deleteSync();
        } catch (_) {}
      } else {
        try {
          longFile(plain).deleteSync();
        } catch (_) {}
      }
    }
  }

  visit(rootPlain);
  try {
    longDir(rootPlain).deleteSync();
  } catch (_) {}
}

/// Relative path of [child] inside [root], or null when it escapes the root.
String? _relativeInside(String root, String child) {
  final rootPrefix =
      root.endsWith(p.separator) ? root : '$root${p.separator}';
  if (child.toLowerCase().startsWith(rootPrefix.toLowerCase())) {
    return child.substring(rootPrefix.length);
  }
  return null;
}

String _childPlain(String parentPlain, String entityPath) {
  final stripped = stripWindowsLongPath(entityPath);
  if (p.isAbsolute(stripped)) return p.normalize(stripped);
  return p.normalize(p.join(parentPlain, stripped));
}
