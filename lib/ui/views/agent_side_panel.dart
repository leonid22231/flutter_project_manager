import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/agent_profile.dart';
import 'package:project_manager/models/context_sync_status.dart';
import 'package:project_manager/models/project_knowledge.dart';
import 'package:project_manager/models/project_semantic_index.dart';
import 'package:project_manager/services/agent_index_meta_service.dart';
import 'package:project_manager/services/agent_learning_pending_service.dart';
import 'package:project_manager/services/agent_profile_service.dart';
import 'package:project_manager/services/project_context_service.dart';
import 'package:project_manager/ui/widgets/agent_progress_panel.dart';
import 'package:project_manager/ui/widgets/markdown_content.dart';
import 'package:project_manager/ui/widgets/resizable_block.dart';
import 'package:project_manager/models/agent_progress_step.dart';
import 'package:project_manager/services/agent_context_orchestrator.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:provider/provider.dart';

enum _SideTab { profile, memory, pending, indexing, ai, advanced }

class AgentSidePanel extends StatefulWidget {
  const AgentSidePanel({
    super.key,
    required this.projectPath,
    required this.profile,
    required this.memory,
    required this.knowledge,
    required this.aiEntries,
    required this.pending,
    required this.indexMeta,
    required this.contextInfo,
    required this.promptPreview,
    required this.isIndexing,
    required this.semantic,
    required this.indexAgentSteps,
    required this.indexPartialOutput,
    required this.syncStatus,
    required this.syncEnabled,
    required this.onReload,
    required this.onIndex,
    required this.onSnapshotOnly,
    required this.onCancelIndex,
    required this.onContinueIndex,
    required this.onSubmitIndexAnswer,
    required this.onSync,
    required this.onConfirmLearning,
    required this.onDiscardLearning,
    required this.onOpenFile,
  });

  final String projectPath;
  final AgentProfile? profile;
  final AgentMemoryStore memory;
  final ProjectKnowledgeStore knowledge;
  final List<AiFolderEntry> aiEntries;
  final LearningPendingStore pending;
  final AgentIndexMeta indexMeta;
  final ProjectContextFileInfo? contextInfo;
  final String? promptPreview;
  final bool isIndexing;
  final SemanticIndexSnapshot semantic;
  final List<AgentProgressStep> indexAgentSteps;
  final String indexPartialOutput;
  final ContextSyncStatus syncStatus;
  final bool syncEnabled;
  final Future<void> Function() onReload;
  final Future<void> Function() onIndex;
  final Future<void> Function() onSnapshotOnly;
  final VoidCallback onCancelIndex;
  final Future<void> Function() onContinueIndex;
  final Future<void> Function({
    required String questionId,
    required String text,
    required IndexQuestionStatus status,
  }) onSubmitIndexAnswer;
  final VoidCallback onSync;
  final Future<void> Function(LearningPendingStore store) onConfirmLearning;
  final Future<void> Function() onDiscardLearning;
  final ValueChanged<String> onOpenFile;

  @override
  State<AgentSidePanel> createState() => _AgentSidePanelState();
}

class _AgentSidePanelState extends State<AgentSidePanel> {
  _SideTab _tab = _SideTab.profile;
  final _profileService = AgentProfileService();
  final _orchestrator = AgentContextOrchestrator();

  late final TextEditingController _name;
  late final TextEditingController _about;
  late final TextEditingController _skills;
  late final TextEditingController _instructions;
  late final TextEditingController _selfAnalysis;
  late final TextEditingController _architecture;
  late final TextEditingController _workflows;
  late final TextEditingController _memoryInput;

