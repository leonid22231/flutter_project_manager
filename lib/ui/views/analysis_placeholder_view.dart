import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/project.dart';

class AnalysisPlaceholderView extends StatelessWidget {
  const AnalysisPlaceholderView({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined,
                size: 48, color: IdeaColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              l10n.codeAnalysis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 420,
              child: Text(
                l10n.codeAnalysisHint(project.name),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _FutureFeature(label: l10n.featureStructureAnalysis),
                _FutureFeature(label: l10n.featureWidgetDiscovery),
                _FutureFeature(label: l10n.featureDependencyTracking),
                _FutureFeature(label: l10n.featureAgentWorkflow),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FutureFeature extends StatelessWidget {
  const _FutureFeature({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: IdeaColors.sidebar,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: IdeaColors.panelBorder),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
