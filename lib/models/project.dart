import 'package:project_manager/models/change_record.dart';
import 'package:project_manager/models/documentation_link.dart';
import 'package:project_manager/models/project_dependency.dart';
import 'package:project_manager/models/project_status.dart';
import 'package:project_manager/models/widget_entry.dart';

class Project {
  const Project({
    required this.id,
    required this.contextId,
    required this.name,
    required this.path,
    this.description = '',
    this.goal = '',
    this.notes = '',
    required this.addedAt,
    this.platforms = const [],
    this.flutterVersion,
    this.dartVersion,
    this.dependencies = const [],
    this.status = ProjectStatus.active,
    this.changeHistory = const [],
    this.widgets = const [],
    this.documentationLinks = const [],
    this.changelog = '',
    this.documentationSections = const {},
    this.isFlutterProject = true,
    this.structureNotes = const [],
    this.sdkAvailable = true,
  });

  /// Internal app-storage key (immutable for `projects/<id>/`).
  final String id;

  /// Sync folder name under the shared GitHub context repo (editable).
  final String contextId;

  final String name;
  final String path;
  final String description;
  final String goal;
  final String notes;
  final DateTime addedAt;
  final List<String> platforms;
  final String? flutterVersion;
  final String? dartVersion;
  final List<ProjectDependency> dependencies;
  final ProjectStatus status;
  final List<ChangeRecord> changeHistory;
  final List<WidgetEntry> widgets;
  final List<DocumentationLink> documentationLinks;
  final String changelog;
  final Map<String, String> documentationSections;
  final bool isFlutterProject;
  final List<String> structureNotes;
  final bool sdkAvailable;

  Project copyWith({
    String? id,
    String? contextId,
    String? name,
    String? path,
    String? description,
    String? goal,
    String? notes,
    DateTime? addedAt,
    List<String>? platforms,
    String? flutterVersion,
    String? dartVersion,
    List<ProjectDependency>? dependencies,
    ProjectStatus? status,
    List<ChangeRecord>? changeHistory,
    List<WidgetEntry>? widgets,
    List<DocumentationLink>? documentationLinks,
    String? changelog,
    Map<String, String>? documentationSections,
    bool? isFlutterProject,
    List<String>? structureNotes,
    bool? sdkAvailable,
  }) {
    return Project(
      id: id ?? this.id,
      contextId: contextId ?? this.contextId,
      name: name ?? this.name,
      path: path ?? this.path,
      description: description ?? this.description,
      goal: goal ?? this.goal,
      notes: notes ?? this.notes,
      addedAt: addedAt ?? this.addedAt,
      platforms: platforms ?? this.platforms,
      flutterVersion: flutterVersion ?? this.flutterVersion,
      dartVersion: dartVersion ?? this.dartVersion,
      dependencies: dependencies ?? this.dependencies,
      status: status ?? this.status,
      changeHistory: changeHistory ?? this.changeHistory,
      widgets: widgets ?? this.widgets,
      documentationLinks: documentationLinks ?? this.documentationLinks,
      changelog: changelog ?? this.changelog,
      documentationSections: documentationSections ?? this.documentationSections,
      isFlutterProject: isFlutterProject ?? this.isFlutterProject,
      structureNotes: structureNotes ?? this.structureNotes,
      sdkAvailable: sdkAvailable ?? this.sdkAvailable,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contextId': contextId,
        'name': name,
        'path': path,
        'description': description,
        'goal': goal,
        'notes': notes,
        'addedAt': addedAt.toIso8601String(),
        'platforms': platforms,
        'flutterVersion': flutterVersion,
        'dartVersion': dartVersion,
        'dependencies': dependencies.map((d) => d.toJson()).toList(),
        'status': status.name,
        'changeHistory': changeHistory.map((c) => c.toJson()).toList(),
        'widgets': widgets.map((w) => w.toJson()).toList(),
        'documentationLinks':
            documentationLinks.map((l) => l.toJson()).toList(),
        'changelog': changelog,
        'documentationSections': documentationSections,
        'isFlutterProject': isFlutterProject,
        'structureNotes': structureNotes,
        'sdkAvailable': sdkAvailable,
      };

  factory Project.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return Project(
      id: id,
      contextId: (json['contextId'] as String?)?.trim().isNotEmpty == true
          ? json['contextId'] as String
          : id,
      name: json['name'] as String,
      path: json['path'] as String,
      description: json['description'] as String? ?? '',
      goal: json['goal'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      addedAt: DateTime.parse(json['addedAt'] as String),
      platforms: (json['platforms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      flutterVersion: json['flutterVersion'] as String?,
      dartVersion: json['dartVersion'] as String?,
      dependencies: (json['dependencies'] as List<dynamic>?)
              ?.map((e) => ProjectDependency.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      status: ProjectStatus.fromString(json['status'] as String? ?? 'active'),
      changeHistory: (json['changeHistory'] as List<dynamic>?)
              ?.map((e) => ChangeRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      widgets: (json['widgets'] as List<dynamic>?)
              ?.map((e) => WidgetEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      documentationLinks: (json['documentationLinks'] as List<dynamic>?)
              ?.map((e) => DocumentationLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      changelog: json['changelog'] as String? ?? '',
      documentationSections:
          (json['documentationSections'] as Map<String, dynamic>?)?.map(
                (key, value) => MapEntry(key, value as String),
              ) ??
              const {},
      isFlutterProject: json['isFlutterProject'] as bool? ?? true,
      structureNotes: (json['structureNotes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      sdkAvailable: json['sdkAvailable'] as bool? ?? true,
    );
  }
}