  LearningPendingStore _editablePending = const LearningPendingStore();
  bool _saving = false;
  bool _analyzing = false;
  List<AgentProgressStep> _analysisSteps = const [];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile?.name ?? '');
    _about = TextEditingController(text: widget.profile?.aboutSelf ?? '');
    _skills = TextEditingController(text: widget.profile?.skills ?? '');
    _instructions =
        TextEditingController(text: widget.profile?.customInstructions ?? '');
    _selfAnalysis =
        TextEditingController(text: widget.profile?.selfAnalysis ?? '');
    _architecture =
        TextEditingController(text: widget.knowledge.architectureSummary);
    _workflows = TextEditingController(text: widget.knowledge.workflowsSummary);
    _memoryInput = TextEditingController();
    _editablePending = widget.pending;
  }

  @override
  void didUpdateWidget(covariant AgentSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.name != widget.profile?.name) {
      _name.text = widget.profile?.name ?? '';
      _about.text = widget.profile?.aboutSelf ?? '';
      _skills.text = widget.profile?.skills ?? '';
      _instructions.text = widget.profile?.customInstructions ?? '';
      _selfAnalysis.text = widget.profile?.selfAnalysis ?? '';
    }
    if (oldWidget.knowledge != widget.knowledge) {
      _architecture.text = widget.knowledge.architectureSummary;
      _workflows.text = widget.knowledge.workflowsSummary;
    }
    if (oldWidget.pending != widget.pending) {
      _editablePending = widget.pending;
      if (widget.pending.isNotEmpty) _tab = _SideTab.pending;
    }
  }

  @override
  void dispose() {
    _orchestrator.cancelSelfAnalysis();
    _name.dispose();
    _about.dispose();
    _skills.dispose();
    _instructions.dispose();
    _selfAnalysis.dispose();
    _architecture.dispose();
    _workflows.dispose();
    _memoryInput.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final profile = AgentProfile(
      name: _name.text.trim(),
      aboutSelf: _about.text.trim(),
      character: widget.profile?.character ?? '',
      skills: _skills.text.trim(),
      capabilities: widget.profile?.capabilities ?? '',
      limitations: widget.profile?.limitations ?? '',
      selfAnalysis: _selfAnalysis.text.trim(),
      customInstructions: _instructions.text.trim(),
      lastSelfAnalysisAt: widget.profile?.lastSelfAnalysisAt,
    );
    await _profileService.saveProfile(widget.projectPath, profile);
    await _profileService.saveKnowledge(
      widget.projectPath,
      widget.knowledge.copyWith(
        architectureSummary: _architecture.text.trim(),
        workflowsSummary: _workflows.text.trim(),
      ),
    );
    setState(() => _saving = false);
    await widget.onReload();
  }

  Future<void> _addMemory() async {
    final text = _memoryInput.text.trim();
    if (text.isEmpty) return;
    await _profileService.addMemoryEntry(widget.projectPath, content: text);
    _memoryInput.clear();
    await widget.onReload();
  }

  Future<void> _runSelfAnalysis() async {
    final state = context.read<ProjectManagerState>();
    final settings = context.read<AppSettingsState>().cursorCliSettings;
    final project = state.selectedProject;
    if (project == null || !settings.enabled) return;

    setState(() {
      _analyzing = true;
      _analysisSteps = const [];
      _tab = _SideTab.profile;
    });

    final result = await _orchestrator.runSelfAnalysis(
      settings: settings,
      contextInput: ProjectContextRefreshInput(
        project: project,
        gitStatus: state.gitRepositoryStatus,
        globalPackageMetadata: state.globalPackageMetadata,
      ),
      appLanguageCode: context.l10n.locale.languageCode,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() => _analysisSteps = progress.steps);
      },
    );

    if (!mounted) return;
    setState(() {
      _analyzing = false;
      if (result.profile != null) {
        _selfAnalysis.text = result.profile!.selfAnalysis;
      }
    });
    await widget.onReload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: IdeaColors.sidebar,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                for (final entry in [
                  (_SideTab.profile, l10n.agentSideProfile),
                  (_SideTab.memory, l10n.agentSideMemory),
                  (_SideTab.pending, l10n.agentSidePending),
                  (_SideTab.indexing, l10n.agentSideIndex),
                  (_SideTab.ai, l10n.agentSideAi),
                  (_SideTab.advanced, l10n.agentSideAdvanced),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: _SideTabButton(
                      label: entry.$2,
                      selected: _tab == entry.$1,
                      onTap: () => setState(() => _tab = entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: IdeaColors.panelBorder),
          Expanded(
            child: switch (_tab) {
              _SideTab.profile => _buildProfile(l10n),
              _SideTab.memory => _buildMemory(l10n),
              _SideTab.pending => _buildPending(l10n),
              _SideTab.indexing => _buildIndex(l10n),
              _SideTab.ai => _buildAi(l10n),
              _SideTab.advanced => _buildAdvanced(l10n),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l10n.agentSideProfile, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: l10n.agentNameLabel, isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _about,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.agentAboutLabel,
            isDense: true,
            helperText: 'Markdown',
          ),
        ),
        if (_about.text.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          _MarkdownPreview(data: _about.text),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _skills,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.agentSkillsLabel,
            isDense: true,
            helperText: 'Markdown',
          ),
        ),
        if (_skills.text.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          _MarkdownPreview(data: _skills.text),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _instructions,
          minLines: 2,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.agentInstructionsLabel,
            isDense: true,
            helperText: 'Markdown',
          ),
        ),
        if (_instructions.text.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          _MarkdownPreview(data: _instructions.text),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _selfAnalysis,
          minLines: 3,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.agentSelfAnalysisLabel,
            isDense: true,
            helperText: 'Markdown',
          ),
        ),
        if (_selfAnalysis.text.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          _MarkdownPreview(data: _selfAnalysis.text),
        ],
        const SizedBox(height: 10),
        AdaptiveActionBar(
          children: [
            FilledButton(
              onPressed: _saving ? null : _saveProfile,
              style: denseFilledStyle(backgroundColor: IdeaColors.accent),
              child: Text(_saving ? '…' : l10n.save),
            ),
            OutlinedButton(
              onPressed: _analyzing ? null : _runSelfAnalysis,
              style: denseOutlinedStyle(),
              child: Text(l10n.agentImproveProfile),
            ),
          ],
        ),
        if (_analyzing || _analysisSteps.isNotEmpty) ...[
          const SizedBox(height: 12),
          AgentProgressPanel(
            title: l10n.agentSelfAnalysisProgressTitle,
            steps: _analysisSteps,
            isLive: _analyzing,
          ),
        ],
      ],
    );
  }

  Widget _buildMemory(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l10n.agentSideMemory, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _memoryInput,
                decoration:
                    InputDecoration(hintText: l10n.agentAddMemory, isDense: true),
                onSubmitted: (_) => _addMemory(),
              ),
            ),
            IconButton(onPressed: _addMemory, icon: const Icon(Icons.add, size: 18)),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.memory.entries.isEmpty)
          Text(l10n.agentMemoryEmpty, style: Theme.of(context).textTheme.bodySmall)
        else
          ...widget.memory.entries.map(
            (e) {
              final editable = AgentProfileService.isEditableMemoryId(e.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MarkdownContent(
                            data: e.content,
                            padding: EdgeInsets.zero,
                            compact: true,
                          ),
                          if (e.tags.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                e.tags.join(' · '),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    editable
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16),
                            onPressed: () async {
                              await _profileService.deleteMemoryEntry(
                                widget.projectPath,
                                e.id,
                              );
                              await widget.onReload();
                            },
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                  ],
                ),
              );
            },
          ),
        const Divider(),
        Text(l10n.agentKnowledgeInsightsLabel,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _architecture,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.agentArchitectureSummaryLabel,
            isDense: true,
            helperText: 'Markdown',
          ),
        ),
        if (_architecture.text.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          _MarkdownPreview(data: _architecture.text),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _workflows,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.agentWorkflowsSummaryLabel,
            isDense: true,
            helperText: 'Markdown',
          ),
        ),
        if (_workflows.text.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          _MarkdownPreview(data: _workflows.text),
        ],
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saveProfile,
          style: FilledButton.styleFrom(backgroundColor: IdeaColors.accent),
          child: Text(l10n.save),
        ),
        if (widget.knowledge.insights.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...widget.knowledge.insights.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    i.topic,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MarkdownContent(
                    data: i.content,
                    padding: EdgeInsets.zero,
                    compact: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPending(AppLocalizations l10n) {
    if (_editablePending.isEmpty) {
      return Center(
        child: Text(l10n.agentPendingEmpty,
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _editablePending.candidates.length,
            itemBuilder: (context, index) {
              final c = _editablePending.candidates[index];
              return CheckboxListTile(
                dense: true,
                value: c.selected,
                title: Text(
                  '${c.kind}${c.topic != null ? ': ${c.topic}' : ''}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: MarkdownContent(
                    data: c.content,
                    padding: EdgeInsets.zero,
                    compact: true,
                  ),
                ),
                onChanged: (v) {
                  setState(() {
                    final list = [..._editablePending.candidates];
                    list[index] = c.copyWith(selected: v ?? false);
                    _editablePending = _editablePending.copyWith(candidates: list);
                  });
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: AdaptiveActionBar(
            children: [
              FilledButton(
                onPressed: () => widget.onConfirmLearning(_editablePending),
                style: denseFilledStyle(backgroundColor: IdeaColors.accent),
                child: Text(l10n.agentConfirmLearning),
              ),
              TextButton(
                onPressed: widget.onDiscardLearning,
                style: denseTextStyle(),
                child: Text(l10n.agentDiscardLearning),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndex(AppLocalizations l10n) {
    final meta = widget.indexMeta;
    final session = widget.semantic.session;
    final openQs = widget.semantic.questions.open;
    final notesCount = widget.semantic.notes.notes.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      children: [
        Text(l10n.agentSideIndex, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          l10n.agentIndexPreferQuestionsHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 8),
        Text(
          meta.lastIndexedAt == null
              ? l10n.agentIndexMissing
              : l10n.agentIndexReady(
                  meta.lastIndexedAt!.toLocal().toIso8601String(),
                ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          '${l10n.agentIndexNotesCount}: $notesCount · '
          '${l10n.agentIndexOpenQuestions}: ${openQs.length}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (session.phase != IndexSessionPhase.idle) ...[
          const SizedBox(height: 8),
          Text(
            l10n.agentIndexProgress,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: session.totalFiles > 0 ? session.progress : null,
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${session.phase.name}'
            '${session.totalBatches > 0 ? ' · ${l10n.agentIndexBatchProgress(session.currentBatch, session.totalBatches, session.currentFolder)}' : ''}',
            style: const TextStyle(fontSize: 10),
          ),
          if (session.error != null)
            Text(
              session.error!,
              style: const TextStyle(color: IdeaColors.error, fontSize: 10),
            ),
        ],
        if (widget.isIndexing || widget.indexAgentSteps.isNotEmpty) ...[
          const SizedBox(height: 10),
          AgentProgressPanel(
            title: l10n.agentIndexLiveThoughts,
            steps: widget.indexAgentSteps,
            isLive: widget.isIndexing,
            partialOutput: widget.indexPartialOutput,
            expanded: true,
          ),
          if (widget.isIndexing && widget.indexAgentSteps.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.agentIndexLiveEmpty,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 30,
          child: FilledButton.icon(
            onPressed: widget.isIndexing ? null : widget.onIndex,
            icon: widget.isIndexing
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.travel_explore, size: 14),
            label: Text(
              l10n.agentIndexSemantic,
              style: const TextStyle(fontSize: 11),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: IdeaColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 28,
          child: OutlinedButton(
            onPressed: widget.isIndexing ? null : widget.onSnapshotOnly,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              l10n.agentIndexSnapshotOnly,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        if (widget.isIndexing) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onCancelIndex,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(l10n.agentIndexCancel, style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          l10n.agentIndexOpenQuestions,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        if (openQs.isEmpty)
          Text(
            l10n.agentIndexNoQuestions,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          ...openQs.map(
            (q) => _IndexQuestionCard(
              question: q,
              enabled: !widget.isIndexing,
              answerHint: l10n.agentIndexAnswerHint,
              whyLabel: l10n.agentIndexWhyNeeded,
              answerLabel: l10n.agentIndexAnswer,
              skipLabel: l10n.agentIndexSkip,
              unknownLabel: l10n.agentIndexUnknown,
              onSubmit: (text, status) => widget.onSubmitIndexAnswer(
                questionId: q.id,
                text: text,
                status: status,
              ),
            ),
          ),
        if (openQs.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: FilledButton(
              onPressed: widget.isIndexing ? null : widget.onContinueIndex,
              style: FilledButton.styleFrom(
                backgroundColor: IdeaColors.accent,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                l10n.agentIndexContinue,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        const Divider(height: 1, color: IdeaColors.panelBorder),
        const SizedBox(height: 10),
        Text(
          l10n.contextSyncSection,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          !widget.syncEnabled
              ? l10n.contextSyncDisabled
              : widget.syncStatus.hasError
                  ? (widget.syncStatus.error ?? l10n.contextSyncFailed)
                  : widget.syncStatus.isSyncing
                      ? l10n.contextSyncInProgress
                      : (widget.syncStatus.message ?? l10n.contextSyncIdle),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 28,
          child: OutlinedButton.icon(
            onPressed: widget.syncEnabled ? widget.onSync : null,
            icon: const Icon(Icons.sync, size: 14),
            label: Text(
              l10n.contextSyncNow,
              style: const TextStyle(fontSize: 11),
            ),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAi(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Text(l10n.agentSideAi, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              onPressed: widget.onReload,
              icon: const Icon(Icons.refresh, size: 16),
            ),
          ],
        ),
        if (widget.aiEntries.isEmpty)
          Text(l10n.agentAiFolderEmpty, style: Theme.of(context).textTheme.bodySmall)
        else
          ...widget.aiEntries.map(
            (e) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                e.isDirectory ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                size: 16,
              ),
              title: Text(e.relativePath, style: const TextStyle(fontSize: 12)),
              subtitle: e.description == null
                  ? null
                  : Text(e.description!, style: const TextStyle(fontSize: 10)),
              onTap: e.isDirectory
                  ? null
                  : () => widget.onOpenFile(
                        p.join(widget.projectPath, e.relativePath),
                      ),
            ),
          ),
      ],
    );
  }

  Widget _buildAdvanced(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l10n.agentSideAdvanced,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(l10n.agentPromptPreviewHint,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: IdeaColors.panelBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: MarkdownContent(
            data: widget.promptPreview ?? l10n.notAvailable,
            padding: EdgeInsets.zero,
            compact: true,
          ),
        ),
      ],
    );
  }
}

class _SideTabButton extends StatelessWidget {
  const _SideTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? IdeaColors.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border(
            bottom: BorderSide(
              color: selected ? IdeaColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            height: 1.1,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? IdeaColors.textBright : IdeaColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: IdeaColors.background,
        border: Border.all(color: IdeaColors.panelBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: MarkdownContent(
          data: data,
          padding: EdgeInsets.zero,
          compact: true,
        ),
      ),
    );
  }
}

class _IndexQuestionCard extends StatefulWidget {
  const _IndexQuestionCard({
    required this.question,
    required this.enabled,
    required this.answerHint,
    required this.whyLabel,
    required this.answerLabel,
    required this.skipLabel,
    required this.unknownLabel,
    required this.onSubmit,
  });

  final IndexQuestion question;
  final bool enabled;
  final String answerHint;
  final String whyLabel;
  final String answerLabel;
  final String skipLabel;
  final String unknownLabel;
  final Future<void> Function(String text, IndexQuestionStatus status) onSubmit;

  @override
  State<_IndexQuestionCard> createState() => _IndexQuestionCardState();
}

class _IndexQuestionCardState extends State<_IndexQuestionCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: IdeaColors.panelBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (q.path != null && q.path!.isNotEmpty)
            Text(q.path!, style: const TextStyle(fontSize: 10, color: IdeaColors.accent)),
          MarkdownContent(
            data: q.question,
            padding: EdgeInsets.zero,
            compact: true,
          ),
          if (q.whyNeeded.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${widget.whyLabel}: ${q.whyNeeded}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (q.options.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                for (final opt in q.options)
                  ActionChip(
                    label: Text(opt, style: const TextStyle(fontSize: 10)),
                    onPressed: widget.enabled
                        ? () => _controller.text = opt
                        : null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            enabled: widget.enabled,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: widget.answerHint,
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilledButton(
                onPressed: !widget.enabled
                    ? null
                    : () => widget.onSubmit(
                          _controller.text,
                          IndexQuestionStatus.answered,
                        ),
                style: denseFilledStyle(backgroundColor: IdeaColors.accent),
                child: Text(widget.answerLabel),
              ),
              OutlinedButton(
                onPressed: !widget.enabled
                    ? null
                    : () => widget.onSubmit('', IndexQuestionStatus.skipped),
                style: denseOutlinedStyle(),
                child: Text(widget.skipLabel),
              ),
              TextButton(
                onPressed: !widget.enabled
                    ? null
                    : () => widget.onSubmit(
                          'unknown',
                          IndexQuestionStatus.unknown,
                        ),
                style: denseTextStyle(),
                child: Text(widget.unknownLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
