import 'package:project_manager/models/dart_import_analysis.dart';

class FileDocumentationInitResult {
  const FileDocumentationInitResult({
    required this.sections,
    this.dartImportAnalysis,
  });

  final Map<String, String> sections;
  final DartImportAnalysis? dartImportAnalysis;
}
