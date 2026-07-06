import 'package:project_manager/models/dependency_source_type.dart';

class ValidationIssue {
  const ValidationIssue({
    required this.message,
    this.suggestion,
    this.isError = true,
  });

  final String message;
  final String? suggestion;
  final bool isError;
}

class SdkInfo {
  const SdkInfo({
    required this.flutterAvailable,
    required this.dartAvailable,
    this.flutterVersion,
    this.dartVersion,
    this.flutterRawOutput,
    this.dartRawOutput,
  });

  final bool flutterAvailable;
  final bool dartAvailable;
  final String? flutterVersion;
  final String? dartVersion;
  final String? flutterRawOutput;
  final String? dartRawOutput;

  bool get allAvailable => flutterAvailable && dartAvailable;
}

class ProjectValidationResult {
  const ProjectValidationResult({
    required this.isValid,
    this.issues = const [],
    this.isFlutterProject = false,
    this.projectName,
    this.platforms = const [],
    this.dependencies = const [],
    this.structureNotes = const [],
    this.sdkInfo,
  });

  final bool isValid;
  final List<ValidationIssue> issues;
  final bool isFlutterProject;
  final String? projectName;
  final List<String> platforms;
  final List<ProjectDependencyRef> dependencies;
  final List<String> structureNotes;
  final SdkInfo? sdkInfo;

  List<ValidationIssue> get errors =>
      issues.where((i) => i.isError).toList();

  List<ValidationIssue> get warnings =>
      issues.where((i) => !i.isError).toList();
}

/// Lightweight dependency info extracted during validation.
class ProjectDependencyRef {
  const ProjectDependencyRef({
    required this.name,
    required this.version,
    required this.source,
    this.isDev = false,
    this.sourceType = DependencySourceType.pub,
  });

  final String name;
  final String version;
  final String source;
  final bool isDev;
  final DependencySourceType sourceType;
}
