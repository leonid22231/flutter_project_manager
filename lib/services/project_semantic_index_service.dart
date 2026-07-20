import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/models/agent_progress_step.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/models/project_file_node.dart';
import 'package:project_manager/models/project_semantic_index.dart';
import 'package:project_manager/services/analysis/cursor_cli_stream_runner.dart';
import 'package:project_manager/services/analysis/project_index_prompt.dart';
import 'package:project_manager/services/app_log_service.dart';
import 'package:project_manager/services/cursor_cli_logger.dart';
import 'package:project_manager/services/project_files_service.dart';
import 'package:project_manager/services/project_semantic_index_store.dart';
import 'package:uuid/uuid.dart';

typedef SemanticIndexProgressCallback = void Function(
  IndexSession session, {
  List<AgentProgressStep> agentSteps,
  String partialOutput,
  IndexFileNotesStore? notes,
  IndexQuestionsStore? questions,
  IndexAnswersStore? answers,
});

class ProjectSemanticIndexService {
  ProjectSemanticIndexService({
    ProjectSemanticIndexStore? store,
    ProjectFilesService? filesService,
    CursorCliStreamRunner? runner,
    CursorCliLogger? logger,
    Uuid? uuid,
  })  : _store = store ?? ProjectSemanticIndexStore(),
        _files = filesService ?? ProjectFilesService(),
        _runner = runner ?? CursorCliStreamRunner(),
        _log = logger ?? CursorCliLogger.instance,
        _uuid = uuid ?? const Uuid();

  final ProjectSemanticIndexStore _store;
  final ProjectFilesService _files;
  final CursorCliStreamRunner _runner;
  final CursorCliLogger _log;
  final Uuid _uuid;

  static const maxFilesPerBatch = 35;
  static const maxBinaryBytes = 256 * 1024;

  var _cancelRequested = false;

  void cancel() {
    _cancelRequested = true;
    _runner.cancel();
  }

  Future<SemanticIndexSnapshot> load(String projectRoot) =>
      _store.loadAll(projectRoot);

