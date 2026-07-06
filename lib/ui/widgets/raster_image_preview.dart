import 'dart:io';

import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';

class RasterImagePreview extends StatelessWidget {
  const RasterImagePreview({super.key, required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: IdeaColors.background,
      child: InteractiveViewer(
        minScale: 0.25,
        maxScale: 4,
        child: Center(
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.l10n.failedToLoadImage(error),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
