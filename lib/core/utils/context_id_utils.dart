import 'package:project_manager/services/git_service.dart';
import 'package:uuid/uuid.dart';

/// Helpers for project context-sync IDs (remote folder names under the sync repo).
///
/// IDs are always UUIDs. Shared seed text (or a GitLab remote) is hashed with
/// UUID v5 so the same words produce the same ID on every device.
class ContextIdUtils {
  ContextIdUtils._();

  static const _uuid = Uuid();

  /// Fixed namespace for context-sync folder IDs (do not change).
  static const namespace = '6f3a9c2e-8b1d-4e57-9a0c-2d5f7e1b4c83';

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _invalidChars = RegExp(r'[<>:"|?*\x00-\x1f]');
  static final _whitespace = RegExp(r'\s+');

  static bool isUuid(String value) => _uuidPattern.hasMatch(value.trim());

  /// Random UUID (new isolated identity; not shared unless copied).
  static String generateUuid() => _uuid.v4().toLowerCase();

  /// Canonical form of a shared seed: trim, lower-case, collapse whitespace.
  static String canonicalizeSeed(String raw) {
    return raw.trim().toLowerCase().replaceAll(_whitespace, ' ');
  }

  /// Deterministic UUID from shared words / seed (same seed → same UUID).
  static String fromSeed(String seed) {
    final canonical = canonicalizeSeed(seed);
    if (canonical.isEmpty) {
      throw ArgumentError('Seed must not be empty');
    }
    return _uuid.v5(namespace, canonical).toLowerCase();
  }

  /// Accept a UUID as-is, or turn free-text seed into a deterministic UUID.
  /// Returns null if empty / path separators / otherwise invalid.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (value.contains('/') || value.contains(r'\')) return null;
    if (value == '.' || value == '..') return null;

    if (isUuid(value)) return value.toLowerCase();

    value = value.replaceAll(_invalidChars, ' ');
    final canonical = canonicalizeSeed(value);
    if (canonical.isEmpty) return null;
    return fromSeed(canonical);
  }

  /// Stable seed slug from a GitLab remote, e.g. `gitlab.com__group__project`.
  static String? gitlabSeed(
    String? remoteUrl, {
    String? configuredGitLabBaseUrl,
  }) {
    final gitlab = parseGitLabRemote(
      remoteUrl,
      configuredGitLabBaseUrl: configuredGitLabBaseUrl,
    );
    if (gitlab == null) return null;

    final host =
        gitlab.host.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.-]'), '_');
    final path = gitlab.projectPath
        .replaceAll(r'\', '/')
        .split('/')
        .where((s) => s.isNotEmpty)
        .map((s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_'))
        .join('__');
    if (path.isEmpty) return null;
    return canonicalizeSeed('${host}__$path');
  }

  /// Deterministic UUID from GitLab remote (same remote → same UUID).
  static String? fromGitLabRemote(
    String? remoteUrl, {
    String? configuredGitLabBaseUrl,
  }) {
    final seed = gitlabSeed(
      remoteUrl,
      configuredGitLabBaseUrl: configuredGitLabBaseUrl,
    );
    if (seed == null) return null;
    return fromSeed(seed);
  }

  /// Prefer GitLab-derived UUID; otherwise a new random UUID.
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
