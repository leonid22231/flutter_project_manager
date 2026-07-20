import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/services/mermaid_render_service.dart';
import 'package:project_manager/ui/widgets/mermaid_diagram.dart';
import 'package:project_manager/ui/widgets/resizable_block.dart';

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
    final resolved = _resolvedVariant;
    final styleSheet = ideaMarkdownStyleSheet(context, variant: resolved);
    final isCompact = resolved == MarkdownContentVariant.compact;
    final isChat = resolved == MarkdownContentVariant.chat;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final body = MarkdownBody(
          data: _normalizeMarkdown(data),
          selectable: selectable,
          softLineBreak: true,
          // Fill available width in chat so blocks don't overflow sideways.
          fitContent: !isChat && !isCompact,
          extensionSet: md.ExtensionSet.gitHubWeb,
          styleSheet: styleSheet,
          styleSheetTheme: MarkdownStyleSheetBaseTheme.material,
          builders: {
            'pre': _PreBlockBuilder(compact: isCompact),
          },
        );

        final padded = Padding(padding: padding, child: body);
        if (!maxW.isFinite) return padded;
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: padded,
        );
      },
    );
  }
}

/// Normalize agent quirks: promote diagram fences, fix lone mermaid headers.
String _normalizeMarkdown(String raw) {
  var text = raw.replaceAll('\r\n', '\n');

  // ```\nflowchart → ```mermaid\nflowchart (and similar starters)
  text = text.replaceAllMapped(
    RegExp(
      r'```([^\n`]*)\n(?=(?:flowchart|graph|sequenceDiagram|classDiagram|'
      r'stateDiagram|erDiagram|journey|gantt|pie|mindmap|timeline|gitGraph|'
      r'quadrantChart|C4Context|block-beta)\b)',
      multiLine: true,
    ),
    (match) {
      final lang = match.group(1)?.trim() ?? '';
      if (lang.isEmpty || lang.toLowerCase() == 'text') {
        return '```mermaid\n';
      }
      return match.group(0)!;
    },
  );

  return text;
}

class _PreBlockBuilder extends MarkdownElementBuilder {
  _PreBlockBuilder({required this.compact});

  final bool compact;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    md.Element? codeEl;
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'code') {
        codeEl = child;
        break;
      }
    }

    final source = (codeEl ?? element).textContent;
    final className = codeEl?.attributes['class'] ?? '';
    var language = className.replaceFirst(RegExp(r'^language-'), '').trim();
    if (language.contains(' ')) {
      language = language.split(RegExp(r'\s+')).first;
    }

    final isMermaid =
        language.toLowerCase() == 'mermaid' || looksLikeMermaidSource(source);
    if (isMermaid) {
      return MermaidDiagramView(source: source, compact: compact);
    }

    return _FencedCodeBlock(
      code: source,
      language: language,
      compact: compact,
    );
  }
}

class _FencedCodeBlock extends StatelessWidget {
  const _FencedCodeBlock({
    required this.code,
    required this.language,
    required this.compact,
  });

  final String code;
  final String language;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = language.isEmpty ? 'code' : language;
    final highlightLang = _mapHighlightLanguage(language);
    final fontSize = compact ? 10.5 : 12.0;
    final lineCount = '\n'.allMatches(code).length + 1;
    final initialH = (lineCount * (fontSize * 1.45) + 24)
        .clamp(compact ? 100.0 : 140.0, compact ? 220.0 : 280.0);

