class ProjectKnowledgeInsight {
  const ProjectKnowledgeInsight({
    required this.id,
    required this.topic,
    required this.content,
    required this.updatedAt,
    this.sources = const [],
  });

  final String id;
  final String topic;
  final String content;
  final DateTime updatedAt;
  final List<String> sources;

  ProjectKnowledgeInsight copyWith({
    String? topic,
    String? content,
    DateTime? updatedAt,
    List<String>? sources,
  }) {
    return ProjectKnowledgeInsight(
      id: id,
      topic: topic ?? this.topic,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      sources: sources ?? this.sources,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
        'sources': sources,
      };

  factory ProjectKnowledgeInsight.fromJson(Map<String, dynamic> json) {
    return ProjectKnowledgeInsight(
      id: json['id'] as String,
      topic: json['topic'] as String? ?? '',
      content: json['content'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}

class ProjectKnowledgeStore {
  const ProjectKnowledgeStore({
    this.architectureSummary = '',
    this.workflowsSummary = '',
    this.insights = const [],
    this.lastEnrichedAt,
    this.interactionCount = 0,
  });

  final String architectureSummary;
  final String workflowsSummary;
  final List<ProjectKnowledgeInsight> insights;
  final DateTime? lastEnrichedAt;
  final int interactionCount;

  ProjectKnowledgeStore copyWith({
    String? architectureSummary,
    String? workflowsSummary,
    List<ProjectKnowledgeInsight>? insights,
    DateTime? lastEnrichedAt,
    int? interactionCount,
  }) {
    return ProjectKnowledgeStore(
      architectureSummary: architectureSummary ?? this.architectureSummary,
      workflowsSummary: workflowsSummary ?? this.workflowsSummary,
      insights: insights ?? this.insights,
      lastEnrichedAt: lastEnrichedAt ?? this.lastEnrichedAt,
      interactionCount: interactionCount ?? this.interactionCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'architectureSummary': architectureSummary,
        'workflowsSummary': workflowsSummary,
        'insights': insights.map((e) => e.toJson()).toList(),
        if (lastEnrichedAt != null)
          'lastEnrichedAt': lastEnrichedAt!.toIso8601String(),
        'interactionCount': interactionCount,
      };

  factory ProjectKnowledgeStore.fromJson(Map<String, dynamic> json) {
    return ProjectKnowledgeStore(
      architectureSummary: json['architectureSummary'] as String? ?? '',
      workflowsSummary: json['workflowsSummary'] as String? ?? '',
      insights: (json['insights'] as List<dynamic>?)
              ?.map(
                (e) =>
                    ProjectKnowledgeInsight.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      lastEnrichedAt: json['lastEnrichedAt'] != null
          ? DateTime.tryParse(json['lastEnrichedAt'] as String)
          : null,
      interactionCount: json['interactionCount'] as int? ?? 0,
    );
  }
}
