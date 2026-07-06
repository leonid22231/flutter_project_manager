import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/build_config_resolver.dart';
import 'package:project_manager/models/project_build_config.dart';

class BuildExecutionService {
  Process? _process;
  StreamSubscription<List<int>>? _stdoutSub;
  StreamSubscription<List<int>>? _stderrSub;

  bool get isRunning => _process != null;

  Future<int> run({
    required ProjectBuildConfig config,
    required String workingDirectory,
    required void Function(String chunk) onOutput,
  }) async {
    await cancel();

    final resolvedConfig = resolveBuildConfigVariables(config, workingDirectory);
    final process = await _startProcess(
      config: resolvedConfig,
      workingDirectory: workingDirectory,
    );
    _process = process;

    void emitOutput(List<int> data) {
      if (data.isEmpty) return;
      onOutput(utf8.decode(data, allowMalformed: true));
    }

    _stdoutSub = process.stdout.listen(emitOutput);
    _stderrSub = process.stderr.listen(emitOutput);

    final exitCode = await process.exitCode;
    await _clearSubscriptions();
    _process = null;
    return exitCode;
  }

  Future<void> cancel() async {
    final process = _process;
    _process = null;
    await _clearSubscriptions();
    if (process != null) {
      process.kill(ProcessSignal.sigterm);
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
  }

  Future<Process> _startProcess({
    required ProjectBuildConfig config,
    required String workingDirectory,
  }) async {
    final cwd = _resolveWorkingDirectory(config.cwd, workingDirectory);
    if (!Directory(cwd).existsSync()) {
      throw StateError('Working directory does not exist: $cwd');
    }

    if (config.shellCommand != null && config.shellCommand!.trim().isNotEmpty) {
      final command = config.shellCommand!.trim();
      if (Platform.isWindows) {
        return Process.start(
          'cmd.exe',
          ['/c', command],
          workingDirectory: cwd,
          runInShell: false,
        );
      }
      return Process.start(
        'sh',
        ['-c', command],
        workingDirectory: cwd,
        runInShell: false,
      );
    }

    final executable = config.executable;
    if (executable == null || executable.isEmpty) {
      throw StateError('Build configuration has no executable command.');
    }

    return Process.start(
      executable,
      config.commandArgs,
      workingDirectory: cwd,
      runInShell: Platform.isWindows,
    );
  }

  String _resolveWorkingDirectory(String? cwd, String projectRoot) {
    if (cwd == null || cwd.trim().isEmpty) {
      return p.normalize(projectRoot);
    }
    final value = cwd.trim();
    if (p.isAbsolute(value)) return p.normalize(value);
    return p.normalize(p.join(projectRoot, value));
  }

  Future<void> _clearSubscriptions() async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
  }
}