  Future<IndexSession> startInventory({
    required String projectRoot,
    required CursorCliSettings settings,
    required String languageCode,
    SemanticIndexProgressCallback? onProgress,
  }) async {
    _cancelRequested = false;
    if (!settings.enabled) {
      throw StateError('Cursor CLI is disabled');
    }

    final paths = await _collectRelativePaths(projectRoot);
    final batches = _chunkPaths(paths);
    final now = DateTime.now();

    var session = IndexSession(
      phase: IndexSessionPhase.inventory,
      totalFiles: paths.length,
      processedFiles: 0,
      currentBatch: 0,
      totalBatches: batches.length,
      currentFolder: batches.isEmpty ? '' : _folderOf(batches.first.first),
      pass: 1,
      startedAt: now,
      updatedAt: now,
    );
    await _store.saveSession(projectRoot, session);
    onProgress?.call(session);
    AppLogService.instance.info(
      'Semantic inventory started: ${paths.length} paths, ${batches.length} batches',
      source: 'semantic-index',
    );

    _log.info(
      'Semantic index inventory started.',
      source: 'semantic-index',
      logRoot: projectRoot,
      data: {
        'files': paths.length,
        'batches': batches.length,
      },
    );

    for (var i = 0; i < batches.length; i++) {
      if (_cancelRequested) {
        session = session.copyWith(
          phase: IndexSessionPhase.cancelled,
          updatedAt: DateTime.now(),
        );
        await _store.saveSession(projectRoot, session);
        onProgress?.call(session);
        AppLogService.instance.warn('Inventory cancelled by user',
            source: 'semantic-index');
        return session;
      }

      final batch = batches[i];
      session = session.copyWith(
        phase: IndexSessionPhase.inventory,
        currentBatch: i + 1,
        currentFolder: _folderOf(batch.first),
        updatedAt: DateTime.now(),
        clearError: true,
      );
      await _store.saveSession(projectRoot, session);
      onProgress?.call(session, agentSteps: const [], partialOutput: '');
      AppLogService.instance.info(
        'Batch ${i + 1}/${batches.length}: ${_folderOf(batch.first)} (${batch.length} paths)',
        source: 'semantic-index',
      );

      try {
        final prompt = ProjectIndexPrompt.buildInventoryBatch(
          languageCode: languageCode,
          batchLabel: 'folder ${_folderOf(batch.first)}',
          relativePaths: batch,
          batchIndex: i,
          totalBatches: batches.length,
        );

        var lastLoggedStepCount = 0;
        final result = await _runner.run(
          projectRoot: projectRoot,
          settings: settings,
          prompt: prompt,
          logSource: 'semantic-index',
          mode: CursorCliMode.ask,
          maxDuration: const Duration(minutes: 12),
          idleTimeout: const Duration(minutes: 4),
          onProgress: (steps, partial) {
            onProgress?.call(
              session,
              agentSteps: steps,
              partialOutput: partial,
            );
            if (steps.length > lastLoggedStepCount) {
              for (var s = lastLoggedStepCount; s < steps.length; s++) {
                final step = steps[s];
                AppLogService.instance.think(
                  step.text,
                  source: 'semantic-index',
                  data: {
                    'batch': i + 1,
                    'complete': step.isComplete,
                    if (step.isError) 'error': true,
                  },
                );
              }
              lastLoggedStepCount = steps.length;
            }
          },
        );

        if (_cancelRequested || result.cancelled) {
          session = session.copyWith(
            phase: IndexSessionPhase.cancelled,
            updatedAt: DateTime.now(),
          );
          await _store.saveSession(projectRoot, session);
          onProgress?.call(session);
          return session;
        }

        if (result.failed) {
          throw StateError(
            result.stderr.trim().isNotEmpty
                ? result.stderr.trim()
                : 'Cursor CLI failed (exit ${result.exitCode})',
          );
        }

        final parsed = _parseNotesQuestionsFromRun(result, batch: i + 1);
        await _store.mergeNotes(projectRoot, parsed.notes);
        await _store.mergeQuestions(projectRoot, parsed.questions);
        final snap = await _store.loadAll(projectRoot);
        onProgress?.call(
          session,
          notes: snap.notes,
          questions: snap.questions,
          answers: snap.answers,
        );
      } catch (e) {
        _log.error(
          'Inventory batch failed: $e',
          source: 'semantic-index',
          logRoot: projectRoot,
          data: {'batch': i + 1},
        );
        session = session.copyWith(
          phase: IndexSessionPhase.failed,
          error: e.toString(),
          updatedAt: DateTime.now(),
        );
        await _store.saveSession(projectRoot, session);
        onProgress?.call(session);
        return session;
      }

      session = session.copyWith(
        processedFiles: (session.processedFiles + batch.length)
            .clamp(0, session.totalFiles),
        updatedAt: DateTime.now(),
      );
      await _store.saveSession(projectRoot, session);
      onProgress?.call(session);
    }

    final open = (await _store.loadQuestions(projectRoot)).open;
    session = session.copyWith(
      phase: open.isEmpty
          ? IndexSessionPhase.finalized
          : IndexSessionPhase.awaitingAnswers,
      processedFiles: session.totalFiles,
      updatedAt: DateTime.now(),
      clearError: true,
    );
    await _store.saveSession(projectRoot, session);
    onProgress?.call(session);
    return session;
  }

