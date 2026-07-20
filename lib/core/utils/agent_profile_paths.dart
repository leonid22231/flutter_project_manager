import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/project_context_paths.dart';

/// Paths for per-project agent identity, memory, and `.ai` workspace files.
class AgentProfilePaths {
  AgentProfilePaths._();

  static const profileFileName = 'agent-profile.json';
  static const memoryFileName = 'agent-memory.json';
  static const knowledgeFileName = 'project-knowledge.json';

  static String aiDir(String projectRoot) =>
      ProjectContextPaths.contextDir(projectRoot);

  static String profilePath(String projectRoot) =>
      p.join(aiDir(projectRoot), profileFileName);

  static String memoryPath(String projectRoot) =>
      p.join(aiDir(projectRoot), memoryFileName);

  static String knowledgePath(String projectRoot) =>
      p.join(aiDir(projectRoot), knowledgeFileName);
}
