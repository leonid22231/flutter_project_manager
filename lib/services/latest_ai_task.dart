import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class LatestAiTask {
  const LatestAiTask({required this.title, this.updatedAt});

  final String title;
  final DateTime? updatedAt;
}

/// Newest task title from `<project>/.ai/*/context.json`.
LatestAiTask? readLatestAiTask(String projectPath) {
  final root = Directory(p.join(projectPath, '.ai'));
  if (!root.existsSync()) return null;

  LatestAiTask? best;
  for (final entity in root.listSync(followLinks: false)) {
    if (entity is! Directory) continue;
    final file = File(p.join(entity.path, 'context.json'));
    if (!file.existsSync()) continue;
    final task = _readTask(file);
    if (task == null) continue;
    best = _newer(best, task);
  }
  return best;
}

LatestAiTask? _readTask(File file) {
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) return null;
    final title = (decoded['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;
    final raw = decoded['updated_at'] ?? decoded['created_at'];
    final updatedAt = raw is String ? DateTime.tryParse(raw) : null;
    return LatestAiTask(title: title, updatedAt: updatedAt);
  } catch (_) {
    return null;
  }
}

LatestAiTask _newer(LatestAiTask? current, LatestAiTask next) {
  if (current == null) return next;
  final currentAt = current.updatedAt;
  final nextAt = next.updatedAt;
  if (nextAt == null) return current;
  if (currentAt == null || nextAt.isAfter(currentAt)) return next;
  return current;
}
