import 'dart:async';

import 'package:flutter/foundation.dart';

/// Unified in-app log bus for the whole Project Manager UI overlay.
class AppLogService extends ChangeNotifier {
  AppLogService._();

  static final AppLogService instance = AppLogService._();

  static const maxEntries = 800;

  /// Coalesce UI rebuilds — flooding notifyListeners during semantic-index
  /// THINK spam triggers mouse_tracker / MediaQuery descendant assertions.
  static const _notifyThrottle = Duration(milliseconds: 120);

  final List<AppLogEntry> _entries = [];
  var _overlayVisible = false;
  String _filterSource = '';
  String _filterLevel = '';
  Timer? _notifyTimer;
  var _notifyPending = false;

  List<AppLogEntry> get entries => List.unmodifiable(_entries.reversed);

  bool get overlayVisible => _overlayVisible;

  String get filterSource => _filterSource;
  String get filterLevel => _filterLevel;

  List<AppLogEntry> get filteredEntries {
    return entries.where((e) {
      if (_filterLevel.isNotEmpty && e.level != _filterLevel) return false;
      if (_filterSource.isNotEmpty &&
          !e.source.toLowerCase().contains(_filterSource.toLowerCase())) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  void showOverlay() {
    if (_overlayVisible) return;
    _overlayVisible = true;
    _notifyNow();
  }

  void hideOverlay() {
    if (!_overlayVisible) return;
    _overlayVisible = false;
    _notifyNow();
  }

  void toggleOverlay() {
    _overlayVisible = !_overlayVisible;
    _notifyNow();
  }

  void setFilter({String? source, String? level}) {
    if (source != null) _filterSource = source;
    if (level != null) _filterLevel = level;
    _notifyNow();
  }

  void clear() {
    _entries.clear();
    _notifyNow();
  }

  void info(
    String message, {
    String source = 'app',
    Map<String, Object?>? data,
  }) =>
      add(level: 'INFO', message: message, source: source, data: data);

  void warn(
    String message, {
    String source = 'app',
    Map<String, Object?>? data,
  }) =>
      add(level: 'WARN', message: message, source: source, data: data);

  void error(
    String message, {
    String source = 'app',
    Map<String, Object?>? data,
  }) =>
      add(level: 'ERROR', message: message, source: source, data: data);

  void think(
    String message, {
    String source = 'agent',
    Map<String, Object?>? data,
  }) =>
      add(level: 'THINK', message: message, source: source, data: data);

  void add({
    required String level,
    required String message,
    String source = 'app',
    Map<String, Object?>? data,
  }) {
    final entry = AppLogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
      data: data,
    );
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    if (kDebugMode) {
      debugPrint('[${entry.level}] ${entry.source} — ${entry.message}');
    }
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_notifyPending) return;
    _notifyPending = true;
    _notifyTimer?.cancel();
    _notifyTimer = Timer(_notifyThrottle, _notifyNow);
  }

  void _notifyNow() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _notifyPending = false;
    notifyListeners();
  }
}

class AppLogEntry {
  const AppLogEntry({
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
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final buffer = StringBuffer()
      ..write(time)
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
