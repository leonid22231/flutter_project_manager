import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/text_search.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/file_preview_focus.dart';
import 'package:project_manager/models/opened_file.dart';
import 'package:project_manager/services/project_files_service.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/dialogs/git_graph_dialog.dart';
import 'package:project_manager/ui/dialogs/git_history_dialog.dart';
import 'package:project_manager/ui/widgets/font_preview.dart';
import 'package:project_manager/ui/widgets/markdown_content.dart';
import 'package:project_manager/ui/widgets/raster_image_preview.dart';
import 'package:project_manager/ui/widgets/syntax_highlight_preview.dart';
import 'package:provider/provider.dart';

enum SvgPreviewMode { image, text }

class FilePreviewView extends StatefulWidget {
  const FilePreviewView({
    super.key,
    required this.openedFile,
    required this.onClose,
    this.focus,
    this.focusToken = 0,
  });

  final OpenedFile openedFile;
  final VoidCallback onClose;
  final FilePreviewFocus? focus;
  final int focusToken;

  @override
  State<FilePreviewView> createState() => _FilePreviewViewState();
}

class _FilePreviewViewState extends State<FilePreviewView> {
  SvgPreviewMode _svgMode = SvgPreviewMode.image;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<TextSearchMatch> _searchMatches = const [];
  int _searchMatchIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(FilePreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openedFile.path != widget.openedFile.path) {
      _svgMode = SvgPreviewMode.image;
      _searchController.clear();
      _searchMatches = const [];
      _searchMatchIndex = 0;
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final content = _searchableContent;
    if (content == null) return;

    final matches = findTextMatches(content, _searchController.text);
    setState(() {
      _searchMatches = matches;
      _searchMatchIndex = 0;
    });
  }

  String? get _searchableContent {
    final result = widget.openedFile.preview;
    return switch (result.kind) {
      FilePreviewKind.text || FilePreviewKind.svg => result.content,
      _ => null,
    };
  }

  bool get _supportsSearch {
    final result = widget.openedFile.preview;
    if (result.kind != FilePreviewKind.text && result.kind != FilePreviewKind.svg) {
      return false;
    }
    if (_isMarkdown(widget.openedFile.fileName)) return false;
    if (result.kind == FilePreviewKind.svg && _svgMode == SvgPreviewMode.image) {
      return false;
    }
    return true;
  }

  bool get _supportsCopy {
    final result = widget.openedFile.preview;
    if (result.content == null) return false;
    return switch (result.kind) {
      FilePreviewKind.text => true,
      FilePreviewKind.svg => _svgMode == SvgPreviewMode.text,
      _ => false,
    };
  }

