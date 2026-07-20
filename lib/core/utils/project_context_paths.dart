import 'package:path/path.dart' as p;

/// Paths for the aggregated project context consumed by Cursor CLI analysis.
class ProjectContextPaths {
  ProjectContextPaths._();

  static const contextVersion = 1;
  static const contextDirName = '.ai';
  static const contextFileName = 'project-context.json';

  static String contextFilePath(String projectRoot) =>
      p.join(projectRoot, contextDirName, contextFileName);

  static String contextDir(String projectRoot) =>
      p.join(projectRoot, contextDirName);
}