  Future<IndexSession> deepenWithAnswers({
    required String projectRoot,
    required CursorCliSettings settings,
    required String languageCode,
    SemanticIndexProgressCallback? onProgress,
  }) async {
    _cancelRequested = false;
    if (!settings.enabled) {
      throw StateError('Cursor CLI is disabled');
    }

    final questions = await _store.loadQuestions(projectRoot);
    final answers = await _store.loadAnswers(projectRoot);
    final answerByQ = {for (final a in answers.answers) a.questionId: a};

    final pairs = <Map<String, String>>[];
    final focus = <String>{};
    for (final q in questions.questions) {
      final a = answerByQ[q.id];
      if (a == null) continue;
      if (q.path != null && q.path!.isNotEmpty) focus.add(q.path!);
      pairs.add({
        'id': q.id,
        'question': q.question,
        'answer': a.answer,
        'kind': a.kind,
      });
    }

    var session = (await _store.loadSession(projectRoot)).copyWith(
      phase: IndexSessionPhase.deepening,
      pass: (await _store.loadSession(projectRoot)).pass + 1,
      updatedAt: DateTime.now(),
      clearError: true,
    );
    await _store.saveSession(projectRoot, session);
    onProgress?.call(session, agentSteps: const [], partialOutput: '');
    AppLogService.instance.info(
      'Deepen pass with ${pairs.length} answers',
      source: 'semantic-index',
    );

    if (pairs.isEmpty) {
      session = session.copyWith(
        phase: IndexSessionPhase.finalized,
        updatedAt: DateTime.now(),
      );
      await _store.saveSession(projectRoot, session);
      onProgress?.call(session);
      return session;
    }

    try {
      final prompt = ProjectIndexPrompt.buildDeepenPass(
        languageCode: languageCode,
        answeredPairs: pairs,
        focusPaths: focus.toList()..sort(),
      );

      var lastLoggedStepCount = 0;
      final result = await _runner.run(
        projectRoot: projectRoot,
        settings: settings,
        prompt: prompt,
        logSource: 'semantic-index',
        mode: CursorCliMode.ask,
        maxDuration: const Duration(minutes: 12),
        idleTimeout: const Duration(minutes: 4),
        onProgress: (steps, partial) {
          onProgress?.call(
            session,
            agentSteps: steps,
            partialOutput: partial,
          );
          if (steps.length > lastLoggedStepCount) {
            for (var s = lastLoggedStepCount; s < steps.length; s++) {
              AppLogService.instance.think(
                steps[s].text,
                source: 'semantic-index',
                data: {'pass': 'deepen', 'complete': steps[s].isComplete},
              );
            }
            lastLoggedStepCount = steps.length;
          }
        },
      );

      if (_cancelRequested || result.cancelled) {
        session = session.copyWith(
          phase: IndexSessionPhase.cancelled,
          updatedAt: DateTime.now(),
        );
        await _store.saveSession(projectRoot, session);
        onProgress?.call(session);
        return session;
      }

      if (result.failed) {
        throw StateError(
          result.stderr.trim().isNotEmpty
              ? result.stderr.trim()
              : 'Cursor CLI failed (exit ${result.exitCode})',
        );
      }

      final parsed = _parseNotesQuestionsFromRun(result, batch: 0);
      await _store.mergeNotes(projectRoot, parsed.notes);
      await _store.mergeQuestions(projectRoot, parsed.questions);

      final remaining = (await _store.loadQuestions(projectRoot)).open;
      final doneFlag = parsed.done == true && remaining.isEmpty;

      session = session.copyWith(
        phase: (doneFlag || remaining.isEmpty)
            ? IndexSessionPhase.finalized
            : IndexSessionPhase.awaitingAnswers,
        updatedAt: DateTime.now(),
        clearError: true,
      );
      await _store.saveSession(projectRoot, session);
      final snap = await _store.loadAll(projectRoot);
      onProgress?.call(
        session,
        notes: snap.notes,
        questions: snap.questions,
        answers: snap.answers,
      );
      return session;
    } catch (e) {
      session = session.copyWith(
        phase: IndexSessionPhase.failed,
        error: e.toString(),
        updatedAt: DateTime.now(),
      );
      await _store.saveSession(projectRoot, session);
      onProgress?.call(session);
      return session;
    }
  }

