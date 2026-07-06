import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/models/dart_import_analysis.dart';
import 'package:project_manager/models/file_documentation_init_result.dart';
import 'package:project_manager/services/dart_import_analyzer_service.dart';
import 'package:project_manager/services/project_storage_service.dart';

class FileDocumentationService {
  FileDocumentationService({
    ProjectStorageService? storage,
    DartImportAnalyzerService? dartImportAnalyzer,
  })  : _storage = storage ?? ProjectStorageService(),
        _dartImportAnalyzer = dartImportAnalyzer ?? DartImportAnalyzerService();

  final ProjectStorageService _storage;
  final DartImportAnalyzerService _dartImportAnalyzer;

  Future<FileDocumentationInitResult> initializeForFile({
    required String projectId,
    required String relativePath,
    required String fileName,
    String? language,
    int lineCount = 0,
    int? sizeBytes,
    String? projectRoot,
    String? absoluteFilePath,
    String? fileContent,
  }) async {
    final fileDir = await _getFileDataDirectory(projectId, relativePath);
    final docsDir = Directory(p.join(fileDir.path, 'docs'));
    if (!docsDir.existsSync()) {
      docsDir.createSync(recursive: true);
    }

    await _ensureAgentDirectory(fileDir);

    var dependenciesContent = _dependenciesTemplate();
    DartImportAnalysis? dartImportAnalysis;
    if (language == 'dart' &&
        fileContent != null &&
        projectRoot != null &&
        absoluteFilePath != null) {
      dartImportAnalysis = await _dartImportAnalyzer.analyze(
        content: fileContent,
        absoluteFilePath: absoluteFilePath,
        projectRoot: projectRoot,
      );
      dependenciesContent = dartImportAnalysis.toMarkdown();
    }

    final sections = <String, String>{};
    final files = <String, String>{
      'overview.md': _overviewTemplate(
        fileName: fileName,
        relativePath: relativePath,
        language: language,
        lineCount: lineCount,
        sizeBytes: sizeBytes,
      ),
      'notes.md': _notesTemplate(),
      'widgets.md': _widgetsTemplate(),
      'analysis.md': _analysisTemplate(),
      'changelog.md': _changelogTemplate(fileName),
      'dependencies.md': dependenciesContent,
    };

    for (final entry in files.entries) {
      final file = File(p.join(docsDir.path, entry.key));
      final shouldWrite = !file.existsSync() ||
          (entry.key == 'dependencies.md' && language == 'dart');
      if (shouldWrite) {
        await file.writeAsString(entry.value);
      }
      sections[_mapFileToSectionKey(entry.key)] = file.readAsStringSync();
    }

    return FileDocumentationInitResult(
      sections: sections,
      dartImportAnalysis: dartImportAnalysis,
    );
  }

  Future<Directory> _getFileDataDirectory(
    String projectId,
    String relativePath,
  ) async {
    final projectDir = await _storage.getProjectDataDirectory(projectId);
    final key = _encodeRelativePath(relativePath);
    final fileDir = Directory(p.join(projectDir.path, 'files', key));
    if (!fileDir.existsSync()) {
      fileDir.createSync(recursive: true);
    }
    return fileDir;
  }

  Future<Directory> _ensureAgentDirectory(Directory fileDir) async {
    final agentDir = Directory(p.join(fileDir.path, 'agent'));
    if (!agentDir.existsSync()) {
      agentDir.createSync(recursive: true);
    }
    return agentDir;
  }

  String _encodeRelativePath(String relativePath) {
    final normalized = p.normalize(relativePath).replaceAll(r'\', '/');
    final bytes = utf8.encode(normalized);
    final hash = md5.convert(bytes).toString();
    final slug = normalized
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final shortSlug = slug.length > 48 ? slug.substring(slug.length - 48) : slug;
    return '${hash.substring(0, 8)}_$shortSlug';
  }

  String _mapFileToSectionKey(String fileName) {
    return switch (fileName) {
      'overview.md' => 'overview',
      'notes.md' => 'notes',
      'widgets.md' => 'widgets',
      'analysis.md' => 'analysis',
      'changelog.md' => 'changelog',
      'dependencies.md' => 'dependencies',
      _ => fileName.replaceAll('.md', ''),
    };
  }

  String _overviewTemplate({
    required String fileName,
    required String relativePath,
    String? language,
    int lineCount = 0,
    int? sizeBytes,
  }) {
    final sizeLine = sizeBytes != null ? '$sizeBytes bytes' : 'unknown';
    return '''
# $fileName

## Path
`$relativePath`

## Metadata

| Field | Value |
|-------|-------|
| Language | ${language ?? 'Plain text'} |
| Lines | $lineCount |
| Size | $sizeLine |
| Registered | ${DateTime.now().toIso8601String()} |
''';
  }

  String _notesTemplate() => '''
# Notes

_File-specific notes and observations._

''';

  String _widgetsTemplate() => '''
# Widgets

> Widgets defined in this file will be listed here after code analysis.

''';

  String _analysisTemplate() => '''
# Code Analysis

> Automated analysis results for this file will appear here.

''';

  String _changelogTemplate(String fileName) => '''
# Changelog

## [Unreleased]

### Added
- File registered in Project Manager: $fileName

''';

  String _dependenciesTemplate() => '''
# Dependencies

> Imports and package dependencies used in this file will be tracked here.

''';
}
