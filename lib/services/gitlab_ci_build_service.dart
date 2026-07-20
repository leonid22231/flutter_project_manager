import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:project_manager/core/utils/build_history_sort_utils.dart';
import 'package:project_manager/core/utils/build_version_utils.dart';
import 'package:project_manager/core/utils/gitlab_pagination_utils.dart';
import 'package:project_manager/core/utils/gitlab_artifact_metadata_parser.dart';
import 'package:project_manager/core/utils/zip_central_directory.dart';
import 'package:project_manager/models/build_config_source.dart';
import 'package:project_manager/models/build_run_mode.dart';
import 'package:project_manager/models/git_repository_status.dart';
import 'package:project_manager/models/gitlab_check_result.dart';
import 'package:project_manager/models/gitlab_ci_build.dart';
import 'package:project_manager/models/gitlab_settings.dart';
import 'package:project_manager/models/project_build_config.dart';
import 'package:project_manager/services/build_history_logger.dart';
import 'package:project_manager/services/gitlab_api_service.dart';
import 'package:project_manager/services/gitlab_ci_config_parser.dart';

class GitLabCiBuildService {
  GitLabCiBuildService({GitLabApiService? api})
      : _api = api ?? GitLabApiService();

  final GitLabApiService _api;
  final _log = BuildHistoryLogger.instance;
  final Map<String, List<String>> _yamlJobNamesCache = {};

  /// How many build results the history UI shows per page.
  static const defaultBuildsPerPage = 10;

  /// How many GitLab jobs we fetch per API request while scanning history.
  static const gitlabJobsPerRequest = 50;
  static const _artifactLoadConcurrency = 4;

  Future<List<ProjectBuildConfig>> listCiJobConfigs({
    required GitLabSettings settings,
    required GitLabCheckResult? connection,
    required GitRepositoryStatus? gitStatus,
    required String projectRoot,
  }) async {
    if (!settings.enabled || connection?.connected != true) return const [];
    if (!_canUseGitLabProject(gitStatus, settings)) return const [];

    final jobNames = await _resolveCiBuildJobNames(
      settings: settings,
      gitStatus: gitStatus!,
      projectRoot: projectRoot,
    );

    return [
      for (final jobName in jobNames)
        ProjectBuildConfig(
          id: 'gitlab-ci:$jobName',
          name: jobName,
          source: BuildConfigSource.gitlabCi,
          mode: BuildRunMode.build,
          type: 'gitlab-ci',
          shellCommand: 'gitlab-ci pipeline run $jobName',
          taskGroup: 'build',
        ),
    ];
  }

  Future<GitLabPipelineTriggerResult> triggerPipeline({
    required GitLabSettings settings,
    required GitLabCheckResult? connection,
    required GitRepositoryStatus? gitStatus,
    required String ref,
    Map<String, String> variables = const {},
  }) async {
    if (!settings.enabled) {
      return const GitLabPipelineTriggerResult(error: 'GitLab is disabled.');
    }
    if (connection?.connected != true) {
      return const GitLabPipelineTriggerResult(error: 'GitLab is not connected.');
    }
    if (!_canUseGitLabProject(gitStatus, settings)) {
      return const GitLabPipelineTriggerResult(
        error: 'Project remote is not linked to the configured GitLab.',
      );
    }

    final encodedProject =
        _api.encodeProjectPath(gitStatus!.gitlabProjectPath!);

    try {
      final response = await _api.postJson(
        settings: settings,
        path: '/api/v4/projects/$encodedProject/pipeline',
        body: {
          'ref': ref,
          if (variables.isNotEmpty)
            'variables': [
              for (final entry in variables.entries)
                {'key': entry.key, 'value': entry.value},
            ],
        },
      );

      if (response.statusCode != 201) {
        return GitLabPipelineTriggerResult(
          error: _readApiError(response) ??
              'GitLab API error (${response.statusCode}).',
        );
      }

      final body = jsonDecode(response.body);
      if (body is! Map) {
        return const GitLabPipelineTriggerResult(
          error: 'Unexpected GitLab API response.',
        );
      }

      final pipeline = Map<String, dynamic>.from(body);
      return GitLabPipelineTriggerResult(
        pipelineId: pipeline['id'] as int?,
        webUrl: pipeline['web_url'] as String?,
        ref: pipeline['ref'] as String? ?? ref,
        status: pipeline['status'] as String?,
      );
    } catch (e) {
      return GitLabPipelineTriggerResult(error: '$e');
    }
  }

