import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Persistent + in-memory log for Cursor Agent CLI operations.
class CursorCliLogger extends ChangeNotifier {
  CursorCliLogger._();

  static final CursorCliLogger instance = CursorCliLogger._();

  static const _maxMemoryEntries = 200;

  final List<CursorCliLogEntry> _entries = [];

  List<CursorCliLogEntry> get recentEntries =>
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
    notifyListeners();
  }

  void _write(
    String level,
    String message, {
    String? source,
    String? logRoot,
    Map<String, Object?>? data,
  }) {
    final entry = CursorCliLogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source ?? 'cursor-cli',
      message: message,
      data: data,
    );
    _entries.add(entry);
    if (_entries.length > _maxMemoryEntries) {
      _entries.removeRange(0, _entries.length - _maxMemoryEntries);
    }
    _appendToFile(entry, logRoot: logRoot);
    notifyListeners();
  }

  void _appendToFile(CursorCliLogEntry entry, {String? logRoot}) {
    try {
      final base = logRoot ?? Directory.current.path;
      final logsDir = Directory(p.join(base, '.ai', 'logs'));
      if (!logsDir.existsSync()) logsDir.createSync(recursive: true);
      final fileName =
          'cursor-cli-${entry.timestamp.toIso8601String().substring(0, 10)}.log';
      final file = File(p.join(logsDir.path, fileName));
      file.writeAsStringSync('${entry.format()}\n', mode: FileMode.append);
    } catch (_) {
      // Logging must not break analysis.
    }
  }
}

class CursorCliLogEntry {
  const CursorCliLogEntry({
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
