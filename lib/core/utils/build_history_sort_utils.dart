import 'package:project_manager/models/build_history_entry.dart';
import 'package:project_manager/models/gitlab_ci_build.dart';

/// GitLab jobs API returns newest jobs first (highest id). Prefer job id over
/// [DateTime] when both entries are from GitLab — [finished_at] can tie across
/// parallel platform jobs in the same pipeline.
int compareGitLabCiBuilds(GitLabCiBuild a, GitLabCiBuild b) {
  final byJob = b.jobId.compareTo(a.jobId);
  if (byJob != 0) return byJob;

  final byDate = b.createdAt.compareTo(a.createdAt);
  if (byDate != 0) return byDate;

  return b.pipelineId.compareTo(a.pipelineId);
}

int compareBuildHistoryEntries(BuildHistoryEntry a, BuildHistoryEntry b) {
  if (a.isGitLab && b.isGitLab) {
    final aJob = a.gitlabJobId ?? 0;
    final bJob = b.gitlabJobId ?? 0;
    final byJob = bJob.compareTo(aJob);
    if (byJob != 0) return byJob;
  }

  final byDate = b.createdAt.compareTo(a.createdAt);
  if (byDate != 0) return byDate;

  final aPipeline = a.gitlabPipelineId ?? 0;
  final bPipeline = b.gitlabPipelineId ?? 0;
  final byPipeline = bPipeline.compareTo(aPipeline);
  if (byPipeline != 0) return byPipeline;

  return a.configName.compareTo(b.configName);
}

void sortBuildHistoryEntries(List<BuildHistoryEntry> entries) {
  entries.sort(compareBuildHistoryEntries);
}

void sortGitLabCiBuilds(List<GitLabCiBuild> builds) {
  builds.sort(compareGitLabCiBuilds);
}
