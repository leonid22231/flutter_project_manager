import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/agent_log_paths.dart';
import 'package:project_manager/services/app_log_service.dart';

/// Persistent + in-memory log for build history / GitLab CI loading.
/// Files land in `<logRoot>/.ai/logs/` for MCP [flutter-debug-log-fs].
class BuildHistoryLogger {
  BuildHistoryLogger._();

  static final BuildHistoryLogger instance = BuildHistoryLogger._();

  static const _maxMemoryEntries = 300;
  static const flutterDebugLogName = 'flutter_debug.log';
  static const buildHistoryLogPrefix = 'build-history';

  final List<BuildHistoryLogEntry> _entries = [];

  List<BuildHistoryLogEntry> get recentEntries =>
      List.unmodifiable(_entries.reversed);

  void info(
    String message, {
    String? source,
    String? logRoot,
    Map<String, Object?>? data,
  }) {
    _write('INFO', message, source: source, logRoot: logRoot, data: data);
  }

  void warn(
    String message, {
    String? source,
    String? logRoot,
    Map<String, Object?>? data,
  }) {
    _write('WARN', message, source: source, logRoot: logRoot, data: data);
  }

  void error(
    String message, {
    String? source,
    String? logRoot,
    Map<String, Object?>? data,
  }) {
    _write('ERROR', message, source: source, logRoot: logRoot, data: data);
  }

  void clear() {
    _entries.clear();
  }

  void _write(
    String level,
    String message, {
    String? source,
    String? logRoot,
    Map<String, Object?>? data,
  }) {
    final resolvedSource = source ?? buildHistoryLogPrefix;
    final entry = BuildHistoryLogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: resolvedSource,
      message: message,
      data: data,
    );
    _entries.add(entry);
    if (_entries.length > _maxMemoryEntries) {
      _entries.removeRange(0, _entries.length - _maxMemoryEntries);
    }
    AppLogService.instance.add(
      level: level,
      message: message,
      source: resolvedSource,
      data: data,
    );
    final line = entry.format();
    _appendToFiles(line, entry: entry, logRoot: logRoot);
    debugPrint('[build-history] $line');
  }

  void _appendToFiles(
    String line, {
    required BuildHistoryLogEntry entry,
    String? logRoot,
  }) {
    try {
      final base = _resolveLogRoot(logRoot);
      final logsDir = Directory(p.join(base, '.ai', 'logs'));
      if (!logsDir.existsSync()) logsDir.createSync(recursive: true);

      final datedName =
          '$buildHistoryLogPrefix-${entry.timestamp.toIso8601String().substring(0, 10)}.log';
      File(p.join(logsDir.path, datedName))
          .writeAsStringSync('$line\n', mode: FileMode.append);
      File(p.join(logsDir.path, flutterDebugLogName))
          .writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (_) {
      // Logging must not break history loading.
    }
  }

  String _resolveLogRoot(String? logRoot) {
    return resolveAgentLogRoot(hint: logRoot);
  }
}

class BuildHistoryLogEntry {
  const BuildHistoryLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.data,
  });

  final DateTime timestamp;
  final String level;
  final String source;
  final String message;
  final Map<String, Object?>? data;

  String format() {
    final buffer = StringBuffer()
      ..write(timestamp.toIso8601String())
      ..write(' [')
      ..write(level)
      ..write('] ')
      ..write(source)
      ..write(' — ')
      ..write(message);
    if (data != null && data!.isNotEmpty) {
      buffer.write(' | ');
      buffer.write(
        data!.entries.map((e) => '${e.key}=${e.value}').join(', '),
      );
    }
    return buffer.toString();
  }
}
