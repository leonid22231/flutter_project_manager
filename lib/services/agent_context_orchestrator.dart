import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:project_manager/core/utils/user_language_utils.dart';
import 'package:project_manager/models/agent_progress_step.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/models/git_repository_status.dart';
import 'package:project_manager/models/global_package_metadata.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/services/agent_profile_service.dart';
import 'package:project_manager/services/analysis/agent_learning_prompt.dart';
import 'package:project_manager/services/analysis/cursor_cli_stream_runner.dart';
import 'package:project_manager/services/cursor_cli_logger.dart';
import 'package:project_manager/services/project_context_service.dart';

typedef AgentSelfAnalysisProgressCallback = void Function(
  AgentSelfAnalysisProgress progress,
);

class ProjectContextRefreshInput {
  const ProjectContextRefreshInput({
    required this.project,
    this.gitStatus,
    this.globalPackageMetadata = const {},
  });

  final Project project;
  final GitRepositoryStatus? gitStatus;
  final Map<String, GlobalPackageMetadata> globalPackageMetadata;
}

/// Refreshes `.ai/project-context.json`, runs post-turn learning and self-analysis.
class AgentContextOrchestrator {
  AgentContextOrchestrator({
    ProjectContextService? contextService,
    AgentProfileService? agentProfileService,
    CursorCliLogger? logger,
    CursorCliStreamRunner? streamRunner,
  })  : _contextService = contextService ?? ProjectContextService(),
        _agentProfile = agentProfileService ?? AgentProfileService(),
        _log = logger ?? CursorCliLogger.instance,
        _streamRunner = streamRunner ?? CursorCliStreamRunner(logger: logger);

  static const selfAnalysisMaxDuration = Duration(minutes: 15);
  static const selfAnalysisIdleTimeout = Duration(minutes: 5);
  static const jsonAgentTimeout = Duration(minutes: 10);

  final ProjectContextService _contextService;
  final AgentProfileService _agentProfile;
  final CursorCliLogger _log;
  final CursorCliStreamRunner _streamRunner;

  bool get isSelfAnalysisRunning => _streamRunner.isRunning;

  void cancelSelfAnalysis() => _streamRunner.cancel();

  Future<ProjectContextBuildResult> refreshFullContext(
    ProjectContextRefreshInput input, {
    String languageCode = 'en',
  }) async {
    final profile = await _agentProfile.loadOrCreateProfile(
      input.project.path,
      languageCode: languageCode,
    );
    final memory = await _agentProfile.loadMemory(input.project.path);
    final knowledge = await _agentProfile.loadKnowledge(input.project.path);

    return _contextService.buildAndSave(
      project: input.project,
      gitStatus: input.gitStatus,
      globalPackageMetadata: input.globalPackageMetadata,
      agentProfile: profile,
      agentMemory: memory,
      agentKnowledge: knowledge,
    );
  }