  Future<GitLabCiBuildsResult> listBuilds({
    required GitLabSettings settings,
    required GitLabCheckResult? connection,
    required GitRepositoryStatus? gitStatus,
    required String projectRoot,
    int page = 1,
    int buildsPerPage = defaultBuildsPerPage,
  }) async {
    if (!settings.enabled) {
      return const GitLabCiBuildsResult();
    }
    if (connection?.connected != true) {
      return const GitLabCiBuildsResult(
        error: 'GitLab is not connected.',
      );
    }
    if (!_canUseGitLabProject(gitStatus, settings)) {
      return const GitLabCiBuildsResult(
        error: 'Project remote is not linked to the configured GitLab.',
      );
    }

    final yamlBuildJobs = await _resolveCiBuildJobNames(
      settings: settings,
      gitStatus: gitStatus!,
      projectRoot: projectRoot,
    );
    final encodedProject = _api.encodeProjectPath(gitStatus.gitlabProjectPath!);
    final stopwatch = Stopwatch()..start();

    _log.info(
      'listBuilds request',
      source: 'gitlab-ci-builds',
      data: {
        'projectRoot': projectRoot,
        'page': page,
        'buildsPerPage': buildsPerPage,
        'project': gitStatus.gitlabProjectPath,
        'yamlBuildJobs': yamlBuildJobs.length,
      },
    );

    try {
      final skip = (page - 1) * buildsPerPage;
      var metadataSkipped = 0;
      final pageJobs = <Map<String, dynamic>>[];
      var gitlabJobPage = 1;
      var hasMoreGitlabJobs = true;
      var leftoverCandidates = false;
      var scannedRawJobs = 0;
      var skippedNoArtifacts = 0;
      var skippedStage = 0;
      var skippedJobName = 0;
      var skippedNoArtifactFiles = 0;
      var skippedNoArtifactHint = 0;

      final yamlBuildJobSet = yamlBuildJobs.toSet();

      while (pageJobs.length < buildsPerPage && hasMoreGitlabJobs) {
        final response = await _api.getJson(
          settings: settings,
          path: '/api/v4/projects/$encodedProject/jobs',
          query: {
            'scope': 'success',
            'per_page': '$gitlabJobsPerRequest',
            'page': '$gitlabJobPage',
          },
        );

        if (response.statusCode == 404) {
          return const GitLabCiBuildsResult(
            error: 'GitLab project was not found or access is denied.',
          );
        }
        if (response.statusCode != 200) {
          return GitLabCiBuildsResult(
            error: _readApiError(response) ??
                'GitLab API error (${response.statusCode}).',
          );
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          return const GitLabCiBuildsResult(
            error: 'Unexpected GitLab API response.',
          );
        }

        scannedRawJobs += decoded.length;
        final candidates = <Map<String, dynamic>>[];
        for (final item in decoded) {
          if (item is! Map) continue;
          final job = Map<String, dynamic>.from(item);
          if (!_jobHasArchiveArtifacts(job)) {
            skippedNoArtifacts++;
            continue;
          }

          final jobName = job['name'] as String? ?? '';
          final jobStage = job['stage'] as String? ?? '';
          if (jobStage.isNotEmpty && jobStage != gitLabBuildStageName) {
            skippedStage++;
            continue;
          }
          if (!_shouldIncludeJob(jobName, yamlBuildJobSet)) {
            skippedJobName++;
            continue;
          }

          final jobId = job['id'] as int?;
          if (jobId == null) continue;

          candidates.add(job);
        }

        var candidateIndex = 0;
        for (; candidateIndex < candidates.length; candidateIndex++) {
          final job = candidates[candidateIndex];
          if (!_hasQuickArtifactHint(job)) {
            skippedNoArtifactHint++;
            continue;
          }

          if (metadataSkipped < skip) {
            metadataSkipped++;
            continue;
          }

          pageJobs.add(job);
          if (pageJobs.length >= buildsPerPage) {
            candidateIndex++;
            break;
          }
        }

        leftoverCandidates = candidateIndex < candidates.length;
        final pagination = parseGitLabPagination(
          headers: response.headers,
          requestedPage: gitlabJobPage,
          requestedPerPage: gitlabJobsPerRequest,
          rawItemCount: decoded.length,
        );
        hasMoreGitlabJobs = pagination.hasNextPage;
        gitlabJobPage++;
      }

      final builds = <GitLabCiBuild>[];
      for (var index = 0; index < pageJobs.length; index += _artifactLoadConcurrency) {
        final batchEnd = (index + _artifactLoadConcurrency).clamp(
          0,
          pageJobs.length,
        );
        final batch = pageJobs.sublist(index, batchEnd);
        final batchBuilds = await Future.wait(
          batch.map(
            (job) => _buildFromJob(
              settings: settings,
              job: job,
              encodedProject: encodedProject,
            ),
          ),
        );
        for (final build in batchBuilds) {
          if (build == null) {
            skippedNoArtifactFiles++;
            continue;
          }
          builds.add(build);
        }
      }

      sortGitLabCiBuilds(builds);

      final hasNextPage = pageJobs.length >= buildsPerPage &&
          (leftoverCandidates || hasMoreGitlabJobs);
      final totalPages = builds.length < buildsPerPage
          ? page
          : (hasNextPage ? page + 1 : page);

      _log.info(
        'listBuilds response',
        source: 'gitlab-ci-builds',
        data: {
          'status': 200,
          'scannedRawJobs': scannedRawJobs,
          'skipped': skip,
          'metadataSkipped': metadataSkipped,
          'pageJobsSelected': pageJobs.length,
          'artifactLoads': pageJobs.length,
          'builds': builds.length,
          'skippedNoArtifacts': skippedNoArtifacts,
          'skippedStage': skippedStage,
          'skippedJobName': skippedJobName,
          'skippedNoArtifactHint': skippedNoArtifactHint,
          'skippedNoArtifactFiles': skippedNoArtifactFiles,
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'page': page,
          'buildsPerPage': buildsPerPage,
          'totalPages': totalPages,
          'hasNextPage': hasNextPage,
        },
      );

      return GitLabCiBuildsResult(
        builds: builds,
        buildJobNames: yamlBuildJobs,
        currentPage: page,
        totalPages: totalPages,
        rawJobCount: scannedRawJobs,
        hasNextPage: hasNextPage,
      );
    } catch (e) {
      _log.error(
        'listBuilds failed',
        source: 'gitlab-ci-builds',
        data: {
          'projectRoot': projectRoot,
          'error': '$e',
          'elapsedMs': stopwatch.elapsedMilliseconds,
        },
      );
      return GitLabCiBuildsResult(error: '$e');
    }
  }

