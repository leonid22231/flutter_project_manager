import 'dart:convert';
import 'dart:io';

import 'package:project_manager/models/cursor_cli_check_result.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/services/cursor_cli_logger.dart';

class CursorCliService {
  Future<CursorCliCheckResult> checkConnection(CursorCliSettings settings) async {
    final log = CursorCliLogger.instance;
    if (settings.cliCommand.trim().isEmpty) {
      log.warn('CLI command is empty.', source: 'connection');
      return const CursorCliCheckResult(
        cliAvailable: false,
        error: 'CLI command is empty.',
      );
    }

    log.info(
      'Checking Cursor CLI connection.',
      source: 'connection',
      data: {'command': settings.cliCommand.trim()},
    );

    final env = _buildEnvironment(settings);

    final versionResult = await _runCommand(
      settings.cliCommand.trim(),
      const ['--version'],
      environment: env,
    );

    if (versionResult.exitCode != 0) {
      log.error(
        'CLI version check failed.',
        source: 'connection',
        data: {'exitCode': versionResult.exitCode},
      );
      return CursorCliCheckResult(
        cliAvailable: false,
        error: _extractError(versionResult),
      );
    }

    final version = _firstLine(versionResult.stdout).trim();
    final statusResult = await _runCommand(
      settings.cliCommand.trim(),
      const ['status'],
      environment: env,
    );

    final statusText = _combineOutput(statusResult);
    final authenticated = _looksAuthenticated(statusResult, statusText);

    List<String> models = [];
    if (authenticated) {
      final modelsResult = await _runCommand(
        settings.cliCommand.trim(),
        const ['models'],
        environment: env,
      );
      if (modelsResult.exitCode == 0) {
        models = _parseModels(modelsResult.stdout);
      }
    }

    log.info(
      'Cursor CLI connected.',
      source: 'connection',
      data: {
        'version': version,
        'authenticated': authenticated,
        'models': models.length,
      },
    );

    return CursorCliCheckResult(
      cliAvailable: true,
      version: version.isEmpty ? null : version,
      authenticated: authenticated,
      statusMessage: statusText.trim().isEmpty ? null : statusText.trim(),
      availableModels: models,
      error: authenticated ? null : 'CLI found, but authentication is required.',
    );
  }

  Map<String, String> _buildEnvironment(CursorCliSettings settings) {
    final env = Map<String, String>.from(Platform.environment);
    if (!settings.useEnvironmentApiKey && settings.apiKey.trim().isNotEmpty) {
      env['CURSOR_API_KEY'] = settings.apiKey.trim();
    }
    return env;
  }

  Future<ProcessResult> _runCommand(
    String command,
    List<String> args, {
    required Map<String, String> environment,
  }) async {
    try {
      if (Platform.isWindows) {
        return Process.run(
          command,
          args,
          environment: environment,
          runInShell: true,
        );
      }

      return Process.run(
        command,
        args,
        environment: environment,
      );
    } catch (e) {
      return ProcessResult(0, 1, '', e.toString());
    }
  }

  String _extractError(ProcessResult result) {
    final stderr = result.stderr.toString().trim();
    final stdout = result.stdout.toString().trim();
    if (stderr.isNotEmpty) return stderr;
    if (stdout.isNotEmpty) return stdout;
    return 'Failed to run Cursor CLI (exit code ${result.exitCode}).';
  }

  String _firstLine(dynamic output) {
    final text = output.toString().trim();
    if (text.isEmpty) return '';
    return text.split(RegExp(r'\r?\n')).first;
  }

  String _combineOutput(ProcessResult result) {
    final stdout = result.stdout.toString().trim();
    final stderr = result.stderr.toString().trim();
    if (stdout.isEmpty) return stderr;
    if (stderr.isEmpty) return stdout;
    return '$stdout\n$stderr';
  }

  bool _looksAuthenticated(ProcessResult result, String text) {
    if (result.exitCode != 0) return false;
    final lower = text.toLowerCase();
    if (lower.contains('not logged in') ||
        lower.contains('not authenticated') ||
        lower.contains('login required')) {
      return false;
    }
    return lower.contains('logged in') ||
        lower.contains('authenticated') ||
        lower.contains('@') ||
        lower.contains('api key');
  }

  List<String> _parseModels(dynamic output) {
    final lines = output
        .toString()
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final models = <String>[];
    for (final line in lines) {
      if (line.startsWith('#') || line.toLowerCase().startsWith('model')) {
        continue;
      }

      final match = RegExp(r'^[\-\*]?\s*([a-zA-Z0-9._-]+)').firstMatch(line);
      final candidate = match?.group(1) ?? line.split(RegExp(r'\s+')).first;
      if (candidate.isNotEmpty && !models.contains(candidate)) {
        models.add(candidate);
      }
    }

    return models;
  }

  String installCommandForPlatform() {
    if (Platform.isWindows) {
      return "irm 'https://cursor.com/install?win32=true' | iex";
    }
    return 'curl https://cursor.com/install -fsS | bash';
  }

  String verifyCommand(CursorCliSettings settings) =>
      '${settings.cliCommand.trim()} --version';

  String authCommand(CursorCliSettings settings) =>
      '${settings.cliCommand.trim()} login';

  String encodeSettings(CursorCliSettings settings) =>
      jsonEncode(settings.toJson());

  CursorCliSettings decodeSettings(String raw) =>
      CursorCliSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
