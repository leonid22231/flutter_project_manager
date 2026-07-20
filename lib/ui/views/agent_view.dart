import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/core/utils/project_context_paths.dart';
import 'package:project_manager/core/utils/user_language_utils.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/agent_profile.dart';
import 'package:project_manager/models/agent_progress_step.dart';
import 'package:project_manager/models/context_sync_status.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/models/project_knowledge.dart';
import 'package:project_manager/models/project_semantic_index.dart';
import 'package:project_manager/services/agent_chat_history_service.dart';
import 'package:project_manager/services/agent_context_orchestrator.dart';
import 'package:project_manager/services/agent_index_meta_service.dart';
import 'package:project_manager/services/agent_learning_pending_service.dart';
import 'package:project_manager/services/agent_profile_service.dart';
import 'package:project_manager/services/analysis/cursor_cli_project_qa_service.dart';
import 'package:project_manager/services/analysis/project_qa_agent_prompt.dart';
import 'package:project_manager/services/app_log_service.dart';
import 'package:project_manager/services/project_context_service.dart';
import 'package:project_manager/services/project_semantic_index_service.dart';
import 'package:project_manager/state/app_settings_state.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/views/agent_side_panel.dart';
import 'package:project_manager/ui/widgets/agent_progress_panel.dart';
import 'package:project_manager/ui/widgets/markdown_content.dart';
import 'package:provider/provider.dart';

enum AgentReadScope { ai, repo }

enum AgentWriteScope { none, ai, project }

class AgentView extends StatefulWidget {
  const AgentView({super.key});

  @override
  State<AgentView> createState() => _AgentViewState();
}

class _AgentViewState extends State<AgentView> {
  final _profileService = AgentProfileService();
  final _orchestrator = AgentContextOrchestrator();
  final _historyService = AgentChatHistoryService();
  final _pendingService = AgentLearningPendingService();
  final _indexMetaService = AgentIndexMetaService();
  final _contextService = ProjectContextService();
  final _semanticIndex = ProjectSemanticIndexService();
  late final _qaService = CursorCliProjectQaService(
    contextOrchestrator: _orchestrator,
  );

  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  final _attachments = <String>[];

  String? _lastProjectId;
  final List<ProjectQaMessage> _messages = [];
  bool _isAsking = false;
  bool _isIndexing = false;
  String _liveAnswer = '';
  List<ProjectQaReasoningStep> _liveReasoningSteps = const [];
  var _liveReasoningExpanded = false;

  CursorCliMode _mode = CursorCliMode.ask;
  AgentReadScope _readScope = AgentReadScope.repo;
  AgentWriteScope _writeScope = AgentWriteScope.none;
  double _sidePanelWidth = 300;

