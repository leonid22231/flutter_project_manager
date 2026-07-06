import 'dart:io';

import 'package:path/path.dart' as p;

const kFlutterPlatformFolders = {
  'android': 'Android',
  'ios': 'iOS',
  'web': 'Web',
  'windows': 'Windows',
  'linux': 'Linux',
  'macos': 'macOS',
};

List<String> detectFlutterPlatforms(String projectRoot) {
  final platforms = <String>[];
  for (final entry in kFlutterPlatformFolders.entries) {
    if (Directory(p.join(projectRoot, entry.key)).existsSync()) {
      platforms.add(entry.value);
    }
  }
  return platforms;
}

Set<String> normalizeFlutterPlatformNames(Iterable<String> platforms) {
  final normalized = <String>{};
  for (final platform in platforms) {
    final value = platform.trim();
    if (value.isEmpty) continue;

    final lower = value.toLowerCase();
    for (final entry in kFlutterPlatformFolders.entries) {
      if (lower == entry.key || lower == entry.value.toLowerCase()) {
        normalized.add(entry.value);
        break;
      }
    }
  }
  return normalized;
}

List<String> resolveProjectPlatforms({
  required String projectRoot,
  required List<String> projectPlatforms,
}) {
  if (projectPlatforms.isNotEmpty) {
    return normalizeFlutterPlatformNames(projectPlatforms).toList()..sort();
  }
  final detected = detectFlutterPlatforms(projectRoot);
  detected.sort();
  return detected;
}
