import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/project_context_paths.dart';

/// Paths for per-project agent identity, memory, and `.ai` workspace files.
class AgentProfilePaths {
  AgentProfilePaths._();

  static const profileFileName = 'agent-profile.json';
  static const memoryFileName = 'agent-memory.json';
  static const memoriesDiaryFileName = 'memories.json';
  static const knowledgeFileName = 'project-knowledge.json';
  static const chatHistoryFileName = 'chat-history.jsonl';
  static const learningPendingFileName = 'learning-pending.json';
  static const indexMetaFileName = 'index-meta.json';
  static const indexDirName = 'index';
  static const indexFileNotesFileName = 'file-notes.json';
  static const indexOpenQuestionsFileName = 'open-questions.json';
  static const indexAnswersFileName = 'answers.json';
  static const indexSessionFileName = 'index-session.json';

  static String aiDir(String projectRoot) =>
      ProjectContextPaths.contextDir(projectRoot);

  static String profilePath(String projectRoot) =>
      p.join(aiDir(projectRoot), profileFileName);

  static String memoryPath(String projectRoot) =>
      p.join(aiDir(projectRoot), memoryFileName);

  static String memoriesDiaryPath(String projectRoot) =>
      p.join(aiDir(projectRoot), memoriesDiaryFileName);

  static String knowledgePath(String projectRoot) =>
      p.join(aiDir(projectRoot), knowledgeFileName);

  static String chatHistoryPath(String projectRoot) =>
      p.join(aiDir(projectRoot), chatHistoryFileName);

  static String learningPendingPath(String projectRoot) =>
      p.join(aiDir(projectRoot), learningPendingFileName);

  static String indexMetaPath(String projectRoot) =>
      p.join(aiDir(projectRoot), indexMetaFileName);

  static String indexDir(String projectRoot) =>
      p.join(aiDir(projectRoot), indexDirName);

  static String indexFileNotesPath(String projectRoot) =>
      p.join(indexDir(projectRoot), indexFileNotesFileName);

  static String indexOpenQuestionsPath(String projectRoot) =>
      p.join(indexDir(projectRoot), indexOpenQuestionsFileName);

  static String indexAnswersPath(String projectRoot) =>
      p.join(indexDir(projectRoot), indexAnswersFileName);

  static String indexSessionPath(String projectRoot) =>
      p.join(indexDir(projectRoot), indexSessionFileName);
}