  Future<List<String>> loadArtifactFilesForJob({
    required GitLabSettings settings,
    required GitRepositoryStatus? gitStatus,
    required int jobId,
    required String projectRoot,
  }) async {
    if (!_canUseGitLabProject(gitStatus, settings)) return const [];

    final encodedProject = _api.encodeProjectPath(gitStatus!.gitlabProjectPath!);
    return _loadArtifactFiles(
      settings: settings,
      projectRef: encodedProject,
      jobId: jobId,
      job: const {},
    );
  }

  bool _hasQuickArtifactHint(Map<String, dynamic> job) {
    return _fallbackArtifactNames(job).isNotEmpty;
  }

  Future<GitLabCiBuild?> _buildFromJob({
    required GitLabSettings settings,
    required Map<String, dynamic> job,
    required String encodedProject,
  }) async {
    final jobId = job['id'] as int?;
    if (jobId == null) return null;

    final jobName = job['name'] as String? ?? '';
    final projectRef = _projectRefForJob(job, encodedProject);

    final artifactFiles = await _loadArtifactFiles(
      settings: settings,
      projectRef: projectRef,
      jobId: jobId,
      job: job,
    );
    if (artifactFiles.isEmpty) return null;

    final version = _resolveProjectVersion(
      jobName: jobName,
      artifactFiles: artifactFiles,
    );
    final platform = detectPlatformFromBuildContext(
      jobName: jobName,
      artifactPaths: artifactFiles,
    );
    final pipeline = job['pipeline'];
    final pipelineId =
        pipeline is Map ? pipeline['id'] as int? ?? 0 : 0;
    final createdAt = DateTime.tryParse(job['finished_at'] as String? ?? '') ??
        DateTime.tryParse(job['created_at'] as String? ?? '') ??
        DateTime.now();

    return GitLabCiBuild(
      jobId: jobId,
      jobName: jobName,
      createdAt: createdAt,
      projectVersion: version,
      platform: platform,
      artifactFiles: artifactFiles,
      webUrl: job['web_url'] as String? ?? '',
      ref: job['ref'] as String? ?? '',
      pipelineId: pipelineId,
      stage: job['stage'] as String? ?? '',
    );
  }

