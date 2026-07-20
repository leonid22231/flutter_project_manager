import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/utf8_file_io.dart';

/// Prepares Cursor Agent CLI argv so long prompts do not hit Windows
/// `cmd.exe` (~8191) / CreateProcess limits ("The command line is too long").
class CursorCliPromptDelivery {
  CursorCliPromptDelivery._();

  /// Keep inline prompts short: other flags + paths already consume budget.
  static const maxInlinePromptChars = 1200;

  /// Writes [prompt] to a temp file under `.ai/logs/` when needed and returns
  /// argv ending with either the raw prompt or a short "read this file" pointer.
  static Future<CursorCliPreparedPrompt> prepare({
    required String projectRoot,
    required List<String> argsWithoutPrompt,
    required String prompt,
  }) async {
    final estimated = _estimateCommandLength(
      argsWithoutPrompt: argsWithoutPrompt,
      prompt: prompt,
    );
    final useFile = Platform.isWindows
        ? (prompt.length > maxInlinePromptChars || estimated > 7000)
        : prompt.length > 100000;

    if (!useFile) {
      return CursorCliPreparedPrompt(
        args: [...argsWithoutPrompt, prompt],
      );
    }

    final logsDir = Directory(p.join(projectRoot, '.ai', 'logs'));
    await logsDir.create(recursive: true);
    final file = File(
      p.join(
        logsDir.path,
        'cursor-prompt-${DateTime.now().millisecondsSinceEpoch}.md',
      ),
    );
    await writeUtf8File(file, prompt, flush: true);

    final pointer = [
      'Your full prompt is in this local file (read it completely and follow it):',
      file.path,
      '',
      'Treat that file contents as the entire user/system prompt.',
      'Do not ask for confirmation. Respond according to that file.',
    ].join('\n');

    return CursorCliPreparedPrompt(
      args: [...argsWithoutPrompt, pointer],
      promptFile: file,
    );
  }

  static int _estimateCommandLength({
    required List<String> argsWithoutPrompt,
    required String prompt,
  }) {
    // Rough: quoted args + spaces; shell wrapper adds more.
    var total = 64;
    for (final a in argsWithoutPrompt) {
      total += a.length + 3;
    }
    total += prompt.length + 3;
    return total;
  }
}

class CursorCliPreparedPrompt {
  const CursorCliPreparedPrompt({
    required this.args,
    this.promptFile,
  });

  final List<String> args;
  final File? promptFile;

  Future<void> cleanup() async {
    final file = promptFile;
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
