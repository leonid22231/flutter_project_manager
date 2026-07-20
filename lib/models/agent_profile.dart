class AgentProfile {
  const AgentProfile({
    required this.name,
    required this.aboutSelf,
    required this.character,
    this.skills = '',
    this.capabilities = '',
    this.limitations = '',
    this.selfAnalysis = '',
    this.customInstructions = '',
    this.updatedAt,
    this.lastSelfAnalysisAt,
  });

  final String name;
  final String aboutSelf;
  final String character;
  final String skills;
  final String capabilities;
  final String limitations;
  final String selfAnalysis;
  final String customInstructions;
  final DateTime? updatedAt;
  final DateTime? lastSelfAnalysisAt;

  AgentProfile copyWith({
    String? name,
    String? aboutSelf,
    String? character,
    String? skills,
    String? capabilities,
    String? limitations,
    String? selfAnalysis,
    String? customInstructions,
    DateTime? updatedAt,
    DateTime? lastSelfAnalysisAt,
  }) {
    return AgentProfile(
      name: name ?? this.name,
      aboutSelf: aboutSelf ?? this.aboutSelf,
      character: character ?? this.character,
      skills: skills ?? this.skills,
      capabilities: capabilities ?? this.capabilities,
      limitations: limitations ?? this.limitations,
      selfAnalysis: selfAnalysis ?? this.selfAnalysis,
      customInstructions: customInstructions ?? this.customInstructions,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSelfAnalysisAt: lastSelfAnalysisAt ?? this.lastSelfAnalysisAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'aboutSelf': aboutSelf,
        'character': character,
        'skills': skills,
        'capabilities': capabilities,
        'limitations': limitations,
        'selfAnalysis': selfAnalysis,
        'customInstructions': customInstructions,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (lastSelfAnalysisAt != null)
          'lastSelfAnalysisAt': lastSelfAnalysisAt!.toIso8601String(),
      };

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      name: json['name'] as String? ?? '',
      aboutSelf: json['aboutSelf'] as String? ?? '',
      character: json['character'] as String? ?? '',
      skills: json['skills'] as String? ?? '',
      capabilities: json['capabilities'] as String? ?? '',
      limitations: json['limitations'] as String? ?? '',
      selfAnalysis: json['selfAnalysis'] as String? ?? '',
      customInstructions: json['customInstructions'] as String? ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      lastSelfAnalysisAt: json['lastSelfAnalysisAt'] != null
          ? DateTime.tryParse(json['lastSelfAnalysisAt'] as String)
          : null,
    );
  }

  static AgentProfile defaults({String languageCode = 'en'}) {
    if (languageCode == 'ru') {
      return AgentProfile(
        name: 'Аналитик проекта',
        aboutSelf:
            'Я AI-агент Project Manager для этого Flutter-проекта. '
            'Помогаю разбираться в архитектуре, зависимостях, виджетах, '
            'медиа, git и сборках. Работаю через Cursor Agent CLI в режиме '
            'только чтения. Мои настройки, память и логи хранятся в папке `.ai`.',
        character:
            'Точный и структурированный. Объясняю связи между частями кодовой '
            'базы. Не додумываю — опираюсь на файлы проекта и контекст. '
            'Дружелюбный, но без воды.',
        skills:
            'Анализ Flutter/Dart проектов, чтение `.ai` контекста, виджеты, '
            'зависимости, медиа, git, CI/CD сборки, рекурсивное обогащение памяти.',
        capabilities:
            'Отвечаю из накопленного контекста (.ai/project-context.json, '
            'память, база знаний). К исходникам обращаюсь только если в контексте '
            'нет данных. После каждого диалога записываю новые факты.',
        limitations:
            'Read-only режим Cursor Agent CLI — не изменяю код проекта. '
            'Не вижу runtime-состояние приложения.',
        selfAnalysis: '',
        customInstructions: '',
        updatedAt: DateTime.now(),
      );
    }

    return AgentProfile(
      name: 'Project Analyst',
      aboutSelf:
          'I am the Project Manager AI agent for this Flutter project. '
          'I help with architecture, dependencies, widgets, media, git, and builds. '
          'I run via Cursor Agent CLI in read-only mode. '
          'My settings, memory, and logs live in the `.ai` folder.',
      character:
          'Precise and structured. I explain how parts of the codebase connect. '
          'I do not guess — I rely on project files and context. '
          'Friendly but concise.',
      skills:
          'Flutter/Dart project analysis, `.ai` context, widgets, dependencies, '
          'media, git, CI builds, recursive memory enrichment.',
      capabilities:
          'Answer from accumulated context (.ai/project-context.json, memory, '
          'knowledge base). Read source only when context lacks detail. '
          'Record new facts after each conversation.',
      limitations:
          'Read-only Cursor Agent CLI — cannot modify project code. '
          'No runtime app state visibility.',
      selfAnalysis: '',
      customInstructions: '',
      updatedAt: DateTime.now(),
    );
  }
}

class AgentMemoryEntry {
  const AgentMemoryEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    this.tags = const [],
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final List<String> tags;

  AgentMemoryEntry copyWith({
    String? content,
    List<String>? tags,
  }) {
    return AgentMemoryEntry(
      id: id,
      content: content ?? this.content,
      createdAt: createdAt,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'tags': tags,
      };

  factory AgentMemoryEntry.fromJson(Map<String, dynamic> json) {
    return AgentMemoryEntry(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}

class AgentMemoryStore {
  const AgentMemoryStore({this.entries = const []});

  final List<AgentMemoryEntry> entries;

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory AgentMemoryStore.fromJson(Map<String, dynamic> json) {
    return AgentMemoryStore(
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => AgentMemoryEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class AiFolderEntry {
  const AiFolderEntry({
    required this.relativePath,
    required this.isDirectory,
    this.sizeBytes,
    this.description,
    this.modifiedAt,
  });

  final String relativePath;
  final bool isDirectory;
  final int? sizeBytes;
  final String? description;
  final DateTime? modifiedAt;
}
