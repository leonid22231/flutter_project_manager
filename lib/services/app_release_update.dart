import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/app_version.dart';
import 'package:project_manager/services/app_log_service.dart';
import 'package:project_manager/services/context_sync_git_service.dart';

/// Looks for `version_x.x.x.zip` in the context clone.
/// A release build replaces itself when the zip is newer.
class AppReleaseUpdate {
  AppReleaseUpdate({ContextSyncGitService? git})
      : _git = git ?? ContextSyncGitService();

  final ContextSyncGitService _git;

  Future<void> check({
    required String repoUrl,
    required String currentVersion,
  }) async {
    if (kDebugMode) return;
    final current = AppVersion.parse(currentVersion);
    if (current == null || repoUrl.trim().isEmpty) return;

    final pull = await _git.pull(repoUrl);
    if (!pull.ok) {
      AppLogService.instance.warn(
        'App update check skipped — pull failed',
        source: 'app-update',
        data: {'error': pull.message},
      );
      return;
    }

    final clone = await _git.getCloneDirectory();
    final newest = _newestZip(clone);
    if (newest == null || newest.version.compareTo(current) <= 0) return;

    AppLogService.instance.info(
      'Updating app to ${newest.version}',
      source: 'app-update',
      data: {'from': currentVersion, 'zip': newest.file.path},
    );
    await _apply(newest.file);
  }

  ({File file, AppVersion version})? _newestZip(Directory root) {
    if (!root.existsSync()) return null;
    ({File file, AppVersion version})? best;
    for (final entity in root.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final match = AppVersion.zipPattern.firstMatch(p.basename(entity.path));
      if (match == null) continue;
      final version = AppVersion.parse(match.group(1)!);
      if (version == null) continue;
      if (best == null || version > best.version) {
        best = (file: entity, version: version);
      }
    }
    return best;
  }

  Future<void> _apply(File zip) async {
    final extract = await Directory.systemTemp.createTemp('pm_update_');
    final expanded = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Expand-Archive -LiteralPath \'${zip.path}\' -DestinationPath \'${extract.path}\' -Force',
      ],
    );
    if (expanded.exitCode != 0) {
      AppLogService.instance.warn(
        'App update extract failed',
        source: 'app-update',
        data: {'error': '${expanded.stderr}'},
      );
      return;
    }

    final installDir = p.dirname(Platform.resolvedExecutable);
    final script = File(p.join(extract.path, 'apply_update.cmd'));
    await script.writeAsString(_script);
    await Process.start(
      'cmd.exe',
      ['/c', 'start', '', script.path, '$pid', extract.path, installDir],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }
}

const _script = r'''@echo off
setlocal
set PID=%~1
set SRC=%~2
set DEST=%~3
:wait
tasklist /FI "PID eq %PID%" | find "%PID%" >nul
if not errorlevel 1 (
  timeout /t 1 /nobreak >nul
  goto wait
)
robocopy "%SRC%" "%DEST%" /E /XF apply_update.cmd /NFL /NDL /NJH /NJS /NC /NS >nul
start "" "%DEST%\project_manager.exe"
''';
