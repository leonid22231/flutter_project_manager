import 'package:project_manager/services/git_service.dart';
import 'package:uuid/uuid.dart';

/// Helpers for project context-sync IDs (remote folder names under the sync repo).
class ContextIdUtils {
  ContextIdUtils._();

  static const _uuid = Uuid();
  static final _invalidChars = RegExp(r'[<>:"|?*\x00-\x1f]');

  /// Trim and reject path separators / reserved characters.
  /// Returns null if the result is empty or invalid.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (value.contains('/') || value.contains(r'\')) return null;
    if (value == '.' || value == '..') return null;
    value = value.replaceAll(_invalidChars, '_');
    if (value.isEmpty) return null;
    return value;
  }

  static String generateUuid() => _uuid.v4();

  /// Stable slug from a GitLab remote, e.g. `gitlab.com__group__project`.
  static String? fromGitLabRemote(
    String? remoteUrl, {
    String? configuredGitLabBaseUrl,
  }) {
    final gitlab = parseGitLabRemote(
      remoteUrl,
      configuredGitLabBaseUrl: configuredGitLabBaseUrl,
    );
    if (gitlab == null) return null;

    final host = gitlab.host.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.-]'), '_');
    final path = gitlab.projectPath
        .replaceAll(r'\', '/')
        .split('/')
        .where((s) => s.isNotEmpty)
        .map((s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_'))
        .join('__');
    if (path.isEmpty) return null;
    return normalize('${host}__$path');
  }

  /// Prefer GitLab-derived id; otherwise a new UUID.
  static String resolveForNewProject({
    String? remoteUrl,
    String? configuredGitLabBaseUrl,
  }) {
    return fromGitLabRemote(
          remoteUrl,
          configuredGitLabBaseUrl: configuredGitLabBaseUrl,
        ) ??
        generateUuid();
  }
}
