import 'dart:io';

import 'package:project_manager/models/validation_result.dart';

class SdkCheckerService {
  Future<SdkInfo> checkSdk() async {
    final flutterResult = await _runCommand('flutter', ['--version']);
    final dartResult = await _runCommand('dart', ['--version']);

    final flutterAvailable = flutterResult.exitCode == 0;
    final dartAvailable = dartResult.exitCode == 0;

    return SdkInfo(
      flutterAvailable: flutterAvailable,
      dartAvailable: dartAvailable,
      flutterVersion: flutterAvailable
          ? _extractFlutterVersion(flutterResult.stdout)
          : null,
      dartVersion:
          dartAvailable ? _extractDartVersion(dartResult.stdout) : null,
      flutterRawOutput: flutterResult.stdout.trim().isEmpty
          ? flutterResult.stderr
          : flutterResult.stdout,
      dartRawOutput: dartResult.stdout.trim().isEmpty
          ? dartResult.stderr
          : dartResult.stdout,
    );
  }

  Future<_ProcessResult> _runCommand(String executable, List<String> args) async {
    try {
      final result = await Process.run(executable, args, runInShell: true);
      return _ProcessResult(
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } catch (e) {
      return _ProcessResult(
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
      );
    }
  }

  String? _extractFlutterVersion(String output) {
    final match = RegExp(r'Flutter\s+([\d.]+)').firstMatch(output);
    return match?.group(1);
  }

  String? _extractDartVersion(String output) {
    final match = RegExp(r'Dart SDK version:\s*([\d.]+)').firstMatch(output);
    if (match != null) return match.group(1);

    final shortMatch = RegExp(r'Dart\s+([\d.]+)').firstMatch(output);
    return shortMatch?.group(1);
  }
}

class _ProcessResult {
  const _ProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
