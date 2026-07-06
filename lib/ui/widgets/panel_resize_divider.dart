import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';

class PanelResizeDivider extends StatefulWidget {
  const PanelResizeDivider({
    super.key,
    required this.axis,
    required this.onDelta,
    this.thickness = 4,
  });

  final Axis axis;
  final ValueChanged<double> onDelta;
  final double thickness;

  @override
  State<PanelResizeDivider> createState() => _PanelResizeDividerState();
}

class _PanelResizeDividerState extends State<PanelResizeDivider> {
  var _hovered = false;
  var _dragging = false;

  @override
  Widget build(BuildContext context) {
    final isVertical = widget.axis == Axis.vertical;
    final active = _hovered || _dragging;
    final color = active ? IdeaColors.accent : IdeaColors.panelBorder;

    return MouseRegion(
      cursor: isVertical
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: isVertical ? _startDrag : null,
        onHorizontalDragUpdate:
            isVertical ? (details) => widget.onDelta(details.delta.dx) : null,
        onHorizontalDragEnd: isVertical ? (_) => _endDrag() : null,
        onVerticalDragStart: !isVertical ? _startDrag : null,
        onVerticalDragUpdate:
            !isVertical ? (details) => widget.onDelta(details.delta.dy) : null,
        onVerticalDragEnd: !isVertical ? (_) => _endDrag() : null,
        child: isVertical
            ? SizedBox(
                width: widget.thickness,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: active ? 2 : 1,
                    color: color,
                  ),
                ),
              )
            : SizedBox(
                height: widget.thickness,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: active ? 2 : 1,
                    color: color,
                  ),
                ),
              ),
      ),
    );
  }

  void _startDrag(_) => setState(() => _dragging = true);

  void _endDrag() => setState(() => _dragging = false);
}

class ResizableSidePanel extends StatelessWidget {
  const ResizableSidePanel({
    super.key,
    required this.width,
    required this.child,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}