  Future<void> submitAnswer({
    required String projectRoot,
    required String questionId,
    required String answerText,
    required IndexQuestionStatus status,
  }) async {
    final questions = await _store.loadQuestions(projectRoot);
    final updated = questions.questions.map((q) {
      if (q.id != questionId) return q;
      return q.copyWith(status: status);
    }).toList();
    await _store.saveQuestions(
      projectRoot,
      IndexQuestionsStore(questions: updated),
    );

    final answers = await _store.loadAnswers(projectRoot);
    final filtered =
        answers.answers.where((a) => a.questionId != questionId).toList();
    final kind = switch (status) {
      IndexQuestionStatus.skipped => 'skipped',
      IndexQuestionStatus.unknown => 'unknown',
      _ => 'answered',
    };
    filtered.add(
      IndexAnswer(
        questionId: questionId,
        answer: answerText.trim().isEmpty
            ? (status == IndexQuestionStatus.unknown
                ? 'unknown'
                : status == IndexQuestionStatus.skipped
                    ? 'skipped'
                    : '')
            : answerText.trim(),
        kind: kind,
        createdAt: DateTime.now(),
      ),
    );
    await _store.saveAnswers(
      projectRoot,
      IndexAnswersStore(answers: filtered),
    );
  }

  Future<List<String>> _collectRelativePaths(String projectRoot) async {
    final tree = await _files.loadFileTree(projectRoot);
    final result = <String>[];

    void walk(List<ProjectFileNode> nodes) {
      for (final node in nodes) {
        final rel =
            p.normalize(p.relative(node.path, from: projectRoot))
                .replaceAll('\\', '/');
        if (node.isDirectory) {
          result.add(rel);
          walk(node.children);
        } else {
          final file = File(node.path);
          if (!file.existsSync()) continue;
          final size = file.lengthSync();
          if (size > maxBinaryBytes && !_looksTexty(rel)) continue;
          result.add(rel);
        }
      }
    }

    walk(tree);
    result.sort();
    return result;
  }

  bool _looksTexty(String rel) {
    final lower = rel.toLowerCase();
    const exts = {
      '.dart',
      '.yaml',
      '.yml',
      '.json',
      '.md',
      '.txt',
      '.xml',
      '.gradle',
      '.kts',
      '.cmake',
      '.gitignore',
      '.properties',
      '.plist',
      '.rc',
      '.sh',
      '.ps1',
      '.bat',
      '.cmd',
      '.html',
      '.css',
      '.js',
      '.ts',
      '.svg',
    };
    final ext = p.extension(lower);
    if (exts.contains(ext)) return true;
    final base = p.basename(lower);
    return base == 'cmakeLists.txt' ||
        base == 'dockerfile' ||
        base == 'makefile' ||
        base.startsWith('.');
  }

  List<List<String>> _chunkPaths(List<String> paths) {
    if (paths.isEmpty) return const [];

    // Prefer grouping by top-level segment, then size-limit.
    final byTop = <String, List<String>>{};
    for (final path in paths) {
      final top = path.contains('/') ? path.split('/').first : path;
      byTop.putIfAbsent(top, () => []).add(path);
    }

    final batches = <List<String>>[];
    for (final entry in byTop.entries) {
      final list = entry.value..sort();
      for (var i = 0; i < list.length; i += maxFilesPerBatch) {
        final end = (i + maxFilesPerBatch).clamp(0, list.length);
        batches.add(list.sublist(i, end));
      }
    }
    return batches;
  }

  String _folderOf(String path) {
    if (!path.contains('/')) return path;
    return path.split('/').first;
  }

