import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

Future<bool> openInVsCode(String projectPath) async {
  if (!Directory(projectPath).existsSync()) return false;

  final commands = <_VsCodeCommand>[];
  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      final codeCmd = p.join(
        localAppData,
        'Programs',
        'Microsoft VS Code',
        'bin',
        'code.cmd',
      );
      if (File(codeCmd).existsSync()) {
        commands.add(_VsCodeCommand(codeCmd, [projectPath]));
      }
    }
  }

  commands.add(_VsCodeCommand('code', [projectPath], runInShell: true));

  for (final command in commands) {
    try {
      final result = await Process.run(
        command.executable,
        command.args,
        runInShell: command.runInShell,
      );
      if (result.exitCode == 0) return true;
    } catch (_) {
      continue;
    }
  }

  return false;
}

class _VsCodeCommand {
  const _VsCodeCommand(
    this.executable,
    this.args, {
    this.runInShell = false,
  });

  final String executable;
  final List<String> args;
  final bool runInShell;
}

Future<void> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> openPathInExplorer(String path) async {
  if (!Directory(path).existsSync() && !File(path).existsSync()) return;

  if (Platform.isWindows) {
    final normalized = path.replaceAll('/', '\\');
    if (File(path).existsSync()) {
      await Process.run('explorer', ['/select,$normalized']);
    } else {
      await Process.run('explorer', [normalized]);
    }
    return;
  }

  if (Platform.isMacOS) {
    await Process.run('open', [path]);
    return;
  }

  if (Platform.isLinux) {
    await Process.run('xdg-open', [path]);
  }
}
