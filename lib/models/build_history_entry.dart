import 'dart:io' show Platform;

import 'package:project_manager/models/build_archive_entry.dart';
import 'package:project_manager/models/gitlab_ci_build.dart';

enum BuildHistorySource {
  local,
  gitlabCi,
}

class BuildHistoryEntry {
  const BuildHistoryEntry({
    required this.id,
    required this.source,
    required this.createdAt,
    required this.projectVersion,
    required this.configName,
    required this.platform,
    required this.artifactFiles,
    this.localArchivePath,
    this.gitlabJobId,
    this.gitlabJobWebUrl,
    this.gitlabRef,
    this.gitlabPipelineId,
  });

  final String id;
  final BuildHistorySource source;
  final DateTime createdAt;
  final String projectVersion;
  final String configName;
  final String platform;
  final List<String> artifactFiles;
  final String? localArchivePath;
  final int? gitlabJobId;
  final String? gitlabJobWebUrl;
  final String? gitlabRef;
  final int? gitlabPipelineId;

  bool get isLocal => source == BuildHistorySource.local;
  bool get isGitLab => source == BuildHistorySource.gitlabCi;

  int get artifactCount => artifactFiles.length;

  String? get artifactsDirectory => localArchivePath == null
      ? null
      : '$localArchivePath${Platform.pathSeparator}artifacts';

  String? gitlabArtifactFileWebUrl(String artifactPath) {
    final jobUrl = gitlabJobWebUrl;
    if (jobUrl == null) return null;
    final encodedPath = artifactPath.split('/').map(Uri.encodeComponent).join('/');
    return '$jobUrl/artifacts/file/$encodedPath';
  }

  String? get gitlabArtifactsDownloadUrl {
    final jobUrl = gitlabJobWebUrl;
    if (jobUrl == null) return null;
    return '$jobUrl/artifacts/download';
  }

  factory BuildHistoryEntry.fromLocal(BuildArchiveEntry entry) {
    return BuildHistoryEntry(
      id: 'local:${entry.id}',
      source: BuildHistorySource.local,
      createdAt: entry.createdAt,
      projectVersion: entry.projectVersion,
      configName: entry.configName,
      platform: entry.platform,
      artifactFiles: entry.artifactFiles,
      localArchivePath: entry.archivePath,
    );
  }

  factory BuildHistoryEntry.fromGitLab(GitLabCiBuild build) {
    return BuildHistoryEntry(
      id: 'gitlab:${build.jobId}',
      source: BuildHistorySource.gitlabCi,
      createdAt: build.createdAt,
      projectVersion: build.projectVersion,
      configName: build.jobName,
      platform: build.platform,
      artifactFiles: build.artifactFiles,
      gitlabJobId: build.jobId,
      gitlabJobWebUrl: build.webUrl,
      gitlabRef: build.ref,
      gitlabPipelineId: build.pipelineId,
    );
  }
}
