import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/project_context_paths.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/agent_progress_step.dart';
import 'package:project_manager/models/agent_profile.dart';
import 'package:project_manager/models/project_knowledge.dart';
import 'package:project_manager/services/agent_context_orchestrator.dart';
import 'package:project_manager/services/agent_profile_service.dart';
import 'package:project_manager/services/analysis/project_qa_agent_prompt.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/widgets/agent_progress_panel.dart';
import 'package:project_manager/ui/widgets/markdown_content.dart';
import 'package:provider/provider.dart';

enum _AgentSection {
  identity,
  skills,
  selfAnalysis,
  instructions,
  memory,
  knowledge,
  aiFolder,
  prompt,
}

class AgentView extends StatefulWidget {
  const AgentView({super.key});

  @override
  State<AgentView> createState() => _AgentViewState();
}

class _AgentViewState extends State<AgentView> {
  final _service = AgentProfileService();
  final _orchestrator = AgentContextOrchestrator();
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _characterController = TextEditingController();
  final _skillsController = TextEditingController();
  final _capabilitiesController = TextEditingController();
  final _limitationsController = TextEditingController();
  final _selfAnalysisController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _memoryController = TextEditingController();
  final _architectureController = TextEditingController();
  final _workflowsController = TextEditingController();

  _AgentSection _section = _AgentSection.identity;
  AgentProfile? _profile;
  AgentMemoryStore _memory = const AgentMemoryStore();
  ProjectKnowledgeStore _knowledge = const ProjectKnowledgeStore();
  List<AiFolderEntry> _aiEntries = const [];
  String? _lastProjectId;
  bool _loading = true;
  bool _saving = false;
  bool _analyzingSelf = false;
  List<AgentProgressStep> _selfAnalysisSteps = const [];
  String _selfAnalysisRawOutput = '';
  var _selfAnalysisLogExpanded = true;
  DateTime? _selfAnalysisStartedAt;
  Timer? _selfAnalysisElapsedTimer;
  String? _promptPreview;

  @override
  void dispose() {
    _selfAnalysisElapsedTimer?.cancel();
    _orchestrator.cancelSelfAnalysis();
    _nameController.dispose();
    _aboutController.dispose();
    _characterController.dispose();
    _skillsController.dispose();
    _capabilitiesController.dispose();
    _limitationsController.dispose();
    _selfAnalysisController.dispose();
    _instructionsController.dispose();
    _memoryController.dispose();
    _architectureController.dispose();
    _workflowsController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final project = context.read<ProjectManagerState>().selectedProject;
    if (project == null) return;
    if (_lastProjectId == project.id) return;
    _lastProjectId = project.id;
    _load(project.path);
  }

  Future<void> _load(String projectRoot) async {
    setState(() => _loading = true);
    final l10n = context.l10n;
    final profile = await _service.loadOrCreateProfile(
      projectRoot,
      languageCode: l10n.locale.languageCode,
    );
    final memory = await _service.loadMemory(projectRoot);
    final knowledge = await _service.loadKnowledge(projectRoot);
    final aiEntries = await _service.scanAiFolder(projectRoot);

    if (!mounted) return;
    _applyProfileToControllers(profile);
    _architectureController.text = knowledge.architectureSummary;
    _workflowsController.text = knowledge.workflowsSummary;
    setState(() {
      _profile = profile;
      _memory = memory;
      _knowledge = knowledge;
      _aiEntries = aiEntries;
      _loading = false;
      _promptPreview =
          _buildPromptPreview(projectRoot, profile, memory, knowledge, aiEntries);
    });
  }

  void _applyProfileToControllers(AgentProfile profile) {
    _nameController.text = profile.name;
    _aboutController.text = profile.aboutSelf;
    _characterController.text = profile.character;
    _skillsController.text = profile.skills;
    _capabilitiesController.text = profile.capabilities;
    _limitationsController.text = profile.limitations;
    _selfAnalysisController.text = profile.selfAnalysis;
    _instructionsController.text = profile.customInstructions;
  }

  String _buildPromptPreview(
    String projectRoot,
    AgentProfile profile,
    AgentMemoryStore memory,
    ProjectKnowledgeStore knowledge,
    List<AiFolderEntry> aiEntries,
  ) {
    return ProjectQaAgentPrompt.buildPreview(
      contextPath: ProjectContextPaths.contextFilePath(projectRoot),
      responseLanguageCode: context.l10n.locale.languageCode,
      profile: profile,
      memory: memory,
      knowledge: knowledge,
      aiFolderEntries: aiEntries,
    );
  }

