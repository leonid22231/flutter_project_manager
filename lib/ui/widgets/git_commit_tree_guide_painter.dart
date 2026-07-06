import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/models/git_commit_graph_entry.dart';

const gitTreeIndentWidth = 16.0;
const gitTreeGuideWidth = 20.0;
const gitTreeMaxGuideColumnWidth = 96.0;

class GitCommitTreeGuidePainter extends CustomPainter {
  GitCommitTreeGuidePainter({
    required this.row,
  });

  final GitCommitTreeRow row;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = IdeaColors.panelBorder
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = IdeaColors.accent
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final midY = size.height / 2;

    for (var level = 0; level < row.depth; level++) {
      final x = level * gitTreeIndentWidth + gitTreeIndentWidth / 2;
      if (level < row.ancestorContinues.length && row.ancestorContinues[level]) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
    }

    if (row.depth > 0) {
      final elbowX = (row.depth - 1) * gitTreeIndentWidth + gitTreeIndentWidth / 2;
      final nodeX = row.depth * gitTreeIndentWidth + gitTreeIndentWidth / 2;
      canvas.drawLine(Offset(elbowX, 0), Offset(elbowX, midY), linePaint);
      canvas.drawLine(Offset(elbowX, midY), Offset(nodeX, midY), accentPaint);
      if (!row.isLastSibling) {
        canvas.drawLine(Offset(elbowX, midY), Offset(elbowX, size.height), linePaint);
      }
    }

    final dotX = row.depth * gitTreeIndentWidth + gitTreeIndentWidth / 2;
    canvas.drawCircle(Offset(dotX, midY), 3.5, Paint()..color = IdeaColors.accent);
    canvas.drawCircle(
      Offset(dotX, midY),
      3.5,
      Paint()
        ..color = IdeaColors.sidebar
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant GitCommitTreeGuidePainter oldDelegate) {
    return oldDelegate.row != row;
  }
}
