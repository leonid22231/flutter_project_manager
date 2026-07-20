import 'package:project_manager/models/widget_entry.dart';
import 'package:project_manager/services/analysis/widget_analysis_result.dart';

/// Contract for widget analysis backends (static, Cursor CLI, etc.).
abstract class WidgetAnalysisBackend {
  const WidgetAnalysisBackend();

  Future<WidgetAnalysisResult> analyze(String projectRoot);
}
