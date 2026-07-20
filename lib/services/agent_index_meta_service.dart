import 'dart:convert';
import 'dart:io';

import 'package:project_manager/core/utils/agent_profile_paths.dart';
import 'package:project_manager/core/utils/project_context_paths.dart';

class AgentIndexMeta {
  const AgentIndexMeta({
    this.lastIndexedAt,
    this.contextPath,
    this.sizeBytes,
    this.includedSources = const [],
    this.excludedSources = const [],
    this.notes = '',
  });

  final DateTime? lastIndexedAt;
  final String? contextPath;
  final int? sizeBytes;
  final List<String> includedSources;
  final List<String> excludedSources;
  final String notes;

  bool get hasIndex => lastIndexedAt != null;

  bool get isStale {
    if (lastIndexedAt == null) return true;
    return DateTime.now().difference(lastIndexedAt!) > const Duration(hours: 24);
  }

  Map<String, dynamic> toJson() => {
        'lastIndexedAt': lastIndexedAt?.toIso8601String(),
        'contextPath': contextPath,
        'sizeBytes': sizeBytes,
        'includedSources': includedSources,
        'excludedSources': excludedSources,
        'notes': notes,
      };

  factory AgentIndexMeta.fromJson(Map<String, dynamic> json) {
    return AgentIndexMeta(
      lastIndexedAt:
          DateTime.tryParse(json['lastIndexedAt'] as String? ?? ''),
      contextPath: json['contextPath'] as String?,
      sizeBytes: json['sizeBytes'] as int?,
      includedSources: (json['includedSources'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      excludedSources: (json['excludedSources'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      notes: json['notes'] as String? ?? '',
    );
  }
}

class AgentIndexMetaService {
  Future<AgentIndexMeta> load(String projectRoot) async {
    final file = File(AgentProfilePaths.indexMetaPath(projectRoot));
    if (!file.existsSync()) {
      final contextFile =
          File(ProjectContextPaths.contextFilePath(projectRoot));
      if (contextFile.existsSync()) {
        final stat = contextFile.statSync();
        return AgentIndexMeta(
          lastIndexedAt: stat.modified,
          contextPath: contextFile.path,
          sizeBytes: stat.size,
          includedSources: const [
            'project-context.json',
            'agent-profile.json',
            'agent-memory.json',
            'memories.json',
            'project-knowledge.json',
          ],
        );
      }
      return const AgentIndexMeta();
    }
    try {
      return AgentIndexMeta.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AgentIndexMeta();
    }
  }

  Future<void> save(String projectRoot, AgentIndexMeta meta) async {
    final file = File(AgentProfilePaths.indexMetaPath(projectRoot));
    file.parent.createSync(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(meta.toJson()),
    );
  }

  Future<AgentIndexMeta> recordIndex({
    required String projectRoot,
    required String contextPath,
    required int sizeBytes,
    List<String> includedSources = const [
      'project-context.json',
      'agent-profile.json',
      'agent-memory.json',
      'memories.json',
      'project-knowledge.json',
      'source tree (sampled)',
    ],
    List<String> excludedSources = const [],
    String notes = '',
  }) async {
    final meta = AgentIndexMeta(
      lastIndexedAt: DateTime.now(),
      contextPath: contextPath,
      sizeBytes: sizeBytes,
      includedSources: includedSources,
      excludedSources: excludedSources,
      notes: notes,
    );
    await save(projectRoot, meta);
    return meta;
  }
}
