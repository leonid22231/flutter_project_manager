import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/long_path.dart';
import 'package:project_manager/services/context_ai_merge_service.dart';
import 'package:project_manager/services/context_sync_git_service.dart';

/// Copies this machine's agent settings into `settings/cursor` of the
/// context clone, and copies the other machine's copy back.
///
/// Only skills, rules, memories.json and mcp.json. mcp.json is copied
/// whole, tokens included. Editor settings.json is not part of this set.
class WorkstationSettingsSync {
  WorkstationSettingsSync({
    ContextSyncGitService? git,
    ContextAiMergeService? merge,
  })  : _git = git,
        _merge = merge ?? ContextAiMergeService();

  static const commitMessage = 'sync: settings';
  static const directoryNames = ['skills', 'rules'];
  static const fileNames = ['memories.json', 'mcp.json'];

  final ContextSyncGitService? _git;
  final ContextAiMergeService _merge;

  /// Pulls, merges the cursor slice both ways, then commits `settings` only.
  Future<ContextSyncGitResult> sync({
    required String repoUrl,
    Directory? cursorHome,
  }) async {
    final git = _git ?? ContextSyncGitService();
    final pull = await git.pull(repoUrl);
    if (!pull.ok) return pull;

    final clone = await git.getCloneDirectory();
    final remoteCursor = Directory(p.join(clone.path, 'settings', 'cursor'));
    await mirror(
      cursorHome: cursorHome ?? defaultCursorHome(),
      settingsCursor: remoteCursor,
    );
    return git.commitSettings(repoUrl: repoUrl);
  }

  static Directory defaultCursorHome() {
    final profile = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    return Directory(p.join(profile, '.cursor'));
  }

  /// Merges [cursorHome] and [settingsCursor]. One-sided files are copied
  /// byte for byte. Does not touch sibling folders such as project UUIDs.
  Future<void> mirror({
    required Directory cursorHome,
    required Directory settingsCursor,
  }) async {
    final root = await Directory.systemTemp.createTemp('pm_settings_');
    final localSnap = Directory(p.join(root.path, 'local'));
    final remoteSnap = Directory(p.join(root.path, 'remote'));
    final merged = Directory(p.join(root.path, 'merged'));
    try {
      await _stage(cursorHome, localSnap);
      await _stage(settingsCursor, remoteSnap);
      await _merge.mergeAdditive(
        localDir: localSnap,
        remoteDir: remoteSnap,
        outputDir: merged,
      );
      await _apply(merged, cursorHome);
      await _apply(merged, settingsCursor);
    } finally {
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  }

  Future<void> _stage(Directory source, Directory dest) async {
    dest.createSync(recursive: true);
    if (!source.existsSync()) return;
    for (final name in directoryNames) {
      final from = Directory(p.join(source.path, name));
      if (!from.existsSync()) continue;
      await _copyTree(from, Directory(p.join(dest.path, name)));
    }
    for (final name in fileNames) {
      final from = File(p.join(source.path, name));
      if (!from.existsSync()) continue;
      await _copyFile(from, File(p.join(dest.path, name)));
    }
  }

  Future<void> _apply(Directory merged, Directory dest) async {
    dest.createSync(recursive: true);
    for (final name in directoryNames) {
      final from = Directory(p.join(merged.path, name));
      if (!from.existsSync()) continue;
      final target = Directory(p.join(dest.path, name));
      if (target.existsSync()) deleteTree(target);
      await _copyTree(from, target);
    }
    for (final name in fileNames) {
      final from = File(p.join(merged.path, name));
      if (!from.existsSync()) continue;
      await _copyFile(from, File(p.join(dest.path, name)));
    }
  }

  Future<void> _copyTree(Directory source, Directory dest) async {
    dest.createSync(recursive: true);
    final files = <(File, String)>[];
    walkFiles(source, (file, relative) => files.add((file, relative)));
    for (final (file, relative) in files) {
      await _copyFile(file, File(p.join(dest.path, relative)));
    }
  }

  Future<void> _copyFile(File source, File dest) async {
    dest.parent.createSync(recursive: true);
    await dest.writeAsBytes(await source.readAsBytes(), flush: true);
  }
}
