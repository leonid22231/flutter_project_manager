import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:project_manager/core/utils/user_language_utils.dart';
import 'package:project_manager/core/utils/project_context_paths.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/services/agent_profile_service.dart';
import 'package:project_manager/services/agent_context_orchestrator.dart';
import 'package:project_manager/services/analysis/cursor_cli_stream_parser.dart';
import 'package:project_manager/services/analysis/project_qa_agent_prompt.dart';
import 'package:project_manager/services/cursor_cli_logger.dart';

class ProjectQaReasoningStep {
  const ProjectQaReasoningStep({
    required this.text,
    required this.timestamp,
    this.isComplete = false,
  });

  final String text;
  final DateTime timestamp;
  final bool isComplete;

  ProjectQaReasoningStep copyWith({String? text, bool? isComplete}) {
    return ProjectQaReasoningStep(
      text: text ?? this.text,
      timestamp: timestamp,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

class ProjectQaMessage {
  const ProjectQaMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.reasoningSteps = const [],
    this.isError = false,
  });

  final String role;
  final String text;
  final DateTime timestamp;
  final List<ProjectQaReasoningStep> reasoningSteps;
  final bool isError;

  bool get isUser => role == 'user';

  ProjectQaMessage copyWith({
    String? text,
    List<ProjectQaReasoningStep>? reasoningSteps,
    bool? isError,
  }) {
    return ProjectQaMessage(
      role: role,
      text: text ?? this.text,
      timestamp: timestamp,
      reasoningSteps: reasoningSteps ?? this.reasoningSteps,
      isError: isError ?? this.isError,
    );
  }
}

class ProjectQaStreamUpdate {
  const ProjectQaStreamUpdate({
    this.partialAnswer = '',
    this.reasoningSteps = const [],
    this.isComplete = false,
    this.error,
  });

  final String partialAnswer;
  final List<ProjectQaReasoningStep> reasoningSteps;
  final bool isComplete;
  final String? error;
}

class ProjectQaResult {
  const ProjectQaResult({
    required this.answer,
    this.reasoningSteps = const [],
    this.error,
  });

  final String answer;
  final List<ProjectQaReasoningStep> reasoningSteps;
  final String? error;

  bool get isSuccess => error == null && answer.trim().isNotEmpty;
}

typedef ProjectQaStreamCallback = void Function(ProjectQaStreamUpdate update);

/// Asks Cursor Agent CLI questions about a project using `.ai/project-context.json`.
class CursorCliProjectQaService {
  CursorCliProjectQaService({
    CursorCliLogger? logger,
    AgentProfileService? agentProfileService,
    AgentContextOrchestrator? contextOrchestrator,
  })  : _log = logger ?? CursorCliLogger.instance,
        _agentProfile = agentProfileService ?? AgentProfileService(),
        _contextOrchestrator =
            contextOrchestrator ?? AgentContextOrchestrator();

  final CursorCliLogger _log;
  final AgentProfileService _agentProfile;
  final AgentContextOrchestrator _contextOrchestrator;

