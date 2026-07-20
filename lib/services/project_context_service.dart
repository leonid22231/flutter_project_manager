import 'dart:convert';
import 'dart:io';

import 'package:project_manager/core/utils/project_context_paths.dart';
import 'package:project_manager/models/git_repository_status.dart';
import 'package:project_manager/models/global_package_metadata.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/models/project_file_node.dart';
import 'package:project_manager/models/project_media_entry.dart';
import 'package:project_manager/models/widget_entry.dart';
import 'package:project_manager/models/widget_origin.dart';
import 'package:project_manager/services/project_files_service.dart';
import 'package:project_manager/services/project_media_service.dart';
import 'package:project_manager/models/agent_profile.dart';
import 'package:project_manager/models/project_knowledge.dart';
import 'package:project_manager/services/agent_profile_service.dart';
import 'package:project_manager/services/vscode_build_config_service.dart';

class ProjectContextBuildResult {
  const ProjectContextBuildResult({
    required this.filePath,
    required this.generatedAt,
    required this.sizeBytes,
    this.error,
  });

  final String filePath;
  final DateTime generatedAt;
  final int sizeBytes;
  final String? error;

  bool get isSuccess => error == null;
}

/// Aggregates all collected project metadata into `.ai/project-context.json`.
class ProjectContextService {
  ProjectContextService({
    ProjectFilesService? filesService,
    ProjectMediaService? mediaService,
    VscodeBuildConfigService? buildConfigService,
    AgentProfileService? agentProfileService,
  })  : _filesService = filesService ?? ProjectFilesService(),
        _mediaService = mediaService ?? ProjectMediaService(),
        _buildConfigService = buildConfigService ?? VscodeBuildConfigService(),
        _agentProfileService = agentProfileService ?? AgentProfileService();

  final ProjectFilesService _filesService;
  final ProjectMediaService _mediaService;
  final VscodeBuildConfigService _buildConfigService;
  final AgentProfileService _agentProfileService;

  Future<ProjectContextBuildResult> buildAndSave({
    required Project project,
    GitRepositoryStatus? gitStatus,
    Map<String, GlobalPackageMetadata> globalPackageMetadata = const {},
    AgentProfile? agentProfile,
    AgentMemoryStore? agentMemory,
    ProjectKnowledgeStore? agentKnowledge,
  }) async {
    final outputPath = ProjectContextPaths.contextFilePath(project.path);
    final generatedAt = DateTime.now();

    try {
      final profile = agentProfile ??
          await _agentProfileService.loadOrCreateProfile(project.path);
      final memory =
          agentMemory ?? await _agentProfileService.loadMemory(project.path);
      final knowledge = agentKnowledge ??
          await _agentProfileService.loadKnowledge(project.path);

      final fileTree = await _filesService.loadFileTree(project.path);
      final mediaResult = await _mediaService.scanProjectMedia(project.path);
      final buildResult = await _buildConfigService.scanProject(
        project.path,
        platforms: project.platforms,
      );

      final context = _assembleContext(
        project: project,
        gitStatus: gitStatus,
        globalPackageMetadata: globalPackageMetadata,
        fileTree: fileTree,
        mediaEntries: mediaResult.entries,
        buildConfigs: buildResult.configs
            .map(
              (c) => {
                'id': c.id,
                'name': c.name,
                'source': c.source.name,
                'mode': c.mode.name,
                'taskGroup': c.taskGroup,
                'command': c.displayCommand,
                'platforms': c.childConfigurationNames,
              },
            )
            .toList(),
        buildScanMeta: {
          'tasksJsonExists': buildResult.tasksJsonExists,
          'usingDefaultConfigs': buildResult.usingDefaultConfigs,
          'resolvedPlatforms': buildResult.resolvedPlatforms,
          if (buildResult.errorMessage != null)
            'error': buildResult.errorMessage,
        },
        agentProfile: profile,
        agentMemory: memory,
        agentKnowledge: knowledge,
        generatedAt: generatedAt,
      );

      final dir = Directory(ProjectContextPaths.contextDir(project.path));
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final encoder = const JsonEncoder.withIndent('  ');
      final file = File(outputPath);
      await file.writeAsString(encoder.convert(context));

      return ProjectContextBuildResult(
        filePath: outputPath,
        generatedAt: generatedAt,
        sizeBytes: file.lengthSync(),
      );
    } catch (e) {
      return ProjectContextBuildResult(
        filePath: outputPath,
        generatedAt: generatedAt,
        sizeBytes: 0,
        error: e.toString(),
      );
    }
  }