  AgentProfile? _profile;
  AgentMemoryStore _memory = const AgentMemoryStore();
  ProjectKnowledgeStore _knowledge = const ProjectKnowledgeStore();
  List<AiFolderEntry> _aiEntries = const [];
  LearningPendingStore _pending = const LearningPendingStore();
  AgentIndexMeta _indexMeta = const AgentIndexMeta();
  ProjectContextFileInfo? _contextInfo;
  String? _promptPreview;
  String? _lastQuestion;
  SemanticIndexSnapshot _semantic = const SemanticIndexSnapshot();
  List<AgentProgressStep> _indexAgentSteps = const [];
  String _indexPartialOutput = '';

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    _orchestrator.cancelSelfAnalysis();
    _semanticIndex.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final project = context.read<ProjectManagerState>().selectedProject;
    if (project == null) return;
    if (_lastProjectId == project.id) return;
    _lastProjectId = project.id;
    unawaited(_bootstrap(project.path, project.id));
  }

  Future<void> _bootstrap(String projectRoot, String projectId) async {
    final languageCode = context.l10n.locale.languageCode;
    final messages = await _historyService.load(projectRoot);
    final profile = await _profileService.loadOrCreateProfile(
      projectRoot,
      languageCode: languageCode,
    );
    final memory = await _profileService.loadMemory(projectRoot);
    final knowledge = await _profileService.loadKnowledge(projectRoot);
    final aiEntries = await _profileService.scanAiFolder(projectRoot);
    final pending = await _pendingService.load(projectRoot);
    final indexMeta = await _indexMetaService.load(projectRoot);
    final contextInfo = _contextService.readExisting(projectRoot);
    final semantic = await _semanticIndex.load(projectRoot);

    if (!mounted || _lastProjectId != projectId) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(messages);
      _profile = profile;
      _memory = memory;
      _knowledge = knowledge;
      _aiEntries = aiEntries;
      _pending = pending;
      _indexMeta = indexMeta;
      _contextInfo = contextInfo;
      _semantic = semantic;
      _promptPreview = ProjectQaAgentPrompt.buildPreview(
        contextPath: ProjectContextPaths.contextFilePath(projectRoot),
        responseLanguageCode: languageCode,
        profile: profile,
        memory: memory,
        knowledge: knowledge,
        aiFolderEntries: aiEntries,
      );
      _mode = context.read<AppSettingsState>().cursorCliSettings.defaultMode;
      _writeScope = _mode == CursorCliMode.agent
          ? AgentWriteScope.project
          : AgentWriteScope.none;
    });
  }

  Future<void> _persistChat(String projectRoot) async {
    await _historyService.save(projectRoot, _messages);
  }

  Future<void> _reloadSideData(String projectRoot) async {
    final languageCode = context.l10n.locale.languageCode;
    final memory = await _profileService.loadMemory(projectRoot);
    final knowledge = await _profileService.loadKnowledge(projectRoot);
    final aiEntries = await _profileService.scanAiFolder(projectRoot);
    final pending = await _pendingService.load(projectRoot);
    final indexMeta = await _indexMetaService.load(projectRoot);
    final profile = await _profileService.loadOrCreateProfile(
      projectRoot,
      languageCode: languageCode,
    );
    final semantic = await _semanticIndex.load(projectRoot);
    if (!mounted) return;
    setState(() {
      _memory = memory;
      _knowledge = knowledge;
      _aiEntries = aiEntries;
      _pending = pending;
      _indexMeta = indexMeta;
      _profile = profile;
      _semantic = semantic;
      _contextInfo = _contextService.readExisting(projectRoot);
      _promptPreview = ProjectQaAgentPrompt.buildPreview(
        contextPath: ProjectContextPaths.contextFilePath(projectRoot),
        responseLanguageCode: languageCode,
        profile: profile,
        memory: memory,
        knowledge: knowledge,
        aiFolderEntries: aiEntries,
      );
    });
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

  Future<void> _refreshSnapshotOnly() async {
    final input = _contextInput();
    final project = context.read<ProjectManagerState>().selectedProject;
    if (input == null || project == null || _isIndexing) return;
    final l10n = context.l10n;
    setState(() => _isIndexing = true);
    try {
      final result = await _orchestrator.refreshFullContext(
        input,
        languageCode: l10n.locale.languageCode,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        final meta = await _indexMetaService.recordIndex(
          projectRoot: project.path,
          contextPath: result.filePath,
          sizeBytes: result.sizeBytes,
          notes: 'Structure snapshot only',
          includedSources: const [
            'project-context.json',
            'file tree',
          ],
        );
        await _reloadSideData(project.path);
        if (!mounted) return;
        setState(() {
          _indexMeta = meta;
          _contextInfo = ProjectContextFileInfo(
            filePath: result.filePath,
            generatedAt: result.generatedAt,
            sizeBytes: result.sizeBytes,
            version: 1,
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? l10n.unknownError)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isIndexing = false);
    }
  }

  Future<void> _indexProject() async {
    final input = _contextInput();
    final project = context.read<ProjectManagerState>().selectedProject;
    final settings = context.read<AppSettingsState>().cursorCliSettings;
    if (input == null || project == null || _isIndexing) return;

    final l10n = context.l10n;
    if (!settings.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.analysisCursorDisabled)),
      );
      return;
    }

    setState(() => _isIndexing = true);
    AppLogService.instance.showOverlay();
    AppLogService.instance.info(
      'Starting semantic index…',
      source: 'semantic-index',
    );
    try {
      final snap = await _orchestrator.refreshFullContext(
        input,
        languageCode: l10n.locale.languageCode,
      );
      if (!mounted) return;
      if (snap.isSuccess) {
        setState(() {
          _contextInfo = ProjectContextFileInfo(
            filePath: snap.filePath,
            generatedAt: snap.generatedAt,
            sizeBytes: snap.sizeBytes,
            version: 1,
          );
        });
      }

      final session = await _semanticIndex.startInventory(
        projectRoot: project.path,
        settings: settings,
        languageCode: l10n.locale.languageCode,
        onProgress: (s, {agentSteps = const [], partialOutput = ''}) {
          if (!mounted) return;
          setState(() {
            _semantic = SemanticIndexSnapshot(
              notes: _semantic.notes,
              questions: _semantic.questions,
              answers: _semantic.answers,
              session: s,
            );
            _indexAgentSteps = agentSteps;
            _indexPartialOutput = partialOutput;
          });
        },
      );

      final refreshed = await _semanticIndex.load(project.path);
      if (!mounted) return;
      setState(() {
        _semantic = refreshed;
        if (session.phase != IndexSessionPhase.inventory &&
            session.phase != IndexSessionPhase.deepening) {
          _indexAgentSteps = const [];
          _indexPartialOutput = '';
        }
      });

      if (session.phase == IndexSessionPhase.finalized) {
        await _finalizeSemanticIndex(project.path, snap);
      } else if (session.phase == IndexSessionPhase.awaitingAnswers) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.agentIndexOpenQuestions}: ${refreshed.openQuestionCount}',
            ),
          ),
        );
      } else if (session.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(session.error!)),
        );
      }
      await _reloadSideData(project.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isIndexing = false);
    }
  }

  Future<void> _finalizeSemanticIndex(
    String projectRoot,
    ProjectContextBuildResult? snap,
  ) async {
    final semantic = await _semanticIndex.load(projectRoot);
    final notes = semantic.notes.notes;
    if (notes.isNotEmpty) {
      final top = notes
          .where((n) => !n.path.contains('/') || n.confidence == 'high')
          .take(12)
          .toList();
      for (final n in top) {
        await _profileService.upsertKnowledgeInsight(
          projectRoot,
          topic: 'Index: ${n.path}',
          content: '**${n.role}**\n\n${n.summary}',
          sources: ['semantic-index', ...n.sources],
        );
      }
    }

    final contextPath =
        snap?.filePath ?? ProjectContextPaths.contextFilePath(projectRoot);
    final size = snap?.sizeBytes ??
        (File(contextPath).existsSync() ? File(contextPath).lengthSync() : 0);

    final meta = await _indexMetaService.recordIndex(
      projectRoot: projectRoot,
      contextPath: contextPath,
      sizeBytes: size,
      notes:
          'Semantic index · ${notes.length} notes · ${semantic.answers.answers.length} answers',
      includedSources: const [
        'project-context.json',
        'index/file-notes.json',
        'index/open-questions.json',
        'index/answers.json',
        'full project walk via Cursor',
      ],
    );
    if (!mounted) return;
    setState(() {
      _indexMeta = meta;
      _semantic = semantic;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.agentIndexReady(
            meta.lastIndexedAt!.toLocal().toIso8601String(),
          ),
        ),
      ),
    );
  }

  Future<void> _submitIndexAnswer({
    required String questionId,
    required String text,
    required IndexQuestionStatus status,
  }) async {
    final project = context.read<ProjectManagerState>().selectedProject;
    if (project == null) return;
    await _semanticIndex.submitAnswer(
      projectRoot: project.path,
      questionId: questionId,
      answerText: text,
      status: status,
    );
    final refreshed = await _semanticIndex.load(project.path);
    if (!mounted) return;
    setState(() => _semantic = refreshed);
  }

  Future<void> _continueIndexWithAnswers() async {
    final project = context.read<ProjectManagerState>().selectedProject;
    final settings = context.read<AppSettingsState>().cursorCliSettings;
    if (project == null || _isIndexing) return;
    final l10n = context.l10n;
    if (!settings.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.analysisCursorDisabled)),
      );
      return;
    }

    setState(() => _isIndexing = true);
    AppLogService.instance.showOverlay();
    AppLogService.instance.info(
      'Continuing semantic index with answers…',
      source: 'semantic-index',
    );
    try {
      final session = await _semanticIndex.deepenWithAnswers(
        projectRoot: project.path,
        settings: settings,
        languageCode: l10n.locale.languageCode,
        onProgress: (s, {agentSteps = const [], partialOutput = ''}) {
          if (!mounted) return;
          setState(() {
            _semantic = SemanticIndexSnapshot(
              notes: _semantic.notes,
              questions: _semantic.questions,
              answers: _semantic.answers,
              session: s,
            );
            _indexAgentSteps = agentSteps;
            _indexPartialOutput = partialOutput;
          });
        },
      );
      final refreshed = await _semanticIndex.load(project.path);
      if (!mounted) return;
      setState(() {
        _semantic = refreshed;
        if (session.phase != IndexSessionPhase.deepening) {
          _indexAgentSteps = const [];
          _indexPartialOutput = '';
        }
      });
      if (session.phase == IndexSessionPhase.finalized) {
        await _finalizeSemanticIndex(project.path, null);
      }
      await _reloadSideData(project.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isIndexing = false);
    }
  }

  void _cancelIndexing() {
    _semanticIndex.cancel();
  }

  Future<void> _ask([String? preset]) async {
    final l10n = context.l10n;
    final state = context.read<ProjectManagerState>();
    final settings = context.read<AppSettingsState>().cursorCliSettings;
    final project = state.selectedProject;
    final question = (preset ?? _questionController.text).trim();
    if (project == null || question.isEmpty || _isAsking) return;

    if (!settings.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.analysisCursorDisabled)),
      );
      return;
    }

    if (_contextInfo == null || _indexMeta.isStale) {
      await _refreshSnapshotOnly();
      if (_contextInfo == null) return;
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
      _liveReasoningExpanded = false;
      _lastQuestion = question;
      if (preset == null) _questionController.clear();
    });
    _scrollToBottom();
    await _persistChat(project.path);

    final result = await _qaService.ask(
      settings: settings,
      projectRoot: project.path,
      question: question,
      responseLanguageCode: UserLanguageUtils.resolveResponseLanguageCode(
        question: question,
        appLanguageCode: l10n.locale.languageCode,
      ),
      contextRefresh: _contextInput(),
      history: _messages.where((m) => m != userMessage).toList(),
      mode: _mode,
      autoLearn: true,
      readScope: _readScope == AgentReadScope.ai ? 'ai' : 'repo',
      writeScope: switch (_writeScope) {
        AgentWriteScope.none => 'none',
        AgentWriteScope.ai => 'ai',
        AgentWriteScope.project => 'project',
      },
      attachments: List.of(_attachments),
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
    await _persistChat(project.path);
    await _reloadSideData(project.path);
    _scrollToBottom();
  }

  Future<void> _retryLast() async {
    if (_lastQuestion == null || _isAsking) return;
    await _ask(_lastQuestion);
  }

  Future<void> _exportTranscript() async {
    final project = context.read<ProjectManagerState>().selectedProject;
    if (project == null || _messages.isEmpty) return;
    final path = await _historyService.exportTranscript(project.path, _messages);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.agentTranscriptExported(path))),
    );
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

  void _onModeChanged(CursorCliMode mode) {
    setState(() {
      _mode = mode;
      if (mode == CursorCliMode.ask || mode == CursorCliMode.plan) {
        _writeScope = AgentWriteScope.none;
      } else if (_writeScope == AgentWriteScope.none) {
        _writeScope = AgentWriteScope.ai;
      }
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
    final model = appSettings.cursorCliSettings.defaultModel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: ColoredBox(
            color: IdeaColors.background,
            child: Column(
              children: [
                _AgentChatToolbar(
                  mode: _mode,
                  readScope: _readScope,
                  writeScope: _writeScope,
                  model: model,
                  cursorEnabled: cursorEnabled,
                  isAsking: _isAsking,
                  pendingCount: _pending.candidates.length,
                  indexStale: _indexMeta.isStale || _contextInfo == null,
                  syncStatus: state.contextSyncStatus,
                  syncEnabled: appSettings.contextSyncSettings.isActive,
                  onModeChanged: _onModeChanged,
                  onReadScopeChanged: (v) => setState(() => _readScope = v),
                  onWriteScopeChanged: (v) => setState(() => _writeScope = v),
                  onIndex: () => _indexProject(),
                  onSync: () => state.syncContextNow(),
                  onExport: _exportTranscript,
                  onRetry: _retryLast,
                ),
                const Divider(height: 1, color: IdeaColors.panelBorder),
                Expanded(
                  child: _messages.isEmpty && !_isAsking
                      ? _AgentEmptyState(
                          projectName: project.name,
                          cursorEnabled: cursorEnabled,
                          indexMeta: _indexMeta,
                          onChip: _ask,
                          onIndex: () => _indexProject(),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          itemCount: _messages.length + (_isAsking ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isAsking && index == _messages.length) {
                              return _LiveBubble(
                                answer: _liveAnswer,
                                steps: _liveReasoningSteps,
                                expanded: _liveReasoningExpanded,
                                onToggle: () => setState(
                                  () => _liveReasoningExpanded =
                                      !_liveReasoningExpanded,
                                ),
                              );
                            }
                            return _MessageBubble(
                              message: _messages[index],
                              onCopy: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _messages[index].text),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.copied)),
                                );
                              },
                            );
                          },
                        ),
                ),
                if (_attachments.isNotEmpty)
                  _AttachmentBar(
                    paths: _attachments,
                    onRemove: (path) =>
                        setState(() => _attachments.remove(path)),
                  ),
                _Composer(
                  controller: _questionController,
                  enabled: cursorEnabled && !_isAsking && !_isIndexing,
                  isAsking: _isAsking,
                  onSubmit: () => _ask(),
                  onAttach: () async {
                    final path = await showDialog<String>(
                      context: context,
                      builder: (ctx) {
                        final c = TextEditingController();
                        return AlertDialog(
                          title: Text(l10n.agentAttachPath),
                          content: TextField(
                            controller: c,
                            decoration: InputDecoration(
                              hintText: l10n.agentAttachPathHint,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l10n.cancel),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, c.text.trim()),
                              child: Text(l10n.save),
                            ),
                          ],
                        );
                      },
                    );
                    if (path == null || path.isEmpty) return;
                    if (!File(path).existsSync() &&
                        !Directory(path).existsSync()) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.agentAttachMissing)),
                      );
                      return;
                    }
                    setState(() => _attachments.add(path));
                  },
                ),
              ],
            ),
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              setState(() {
                _sidePanelWidth = (_sidePanelWidth - details.delta.dx)
                    .clamp(220.0, 560.0);
              });
            },
            child: const SizedBox(width: 5),
          ),
        ),
        SizedBox(
          width: _sidePanelWidth,
          child: AgentSidePanel(
            projectPath: project.path,
            profile: _profile,
            memory: _memory,
            knowledge: _knowledge,
            aiEntries: _aiEntries,
            pending: _pending,
            indexMeta: _indexMeta,
            contextInfo: _contextInfo,
            promptPreview: _promptPreview,
            isIndexing: _isIndexing,
            semantic: _semantic,
            indexAgentSteps: _indexAgentSteps,
            indexPartialOutput: _indexPartialOutput,
            syncStatus: state.contextSyncStatus,
            syncEnabled: appSettings.contextSyncSettings.isActive,
            onReload: () => _reloadSideData(project.path),
            onIndex: () => _indexProject(),
            onSnapshotOnly: () => _refreshSnapshotOnly(),
            onCancelIndex: _cancelIndexing,
            onContinueIndex: () => _continueIndexWithAnswers(),
            onSubmitIndexAnswer: ({
              required questionId,
              required text,
              required status,
            }) =>
                _submitIndexAnswer(
                  questionId: questionId,
                  text: text,
                  status: status,
                ),
            onSync: () => state.syncContextNow(),
            onConfirmLearning: (store) async {
              final input = _contextInput();
              if (input == null) return;
              await _orchestrator.confirmPendingLearning(
                contextInput: input,
                store: store,
                languageCode: context.l10n.locale.languageCode,
              );
              await _reloadSideData(project.path);
            },
            onDiscardLearning: () async {
              await _orchestrator.discardPendingLearning(project.path);
              await _reloadSideData(project.path);
            },
            onOpenFile: (path) {
              context.read<ProjectManagerState>().openFile(path);
            },
          ),
        ),
      ],
    );
  }
}