  ({List<IndexFileNote> notes, List<IndexQuestion> questions, bool? done})
      _parseNotesQuestionsFromRun(
    CursorCliStreamRunResult result, {
    required int batch,
  }) {
    final fromAnswer = _parseNotesQuestions(result.answer);
    if (fromAnswer.notes.isNotEmpty || fromAnswer.questions.isNotEmpty) {
      AppLogService.instance.info(
        'Batch parse: ${fromAnswer.notes.length} notes, '
        '${fromAnswer.questions.length} questions (from answer)',
        source: 'semantic-index',
        data: {'batch': batch},
      );
      return fromAnswer;
    }

    // JSON often lands in assistant segments (logged as THINK) while
    // result.answer is empty / prose-only.
    for (final step in result.steps.reversed) {
      final fromStep = _parseNotesQuestions(step.text);
      if (fromStep.notes.isNotEmpty || fromStep.questions.isNotEmpty) {
        AppLogService.instance.warn(
          'Batch parse recovered from agent steps '
          '(answer had no JSON): ${fromStep.notes.length} notes, '
          '${fromStep.questions.length} questions',
          source: 'semantic-index',
          data: {'batch': batch},
        );
        return fromStep;
      }
    }

    final combined = StringBuffer(result.answer);
    for (final step in result.steps) {
      combined.writeln(step.text);
    }
    final fromCombined = _parseNotesQuestions(combined.toString());
    if (fromCombined.notes.isNotEmpty || fromCombined.questions.isNotEmpty) {
      AppLogService.instance.warn(
        'Batch parse recovered from combined output: '
        '${fromCombined.notes.length} notes, '
        '${fromCombined.questions.length} questions',
        source: 'semantic-index',
        data: {'batch': batch},
      );
      return fromCombined;
    }

    AppLogService.instance.warn(
      'Batch parse empty — no notes/questions in answer or steps '
      '(answerChars=${result.answer.length}, steps=${result.steps.length})',
      source: 'semantic-index',
      data: {'batch': batch},
    );
    return fromAnswer;
  }

  ({List<IndexFileNote> notes, List<IndexQuestion> questions, bool? done})
      _parseNotesQuestions(String raw) {
    final map = _extractJsonMap(raw);
    if (map == null) {
      return (notes: const [], questions: const [], done: null);
    }

    final now = DateTime.now();
    final notes = <IndexFileNote>[];
    for (final item in (map['notes'] as List<dynamic>? ?? const [])
        .whereType<Map>()) {
      final path = (item['path'] as String?)?.trim() ?? '';
      if (path.isEmpty) continue;
      notes.add(
        IndexFileNote(
          path: path.replaceAll('\\', '/'),
          role: (item['role'] as String?)?.trim() ?? '',
          summary: (item['summary'] as String?)?.trim() ?? '',
          confidence: (item['confidence'] as String?)?.trim() ?? 'medium',
          sources: (item['sources'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
          updatedAt: now,
        ),
      );
    }

    final questions = <IndexQuestion>[];
    for (final item in (map['questions'] as List<dynamic>? ?? const [])
        .whereType<Map>()) {
      final question = (item['question'] as String?)?.trim() ?? '';
      if (question.isEmpty) continue;
      var id = (item['id'] as String?)?.trim() ?? '';
      if (id.isEmpty) id = _uuid.v4();
      questions.add(
        IndexQuestion(
          id: id,
          path: (item['path'] as String?)?.trim(),
          question: question,
          whyNeeded: (item['whyNeeded'] as String?)?.trim() ?? '',
          options: (item['options'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
        ),
      );
    }

    final done = map['done'] as bool?;
    return (notes: notes, questions: questions, done: done);
  }

  Map<String, dynamic>? _extractJsonMap(String stdout) {
    final text = stdout.trim();
    if (text.isEmpty) return null;

    try {
      final outer = jsonDecode(text);
      if (outer is Map<String, dynamic>) {
        if (outer.containsKey('notes') || outer.containsKey('questions')) {
          return outer;
        }
        final result = outer['result'] as String?;
        if (result != null && result.trim().isNotEmpty) {
          return _extractJsonMap(result);
        }
      }
    } catch (_) {}

    // Prefer the object that actually contains notes/questions when the
    // stream dumps multiple JSON blobs or prose around the payload.
    final notesKey = text.indexOf('"notes"');
    final qKey = text.indexOf('"questions"');
    final keyAt = notesKey >= 0
        ? (qKey >= 0 && qKey < notesKey ? qKey : notesKey)
        : qKey;
    if (keyAt >= 0) {
      final start = text.lastIndexOf('{', keyAt);
      final end = text.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          final sliced = jsonDecode(text.substring(start, end + 1));
          if (sliced is Map<String, dynamic>) return sliced;
        } catch (_) {}
      }
    }

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final sliced = jsonDecode(text.substring(start, end + 1));
        if (sliced is Map<String, dynamic>) return sliced;
      } catch (_) {}
    }
    return null;
  }
}
