/// Semantic project index: file notes, open questions, answers, session.
library;

enum IndexQuestionStatus { open, answered, skipped, unknown }

enum IndexSessionPhase {
  idle,
  snapshot,
  inventory,
  awaitingAnswers,
  deepening,
  finalized,
  cancelled,
  failed,
}

class IndexFileNote {
  const IndexFileNote({
    required this.path,
    required this.role,
    required this.summary,
    this.confidence = 'medium',
    this.sources = const [],
    required this.updatedAt,
  });

  final String path;
  final String role;
  final String summary;

  /// high | medium | low | unknown
  final String confidence;
  final List<String> sources;
  final DateTime updatedAt;

  IndexFileNote copyWith({
    String? role,
    String? summary,
    String? confidence,
    List<String>? sources,
    DateTime? updatedAt,
  }) {
    return IndexFileNote(
      path: path,
      role: role ?? this.role,
      summary: summary ?? this.summary,
      confidence: confidence ?? this.confidence,
      sources: sources ?? this.sources,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'role': role,
        'summary': summary,
        'confidence': confidence,
        'sources': sources,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory IndexFileNote.fromJson(Map<String, dynamic> json) {
    return IndexFileNote(
      path: json['path'] as String? ?? '',
      role: json['role'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      confidence: json['confidence'] as String? ?? 'medium',
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class IndexQuestion {
  const IndexQuestion({
    required this.id,
    required this.question,
    this.path,
    this.whyNeeded = '',
    this.options = const [],
    this.status = IndexQuestionStatus.open,
  });

  final String id;
  final String? path;
  final String question;
  final String whyNeeded;
  final List<String> options;
  final IndexQuestionStatus status;

  bool get isOpen => status == IndexQuestionStatus.open;

  IndexQuestion copyWith({IndexQuestionStatus? status}) {
    return IndexQuestion(
      id: id,
      path: path,
      question: question,
      whyNeeded: whyNeeded,
      options: options,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'question': question,
        'whyNeeded': whyNeeded,
        'options': options,
        'status': status.name,
      };

  factory IndexQuestion.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? 'open';
    return IndexQuestion(
      id: json['id'] as String? ?? '',
      path: json['path'] as String?,
      question: json['question'] as String? ?? '',
      whyNeeded: json['whyNeeded'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: IndexQuestionStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => IndexQuestionStatus.open,
      ),
    );
  }
}

class IndexAnswer {
  const IndexAnswer({
    required this.questionId,
    required this.answer,
    required this.createdAt,
    this.kind = 'answered',
  });

  final String questionId;
  final String answer;

  /// answered | skipped | unknown
  final String kind;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'answer': answer,
        'kind': kind,
        'createdAt': createdAt.toIso8601String(),
      };

  factory IndexAnswer.fromJson(Map<String, dynamic> json) {
    return IndexAnswer(
      questionId: json['questionId'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      kind: json['kind'] as String? ?? 'answered',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class IndexSession {
  const IndexSession({
    this.phase = IndexSessionPhase.idle,
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.currentBatch = 0,
    this.totalBatches = 0,
    this.currentFolder = '',
    this.pass = 0,
    this.error,
    this.startedAt,
    this.updatedAt,
  });

  final IndexSessionPhase phase;
  final int totalFiles;
  final int processedFiles;
  final int currentBatch;
  final int totalBatches;
  final String currentFolder;
  final int pass;
  final String? error;
  final DateTime? startedAt;
  final DateTime? updatedAt;

  bool get isActive =>
      phase == IndexSessionPhase.snapshot ||
      phase == IndexSessionPhase.inventory ||
      phase == IndexSessionPhase.awaitingAnswers ||
      phase == IndexSessionPhase.deepening;

  bool get canResume =>
      phase == IndexSessionPhase.awaitingAnswers ||
      (phase == IndexSessionPhase.failed && processedFiles > 0);

  double get progress {
    if (totalFiles <= 0) return 0;
    return (processedFiles / totalFiles).clamp(0.0, 1.0);
  }

  IndexSession copyWith({
    IndexSessionPhase? phase,
    int? totalFiles,
    int? processedFiles,
    int? currentBatch,
    int? totalBatches,
    String? currentFolder,
    int? pass,
    String? error,
    bool clearError = false,
    DateTime? startedAt,
    DateTime? updatedAt,
  }) {
    return IndexSession(
      phase: phase ?? this.phase,
      totalFiles: totalFiles ?? this.totalFiles,
      processedFiles: processedFiles ?? this.processedFiles,
      currentBatch: currentBatch ?? this.currentBatch,
      totalBatches: totalBatches ?? this.totalBatches,
      currentFolder: currentFolder ?? this.currentFolder,
      pass: pass ?? this.pass,
      error: clearError ? null : (error ?? this.error),
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'totalFiles': totalFiles,
        'processedFiles': processedFiles,
        'currentBatch': currentBatch,
        'totalBatches': totalBatches,
        'currentFolder': currentFolder,
        'pass': pass,
        'error': error,
        'startedAt': startedAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory IndexSession.fromJson(Map<String, dynamic> json) {
    final phaseName = json['phase'] as String? ?? 'idle';
    return IndexSession(
      phase: IndexSessionPhase.values.firstWhere(
        (p) => p.name == phaseName,
        orElse: () => IndexSessionPhase.idle,
      ),
      totalFiles: json['totalFiles'] as int? ?? 0,
      processedFiles: json['processedFiles'] as int? ?? 0,
      currentBatch: json['currentBatch'] as int? ?? 0,
      totalBatches: json['totalBatches'] as int? ?? 0,
      currentFolder: json['currentFolder'] as String? ?? '',
      pass: json['pass'] as int? ?? 0,
      error: json['error'] as String?,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class IndexFileNotesStore {
  const IndexFileNotesStore({this.notes = const []});

  final List<IndexFileNote> notes;

  Map<String, dynamic> toJson() => {
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  factory IndexFileNotesStore.fromJson(Map<String, dynamic> json) {
    return IndexFileNotesStore(
      notes: (json['notes'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(IndexFileNote.fromJson)
              .toList() ??
          const [],
    );
  }
}

class IndexQuestionsStore {
  const IndexQuestionsStore({this.questions = const []});

  final List<IndexQuestion> questions;

  List<IndexQuestion> get open =>
      questions.where((q) => q.isOpen).toList(growable: false);

  Map<String, dynamic> toJson() => {
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  factory IndexQuestionsStore.fromJson(Map<String, dynamic> json) {
    return IndexQuestionsStore(
      questions: (json['questions'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(IndexQuestion.fromJson)
              .toList() ??
          const [],
    );
  }
}

class IndexAnswersStore {
  const IndexAnswersStore({this.answers = const []});

  final List<IndexAnswer> answers;

  Map<String, dynamic> toJson() => {
        'answers': answers.map((a) => a.toJson()).toList(),
      };

  factory IndexAnswersStore.fromJson(Map<String, dynamic> json) {
    return IndexAnswersStore(
      answers: (json['answers'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(IndexAnswer.fromJson)
              .toList() ??
          const [],
    );
  }
}

class SemanticIndexSnapshot {
  const SemanticIndexSnapshot({
    this.notes = const IndexFileNotesStore(),
    this.questions = const IndexQuestionsStore(),
    this.answers = const IndexAnswersStore(),
    this.session = const IndexSession(),
  });

  final IndexFileNotesStore notes;
  final IndexQuestionsStore questions;
  final IndexAnswersStore answers;
  final IndexSession session;

  int get openQuestionCount => questions.open.length;
}
