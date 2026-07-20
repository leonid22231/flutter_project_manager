import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:project_manager/models/agent_progress_step.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/services/analysis/cursor_cli_stream_parser.dart';
import 'package:project_manager/services/cursor_cli_logger.dart';

class CursorCliStreamRunResult {
  const CursorCliStreamRunResult({
    required this.exitCode,
    required this.stderr,
    required this.answer,
    required this.steps,
    this.timedOut = false,
    this.idleTimedOut = false,
    this.cancelled = false,
  });

  final int exitCode;
  final String stderr;
  final String answer;
  final List<AgentProgressStep> steps;
  final bool timedOut;
  final bool idleTimedOut;
  final bool cancelled;

  bool get failed =>
      cancelled || timedOut || idleTimedOut || exitCode != 0;
}

typedef CursorCliStreamProgressCallback = void Function(
  List<AgentProgressStep> steps,
  String partialOutput,
);

/// Runs Cursor CLI with stream-json output, watchdog timers and cancel support.
class CursorCliStreamRunner {
  CursorCliStreamRunner({CursorCliLogger? logger})
      : _log = logger ?? CursorCliLogger.instance;

  final CursorCliLogger _log;

  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  Timer? _idleTimer;
  Timer? _maxTimer;
  var _cancelRequested = false;

  bool get isRunning => _process != null;

  void cancel() {
    _cancelRequested = true;
    unawaited(_killProcess(reason: 'cancelled'));
  }

  Future<CursorCliStreamRunResult> run({
    required String projectRoot,
    required CursorCliSettings settings,
    required String prompt,
    required String logSource,
    CursorCliStreamProgressCallback? onProgress,
    Duration maxDuration = const Duration(minutes: 15),
    Duration idleTimeout = const Duration(minutes: 5),
  }) async {
    _cancelRequested = false;
    await _killProcess(reason: 'restart');

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
      'Starting Cursor CLI stream.',
      source: logSource,
      logRoot: projectRoot,
      data: {
        'model': settings.defaultModel,
        'promptChars': prompt.length,
        'maxDurationSec': maxDuration.inSeconds,
        'idleTimeoutSec': idleTimeout.inSeconds,
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
    _process = process;

    final steps = <AgentProgressStep>[];
    final pendingTools = <String, int>{};
    var partialAnswer = '';
    var finalAnswer = '';
    final stderrBuffer = StringBuffer();
    var timedOut = false;
    var idleTimedOut = false;
    var cancelled = false;

    final completer = Completer<CursorCliStreamRunResult>();

    void emitProgress() {
      onProgress?.call(
        List.unmodifiable(steps),
        finalAnswer.isNotEmpty ? finalAnswer : partialAnswer,
      );
    }

    void complete(CursorCliStreamRunResult result) {
      if (completer.isCompleted) return;
      _clearWatchdogs();
      completer.complete(result);
    }

    Future<void> finishWithExitCode(int exitCode) async {
      await _stdoutSub?.cancel();
      await _stderrSub?.cancel();
      _stdoutSub = null;
      _stderrSub = null;
      _process = null;

      final answer = finalAnswer.trim().isNotEmpty ? finalAnswer : partialAnswer;
      emitProgress();
      complete(
        CursorCliStreamRunResult(
          exitCode: exitCode,
          stderr: stderrBuffer.toString(),
          answer: answer,
          steps: steps,
          timedOut: timedOut,
          idleTimedOut: idleTimedOut,
          cancelled: cancelled,
        ),
      );
    }

    void armIdleTimer() {
      _idleTimer?.cancel();
      _idleTimer = Timer(idleTimeout, () async {
        if (completer.isCompleted) return;
        idleTimedOut = true;
        _log.warn(
          'Cursor CLI idle timeout (${idleTimeout.inMinutes} min without output).',
          source: logSource,
          logRoot: projectRoot,
        );
        await _killProcess(reason: 'idle-timeout');
      });
    }

    _maxTimer = Timer(maxDuration, () async {
      if (completer.isCompleted) return;
      timedOut = true;
      _log.warn(
        'Cursor CLI max duration timeout (${maxDuration.inMinutes} min).',
        source: logSource,
        logRoot: projectRoot,
      );
      await _killProcess(reason: 'max-timeout');
    });
    armIdleTimer();

    _stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        armIdleTimer();
        final event = CursorCliStreamParser.parseLine(line);
        if (event == null) return;

        switch (event.kind) {
          case CursorCliStreamEventKind.textDelta:
            partialAnswer += event.text ?? '';
            emitProgress();
          case CursorCliStreamEventKind.assistantSegment:
            final segment = event.text?.trim();
            if (segment != null && segment.isNotEmpty) {
              steps.add(
                AgentProgressStep(
                  text: segment,
                  timestamp: DateTime.now(),
                  isComplete: true,
                ),
              );
              emitProgress();
            }
          case CursorCliStreamEventKind.toolStarted:
            final label = _formatToolStarted(event);
            pendingTools[event.toolPath ?? label] = steps.length;
            steps.add(
              AgentProgressStep(
                text: label,
                timestamp: DateTime.now(),
              ),
            );
            if (partialAnswer.trim().isNotEmpty) {
              steps.add(
                AgentProgressStep(
                  text: partialAnswer.trim(),
                  timestamp: DateTime.now(),
                  isComplete: true,
                ),
              );
              partialAnswer = '';
            }
            emitProgress();
          case CursorCliStreamEventKind.toolCompleted:
            final key = event.toolPath ?? _formatToolStarted(event);
            final index = pendingTools.remove(key);
            if (index != null && index < steps.length) {
              steps[index] = steps[index].copyWith(
                text: _formatToolCompleted(event),
                isComplete: true,
              );
            } else {
              steps.add(
                AgentProgressStep(
                  text: _formatToolCompleted(event),
                  timestamp: DateTime.now(),
                  isComplete: true,
                ),
              );
            }
            emitProgress();
          case CursorCliStreamEventKind.result:
            finalAnswer = event.text ?? finalAnswer;
            emitProgress();
        }
      },
      onError: (Object error) {
        stderrBuffer.writeln(error);
      },
      onDone: () {},
      cancelOnError: false,
    );

    _stderrSub = process.stderr.transform(utf8.decoder).listen(
      (chunk) {
        armIdleTimer();
        stderrBuffer.write(chunk);
      },
      onError: (Object error) {
        stderrBuffer.writeln(error);
      },
      cancelOnError: false,
    );

    process.exitCode.then((exitCode) async {
      cancelled = _cancelRequested;
      await finishWithExitCode(exitCode);
    });

    return completer.future;
  }

  Future<void> _killProcess({required String reason}) async {
    _clearWatchdogs();
    final process = _process;
    if (process == null) return;

    _log.info(
      'Stopping Cursor CLI process ($reason).',
      source: 'cursor-cli-runner',
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

  void _clearWatchdogs() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _maxTimer?.cancel();
    _maxTimer = null;
  }

  String _formatToolStarted(CursorCliStreamEvent event) {
    final name = event.toolName ?? 'Tool';
    final path = event.toolPath;
    if (path != null && path.isNotEmpty) return '$name: `$path`';
    if (event.toolDetail != null && event.toolDetail!.isNotEmpty) {
      return '$name: ${event.toolDetail}';
    }
    return name;
  }

  String _formatToolCompleted(CursorCliStreamEvent event) {
    final started = _formatToolStarted(event);
    final ms = event.durationMs;
    if (ms != null) return '$started ✓ (${ms}ms)';
    return '$started ✓';
  }
}
