import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/models/dependency_source_type.dart';
import 'package:project_manager/models/global_package_metadata.dart';
import 'package:project_manager/models/project_dependency.dart';
import 'package:project_manager/services/pub_dev_service.dart';
import 'package:yaml/yaml.dart';

class DependencyResolverService {
  DependencyResolverService({PubDevService? pubDev})
      : _pubDev = pubDev ?? PubDevService();

  final PubDevService _pubDev;

  Future<List<ProjectDependency>> resolveProjectDependencies(
    String projectPath, {
    Map<String, GlobalPackageMetadata>? globalMetadata,
  }) async {
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return [];

    final pubspec = loadYaml(await pubspecFile.readAsString()) as Map?;
    if (pubspec == null) return [];

    final lockVersions = _parseLockVersions(projectPath);
    final refs = _extractFromPubspec(pubspec, projectPath);
    final now = DateTime.now();
    final result = <ProjectDependency>[];

    for (final ref in refs) {
      final resolved = lockVersions[ref.name];
      var dependency = ProjectDependency(
        name: ref.name,
        isDev: ref.isDev,
        declaredVersion: ref.declaredVersion,
        resolvedVersion: resolved,
        sourceType: ref.sourceType,
        sourceDetail: ref.sourceDetail,
        localPath: ref.localPath,
        pubDevUrl: ref.sourceType == DependencySourceType.pub
            ? 'https://pub.dev/packages/${ref.name}'
            : null,
        lastCheckedAt: now,
      );

      if (ref.sourceType == DependencySourceType.pub) {
        final pubInfo = await _pubDev.fetchPackageInfo(ref.name);
        dependency = dependency.copyWith(
          latestVersion: pubInfo?.latestVersion,
          description: pubInfo?.description,
        );
      }

      result.add(dependency);
    }

    return result;
  }

  Map<String, String> _parseLockVersions(String projectPath) {
    final lockFile = File(p.join(projectPath, 'pubspec.lock'));
    if (!lockFile.existsSync()) return {};

    try {
      final yaml = loadYaml(lockFile.readAsStringSync());
      if (yaml is! YamlMap) return {};

      final packages = yaml['packages'];
      if (packages is! YamlMap) return {};

      final result = <String, String>{};
      for (final entry in packages.entries) {
        final name = entry.key.toString();
        final data = entry.value;
        if (data is YamlMap && data['version'] != null) {
          result[name] = data['version'].toString();
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  List<_DependencyRef> _extractFromPubspec(
    Map<dynamic, dynamic> pubspec,
    String projectPath,
  ) {
    final result = <_DependencyRef>[];

    void parseSection(Map<dynamic, dynamic>? section, {required bool isDev}) {
      if (section == null) return;
      for (final entry in section.entries) {
        final name = entry.key.toString();
        if (name == 'flutter') continue;

        final parsed = _parseDependencyEntry(
          name: name,
          value: entry.value,
          projectPath: projectPath,
          isDev: isDev,
        );
        if (parsed != null) result.add(parsed);
      }
    }

    final deps = pubspec['dependencies'];
    if (deps is YamlMap) {
      parseSection(Map<dynamic, dynamic>.from(deps), isDev: false);
    }

    final devDeps = pubspec['dev_dependencies'];
    if (devDeps is YamlMap) {
      parseSection(Map<dynamic, dynamic>.from(devDeps), isDev: true);
    }

    return result;
  }

  _DependencyRef? _parseDependencyEntry({
    required String name,
    required dynamic value,
    required String projectPath,
    required bool isDev,
  }) {
    var declaredVersion = '';
    var sourceType = DependencySourceType.pub;
    String? sourceDetail;
    String? localPath;

    if (value is String) {
      declaredVersion = value;
    } else if (value is YamlMap) {
      declaredVersion = value['version']?.toString() ?? '';

      if (value.containsKey('path')) {
        sourceType = DependencySourceType.path;
        final relPath = value['path'].toString();
        sourceDetail = relPath;
        localPath = p.normalize(p.join(projectPath, relPath));
      } else if (value.containsKey('git')) {
        sourceType = DependencySourceType.git;
        final git = value['git'];
        if (git is YamlMap) {
          final url = git['url']?.toString();
          final ref = git['ref']?.toString();
          sourceDetail = [url, ref].whereType<String>().join('@');
        } else {
          sourceDetail = git.toString();
        }
      } else if (value.containsKey('sdk')) {
        sourceType = DependencySourceType.sdk;
        sourceDetail = value['sdk']?.toString();
      }
    }

    return _DependencyRef(
      name: name,
      isDev: isDev,
      declaredVersion: declaredVersion.isEmpty ? 'any' : declaredVersion,
      sourceType: sourceType,
      sourceDetail: sourceDetail,
      localPath: localPath,
    );
  }
}

class _DependencyRef {
  const _DependencyRef({
    required this.name,
    required this.isDev,
    required this.declaredVersion,
    required this.sourceType,
    this.sourceDetail,
    this.localPath,
  });

  final String name;
  final bool isDev;
  final String declaredVersion;
  final DependencySourceType sourceType;
  final String? sourceDetail;
  final String? localPath;
}