  Future<void> learnFromInteraction({
    required CursorCliSettings settings,
    required ProjectContextRefreshInput contextInput,
    required String question,
    required String answer,
    required String appLanguageCode,
  }) async {
    if (!settings.enabled) return;

    final projectRoot = contextInput.project.path;
    final languageCode = UserLanguageUtils.resolveResponseLanguageCode(
      question: question,
      appLanguageCode: appLanguageCode,
    );

    _log.info(
      'Starting post-turn learning pass.',
      source: 'agent-learn',
      logRoot: projectRoot,
    );

    final prompt = AgentLearningPrompt.buildLearningPrompt(
      question: question,
      answer: answer,
      languageCode: languageCode,
    );

    final raw = await _runJsonAgent(
      projectRoot: projectRoot,
      settings: settings,
      prompt: prompt,
    );
    if (raw == null) {
      await refreshFullContext(contextInput, languageCode: languageCode);
      return;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final memoryFacts = (decoded['memory'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      final insights = (decoded['insights'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [];

      await _agentProfile.mergeLearnedFacts(
        projectRoot,
        memoryFacts: memoryFacts,
        insights: insights,
        architectureSummary: decoded['architectureSummary'] as String?,
        workflowsSummary: decoded['workflowsSummary'] as String?,
      );

      _log.info(
        'Learning pass saved facts.',
        source: 'agent-learn',
        logRoot: projectRoot,
        data: {
          'memoryFacts': memoryFacts.length,
          'insights': insights.length,
        },
      );
    } catch (e) {
      _log.warn(
        'Failed to parse learning JSON: $e',
        source: 'agent-learn',
        logRoot: projectRoot,
      );
    }

    await refreshFullContext(contextInput, languageCode: languageCode);
  }

  Future<AgentSelfAnalysisResult> runSelfAnalysis({
    required CursorCliSettings settings,
    required ProjectContextRefreshInput contextInput,
    required String appLanguageCode,
    AgentSelfAnalysisProgressCallback? onProgress,
  }) async {
    final languageCode = UserLanguageUtils.resolveResponseLanguageCode(
      question: 'анализ агента',
      appLanguageCode: appLanguageCode,
    );
    final steps = <AgentProgressStep>[];
    var partialOutput = '';

    void emit({bool isRunning = true}) {
      onProgress?.call(
        AgentSelfAnalysisProgress(
          steps: List.unmodifiable(steps),
          partialOutput: partialOutput,
          isRunning: isRunning,
        ),
      );
    }

    void addStep(String text, {bool complete = true, bool error = false}) {
      steps.add(
        AgentProgressStep(
          text: text,
          timestamp: DateTime.now(),
          isComplete: complete,
          isError: error,
        ),
      );
      emit();
    }

    void markLastComplete() {
      if (steps.isEmpty) return;
      final last = steps.last;
      steps[steps.length - 1] = last.copyWith(isComplete: true);
      emit();
    }

    if (!settings.enabled) {
      addStep(_msg(languageCode, 'Cursor CLI отключён в настройках.', 'Cursor CLI is disabled in settings.'), error: true);
      emit(isRunning: false);
      return AgentSelfAnalysisResult(
        error: _msg(languageCode, 'Включите Cursor CLI в настройках.', 'Enable Cursor CLI in settings.'),
        steps: List.unmodifiable(steps),
      );
    }

    final projectRoot = contextInput.project.path;

    addStep(
      _msg(languageCode, 'Обновление `.ai/project-context.json`…', 'Refreshing `.ai/project-context.json`…'),
      complete: false,
    );
    try {
      await refreshFullContext(contextInput, languageCode: appLanguageCode);
      markLastComplete();
    } catch (e) {
      steps[steps.length - 1] = steps.last.copyWith(
        text: _msg(languageCode, 'Ошибка обновления контекста: $e', 'Context refresh failed: $e'),
        isComplete: true,
        isError: true,
      );
      emit(isRunning: false);
      return AgentSelfAnalysisResult(
        error: e.toString(),
        steps: List.unmodifiable(steps),
      );
    }

    final prompt = AgentLearningPrompt.buildSelfAnalysisPrompt(
      languageCode: languageCode,
    );

    addStep(
      _msg(
        languageCode,
        'Запуск Cursor Agent (лимит ${selfAnalysisMaxDuration.inMinutes} мин, простой ${selfAnalysisIdleTimeout.inMinutes} мин)…',
        'Starting Cursor Agent (limit ${selfAnalysisMaxDuration.inMinutes} min, idle ${selfAnalysisIdleTimeout.inMinutes} min)…',
      ),
      complete: false,
    );

    final streamResult = await _streamRunner.run(
      projectRoot: projectRoot,
      settings: settings,
      prompt: prompt,
      logSource: 'agent-learn',
      maxDuration: selfAnalysisMaxDuration,
      idleTimeout: selfAnalysisIdleTimeout,
      onProgress: (cliSteps, partial) {
        partialOutput = partial;
        final combined = <AgentProgressStep>[...steps, ...cliSteps];
        onProgress?.call(
          AgentSelfAnalysisProgress(
            steps: List.unmodifiable(combined),
            partialOutput: partialOutput,
            isRunning: true,
          ),
        );
      },
    );

    markLastComplete();

    if (streamResult.cancelled) {
      addStep(
        _msg(languageCode, 'Самоанализ отменён.', 'Self-analysis cancelled.'),
        error: true,
      );
      emit(isRunning: false);
      return AgentSelfAnalysisResult(
        error: _msg(languageCode, 'Операция отменена.', 'Operation cancelled.'),
        steps: List.unmodifiable([...steps, ...streamResult.steps]),
        rawOutput: streamResult.answer,
        cancelled: true,
      );
    }

    if (streamResult.timedOut) {
      addStep(
        _msg(
          languageCode,
          'Превышен лимит времени (${selfAnalysisMaxDuration.inMinutes} мин).',
          'Time limit exceeded (${selfAnalysisMaxDuration.inMinutes} min).',
        ),
        error: true,
      );
      emit(isRunning: false);
      return AgentSelfAnalysisResult(
        error: _msg(
          languageCode,
          'Самоанализ прерван по таймауту. Упростите задачу или повторите.',
          'Self-analysis timed out. Retry or simplify.',
        ),
        steps: List.unmodifiable([...steps, ...streamResult.steps]),
        rawOutput: streamResult.answer,
        timedOut: true,
      );
    }

    if (streamResult.idleTimedOut) {
      addStep(
        _msg(
          languageCode,
          'Нет ответа от CLI ${selfAnalysisIdleTimeout.inMinutes} мин — процесс остановлен.',
          'No CLI output for ${selfAnalysisIdleTimeout.inMinutes} min — process stopped.',
        ),
        error: true,
      );
      emit(isRunning: false);
      return AgentSelfAnalysisResult(
        error: _msg(
          languageCode,
          'CLI завис без вывода. Проверьте Cursor CLI и повторите.',
          'CLI hung with no output. Check Cursor CLI and retry.',
        ),
        steps: List.unmodifiable([...steps, ...streamResult.steps]),
        rawOutput: streamResult.answer,
        idleTimedOut: true,
      );
    }

    if (streamResult.exitCode != 0) {
      final err = streamResult.stderr.trim().isNotEmpty
          ? streamResult.stderr.trim()
          : _msg(languageCode, 'Агент завершился с кодом ${streamResult.exitCode}', 'Agent exited with code ${streamResult.exitCode}');
      addStep(
        _msg(languageCode, 'Ошибка CLI: $err', 'CLI error: $err'),
        error: true,
      );
      emit(isRunning: false);
      _log.error(
        'Self-analysis CLI failed.',
        source: 'agent-learn',
        logRoot: projectRoot,
        data: {'exitCode': streamResult.exitCode, 'stderr': err},
      );
      return AgentSelfAnalysisResult(
        error: err,
        steps: List.unmodifiable([...steps, ...streamResult.steps]),
        rawOutput: streamResult.answer,
      );
    }

    addStep(
      _msg(languageCode, 'Извлечение JSON из ответа…', 'Extracting JSON from response…'),
      complete: false,
    );

    final raw = _extractJsonPayload(streamResult.answer);
    markLastComplete();

    if (raw == null || raw.trim().isEmpty) {
      final preview = _truncate(streamResult.answer, 500);
      addStep(
        _msg(
          languageCode,
          'Не удалось найти JSON в ответе агента.',
          'Could not find JSON in agent response.',
        ),
        error: true,
      );
      emit(isRunning: false);
      return AgentSelfAnalysisResult(
        error: _msg(
          languageCode,
          'Агент не вернул валидный JSON. Проверьте лог ниже.',
          'Agent did not return valid JSON. Check the log below.',
        ),
        steps: List.unmodifiable([...steps, ...streamResult.steps]),
        rawOutput: preview,
      );
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final current = await _agentProfile.loadOrCreateProfile(
        projectRoot,
        languageCode: appLanguageCode,
      );

      addStep(
        _msg(languageCode, 'Сохранение профиля…', 'Saving profile…'),
        complete: false,
      );

      final updated = current.copyWith(
        selfAnalysis: decoded['selfAnalysis'] as String? ?? current.selfAnalysis,
        skills: decoded['skills'] as String? ?? current.skills,
        capabilities: decoded['capabilities'] as String? ?? current.capabilities,
        limitations: decoded['limitations'] as String? ?? current.limitations,
        aboutSelf: decoded['aboutSelf'] as String? ?? current.aboutSelf,
        lastSelfAnalysisAt: DateTime.now(),
      );

      await _agentProfile.saveProfile(projectRoot, updated);
      markLastComplete();

      addStep(
        _msg(languageCode, 'Повторное обновление контекста…', 'Refreshing context again…'),
        complete: false,
      );
      await refreshFullContext(contextInput, languageCode: appLanguageCode);
      markLastComplete();

      addStep(
        _msg(languageCode, 'Самоанализ завершён.', 'Self-analysis complete.'),
      );
      emit(isRunning: false);

      _log.info(
        'Self-analysis completed.',
        source: 'agent-learn',
        logRoot: projectRoot,
      );

      return AgentSelfAnalysisResult(
        profile: updated,
        steps: List.unmodifiable([...steps, ...streamResult.steps]),
        rawOutput: _truncate(streamResult.answer, 2000),
      );
    } catch (e) {
      addStep(
        _msg(languageCode, 'Ошибка парсинга JSON: $e', 'JSON parse error: $e'),
        error: true,
      );
      emit(isRunning: false);
      _log.warn(
        'Self-analysis parse failed: $e',
        source: 'agent-learn',
        logRoot: projectRoot,
        data: {'raw': _truncate(raw, 300)},
      );
      return AgentSelfAnalysisResult(
        error: e.toString(),
        steps: List.unmodifiable([...steps, ...streamResult.steps]),
        rawOutput: _truncate(streamResult.answer, 2000),
      );
    }
  }

  String _msg(String languageCode, String ru, String en) =>
      languageCode == 'ru' ? ru : en;

  String _truncate(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars)}…';
  }

  Future<String?> _runJsonAgent({
    required String projectRoot,
    required CursorCliSettings settings,
    required String prompt,
  }) async {
    final env = Map<String, String>.from(Platform.environment);
    if (!settings.useEnvironmentApiKey && settings.apiKey.trim().isNotEmpty) {
      env['CURSOR_API_KEY'] = settings.apiKey.trim();
    }

    final args = <String>[
      '-p',
      '--output-format',
      'json',
      '--mode',
      'ask',
      '--trust',
      '--workspace',
      projectRoot,
      '--model',
      settings.defaultModel,
      prompt,
    ];

    try {
      final result = Platform.isWindows
          ? await Process.run(
              settings.cliCommand.trim(),
              args,
              environment: env,
              runInShell: true,
            ).timeout(jsonAgentTimeout)
          : await Process.run(
              settings.cliCommand.trim(),
              args,
              environment: env,
            ).timeout(jsonAgentTimeout);

      if (result.exitCode != 0) {
        _log.error(
          'JSON agent failed.',
          source: 'agent-learn',
          logRoot: projectRoot,
          data: {
            'exitCode': result.exitCode,
            'stderr': result.stderr.toString(),
          },
        );
        return null;
      }

      return _extractJsonPayload(result.stdout.toString());
    } on TimeoutException {
      _log.warn(
        'JSON agent timed out after ${jsonAgentTimeout.inMinutes} min.',
        source: 'agent-learn',
        logRoot: projectRoot,
      );
      return null;
    }
  }

  String? _extractJsonPayload(String stdout) {
    final text = stdout.trim();
    if (text.isEmpty) return null;

    try {
      final outer = jsonDecode(text);
      if (outer is Map<String, dynamic>) {
        final result = outer['result'] as String?;
        if (result != null && result.trim().isNotEmpty) {
          final inner = result.trim();
          if (inner.startsWith('{')) return inner;
          final start = inner.indexOf('{');
          final end = inner.lastIndexOf('}');
          if (start != -1 && end > start) {
            return inner.substring(start, end + 1);
          }
        }
      }
    } catch (_) {}

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return null;
  }
}
