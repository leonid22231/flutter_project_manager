import 'package:flutter/material.dart';
import 'package:project_manager/core/theme/idea_theme.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/services/ai_folder_reader.dart';

class AiFolderView extends StatefulWidget {
  const AiFolderView({super.key, required this.project});

  final Project project;

  @override
  State<AiFolderView> createState() => _AiFolderViewState();
}

class _AiFolderViewState extends State<AiFolderView> {
  late AiFolderSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = readAiFolder(widget.project.path);
  }

  @override
  void didUpdateWidget(covariant AiFolderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.path != widget.project.path) {
      _snapshot = readAiFolder(widget.project.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = _snapshot;
    if (snapshot.isEmpty) {
      return Center(
        child: Text(
          l10n.aiFolderEmpty,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final current = snapshot.tasks.isEmpty ? null : snapshot.tasks.first;
    final recent = snapshot.tasks.skip(1).take(6).toList();
    final hiddenTasks = snapshot.tasks.length - (current == null ? 0 : 1) - recent.length;
    final memories = snapshot.memories.take(8).toList();
    final hiddenMemories = snapshot.memories.length - memories.length;
    final questions = snapshot.openQuestions.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        if (current != null) _CurrentTask(task: current, l10n: l10n),
        if (questions.isNotEmpty)
          _Section(title: l10n.aiOpenQuestions, notes: questions),
        if (memories.isNotEmpty) ...[
          _Section(title: l10n.aiMemories, notes: memories),
          if (hiddenMemories > 0)
            Text(
              l10n.aiMoreCount(hiddenMemories),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        if (recent.isNotEmpty) ...[
          _Section(title: l10n.aiRecentTasks, notes: recent),
          if (hiddenTasks > 0)
            Text(
              l10n.aiMoreCount(hiddenTasks),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}

class _CurrentTask extends StatelessWidget {
  const _CurrentTask({required this.task, required this.l10n});

  final AiNote task;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (task.status.isNotEmpty) task.status,
      if (task.when.isNotEmpty) task.when,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.aiNow.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: const TextStyle(
              color: IdeaColors.textBright,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(meta, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (task.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              task.body.length > 500 ? '${task.body.substring(0, 500)}…' : task.body,
              style: const TextStyle(
                color: IdeaColors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.notes});

  final String title;
  final List<AiNote> notes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        for (final note in notes) _NoteTile(note: note),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});

  final AiNote note;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      note.title,
      style: const TextStyle(color: IdeaColors.textBright, fontSize: 14),
    );
    final meta = [
      if (note.status.isNotEmpty) note.status,
      if (note.when.isNotEmpty) note.when,
    ].join(' · ');
    final subtitle = meta.isEmpty
        ? null
        : Text(meta, style: Theme.of(context).textTheme.bodySmall);
    if (note.body.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: title,
        subtitle: subtitle,
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: title,
        subtitle: subtitle,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              note.body,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
