import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/models/widget_entry.dart';
import 'package:project_manager/services/analysis/cursor_cli_widget_analysis_backend.dart';
import 'package:project_manager/services/analysis/static_widget_analysis_backend.dart';
import 'package:project_manager/services/analysis/widget_analysis_result.dart';

/// Runs static analysis first, then optional Cursor CLI enrichment in background.
class WidgetAnalysisCoordinator {
  WidgetAnalysisCoordinator({
    StaticWidgetAnalysisBackend? staticBackend,
  }) : _staticBackend = staticBackend ?? StaticWidgetAnalysisBackend();

  final StaticWidgetAnalysisBackend _staticBackend;

  Future<WidgetAnalysisResult> analyzeStatic(String projectRoot) {
    return _staticBackend.analyze(projectRoot);
  }

  Future<WidgetAnalysisResult> enrichWithCursor({
    required String projectId,
    required String projectRoot,
    required CursorCliSettings settings,
    required List<WidgetEntry> baseline,
  }) {
    return CursorCliWidgetAnalysisBackend(
      settings: settings,
      projectRoot: projectRoot,
      projectId: projectId,
      baseline: baseline,
    ).analyze(projectRoot);
  }
}