  ProjectContextFileInfo? readExisting(String projectRoot) {
    final file = File(ProjectContextPaths.contextFilePath(projectRoot));
    if (!file.existsSync()) return null;

    try {
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final generatedAtRaw = decoded['generatedAt'] as String?;
      return ProjectContextFileInfo(
        filePath: file.path,
        generatedAt: generatedAtRaw != null
            ? DateTime.tryParse(generatedAtRaw) ?? file.lastModifiedSync()
            : file.lastModifiedSync(),
        sizeBytes: file.lengthSync(),
        version: decoded['version'] as int? ?? 0,
      );
    } catch (_) {
      return ProjectContextFileInfo(
        filePath: file.path,
        generatedAt: file.lastModifiedSync(),
        sizeBytes: file.lengthSync(),
        version: 0,
      );
    }
  }

  Map<String, dynamic> _assembleContext({
    required Project project,
    required GitRepositoryStatus? gitStatus,
    required Map<String, GlobalPackageMetadata> globalPackageMetadata,
    required List<ProjectFileNode> fileTree,
    required List<ProjectMediaEntry> mediaEntries,
    required List<Map<String, dynamic>> buildConfigs,
    required Map<String, dynamic> buildScanMeta,
    required AgentProfile agentProfile,
    required AgentMemoryStore agentMemory,
    required ProjectKnowledgeStore agentKnowledge,
    required DateTime generatedAt,
  }) {
    final customWidgets =
        project.widgets.where((w) => w.origin == WidgetOrigin.custom).toList();

    return {
      'version': ProjectContextPaths.contextVersion,
      'generatedAt': generatedAt.toIso8601String(),
      'project': {
        'id': project.id,
        'contextId': project.contextId,
        'name': project.name,
        'path': project.path,
        'description': project.description,
        'goal': project.goal,
        'notes': project.notes,
        'status': project.status.name,
        'addedAt': project.addedAt.toIso8601String(),
        'platforms': project.platforms,
        'flutterVersion': project.flutterVersion,
        'dartVersion': project.dartVersion,
        'isFlutterProject': project.isFlutterProject,
        'sdkAvailable': project.sdkAvailable,
        'structureNotes': project.structureNotes,
        'changelog': project.changelog,
      },
      'dependencies': project.dependencies
          .map(
            (d) => {
              'name': d.name,
              'isDev': d.isDev,
              'declaredVersion': d.declaredVersion,
              'resolvedVersion': d.resolvedVersion,
              'latestVersion': d.latestVersion,
              'sourceType': d.sourceType.name,
              'sourceDetail': d.sourceDetail,
              'description': d.displayDescription(globalPackageMetadata[d.name]),
              'notes': d.displayNotes(globalPackageMetadata[d.name]),
              'risks': d.displayRisks(globalPackageMetadata[d.name]),
            },
          )
          .toList(),
      'widgets': {
        'summary': {
          'total': project.widgets.length,
          'custom': customWidgets.length,
          'library': project.widgets.length - customWidgets.length,
          'totalUsages': customWidgets.fold<int>(
            0,
            (sum, w) => sum + w.usageCount,
          ),
        },
        'custom': customWidgets.map(_widgetToJson).toList(),
      },
      'media': {
        'summary': {
          'total': mediaEntries.length,
          'declaredInPubspec':
              mediaEntries.where((e) => e.declaredInPubspec).length,
          'withUsages': mediaEntries.where((e) => e.usageCount > 0).length,
          'byKind': _mediaKindCounts(mediaEntries),
        },
        'entries': mediaEntries
            .map(
              (e) => {
                'relativePath': e.relativePath,
                'fileName': e.fileName,
                'folder': e.folder,
                'kind': e.kind.name,
                'sizeBytes': e.sizeBytes,
                'declaredInPubspec': e.declaredInPubspec,
                'usageCount': e.usageCount,
                'assetBindings': e.assetBindings
                    .map(
                      (b) => {
                        'className': b.className,
                        'constant': b.constantName,
                        'assetPath': b.assetPath,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      },
      'git': _gitToJson(gitStatus),
      'builds': {
        ...buildScanMeta,
        'configs': buildConfigs,
      },
      'documentation': {
        'sections': project.documentationSections,
        'links': project.documentationLinks
            .map(
              (l) => {
                'title': l.title,
                'url': l.url,
                'description': l.description,
              },
            )
            .toList(),
      },
      'changeHistory': project.changeHistory
          .take(30)
          .map(
            (c) => {
              'timestamp': c.timestamp.toIso8601String(),
              'title': c.title,
              'description': c.description,
              'category': c.category,
            },
          )
          .toList(),
      'agent': {
        'profile': {
          'name': agentProfile.name,
          'aboutSelf': agentProfile.aboutSelf,
          'character': agentProfile.character,
          'skills': agentProfile.skills,
          'capabilities': agentProfile.capabilities,
          'limitations': agentProfile.limitations,
          'selfAnalysis': agentProfile.selfAnalysis,
          'customInstructions': agentProfile.customInstructions,
        },
        'memory': agentMemory.entries
            .take(80)
            .map(
              (e) => {
                'content': e.content,
                'tags': e.tags,
                'createdAt': e.createdAt.toIso8601String(),
              },
            )
            .toList(),
        'knowledge': {
          'architectureSummary': agentKnowledge.architectureSummary,
          'workflowsSummary': agentKnowledge.workflowsSummary,
          'interactionCount': agentKnowledge.interactionCount,
          'lastEnrichedAt': agentKnowledge.lastEnrichedAt?.toIso8601String(),
          'insights': agentKnowledge.insights
              .map(
                (i) => {
                  'topic': i.topic,
                  'content': i.content,
                  'sources': i.sources,
                  'updatedAt': i.updatedAt.toIso8601String(),
                },
              )
              .toList(),
        },
      },
      'fileStructure': _fileTreeSummary(fileTree),
    };
  }

  Map<String, dynamic> _widgetToJson(WidgetEntry w) => {
        'name': w.name,
        'filePath': w.filePath,
        'type': w.type,
        'description': w.description,
        'notes': w.notes,
        'superType': w.superType,
        'stateClassName': w.stateClassName,
        'usageCount': w.usageCount,
        'enrichedByCursor': w.enrichedByCursor,
        'constructorParams': w.constructorParams
            .map((p) => {'name': p.name, 'type': p.type, 'required': p.isRequired})
            .toList(),
        'usages': w.usages
            .take(8)
            .map(
              (u) => {
                'filePath': u.filePath,
                'line': u.line,
              },
            )
            .toList(),
      };

  Map<String, int> _mediaKindCounts(List<ProjectMediaEntry> entries) {
    final counts = <String, int>{};
    for (final entry in entries) {
      counts.update(entry.kind.name, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, dynamic>? _gitToJson(GitRepositoryStatus? status) {
    if (status == null) return null;
    return {
      'isRepository': status.isRepository,
      'branch': status.branch,
      'upstreamBranch': status.upstreamBranch,
      'ahead': status.ahead,
      'behind': status.behind,
      'remoteUrl': status.remoteUrl,
      'isGitLabRemote': status.isGitLabRemote,
      'gitlabHost': status.gitlabHost,
      'gitlabProjectPath': status.gitlabProjectPath,
      'gitlabWebUrl': status.gitlabWebUrl,
      'isClean': status.isClean,
      'changeSummary': {
        'total': status.changes.length,
        'staged': status.stagedCount,
        'unstaged': status.unstagedCount,
        'untracked': status.untrackedCount,
      },
      'changes': status.changes
          .take(40)
          .map(
            (c) => {
              'path': c.path,
              'kind': c.kind.name,
              'staged': c.staged,
              'unstaged': c.unstaged,
              if (c.oldPath != null) 'oldPath': c.oldPath,
            },
          )
          .toList(),
      'checkedAt': status.checkedAt.toIso8601String(),
      if (status.error != null) 'error': status.error,
    };
  }

  List<Map<String, dynamic>> _fileTreeSummary(
    List<ProjectFileNode> nodes, {
    int depth = 0,
    int maxDepth = 2,
  }) {
    final result = <Map<String, dynamic>>[];
    for (final node in nodes) {
      final item = <String, dynamic>{
        'name': node.name,
        'isDirectory': node.isDirectory,
        if (!node.isDirectory) 'sizeBytes': node.sizeBytes,
      };
      if (node.isDirectory &&
          depth < maxDepth &&
          node.children.isNotEmpty) {
        item['children'] = _fileTreeSummary(
          node.children,
          depth: depth + 1,
          maxDepth: maxDepth,
        );
      }
      result.add(item);
    }
    return result;
  }
}

class ProjectContextFileInfo {
  const ProjectContextFileInfo({
    required this.filePath,
    required this.generatedAt,
    required this.sizeBytes,
    required this.version,
  });

  final String filePath;
  final DateTime generatedAt;
  final int sizeBytes;
  final int version;
}
