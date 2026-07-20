import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:project_manager/core/theme/idea_theme.dart';

enum MarkdownContentVariant {
  /// Side panels, lists, dense previews.
  compact,

  /// Agent chat bubbles and streaming answers.
  chat,

  /// Full documents / long-form preview.
  document,
}

class MarkdownContent extends StatelessWidget {
  const MarkdownContent({
    super.key,
    required this.data,
    this.selectable = true,
    this.padding = const EdgeInsets.all(16),
    this.compact = false,
    this.variant,
  });

  final String data;
  final bool selectable;
  final EdgeInsets padding;

  /// Legacy flag — prefer [variant]. When true and [variant] is null → compact.
  final bool compact;
  final MarkdownContentVariant? variant;

  MarkdownContentVariant get _resolvedVariant {
    if (variant != null) return variant!;
    if (compact) return MarkdownContentVariant.compact;
    return MarkdownContentVariant.document;
  }

  @override
  Widget build(BuildContext context) {
    final styleSheet = ideaMarkdownStyleSheet(
      context,
      variant: _resolvedVariant,
    );

    return Padding(
      padding: padding,
      child: MarkdownBody(
        data: data,
        selectable: selectable,
        softLineBreak: true,
        extensionSet: md.ExtensionSet.gitHubWeb,
        styleSheet: styleSheet,
        styleSheetTheme: MarkdownStyleSheetBaseTheme.material,
      ),
    );
  }
}

MarkdownStyleSheet ideaMarkdownStyleSheet(
  BuildContext context, {
  MarkdownContentVariant variant = MarkdownContentVariant.document,
}) {
  final theme = Theme.of(context);
  final isCompact = variant == MarkdownContentVariant.compact;
  final isChat = variant == MarkdownContentVariant.chat;

  final bodySize = isCompact ? 11.5 : (isChat ? 12.5 : 13.0);
  final h1Size = isCompact ? 15.0 : (isChat ? 16.0 : 22.0);
  final h2Size = isCompact ? 13.5 : (isChat ? 14.5 : 18.0);
  final h3Size = isCompact ? 12.5 : (isChat ? 13.0 : 15.0);
  final codeSize = isCompact ? 10.5 : (isChat ? 11.0 : 12.0);
  final lineHeight = isCompact ? 1.4 : (isChat ? 1.45 : 1.55);

  const monoFamily = 'Consolas';

  final pStyle = TextStyle(
    color: IdeaColors.textPrimary,
    fontSize: bodySize,
    height: lineHeight,
  );

  final mono = TextStyle(
    fontFamily: monoFamily,
    fontSize: codeSize,
    color: IdeaColors.textPrimary,
    height: 1.4,
  );

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    blockSpacing: isCompact ? 6 : (isChat ? 12 : 10),
    listIndent: isCompact ? 18 : 26,
    checkbox: TextStyle(
      color: IdeaColors.accent,
      fontSize: bodySize,
    ),
    h1: TextStyle(
      color: IdeaColors.textBright,
      fontSize: h1Size,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.2,
    ),
    h1Padding: EdgeInsets.only(
      top: isCompact ? 4 : 8,
      bottom: isCompact ? 4 : 10,
    ),
    h2: TextStyle(
      color: IdeaColors.textBright,
      fontSize: h2Size,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    h2Padding: EdgeInsets.only(
      top: isCompact ? 6 : 14,
      bottom: isCompact ? 4 : 8,
    ),
    h3: TextStyle(
      color: IdeaColors.textBright,
      fontSize: h3Size,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    h3Padding: EdgeInsets.only(
      top: isCompact ? 4 : 10,
      bottom: isCompact ? 2 : 6,
    ),
    h4: TextStyle(
      color: IdeaColors.textBright,
      fontSize: isCompact ? 11.5 : 13.5,
      fontWeight: FontWeight.w600,
    ),
    h4Padding: const EdgeInsets.only(top: 8, bottom: 4),
    p: pStyle,
    pPadding: EdgeInsets.only(bottom: isCompact ? 2 : 4),
    strong: const TextStyle(
      color: IdeaColors.textBright,
      fontWeight: FontWeight.w700,
    ),
    em: TextStyle(
      color: IdeaColors.textPrimary,
      fontStyle: FontStyle.italic,
      fontSize: bodySize,
    ),
    del: TextStyle(
      color: IdeaColors.textSecondary,
      decoration: TextDecoration.lineThrough,
      fontSize: bodySize,
    ),
    blockquote: mono.copyWith(
      color: IdeaColors.textSecondary,
      fontFamily: null,
      fontSize: bodySize,
      fontStyle: FontStyle.italic,
    ),
    blockquoteDecoration: BoxDecoration(
      color: IdeaColors.accent.withValues(alpha: 0.08),
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(6),
        bottomRight: Radius.circular(6),
      ),
      border: const Border(
        left: BorderSide(color: IdeaColors.accent, width: 3),
      ),
    ),
    blockquotePadding: EdgeInsets.symmetric(
      horizontal: isCompact ? 8 : 12,
      vertical: isCompact ? 6 : 10,
    ),
    code: mono.copyWith(
      color: IdeaColors.accent,
      backgroundColor: IdeaColors.background.withValues(alpha: 0.9),
    ),
    codeblockDecoration: BoxDecoration(
      color: const Color(0xFF1A1D24),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: IdeaColors.panelBorder),
    ),
    codeblockPadding: EdgeInsets.all(isCompact ? 8 : 14),
    a: const TextStyle(
      color: IdeaColors.accent,
      decoration: TextDecoration.underline,
      decorationColor: IdeaColors.accent,
    ),
    listBullet: TextStyle(
      color: IdeaColors.accent,
      fontSize: bodySize,
      fontWeight: FontWeight.w600,
      height: lineHeight,
    ),
    listBulletPadding: const EdgeInsets.only(right: 8),
    tableHead: TextStyle(
      color: IdeaColors.textBright,
      fontWeight: FontWeight.w700,
      fontSize: isCompact ? 11 : 12.5,
    ),
    tableBody: TextStyle(
      color: IdeaColors.textPrimary,
      fontSize: isCompact ? 10.5 : 12,
      height: 1.4,
    ),
    tableBorder: TableBorder.all(
      color: IdeaColors.panelBorder,
      borderRadius: BorderRadius.circular(6),
    ),
    tableHeadAlign: TextAlign.left,
    tableCellsPadding: EdgeInsets.symmetric(
      horizontal: isCompact ? 6 : 10,
      vertical: isCompact ? 4 : 8,
    ),
    tableColumnWidth: const FlexColumnWidth(),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: IdeaColors.panelBorder.withValues(alpha: 0.9),
          width: 1,
        ),
      ),
    ),
  );
}