class _AgentChatToolbar extends StatelessWidget {
  const _AgentChatToolbar({
    required this.mode,
    required this.readScope,
    required this.writeScope,
    required this.model,
    required this.cursorEnabled,
    required this.isAsking,
    required this.pendingCount,
    required this.indexStale,
    required this.syncStatus,
    required this.syncEnabled,
    required this.onModeChanged,
    required this.onReadScopeChanged,
    required this.onWriteScopeChanged,
    required this.onIndex,
    required this.onSync,
    required this.onExport,
    required this.onRetry,
  });

  final CursorCliMode mode;
  final AgentReadScope readScope;
  final AgentWriteScope writeScope;
  final String model;
  final bool cursorEnabled;
  final bool isAsking;
  final int pendingCount;
  final bool indexStale;
  final ContextSyncStatus syncStatus;
  final bool syncEnabled;
  final ValueChanged<CursorCliMode> onModeChanged;
  final ValueChanged<AgentReadScope> onReadScopeChanged;
  final ValueChanged<AgentWriteScope> onWriteScopeChanged;
  final VoidCallback onIndex;
  final VoidCallback onSync;
  final VoidCallback onExport;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: IdeaColors.toolbar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ModeChip(
              label: 'ask',
              selected: mode == CursorCliMode.ask,
              onTap: () => onModeChanged(CursorCliMode.ask),
            ),
            _ModeChip(
              label: 'plan',
              selected: mode == CursorCliMode.plan,
              onTap: () => onModeChanged(CursorCliMode.plan),
            ),
            _ModeChip(
              label: 'agent',
              selected: mode == CursorCliMode.agent,
              onTap: () => onModeChanged(CursorCliMode.agent),
            ),
            const SizedBox(width: 4),
            DropdownButton<AgentReadScope>(
              value: readScope,
              underline: const SizedBox.shrink(),
              style: Theme.of(context).textTheme.labelSmall,
              items: [
                DropdownMenuItem(
                  value: AgentReadScope.ai,
                  child: Text(l10n.agentReadAiOnly),
                ),
                DropdownMenuItem(
                  value: AgentReadScope.repo,
                  child: Text(l10n.agentReadRepo),
                ),
              ],
              onChanged: (v) => v == null ? null : onReadScopeChanged(v),
            ),
            DropdownButton<AgentWriteScope>(
              value: writeScope,
              underline: const SizedBox.shrink(),
              style: Theme.of(context).textTheme.labelSmall,
              items: [
                DropdownMenuItem(
                  value: AgentWriteScope.none,
                  child: Text(l10n.agentWriteNone),
                ),
                DropdownMenuItem(
                  value: AgentWriteScope.ai,
                  child: Text(l10n.agentWriteAi),
                ),
                DropdownMenuItem(
                  value: AgentWriteScope.project,
                  child: Text(l10n.agentWriteProject),
                ),
              ],
              onChanged: mode == CursorCliMode.agent
                  ? (v) => v == null ? null : onWriteScopeChanged(v)
                  : null,
            ),
            Text(
              model,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: IdeaColors.textSecondary,
                  ),
            ),
            if (indexStale)
              _StatusPill(
                color: IdeaColors.warning,
                label: l10n.agentIndexStale,
                onTap: onIndex,
              ),
            if (pendingCount > 0)
              _StatusPill(
                color: IdeaColors.accent,
                label: l10n.agentPendingLearning(pendingCount),
              ),
            if (syncEnabled && syncStatus.hasError)
              _StatusPill(
                color: IdeaColors.error,
                label: l10n.statusBarContextSyncError,
                onTap: onSync,
              ),
            if (!cursorEnabled)
              _StatusPill(
                color: IdeaColors.warning,
                label: l10n.analysisCursorDisabled,
              ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: l10n.agentRetry,
              onPressed: isAsking ? null : onRetry,
              icon: const Icon(Icons.refresh, size: 16),
            ),
            IconButton(
              tooltip: l10n.agentExportTranscript,
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined, size: 16),
            ),
            IconButton(
              tooltip: l10n.agentIndexNow,
              onPressed: onIndex,
              icon: const Icon(Icons.travel_explore, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? IdeaColors.accent.withValues(alpha: 0.18) : null,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected ? IdeaColors.accent : IdeaColors.panelBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            height: 1.1,
            color: selected ? IdeaColors.accent : IdeaColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.color,
    required this.label,
    this.onTap,
  });

  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, color: color)),
      ),
    );
  }
}

