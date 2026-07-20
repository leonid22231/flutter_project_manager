import 'dart:convert';

enum CursorCliStreamEventKind {
  textDelta,
  assistantSegment,
  toolStarted,
  toolCompleted,
  result,
}

class CursorCliStreamEvent {
  const CursorCliStreamEvent({
    required this.kind,
    this.text,
    this.toolName,
    this.toolPath,
    this.toolDetail,
    this.durationMs,
    this.isError = false,
  });

  final CursorCliStreamEventKind kind;
  final String? text;
  final String? toolName;
  final String? toolPath;
  final String? toolDetail;
  final int? durationMs;
  final bool isError;
}

/// Parses NDJSON lines from `cursor agent --output-format stream-json`.
class CursorCliStreamParser {
  const CursorCliStreamParser._();

  static CursorCliStreamEvent? parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    Map<String, dynamic> obj;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) return null;
      obj = decoded;
    } catch (_) {
      return null;
    }

    return switch (obj['type']) {
      'assistant' => _parseAssistant(obj),
      'tool_call' => _parseToolCall(obj),
      'result' => _parseResult(obj),
      _ => null,
    };
  }

  static CursorCliStreamEvent? _parseAssistant(Map<String, dynamic> obj) {
    final text = _extractAssistantText(obj);
    if (text.isEmpty) return null;

    final hasTimestamp = obj.containsKey('timestamp_ms');
    final hasModelCallId = obj.containsKey('model_call_id');

    if (hasTimestamp && !hasModelCallId) {
      return CursorCliStreamEvent(kind: CursorCliStreamEventKind.textDelta, text: text);
    }
    if (!hasTimestamp && !hasModelCallId) {
      return CursorCliStreamEvent(
        kind: CursorCliStreamEventKind.assistantSegment,
        text: text,
      );
    }
    return null;
  }

  static CursorCliStreamEvent? _parseToolCall(Map<String, dynamic> obj) {
    final subtype = obj['subtype'] as String?;
    final toolCall = obj['tool_call'];
    if (toolCall is! Map<String, dynamic>) return null;

    final read = toolCall['readToolCall'];
    if (read is Map<String, dynamic>) {
      final path = _readPath(read['args']);
      if (subtype == 'started') {
        return CursorCliStreamEvent(
          kind: CursorCliStreamEventKind.toolStarted,
          toolName: 'Read',
          toolPath: path,
        );
      }
      if (subtype == 'completed') {
        final detail = _readToolResult(read['result']);
        return CursorCliStreamEvent(
          kind: CursorCliStreamEventKind.toolCompleted,
          toolName: 'Read',
          toolPath: path,
          toolDetail: detail,
        );
      }
    }

    final write = toolCall['writeToolCall'];
    if (write is Map<String, dynamic>) {
      final path = _readPath(write['args']);
      if (subtype == 'started') {
        return CursorCliStreamEvent(
          kind: CursorCliStreamEventKind.toolStarted,
          toolName: 'Write',
          toolPath: path,
        );
      }
      if (subtype == 'completed') {
        final detail = _writeToolResult(write['result']);
        return CursorCliStreamEvent(
          kind: CursorCliStreamEventKind.toolCompleted,
          toolName: 'Write',
          toolPath: path,
          toolDetail: detail,
        );
      }
    }

    final function = toolCall['function'];
    if (function is Map<String, dynamic> && subtype == 'started') {
      return CursorCliStreamEvent(
        kind: CursorCliStreamEventKind.toolStarted,
        toolName: function['name'] as String? ?? 'Tool',
        toolDetail: function['arguments']?.toString(),
      );
    }

    return null;
  }

  static CursorCliStreamEvent? _parseResult(Map<String, dynamic> obj) {
    if (obj['subtype'] != 'success') {
      return CursorCliStreamEvent(
        kind: CursorCliStreamEventKind.result,
        text: obj['result'] as String? ?? '',
        isError: obj['is_error'] == true,
      );
    }

    return CursorCliStreamEvent(
      kind: CursorCliStreamEventKind.result,
      text: obj['result'] as String? ?? '',
      durationMs: obj['duration_ms'] as int?,
    );
  }

  static String _extractAssistantText(Map<String, dynamic> obj) {
    final message = obj['message'];
    if (message is! Map<String, dynamic>) return '';

    final content = message['content'];
    if (content is! List) return '';

    final buffer = StringBuffer();
    for (final item in content) {
      if (item is Map<String, dynamic> && item['type'] == 'text') {
        buffer.write(item['text'] as String? ?? '');
      }
    }
    return buffer.toString();
  }

  static String? _readPath(Object? args) {
    if (args is Map<String, dynamic>) {
      return args['path'] as String?;
    }
    return null;
  }

  static String? _readToolResult(Object? result) {
    if (result is! Map<String, dynamic>) return null;
    final success = result['success'];
    if (success is! Map<String, dynamic>) return null;
    final lines = success['totalLines'];
    if (lines is int) return '$lines lines';
    return null;
  }

  static String? _writeToolResult(Object? result) {
    if (result is! Map<String, dynamic>) return null;
    final success = result['success'];
    if (success is! Map<String, dynamic>) return null;
    final lines = success['linesCreated'];
    if (lines is int) return '$lines lines';
    return null;
  }
}
