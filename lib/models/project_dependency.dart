import 'package:project_manager/models/dependency_source_type.dart';
import 'package:project_manager/models/global_package_metadata.dart';

class ProjectDependency {
  const ProjectDependency({
    required this.name,
    this.isDev = false,
    required this.declaredVersion,
    this.resolvedVersion,
    this.latestVersion,
    required this.sourceType,
    this.sourceDetail,
    this.description,
    this.pubDevUrl,
    this.localPath,
    this.lastCheckedAt,
    this.updateNotes,
    this.updateRisks,
    // Legacy field kept for JSON migration.
    String? version,
  })  : _legacyVersion = version;

  final String name;
  final bool isDev;
  final String declaredVersion;
  final String? resolvedVersion;
  final String? latestVersion;
  final DependencySourceType sourceType;
  final String? sourceDetail;
  final String? description;
  final String? pubDevUrl;
  final String? localPath;
  final DateTime? lastCheckedAt;
  final String? updateNotes;
  final String? updateRisks;
  final String? _legacyVersion;

  String get displayName => isDev ? '$name (dev)' : name;

  String get currentVersion => resolvedVersion ?? effectiveDeclaredVersion;

  String get effectiveDeclaredVersion {
    if (declaredVersion.isNotEmpty) return declaredVersion;
    return _legacyVersion ?? 'any';
  }

  String get sourceLabel => sourceType.label;

  String? get linkUrl {
    if (localPath != null) return localPath;
    return pubDevUrl ?? externalUrl;
  }

  String? get externalUrl {
    if (pubDevUrl != null) return pubDevUrl;
    if (sourceType == DependencySourceType.git && sourceDetail != null) {
      final detail = sourceDetail!;
      final atIndex = detail.indexOf('@');
      final url = atIndex > 0 ? detail.substring(0, atIndex) : detail;
      if (url.startsWith('http')) return url;
    }
    return null;
  }

  String displayDescription(GlobalPackageMetadata? global) {
    if (global != null && global.customDescription.isNotEmpty) {
      return global.customDescription;
    }
    return description ?? '';
  }

  String displayNotes(GlobalPackageMetadata? global) {
    if (global != null && global.customNotes.isNotEmpty) {
      return global.customNotes;
    }
    return updateNotes ?? '';
  }

  String displayRisks(GlobalPackageMetadata? global) {
    if (global != null && global.updateRisks.isNotEmpty) {
      return global.updateRisks;
    }
    return updateRisks ?? '';
  }

  bool get hasUpdateAvailable {
    final latest = latestVersion;
    final current = resolvedVersion;
    if (latest == null || current == null) return false;
    return latest != current;
  }

  ProjectDependency copyWith({
    String? name,
    bool? isDev,
    String? declaredVersion,
    String? resolvedVersion,
    String? latestVersion,
    DependencySourceType? sourceType,
    String? sourceDetail,
    String? description,
    String? pubDevUrl,
    String? localPath,
    DateTime? lastCheckedAt,
    String? updateNotes,
    String? updateRisks,
  }) {
    return ProjectDependency(
      name: name ?? this.name,
      isDev: isDev ?? this.isDev,
      declaredVersion: declaredVersion ?? this.declaredVersion,
      resolvedVersion: resolvedVersion ?? this.resolvedVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      sourceType: sourceType ?? this.sourceType,
      sourceDetail: sourceDetail ?? this.sourceDetail,
      description: description ?? this.description,
      pubDevUrl: pubDevUrl ?? this.pubDevUrl,
      localPath: localPath ?? this.localPath,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      updateNotes: updateNotes ?? this.updateNotes,
      updateRisks: updateRisks ?? this.updateRisks,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'isDev': isDev,
        'declaredVersion': declaredVersion,
        'resolvedVersion': resolvedVersion,
        'latestVersion': latestVersion,
        'sourceType': sourceType.name,
        'sourceDetail': sourceDetail,
        'description': description,
        'pubDevUrl': pubDevUrl,
        'localPath': localPath,
        'lastCheckedAt': lastCheckedAt?.toIso8601String(),
        'updateNotes': updateNotes,
        'updateRisks': updateRisks,
        // Legacy compatibility.
        'version': declaredVersion,
        'source': sourceType.label,
      };

  factory ProjectDependency.fromJson(Map<String, dynamic> json) {
    final legacyVersion = json['version'] as String? ?? '';
    final declared = json['declaredVersion'] as String? ?? legacyVersion;
    final legacySource = json['source'] as String? ?? 'pub.dev';
    final sourceTypeRaw = json['sourceType'] as String?;

    return ProjectDependency(
      name: _normalizeName(json['name'] as String),
      isDev: json['isDev'] as bool? ?? (json['name'] as String).contains('(dev)'),
      declaredVersion: declared,
      resolvedVersion: json['resolvedVersion'] as String?,
      latestVersion: json['latestVersion'] as String?,
      sourceType: sourceTypeRaw != null
          ? DependencySourceType.fromString(sourceTypeRaw)
          : _sourceFromLegacy(legacySource),
      sourceDetail: json['sourceDetail'] as String?,
      description: json['description'] as String?,
      pubDevUrl: json['pubDevUrl'] as String?,
      localPath: json['localPath'] as String?,
      lastCheckedAt: json['lastCheckedAt'] != null
          ? DateTime.parse(json['lastCheckedAt'] as String)
          : null,
      updateNotes: json['updateNotes'] as String?,
      updateRisks: json['updateRisks'] as String?,
      version: legacyVersion,
    );
  }

  static String _normalizeName(String name) {
    return name.replaceAll(' (dev)', '').trim();
  }

  static DependencySourceType _sourceFromLegacy(String source) {
    if (source.startsWith('path')) return DependencySourceType.path;
    if (source == 'git') return DependencySourceType.git;
    if (source.startsWith('sdk')) return DependencySourceType.sdk;
    return DependencySourceType.pub;
  }
}
