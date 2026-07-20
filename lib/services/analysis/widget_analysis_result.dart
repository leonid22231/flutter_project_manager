import 'package:project_manager/models/widget_entry.dart';

/// Result of widget analysis — static baseline plus optional Cursor enrichment.
class WidgetAnalysisResult {
  const WidgetAnalysisResult({
    required this.widgets,
    this.enrichedByCursor = false,
  });

  final List<WidgetEntry> widgets;
  final bool enrichedByCursor;
}
