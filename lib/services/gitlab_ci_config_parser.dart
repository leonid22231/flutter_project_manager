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

Set<String> parseGitLabCiBuildJobNames(String content) {
  final jobs = <String>{};
  String? currentJob;

  for (final rawLine in content.split('\n')) {
    final line = rawLine.split('#').first;
    if (line.trim().isEmpty) continue;

    final indent = line.length - line.trimLeft().length;
    final trimmed = line.trim();

    if (indent == 0 && trimmed.endsWith(':') && !trimmed.startsWith('.')) {
      final name = trimmed.substring(0, trimmed.length - 1).trim();
      if (_gitlabCiRootKeys.contains(name) || name.startsWith('.')) {
        currentJob = null;
      } else {
        currentJob = name;
      }
      continue;
    }

    if (currentJob != null && indent > 0 && trimmed == 'artifacts:') {
      jobs.add(currentJob);
    }
  }

  return jobs;
}

bool looksLikeCiBuildJobName(String jobName, Set<String> yamlBuildJobs) {
  if (yamlBuildJobs.contains(jobName)) return true;

  final lower = jobName.toLowerCase();
  return lower.contains('build') ||
      lower.contains('release') ||
      lower.contains('package') ||
      lower.contains('deploy') ||
      lower.contains('apk') ||
      lower.contains('appbundle') ||
      lower.contains('windows') ||
      lower.contains('android') ||
      lower.contains('ios') ||
      lower.contains('web');
}
