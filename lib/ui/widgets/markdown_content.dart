import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:project_manager/core/theme/idea_theme.dart';

class MarkdownContent extends StatelessWidget {
  const MarkdownContent({
    super.key,
    required this.data,
    this.selectable = true,
    this.padding = const EdgeInsets.all(16),
  });

  final String data;
  final bool selectable;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: MarkdownBody(
        data: data,
        selectable: selectable,
        extensionSet: md.ExtensionSet.gitHubWeb,
        styleSheet: ideaMarkdownStyleSheet(context),
      ),
    );
  }
}

MarkdownStyleSheet ideaMarkdownStyleSheet(BuildContext context) {
  const mono = TextStyle(
    fontFamily: 'Consolas',
    fontSize: 12,
    color: IdeaColors.textPrimary,
  );

  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    h1: const TextStyle(
      color: IdeaColors.textBright,
      fontSize: 22,
      fontWeight: FontWeight.w600,
    ),
    h2: const TextStyle(
      color: IdeaColors.textBright,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    h3: const TextStyle(
      color: IdeaColors.textBright,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    h4: const TextStyle(
      color: IdeaColors.textBright,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    p: const TextStyle(
      color: IdeaColors.textPrimary,
      fontSize: 13,
      height: 1.5,
    ),
    strong: const TextStyle(
      color: IdeaColors.textBright,
      fontWeight: FontWeight.w600,
    ),
    em: const TextStyle(
      color: IdeaColors.textPrimary,
      fontStyle: FontStyle.italic,
    ),
    blockquote: mono.copyWith(color: IdeaColors.textSecondary),
    blockquoteDecoration: BoxDecoration(
      color: IdeaColors.background,
      border: Border(
        left: BorderSide(color: IdeaColors.accent, width: 3),
      ),
    ),
    blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    code: mono.copyWith(
      color: IdeaColors.accent,
      backgroundColor: IdeaColors.background,
    ),
    codeblockDecoration: BoxDecoration(
      color: IdeaColors.background,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: IdeaColors.panelBorder),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    a: const TextStyle(
      color: IdeaColors.accent,
      decoration: TextDecoration.underline,
    ),
    listBullet: const TextStyle(color: IdeaColors.textSecondary, fontSize: 13),
    tableHead: const TextStyle(
      color: IdeaColors.textBright,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    ),
    tableBody: const TextStyle(color: IdeaColors.textPrimary, fontSize: 12),
    tableBorder: TableBorder.all(color: IdeaColors.panelBorder),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: IdeaColors.panelBorder)),
    ),
  );
}