  Future<void> _copyAll() async {
    final content = _searchableContent;
    if (content == null) return;

    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.fileCopiedToClipboard),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _goToNextMatch({required bool reverse}) {
    if (_searchMatches.isEmpty) return;
    setState(() {
      if (reverse) {
        _searchMatchIndex =
            (_searchMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
      } else {
        _searchMatchIndex = (_searchMatchIndex + 1) % _searchMatches.length;
      }
    });
  }

  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final reverse = HardwareKeyboard.instance.isShiftPressed;
      _goToNextMatch(reverse: reverse);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _searchController.clear();
      _searchFocusNode.unfocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.openedFile.preview;
    final isSvg = result.kind == FilePreviewKind.svg;
    final state = context.watch<ProjectManagerState>();
    final gitStatus = state.gitRepositoryStatus;
    final isGitRepo = gitStatus?.isRepository == true;
    final relativePath = widget.openedFile.relativePath;

    void showHistory({int? line}) {
      final l10n = context.l10n;
      showGitHistoryDialog(
        context,
        title: line != null ? l10n.gitLineHistory(line) : l10n.gitFileHistory,
        loadCommits: () => line != null
            ? state.loadGitLineHistory(relativePath, line)
            : state.loadGitFileHistory(relativePath),
        relativePath: relativePath,
        gitStatus: gitStatus,
        line: line,
      );
    }

    void showGraph() {
      final l10n = context.l10n;
      showGitGraphDialog(
        context,
        title: l10n.gitFileGraph,
        loadGraph: () => state.loadGitFileGraph(relativePath),
        scopeLabel: relativePath,
        gitStatus: gitStatus,
      );
    }

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyF, control: true): _FocusSearchIntent(),
      },
      child: Actions(
        actions: {
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              if (_supportsSearch) {
                _searchFocusNode.requestFocus();
              }
              return null;
            },
          ),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PreviewToolbar(
              fileName: widget.openedFile.fileName,
              relativePath: widget.openedFile.relativePath,
              onClose: widget.onClose,
              isSvg: isSvg,
              svgMode: _svgMode,
              onSvgModeChanged: isSvg
                  ? (mode) => setState(() => _svgMode = mode)
                  : null,
              supportsSearch: _supportsSearch,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              searchMatchIndex: _searchMatchIndex,
              searchMatchCount: _searchMatches.length,
              onPreviousMatch: _searchMatches.isEmpty
                  ? null
                  : () => _goToNextMatch(reverse: true),
              onNextMatch:
                  _searchMatches.isEmpty ? null : () => _goToNextMatch(reverse: false),
              onSearchKey: _handleSearchKey,
              supportsCopy: _supportsCopy,
              onCopyAll: _supportsCopy ? _copyAll : null,
              onShowFileHistory:
                  isGitRepo && _supportsSearch ? () => showHistory() : null,
              onShowFileGraph:
                  isGitRepo && _supportsSearch ? showGraph : null,
            ),
            Expanded(
              child: _buildContent(
                context,
                result,
                onLineNumberTap: isGitRepo && _supportsSearch
                    ? (line) => showHistory(line: line)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    FilePreviewResult result, {
    ValueChanged<int>? onLineNumberTap,
  }) {
    final l10n = context.l10n;
    return switch (result.kind) {
      FilePreviewKind.text =>
        _isMarkdown(widget.openedFile.fileName)
            ? Material(
                color: IdeaColors.background,
                child: SelectionArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: MarkdownContent(data: result.content!),
                  ),
                ),
              )
            : SyntaxHighlightPreview(
                content: result.content!,
                fileName: widget.openedFile.fileName,
                highlightLine: widget.focus?.line,
                focusToken: widget.focusToken,
                searchMatches: _searchMatches,
                searchMatchIndex: _searchMatchIndex,
                onLineNumberTap: onLineNumberTap,
              ),
      FilePreviewKind.rasterImage =>
        RasterImagePreview(filePath: result.filePath!),
      FilePreviewKind.font => FontPreview(filePath: result.filePath!),
      FilePreviewKind.svg => _svgMode == SvgPreviewMode.image
          ? _SvgImagePreview(filePath: result.filePath!)
          : SyntaxHighlightPreview(
              content: result.content!,
              fileName: widget.openedFile.fileName,
              highlightLine: widget.focus?.line,
              focusToken: widget.focusToken,
              searchMatches: _searchMatches,
              searchMatchIndex: _searchMatchIndex,
              onLineNumberTap: onLineNumberTap,
            ),
      FilePreviewKind.binary => _MessageView(
          message: l10n.binaryFilePreview(_formatSize(result.sizeBytes ?? 0)),
        ),
      FilePreviewKind.tooLarge => _MessageView(
          message: l10n.fileTooLarge(
            _formatSize(result.sizeBytes ?? 0),
            ProjectFilesService.maxPreviewBytes ~/ 1024,
          ),
        ),
      FilePreviewKind.error =>
        _MessageView(message: result.errorMessage ?? l10n.unknownError),
    };
  }

  bool _isMarkdown(String fileName) {
    return fileName.toLowerCase().endsWith('.md');
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _SvgImagePreview extends StatelessWidget {
  const _SvgImagePreview({required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: IdeaColors.background,
      child: InteractiveViewer(
        minScale: 0.25,
        maxScale: 4,
        child: Center(
          child: SvgPicture.file(
            File(filePath),
            fit: BoxFit.contain,
            placeholderBuilder: (_) => const CircularProgressIndicator(
              color: IdeaColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewToolbar extends StatelessWidget {
  const _PreviewToolbar({
    required this.fileName,
    required this.relativePath,
    required this.onClose,
    this.isSvg = false,
    this.svgMode = SvgPreviewMode.image,
    this.onSvgModeChanged,
    this.supportsSearch = false,
    this.searchController,
    this.searchFocusNode,
    this.searchMatchIndex = 0,
    this.searchMatchCount = 0,
    this.onPreviousMatch,
    this.onNextMatch,
    this.onSearchKey,
    this.supportsCopy = false,
    this.onCopyAll,
    this.onShowFileHistory,
    this.onShowFileGraph,
  });

  final String fileName;
  final String relativePath;
  final VoidCallback onClose;
  final bool isSvg;
  final SvgPreviewMode svgMode;
  final ValueChanged<SvgPreviewMode>? onSvgModeChanged;
  final bool supportsSearch;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final int searchMatchIndex;
  final int searchMatchCount;
  final VoidCallback? onPreviousMatch;
  final VoidCallback? onNextMatch;
  final FocusOnKeyEventCallback? onSearchKey;
  final bool supportsCopy;
  final VoidCallback? onCopyAll;
  final VoidCallback? onShowFileHistory;
  final VoidCallback? onShowFileGraph;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final matchLabel = searchMatchCount == 0
        ? l10n.fileSearchNoMatches
        : l10n.fileSearchMatchCount(searchMatchIndex + 1, searchMatchCount);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: IdeaColors.toolbar,
        border: Border(bottom: BorderSide(color: IdeaColors.panelBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined,
                    size: 14, color: IdeaColors.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                      color: IdeaColors.textBright,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 2,
                  child: Text(
                    relativePath,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (supportsSearch &&
                      searchController != null &&
                      searchFocusNode != null) ...[
                    SizedBox(
                      width: 140,
                      height: 24,
                      child: Focus(
                        onKeyEvent: onSearchKey,
                        child: TextField(
                          controller: searchController,
                          focusNode: searchFocusNode,
                          style: const TextStyle(
                            fontSize: 11,
                            color: IdeaColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: l10n.fileSearchHint,
                            hintStyle: const TextStyle(
                              fontSize: 11,
                              color: IdeaColors.textSecondary,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            prefixIcon: const Icon(Icons.search, size: 14),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 24,
                            ),
                            filled: true,
                            fillColor: IdeaColors.inputBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: IdeaColors.panelBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: IdeaColors.panelBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: IdeaColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 88),
                      child: Text(
                        matchLabel,
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 16),
                      tooltip: l10n.fileSearchPrevious,
                      onPressed: onPreviousMatch,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                      tooltip: l10n.fileSearchNext,
                      onPressed: onNextMatch,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (supportsCopy && onCopyAll != null) ...[
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      tooltip: l10n.fileCopyAll,
                      onPressed: onCopyAll,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (onShowFileHistory != null) ...[
                    IconButton(
                      icon: const Icon(Icons.history, size: 16),
                      tooltip: l10n.gitFileHistory,
                      onPressed: onShowFileHistory,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (onShowFileGraph != null) ...[
                    IconButton(
                      icon: const Icon(Icons.account_tree_outlined, size: 16),
                      tooltip: l10n.gitFileGraph,
                      onPressed: onShowFileGraph,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (isSvg && onSvgModeChanged != null) ...[
                    _SvgModeToggle(
                      mode: svgMode,
                      onChanged: onSvgModeChanged!,
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: l10n.closeFile,
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _SvgModeToggle extends StatelessWidget {
  const _SvgModeToggle({
    required this.mode,
    required this.onChanged,
  });

  final SvgPreviewMode mode;
  final ValueChanged<SvgPreviewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: IdeaColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: IdeaColors.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            label: l10n.viewImage,
            icon: Icons.image_outlined,
            isActive: mode == SvgPreviewMode.image,
            onTap: () => onChanged(SvgPreviewMode.image),
          ),
          Container(width: 1, height: 16, color: IdeaColors.panelBorder),
          _ToggleButton(
            label: l10n.viewText,
            icon: Icons.code,
            isActive: mode == SvgPreviewMode.text,
            onTap: () => onChanged(SvgPreviewMode.text),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 24,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isActive ? IdeaColors.accent : IdeaColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? IdeaColors.textBright : IdeaColors.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
