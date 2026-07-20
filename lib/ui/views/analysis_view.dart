import 'package:flutter/material.dart';
import 'package:project_manager/core/utils/user_language_utils.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/services/agent_context_orchestrator.dart';
import 'package:project_manager/services/analysis/cursor_cli_project_qa_service.dart';
import 'package:project_manager/services/cursor_cli_logger.dart';
import 'package:project_manager/services/project_context_service.dart';
import 'package:project_manager/ui/widgets/markdown_content.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:provider/provider.dart';

class AnalysisView extends StatefulWidget {
  const AnalysisView({super.key});

  @override
  State<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends State<AnalysisView> {
  final _contextService = ProjectContextService();
  final _contextOrchestrator = AgentContextOrchestrator();
  late final _qaService = CursorCliProjectQaService(
    contextOrchestrator: _contextOrchestrator,
  );
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isBuildingContext = false;
  bool _isAsking = false;
  String? _contextError;
  ProjectContextFileInfo? _contextInfo;
  final List<ProjectQaMessage> _messages = [];
  String? _lastProjectId;
  var _showCursorLog = false;
  String _liveAnswer = '';
  List<ProjectQaReasoningStep> _liveReasoningSteps = const [];
  var _liveReasoningExpanded = true;

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final project = context.read<ProjectManagerState>().selectedProject;
    if (project == null) return;
    if (_lastProjectId == project.id) return;

    _lastProjectId = project.id;
    _messages.clear();
    _contextError = null;
    _contextInfo = _contextService.readExisting(project.path);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureContext(projectId: project.id);
    });
  }

  Future<void> _ensureContext({required String projectId, bool force = false}) async {
    if (_isBuildingContext) return;

    final state = context.read<ProjectManagerState>();
    final project = state.selectedProject;
    if (project == null || project.id != projectId) return;

    if (!force && _contextInfo != null) return;

    setState(() {
      _isBuildingContext = true;
      _contextError = null;
    });

    final result = await _contextOrchestrator.refreshFullContext(
      ProjectContextRefreshInput(
        project: project,
        gitStatus: state.gitRepositoryStatus,
        globalPackageMetadata: state.globalPackageMetadata,
      ),
      languageCode: context.l10n.locale.languageCode,
    );

    if (!mounted || state.selectedProject?.id != projectId) return;

    setState(() {
      _isBuildingContext = false;
      if (result.isSuccess) {
        _contextInfo = ProjectContextFileInfo(
          filePath: result.filePath,
          generatedAt: result.generatedAt,
          sizeBytes: result.sizeBytes,
          version: 1,
        );
        _contextError = null;
      } else {
        _contextError = result.error;
      }
    });
  }

  Future<void> _askQuestion() async {
    final l10n = context.l10n;
    final state = context.read<ProjectManagerState>();
    final settings = context.read<AppSettingsState>().cursorCliSettings;
    final project = state.selectedProject;
    final question = _questionController.text.trim();

    if (project == null || question.isEmpty || _isAsking) return;

    if (!settings.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.analysisCursorDisabled)),
      );
      return;
    }

    if (_contextInfo == null) {
      await _ensureContext(projectId: project.id, force: true);
      if (_contextInfo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_contextError ?? l10n.analysisContextMissing)),
          );
        }
        return;
      }
    }

    final userMessage = ProjectQaMessage(
      role: 'user',
      text: question,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isAsking = true;
      _liveAnswer = '';
      _liveReasoningSteps = const [];
      _liveReasoningExpanded = true;
      _questionController.clear();
    });
    _scrollToBottom();

    final result = await _qaService.ask(
      settings: settings,
      projectRoot: project.path,
      question: question,
      responseLanguageCode: UserLanguageUtils.resolveResponseLanguageCode(
        question: question,
        appLanguageCode: l10n.locale.languageCode,
      ),
      contextRefresh: ProjectContextRefreshInput(
        project: project,
        gitStatus: state.gitRepositoryStatus,
        globalPackageMetadata: state.globalPackageMetadata,
      ),
      history: _messages.where((m) => m != userMessage).toList(),
      onStreamUpdate: (update) {
        if (!mounted) return;
        setState(() {
          _liveAnswer = update.partialAnswer;
          _liveReasoningSteps = update.reasoningSteps;
        });
        _scrollToBottom();
      },
    );

    if (!mounted) return;

    setState(() {
      _isAsking = false;
      _liveAnswer = '';
      _liveReasoningSteps = const [];
      if (result.isSuccess) {
        _messages.add(
          ProjectQaMessage(
            role: 'assistant',
            text: result.answer,
            timestamp: DateTime.now(),
            reasoningSteps: result.reasoningSteps,
          ),
        );
      } else {
        _messages.add(
          ProjectQaMessage(
            role: 'assistant',
            text: result.error ?? l10n.unknownError,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProjectManagerState>();
    final appSettings = context.watch<AppSettingsState>();
    final project = state.selectedProject;

    if (project == null) return const SizedBox.shrink();

    final cursorEnabled = appSettings.cursorCliSettings.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContextHeader(
          isBuilding: _isBuildingContext,
          contextInfo: _contextInfo,
          contextError: _contextError,
          cursorEnabled: cursorEnabled,
          onRegenerate: () => _ensureContext(projectId: project.id, force: true),
        ),
        Expanded(
          child: _messages.isEmpty
              ? _WelcomePanel(l10n: l10n, projectName: project.name)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isAsking ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isAsking && index == _messages.length) {
                      return _LiveAgentBubble(
                        answer: _liveAnswer,
                        reasoningSteps: _liveReasoningSteps,
                        reasoningExpanded: _liveReasoningExpanded,
                        onReasoningToggle: () => setState(
                          () => _liveReasoningExpanded = !_liveReasoningExpanded,
                        ),
                      );
                    }
                    final message = _messages[index];
                    return _ChatBubble(message: message);
                  },
                ),
        ),
        _CursorCliLogPanel(
          expanded: _showCursorLog,
          onToggle: () => setState(() => _showCursorLog = !_showCursorLog),
        ),
        _QuestionInput(
          controller: _questionController,
          enabled: cursorEnabled && !_isAsking && !_isBuildingContext,
          isAsking: _isAsking,
          onSubmit: _askQuestion,
        ),
      ],
    );
  }
}

