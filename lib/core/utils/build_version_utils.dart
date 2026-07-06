final _versionPattern = RegExp(
  r'(\d+\.\d+\.\d+(?:\.\d+)?(?:[-+]\d+)?)',
);

const _ignoredArtifactNames = {
  'artifacts.zip',
  'metadata.gz',
  'job.log',
  'ci_build_artifacts.zip',
};

const _versionArtifactExtensions = {
  '.apk',
  '.aab',
  '.exe',
  '.msi',
  '.ipa',
  '.dmg',
  '.app',
};

String? parseVersionFromBuildNames(Iterable<String> names) {
  String? bestVersion;
  var bestScore = -1;

  for (final name in names) {
    final normalized = name.replaceAll(r'\', '/');
    if (_isIgnoredArtifactPath(normalized)) continue;

    for (final segment in normalized.split('/')) {
      if (segment.isEmpty || _isIgnoredArtifactPath(segment)) continue;
      final version = parseVersionFromBuildName(segment);
      if (version == null) continue;

      final score = _versionScore(normalized, segment, version);
      if (score > bestScore) {
        bestScore = score;
        bestVersion = version;
      }
    }

    final fullVersion = parseVersionFromBuildName(normalized);
    if (fullVersion != null) {
      final score = _versionScore(normalized, normalized, fullVersion);
      if (score > bestScore) {
        bestScore = score;
        bestVersion = fullVersion;
      }
    }
  }

  return bestVersion;
}

String? parseVersionFromBuildName(String name) {
  final normalized = name.replaceAll(r'\', '/');
  final fileName = normalized.split('/').last;
  if (_isIgnoredArtifactPath(fileName)) return null;

  final match = _versionPattern.firstMatch(fileName);
  if (match != null) return match.group(1);

  final loose = RegExp(
    r'[vV_-]?(\d+\.\d+\.\d+(?:\.\d+)?(?:[-+]\d+)?)',
  ).firstMatch(fileName);
  return loose?.group(1);
}

bool _isIgnoredArtifactPath(String value) {
  final lower = value.toLowerCase();
  if (_ignoredArtifactNames.contains(lower)) return true;
  return lower.endsWith('.json') ||
      lower.endsWith('.xml') ||
      lower.endsWith('.txt') ||
      lower.endsWith('.log');
}

int _versionScore(String fullPath, String segment, String version) {
  var score = 0;
  final lowerPath = fullPath.toLowerCase();
  final lowerSegment = segment.toLowerCase();

  for (final extension in _versionArtifactExtensions) {
    if (lowerSegment.endsWith(extension) || lowerPath.endsWith(extension)) {
      score += 20;
      break;
    }
  }

  if (version.contains('+') || version.contains('-')) score += 5;
  if (lowerSegment.contains('release')) score += 3;
  if (lowerSegment.contains('production')) score += 2;
  if (lowerPath.contains('flutter-apk') || lowerPath.contains('bundle')) {
    score += 2;
  }

  return score;
}

String detectPlatformFromBuildContext({
  required String jobName,
  required Iterable<String> artifactPaths,
}) {
  final paths = artifactPaths.map((path) => path.toLowerCase()).toList();
  final haystack = [
    jobName.toLowerCase(),
    ...paths,
  ].join(' ');

  if (haystack.contains('windows') ||
      paths.any((path) => path.endsWith('.exe'))) {
    return 'Windows';
  }
  if (haystack.contains('appbundle') ||
      haystack.contains('.aab') ||
      haystack.contains('bundle')) {
    return 'Android';
  }
  if (haystack.contains('apk') || paths.any((path) => path.endsWith('.apk'))) {
    return 'Android';
  }
  if (haystack.contains('ios') || paths.any((path) => path.endsWith('.ipa'))) {
    return 'iOS';
  }
  if (haystack.contains('macos') || paths.any((path) => path.endsWith('.dmg'))) {
    return 'macOS';
  }
  if (haystack.contains('linux')) {
    return 'Linux';
  }
  if (haystack.contains('web')) {
    return 'Web';
  }
  return 'Other';
}