class _AgentEmptyState extends StatelessWidget {
  const _AgentEmptyState({
    required this.projectName,
    required this.cursorEnabled,
    required this.indexMeta,
    required this.onChip,
    required this.onIndex,
  });

  final String projectName;
  final bool cursorEnabled;
  final AgentIndexMeta indexMeta;
  final ValueChanged<String> onChip;
  final VoidCallback onIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.smart_toy_outlined,
                  size: 28, color: IdeaColors.accent),
              const SizedBox(height: 8),
              Text(
                l10n.tabAgent,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.agentWorkspaceWelcome(projectName),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!cursorEnabled) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.analysisCursorDisabled,
                  style: const TextStyle(color: IdeaColors.warning, fontSize: 11),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final chip in [
                    l10n.agentChipArchitecture,
                    l10n.agentChipMemory,
                    l10n.agentChipUpdateKnowledge,
                    l10n.agentChipGaps,
                  ])
                    ActionChip(
                      label: Text(chip, style: const TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () => onChip(chip),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.travel_explore, size: 12),
                    label: Text(
                      l10n.agentIndexNow,
                      style: const TextStyle(fontSize: 10),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onPressed: onIndex,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onCopy});

  final ProjectQaMessage message;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubble = (constraints.maxWidth * 0.96).clamp(280.0, 920.0);
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            constraints: BoxConstraints(maxWidth: maxBubble),
            decoration: BoxDecoration(
              color: isUser
                  ? IdeaColors.accent.withValues(alpha: 0.12)
                  : IdeaColors.sidebar,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    message.isError ? IdeaColors.error : IdeaColors.panelBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isUser ? 'You' : 'Agent',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isUser
                            ? IdeaColors.textBright
                            : IdeaColors.accent,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: context.l10n.copy,
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy, size: 13),
                      visualDensity: VisualDensity.compact,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (isUser)
                  SelectableText(
                    message.text,
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  )
                else ...[
                  if (message.reasoningSteps.isNotEmpty) ...[
                    AgentProgressPanel(
                      title: context.l10n.agentShowReasoning,
                      steps: [
                        for (final s in message.reasoningSteps)
                          AgentProgressStep(
                            text: s.text,
                            timestamp: s.timestamp,
                            isComplete: s.isComplete,
                          ),
                      ],
                      isLive: false,
                      expanded: false,
                    ),
                    const SizedBox(height: 6),
                  ],
                  MarkdownContent(
                    data: message.text,
                    padding: EdgeInsets.zero,
                    variant: MarkdownContentVariant.chat,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LiveBubble extends StatelessWidget {
  const _LiveBubble({
    required this.answer,
    required this.steps,
    required this.expanded,
    required this.onToggle,
  });

  final String answer;
  final List<ProjectQaReasoningStep> steps;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubble = (constraints.maxWidth * 0.96).clamp(280.0, 920.0);
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            constraints: BoxConstraints(maxWidth: maxBubble),
            decoration: BoxDecoration(
              color: IdeaColors.sidebar,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: IdeaColors.panelBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.l10n.analysisStreaming,
                      style: const TextStyle(fontSize: 10),
                    ),
                    const Spacer(),
                    if (steps.isNotEmpty)
                      TextButton(
                        onPressed: onToggle,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          expanded
                              ? context.l10n.agentHideReasoning
                              : context.l10n.agentShowReasoning,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                ),
                if (expanded && steps.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...steps.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Expanded(
                            child: MarkdownContent(
                              data: s.text,
                              padding: EdgeInsets.zero,
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                if (answer.isEmpty)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  MarkdownContent(
                    data: answer,
                    padding: EdgeInsets.zero,
                    variant: MarkdownContentVariant.chat,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttachmentBar extends StatelessWidget {
  const _AttachmentBar({required this.paths, required this.onRemove});

  final List<String> paths;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: IdeaColors.sidebar,
      child: Wrap(
        spacing: 6,
        children: [
          for (final path in paths)
            InputChip(
              label: Text(path.split(RegExp(r'[\\/]')).last,
                  style: const TextStyle(fontSize: 11)),
              onDeleted: () => onRemove(path),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.isAsking,
    required this.onSubmit,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isAsking;
  final VoidCallback onSubmit;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: IdeaColors.toolbar,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: IdeaColors.panelBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: l10n.agentAttachPath,
              onPressed: enabled ? onAttach : null,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.attach_file, size: 16),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 3,
                style: const TextStyle(fontSize: 12.5, height: 1.35),
                decoration: InputDecoration(
                  hintText: l10n.analysisAskPlaceholder,
                  isDense: true,
                  filled: true,
                  fillColor: IdeaColors.inputBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: IdeaColors.panelBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: IdeaColors.panelBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: IdeaColors.accent),
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 32,
              child: FilledButton(
                onPressed: enabled ? onSubmit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: IdeaColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: isAsking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n.analysisAskButton,
                        style: const TextStyle(fontSize: 12),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