  Future<ProjectQaResult> ask({
    required CursorCliSettings settings,
    required String projectRoot,
    required String question,
    required String responseLanguageCode,
    ProjectContextRefreshInput? contextRefresh,
    List<ProjectQaMessage> history = const [],
    ProjectQaStreamCallback? onStreamUpdate,
  }) async {
    if (!settings.enabled) {
      return const ProjectQaResult(
        answer: '',
        error: 'Cursor CLI is disabled in settings.',
      );
    }

    final trimmed = question.trim();
    if (trimmed.isEmpty) {
      return const ProjectQaResult(answer: '', error: 'Question is empty.');
    }

    final effectiveLanguage = UserLanguageUtils.resolveResponseLanguageCode(
      question: trimmed,
      appLanguageCode: responseLanguageCode,
    );

    if (contextRefresh != null) {
      await _contextOrchestrator.refreshFullContext(
        contextRefresh,
        languageCode: effectiveLanguage,
      );
    }

    final contextPath = ProjectContextPaths.contextFilePath(projectRoot);
    if (!File(contextPath).existsSync()) {
      return const ProjectQaResult(
        answer: '',
        error: 'Project context file is missing. Regenerate it first.',
      );
    }

    final prompt = await _buildPrompt(
      projectRoot: projectRoot,
      question: trimmed,
      contextPath: contextPath,
      responseLanguageCode: effectiveLanguage,
      history: history,
    );
    final started = DateTime.now();

    _log.info(
      'Starting project Q&A via Cursor Agent.',
      source: 'analysis',
      logRoot: projectRoot,
      data: {
        'command': settings.cliCommand,
        'model': settings.defaultModel,
        'questionChars': trimmed.length,
        'historyMessages': history.length,
        'appLanguage': responseLanguageCode,
        'responseLanguage': UserLanguageUtils.resolveResponseLanguageCode(
          question: trimmed,
          appLanguageCode: responseLanguageCode,
        ),
      },
    );

    try {
      final streamResult = await _runAgentStreaming(
        projectRoot: projectRoot,
        settings: settings,
        prompt: prompt,
        onStreamUpdate: onStreamUpdate,
      );
      final elapsed = DateTime.now().difference(started).inMilliseconds;

      if (streamResult.exitCode != 0) {
        final err = _truncate(streamResult.stderr);
        _log.error(
          'Project Q&A agent exited with non-zero code.',
          source: 'analysis',
          logRoot: projectRoot,
          data: {
            'exitCode': streamResult.exitCode,
            'elapsedMs': elapsed,
            'stderr': err,
          },
        );
        return ProjectQaResult(answer: '', error: err.isEmpty ? 'Agent failed.' : err);
      }

      _log.info(
        'Project Q&A completed.',
        source: 'analysis',
        logRoot: projectRoot,
        data: {
          'elapsedMs': elapsed,
          'answerChars': streamResult.answer.length,
          'reasoningSteps': streamResult.reasoningSteps.length,
        },
      );

      if (streamResult.answer.trim().isEmpty) {
        return const ProjectQaResult(
          answer: '',
          error: 'Agent returned an empty response.',
        );
      }

      final result = ProjectQaResult(
        answer: streamResult.answer.trim(),
        reasoningSteps: streamResult.reasoningSteps,
      );

      if (contextRefresh != null) {
        _contextOrchestrator.learnFromInteraction(
          settings: settings,
          contextInput: contextRefresh,
          question: trimmed,
          answer: result.answer,
          appLanguageCode: responseLanguageCode,
        );
      }

      return result;
    } catch (e, stack) {
      _log.error(
        'Project Q&A failed: $e',
        source: 'analysis',
        logRoot: projectRoot,
        data: {'stack': _truncate(stack.toString(), 400)},
      );
      return ProjectQaResult(answer: '', error: e.toString());
    }
  }

  Future<String> _buildPrompt({
    required String projectRoot,
    required String question,
    required String contextPath,
    required String responseLanguageCode,
    required List<ProjectQaMessage> history,
  }) async {
    final profile = await _agentProfile.loadOrCreateProfile(
      projectRoot,
      languageCode: responseLanguageCode,
    );
    final memory = await _agentProfile.loadMemory(projectRoot);
    final knowledge = await _agentProfile.loadKnowledge(projectRoot);
    final aiFolder = await _agentProfile.scanAiFolder(projectRoot);

    return ProjectQaAgentPrompt.build(
      question: question,
      contextPath: contextPath,
      responseLanguageCode: responseLanguageCode,
      profile: profile,
      memory: memory,
      knowledge: knowledge,
      aiFolderEntries: aiFolder,
      history: history.map((m) => (role: m.role, text: m.text)).toList(),
    );
  }

