import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/flutter_platform_utils.dart';
import 'package:project_manager/models/dependency_source_type.dart';
import 'package:project_manager/models/project_dependency.dart';
import 'package:project_manager/models/validation_result.dart';
import 'package:project_manager/services/sdk_checker_service.dart';
import 'package:yaml/yaml.dart';

class ProjectValidatorService {
  ProjectValidatorService({SdkCheckerService? sdkChecker})
      : _sdkChecker = sdkChecker ?? SdkCheckerService();

  final SdkCheckerService _sdkChecker;

  static const _platformFolders = kFlutterPlatformFolders;

  Future<ProjectValidationResult> validate(String projectPath) async {
    final issues = <ValidationIssue>[];
    final normalizedPath = p.normalize(projectPath.trim());

    if (normalizedPath.isEmpty) {
      return const ProjectValidationResult(
        isValid: false,
        issues: [
          ValidationIssue(message: 'Project path is empty.'),
        ],
      );
    }

    final directory = Directory(normalizedPath);
    if (!directory.existsSync()) {
      return ProjectValidationResult(
        isValid: false,
        issues: [
          ValidationIssue(
            message: 'Directory does not exist: $normalizedPath',
            suggestion: 'Check the path and try again.',
          ),
        ],
      );
    }

    final pubspecFile = File(p.join(normalizedPath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      return ProjectValidationResult(
        isValid: false,
        issues: [
          ValidationIssue(
            message: 'pubspec.yaml not found in the selected directory.',
            suggestion:
                'Select a Flutter/Dart project root folder that contains pubspec.yaml.',
          ),
        ],
      );
    }

    final sdkInfo = await _sdkChecker.checkSdk();
    if (!sdkInfo.flutterAvailable) {
      issues.add(
        const ValidationIssue(
          message: 'Flutter SDK is not available in PATH.',
          suggestion:
              'Install Flutter from https://docs.flutter.dev/get-started/install '
              'and add it to your system PATH.',
        ),
      );
    }
    if (!sdkInfo.dartAvailable) {
      issues.add(
        const ValidationIssue(
          message: 'Dart SDK is not available in PATH.',
          suggestion:
              'Dart is bundled with Flutter. Install Flutter SDK or install Dart separately '
              'from https://dart.dev/get-dart.',
        ),
      );
    }

    Map<dynamic, dynamic>? pubspec;
    String? projectName;
    var isFlutterProject = false;
    final dependencies = <ProjectDependencyRef>[];
    final structureNotes = <String>[];

    try {
      final content = pubspecFile.readAsStringSync();
      pubspec = loadYaml(content) as Map?;
      if (pubspec == null) {
        issues.add(
          const ValidationIssue(
            message: 'Failed to parse pubspec.yaml.',
            suggestion: 'Ensure pubspec.yaml is valid YAML.',
          ),
        );
      } else {
        projectName = pubspec['name']?.toString();
        final flutterDep = pubspec['dependencies']?['flutter'];
        isFlutterProject = flutterDep != null;

        if (!isFlutterProject) {
          issues.add(
            const ValidationIssue(
              message:
                  'This is not a Flutter project (no flutter dependency in pubspec.yaml).',
              suggestion:
                  'Project Manager supports only Flutter/Dart projects with a flutter SDK dependency.',
            ),
          );
        }

        dependencies.addAll(_extractDependencies(pubspec));
      }
    } catch (e) {
      issues.add(
        ValidationIssue(
          message: 'Error reading pubspec.yaml: $e',
          suggestion: 'Fix pubspec.yaml syntax errors.',
        ),
      );
    }

    final libDir = Directory(p.join(normalizedPath, 'lib'));
    if (!libDir.existsSync()) {
      issues.add(
        const ValidationIssue(
          message: 'lib/ directory not found.',
          suggestion:
              'A standard Flutter project should have a lib/ folder with Dart source files.',
          isError: false,
        ),
      );
    } else {
      structureNotes.add('lib/ directory found');
    }

    final platforms = <String>[];
    for (final entry in _platformFolders.entries) {
      if (Directory(p.join(normalizedPath, entry.key)).existsSync()) {
        platforms.add(entry.value);
        structureNotes.add('${entry.key}/ platform folder detected');
      }
    }

    if (platforms.isEmpty && isFlutterProject) {
      issues.add(
        const ValidationIssue(
          message: 'No platform folders detected (android, ios, web, etc.).',
          suggestion:
              'Run "flutter create ." in the project directory to add platform support.',
          isError: false,
        ),
      );
    }

    final hasErrors = issues.any((i) => i.isError);
    return ProjectValidationResult(
      isValid: !hasErrors,
      issues: issues,
      isFlutterProject: isFlutterProject,
      projectName: projectName,
      platforms: platforms,
      dependencies: dependencies,
      structureNotes: structureNotes,
      sdkInfo: sdkInfo,
    );
  }

  List<ProjectDependencyRef> _extractDependencies(Map<dynamic, dynamic> pubspec) {
    final result = <ProjectDependencyRef>[];

    void parseSection(YamlMap? section, {required bool isDev}) {
      if (section == null) return;
      for (final entry in section.entries) {
        final name = entry.key.toString();
        if (name == 'flutter') continue;

        final parsed = _parseRef(name, entry.value, isDev: isDev);
        if (parsed != null) result.add(parsed);
      }
    }

    final deps = pubspec['dependencies'];
    if (deps is YamlMap) parseSection(deps, isDev: false);

    final devDeps = pubspec['dev_dependencies'];
    if (devDeps is YamlMap) parseSection(devDeps, isDev: true);

    return result;
  }

  ProjectDependencyRef? _parseRef(
    String name,
    dynamic value, {
    required bool isDev,
  }) {
    var version = '';
    var sourceType = DependencySourceType.pub;
    var source = 'pub';

    if (value is String) {
      version = value;
    } else if (value is YamlMap) {
      version = value['version']?.toString() ?? 'any';
      if (value.containsKey('path')) {
        sourceType = DependencySourceType.path;
        source = 'path';
      } else if (value.containsKey('git')) {
        sourceType = DependencySourceType.git;
        source = 'git';
      } else if (value.containsKey('sdk')) {
        sourceType = DependencySourceType.sdk;
        source = 'sdk';
      }
    }

    return ProjectDependencyRef(
      name: name,
      version: version.isEmpty ? 'any' : version,
      source: source,
      isDev: isDev,
      sourceType: sourceType,
    );
  }

  List<ProjectDependency> toProjectDependencies(
    List<ProjectDependencyRef> refs,
  ) {
    final now = DateTime.now();
    return refs
        .map(
          (ref) => ProjectDependency(
            name: ref.name,
            isDev: ref.isDev,
            declaredVersion: ref.version,
            sourceType: ref.sourceType,
            sourceDetail: ref.sourceType == DependencySourceType.path
                ? ref.source
                : null,
            lastCheckedAt: now,
          ),
        )
        .toList();
  }
}