  String _resolveProjectVersion({
    required String jobName,
    required List<String> artifactFiles,
  }) {
    return parseVersionFromBuildNames(artifactFiles) ??
        parseVersionFromBuildName(jobName) ??
        'unknown';
  }

  bool _canUseGitLabProject(
    GitRepositoryStatus? gitStatus,
    GitLabSettings settings,
  ) {
    if (gitStatus?.isGitLabRemote != true ||
        gitStatus?.gitlabProjectPath == null) {
      return false;
    }
    return gitLabRemoteMatchesSettings(gitStatus!, settings);
  }

  Future<List<String>> _resolveCiBuildJobNames({
    required GitLabSettings settings,
    required GitRepositoryStatus gitStatus,
    required String projectRoot,
  }) async {
    final cached = _yamlJobNamesCache[projectRoot];
    if (cached != null) return cached;

    final localJobs = _readYamlBuildJobs(projectRoot);
    final lintJobs = await _lintCiJobNames(
      settings: settings,
      gitStatus: gitStatus,
      projectRoot: projectRoot,
    );

    final jobs = <String>{...localJobs, ...lintJobs};
    final resolved = jobs.isEmpty ? const <String>[] : (jobs.toList()..sort());
    _yamlJobNamesCache[projectRoot] = resolved;
    return resolved;
  }

  Future<Set<String>> _lintCiJobNames({
    required GitLabSettings settings,
    required GitRepositoryStatus gitStatus,
    required String projectRoot,
  }) async {
    final file = File('$projectRoot/.gitlab-ci.yml');
    if (!file.existsSync()) return const {};

    try {
      final encodedProject =
          _api.encodeProjectPath(gitStatus.gitlabProjectPath!);
      final response = await _api.postJson(
        settings: settings,
        path: '/api/v4/projects/$encodedProject/ci/lint',
        body: {'content': await file.readAsString()},
      );
      if (response.statusCode != 200) return const {};

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const {};

      final jobs = decoded['jobs'];
      if (jobs is! List) return const {};

      final names = <String>{};
      for (final item in jobs) {
        if (item is! Map) continue;
        final name = item['name']?.toString();
        if (name == null || name.isEmpty) continue;
        final stage = item['stage']?.toString();
        if (stage != null && stage.isNotEmpty && stage != gitLabBuildStageName) {
          continue;
        }
        if (looksLikeCiBuildJobName(name, const {}) ||
            _jobMapHasArtifacts(item)) {
          names.add(name);
        }
      }
      return names;
    } catch (_) {
      return const {};
    }
  }

  bool _jobMapHasArtifacts(Map item) {
    final artifacts = item['artifacts'];
    return artifacts is List && artifacts.isNotEmpty;
  }

  Set<String> _readYamlBuildJobs(String projectRoot) {
    final file = File('$projectRoot/.gitlab-ci.yml');
    if (!file.existsSync()) return const {};
    return parseGitLabCiBuildJobNames(file.readAsStringSync());
  }

  bool _jobHasArchiveArtifacts(Map<String, dynamic> job) {
    if (job['artifacts_file'] != null) return true;

    final artifacts = job['artifacts'];
    if (artifacts is! List) return false;

    return artifacts.any((item) {
      if (item is! Map) return false;
      return item['file_type'] == 'archive';
    });
  }

