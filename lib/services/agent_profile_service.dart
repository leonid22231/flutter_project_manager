import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/agent_profile_paths.dart';
import 'package:project_manager/core/utils/project_context_paths.dart';
import 'package:project_manager/models/agent_profile.dart';
import 'package:project_manager/models/project_knowledge.dart';
import 'package:uuid/uuid.dart';

class AgentProfileService {
  AgentProfileService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  static const _knownFileDescriptions = {
    'project-context.json':
        'Full snapshot: project data + agent memory + knowledge (auto-updated).',
    'agent-profile.json': 'Agent identity, character, skills, self-analysis.',
    'agent-memory.json': 'Learned facts and user-provided memory entries.',
    'project-knowledge.json':
        'Accumulated project knowledge: architecture, workflows, insights.',
    'logs/': 'Debug logs from Project Manager and Cursor CLI.',
    'logs/flutter_debug.log': 'Combined debug log stream.',
    'logs/build-history-': 'Build history / GitLab CI loading logs (dated).',
    'logs/cursor-cli-': 'Cursor Agent CLI operation logs (dated).',
  };

  Future<AgentProfile> loadOrCreateProfile(
    String projectRoot, {
    String languageCode = 'en',
  }) async {
    _ensureAiDir(projectRoot);
    final file = File(AgentProfilePaths.profilePath(projectRoot));
    if (!file.existsSync()) {
      final defaults = AgentProfile.defaults(languageCode: languageCode);
      await saveProfile(projectRoot, defaults);
      return defaults;
    }

    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return AgentProfile.fromJson(json);
    } catch (_) {
      final defaults = AgentProfile.defaults(languageCode: languageCode);
      await saveProfile(projectRoot, defaults);
      return defaults;
    }
  }

  Future<void> saveProfile(String projectRoot, AgentProfile profile) async {
    _ensureAiDir(projectRoot);
    final updated = profile.copyWith(updatedAt: DateTime.now());
    final file = File(AgentProfilePaths.profilePath(projectRoot));
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(updated.toJson()));
  }

  Future<AgentMemoryStore> loadMemory(String projectRoot) async {
    _ensureAiDir(projectRoot);
    final file = File(AgentProfilePaths.memoryPath(projectRoot));
    if (!file.existsSync()) {
      return const AgentMemoryStore();
    }

    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return AgentMemoryStore.fromJson(json);
    } catch (_) {
      return const AgentMemoryStore();
    }
  }

  Future<void> saveMemory(String projectRoot, AgentMemoryStore store) async {
    _ensureAiDir(projectRoot);
    final file = File(AgentProfilePaths.memoryPath(projectRoot));
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(store.toJson()));
  }

  Future<AgentMemoryEntry> addMemoryEntry(
    String projectRoot, {
    required String content,
    List<String> tags = const [],
  }) async {
    final store = await loadMemory(projectRoot);
    final entry = AgentMemoryEntry(
      id: _uuid.v4(),
      content: content.trim(),
      createdAt: DateTime.now(),
      tags: tags,
    );
    await saveMemory(
      projectRoot,
      AgentMemoryStore(entries: [...store.entries, entry]),
    );
    return entry;
  }

  Future<void> deleteMemoryEntry(String projectRoot, String entryId) async {
    final store = await loadMemory(projectRoot);
    await saveMemory(
      projectRoot,
      AgentMemoryStore(
        entries: store.entries.where((e) => e.id != entryId).toList(),
      ),
    );
  }

  Future<ProjectKnowledgeStore> loadKnowledge(String projectRoot) async {
    _ensureAiDir(projectRoot);
    final file = File(AgentProfilePaths.knowledgePath(projectRoot));
    if (!file.existsSync()) return const ProjectKnowledgeStore();

    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return ProjectKnowledgeStore.fromJson(json);
    } catch (_) {
      return const ProjectKnowledgeStore();
    }
  }

  Future<void> saveKnowledge(
    String projectRoot,
    ProjectKnowledgeStore store,
  ) async {
    _ensureAiDir(projectRoot);
    final file = File(AgentProfilePaths.knowledgePath(projectRoot));
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(store.toJson()));
  }

  Future<void> upsertKnowledgeInsight(
    String projectRoot, {
    required String topic,
    required String content,
    List<String> sources = const [],
  }) async {
    final store = await loadKnowledge(projectRoot);
    final normalizedTopic = topic.trim().toLowerCase();
    final existingIndex = store.insights.indexWhere(
      (i) => i.topic.trim().toLowerCase() == normalizedTopic,
    );

    final insight = ProjectKnowledgeInsight(
      id: existingIndex >= 0 ? store.insights[existingIndex].id : _uuid.v4(),
      topic: topic.trim(),
      content: content.trim(),
      updatedAt: DateTime.now(),
      sources: sources,
    );

    final insights = [...store.insights];
    if (existingIndex >= 0) {
      insights[existingIndex] = insight;
    } else {
      insights.add(insight);
    }

    await saveKnowledge(
      projectRoot,
      store.copyWith(
        insights: insights,
        lastEnrichedAt: DateTime.now(),
        interactionCount: store.interactionCount + 1,
      ),
    );
  }

  Future<void> mergeLearnedFacts(
    String projectRoot, {
    required List<String> memoryFacts,
    required List<Map<String, dynamic>> insights,
    String? architectureSummary,
    String? workflowsSummary,
  }) async {
    for (final fact in memoryFacts) {
      final trimmed = fact.trim();
      if (trimmed.isEmpty) continue;
      final store = await loadMemory(projectRoot);
      final exists = store.entries.any(
        (e) =>
            e.content.trim().toLowerCase() == trimmed.toLowerCase() ||
            e.content.contains(trimmed) ||
            trimmed.contains(e.content),
      );
      if (!exists) {
        await addMemoryEntry(
          projectRoot,
          content: trimmed,
          tags: const ['auto-learned'],
        );
      }
    }

    var knowledge = await loadKnowledge(projectRoot);
    if (architectureSummary != null && architectureSummary.trim().isNotEmpty) {
      knowledge = knowledge.copyWith(
        architectureSummary: architectureSummary.trim(),
      );
    }
    if (workflowsSummary != null && workflowsSummary.trim().isNotEmpty) {
      knowledge = knowledge.copyWith(workflowsSummary: workflowsSummary.trim());
    }

    for (final raw in insights) {
      final topic = raw['topic'] as String? ?? '';
      final content = raw['content'] as String? ?? '';
      if (topic.isEmpty || content.isEmpty) continue;
      final sources = (raw['sources'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      await upsertKnowledgeInsight(
        projectRoot,
        topic: topic,
        content: content,
        sources: sources,
      );
    }

    if (architectureSummary != null || workflowsSummary != null) {
      knowledge = await loadKnowledge(projectRoot);
      await saveKnowledge(
        projectRoot,
        knowledge.copyWith(
          architectureSummary: knowledge.architectureSummary,
          workflowsSummary: knowledge.workflowsSummary,
          lastEnrichedAt: DateTime.now(),
          interactionCount: knowledge.interactionCount + 1,
        ),
      );
    }
  }

  Future<void> deleteKnowledgeInsight(String projectRoot, String id) async {
    final store = await loadKnowledge(projectRoot);
    await saveKnowledge(
      projectRoot,
      store.copyWith(
        insights: store.insights.where((i) => i.id != id).toList(),
      ),
    );
  }

  Future<List<AiFolderEntry>> scanAiFolder(String projectRoot) async {
    final dir = Directory(ProjectContextPaths.contextDir(projectRoot));
    if (!dir.existsSync()) {
      return const [];
    }

    final entries = <AiFolderEntry>[];
    await _scanDirectory(dir, projectRoot, entries);
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.relativePath.compareTo(b.relativePath);
    });
    return entries;
  }

  Future<void> _scanDirectory(
    Directory dir,
    String projectRoot,
    List<AiFolderEntry> output,
  ) async {
    final aiRoot = ProjectContextPaths.contextDir(projectRoot);

    for (final entity in dir.listSync(followLinks: false)) {
      final relative =
          p.relative(entity.path, from: aiRoot).replaceAll(r'\', '/');
      final displayPath = relative.isEmpty ? '.' : '.ai/$relative';

      if (entity is Directory) {
        output.add(
          AiFolderEntry(
            relativePath: displayPath,
            isDirectory: true,
            description: _describePath(relative),
            modifiedAt: entity.statSync().modified,
          ),
        );
        await _scanDirectory(entity, projectRoot, output);
      } else if (entity is File) {
        final stat = entity.statSync();
        output.add(
          AiFolderEntry(
            relativePath: displayPath,
            isDirectory: false,
            sizeBytes: stat.size,
            description: _describePath(relative),
            modifiedAt: stat.modified,
          ),
        );
      }
    }
  }

  String? _describePath(String relativePath) {
    final normalized = relativePath.replaceAll(r'\', '/');
    if (_knownFileDescriptions.containsKey(normalized)) {
      return _knownFileDescriptions[normalized];
    }
    for (final entry in _knownFileDescriptions.entries) {
      if (entry.key.endsWith('/') && normalized.startsWith(entry.key)) {
        return entry.value;
      }
      if (entry.key.endsWith('-') && p.basename(normalized).startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  void _ensureAiDir(String projectRoot) {
    final dir = Directory(ProjectContextPaths.contextDir(projectRoot));
    if (!dir.existsSync()) dir.createSync(recursive: true);
  }
}
