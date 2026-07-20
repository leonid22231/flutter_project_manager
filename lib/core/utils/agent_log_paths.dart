import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves the project_manager app root for `.ai/logs` (MCP flutter-debug-log-fs).
String? findProjectManagerRoot({String? start}) {
  var dir = Directory(start ?? Directory.current.path);
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (RegExp(r'^name:\s*project_manager\s*$', multiLine: true)
          .hasMatch(content)) {
        return dir.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

String resolveAgentLogRoot({String? hint}) {
  return findProjectManagerRoot(start: hint) ??
      findProjectManagerRoot() ??
      (hint?.trim().isNotEmpty == true ? hint!.trim() : Directory.current.path);
}
