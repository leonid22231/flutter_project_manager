import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/services/app_log_service.dart';

/// Floating log console over the whole IDE.
class LogConsoleOverlay extends StatefulWidget {
  const LogConsoleOverlay({super.key});

  @override
  State<LogConsoleOverlay> createState() => _LogConsoleOverlayState();
}

class _LogConsoleOverlayState extends State<LogConsoleOverlay> {
  final _scroll = ScrollController();
  final _sourceFilter = TextEditingController();
  var _follow = true;
  String _level = '';

  @override
  void initState() {
    super.initState();
    AppLogService.instance.addListener(_onLogs);
  }

  @override
  void dispose() {
    AppLogService.instance.removeListener(_onLogs);
    _scroll.dispose();
    _sourceFilter.dispose();
    super.dispose();
  }

  void _onLogs() {
    if (!mounted) return;
    setState(() {});
    if (_follow && _scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(0); // reversed list — top is newest
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final logs = AppLogService.instance;
    if (!logs.overlayVisible) return const SizedBox.shrink();

    final entries = logs.entries.where((e) {
      if (_level.isNotEmpty && e.level != _level) return false;
      final src = _sourceFilter.text.trim();
      if (src.isNotEmpty &&
          !e.source.toLowerCase().contains(src.toLowerCase())) {
        return false;
      }
      return true;
    }).toList(growable: false);

    return Positioned(
      left: 24,
      right: 24,
      bottom: 36,
      child: Material(
        elevation: 12,
        color: IdeaColors.toolbar,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.38,
          constraints: const BoxConstraints(minHeight: 200, maxHeight: 420),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: IdeaColors.accent.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: IdeaColors.panelBorder),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.terminal, size: 14, color: IdeaColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      l10n.appLogsTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entries.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: IdeaColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 120,
                      height: 28,
                      child: TextField(
                        controller: _sourceFilter,
                        style: const TextStyle(fontSize: 11),
                        decoration: InputDecoration(
                          hintText: l10n.appLogsFilterSource,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _level.isEmpty ? null : _level,
                        hint: Text(
                          l10n.appLogsFilterLevel,
                          style: const TextStyle(fontSize: 11),
                        ),
                        isDense: true,
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(l10n.appLogsAllLevels,
                                style: const TextStyle(fontSize: 11)),
                          ),
                          for (final level in const [
                            'THINK',
                            'INFO',
                            'WARN',
                            'ERROR',
                          ])
                            DropdownMenuItem(
                              value: level,
                              child: Text(level,
                                  style: const TextStyle(fontSize: 11)),
                            ),
                        ],
                        onChanged: (v) => setState(() => _level = v ?? ''),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.appLogsFollow,
                      onPressed: () => setState(() => _follow = !_follow),
                      icon: Icon(
                        _follow
                            ? Icons.vertical_align_bottom
                            : Icons.vertical_align_center,
                        size: 16,
                        color: _follow ? IdeaColors.accent : null,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: l10n.appLogsCopy,
                      onPressed: () async {
                        final text =
                            entries.map((e) => e.format()).join('\n');
                        await Clipboard.setData(ClipboardData(text: text));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.copied)),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: l10n.appLogsClear,
                      onPressed: () => AppLogService.instance.clear(),
                      icon: const Icon(Icons.delete_outline, size: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: () => AppLogService.instance.hideOverlay(),
                      icon: const Icon(Icons.close, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          l10n.appLogsEmpty,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final color = switch (entry.level) {
                            'ERROR' => IdeaColors.error,
                            'WARN' => IdeaColors.warning,
                            'THINK' => IdeaColors.accent,
                            _ => IdeaColors.textPrimary,
                          };
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: SelectableText(
                              entry.format(),
                              style: TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 10.5,
                                height: 1.3,
                                color: color,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
