import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/project_status.dart';
import 'package:project_manager/state/project_manager_state.dart';

extension WorkspaceTabL10n on WorkspaceTab {
  String localized(AppLocalizations l10n) => switch (this) {
        WorkspaceTab.overview => l10n.tabOverview,
        WorkspaceTab.documentation => l10n.tabDocumentation,
        WorkspaceTab.dependencies => l10n.tabDependencies,
        WorkspaceTab.widgets => l10n.tabWidgets,
        WorkspaceTab.media => l10n.tabMedia,
        WorkspaceTab.gitlab => l10n.tabGitlab,
        WorkspaceTab.builds => l10n.tabBuilds,
        WorkspaceTab.analysis => l10n.tabAnalysis,
        WorkspaceTab.agent => l10n.tabAgent,
      };
}

extension DetailPanelSectionL10n on DetailPanelSection {
  String localized(AppLocalizations l10n) => switch (this) {
        DetailPanelSection.details => l10n.sectionDetails,
        DetailPanelSection.documentation => l10n.sectionDocumentation,
        DetailPanelSection.tasks => l10n.sectionTasks,
      };
}

extension ProjectStatusL10n on ProjectStatus {
  String localized(AppLocalizations l10n) =>
      l10n.projectStatusLabel(name);
}

extension FileTypeLabelL10n on String? {
  String localizedFileType(AppLocalizations l10n, {required String fileName}) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.svg')) return l10n.fileTypeSvg;
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.ico')) {
      return l10n.fileTypeImage;
    }
    return l10n.languageDisplayName(this);
  }
}
