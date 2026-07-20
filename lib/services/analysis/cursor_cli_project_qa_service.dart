import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:project_manager/core/utils/user_language_utils.dart';
import 'package:project_manager/core/utils/project_context_paths.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/services/agent_profile_service.dart';
import 'package:project_manager/services/agent_context_orchestrator.dart';
import 'package:project_manager/services/analysis/cursor_cli_stream_parser.dart';
import 'package:project_manager/services/analysis/cursor_cli_prompt_delivery.dart';
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
    CursorCliMode mode = CursorCliMode.ask,
    bool autoLearn = true,
    String? readScope,
    String? writeScope,
    List<String> attachments = const [],
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
      mode: mode,
      readScope: readScope,
      writeScope: writeScope,
      attachments: attachments,
    );
    final started = DateTime.now();

    _log.info(
      'Starting project Q&A via Cursor Agent.',
      source: 'analysis',
      logRoot: projectRoot,
      data: {
        'command': settings.cliCommand,
        'model': settings.defaultModel,
        'mode': mode.cliValue,
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
        mode: mode,
        onStreamUpdate: onStreamUpdate,
      );
      final elapsed = DateTime.now().difference(started).inMilliseconds;

      if (streamResult.exitCode != 0 && streamResult.answer.trim().isEmpty) {
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

      if (streamResult.exitCode != 0) {
        _log.warn(
          'Project Q&A process non-zero exit but answer present — accepting.',
          source: 'analysis',
          logRoot: projectRoot,
          data: {
            'exitCode': streamResult.exitCode,
            'elapsedMs': elapsed,
            'answerChars': streamResult.answer.length,
          },
        );
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

      if (autoLearn && contextRefresh != null) {
        _contextOrchestrator.learnFromInteraction(
          settings: settings,
          contextInput: contextRefresh,
          question: trimmed,
          answer: result.answer,
          appLanguageCode: responseLanguageCode,
          saveAsPending: true,
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
    CursorCliMode mode = CursorCliMode.ask,
    String? readScope,
    String? writeScope,
    List<String> attachments = const [],
  }) async {
    final profile = await _agentProfile.loadOrCreateProfile(
      projectRoot,
      languageCode: responseLanguageCode,
    );
    final memory = await _agentProfile.loadMemory(projectRoot);
    final knowledge = await _agentProfile.loadKnowledge(projectRoot);
    final aiFolder = await _agentProfile.scanAiFolder(projectRoot);

    final scopeNotes = StringBuffer()
      ..writeln('Operating mode: ${mode.cliValue}.')
      ..writeln('Read scope: ${readScope ?? 'repo'}.')
      ..writeln('Write scope: ${writeScope ?? 'none'}.');
    if (mode == CursorCliMode.ask) {
      scopeNotes.writeln('Do not modify any files.');
    } else if (mode == CursorCliMode.plan) {
      scopeNotes.writeln('Produce a plan only. Do not modify files.');
    } else if (writeScope == 'ai') {
      scopeNotes.writeln('You may modify files only under the .ai/ folder.');
    } else if (writeScope == 'project') {
      scopeNotes.writeln('You may modify project files as needed.');
    }
    if (attachments.isNotEmpty) {
      scopeNotes.writeln('User attachments (prioritize):');
      for (final path in attachments) {
        scopeNotes.writeln('- $path');
      }
    }

    return ProjectQaAgentPrompt.build(
      question: '$question\n\n---\n${scopeNotes.toString()}',
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
    required CursorCliMode mode,
    ProjectQaStreamCallback? onStreamUpdate,
    Duration maxDuration = const Duration(minutes: 15),
    Duration idleTimeout = const Duration(minutes: 5),
    Duration resultExitGrace = const Duration(seconds: 8),
  }) async {
    final env = Map<String, String>.from(Platform.environment);
    if (!settings.useEnvironmentApiKey && settings.apiKey.trim().isNotEmpty) {
      env['CURSOR_API_KEY'] = settings.apiKey.trim();
    }

    final argsWithoutPrompt = <String>[
      '-p',
      '--output-format',
      'stream-json',
      '--stream-partial-output',
      ...mode.cliModeArgs,
      if (mode == CursorCliMode.agent) '--force',
      '--trust',
      '--workspace',
      projectRoot,
      '--model',
      settings.defaultModel,
    ];

    final prepared = await CursorCliPromptDelivery.prepare(
      projectRoot: projectRoot,
      argsWithoutPrompt: argsWithoutPrompt,
      prompt: prompt,
    );

    _log.info(
      'Running project Q&A agent command.',
      source: 'analysis',
      logRoot: projectRoot,
      data: {
        'args': prepared.args.take(9).join(' '),
        'promptChars': prompt.length,
        'promptViaFile': prepared.promptFile != null,
        if (prepared.promptFile != null)
          'promptFile': prepared.promptFile!.path.replaceAll(r'\', '/'),
        'mode': mode.cliValue,
      },
    );

    final process = Platform.isWindows
        ? await Process.start(
            settings.cliCommand.trim(),
            prepared.args,
            environment: env,
            runInShell: true,
          )
        : await Process.start(
            settings.cliCommand.trim(),
            prepared.args,
            environment: env,
          );

    _log.info(
      'Q&A process spawned (pid=${process.pid}).',
      source: 'analysis',
      logRoot: projectRoot,
    );

    final reasoningSteps = <ProjectQaReasoningStep>[];
    final pendingTools = <String, int>{};
    var partialAnswer = '';
    var finalAnswer = '';
    final stderrBuffer = StringBuffer();
    final completer = Completer<_AgentStreamResult>();
    StreamSubscription<String>? stdoutSub;
    StreamSubscription<String>? stderrSub;
    Timer? idleTimer;
    Timer? maxTimer;
    Timer? resultGraceTimer;
    Timer? heartbeatTimer;
    var gotResultEvent = false;
    var eventCount = 0;
    var lastActivity = 'spawned';
    final startedAt = DateTime.now();

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

    Future<void> killProcess(String reason) async {
      _log.warn(
        'Stopping Q&A Cursor process ($reason).',
        source: 'analysis',
        logRoot: projectRoot,
      );
      try {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      } catch (_) {
        try {
          process.kill(ProcessSignal.sigkill);
        } catch (_) {}
      }
    }

    void complete(int exitCode, {bool timedOut = false, bool idle = false}) {
      if (completer.isCompleted) return;
      idleTimer?.cancel();
      maxTimer?.cancel();
      resultGraceTimer?.cancel();
      heartbeatTimer?.cancel();
      final answer =
          finalAnswer.trim().isNotEmpty ? finalAnswer : partialAnswer;
      emitUpdate(isComplete: true);
      _log.info(
        'Q&A stream completing.',
        source: 'analysis',
        logRoot: projectRoot,
        data: {
          'exitCode': exitCode,
          'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
          'events': eventCount,
          'steps': reasoningSteps.length,
          'answerChars': answer.length,
          'gotResult': gotResultEvent,
          'lastActivity': lastActivity,
          'timedOut': timedOut,
          'idle': idle,
        },
      );
      completer.complete(
        _AgentStreamResult(
          exitCode: timedOut || idle ? (exitCode == 0 ? 1 : exitCode) : exitCode,
          stderr: stderrBuffer.toString(),
          answer: answer,
          reasoningSteps: reasoningSteps,
        ),
      );
    }

    void armIdle() {
      idleTimer?.cancel();
      idleTimer = Timer(idleTimeout, () async {
        if (completer.isCompleted) return;
        await killProcess('idle-timeout');
        complete(1, idle: true);
      });
    }

    maxTimer = Timer(maxDuration, () async {
      if (completer.isCompleted) return;
      await killProcess('max-timeout');
      complete(1, timedOut: true);
    });
    armIdle();

    heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (completer.isCompleted) return;
      final sec = DateTime.now().difference(startedAt).inSeconds;
      _log.info(
        'Q&A still working… ${sec}s',
        source: 'analysis',
        logRoot: projectRoot,
        data: {
          'lastActivity': lastActivity,
          'events': eventCount,
          'steps': reasoningSteps.length,
          'answerChars':
              (finalAnswer.isNotEmpty ? finalAnswer : partialAnswer).length,
          'gotResult': gotResultEvent,
        },
      );
    });

    stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        armIdle();
        final event = CursorCliStreamParser.parseLine(line);
        if (event == null) return;
        eventCount++;

        switch (event.kind) {
          case CursorCliStreamEventKind.textDelta:
            partialAnswer += event.text ?? '';
            lastActivity = 'textDelta';
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
              lastActivity = 'assistantSegment';
              final preview = segment.length <= 100
                  ? segment
                  : '${segment.substring(0, 100)}…';
              _log.info(
                'Q&A agent: $preview',
                source: 'analysis',
                logRoot: projectRoot,
              );
              emitUpdate();
            }
          case CursorCliStreamEventKind.toolStarted:
            final label = _formatToolStarted(event);
            lastActivity = 'tool:$label';
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
            _log.info(
              'Q&A tool start: $label',
              source: 'analysis',
              logRoot: projectRoot,
            );
            emitUpdate();
          case CursorCliStreamEventKind.toolCompleted:
            final key = event.toolPath ?? _formatToolStarted(event);
            final label = _formatToolCompleted(event);
            lastActivity = 'toolDone:$label';
            final index = pendingTools.remove(key);
            if (index != null && index < reasoningSteps.length) {
              reasoningSteps[index] = reasoningSteps[index].copyWith(
                text: label,
                isComplete: true,
              );
            } else {
              reasoningSteps.add(
                ProjectQaReasoningStep(
                  text: label,
                  timestamp: DateTime.now(),
                  isComplete: true,
                ),
              );
            }
            _log.info(
              'Q&A tool done: $label',
              source: 'analysis',
              logRoot: projectRoot,
            );
            emitUpdate();
          case CursorCliStreamEventKind.result:
            gotResultEvent = true;
            lastActivity = 'result';
            finalAnswer = event.text ?? finalAnswer;
            _log.info(
              'Q&A result received (${finalAnswer.length} chars'
              '${event.isError ? ', error' : ''}).',
              source: 'analysis',
              logRoot: projectRoot,
            );
            if (event.isError) {
              emitUpdate(isComplete: true, error: finalAnswer);
            } else {
              emitUpdate(isComplete: true);
            }
            // Cursor often keeps the process alive after the final result
            // (agent mode). Don't leave the chat spinner waiting on exit.
            resultGraceTimer?.cancel();
            resultGraceTimer = Timer(resultExitGrace, () async {
              if (completer.isCompleted) return;
              await killProcess('result-grace');
              complete(event.isError ? 1 : 0);
            });
        }
      },
      onError: (Object error) {
        stderrBuffer.writeln(error);
      },
      onDone: () {
        _log.info(
          'Q&A stdout closed.',
          source: 'analysis',
          logRoot: projectRoot,
          data: {'events': eventCount, 'gotResult': gotResultEvent},
        );
      },
      cancelOnError: false,
    );

    stderrSub = process.stderr.transform(utf8.decoder).listen(
      (chunk) {
        armIdle();
        stderrBuffer.write(chunk);
      },
      onError: (Object error) {
        stderrBuffer.writeln(error);
      },
      cancelOnError: false,
    );

    unawaited(process.exitCode.then((code) async {
      await stdoutSub?.cancel();
      await stderrSub?.cancel();
      if (completer.isCompleted) return;
      final hasAnswer =
          finalAnswer.trim().isNotEmpty || partialAnswer.trim().isNotEmpty;
      if (gotResultEvent && hasAnswer) {
        // Process may exit non-zero after we killed it post-result.
        complete(0);
        return;
      }
      if (!gotResultEvent && !hasAnswer) {
        _log.warn(
          'Q&A process exited before result event.',
          source: 'analysis',
          logRoot: projectRoot,
          data: {'exitCode': code},
        );
      }
      complete(code);
    }));

    try {
      return await completer.future;
    } finally {
      idleTimer?.cancel();
      maxTimer.cancel();
      resultGraceTimer?.cancel();
      heartbeatTimer.cancel();
      await stdoutSub.cancel();
      await stderrSub.cancel();
      await prepared.cleanup();
    }
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
