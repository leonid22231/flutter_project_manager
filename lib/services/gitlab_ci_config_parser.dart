const _gitlabCiRootKeys = {
  'stages',
  'include',
  'variables',
  'workflow',
  'default',
  'image',
  'services',
  'before_script',
  'after_script',
  'cache',
  'pages',
};

const gitLabBuildStageName = 'build';

const _excludedGitLabStages = {
  'pre_build',
  'analyze_and_test',
  'test',
};

/// Returns GitLab CI job names that belong to the [gitLabBuildStageName] stage.
Set<String> parseGitLabCiBuildJobNames(String content) {
  final anchors = _parseAnchorDefinitions(content);
  final jobs = <String>{};

  final lines = content.split('\n');
  String? currentJob;
  final jobLines = <String>[];

  void flushJob() {
    if (currentJob == null) return;
    final stage = _resolveBlockStage(jobLines, anchors);
    if (stage == gitLabBuildStageName) {
      jobs.add(currentJob!);
    }
    currentJob = null;
    jobLines.clear();
  }

  for (final rawLine in lines) {
    final line = rawLine.split('#').first;
    if (line.trim().isEmpty) continue;

    final indent = line.length - line.trimLeft().length;
    final trimmed = line.trim();

    if (indent == 0) {
      flushJob();

      if (!trimmed.endsWith(':')) continue;

      if (trimmed.startsWith('.')) {
        currentJob = null;
        continue;
      }

      final name = trimmed.substring(0, trimmed.length - 1).trim();
      if (_gitlabCiRootKeys.contains(name)) {
        currentJob = null;
        continue;
      }

      currentJob = name;
      jobLines.clear();
      continue;
    }

    if (currentJob != null && indent > 0) {
      jobLines.add(trimmed);
    }
  }

  flushJob();
  return jobs;
}

class _AnchorDefinition {
  const _AnchorDefinition({
    this.stage,
    this.mergeRefs = const [],
  });

  final String? stage;
  final List<String> mergeRefs;
}

Map<String, _AnchorDefinition> _parseAnchorDefinitions(String content) {
  final anchors = <String, _AnchorDefinition>{};
  final lines = content.split('\n');

  String? currentAnchor;
  final blockLines = <String>[];

  void flushAnchor() {
    if (currentAnchor == null) return;
    anchors[currentAnchor!] = _anchorFromLines(blockLines);
    currentAnchor = null;
    blockLines.clear();
  }

  for (final rawLine in lines) {
    final line = rawLine.split('#').first;
    if (line.trim().isEmpty) continue;

    final indent = line.length - line.trimLeft().length;
    final trimmed = line.trim();

    if (indent == 0 && trimmed.contains('&')) {
      flushAnchor();
      final anchorMatch = RegExp(r'&(\w+)').firstMatch(trimmed);
      if (anchorMatch != null) {
        currentAnchor = anchorMatch.group(1);
        blockLines.clear();
      }
      continue;
    }

    if (currentAnchor != null && indent > 0) {
      blockLines.add(trimmed);
    } else if (indent == 0) {
      flushAnchor();
    }
  }

  flushAnchor();
  return anchors;
}

_AnchorDefinition _anchorFromLines(List<String> lines) {
  String? stage;
  final mergeRefs = <String>[];

  for (final line in lines) {
    if (line.startsWith('stage:')) {
      stage = line.substring('stage:'.length).trim();
    }
    final mergeMatch = RegExp(r'<<:\s*\*(\w+)').firstMatch(line);
    if (mergeMatch != null) {
      mergeRefs.add(mergeMatch.group(1)!);
    }
  }

  return _AnchorDefinition(stage: stage, mergeRefs: mergeRefs);
}

String? _resolveBlockStage(
  List<String> lines,
  Map<String, _AnchorDefinition> anchors,
) {
  String? explicitStage;
  final mergeRefs = <String>[];

  for (final line in lines) {
    if (line.startsWith('stage:')) {
      explicitStage = line.substring('stage:'.length).trim();
    }
    final mergeMatch = RegExp(r'<<:\s*\*(\w+)').firstMatch(line);
    if (mergeMatch != null) {
      mergeRefs.add(mergeMatch.group(1)!);
    }
  }

  if (explicitStage != null && explicitStage.isNotEmpty) {
    return explicitStage;
  }

  for (final ref in mergeRefs) {
    final fromAnchor = _resolveAnchorStage(ref, anchors, <String>{});
    if (fromAnchor != null && fromAnchor.isNotEmpty) {
      return fromAnchor;
    }
  }

  return null;
}

String? _resolveAnchorStage(
  String anchorName,
  Map<String, _AnchorDefinition> anchors,
  Set<String> visited,
) {
  if (visited.contains(anchorName)) return null;
  visited.add(anchorName);

  final anchor = anchors[anchorName];
  if (anchor == null) return null;
  if (anchor.stage != null && anchor.stage!.isNotEmpty) {
    return anchor.stage;
  }

  for (final ref in anchor.mergeRefs) {
    final nested = _resolveAnchorStage(ref, anchors, visited);
    if (nested != null && nested.isNotEmpty) return nested;
  }

  return null;
}

bool looksLikeCiBuildJobName(String jobName, Set<String> yamlBuildJobs) {
  if (yamlBuildJobs.contains(jobName)) return true;

  final lower = jobName.toLowerCase();
  return lower.startsWith('build_') ||
      lower.contains('build') ||
      lower.contains('release') ||
      lower.contains('package');
}

bool isExcludedGitLabStage(String? stage) {
  if (stage == null || stage.isEmpty) return false;
  return _excludedGitLabStages.contains(stage);
}
