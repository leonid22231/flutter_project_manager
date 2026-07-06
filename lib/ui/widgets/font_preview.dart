import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/file_type_utils.dart';
import 'package:project_manager/l10n/app_localizations.dart';

class FontPreview extends StatefulWidget {
  const FontPreview({
    super.key,
    required this.filePath,
    this.compact = false,
    this.sampleText,
  });

  final String filePath;
  final bool compact;
  final String? sampleText;

  @override
  State<FontPreview> createState() => _FontPreviewState();
}

class _FontPreviewState extends State<FontPreview> {
  String? _fontFamily;
  String? _error;
  bool _loading = true;
  bool _unsupportedFormat = false;

  @override
  void initState() {
    super.initState();
    _loadFont();
  }

  @override
  void didUpdateWidget(FontPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadFont();
    }
  }

  Future<void> _loadFont() async {
    setState(() {
      _loading = true;
      _error = null;
      _fontFamily = null;
      _unsupportedFormat = false;
    });

    final fileName = widget.filePath.split(Platform.pathSeparator).last;
    if (!isPreviewableFontFile(fileName)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _unsupportedFormat = true;
        });
      }
      return;
    }

    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final family = 'pm_font_${md5.convert(bytes).toString().substring(0, 10)}';
      final loader = FontLoader(family);
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      if (!mounted) return;
      setState(() {
        _fontFamily = family;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: IdeaColors.accent,
          ),
        ),
      );
    }

    if (_unsupportedFormat) {
      return _FontPreviewMessage(
        icon: Icons.font_download_outlined,
        message: l10n.mediaFontUnsupportedFormat,
      );
    }

    if (_error != null) {
      return _FontPreviewMessage(
        icon: Icons.broken_image_outlined,
        message: l10n.failedToLoadFont(_error!),
      );
    }

    final family = _fontFamily;
    if (family == null) {
      return _FontPreviewMessage(
        icon: Icons.font_download_outlined,
        message: l10n.failedToLoadFont(''),
      );
    }

    final sample = widget.sampleText ?? l10n.mediaFontPreviewSample;

    if (widget.compact) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            sample,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: family,
              fontSize: 28,
              color: IdeaColors.textBright,
              height: 1.1,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Aa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: family,
                    fontSize: 56,
                    color: IdeaColors.textBright,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  sample,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: family,
                    fontSize: 18,
                    color: IdeaColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                for (final size in const [12.0, 16.0, 24.0, 32.0])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${size.toInt()}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: IdeaColors.textSecondary,
                              fontFamily: 'Consolas',
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            sample,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: family,
                              fontSize: size,
                              color: IdeaColors.textBright,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FontPreviewMessage extends StatelessWidget {
  const _FontPreviewMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: IdeaColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