  bool _shouldIncludeJob(String jobName, Set<String> yamlBuildJobs) {
    if (yamlBuildJobs.isEmpty) {
      return looksLikeCiBuildJobName(jobName, yamlBuildJobs);
    }

    if (yamlBuildJobs.contains(jobName)) return true;

    final normalizedJob = _normalizeJobName(jobName);
    for (final yamlJob in yamlBuildJobs) {
      if (_normalizeJobName(yamlJob) == normalizedJob) return true;
    }

    return looksLikeCiBuildJobName(jobName, yamlBuildJobs);
  }

  String _normalizeJobName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String _projectRefForJob(
    Map<String, dynamic> job,
    String encodedProjectPath,
  ) {
    final pipeline = job['pipeline'];
    if (pipeline is Map) {
      final projectId = pipeline['project_id'];
      if (projectId != null) return '$projectId';
    }
    return encodedProjectPath;
  }

  Future<List<String>> _loadArtifactFiles({
    required GitLabSettings settings,
    required String projectRef,
    required int jobId,
    required Map<String, dynamic> job,
  }) async {
    final fromTree = await _loadArtifactFilesFromTree(
      settings: settings,
      projectRef: projectRef,
      jobId: jobId,
    );
    if (fromTree.isNotEmpty) return fromTree;

    final fromZipCatalog = await _loadArtifactFilesFromZipCatalog(
      settings: settings,
      projectRef: projectRef,
      jobId: jobId,
    );
    if (fromZipCatalog.isNotEmpty) return fromZipCatalog;

    final fromMetadata = await _loadArtifactFilesFromMetadataGz(
      settings: settings,
      projectRef: projectRef,
      jobId: jobId,
      job: job,
    );
    if (fromMetadata.isNotEmpty) return fromMetadata;

    return _fallbackArtifactNames(job);
  }

  Future<List<String>> _loadArtifactFilesFromTree({
    required GitLabSettings settings,
    required String projectRef,
    required int jobId,
  }) async {
    const attempts = <Map<String, String>?>[
      null,
      {'recursive': 'true'},
    ];

    for (final query in attempts) {
      try {
        final body = await _api.getJsonBody(
          settings: settings,
          path: '/api/v4/projects/$projectRef/jobs/$jobId/artifacts/tree',
          query: query,
        );
        if (body == null) continue;

        final decoded = jsonDecode(body);
        final files = _parseArtifactTreeResponse(decoded);
        if (files.isNotEmpty) return files;
      } catch (_) {
        continue;
      }
    }

    return const [];
  }

  List<String> _parseArtifactTreeResponse(dynamic decoded) {
    if (decoded is! List) return const [];

    final files = <String>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      if (item['type'] != 'file') continue;

      final path = (item['path'] as String?)?.trim();
      final name = (item['name'] as String?)?.trim();
      final value = (path != null && path.isNotEmpty) ? path : name;
      if (value == null || value.isEmpty) continue;
      if (_isIgnoredArtifactListing(value)) continue;
      files.add(value.replaceAll(r'\', '/'));
    }

    files.sort();
    return files;
  }

  Future<List<String>> _loadArtifactFilesFromZipCatalog({
    required GitLabSettings settings,
    required String projectRef,
    required int jobId,
  }) async {
    const tailSize = 262144;
    const maxTailBytes = 512000;
    final archivePath = '/api/v4/projects/$projectRef/jobs/$jobId/artifacts';

    try {
      final tailResponse = await _api.getRangeSuffix(
        settings: settings,
        path: archivePath,
        suffixBytes: tailSize,
        maxResponseBytes: maxTailBytes,
      );

      if (!_isAcceptableRangeResponse(tailResponse, maxTailBytes)) {
        return const [];
      }

      final info = findZipCentralDirectoryInfo(tailResponse.bodyBytes);
      if (info == null) return const [];

      final end = info.offset + info.size - 1;
      final cdResponse = await _api.getRange(
        settings: settings,
        path: archivePath,
        start: info.offset,
        end: end,
        maxResponseBytes: info.size + 1024,
      );
      if (!_isAcceptableRangeResponse(cdResponse, info.size + 1024)) {
        return const [];
      }

      final files = parseZipCentralDirectoryFilenames(cdResponse.bodyBytes)
          .where((path) => !_isIgnoredArtifactListing(path))
          .toList();
      files.sort();
      return files;
    } catch (_) {
      return const [];
    }
  }

  bool _isAcceptableRangeResponse(http.Response response, int maxBytes) {
    if (response.statusCode == 413) return false;
    if (response.statusCode == 206 || response.statusCode == 200) {
      return response.bodyBytes.isNotEmpty &&
          response.bodyBytes.length <= maxBytes;
    }
    return false;
  }

  Future<List<String>> _loadArtifactFilesFromMetadataGz({
    required GitLabSettings settings,
    required String projectRef,
    required int jobId,
    required Map<String, dynamic> job,
  }) async {
    final metadataSize = _metadataArtifactSize(job);
    if (metadataSize != null && metadataSize > 65536) {
      return const [];
    }

    for (final path in _metadataArtifactPaths(projectRef, jobId)) {
      try {
        final response = await _api.getBytes(
          settings: settings,
          path: path,
          maxResponseBytes: 65536,
        );
        if (response.statusCode == 413) continue;
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          continue;
        }
        if (response.bodyBytes.length > 65536) continue;

        final files = parseGitLabArtifactMetadataGz(response.bodyBytes)
            .where((path) => !_isIgnoredArtifactListing(path))
            .toList();
        if (files.isNotEmpty) {
          files.sort();
          return files;
        }
      } catch (_) {
        continue;
      }
    }

    return const [];
  }

