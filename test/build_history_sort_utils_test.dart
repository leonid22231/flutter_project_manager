import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/core/utils/build_history_sort_utils.dart';
import 'package:project_manager/models/build_history_entry.dart';
import 'package:project_manager/models/gitlab_ci_build.dart';

void main() {
  test('compareGitLabCiBuilds prefers newer job id when dates tie', () {
    final older = GitLabCiBuild(
      jobId: 100,
      jobName: 'build_android',
      createdAt: DateTime(2026, 1, 1, 12),
      projectVersion: '1.0.0',
      platform: 'Android',
      artifactFiles: const ['artifacts.zip'],
      webUrl: '',
      ref: 'main',
      pipelineId: 10,
      stage: 'build',
    );
    final newer = GitLabCiBuild(
      jobId: 101,
      jobName: 'build_windows',
      createdAt: DateTime(2026, 1, 1, 12),
      projectVersion: '1.0.0',
      platform: 'Windows',
      artifactFiles: const ['artifacts.zip'],
      webUrl: '',
      ref: 'main',
      pipelineId: 10,
      stage: 'build',
    );

    final builds = [older, newer]..sort(compareGitLabCiBuilds);
    expect(builds.first.jobId, 101);
  });

  test('compareBuildHistoryEntries sorts gitlab entries by job id', () {
    final entries = [
      BuildHistoryEntry(
        id: 'gitlab:1',
        source: BuildHistorySource.gitlabCi,
        createdAt: DateTime(2026, 1, 1, 12),
        projectVersion: '1.0.0',
        configName: 'build_android',
        platform: 'Android',
        artifactFiles: const ['artifacts.zip'],
        gitlabJobId: 1,
        gitlabPipelineId: 10,
      ),
      BuildHistoryEntry(
        id: 'gitlab:2',
        source: BuildHistorySource.gitlabCi,
        createdAt: DateTime(2026, 1, 1, 12),
        projectVersion: '1.0.0',
        configName: 'build_windows',
        platform: 'Windows',
        artifactFiles: const ['artifacts.zip'],
        gitlabJobId: 2,
        gitlabPipelineId: 10,
      ),
    ]..sort(compareBuildHistoryEntries);

    expect(entries.first.gitlabJobId, 2);
  });
}
