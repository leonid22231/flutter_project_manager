import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/platform_utils.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/dependency_source_type.dart';
import 'package:project_manager/models/global_package_metadata.dart';
import 'package:project_manager/models/project_dependency.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/dialogs/edit_package_metadata_dialog.dart';
import 'package:provider/provider.dart';

class DependenciesView extends StatelessWidget {
  const DependenciesView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectManagerState>();
    final project = state.selectedProject;
    final l10n = context.l10n;

    if (project == null) {
      return const SizedBox.shrink();
    }

    if (state.isLoadingDependencies && project.dependencies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: IdeaColors.accent),
            const SizedBox(height: 12),
            Text(
              l10n.loadingDependencies,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (project.dependencies.isEmpty) {
      return Center(
        child: Text(
          l10n.noDependencies,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final sorted = [...project.dependencies]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.dependenciesCount(project.dependencies.length),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.refreshDependencies,
                onPressed: state.isLoadingDependencies
                    ? null
                    : state.refreshDependencies,
                icon: state.isLoadingDependencies
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: IdeaColors.accent,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...sorted.map(
            (dep) => _DependencyCard(
              dependency: dep,
              global: state.globalMetadataFor(dep.name),
              onOpenLink: () => _openDependencyLink(dep),
              onEdit: () => EditPackageMetadataDialog.show(
                context,
                packageName: dep.name,
                initial: state.globalMetadataFor(dep.name),
                pubDescription: dep.description,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDependencyLink(ProjectDependency dep) async {
    if (dep.sourceType == DependencySourceType.path &&
        dep.localPath != null) {
      await openPathInExplorer(dep.localPath!);
      return;
    }

    final url = dep.externalUrl;
    if (url != null) {
      await openExternalUrl(url);
    }
  }
}

class _DependencyCard extends StatelessWidget {
  const _DependencyCard({
    required this.dependency,
    required this.global,
    required this.onOpenLink,
    required this.onEdit,
  });

  final ProjectDependency dependency;
  final GlobalPackageMetadata? global;
  final VoidCallback onOpenLink;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final description = dependency.displayDescription(global);
    final notes = dependency.displayNotes(global);
    final risks = dependency.displayRisks(global);
    final hasGlobal = global?.hasCustomData == true;
    final current = dependency.currentVersion;
    final latest = dependency.latestVersion ?? l10n.notAvailable;
    final canOpenLink =
        dependency.localPath != null || dependency.externalUrl != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: IdeaColors.panelBorder),
        borderRadius: BorderRadius.circular(4),
        color: IdeaColors.background,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _PackageLink(
                        name: dependency.displayName,
                        canOpen: canOpenLink,
                        onTap: onOpenLink,
                      ),
                      _SourceBadge(
                        sourceType: dependency.sourceType,
                        detail: dependency.sourceDetail,
                      ),
                      if (dependency.isDev)
                        _Badge(
                          label: l10n.devDependency,
                          color: IdeaColors.textSecondary,
                        ),
                      if (hasGlobal)
                        _Badge(
                          label: l10n.globalMetadataBadge,
                          color: IdeaColors.accent,
                        ),
                      if (dependency.hasUpdateAvailable)
                        _Badge(
                          label: l10n.colLatest,
                          color: const Color(0xFFE5A045),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.editPackageMetadata,
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.colCurrent, style: _metaLabelStyle),
                const SizedBox(width: 6),
                Text(current, style: _versionStyle),
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_forward,
                  size: 12,
                  color: IdeaColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(l10n.colLatest, style: _metaLabelStyle),
                const SizedBox(width: 6),
                Text(
                  latest,
                  style: _versionStyle.copyWith(
                    color: dependency.hasUpdateAvailable
                        ? const Color(0xFFE5A045)
                        : IdeaColors.textPrimary,
                  ),
                ),
                if (dependency.effectiveDeclaredVersion != current) ...[
                  const SizedBox(width: 12),
                  Text(
                    '(${dependency.effectiveDeclaredVersion})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(l10n.colDescription, style: _metaLabelStyle),
            const SizedBox(height: 4),
            Text(
              description.isEmpty ? l10n.noDescriptionAvailable : description,
              style: TextStyle(
                fontSize: 12,
                color: description.isEmpty
                    ? IdeaColors.textSecondary
                    : IdeaColors.textPrimary,
                height: 1.4,
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l10n.packageNotes, style: _metaLabelStyle),
              const SizedBox(height: 4),
              Text(notes, style: const TextStyle(fontSize: 12, height: 1.4)),
            ],
            if (risks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l10n.packageUpdateRisks, style: _metaLabelStyle),
              const SizedBox(height: 4),
              Text(risks, style: const TextStyle(fontSize: 12, height: 1.4)),
            ],
            if (canOpenLink) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onOpenLink,
                icon: Icon(
                  dependency.sourceType == DependencySourceType.path
                      ? Icons.folder_open_outlined
                      : Icons.open_in_new,
                  size: 14,
                ),
                label: Text(
                  _linkLabel(l10n, dependency),
                  style: const TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _linkLabel(AppLocalizations l10n, ProjectDependency dep) {
    return switch (dep.sourceType) {
      DependencySourceType.path => l10n.openInExplorer,
      DependencySourceType.git => l10n.openRepository,
      _ => l10n.openOnPubDev,
    };
  }

  static const _metaLabelStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: IdeaColors.textSecondary,
    letterSpacing: 0.5,
  );

  static const _versionStyle = TextStyle(
    fontSize: 12,
    fontFamily: 'Consolas',
    color: IdeaColors.textPrimary,
  );
}

class _PackageLink extends StatelessWidget {
  const _PackageLink({
    required this.name,
    required this.canOpen,
    required this.onTap,
  });

  final String name;
  final bool canOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!canOpen) {
      return Text(
        name,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'Consolas',
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'Consolas',
          color: IdeaColors.accent,
          decoration: TextDecoration.underline,
          decorationColor: IdeaColors.accent,
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({
    required this.sourceType,
    this.detail,
  });

  final DependencySourceType sourceType;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final label = detail != null && detail!.isNotEmpty
        ? '${sourceType.label}: $detail'
        : sourceType.label;

    return _Badge(label: label, color: IdeaColors.textSecondary);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: IdeaColors.panelBorder),
        borderRadius: BorderRadius.circular(3),
        color: IdeaColors.toolbar,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
