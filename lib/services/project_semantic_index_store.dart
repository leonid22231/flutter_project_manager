import 'dart:convert';
import 'dart:io';

import 'package:project_manager/core/utils/agent_profile_paths.dart';
import 'package:project_manager/models/project_semantic_index.dart';

class ProjectSemanticIndexStore {
  Future<void> ensureDir(String projectRoot) async {
    await Directory(AgentProfilePaths.indexDir(projectRoot))
        .create(recursive: true);
  }

  Future<SemanticIndexSnapshot> loadAll(String projectRoot) async {
    await ensureDir(projectRoot);
    return SemanticIndexSnapshot(
      notes: await loadNotes(projectRoot),
      questions: await loadQuestions(projectRoot),
      answers: await loadAnswers(projectRoot),
      session: await loadSession(projectRoot),
    );
  }

  Future<IndexFileNotesStore> loadNotes(String projectRoot) async {
    return _loadJson(
      AgentProfilePaths.indexFileNotesPath(projectRoot),
      IndexFileNotesStore.fromJson,
      const IndexFileNotesStore(),
    );
  }

  Future<IndexQuestionsStore> loadQuestions(String projectRoot) async {
    return _loadJson(
      AgentProfilePaths.indexOpenQuestionsPath(projectRoot),
      IndexQuestionsStore.fromJson,
      const IndexQuestionsStore(),
    );
  }

  Future<IndexAnswersStore> loadAnswers(String projectRoot) async {
    return _loadJson(
      AgentProfilePaths.indexAnswersPath(projectRoot),
      IndexAnswersStore.fromJson,
      const IndexAnswersStore(),
    );
  }

  Future<IndexSession> loadSession(String projectRoot) async {
    return _loadJson(
      AgentProfilePaths.indexSessionPath(projectRoot),
      IndexSession.fromJson,
      const IndexSession(),
    );
  }

  Future<void> saveNotes(String projectRoot, IndexFileNotesStore store) =>
      _saveJson(AgentProfilePaths.indexFileNotesPath(projectRoot), store.toJson());

  Future<void> saveQuestions(
    String projectRoot,
    IndexQuestionsStore store,
  ) =>
      _saveJson(
        AgentProfilePaths.indexOpenQuestionsPath(projectRoot),
        store.toJson(),
      );

  Future<void> saveAnswers(String projectRoot, IndexAnswersStore store) =>
      _saveJson(AgentProfilePaths.indexAnswersPath(projectRoot), store.toJson());

  Future<void> saveSession(String projectRoot, IndexSession session) =>
      _saveJson(
        AgentProfilePaths.indexSessionPath(projectRoot),
        session.toJson(),
      );

  Future<void> mergeNotes(
    String projectRoot,
    List<IndexFileNote> incoming,
  ) async {
    final existing = await loadNotes(projectRoot);
    final byPath = <String, IndexFileNote>{
      for (final n in existing.notes) n.path: n,
    };
    for (final n in incoming) {
      if (n.path.trim().isEmpty) continue;
      byPath[n.path] = n;
    }
    await saveNotes(
      projectRoot,
      IndexFileNotesStore(notes: byPath.values.toList()),
    );
  }

  Future<void> mergeQuestions(
    String projectRoot,
    List<IndexQuestion> incoming,
  ) async {
    final existing = await loadQuestions(projectRoot);
    final byId = <String, IndexQuestion>{
      for (final q in existing.questions) q.id: q,
    };
    for (final q in incoming) {
      if (q.id.trim().isEmpty || q.question.trim().isEmpty) continue;
      final prev = byId[q.id];
      if (prev != null && !prev.isOpen) continue;
      byId[q.id] = q;
    }
    await saveQuestions(
      projectRoot,
      IndexQuestionsStore(questions: byId.values.toList()),
    );
  }

  Future<T> _loadJson<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
    T fallback,
  ) async {
    final file = File(path);
    if (!file.existsSync()) return fallback;
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map<String, dynamic>) return fromJson(raw);
    } catch (_) {}
    return fallback;
  }

  Future<void> _saveJson(String path, Map<String, dynamic> json) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }
}