  ProjectContextRefreshInput? _contextInput() {
    final state = context.read<ProjectManagerState>();
    final project = state.selectedProject;
    if (project == null) return null;
    return ProjectContextRefreshInput(
      project: project,
      gitStatus: state.gitRepositoryStatus,
      globalPackageMetadata: state.globalPackageMetadata,
    );
  }

  Future<void> _refreshPromptPreview(String projectRoot) async {
    final profile = _profile;
    if (profile == null) return;
    final memory = await _service.loadMemory(projectRoot);
    final knowledge = await _service.loadKnowledge(projectRoot);
    final aiEntries = await _service.scanAiFolder(projectRoot);
    if (!mounted) return;
    setState(() {
      _memory = memory;
      _knowledge = knowledge;
      _aiEntries = aiEntries;
      _promptPreview =
          _buildPromptPreview(projectRoot, profile, memory, knowledge, aiEntries);
    });
  }

  Future<void> _saveProfile() async {
    final project = context.read<ProjectManagerState>().selectedProject;
    if (project == null || _saving) return;

    setState(() => _saving = true);
    final profile = AgentProfile(
      name: _nameController.text.trim(),
      aboutSelf: _aboutController.text.trim(),
      character: _characterController.text.trim(),
      skills: _skillsController.text.trim(),
      capabilities: _capabilitiesController.text.trim(),
      limitations: _limitationsController.text.trim(),
      selfAnalysis: _selfAnalysisController.text.trim(),
      customInstructions: _instructionsController.text.trim(),
      lastSelfAnalysisAt: _profile?.lastSelfAnalysisAt,
    );
    await _service.saveProfile(project.path, profile);
    final input = _contextInput();
    if (input != null) {
      await _orchestrator.refreshFullContext(
        input,
        languageCode: context.l10n.locale.languageCode,
      );
    }
    await _refreshPromptPreview(project.path);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.agentSaved)),
    );
  }

  Future<void> _saveKnowledge() async {
    final project = context.read<ProjectManagerState>().selectedProject;
    if (project == null || _saving) return;
    setState(() => _saving = true);
    await _service.saveKnowledge(
      project.path,
      _knowledge.copyWith(
        architectureSummary: _architectureController.text.trim(),
        workflowsSummary: _workflowsController.text.trim(),
      ),
    );
    final input = _contextInput();
    if (input != null) {
      await _orchestrator.refreshFullContext(
        input,
        languageCode: context.l10n.locale.languageCode,
      );
    }
    await _refreshPromptPreview(project.path);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.agentSaved)),
    );
  }

  void _startSelfAnalysisElapsedTimer() {
    _selfAnalysisElapsedTimer?.cancel();
    _selfAnalysisStartedAt = DateTime.now();
    _selfAnalysisElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_analyzingSelf) return;
      setState(() {});
    });
  }

  void _stopSelfAnalysisElapsedTimer() {
    _selfAnalysisElapsedTimer?.cancel();
    _selfAnalysisElapsedTimer = null;
  }

  String? _selfAnalysisElapsedLabel(AppLocalizations l10n) {
    final started = _selfAnalysisStartedAt;
    if (started == null || !_analyzingSelf) return null;
    final elapsed = DateTime.now().difference(started);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return l10n.agentSelfAnalysisElapsed(minutes, seconds);
  }

  Future<void> _runSelfAnalysis() async {
    final project = context.read<ProjectManagerState>().selectedProject;
    final input = _contextInput();
    final settings = context.read<AppSettingsState>().cursorCliSettings;
    if (project == null || input == null || _analyzingSelf) return;

    setState(() {
      _analyzingSelf = true;
      _selfAnalysisSteps = const [];
      _selfAnalysisRawOutput = '';
      _selfAnalysisLogExpanded = true;
      _section = _AgentSection.selfAnalysis;
    });
    _startSelfAnalysisElapsedTimer();

    final result = await _orchestrator.runSelfAnalysis(
      settings: settings,
      contextInput: input,
      appLanguageCode: context.l10n.locale.languageCode,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() {
          _selfAnalysisSteps = progress.steps;
          _selfAnalysisRawOutput = progress.partialOutput;
          _analyzingSelf = progress.isRunning;
        });
      },
    );

    if (!mounted) return;
    _stopSelfAnalysisElapsedTimer();

    setState(() {
      _selfAnalysisSteps = result.steps;
      _selfAnalysisRawOutput = result.rawOutput;
      _analyzingSelf = false;
    });

    if (result.isSuccess && result.profile != null) {
      _applyProfileToControllers(result.profile!);
      setState(() => _profile = result.profile);
      await _refreshPromptPreview(project.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.agentSelfAnalysisSucceeded)),
      );
    } else {
      final message = result.cancelled
          ? context.l10n.agentSelfAnalysisCancelled
          : result.timedOut
              ? context.l10n.agentSelfAnalysisTimedOut
              : result.idleTimedOut
                  ? context.l10n.agentSelfAnalysisIdleTimedOut
                  : result.error ?? context.l10n.agentSelfAnalysisFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  void _cancelSelfAnalysis() {
    if (!_analyzingSelf) return;
    _orchestrator.cancelSelfAnalysis();
  }

  Future<void> _addMemory() async {
    final project = context.read<ProjectManagerState>().selectedProject;
    final content = _memoryController.text.trim();
    if (project == null || content.isEmpty) return;

    await _service.addMemoryEntry(project.path, content: content);
    _memoryController.clear();
    final input = _contextInput();
    if (input != null) {
      await _orchestrator.refreshFullContext(
        input,
        languageCode: context.l10n.locale.languageCode,
      );
    }
    await _refreshPromptPreview(project.path);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.agentMemoryAdded)),
    );
  }

  Future<void> _deleteMemory(String id) async {
    final project = context.read<ProjectManagerState>().selectedProject;
    if (project == null) return;

    await _service.deleteMemoryEntry(project.path, id);
    final input = _contextInput();
    if (input != null) {
      await _orchestrator.refreshFullContext(
        input,
        languageCode: context.l10n.locale.languageCode,
      );
    }
    await _refreshPromptPreview(project.path);
  }

  Future<void> _refreshAiFolder() async {
    final project = context.read<ProjectManagerState>().selectedProject;
    if (project == null) return;
    final entries = await _service.scanAiFolder(project.path);
    if (!mounted) return;
    setState(() => _aiEntries = entries);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final project = context.watch<ProjectManagerState>().selectedProject;
    if (project == null) return const SizedBox.shrink();

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: IdeaColors.accent),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 220,
          child: ColoredBox(
            color: IdeaColors.sidebar,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.smart_toy_outlined,
                          size: 16, color: IdeaColors.accent),
                      const SizedBox(width: 6),
                      Text(
                        l10n.tabAgent,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    l10n.agentContextAutoRefreshHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                for (final section in _AgentSection.values)
                  _SectionTile(
                    title: _sectionTitle(l10n, section),
                    icon: _sectionIcon(section),
                    selected: _section == section,
                    onTap: () => setState(() => _section = section),
                  ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                title: _sectionTitle(l10n, _section),
                actions: switch (_section) {
                  _AgentSection.aiFolder => [
                      IconButton(
                        tooltip: l10n.agentRefreshAiFolder,
                        onPressed: _refreshAiFolder,
                        icon: const Icon(Icons.refresh, size: 18),
                      ),
                    ],
                  _AgentSection.selfAnalysis => [
                      FilledButton.icon(
                        onPressed: _analyzingSelf ? null : _runSelfAnalysis,
                        icon: _analyzingSelf
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.psychology, size: 16),
                        label: Text(l10n.agentRunSelfAnalysis),
                      ),
                      if (_analyzingSelf) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _cancelSelfAnalysis,
                          icon: const Icon(Icons.stop_circle_outlined, size: 16),
                          label: Text(l10n.agentCancelSelfAnalysis),
                        ),
                      ],
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _saveProfile,
                        icon: const Icon(Icons.save, size: 16),
                        label: Text(l10n.save),
                      ),
                    ],
                  _AgentSection.knowledge => [
                      FilledButton.icon(
                        onPressed: _saving ? null : _saveKnowledge,
                        icon: const Icon(Icons.save, size: 16),
                        label: Text(l10n.save),
                      ),
                    ],
                  _AgentSection.identity ||
                  _AgentSection.skills ||
                  _AgentSection.instructions =>
                    [
                      FilledButton.icon(
                        onPressed: _saving ? null : _saveProfile,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save, size: 16),
                        label: Text(l10n.save),
                      ),
                    ],
                  _ => null,
                },
              ),
              Expanded(child: _buildSectionContent(l10n)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent(AppLocalizations l10n) {
    return switch (_section) {
      _AgentSection.identity => _IdentitySection(
          nameController: _nameController,
          aboutController: _aboutController,
          characterController: _characterController,
          l10n: l10n,
        ),
      _AgentSection.skills => _SkillsSection(
          skillsController: _skillsController,
          capabilitiesController: _capabilitiesController,
          limitationsController: _limitationsController,
          l10n: l10n,
        ),
      _AgentSection.selfAnalysis => _SelfAnalysisSection(
          controller: _selfAnalysisController,
          l10n: l10n,
          isRunning: _analyzingSelf,
          steps: _selfAnalysisSteps,
          rawOutput: _selfAnalysisRawOutput,
          logExpanded: _selfAnalysisLogExpanded,
          elapsedLabel: _selfAnalysisElapsedLabel(l10n),
          onLogToggle: () => setState(
            () => _selfAnalysisLogExpanded = !_selfAnalysisLogExpanded,
          ),
        ),
      _AgentSection.instructions => _InstructionsSection(
          controller: _instructionsController,
          l10n: l10n,
        ),
      _AgentSection.memory => _MemorySection(
          memory: _memory,
          controller: _memoryController,
          l10n: l10n,
          onAdd: _addMemory,
          onDelete: _deleteMemory,
        ),
      _AgentSection.knowledge => _KnowledgeSection(
          knowledge: _knowledge,
          architectureController: _architectureController,
          workflowsController: _workflowsController,
          l10n: l10n,
          onDeleteInsight: (id) async {
            final project =
                context.read<ProjectManagerState>().selectedProject;
            if (project == null) return;
            await _service.deleteKnowledgeInsight(project.path, id);
            await _refreshPromptPreview(project.path);
          },
        ),
      _AgentSection.aiFolder => _AiFolderSection(
          entries: _aiEntries,
          l10n: l10n,
        ),
      _AgentSection.prompt => _PromptSection(
          prompt: _promptPreview ?? '',
          l10n: l10n,
        ),
    };
  }

  String _sectionTitle(AppLocalizations l10n, _AgentSection section) =>
      switch (section) {
        _AgentSection.identity => l10n.agentSectionIdentity,
        _AgentSection.skills => l10n.agentSectionSkills,
        _AgentSection.selfAnalysis => l10n.agentSectionSelfAnalysis,
        _AgentSection.instructions => l10n.agentSectionInstructions,
        _AgentSection.memory => l10n.agentSectionMemory,
        _AgentSection.knowledge => l10n.agentSectionKnowledge,
        _AgentSection.aiFolder => l10n.agentSectionAiFolder,
        _AgentSection.prompt => l10n.agentSectionPrompt,
      };

  IconData _sectionIcon(_AgentSection section) => switch (section) {
        _AgentSection.identity => Icons.badge_outlined,
        _AgentSection.skills => Icons.build_outlined,
        _AgentSection.selfAnalysis => Icons.psychology_outlined,
        _AgentSection.instructions => Icons.school_outlined,
        _AgentSection.memory => Icons.psychology_alt_outlined,
        _AgentSection.knowledge => Icons.menu_book_outlined,
        _AgentSection.aiFolder => Icons.folder_special_outlined,
        _AgentSection.prompt => Icons.terminal_outlined,
      };
}

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({
    required this.skillsController,
    required this.capabilitiesController,
    required this.limitationsController,
    required this.l10n,
  });

  final TextEditingController skillsController;
  final TextEditingController capabilitiesController;
  final TextEditingController limitationsController;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LabeledField(
            label: l10n.agentSkillsLabel,
            child: TextField(
              controller: skillsController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label: l10n.agentCapabilitiesLabel,
            child: TextField(
              controller: capabilitiesController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label: l10n.agentLimitationsLabel,
            child: TextField(
              controller: limitationsController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelfAnalysisSection extends StatelessWidget {
  const _SelfAnalysisSection({
    required this.controller,
    required this.l10n,
    required this.isRunning,
    required this.steps,
    required this.rawOutput,
    required this.logExpanded,
    required this.onLogToggle,
    this.elapsedLabel,
  });

  final TextEditingController controller;
  final AppLocalizations l10n;
  final bool isRunning;
  final List<AgentProgressStep> steps;
  final String rawOutput;
  final bool logExpanded;
  final VoidCallback onLogToggle;
  final String? elapsedLabel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (elapsedLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                elapsedLabel!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IdeaColors.accent,
                    ),
              ),
            ),
          AgentProgressPanel(
            steps: steps,
            title: l10n.agentSelfAnalysisProgressTitle,
            isLive: isRunning,
            partialOutput: rawOutput,
            expanded: logExpanded,
            onToggle: onLogToggle,
          ),
          if (isRunning || steps.isNotEmpty) const SizedBox(height: 16),
          _LabeledField(
            label: l10n.agentSelfAnalysisLabel,
            child: TextField(
              controller: controller,
              minLines: 16,
              maxLines: 40,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                hintText: isRunning ? l10n.agentAnalyzingSelf : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeSection extends StatelessWidget {
  const _KnowledgeSection({
    required this.knowledge,
    required this.architectureController,
    required this.workflowsController,
    required this.l10n,
    required this.onDeleteInsight,
  });

  final ProjectKnowledgeStore knowledge;
  final TextEditingController architectureController;
  final TextEditingController workflowsController;
  final AppLocalizations l10n;
  final ValueChanged<String> onDeleteInsight;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LabeledField(
            label: l10n.agentArchitectureSummaryLabel,
            child: TextField(
              controller: architectureController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label: l10n.agentWorkflowsSummaryLabel,
            child: TextField(
              controller: workflowsController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.agentKnowledgeInsightsLabel,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (knowledge.insights.isEmpty)
            Text(
              l10n.agentMemoryEmpty,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final insight in knowledge.insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: IdeaColors.sidebar,
                  borderRadius: BorderRadius.circular(6),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      insight.topic,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    subtitle: MarkdownContent(
                      data: insight.content,
                      padding: EdgeInsets.zero,
                      compact: true,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => onDeleteInsight(insight.id),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? IdeaColors.background : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: IdeaColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IdeaColors.toolbar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({
    required this.nameController,
    required this.aboutController,
    required this.characterController,
    required this.l10n,
  });

  final TextEditingController nameController;
  final TextEditingController aboutController;
  final TextEditingController characterController;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LabeledField(
            label: l10n.agentNameLabel,
            child: TextField(
              controller: nameController,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label: l10n.agentAboutLabel,
            child: TextField(
              controller: aboutController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label: l10n.agentCharacterLabel,
            child: TextField(
              controller: characterController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionsSection extends StatelessWidget {
  const _InstructionsSection({
    required this.controller,
    required this.l10n,
  });

  final TextEditingController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _LabeledField(
        label: l10n.agentInstructionsLabel,
        child: TextField(
          controller: controller,
          minLines: 12,
          maxLines: 24,
          decoration: InputDecoration(
            hintText: l10n.agentInstructionsHint,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({
    required this.memory,
    required this.controller,
    required this.l10n,
    required this.onAdd,
    required this.onDelete,
  });

  final AgentMemoryStore memory;
  final TextEditingController controller;
  final AppLocalizations l10n;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: l10n.agentMemoryHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onAdd,
                child: Text(l10n.agentAddMemory),
              ),
            ],
          ),
        ),
        Expanded(
          child: memory.entries.isEmpty
              ? Center(
                  child: Text(
                    l10n.agentMemoryEmpty,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: memory.entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = memory.entries[memory.entries.length - 1 - index];
                    return Material(
                      color: IdeaColors.sidebar,
                      borderRadius: BorderRadius.circular(6),
                      child: ListTile(
                        dense: true,
                        title: Text(entry.content, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          entry.createdAt.toLocal().toString().substring(0, 16),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => onDelete(entry.id),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AiFolderSection extends StatelessWidget {
  const _AiFolderSection({
    required this.entries,
    required this.l10n,
  });

  final List<AiFolderEntry> entries;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          l10n.agentAiFolderEmpty,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: IdeaColors.sidebar,
              borderRadius: BorderRadius.circular(6),
              child: ListTile(
                dense: true,
                leading: Icon(
                  entry.isDirectory ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                  size: 18,
                  color: IdeaColors.accent,
                ),
                title: Text(
                  entry.relativePath,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                ),
                subtitle: entry.description != null
                    ? Text(entry.description!, style: const TextStyle(fontSize: 11))
                    : null,
                trailing: Text(
                  entry.isDirectory
                      ? 'dir'
                      : _formatBytes(entry.sizeBytes ?? 0),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _PromptSection extends StatelessWidget {
  const _PromptSection({required this.prompt, required this.l10n});

  final String prompt;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            l10n.agentPromptPreviewHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: IdeaColors.sidebar,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: IdeaColors.panelBorder),
              ),
              child: SelectableText(
                prompt,
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