  Future<_AgentStreamResult> _runAgentStreaming({
    required String projectRoot,
    required CursorCliSettings settings,
    required String prompt,
    ProjectQaStreamCallback? onStreamUpdate,
  }) async {
    final env = Map<String, String>.from(Platform.environment);
    if (!settings.useEnvironmentApiKey && settings.apiKey.trim().isNotEmpty) {
      env['CURSOR_API_KEY'] = settings.apiKey.trim();
    }

    final args = <String>[
      '-p',
      '--output-format',
      'stream-json',
      '--stream-partial-output',
      '--mode',
      'ask',
      '--trust',
      '--workspace',
      projectRoot,
      '--model',
      settings.defaultModel,
      prompt,
    ];

    _log.info(
      'Running project Q&A agent command.',
      source: 'analysis',
      logRoot: projectRoot,
      data: {
        'args': args.take(9).join(' '),
        'promptChars': prompt.length,
      },
    );

    final process = Platform.isWindows
        ? await Process.start(
            settings.cliCommand.trim(),
            args,
            environment: env,
            runInShell: true,
          )
        : await Process.start(
            settings.cliCommand.trim(),
            args,
            environment: env,
          );

    final reasoningSteps = <ProjectQaReasoningStep>[];
    final pendingTools = <String, int>{};
    var partialAnswer = '';
    var finalAnswer = '';
    final stderrBuffer = StringBuffer();

    void emitUpdate({bool isComplete = false, String? error}) {
      onStreamUpdate?.call(
        ProjectQaStreamUpdate(
          partialAnswer: finalAnswer.isNotEmpty ? finalAnswer : partialAnswer,
          reasoningSteps: List.unmodifiable(reasoningSteps),
          isComplete: isComplete,
          error: error,
        ),
      );
    }

    final stdoutFuture = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final event = CursorCliStreamParser.parseLine(line);
      if (event == null) return;

      switch (event.kind) {
        case CursorCliStreamEventKind.textDelta:
          partialAnswer += event.text ?? '';
          emitUpdate();
        case CursorCliStreamEventKind.assistantSegment:
          final segment = event.text?.trim();
          if (segment != null && segment.isNotEmpty) {
            reasoningSteps.add(
              ProjectQaReasoningStep(
                text: segment,
                timestamp: DateTime.now(),
                isComplete: true,
              ),
            );
            emitUpdate();
          }
        case CursorCliStreamEventKind.toolStarted:
          final label = _formatToolStarted(event);
          pendingTools[event.toolPath ?? label] = reasoningSteps.length;
          reasoningSteps.add(
            ProjectQaReasoningStep(
              text: label,
              timestamp: DateTime.now(),
            ),
          );
          if (partialAnswer.trim().isNotEmpty) {
            reasoningSteps.add(
              ProjectQaReasoningStep(
                text: partialAnswer.trim(),
                timestamp: DateTime.now(),
                isComplete: true,
              ),
            );
            partialAnswer = '';
          }
          emitUpdate();
        case CursorCliStreamEventKind.toolCompleted:
          final key = event.toolPath ?? _formatToolStarted(event);
          final index = pendingTools.remove(key);
          if (index != null && index < reasoningSteps.length) {
            reasoningSteps[index] = reasoningSteps[index].copyWith(
              text: _formatToolCompleted(event),
              isComplete: true,
            );
          } else {
            reasoningSteps.add(
              ProjectQaReasoningStep(
                text: _formatToolCompleted(event),
                timestamp: DateTime.now(),
                isComplete: true,
              ),
            );
          }
          emitUpdate();
        case CursorCliStreamEventKind.result:
          finalAnswer = event.text ?? finalAnswer;
          if (event.isError) {
            emitUpdate(isComplete: true, error: finalAnswer);
          } else {
            emitUpdate(isComplete: true);
          }
      }
    });

    final stderrFuture = process.stderr.transform(utf8.decoder).listen((chunk) {
      stderrBuffer.write(chunk);
    });

    await stdoutFuture.asFuture<void>();
    await stderrFuture.asFuture<void>();
    final exitCode = await process.exitCode;

    final answer = finalAnswer.trim().isNotEmpty ? finalAnswer : partialAnswer;
    emitUpdate(isComplete: true);

    return _AgentStreamResult(
      exitCode: exitCode,
      stderr: stderrBuffer.toString(),
      answer: answer,
      reasoningSteps: reasoningSteps,
    );
  }

  String _formatToolStarted(CursorCliStreamEvent event) {
    final name = event.toolName ?? 'Tool';
    final path = event.toolPath;
    if (path != null && path.isNotEmpty) return '$name: $path';
    if (event.toolDetail != null && event.toolDetail!.isNotEmpty) {
      return '$name: ${event.toolDetail}';
    }
    return name;
  }

  String _formatToolCompleted(CursorCliStreamEvent event) {
    final base = _formatToolStarted(event);
    final detail = event.toolDetail;
    if (detail == null || detail.isEmpty) return '✓ $base';
    return '✓ $base ($detail)';
  }

  static String _truncate(String value, [int max = 240]) {
    final trimmed = value.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max)}…';
  }
}

class _AgentStreamResult {
  const _AgentStreamResult({
    required this.exitCode,
    required this.stderr,
    required this.answer,
    required this.reasoningSteps,
  });

  final int exitCode;
  final String stderr;
  final String answer;
  final List<ProjectQaReasoningStep> reasoningSteps;
}
