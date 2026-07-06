import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/models/git_commit_graph_entry.dart';

const gitGraphLaneWidth = 14.0;
const gitGraphRowHeight = 60.0;

const _laneColors = [
  IdeaColors.accent,
  IdeaColors.success,
  IdeaColors.warning,
  IdeaColors.hover,
];

class GitCommitGraphPainter extends CustomPainter {
  GitCommitGraphPainter({
    required this.row,
  });

  final GitCommitGraphRow row;

  @override
  void paint(Canvas canvas, Size size) {
    final commitX = _laneCenterX(row.lane);
    final midY = size.height / 2;

    for (final lane in row.activeLanes) {
      final color = _laneColors[lane % _laneColors.length];
      _drawVerticalLine(
        canvas,
        _laneCenterX(lane),
        0,
        size.height,
        color,
      );
    }

    for (final parentLane in row.parentLanes.toSet()) {
      final color = _laneColors[parentLane % _laneColors.length];
      if (parentLane == row.lane) {
        _drawVerticalLine(canvas, commitX, midY, size.height, color);
        continue;
      }

      final parentX = _laneCenterX(parentLane);
      final path = Path()
        ..moveTo(commitX, midY)
        ..lineTo(commitX, size.height - 6)
        ..lineTo(parentX, size.height - 6)
        ..lineTo(parentX, size.height);
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (row.parentLanes.isEmpty) {
      _drawVerticalLine(
        canvas,
        commitX,
        midY,
        size.height,
        _laneColors[row.lane % _laneColors.length].withValues(alpha: 0.35),
      );
    }

    canvas.drawCircle(
      Offset(commitX, midY),
      4,
      Paint()..color = _laneColors[row.lane % _laneColors.length],
    );
    canvas.drawCircle(
      Offset(commitX, midY),
      4,
      Paint()
        ..color = IdeaColors.sidebar
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  double _laneCenterX(int lane) => lane * gitGraphLaneWidth + gitGraphLaneWidth / 2;

  void _drawVerticalLine(
    Canvas canvas,
    double x,
    double top,
    double bottom,
    Color color,
  ) {
    canvas.drawLine(
      Offset(x, top),
      Offset(x, bottom),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant GitCommitGraphPainter oldDelegate) {
    return oldDelegate.row != row;
  }
}
