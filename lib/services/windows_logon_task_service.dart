import 'dart:io';

import 'package:project_manager/services/windows_logon_task.dart';

typedef SchtasksRunner = Future<ProcessResult> Function(List<String> arguments);

class WindowsLogonTaskResult {
  const WindowsLogonTaskResult({
    required this.ok,
    required this.arguments,
    this.message,
  });

  final bool ok;
  final List<String> arguments;
  final String? message;
}

class WindowsLogonTaskService {
  WindowsLogonTaskService({SchtasksRunner? run}) : _run = run;

  final SchtasksRunner? _run;

  Future<WindowsLogonTaskResult> apply({
    required bool enabled,
    required String exePath,
  }) async {
    final arguments = enabled
        ? WindowsLogonTask.createArguments(exePath)
        : WindowsLogonTask.deleteArguments();
    if (!Platform.isWindows) {
      return WindowsLogonTaskResult(
        ok: false,
        arguments: arguments,
        message: 'Windows logon task is only supported on Windows',
      );
    }

    final result = await (_run ?? _runSchtasks)(arguments);
    final text = '${result.stdout}\n${result.stderr}'.trim();
    final missingTask = !enabled && text.toLowerCase().contains('cannot find');
    final ok = result.exitCode == 0 || missingTask;
    return WindowsLogonTaskResult(
      ok: ok,
      arguments: arguments,
      message: ok ? null : (text.isEmpty ? 'schtasks exited ${result.exitCode}' : text),
    );
  }

  static Future<ProcessResult> _runSchtasks(List<String> arguments) {
    return Process.run('schtasks', arguments);
  }
}
