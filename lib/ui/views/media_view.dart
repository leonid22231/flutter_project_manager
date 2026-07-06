import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/file_type_utils.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/media_asset_binding.dart';
import 'package:project_manager/models/media_usage_entry.dart';
import 'package:project_manager/models/project_media_entry.dart';
import 'package:project_manager/services/project_media_service.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/widgets/file_documentation/doc_ui_primitives.dart';
import 'package:project_manager/ui/widgets/font_preview.dart';
import 'package:provider/provider.dart';

class MediaView extends StatefulWidget {
  const MediaView({super.key});

  @override
  State<MediaView> createState() => _MediaViewState();
}

class _MediaViewState extends State<MediaView> {
  final _searchController = TextEditingController();
  final _mediaService = ProjectMediaService();

  Future<ProjectMediaScanResult>? _future;
  String? _loadedProjectPath;
  String? _selectedFolder;
  String? _selectedPath;
  bool _visualOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload(String projectPath) {
    setState(() {
      _loadedProjectPath = projectPath;
      _selectedPath = null;
      _future = _mediaService.scanProjectMedia(projectPath);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectManagerState>();
    final project = state.selectedProject;
    final l10n = context.l10n;

    if (project == null) return const SizedBox.shrink();

    if (_loadedProjectPath != project.path) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload(project.path);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          searchController: _searchController,
          onSearchChanged: (_) => setState(() {}),
          onRefresh: () => _reload(project.path),
          visualOnly: _visualOnly,
          onVisualOnlyChanged: (value) => setState(() => _visualOnly = value),
        ),
        Expanded(
          child: FutureBuilder<ProjectMediaScanResult>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: IdeaColors.accent),
                      const SizedBox(height: 12),
                      Text(
                        l10n.loadingMedia,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: IdeaColors.error, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final result = snapshot.data;
              if (result == null) return const SizedBox.shrink();

              if (!result.assetsFolderExists) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.mediaAssetsFolderMissing,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (result.entries.isEmpty) {
                return Center(
                  child: Text(
                    l10n.mediaNoFiles,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }

              final folders = {
                for (final entry in result.entries) entry.folder,
              }.toList()
                ..sort();

              final filtered = _filterEntries(result.entries);
              final undeclaredCount =
                  result.entries.where((entry) => !entry.declaredInPubspec).length;
              final selected = filtered.cast<ProjectMediaEntry?>().firstWhere(
                    (entry) => entry?.relativePath == _selectedPath,
                    orElse: () => filtered.isNotEmpty ? filtered.first : null,
                  );

              if (_selectedPath == null && selected != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedPath = selected.relativePath);
                });
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.mediaSummary(
                                  filtered.length,
                                  result.entries.length,
                                  undeclaredCount,
                                ),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (undeclaredCount > 0) ...[
                                const SizedBox(height: 6),
                                Text(
                                  l10n.mediaUndeclaredHint,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  FilterChip(
                                    label: Text(l10n.mediaFilterAll),
                                    selected: _selectedFolder == null,
                                    onSelected: (_) =>
                                        setState(() => _selectedFolder = null),
                                  ),
                                  for (final folder in folders)
                                    FilterChip(
                                      label: Text(folder),
                                      selected: _selectedFolder == folder,
                                      onSelected: (_) =>
                                          setState(() => _selectedFolder = folder),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.mediaNoMatches,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final width = constraints.maxWidth;
                                    final crossAxisCount = width >= 900
                                        ? 5
                                        : width >= 700
                                            ? 4
                                            : width >= 480
                                                ? 3
                                                : 2;

                                    return GridView.builder(
                                      padding: const EdgeInsets.all(16),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 0.82,
                                      ),
                                      itemCount: filtered.length,
                                      itemBuilder: (context, index) {
                                        final entry = filtered[index];
                                        return _MediaTile(
                                          entry: entry,
                                          isSelected:
                                              entry.relativePath == _selectedPath,
                                          onTap: () => setState(
                                            () => _selectedPath = entry.relativePath,
                                          ),
                                          onOpen: () => state.openFile(entry.path),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 380,
                    child: selected == null
                        ? Center(
                            child: Text(
                              l10n.mediaSelectPrompt,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          )
                        : _MediaDetailPanel(
                            entry: selected,
                            projectRoot: project.path,
                            onOpenFile: (path, {line}) =>
                                state.openFile(path, line: line),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<ProjectMediaEntry> _filterEntries(List<ProjectMediaEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();
    return entries.where((entry) {
      if (_visualOnly && !entry.hasVisualPreview) return false;
      if (_selectedFolder != null && entry.folder != _selectedFolder) {
        return false;
      }
      if (query.isEmpty) return true;
      if (entry.fileName.toLowerCase().contains(query)) return true;
      if (entry.relativePath.toLowerCase().contains(query)) return true;
      return entry.assetBindings.any(
        (binding) => binding.reference.toLowerCase().contains(query),
      );
    }).toList();
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.visualOnly,
    required this.onVisualOnlyChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final bool visualOnly;
  final ValueChanged<bool> onVisualOnlyChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: IdeaColors.toolbar,
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.perm_media_outlined, size: 16, color: IdeaColors.accent),
          const SizedBox(width: 8),
          Text(l10n.tabMedia, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 28,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                style: const TextStyle(fontSize: 12, color: IdeaColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.mediaSearchHint,
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: IdeaColors.textSecondary,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 32, minHeight: 28),
                  filled: true,
                  fillColor: IdeaColors.inputBackground,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: IdeaColors.panelBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: IdeaColors.panelBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: IdeaColors.accent),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(l10n.mediaVisualOnly),
            selected: visualOnly,
            onSelected: onVisualOnlyChanged,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: l10n.refreshMedia,
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.entry,
    required this.isSelected,
    required this.onTap,
    required this.onOpen,
  });

  final ProjectMediaEntry entry;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typeLabel = fileTypeLabel(entry.fileName) ?? l10n.mediaOtherType;

    return Material(
      color: IdeaColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? IdeaColors.accent
              : entry.declaredInPubspec
                  ? IdeaColors.panelBorder
                  : IdeaColors.warning.withValues(alpha: 0.55),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: IdeaColors.background,
                padding: const EdgeInsets.all(8),
                child: _MediaThumbnail(entry: entry),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fileName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: IdeaColors.textBright,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.assetBindings.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.assetBindings.first.reference,
                      style: const TextStyle(
                        fontSize: 10,
                        color: IdeaColors.accent,
                        fontFamily: 'Consolas',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Badge(label: typeLabel, color: IdeaColors.accent),
                      _Badge(
                        label: l10n.mediaUsageCount(entry.usageCount),
                        color: entry.usageCount > 0
                            ? IdeaColors.success
                            : IdeaColors.textSecondary,
                      ),
                      if (!entry.declaredInPubspec)
                        _Badge(
                          label: l10n.mediaNotDeclared,
                          color: IdeaColors.warning,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaDetailPanel extends StatelessWidget {
  const _MediaDetailPanel({
    required this.entry,
    required this.projectRoot,
    required this.onOpenFile,
  });

  final ProjectMediaEntry entry;
  final String projectRoot;
  final void Function(String path, {int? line}) onOpenFile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ColoredBox(
      color: IdeaColors.sidebar,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              entry.fileName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              entry.relativePath,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                color: IdeaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: entry.kind == ProjectMediaKind.font ? 260 : 180,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: IdeaColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: IdeaColors.panelBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _MediaThumbnail(
                    entry: entry,
                    detailed: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => onOpenFile(entry.path),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: Text(l10n.mediaOpenFile),
            ),
            if (entry.assetBindings.isNotEmpty) ...[
              const SizedBox(height: 8),
              DocSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DocGroupHeader(
                      icon: Icons.code,
                      title: l10n.mediaAppAssetsBindings,
                      count: entry.assetBindings.length,
                    ),
                    const SizedBox(height: 10),
                    ...entry.assetBindings.map(
                      (binding) => _BindingTile(
                        binding: binding,
                        projectRoot: projectRoot,
                        onOpenFile: onOpenFile,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            DocSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DocGroupHeader(
                    icon: Icons.hub_outlined,
                    title: l10n.mediaUsages,
                    count: entry.usages.length,
                  ),
                  const SizedBox(height: 10),
                  if (entry.usages.isEmpty)
                    DocEmptyState(
                      icon: Icons.search_off,
                      message: l10n.mediaNoUsages,
                    )
                  else
                    ...entry.usages.map(
                      (usage) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _UsageTile(
                          usage: usage,
                          onOpenFile: () => onOpenFile(
                            p.join(projectRoot, usage.filePath),
                            line: usage.line,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BindingTile extends StatelessWidget {
  const _BindingTile({
    required this.binding,
    required this.projectRoot,
    required this.onOpenFile,
  });

  final MediaAssetBinding binding;
  final String projectRoot;
  final void Function(String path, {int? line}) onOpenFile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onOpenFile(
          p.join(projectRoot, binding.definitionFile),
          line: binding.definitionLine,
        ),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: IdeaColors.toolbar,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: IdeaColors.panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                binding.reference,
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 11,
                  color: IdeaColors.accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                binding.assetPath,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (binding.inPreloadList) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.mediaPreloadListMember,
                  style: const TextStyle(fontSize: 10, color: IdeaColors.success),
                ),
              ],
              if (binding.isTemplate) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.mediaTemplateBinding,
                  style: const TextStyle(fontSize: 10, color: IdeaColors.warning),
                ),
              ],
              if (binding.isMethod) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.mediaMethodBinding,
                  style: const TextStyle(fontSize: 10, color: IdeaColors.accent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({
    required this.usage,
    required this.onOpenFile,
  });

  final MediaUsageEntry usage;
  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenFile,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: IdeaColors.toolbar,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: IdeaColors.panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${usage.filePath}:${usage.line}',
                style: const TextStyle(
                  fontSize: 11,
                  color: IdeaColors.accent,
                  fontFamily: 'Consolas',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                usage.reference,
                style: const TextStyle(
                  fontSize: 10,
                  color: IdeaColors.success,
                  fontFamily: 'Consolas',
                ),
              ),
              if (usage.snippet.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  usage.snippet,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({
    required this.entry,
    this.detailed = false,
  });

  final ProjectMediaEntry entry;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    return switch (entry.kind) {
      ProjectMediaKind.rasterImage => Image.file(
          File(entry.path),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const _FallbackThumb(icon: Icons.broken_image_outlined),
        ),
      ProjectMediaKind.svg => SvgPicture.file(
          File(entry.path),
          fit: BoxFit.contain,
          placeholderBuilder: (_) =>
              const _FallbackThumb(icon: Icons.image_outlined),
        ),
      ProjectMediaKind.font => FontPreview(
          filePath: entry.path,
          compact: !detailed,
        ),
      ProjectMediaKind.other =>
        const _FallbackThumb(icon: Icons.insert_drive_file_outlined),
    };
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(icon, size: 32, color: IdeaColors.textSecondary),
    );
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
