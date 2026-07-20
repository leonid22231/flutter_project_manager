import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/models/validation_result.dart';

class SdkCheckerService {
  Future<SdkInfo> checkSdk() async {
    final flutterResult = await _runFlutter(['--version']);
    final dartResult = await _runDart(['--version']);

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

  Future<_ProcessResult> _runFlutter(List<String> args) async {
    for (final candidate in _flutterCandidates()) {
      final result = await _runCommand(candidate, args);
      if (result.exitCode == 0) return result;
    }
    return _runCommand(Platform.isWindows ? 'flutter.bat' : 'flutter', args);
  }

  Future<_ProcessResult> _runDart(List<String> args) async {
    for (final candidate in _dartCandidates()) {
      final result = await _runCommand(candidate, args);
      if (result.exitCode == 0) return result;
    }
    return _runCommand(Platform.isWindows ? 'dart.bat' : 'dart', args);
  }

  /// PATH first, then FVM default / FLUTTER_ROOT / common installs.
  Iterable<String> _flutterCandidates() sync* {
    if (Platform.isWindows) {
      yield 'flutter.bat';
      yield 'flutter';
    } else {
      yield 'flutter';
    }

    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (home.isNotEmpty) {
      yield p.join(home, 'fvm', 'default', 'bin',
          Platform.isWindows ? 'flutter.bat' : 'flutter');
      yield p.join(home, 'fvm', 'default', 'bin', 'flutter');
    }

    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null && flutterRoot.trim().isNotEmpty) {
      yield p.join(flutterRoot.trim(), 'bin',
          Platform.isWindows ? 'flutter.bat' : 'flutter');
    }

    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      yield p.join(localAppData, 'fvm', 'default', 'bin',
          Platform.isWindows ? 'flutter.bat' : 'flutter');
    }
  }

  Iterable<String> _dartCandidates() sync* {
    if (Platform.isWindows) {
      yield 'dart.bat';
      yield 'dart';
      yield 'dart.exe';
    } else {
      yield 'dart';
    }

    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (home.isNotEmpty) {
      yield p.join(home, 'fvm', 'default', 'bin',
          Platform.isWindows ? 'dart.bat' : 'dart');
    }

    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null && flutterRoot.trim().isNotEmpty) {
      yield p.join(flutterRoot.trim(), 'bin', 'cache', 'dart-sdk', 'bin',
          Platform.isWindows ? 'dart.exe' : 'dart');
      yield p.join(flutterRoot.trim(), 'bin',
          Platform.isWindows ? 'dart.bat' : 'dart');
    }
  }

  Future<_ProcessResult> _runCommand(String executable, List<String> args) async {
    try {
      // Absolute paths: run directly. Bare names: use shell so PATH/.bat resolve.
      final isAbsolute = p.isAbsolute(executable);
      if (isAbsolute && !File(executable).existsSync()) {
        return const _ProcessResult(
          exitCode: -1,
          stdout: '',
          stderr: 'Executable not found',
        );
      }

      final result = await Process.run(
        executable,
        args,
        runInShell: !isAbsolute || Platform.isWindows,
      );
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
    this.stdout = '',
    this.stderr = '',
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
