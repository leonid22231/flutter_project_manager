import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:project_manager/core/utils/context_id_utils.dart';
import 'package:project_manager/models/project.dart';

class ProjectStorageService {
  static const _storageDirName = 'project_manager';
  static const _projectsFileName = 'projects.json';

  Future<File> _getProjectsFile() async {
    final baseDir = await _getBaseDirectory();
    return File(p.join(baseDir.path, _projectsFileName));
  }

  Future<Directory> _getBaseDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final storageDir = Directory(p.join(appDir.path, _storageDirName));
    if (!storageDir.existsSync()) {
      storageDir.createSync(recursive: true);
    }
    return storageDir;
  }

  Future<Directory> getProjectDataDirectory(String projectId) async {
    final baseDir = await _getBaseDirectory();
    final projectDir = Directory(p.join(baseDir.path, 'projects', projectId));
    if (!projectDir.existsSync()) {
      projectDir.createSync(recursive: true);
    }
    return projectDir;
  }

  Future<List<Project>> loadProjects() async {
    final file = await _getProjectsFile();
    if (!file.existsSync()) return [];

    try {
      final content = file.readAsStringSync();
      final json = jsonDecode(content) as List<dynamic>;
      var needsRewrite = false;
      final projects = <Project>[];
      for (final entry in json) {
        final map = Map<String, dynamic>.from(entry as Map);
        final rawContextId =
            (map['contextId'] as String?)?.trim().isNotEmpty == true
                ? map['contextId'] as String
                : map['id'] as String;
        if (!ContextIdUtils.isUuid(rawContextId)) {
          needsRewrite = true;
        }
        projects.add(Project.fromJson(map));
      }
      if (needsRewrite) {
        await saveProjects(projects);
      }
      return projects;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProjects(List<Project> projects) async {
    final file = await _getProjectsFile();
    final json = jsonEncode(projects.map((p) => p.toJson()).toList());
    await file.writeAsString(json);
  }

  Future<void> saveProject(Project project) async {
    final projects = await loadProjects();
    final index = projects.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      projects[index] = project;
    } else {
      projects.add(project);
    }
    await saveProjects(projects);
  }

  Future<void> deleteProject(String projectId) async {
    final projects = await loadProjects();
    projects.removeWhere((p) => p.id == projectId);
    await saveProjects(projects);

    final projectDir = await getProjectDataDirectory(projectId);
    if (projectDir.existsSync()) {
      projectDir.deleteSync(recursive: true);
    }
  }

  /// Placeholder for future code analysis artifacts.
  Future<Directory> getAnalysisDirectory(String projectId) async {
    final projectDir = await getProjectDataDirectory(projectId);
    final analysisDir = Directory(p.join(projectDir.path, 'analysis'));
    if (!analysisDir.existsSync()) {
      analysisDir.createSync(recursive: true);
    }
    return analysisDir;
  }

  /// Placeholder for future agent-driven workflow data.
  Future<Directory> getAgentWorkspaceDirectory(String projectId) async {
    final projectDir = await getProjectDataDirectory(projectId);
    final agentDir = Directory(p.join(projectDir.path, 'agent'));
    if (!agentDir.existsSync()) {
      agentDir.createSync(recursive: true);
    }
    return agentDir;
  }

  Future<Directory> getBuildsDirectory(String projectId) async {
    final projectDir = await getProjectDataDirectory(projectId);
    final buildsDir = Directory(p.join(projectDir.path, 'builds'));
    if (!buildsDir.existsSync()) {
      buildsDir.createSync(recursive: true);
    }
    return buildsDir;
  }
}
