import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/models/change_record.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/services/project_storage_service.dart';
import 'package:uuid/uuid.dart';

class DocumentationService {
  DocumentationService({ProjectStorageService? storage})
      : _storage = storage ?? ProjectStorageService();

  final ProjectStorageService _storage;
  static const _uuid = Uuid();

  static const sectionKeys = {
    'overview': 'Project Overview',
    'changelog': 'Changelog',
    'dependencies': 'Dependencies',
    'widgets': 'Widgets',
    'changeNotes': 'Change Notes',
    'codeAnalysis': 'Code Analysis (future)',
  };

  Future<Project> initializeDocumentation(Project project) async {
    final projectDir = await _storage.getProjectDataDirectory(project.id);
    final docsDir = Directory(p.join(projectDir.path, 'docs'));
    if (!docsDir.existsSync()) {
      docsDir.createSync(recursive: true);
    }

    await _storage.getAnalysisDirectory(project.id);
    await _storage.getAgentWorkspaceDirectory(project.id);

    final sections = Map<String, String>.from(project.documentationSections);
    final files = <String, String>{
      'overview.md': _overviewTemplate(project),
      'changelog.md': _changelogTemplate(project),
      'dependencies.md': _dependenciesTemplate(project),
      'widgets.md': _widgetsTemplate(),
      'change_notes.md': _changeNotesTemplate(),
      'code_analysis.md': _codeAnalysisTemplate(),
    };

    for (final entry in files.entries) {
      final file = File(p.join(docsDir.path, entry.key));
      if (!file.existsSync()) {
        await file.writeAsString(entry.value);
      }
      final mappedKey = _mapFileToSectionKey(entry.key);
      sections.putIfAbsent(mappedKey, () => entry.value);
    }

    final readme = File(p.join(docsDir.path, 'README.md'));
    if (!readme.existsSync()) {
      await readme.writeAsString(_readmeTemplate(project));
    }

    return project.copyWith(documentationSections: sections);
  }

  String _mapFileToSectionKey(String fileName) {
    return switch (fileName) {
      'overview.md' => 'overview',
      'changelog.md' => 'changelog',
      'dependencies.md' => 'dependencies',
      'widgets.md' => 'widgets',
      'change_notes.md' => 'changeNotes',
      'code_analysis.md' => 'codeAnalysis',
      _ => fileName.replaceAll('.md', ''),
    };
  }

  Future<void> exportDocumentation(Project project) async {
    final projectDir = await _storage.getProjectDataDirectory(project.id);
    final exportDir = Directory(p.join(projectDir.path, 'export'));
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final exportFile = File(p.join(exportDir.path, 'documentation_$timestamp.md'));
    await exportFile.writeAsString(_buildExportContent(project));
  }

  String _buildExportContent(Project project) {
    final buffer = StringBuffer()
      ..writeln('# ${project.name} — Documentation Export')
      ..writeln()
      ..writeln('> Exported: ${DateTime.now().toIso8601String()}')
      ..writeln('> Path: `${project.path}`')
      ..writeln();

    for (final entry in sectionKeys.entries) {
      final content = project.documentationSections[entry.key] ?? '';
      buffer
        ..writeln('## ${entry.value}')
        ..writeln()
        ..writeln(content.isEmpty ? '_No content yet._' : content)
        ..writeln()
        ..writeln('---')
        ..writeln();
    }

    return buffer.toString();
  }

  ChangeRecord createInitialChangeRecord(Project project) {
    return ChangeRecord(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      title: 'Project added',
      description:
          'Project "${project.name}" was added to Project Manager.\n'
          'Path: ${project.path}\n'
          'Platforms: ${project.platforms.join(", ")}',
      category: 'system',
    );
  }

  String _readmeTemplate(Project project) => '''
# ${project.name}

Local documentation managed by Project Manager.

## Sections

- [overview.md](overview.md) — Project card and metadata
- [changelog.md](changelog.md) — Version history
- [dependencies.md](dependencies.md) — Package dependencies
- [widgets.md](widgets.md) — Widget inventory (future analysis)
- [change_notes.md](change_notes.md) — Development notes
- [code_analysis.md](code_analysis.md) — Code analysis (future)

## Project Info

- **Path:** `${project.path}`
- **Added:** ${project.addedAt.toIso8601String()}
- **Flutter:** ${project.flutterVersion ?? 'unknown'}
- **Dart:** ${project.dartVersion ?? 'unknown'}
''';

  String _overviewTemplate(Project project) => '''
# ${project.name}

## Description
${project.description.isEmpty ? '_No description yet._' : project.description}

## Goal
${project.goal.isEmpty ? '_No goal defined yet._' : project.goal}

## Notes
${project.notes.isEmpty ? '_No notes yet._' : project.notes}

## Metadata

| Field | Value |
|-------|-------|
| Path | `${project.path}` |
| Status | ${project.status.label} |
| Added | ${project.addedAt.toIso8601String()} |
| Flutter | ${project.flutterVersion ?? 'N/A'} |
| Dart | ${project.dartVersion ?? 'N/A'} |
| Platforms | ${project.platforms.isEmpty ? 'None detected' : project.platforms.join(', ')} |
''';

  String _changelogTemplate(Project project) => '''
# Changelog

## [Unreleased]

### Added
- Project registered in Project Manager (${project.addedAt.toIso8601String().split('T').first})
''';

  String _dependenciesTemplate(Project project) {
    if (project.dependencies.isEmpty) {
      return '# Dependencies\n\n_No dependencies recorded yet._\n';
    }

    final buffer = StringBuffer('# Dependencies\n\n');
    buffer.writeln('| Package | Current | Latest | Source | Last Checked |');
    buffer.writeln('|---------|---------|--------|--------|--------------|');

    for (final dep in project.dependencies) {
      final checked = dep.lastCheckedAt?.toIso8601String().split('T').first ?? '-';
      buffer.writeln(
        '| ${dep.displayName} | ${dep.currentVersion} | '
        '${dep.latestVersion ?? '-'} | ${dep.sourceLabel} | $checked |',
      );
    }

    return buffer.toString();
  }

  String _widgetsTemplate() => '''
# Widgets

> Widget inventory will be populated by future code analysis.

## Custom Widgets

_No custom widgets analyzed yet._

## Library Widgets

_No library widgets analyzed yet._

## Schema

Each widget entry will include:
- Name
- File path
- Type (StatelessWidget, StatefulWidget, etc.)
- Origin (custom / library)
- Description
- Constructor parameters
- Notes
''';

  String _changeNotesTemplate() => '''
# Change Notes

_Development notes and observations about project changes._

''';

  String _codeAnalysisTemplate() => '''
# Code Analysis

> This section is reserved for future automated code analysis.

## Planned Features

- Project structure analysis
- Widget discovery and cataloging
- Dependency change tracking
- Agent-driven workflow integration

## Analysis Directory

Analysis artifacts will be stored in the project's `analysis/` folder.
''';
}
