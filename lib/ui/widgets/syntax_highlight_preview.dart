import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/theme/syntax_theme.dart';
import 'package:project_manager/core/utils/syntax_language.dart';
import 'package:project_manager/core/utils/text_search.dart';

class SyntaxHighlightPreview extends StatefulWidget {
  const SyntaxHighlightPreview({
    super.key,
    required this.content,
    required this.fileName,
    this.highlightLine,
    this.focusToken = 0,
    this.searchMatches = const [],
    this.searchMatchIndex = 0,
    this.onLineNumberTap,
  });

  final String content;
  final String fileName;
  final int? highlightLine;
  final int focusToken;
  final List<TextSearchMatch> searchMatches;
  final int searchMatchIndex;
  final ValueChanged<int>? onLineNumberTap;

  static const verticalPadding = 12.0;
  static const charWidth = 7.2;

  static String normalizeContent(String content) =>
      content.replaceAll('\t', '        ');

  @override
  State<SyntaxHighlightPreview> createState() => _SyntaxHighlightPreviewState();
}

class _SyntaxHighlightPreviewState extends State<SyntaxHighlightPreview> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();
  int _lastHandledFocusToken = 0;

  @override
  void initState() {
    super.initState();
    _textController.text =
        SyntaxHighlightPreview.normalizeContent(widget.content);
    _scheduleScrollToFocus();
  }

  @override
  void didUpdateWidget(SyntaxHighlightPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _lastHandledFocusToken = 0;
      _textController.text =
          SyntaxHighlightPreview.normalizeContent(widget.content);
    }
    if (oldWidget.focusToken != widget.focusToken ||
        oldWidget.highlightLine != widget.highlightLine ||
        oldWidget.searchMatchIndex != widget.searchMatchIndex ||
        oldWidget.searchMatches != widget.searchMatches ||
        oldWidget.content != widget.content) {
      _scheduleScrollToFocus();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _scheduleScrollToFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus(retry: 3));
  }

  void _scrollToFocus({int retry = 0}) {
    if (!_verticalController.hasClients) {
      if (retry > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToFocus(retry: retry - 1),
        );
      }
      return;
    }

    final pendingNavigation = widget.highlightLine != null &&
        widget.focusToken > 0 &&
        widget.focusToken != _lastHandledFocusToken;

    if (pendingNavigation) {
      _lastHandledFocusToken = widget.focusToken;
      _scrollToLine(widget.highlightLine!);
      return;
    }

    if (widget.searchMatches.isNotEmpty) {
      final index =
          widget.searchMatchIndex.clamp(0, widget.searchMatches.length - 1);
      _scrollToMatch(widget.searchMatches[index]);
      return;
    }

    final line = widget.highlightLine;
    if (line != null) {
      _scrollToLine(line);
    }
  }

  void _scrollToLine(int line) {
    if (!_verticalController.hasClients) return;

    final target = SyntaxHighlightPreview.verticalPadding +
        (line - 1) * ideaCodeLineHeight;
    final viewport = _verticalController.position.viewportDimension;
    final maxScroll = _verticalController.position.maxScrollExtent;
    final scrollTo = (target - viewport / 3).clamp(0.0, maxScroll);

    _verticalController.animateTo(
      scrollTo,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollToMatch(TextSearchMatch match) {
    _scrollToLine(match.line);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_horizontalController.hasClients) return;

      final lines = SyntaxHighlightPreview.normalizeContent(widget.content)
          .split('\n');
      final lineNumberWidth = _lineNumberWidth(lines.length);
      final target = lineNumberWidth +
          match.column * SyntaxHighlightPreview.charWidth -
          48;
      final maxScroll = _horizontalController.position.maxScrollExtent;

      _horizontalController.animateTo(
        target.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  double _lineNumberWidth(int lineCount) {
    final digits = lineCount.toString().length;
    return 16.0 + digits * 8.0;
  }

  double _contentWidth(List<String> lines) {
    var maxLength = 1;
    for (final line in lines) {
      if (line.length > maxLength) maxLength = line.length;
    }
    return maxLength * SyntaxHighlightPreview.charWidth + 32;
  }

  Color? _lineBackground(int lineNumber) {
    if (widget.searchMatches.isNotEmpty) {
      final currentMatch = widget.searchMatches[
          widget.searchMatchIndex.clamp(0, widget.searchMatches.length - 1)];
      final isCurrentMatch = currentMatch.line == lineNumber;
      final isMatchLine =
          widget.searchMatches.any((match) => match.line == lineNumber);

      if (isCurrentMatch) return IdeaColors.selected.withValues(alpha: 0.65);
      if (isMatchLine) return IdeaColors.selected.withValues(alpha: 0.35);
    }

    if (widget.highlightLine == lineNumber) {
      return IdeaColors.hover.withValues(alpha: 0.55);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final language = syntaxLanguageForFile(widget.fileName);
    final normalizedContent =
        SyntaxHighlightPreview.normalizeContent(widget.content);
    final lines = normalizedContent.split('\n');
    final lineNumberWidth = _lineNumberWidth(lines.length);
    final contentWidth = _contentWidth(lines);

    return Material(
      color: IdeaColors.background,
      child: TextSelectionTheme(
        data: TextSelectionThemeData(
          selectionColor: IdeaColors.selected.withValues(alpha: 0.55),
          cursorColor: Colors.transparent,
          selectionHandleColor: IdeaColors.accent,
        ),
        child: Scrollbar(
          controller: _verticalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalController,
            padding: const EdgeInsets.all(
              SyntaxHighlightPreview.verticalPadding,
            ),
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              notificationPredicate: (notification) => notification.depth == 1,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: lineNumberWidth + contentWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LineNumbersColumn(
                        lineCount: lines.length,
                        width: lineNumberWidth,
                        lineBackground: _lineBackground,
                        onLineTap: widget.onLineNumberTap,
                      ),
                      SizedBox(
                        width: contentWidth,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < lines.length; i++)
                                  Container(
                                    height: ideaCodeLineHeight,
                                    color: _lineBackground(i + 1),
                                  ),
                              ],
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: language != null
                                    ? HighlightView(
                                        normalizedContent,
                                        language: language,
                                        theme: ideaSyntaxTheme,
                                        textStyle: ideaCodeTextStyle,
                                        padding: EdgeInsets.zero,
                                      )
                                    : Text(
                                        normalizedContent,
                                        style: ideaCodeTextStyle.copyWith(
                                          color: IdeaColors.textPrimary,
                                        ),
                                      ),
                              ),
                            ),
                            TextField(
                              readOnly: true,
                              controller: _textController,
                              focusNode: _textFocusNode,
                              maxLines: lines.length,
                              minLines: lines.length,
                              style: ideaCodeTextStyle.copyWith(
                                color: Colors.transparent,
                              ),
                              strutStyle: const StrutStyle(
                                fontFamily: 'Consolas',
                                fontSize: 12,
                                height: 1.5,
                                forceStrutHeight: true,
                                leadingDistribution:
                                    TextLeadingDistribution.even,
                              ),
                              cursorWidth: 0,
                              showCursor: false,
                              enableInteractiveSelection: true,
                              mouseCursor: SystemMouseCursors.text,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isCollapsed: true,
                                filled: false,
                              ),
                              contextMenuBuilder:
                                  (context, editableTextState) {
                                return AdaptiveTextSelectionToolbar.editableText(
                                  editableTextState: editableTextState,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LineNumbersColumn extends StatelessWidget {
  const _LineNumbersColumn({
    required this.lineCount,
    required this.width,
    required this.lineBackground,
    this.onLineTap,
  });

  final int lineCount;
  final double width;
  final Color? Function(int lineNumber) lineBackground;
  final ValueChanged<int>? onLineTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 1; i <= lineCount; i++)
            _LineNumberCell(
              lineNumber: i,
              width: width,
              backgroundColor: lineBackground(i),
              onTap: onLineTap != null ? () => onLineTap!(i) : null,
            ),
        ],
      ),
    );
  }
}

class _LineNumberCell extends StatelessWidget {
  const _LineNumberCell({
    required this.lineNumber,
    required this.width,
    this.backgroundColor,
    this.onTap,
  });

  final int lineNumber;
  final double width;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      '$lineNumber',
      style: TextStyle(
        fontFamily: 'Consolas',
        fontSize: 12,
        height: 1.0,
        color: onTap != null
            ? IdeaColors.accent
            : (backgroundColor != null
                ? IdeaColors.textBright
                : IdeaColors.textSecondary),
        fontWeight: backgroundColor != null || onTap != null
            ? FontWeight.w600
            : FontWeight.normal,
        decoration: onTap != null ? TextDecoration.underline : null,
      ),
    );

    return Container(
      width: width,
      height: ideaCodeLineHeight,
      color: backgroundColor,
      padding: const EdgeInsets.only(right: 12),
      alignment: Alignment.centerRight,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              child: text,
            )
          : text,
    );
  }
}