    return ResizableBlockFrame(
      initialHeight: initialH,
      minHeight: compact ? 80 : 100,
      maxHeight: 640,
      margin: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
      header: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: IdeaColors.sidebar.withValues(alpha: 0.9),
          border: Border(
            bottom: BorderSide(
              color: IdeaColors.panelBorder.withValues(alpha: 0.85),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: IdeaColors.textBright,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              icon: const Icon(Icons.copy, size: 13),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              style: IconButton.styleFrom(
                minimumSize: const Size(28, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          compact ? 10 : 12,
          compact ? 8 : 10,
          compact ? 10 : 12,
          compact ? 8 : 10,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 100),
            child: HighlightView(
              code.trimRight(),
              language: highlightLang,
              theme: atomOneDarkTheme,
              textStyle: TextStyle(
                fontFamily: 'Consolas',
                fontSize: fontSize,
                height: 1.45,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _mapHighlightLanguage(String language) {
    final lang = language.toLowerCase();
    if (lang.isEmpty || lang == 'text' || lang == 'plain') return 'plaintext';
    if (lang == 'js' || lang == 'javascript') return 'javascript';
    if (lang == 'ts' || lang == 'typescript') return 'typescript';
    if (lang == 'yml') return 'yaml';
    if (lang == 'sh' || lang == 'shell' || lang == 'bash' || lang == 'zsh') {
      return 'bash';
    }
    if (lang == 'kt') return 'kotlin';
    if (lang == 'cs' || lang == 'csharp') return 'csharp';
    if (lang == 'c++' || lang == 'cpp') return 'cpp';
    if (lang == 'objc' || lang == 'objectivec') return 'objectivec';
    if (lang == 'md' || lang == 'markdown') return 'markdown';
    return lang;
  }
}

MarkdownStyleSheet ideaMarkdownStyleSheet(
  BuildContext context, {
  MarkdownContentVariant variant = MarkdownContentVariant.document,
}) {
  final theme = Theme.of(context);
  final isCompact = variant == MarkdownContentVariant.compact;
  final isChat = variant == MarkdownContentVariant.chat;

  final bodySize = isCompact ? 12.0 : (isChat ? 13.5 : 13.5);
  final h1Size = isCompact ? 16.0 : (isChat ? 18.0 : 22.0);
  final h2Size = isCompact ? 14.5 : (isChat ? 16.0 : 18.0);
  final h3Size = isCompact ? 13.0 : (isChat ? 14.5 : 15.5);
  final codeSize = isCompact ? 11.0 : (isChat ? 12.0 : 12.0);
  final lineHeight = isCompact ? 1.45 : (isChat ? 1.55 : 1.55);

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
    height: 1.45,
  );

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    blockSpacing: isCompact ? 8 : (isChat ? 14 : 12),
    listIndent: isCompact ? 20 : 28,
    checkbox: TextStyle(
      color: IdeaColors.accent,
      fontSize: bodySize,
    ),
    h1: TextStyle(
      color: IdeaColors.textBright,
      fontSize: h1Size,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.25,
    ),
    h1Padding: EdgeInsets.only(
      top: isCompact ? 6 : 10,
      bottom: isCompact ? 6 : 10,
    ),
    h2: TextStyle(
      color: IdeaColors.textBright,
      fontSize: h2Size,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    h2Padding: EdgeInsets.only(
      top: isCompact ? 8 : 16,
      bottom: isCompact ? 4 : 8,
    ),
    h3: TextStyle(
      color: IdeaColors.textBright,
      fontSize: h3Size,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    h3Padding: EdgeInsets.only(
      top: isCompact ? 6 : 12,
      bottom: isCompact ? 4 : 6,
    ),
    h4: TextStyle(
      color: IdeaColors.textBright,
      fontSize: isCompact ? 12.0 : 13.5,
      fontWeight: FontWeight.w600,
    ),
    h4Padding: const EdgeInsets.only(top: 8, bottom: 4),
    p: pStyle,
    pPadding: EdgeInsets.only(bottom: isCompact ? 4 : 8),
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
    blockquote: pStyle.copyWith(
      color: IdeaColors.textSecondary,
      fontStyle: FontStyle.italic,
    ),
    blockquoteDecoration: BoxDecoration(
      color: IdeaColors.accent.withValues(alpha: 0.07),
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(8),
        bottomRight: Radius.circular(8),
      ),
      border: const Border(
        left: BorderSide(color: IdeaColors.accent, width: 3),
      ),
    ),
    blockquotePadding: EdgeInsets.symmetric(
      horizontal: isCompact ? 10 : 14,
      vertical: isCompact ? 8 : 12,
    ),
    code: mono.copyWith(
      color: const Color(0xFFE6C07B),
      backgroundColor: const Color(0xFF1A1D24),
    ),
    // Fenced blocks are custom-built; keep a sane fallback.
    codeblockDecoration: BoxDecoration(
      color: const Color(0xFF1A1D24),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: IdeaColors.panelBorder),
    ),
    codeblockPadding: EdgeInsets.all(isCompact ? 10 : 14),
    a: const TextStyle(
      color: IdeaColors.accent,
      decoration: TextDecoration.underline,
      decorationColor: IdeaColors.accent,
    ),
    listBullet: TextStyle(
      color: IdeaColors.accent,
      fontSize: bodySize,
      fontWeight: FontWeight.w700,
      height: lineHeight,
    ),
    listBulletPadding: const EdgeInsets.only(right: 10),
    tableHead: TextStyle(
      color: IdeaColors.textBright,
      fontWeight: FontWeight.w700,
      fontSize: isCompact ? 11.5 : 13,
    ),
    tableBody: TextStyle(
      color: IdeaColors.textPrimary,
      fontSize: isCompact ? 11 : 12.5,
      height: 1.45,
    ),
    tableBorder: TableBorder.all(
      color: IdeaColors.panelBorder,
      borderRadius: BorderRadius.circular(8),
      width: 1,
    ),
    tableHeadAlign: TextAlign.left,
    tableCellsPadding: EdgeInsets.symmetric(
      horizontal: isCompact ? 8 : 12,
      vertical: isCompact ? 6 : 10,
    ),
    tableColumnWidth: const FlexColumnWidth(),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: IdeaColors.panelBorder.withValues(alpha: 0.95),
          width: 1,
        ),
      ),
    ),
  );
}
