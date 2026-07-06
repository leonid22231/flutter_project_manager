import 'package:project_manager/models/dart_import_analysis.dart';
import 'package:project_manager/services/project_files_service.dart';

class OpenedFile {
  const OpenedFile({
    required this.path,
    required this.fileName,
    required this.relativePath,
    required this.preview,
    required this.lineCount,
    this.languageId,
    this.documentationSections = const {},
    this.dartImportAnalysis,
  });

  final String path;
  final String fileName;
  final String relativePath;
  final FilePreviewResult preview;
  final int lineCount;
  final String? languageId;
  final Map<String, String> documentationSections;
  final DartImportAnalysis? dartImportAnalysis;

  int? get sizeBytes => preview.sizeBytes;
}
