import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class AiNote {
  const AiNote({
    required this.title,
    this.body = '',
    this.when = '',
    this.status = '',
  });

  final String title;
  final String body;
  final String when;
  final String status;
}

class AiFolderSnapshot {
  const AiFolderSnapshot({
    this.memories = const [],
    this.agentMemory = const [],
    this.tasks = const [],
    this.openQuestions = const [],
    this.selfAnalysis = '',
  });

  final List<AiNote> memories;
  final List<AiNote> agentMemory;
  final List<AiNote> tasks;
  final List<AiNote> openQuestions;
  final String selfAnalysis;

  bool get isEmpty =>
      memories.isEmpty &&
      agentMemory.isEmpty &&
      tasks.isEmpty &&
      openQuestions.isEmpty;
}

/// Reads memories, learned facts, task titles, and the self-analysis report
/// from `<project>/.ai` without creating files.
AiFolderSnapshot readAiFolder(String projectPath) {
  final ai = Directory(p.join(projectPath, '.ai'));
  if (!ai.existsSync()) return const AiFolderSnapshot();
  return AiFolderSnapshot(
    memories: _readDiary(File(p.join(ai.path, 'memories.json'))),
    agentMemory: _readAgentMemory(File(p.join(ai.path, 'agent-memory.json'))),
    tasks: _readTasks(ai),
    openQuestions: _readOpenQuestions(
      File(p.join(ai.path, 'index', 'open-questions.json')),
    ),
    selfAnalysis: _readSelfAnalysis(File(p.join(ai.path, 'agent-profile.json'))),
  );
}

List<AiNote> _readDiary(File file) {
  final decoded = _decode(file);
  final list = decoded is List
      ? decoded
      : decoded is Map
          ? (decoded['items'] ?? decoded['memories'] ?? decoded['entries'])
          : null;
  if (list is! List) return const [];
  final notes = <AiNote>[];
  for (final item in list) {
    if (item is! Map) continue;
    final title = (item['summary'] as String?)?.trim() ?? '';
    if (title.isEmpty) continue;
    final when = (item['date'] as String?)?.trim() ?? '';
    final notesText = (item['notes'] as String?)?.trim() ?? '';
    notes.add(AiNote(title: title, body: notesText, when: when));
  }
  return notes.reversed.toList();
}

List<AiNote> _readAgentMemory(File file) {
  final decoded = _decode(file);
  if (decoded is! Map) return const [];
  final list = decoded['entries'];
  if (list is! List) return const [];
  final notes = <AiNote>[];
  for (final item in list) {
    if (item is! Map) continue;
    final title = (item['content'] as String?)?.trim() ?? '';
    if (title.isEmpty) continue;
    final when = (item['createdAt'] as String?)?.trim() ?? '';
    notes.add(AiNote(title: title, when: when));
  }
  notes.sort((a, b) => b.when.compareTo(a.when));
  return notes;
}

List<AiNote> _readTasks(Directory ai) {
  final notes = <AiNote>[];
  for (final entity in ai.listSync(followLinks: false)) {
    if (entity is! Directory) continue;
    final file = File(p.join(entity.path, 'context.json'));
    final decoded = _decode(file);
    if (decoded is! Map) continue;
    final title = (decoded['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) continue;
    final raw = decoded['updated_at'] ?? decoded['created_at'];
    final when = raw is String ? raw : '';
    final status = (decoded['status'] as String?)?.trim() ?? '';
    final summary = (decoded['summary'] as String?)?.trim() ?? '';
    notes.add(AiNote(title: title, body: summary, when: when, status: status));
  }
  notes.sort((a, b) {
    final left = DateTime.tryParse(a.when);
    final right = DateTime.tryParse(b.when);
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  });
  return notes;
}

List<AiNote> _readOpenQuestions(File file) {
  final decoded = _decode(file);
  if (decoded is! Map) return const [];
  final list = decoded['questions'];
  if (list is! List) return const [];
  final notes = <AiNote>[];
  for (final item in list) {
    if (item is! Map) continue;
    final status = (item['status'] as String?)?.trim().toLowerCase() ?? '';
    if (status == 'answered' || status == 'done' || status == 'closed') {
      continue;
    }
    final title = (item['question'] as String?)?.trim() ?? '';
    if (title.isEmpty) continue;
    final why = (item['whyNeeded'] as String?)?.trim() ?? '';
    notes.add(AiNote(title: title, body: why, status: status));
  }
  return notes;
}

String _readSelfAnalysis(File file) {
  final decoded = _decode(file);
  if (decoded is! Map) return '';
  return (decoded['selfAnalysis'] as String?)?.trim() ?? '';
}

Object? _decode(File file) {
  if (!file.existsSync()) return null;
  try {
    return jsonDecode(file.readAsStringSync());
  } catch (_) {
    return null;
  }
}
