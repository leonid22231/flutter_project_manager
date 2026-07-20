import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/widget_constructor_param.dart';
import 'package:project_manager/models/widget_entry.dart';
import 'package:project_manager/models/widget_origin.dart';
import 'package:project_manager/models/widget_usage_entry.dart';
import 'package:project_manager/services/cursor_cli_logger.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/widgets/file_documentation/doc_ui_primitives.dart';
import 'package:provider/provider.dart';

enum _WidgetScope { project, file }

class WidgetsView extends StatefulWidget {
  const WidgetsView({super.key});

  @override
  State<WidgetsView> createState() => _WidgetsViewState();
}

class _WidgetsViewState extends State<WidgetsView> {
  final _searchController = TextEditingController();
  _WidgetScope _scope = _WidgetScope.project;
  String? _selectedFile;
  String? _selectedWidgetId;
  bool _legacyRescanTriggered = false;
  var _showCursorLog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rescanIfLegacyParams());
  }

  void _rescanIfLegacyParams() {
    if (_legacyRescanTriggered || !mounted) return;
    final project = context.read<ProjectManagerState>().selectedProject;
    if (project == null) return;

    final hasLegacyBraces = project.widgets.any(
      (w) => w.constructorParams.any(
        (p) => p.name == '{' || p.name == '}',
      ),
    );
    if (!hasLegacyBraces) return;

    _legacyRescanTriggered = true;
    final settings = context.read<AppSettingsState>().cursorCliSettings;
    context.read<ProjectManagerState>().refreshWidgets(
          cursorSettings: settings,
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProjectManagerState>();
    final appSettings = context.watch<AppSettingsState>();
    final project = state.selectedProject;
    final l10n = context.l10n;

    if (project == null) return const SizedBox.shrink();

    final customWidgets =
        project.widgets.where((w) => w.origin == WidgetOrigin.custom);

    if (state.isLoadingWidgets && customWidgets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: IdeaColors.accent),
            const SizedBox(height: 12),
            Text(l10n.loadingWidgets, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    final fileOptions = _collectFileOptions(customWidgets);
    final filtered = _filterWidgets(customWidgets);
    final selected = filtered.cast<WidgetEntry?>().firstWhere(
          (widget) => widget?.id == _selectedWidgetId,
          orElse: () => filtered.isNotEmpty ? filtered.first : null,
        );

    if (_selectedWidgetId != null &&
        selected != null &&
        selected.id != _selectedWidgetId &&
        filtered.any((w) => w.id == _selectedWidgetId)) {
      // keep selection
    } else if (selected != null &&
        (_selectedWidgetId == null ||
            !filtered.any((w) => w.id == _selectedWidgetId))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedWidgetId = selected.id);
      });
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 320,
          child: ColoredBox(
            color: IdeaColors.sidebar,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Toolbar(
                  searchController: _searchController,
                  onSearchChanged: (_) => setState(() {}),
                  onRefresh: state.isLoadingWidgets
                      ? null
                      : () => state.refreshWidgets(
                            cursorSettings: appSettings.cursorCliSettings,
                          ),
                  isRefreshing: state.isLoadingWidgets,
                  subtitle: state.isEnrichingWidgetsWithCursor
                      ? l10n.widgetsEnrichingWithCursor
                      : state.widgetsEnrichedByCursor
                          ? l10n.widgetsEnrichedByCursor
                          : null,
                  summary: l10n.widgetsCustomSummary(
                    customWidgets.length,
                    customWidgets.fold<int>(0, (sum, w) => sum + w.usageCount),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.widgetsScopeProject),
                        selected: _scope == _WidgetScope.project,
                        onSelected: (_) =>
                            setState(() => _scope = _WidgetScope.project),
                      ),
                      ChoiceChip(
                        label: Text(l10n.widgetsScopeFile),
                        selected: _scope == _WidgetScope.file,
                        onSelected: (_) =>
                            setState(() => _scope = _WidgetScope.file),
                      ),
                    ],
                  ),
                ),
                if (_scope == _WidgetScope.file)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedFile ?? fileOptions.firstOrNull,
                      decoration: InputDecoration(
                        labelText: l10n.widgetsSelectFile,
                        isDense: true,
                      ),
                      items: fileOptions
                          .map(
                            (file) => DropdownMenuItem(
                              value: file,
                              child: Text(
                                file,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _selectedFile = value),
                    ),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noWidgetsFound,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final widget = filtered[index];
                            final isSelected = widget.id == _selectedWidgetId;
                            return _WidgetListTile(
                              widget: widget,
                              isSelected: isSelected,
                              onTap: () =>
                                  setState(() => _selectedWidgetId = widget.id),
                            );
                          },
                        ),
                ),
                _CursorCliLogPanel(
                  expanded: _showCursorLog,
                  onToggle: () => setState(() => _showCursorLog = !_showCursorLog),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: selected == null
              ? Center(
                  child: Text(
                    l10n.widgetsSelectPrompt,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : _WidgetDetailsPanel(
                  widget: selected,
                  projectRoot: project.path,
                  onOpenFile: (path, {int? line}) =>
                      state.openFile(path, line: line),
                ),
        ),
      ],
    );
  }

  List<WidgetEntry> _filterWidgets(Iterable<WidgetEntry> widgets) {
    final query = _searchController.text.trim().toLowerCase();
    Iterable<WidgetEntry> result = widgets;

    if (_scope == _WidgetScope.file && _selectedFile != null) {
      result = result.forRelativeFile(_selectedFile!);
    }

    if (query.isNotEmpty) {
      result = result.where(
        (widget) =>
            widget.name.toLowerCase().contains(query) ||
            widget.filePath.toLowerCase().contains(query) ||
            widget.usages.any(
              (usage) =>
                  usage.filePath.toLowerCase().contains(query) ||
                  usage.positionalArgs.any(
                    (arg) => arg.toLowerCase().contains(query),
                  ),
            ),
      );
    }

    final sorted = result.toList()
      ..sort((a, b) {
        final byUsage = b.usageCount.compareTo(a.usageCount);
        if (byUsage != 0) return byUsage;
        return a.name.compareTo(b.name);
      });
    return sorted;
  }

  List<String> _collectFileOptions(Iterable<WidgetEntry> widgets) {
    final files = <String>{};
    for (final widget in widgets) {
      if (widget.filePath.isNotEmpty) files.add(widget.filePath);
      for (final usage in widget.usages) {
        files.add(usage.filePath);
      }
    }
    final sortedFiles = files.toList()..sort();
    if (_selectedFile == null && sortedFiles.isNotEmpty) {
      _selectedFile = sortedFiles.first;
    }
    return sortedFiles;
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.isRefreshing,
    required this.summary,
    this.subtitle,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final String summary;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.refreshWidgets,
                onPressed: onRefresh,
                icon: isRefreshing
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
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: IdeaColors.accent,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 16),
              hintText: l10n.widgetsSearchHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetListTile extends StatelessWidget {
  const _WidgetListTile({
    required this.widget,
    required this.isSelected,
    required this.onTap,
  });

  final WidgetEntry widget;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: isSelected ? IdeaColors.selected : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.widgets_outlined,
                size: 16,
                color: isSelected ? IdeaColors.accent : IdeaColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? IdeaColors.textBright
                            : IdeaColors.textPrimary,
                        fontFamily: 'Consolas',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isDefinedInProject
                          ? widget.filePath
                          : l10n.widgetsLibraryOnly,
                      style: Theme.of(context).textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              DocStatusBadge(
                label: '${widget.usageCount}',
                color: IdeaColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidgetDetailsPanel extends StatelessWidget {
  const _WidgetDetailsPanel({
    required this.widget,
    required this.projectRoot,
    required this.onOpenFile,
  });

  final WidgetEntry widget;
  final String projectRoot;
  final Future<void> Function(String path, {int? line}) onOpenFile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'Consolas',
                      ),
                ),
              ),
              DocStatusBadge(
                label: widget.origin.label,
                color: widget.origin == WidgetOrigin.custom
                    ? IdeaColors.success
                    : IdeaColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DocMetaChip(
                icon: Icons.category_outlined,
                label: l10n.widgetsLabelType,
                value: widget.superType ?? widget.type,
              ),
              DocMetaChip(
                icon: Icons.repeat,
                label: l10n.widgetsLabelUsages,
                value: '${widget.usageCount}',
              ),
              if (widget.isConstConstructor)
                DocMetaChip(
                  icon: Icons.lock_outline,
                  label: l10n.widgetsLabelConst,
                  value: l10n.yes,
                ),
            ],
          ),
          if (widget.isDefinedInProject) ...[
            const SizedBox(height: 12),
            DocSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DocGroupHeader(
                    icon: Icons.code,
                    title: l10n.widgetsDefinition,
                    count: 1,
                  ),
                  const SizedBox(height: 10),
                  _DetailLine(
                    label: l10n.labelPath,
                    value: widget.filePath,
                    onTap: () => onOpenFile(
                      p.join(projectRoot, widget.filePath),
                      line: widget.definitionLine,
                    ),
                  ),
                  if (widget.definitionLine != null)
                    _DetailLine(
                      label: l10n.labelLines,
                      value: '${widget.definitionLine}',
                    ),
                  if (widget.stateClassName != null)
                    _DetailLine(
                      label: l10n.widgetsStateClass,
                      value: widget.stateClassName!,
                    ),
                  if (widget.constructorParams.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(l10n.widgetsConstructorParams, style: _labelStyle),
                    const SizedBox(height: 6),
                    _ConstructorParamsTable(
                      params: widget.constructorParams
                          .where((p) => p.name != '{' && p.name != '}')
                          .toList(),
                    ),
                  ],
                  if (widget.description != null &&
                      widget.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(l10n.colDescription, style: _labelStyle),
                    const SizedBox(height: 4),
                    Text(widget.description!, style: const TextStyle(fontSize: 12)),
                  ],
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
                  title: l10n.widgetsUsages,
                  count: widget.usages.length,
                ),
                const SizedBox(height: 10),
                if (widget.usages.isEmpty)
                  DocEmptyState(
                    icon: Icons.search_off,
                    message: l10n.widgetsNoUsages,
                  )
                else
                  ...widget.usages.map(
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
    );
  }

  static const _labelStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: IdeaColors.textSecondary,
    letterSpacing: 0.5,
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      value,
      style: TextStyle(
        fontSize: 12,
        color: onTap != null ? IdeaColors.accent : IdeaColors.textPrimary,
        fontFamily: 'Consolas',
        decoration: onTap != null ? TextDecoration.underline : null,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: _WidgetDetailsPanel._labelStyle),
          ),
          Expanded(
            child: onTap != null
                ? InkWell(onTap: onTap, child: text)
                : text,
          ),
        ],
      ),
    );
  }
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({
    required this.usage,
    required this.onOpenFile,
  });

  final WidgetUsageEntry usage;
  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                  decoration: TextDecoration.underline,
                ),
              ),
              if (usage.enclosingName != null) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.widgetsUsedIn(usage.enclosingName!),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
              if (usage.positionalArgs.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.widgetsPositionalArgs,
                  style: _WidgetDetailsPanel._labelStyle,
                ),
                const SizedBox(height: 4),
                ...usage.positionalArgs.map(
                  (arg) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: DocCodeChip(text: arg),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConstructorParamsTable extends StatelessWidget {
  const _ConstructorParamsTable({required this.params});

  final List<WidgetConstructorParam> params;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (params.isEmpty) {
      return Text(
        l10n.notAvailable,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      children: params.map((param) {
        final kindLabel = param.kind == WidgetParamKind.positional
            ? l10n.widgetsParamPositional
            : l10n.widgetsParamNamed;
        final requiredLabel = param.isRequired
            ? l10n.widgetsParamRequired
            : l10n.widgetsParamOptional;
        final defaultSuffix = param.defaultValue != null
            ? ' = ${param.defaultValue}'
            : '';
        final typeLabel = (param.type != null && param.type!.isNotEmpty)
            ? param.type!
            : l10n.notAvailable;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  '${param.name}$defaultSuffix',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Consolas',
                    color: IdeaColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: DocCodeChip(text: typeLabel),
              ),
              const SizedBox(width: 8),
              DocStatusBadge(label: kindLabel, color: IdeaColors.accent),
              const SizedBox(width: 4),
              DocStatusBadge(
                label: requiredLabel,
                color: param.isRequired ? IdeaColors.warning : IdeaColors.success,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CursorCliLogPanel extends StatelessWidget {
  const _CursorCliLogPanel({
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: CursorCliLogger.instance,
      builder: (context, _) {
        final entries = CursorCliLogger.instance.recentEntries.take(30).toList();
        return Material(
          color: IdeaColors.toolbar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal, size: 14, color: IdeaColors.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.widgetsCursorCliLog,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        expanded ? Icons.expand_more : Icons.expand_less,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded)
                SizedBox(
                  height: 140,
                  child: entries.isEmpty
                      ? Center(
                          child: Text(
                            l10n.widgetsCursorCliLogEmpty,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final color = switch (entry.level) {
                              'ERROR' => IdeaColors.warning,
                              'WARN' => IdeaColors.warning,
                              _ => IdeaColors.textSecondary,
                            };
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                entry.format(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'Consolas',
                                  color: color,
                                  height: 1.3,
                                ),
                              ),
                            );
                          },
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}
