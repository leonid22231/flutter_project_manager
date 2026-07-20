import 'dart:convert';
import 'dart:io';

import 'package:project_manager/core/utils/agent_profile_paths.dart';
import 'package:project_manager/core/utils/utf8_file_io.dart';
import 'package:uuid/uuid.dart';

class LearningPendingCandidate {
  const LearningPendingCandidate({
    required this.id,
    required this.kind,
    required this.content,
    this.topic,
    this.sources = const [],
    required this.createdAt,
    this.selected = true,
  });

  /// memory | insight | architecture | workflows
  final String id;
  final String kind;
  final String content;
  final String? topic;
  final List<String> sources;
  final DateTime createdAt;
  final bool selected;

  LearningPendingCandidate copyWith({
    String? content,
    String? topic,
    bool? selected,
  }) {
    return LearningPendingCandidate(
      id: id,
      kind: kind,
      content: content ?? this.content,
      topic: topic ?? this.topic,
      sources: sources,
      createdAt: createdAt,
      selected: selected ?? this.selected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'content': content,
        'topic': topic,
        'sources': sources,
        'createdAt': createdAt.toIso8601String(),
        'selected': selected,
      };

  factory LearningPendingCandidate.fromJson(Map<String, dynamic> json) {
    return LearningPendingCandidate(
      id: json['id'] as String? ?? const Uuid().v4(),
      kind: repairUtf8Mojibake(json['kind'] as String? ?? 'memory'),
      content: repairUtf8Mojibake(json['content'] as String? ?? ''),
      topic: json['topic'] == null
          ? null
          : repairUtf8Mojibake(json['topic'].toString()),
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => repairUtf8Mojibake(e.toString()))
              .toList() ??
          const [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      selected: json['selected'] as bool? ?? true,
    );
  }
}

class LearningPendingStore {
  const LearningPendingStore({this.candidates = const []});

  final List<LearningPendingCandidate> candidates;

  bool get isEmpty => candidates.isEmpty;
  bool get isNotEmpty => candidates.isNotEmpty;

  LearningPendingStore copyWith({List<LearningPendingCandidate>? candidates}) {
    return LearningPendingStore(candidates: candidates ?? this.candidates);
  }

  Map<String, dynamic> toJson() => {
        'candidates': candidates.map((c) => c.toJson()).toList(),
      };

  factory LearningPendingStore.fromJson(Map<String, dynamic> json) {
    return LearningPendingStore(
      candidates: (json['candidates'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(LearningPendingCandidate.fromJson)
              .toList() ??
          const [],
    );
  }
}

class AgentLearningPendingService {
  AgentLearningPendingService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<LearningPendingStore> load(String projectRoot) async {
    final file = File(AgentProfilePaths.learningPendingPath(projectRoot));
    if (!file.existsSync()) return const LearningPendingStore();
    try {
      final raw = await readUtf8File(file);
      final decoded = jsonDecode(raw);
      final repaired = repairUtf8InJson(decoded);
      if (repaired is! Map<String, dynamic>) {
        return const LearningPendingStore();
      }
      final store = LearningPendingStore.fromJson(repaired);
      // Rewrite repaired content so the file stays clean on disk.
      if (looksLikeUtf8Mojibake(raw) ||
          store.candidates.any((c) => looksLikeUtf8Mojibake(c.content))) {
        await save(projectRoot, store);
      }
      return store;
    } catch (_) {
      return const LearningPendingStore();
    }
  }

  Future<void> save(String projectRoot, LearningPendingStore store) async {
    final file = File(AgentProfilePaths.learningPendingPath(projectRoot));
    file.parent.createSync(recursive: true);
    await writeUtf8File(
      file,
      const JsonEncoder.withIndent('  ').convert(store.toJson()),
    );
  }

  Future<LearningPendingStore> replaceFromLearningJson(
    String projectRoot,
    Map<String, dynamic> decoded,
  ) async {
    final cleaned = repairUtf8InJson(decoded);
    final map = cleaned is Map<String, dynamic>
        ? cleaned
        : Map<String, dynamic>.from(decoded);
    final now = DateTime.now();
    final candidates = <LearningPendingCandidate>[];

    for (final fact in (map['memory'] as List<dynamic>? ?? const [])) {
      final text = repairUtf8Mojibake(fact.toString()).trim();
      if (text.isEmpty) continue;
      candidates.add(
        LearningPendingCandidate(
          id: _uuid.v4(),
          kind: 'memory',
          content: text,
          createdAt: now,
        ),
      );
    }

    for (final raw in (map['insights'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()) {
      final topic = repairUtf8Mojibake(raw['topic'] as String? ?? '');
      final content = repairUtf8Mojibake(raw['content'] as String? ?? '');
      if (topic.isEmpty || content.isEmpty) continue;
      candidates.add(
        LearningPendingCandidate(
          id: _uuid.v4(),
          kind: 'insight',
          topic: topic,
          content: content,
          sources: (raw['sources'] as List<dynamic>?)
                  ?.map((e) => repairUtf8Mojibake(e.toString()))
                  .toList() ??
              const [],
          createdAt: now,
        ),
      );
    }

    final architecture = map['architectureSummary'] as String?;
    if (architecture != null && architecture.trim().isNotEmpty) {
      candidates.add(
        LearningPendingCandidate(
          id: _uuid.v4(),
          kind: 'architecture',
          content: repairUtf8Mojibake(architecture).trim(),
          createdAt: now,
        ),
      );
    }

    final workflows = map['workflowsSummary'] as String?;
    if (workflows != null && workflows.trim().isNotEmpty) {
      candidates.add(
        LearningPendingCandidate(
          id: _uuid.v4(),
          kind: 'workflows',
          content: repairUtf8Mojibake(workflows).trim(),
          createdAt: now,
        ),
      );
    }

    final store = LearningPendingStore(candidates: candidates);
    await save(projectRoot, store);
    return store;
  }

  Future<void> clear(String projectRoot) async {
    await save(projectRoot, const LearningPendingStore());
  }
}
