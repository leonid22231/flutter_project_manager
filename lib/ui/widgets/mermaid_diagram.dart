import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/services/mermaid_render_service.dart';
import 'package:project_manager/ui/widgets/resizable_block.dart';

/// Renders a Mermaid diagram as a raster image (PNG/JPEG), height-resizable.
class MermaidDiagramView extends StatefulWidget {
  const MermaidDiagramView({
    super.key,
    required this.source,
    this.compact = false,
  });

  final String source;
  final bool compact;

  @override
  State<MermaidDiagramView> createState() => _MermaidDiagramViewState();
}

class _MermaidDiagramViewState extends State<MermaidDiagramView> {
  late Future<Uint8List> _future;
  var _showSource = false;

  @override
  void initState() {
    super.initState();
    _future = MermaidRenderService.instance.renderImage(widget.source);
  }

  @override
  void didUpdateWidget(covariant MermaidDiagramView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _future = MermaidRenderService.instance.renderImage(widget.source);
      _showSource = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialH = widget.compact ? 180.0 : 260.0;
    return ResizableBlockFrame(
      initialHeight: initialH,
      minHeight: widget.compact ? 100 : 140,
      maxHeight: 720,
      header: _Header(
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: widget.source));
        },
        onToggleSource: () => setState(() => _showSource = !_showSource),
        showSource: _showSource,
        onRetry: () => setState(() {
          _future = MermaidRenderService.instance.renderImage(widget.source);
        }),
      ),
      child: _showSource
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: SelectableText(
                widget.source.trim(),
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: widget.compact ? 10.5 : 11.5,
                  height: 1.45,
                  color: IdeaColors.textPrimary,
                ),
              ),
            )
          : FutureBuilder<Uint8List>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: _ErrorPane(
                      message: snapshot.error?.toString() ??
                          'Failed to render diagram',
                      source: widget.source,
                      compact: widget.compact,
                      onRetry: () => setState(() {
                        _future = MermaidRenderService.instance
                            .renderImage(widget.source);
                      }),
                      onShowSource: () =>
                          setState(() => _showSource = true),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 320.0;
                    final h = constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : initialH;
                    return ColoredBox(
                      color: const Color(0xFFEEF1F5),
                      child: ClipRect(
                        child: InteractiveViewer(
                          minScale: 0.4,
                          maxScale: 4,
                          boundaryMargin: const EdgeInsets.all(64),
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: w,
                            height: h,
                            child: Image.memory(
                              snapshot.data!,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.medium,
                              gaplessPlayback: true,
                              errorBuilder: (_, error, _) => Center(
                                child: Text(
                                  'Image decode failed: $error',
                                  style: const TextStyle(
                                    color: IdeaColors.error,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onCopy,
    required this.onToggleSource,
    required this.showSource,
    required this.onRetry,
  });

  final VoidCallback onCopy;
  final VoidCallback onToggleSource;
  final bool showSource;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: IdeaColors.sidebar.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: IdeaColors.panelBorder.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_tree_outlined,
            size: 14,
            color: IdeaColors.accent,
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'mermaid',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: IdeaColors.textBright,
                letterSpacing: 0.3,
              ),
            ),
          ),
          _TinyIconButton(
            tooltip: showSource ? 'Show diagram' : 'Show source',
            onPressed: onToggleSource,
            icon: showSource ? Icons.image_outlined : Icons.code,
          ),
          _TinyIconButton(
            tooltip: 'Retry',
            onPressed: onRetry,
            icon: Icons.refresh,
          ),
          _TinyIconButton(
            tooltip: 'Copy source',
            onPressed: onCopy,
            icon: Icons.copy,
          ),
        ],
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      style: IconButton.styleFrom(
        minimumSize: const Size(28, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({
    required this.message,
    required this.source,
    required this.compact,
    required this.onRetry,
    required this.onShowSource,
  });

  final String message;
  final String source;
  final bool compact;
  final VoidCallback onRetry;
  final VoidCallback onShowSource;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(fontSize: 11.5, color: IdeaColors.error),
        ),
        const SizedBox(height: 8),
        AdaptiveActionBar(
          children: [
            TextButton.icon(
              onPressed: onRetry,
              style: denseTextStyle(),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              onPressed: onShowSource,
              style: denseTextStyle(),
              child: const Text('Source', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SelectableText(
          source.trim(),
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: compact ? 10 : 11,
            height: 1.4,
            color: IdeaColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