class _ContextHeader extends StatelessWidget {
  const _ContextHeader({
    required this.isBuilding,
    required this.contextInfo,
    required this.contextError,
    required this.cursorEnabled,
    required this.onRegenerate,
  });

  final bool isBuilding;
  final ProjectContextFileInfo? contextInfo;
  final String? contextError;
  final bool cursorEnabled;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final generatedLabel = contextInfo != null
        ? _formatDateTime(contextInfo!.generatedAt.toLocal())
        : '';

    return Material(
      color: IdeaColors.sidebar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            const Icon(Icons.description_outlined,
                size: 18, color: IdeaColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.analysisContextTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (isBuilding)
                    Text(
                      l10n.analysisContextBuilding,
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else if (contextError != null)
                    Text(
                      contextError!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: IdeaColors.error),
                    )
                  else if (contextInfo != null)
                    Text(
                      l10n.analysisContextReady(
                        generatedLabel,
                        _formatBytes(contextInfo!.sizeBytes),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Text(
                      l10n.analysisContextMissing,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (!cursorEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.analysisCursorDisabled,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: IdeaColors.warning),
                      ),
                    ),
                ],
              ),
            ),
            if (isBuilding)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: IdeaColors.accent,
                ),
              )
            else
              IconButton(
                tooltip: l10n.analysisRegenerateContext,
                onPressed: onRegenerate,
                icon: const Icon(Icons.refresh, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $h:$min';
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({
    required this.l10n,
    required this.projectName,
  });

  final AppLocalizations l10n;
  final String projectName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology_outlined,
                  size: 48, color: IdeaColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                l10n.codeAnalysis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.analysisWelcome(projectName),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _SuggestionChip(text: l10n.analysisSuggestionArchitecture),
                  _SuggestionChip(text: l10n.analysisSuggestionDependencies),
                  _SuggestionChip(text: l10n.analysisSuggestionWidgets),
                  _SuggestionChip(text: l10n.analysisSuggestionBuilds),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: IdeaColors.sidebar,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: IdeaColors.panelBorder),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ProjectQaMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? IdeaColors.accent.withValues(alpha: 0.15)
              : message.isError
                  ? IdeaColors.error.withValues(alpha: 0.08)
                  : IdeaColors.sidebar,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isUser
                ? IdeaColors.accent.withValues(alpha: 0.3)
                : message.isError
                    ? IdeaColors.error.withValues(alpha: 0.35)
                    : IdeaColors.panelBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isUser && message.reasoningSteps.isNotEmpty)
              _ReasoningPanel(steps: message.reasoningSteps),
            if (isUser)
              SelectableText(
                message.text,
                style: const TextStyle(fontSize: 13, height: 1.45),
              )
            else if (message.isError)
              SelectableText(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: IdeaColors.error,
                ),
              )
            else
              MarkdownContent(
                data: message.text,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveAgentBubble extends StatelessWidget {
  const _LiveAgentBubble({
    required this.answer,
    required this.reasoningSteps,
    required this.reasoningExpanded,
    required this.onReasoningToggle,
  });

  final String answer;
  final List<ProjectQaReasoningStep> reasoningSteps;
  final bool reasoningExpanded;
  final VoidCallback onReasoningToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: IdeaColors.sidebar,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IdeaColors.panelBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReasoningPanel(
              steps: reasoningSteps,
              expanded: reasoningExpanded,
              onToggle: onReasoningToggle,
              isLive: true,
            ),
            if (answer.trim().isEmpty)
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: IdeaColors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.analysisStreaming,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            else
              MarkdownContent(
                data: answer,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReasoningPanel extends StatefulWidget {
  const _ReasoningPanel({
    required this.steps,
    this.expanded,
    this.onToggle,
    this.isLive = false,
  });

  final List<ProjectQaReasoningStep> steps;
  final bool? expanded;
  final VoidCallback? onToggle;
  final bool isLive;

  @override
  State<_ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<_ReasoningPanel> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded ?? true;
  }

  @override
  void didUpdateWidget(covariant _ReasoningPanel oldWidget) {
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
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
                        l10n.analysisReasoningTitle,
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
                                      step.isComplete
                                          ? Icons.check_circle_outline
                                          : Icons.radio_button_unchecked,
                                      size: 12,
                                      color: step.isComplete
                                          ? IdeaColors.accent
                                          : IdeaColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _ReasoningStepMarkdown(
                                      text: step.text,
                                      isPending: !step.isComplete,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReasoningStepMarkdown extends StatelessWidget {
  const _ReasoningStepMarkdown({
    required this.text,
    required this.isPending,
  });

  final String text;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final data =
        isPending && !text.contains('*') ? '_${text}_' : text;
    return MarkdownContent(
      data: data,
      padding: EdgeInsets.zero,
      compact: true,
    );
  }
}

class _QuestionInput extends StatelessWidget {
  const _QuestionInput({
    required this.controller,
    required this.enabled,
    required this.isAsking,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isAsking;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: IdeaColors.toolbar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: l10n.analysisAskPlaceholder,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: IdeaColors.panelBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: IdeaColors.panelBorder),
                  ),
                ),
                onSubmitted: enabled ? (_) => onSubmit() : null,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: enabled ? onSubmit : null,
              icon: isAsking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 16),
              label: Text(l10n.analysisAskButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _CursorCliLogPanel extends StatelessWidget {
  const _CursorCliLogPanel({
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: CursorCliLogger.instance,
      builder: (context, _) {
        final entries = CursorCliLogger.instance.recentEntries
            .where((e) => e.source == 'analysis' || e.source == 'cursor-cli')
            .take(20)
            .toList();

        return Material(
          color: IdeaColors.toolbar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onToggle,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal,
                          size: 14, color: IdeaColors.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.widgetsCursorCliLog,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        expanded ? Icons.expand_more : Icons.expand_less,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded)
                Container(
                  height: 120,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: IdeaColors.sidebar,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: IdeaColors.panelBorder),
                  ),
                  child: entries.isEmpty
                      ? Center(
                          child: Text(
                            l10n.widgetsCursorCliLogEmpty,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      : ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                entry.format(),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  height: 1.3,
                                ),
                              ),
                            );
                          },
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}
