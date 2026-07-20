class GitLabCiBuild {
  const GitLabCiBuild({
    required this.jobId,
    required this.jobName,
    required this.createdAt,
    required this.projectVersion,
    required this.platform,
    required this.artifactFiles,
    required this.webUrl,
    required this.ref,
    required this.pipelineId,
    required this.stage,
  });

  final int jobId;
  final String jobName;
  final DateTime createdAt;
  final String projectVersion;
  final String platform;
  final List<String> artifactFiles;
  final String webUrl;
  final String ref;
  final int pipelineId;
  final String stage;

  GitLabCiBuild copyWith({
    String? projectVersion,
    List<String>? artifactFiles,
  }) {
    return GitLabCiBuild(
      jobId: jobId,
      jobName: jobName,
      createdAt: createdAt,
      projectVersion: projectVersion ?? this.projectVersion,
      platform: platform,
      artifactFiles: artifactFiles ?? this.artifactFiles,
      webUrl: webUrl,
      ref: ref,
      pipelineId: pipelineId,
      stage: stage,
    );
  }
}

class GitLabCiBuildsResult {
  const GitLabCiBuildsResult({
    this.builds = const [],
    this.buildJobNames = const [],
    this.error,
    this.currentPage = 1,
    this.totalPages = 1,
    this.rawJobCount = 0,
    this.hasNextPage = false,
  });

  final List<GitLabCiBuild> builds;
  final List<String> buildJobNames;
  final String? error;
  final int currentPage;
  final int totalPages;
  final int rawJobCount;
  final bool hasNextPage;
}

class GitLabPipelineTriggerResult {
  const GitLabPipelineTriggerResult({
    this.pipelineId,
    this.webUrl,
    this.ref,
    this.status,
    this.error,
  });

  final int? pipelineId;
  final String? webUrl;
  final String? ref;
  final String? status;
  final String? error;

  bool get isSuccess => error == null && pipelineId != null;
}
