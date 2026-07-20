import 'package:project_manager/services/analysis/widget_analysis_backend.dart';
import 'package:project_manager/services/analysis/widget_analysis_result.dart';
import 'package:project_manager/services/widget_analyzer_service.dart';

/// Fast offline widget scan using regex/AST-like parsing.
class StaticWidgetAnalysisBackend extends WidgetAnalysisBackend {
  StaticWidgetAnalysisBackend({WidgetAnalyzerService? analyzer})
      : _analyzer = analyzer ?? WidgetAnalyzerService();

  final WidgetAnalyzerService _analyzer;

  @override
  Future<WidgetAnalysisResult> analyze(String projectRoot) async {
    final widgets = await _analyzer.scanProject(projectRoot);
    return WidgetAnalysisResult(widgets: widgets);
  }
}
