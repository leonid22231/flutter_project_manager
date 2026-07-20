import 'dart:convert';
import 'dart:io';

import 'package:project_manager/core/utils/agent_profile_paths.dart';
import 'package:project_manager/core/utils/utf8_file_io.dart';
import 'package:project_manager/services/analysis/cursor_cli_project_qa_service.dart';
import 'package:uuid/uuid.dart';

class AgentChatHistoryService {
  AgentChatHistoryService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<List<ProjectQaMessage>> load(String projectRoot) async {
    final file = File(AgentProfilePaths.chatHistoryPath(projectRoot));
    if (!file.existsSync()) return const [];
    try {
      final lines = await file.readAsLines(encoding: utf8);
      final messages = <ProjectQaMessage>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        messages.add(
          ProjectQaMessage(
            role: json['role'] as String? ?? 'assistant',
            text: repairUtf8Mojibake(json['text'] as String? ?? ''),
            timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
                DateTime.now(),
            isError: json['isError'] as bool? ?? false,
          ),
        );
      }
      return messages;
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(String projectRoot, List<ProjectQaMessage> messages) async {
    final file = File(AgentProfilePaths.chatHistoryPath(projectRoot));
    file.parent.createSync(recursive: true);
    final buffer = StringBuffer();
    for (final message in messages) {
      buffer.writeln(
        jsonEncode({
          'id': _uuid.v4(),
          'role': message.role,
          'text': message.text,
          'timestamp': message.timestamp.toIso8601String(),
          'isError': message.isError,
        }),
      );
    }
    await writeUtf8File(file, buffer.toString());
  }

  Future<String> exportTranscript(
    String projectRoot,
    List<ProjectQaMessage> messages,
  ) async {
    final buffer = StringBuffer();
    for (final message in messages) {
      final who = message.isUser ? 'User' : 'Agent';
      buffer.writeln('## $who (${message.timestamp.toIso8601String()})');
      buffer.writeln(message.text);
      buffer.writeln();
    }
    final out = File(
      '${AgentProfilePaths.aiDir(projectRoot)}/chat-export-${DateTime.now().millisecondsSinceEpoch}.md',
    );
    await writeUtf8File(out, buffer.toString());
    return out.path;
  }
}
