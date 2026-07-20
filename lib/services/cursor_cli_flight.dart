import 'dart:async';

import 'package:project_manager/services/analysis/cursor_cli_stream_runner.dart';
import 'package:project_manager/services/app_log_service.dart';

/// Global single-flight for Cursor CLI jobs.
///
/// Rules:
/// - at most one Cursor job app-wide;
/// - same project + job already running → skip (no duplicate);
/// - other job busy → skip (no pile-up on project switch).
class CursorCliFlight {
  CursorCliFlight._();

  static final CursorCliFlight instance = CursorCliFlight._();

  final _log = AppLogService.instance;

  String? _projectId;
  String? _job;
  CursorCliStreamRunner? _runner;
  Completer<void>? _lock;

  bool get isBusy => _lock != null && !(_lock!.isCompleted);

  String? get activeProjectId => _projectId;
  String? get activeJob => _job;

  /// Runs [action] if the gate is free. Returns `null` when skipped.
  Future<T?> run<T>({
    required String projectId,
    required String job,
    required Future<T> Function() action,
    CursorCliStreamRunner? runner,
  }) async {
    if (isBusy) {
      final same = _projectId == projectId && _job == job;
      _log.info(
        same
            ? 'Cursor skipped — same job already running'
            : 'Cursor skipped — another job is active',
        source: 'cursor-flight',
        data: {
          'activeProjectId': _projectId,
          'activeJob': _job,
          'requestedProjectId': projectId,
          'requestedJob': job,
        },
      );
      return null;
    }

    _projectId = projectId;
    _job = job;
    _runner = runner;
    _lock = Completer<void>();
    _log.info(
      'Cursor job acquired',
      source: 'cursor-flight',
      data: {'projectId': projectId, 'job': job},
    );

    try {
      return await action();
    } finally {
      _runner = null;
      _projectId = null;
      _job = null;
      final lock = _lock;
      _lock = null;
      if (lock != null && !lock.isCompleted) {
        lock.complete();
      }
      _log.info(
        'Cursor job released',
        source: 'cursor-flight',
        data: {'projectId': projectId, 'job': job},
      );
    }
  }

  /// Cancels the active stream runner (if any) when leaving a project.
  void onProjectSwitched(String? newProjectId) {
    if (!isBusy) return;
    if (_projectId == null || _projectId == newProjectId) return;
    _log.warn(
      'Cancelling Cursor job after project switch',
      source: 'cursor-flight',
      data: {
        'cancelledProjectId': _projectId,
        'cancelledJob': _job,
        'newProjectId': newProjectId,
      },
    );
    _runner?.cancel();
  }
}
