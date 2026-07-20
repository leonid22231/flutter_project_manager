import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/agent_progress_step.dart';
import 'package:project_manager/ui/widgets/markdown_content.dart';

class AgentProgressPanel extends StatefulWidget {
  const AgentProgressPanel({
    super.key,
    required this.steps,
    required this.title,
    this.isLive = false,
    this.partialOutput = '',
    this.expanded,
    this.onToggle,
  });

  final List<AgentProgressStep> steps;
  final String title;
  final bool isLive;
  final String partialOutput;
  final bool? expanded;
  final VoidCallback? onToggle;

  @override
  State<AgentProgressPanel> createState() => _AgentProgressPanelState();
}

class _AgentProgressPanelState extends State<AgentProgressPanel> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded ?? true;
  }

  @override
  void didUpdateWidget(covariant AgentProgressPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != null) {
      _expanded = widget.expanded!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.steps.isEmpty && !widget.isLive) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: IdeaColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IdeaColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              if (widget.onToggle != null) {
                widget.onToggle!();
              } else {
                setState(() => _expanded = !_expanded);
              }
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    widget.isLive ? Icons.psychology : Icons.psychology_outlined,
                    size: 14,
                    color: IdeaColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.isLive)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: IdeaColors.accent,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    (widget.expanded ?? _expanded)
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (widget.expanded ?? _expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: widget.steps.isEmpty
                  ? Text(
                      l10n.analysisReasoningEmpty,
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final step in widget.steps)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    step.isError
                                        ? Icons.error_outline
                                        : step.isComplete
                                            ? Icons.check_circle_outline
                                            : Icons.radio_button_unchecked,
                                    size: 12,
                                    color: step.isError
                                        ? Colors.redAccent
                                        : step.isComplete
                                            ? IdeaColors.accent
                                            : IdeaColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: MarkdownContent(
                                    data: step.text,
                                    padding: EdgeInsets.zero,
                                    compact: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.partialOutput.trim().isNotEmpty) ...[
                          const Divider(height: 16),
                          Text(
                            l10n.agentSelfAnalysisRawOutputLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          MarkdownContent(
                            data: widget.partialOutput,
                            padding: EdgeInsets.zero,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
