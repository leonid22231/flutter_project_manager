import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';

/// Card-like block with a drag handle to resize height.
class ResizableBlockFrame extends StatefulWidget {
  const ResizableBlockFrame({
    super.key,
    required this.header,
    required this.child,
    this.initialHeight = 240,
    this.minHeight = 120,
    this.maxHeight = 720,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  final Widget header;
  final Widget child;
  final double initialHeight;
  final double minHeight;
  final double maxHeight;
  final EdgeInsetsGeometry margin;

  @override
  State<ResizableBlockFrame> createState() => _ResizableBlockFrameState();
}

class _ResizableBlockFrameState extends State<ResizableBlockFrame> {
  late double _height;

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight.clamp(widget.minHeight, widget.maxHeight);
  }

  @override
  void didUpdateWidget(covariant ResizableBlockFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _height = _height.clamp(widget.minHeight, widget.maxHeight);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IdeaColors.panelBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.header,
          SizedBox(
            height: _height,
            width: double.infinity,
            child: widget.child,
          ),
          _ResizeHandle(
            onDrag: (delta) {
              setState(() {
                _height = (_height + delta).clamp(
                  widget.minHeight,
                  widget.maxHeight,
                );
              });
            },
          ),
        ],
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
        child: SizedBox(
          height: 14,
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: IdeaColors.panelBorder,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact action buttons that wrap instead of overflowing narrow panels.
class AdaptiveActionBar extends StatelessWidget {
  const AdaptiveActionBar({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

ButtonStyle denseFilledStyle({Color? backgroundColor}) {
  return FilledButton.styleFrom(
    backgroundColor: backgroundColor,
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: const Size(0, 32),
  );
}

ButtonStyle denseOutlinedStyle() {
  return OutlinedButton.styleFrom(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: const Size(0, 32),
  );
}

ButtonStyle denseTextStyle() {
  return TextButton.styleFrom(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    minimumSize: const Size(0, 32),
  );
}
