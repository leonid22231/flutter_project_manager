import 'dart:convert';
import 'dart:io';

import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/models/widget_entry.dart';
import 'package:project_manager/models/widget_origin.dart';
import 'package:project_manager/services/analysis/widget_analysis_backend.dart';
import 'package:project_manager/services/analysis/widget_analysis_result.dart';
import 'package:project_manager/services/cursor_cli_logger.dart';

/// Enriches static widget analysis via Cursor Agent CLI (background-capable).
class CursorCliWidgetAnalysisBackend extends WidgetAnalysisBackend {
  CursorCliWidgetAnalysisBackend({
    required this.settings,
    required this.projectRoot,
    this.baseline,
  });

  final CursorCliSettings settings;
  final String projectRoot;
  final List<WidgetEntry>? baseline;

  final _log = CursorCliLogger.instance;

  @override
  Future<WidgetAnalysisResult> analyze(String projectRoot) async {
    if (!settings.enabled || baseline == null || baseline!.isEmpty) {
      _log.info(
        'Widget enrichment skipped (disabled or empty baseline).',
        source: 'widgets',
        logRoot: projectRoot,
        data: {
          'enabled': settings.enabled,
          'baselineCount': baseline?.length ?? 0,
        },
      );
      return WidgetAnalysisResult(
        widgets: baseline ?? const [],
        enrichedByCursor: false,
      );
    }

    final custom = baseline!
        .where((w) => w.origin == WidgetOrigin.custom)
        .map(
          (w) => {
            'name': w.name,
            'filePath': w.filePath,
            'description': w.description,
          },
        )
        .toList();

    final prompt = '''
Analyze custom Flutter widgets in this project workspace.
Return ONLY valid JSON (no markdown) as an array of objects:
[{"name":"WidgetName","description":"short purpose in one sentence","notes":"optional extra context"}]

Widgets to enrich:
${jsonEncode(custom)}
''';

    final started = DateTime.now();
    _log.info(
      'Starting widget enrichment via Cursor Agent.',
      source: 'widgets',
      logRoot: projectRoot,
      data: {
        'command': settings.cliCommand,
        'model': settings.defaultModel,
        'customWidgets': custom.length,
      },
    );

    try {
      final result = await _runAgent(projectRoot, prompt);
      final elapsed = DateTime.now().difference(started).inMilliseconds;

      if (result.exitCode != 0) {
        _log.error(
          'Agent exited with non-zero code.',
          source: 'widgets',
          logRoot: projectRoot,
          data: {
            'exitCode': result.exitCode,
            'elapsedMs': elapsed,
            'stderr': _truncate(result.stderr.toString()),
          },
        );
        return WidgetAnalysisResult(widgets: baseline!, enrichedByCursor: false);
      }

      final enriched = _mergeEnrichment(baseline!, result.stdout.toString());
      final patched =
          enriched.where((w) => w.enrichedByCursor).length;

      _log.info(
        'Widget enrichment completed.',
        source: 'widgets',
        logRoot: projectRoot,
        data: {
          'elapsedMs': elapsed,
          'patchedWidgets': patched,
          'stdoutPreview': _truncate(result.stdout.toString()),
        },
      );

      return WidgetAnalysisResult(
        widgets: enriched,
        enrichedByCursor: patched > 0,
      );
    } catch (e, stack) {
      _log.error(
        'Widget enrichment failed: $e',
        source: 'widgets',
        logRoot: projectRoot,
        data: {'stack': _truncate(stack.toString(), 400)},
      );
      return WidgetAnalysisResult(widgets: baseline!, enrichedByCursor: false);
    }
  }

  Future<ProcessResult> _runAgent(String projectRoot, String prompt) {
    final env = Map<String, String>.from(Platform.environment);
    if (!settings.useEnvironmentApiKey && settings.apiKey.trim().isNotEmpty) {
      env['CURSOR_API_KEY'] = settings.apiKey.trim();
    }

    final args = <String>[
      '-p',
      '--output-format',
      'json',
      '--mode',
      'ask',
      '--trust',
      '--workspace',
      projectRoot,
      '--model',
      settings.defaultModel,
      prompt,
    ];

    _log.info(
      'Running agent command.',
      source: 'widgets',
      logRoot: projectRoot,
      data: {
        'args': args.take(8).join(' '),
        'promptChars': prompt.length,
      },
    );

    if (Platform.isWindows) {
      return Process.run(
        settings.cliCommand.trim(),
        args,
        environment: env,
        runInShell: true,
      );
    }

    return Process.run(
      settings.cliCommand.trim(),
      args,
      environment: env,
    );
  }

  List<WidgetEntry> _mergeEnrichment(
    List<WidgetEntry> baseline,
    String stdout,
  ) {
    final patches = _parseEnrichmentPatches(stdout);
    if (patches.isEmpty) {
      _log.warn(
        'No enrichment patches parsed from agent output.',
        source: 'widgets',
        logRoot: projectRoot,
        data: {'stdoutPreview': _truncate(stdout)},
      );
      return baseline;
    }

    return baseline
        .map((widget) {
          final patch = patches[widget.name];
          if (patch == null) return widget;

          final description = (patch['description'] as String?)?.trim();
          final notes = (patch['notes'] as String?)?.trim();
          if ((description == null || description.isEmpty) &&
              (notes == null || notes.isEmpty)) {
            return widget;
          }

          return widget.copyWith(
            description: description?.isNotEmpty == true
                ? description
                : widget.description,
            notes: notes?.isNotEmpty == true ? notes : widget.notes,
            enrichedByCursor: true,
          );
        })
        .toList();
  }

  Map<String, Map<String, dynamic>> _parseEnrichmentPatches(String stdout) {
    final text = stdout.trim();
    if (text.isEmpty) return {};

    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return {
          for (final item in decoded)
            if (item is Map<String, dynamic> && item['name'] != null)
              item['name'] as String: item,
        };
      }
      if (decoded is Map<String, dynamic>) {
        final widgets = decoded['widgets'] ?? decoded['result'];
        if (widgets is List) {
          return {
            for (final item in widgets)
              if (item is Map<String, dynamic> && item['name'] != null)
                item['name'] as String: item,
          };
        }
      }
    } catch (_) {
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start != -1 && end > start) {
        try {
          final list = jsonDecode(text.substring(start, end + 1)) as List;
          return {
            for (final item in list)
              if (item is Map<String, dynamic> && item['name'] != null)
                item['name'] as String: item,
          };
        } catch (_) {}
      }
    }
    return {};
  }

  static String _truncate(String value, [int max = 240]) {
    final trimmed = value.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max)}…';
  }
}