  List<String> _metadataArtifactPaths(String projectRef, int jobId) {
    return [
      '/api/v4/projects/$projectRef/jobs/$jobId/artifacts?file_type=metadata',
      '/api/v4/projects/$projectRef/jobs/$jobId/artifacts/metadata.gz',
    ];
  }

  int? _metadataArtifactSize(Map<String, dynamic> job) {
    final artifacts = job['artifacts'];
    if (artifacts is! List) return null;

    for (final item in artifacts) {
      if (item is! Map) continue;
      if (item['file_type'] == 'metadata') {
        return item['size'] as int?;
      }
    }

    return null;
  }

  List<String> _fallbackArtifactNames(Map<String, dynamic> job) {
    final names = <String>[];
    final seen = <String>{};

    void add(String? value) {
      if (value == null || value.isEmpty) return;
      if (seen.add(value)) names.add(value);
    }

    final artifacts = job['artifacts'];
    if (artifacts is List) {
      for (final item in artifacts) {
        if (item is! Map) continue;
        if (item['file_type'] == 'archive') {
          add(item['filename'] as String?);
        }
      }
    }

    final artifactsFile = job['artifacts_file'];
    if (artifactsFile is Map) {
      add(artifactsFile['filename'] as String?);
    }

    if (names.isEmpty) return const [];

    final versioned = names
        .where(
          (name) =>
              !_isIgnoredArtifactListing(name) &&
              parseVersionFromBuildName(name) != null,
        )
        .toList();
    if (versioned.isNotEmpty) return versioned;

    final named =
        names.where((name) => !_isIgnoredArtifactListing(name)).toList();
    if (named.isNotEmpty) return named;

    return names;
  }

  bool _isIgnoredArtifactListing(String path) {
    final lower = path.toLowerCase();
    return lower == 'artifacts.zip' ||
        lower == 'metadata.gz' ||
        lower == 'job.log';
  }

  String? _readApiError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return decoded['message']?.toString() ??
            decoded['error']?.toString();
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

bool gitLabRemoteMatchesSettings(
  GitRepositoryStatus gitStatus,
  GitLabSettings settings,
) {
  final remoteHost = gitStatus.gitlabHost?.toLowerCase();
  if (remoteHost == null || remoteHost.isEmpty) return false;

  final settingsUri = Uri.tryParse(settings.normalizedBaseUrl);
  if (settingsUri == null || settingsUri.host.isEmpty) return false;

  final settingsHost = settingsUri.host.toLowerCase();
  if (remoteHost == settingsHost) return true;

  if (settingsUri.hasPort) {
    final authority = '$settingsHost:${settingsUri.port}';
    if (remoteHost == authority) return true;
  }

  return false;
}