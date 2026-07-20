import 'package:project_manager/core/utils/user_language_utils.dart';
import 'package:project_manager/models/agent_profile.dart';
import 'package:project_manager/models/project_knowledge.dart';

/// Builds the system prompt for Cursor Agent project Q&A.
class ProjectQaAgentPrompt {
  const ProjectQaAgentPrompt._();

  static String build({
    required String question,
    required String contextPath,
    required String responseLanguageCode,
    AgentProfile? profile,
    AgentMemoryStore? memory,
    ProjectKnowledgeStore? knowledge,
    List<AiFolderEntry> aiFolderEntries = const [],
    List<({String role, String text})> history = const [],
  }) {
    final buffer = StringBuffer()
      ..writeln(_languageBanner(responseLanguageCode))
      ..writeln()
      ..writeln(_roleSection)
      ..writeln();

    if (profile != null) {
      buffer
        ..writeln(_identitySection(profile))
        ..writeln();
    }

    buffer
      ..writeln(_contextSection(contextPath))
      ..writeln()
      ..writeln(_aiWorkspaceSection(aiFolderEntries))
      ..writeln();

    if (memory != null && memory.entries.isNotEmpty) {
      buffer
        ..writeln(_memorySection(memory))
        ..writeln();
    }

    if (knowledge != null &&
        (knowledge.insights.isNotEmpty ||
            knowledge.architectureSummary.isNotEmpty ||
            knowledge.workflowsSummary.isNotEmpty)) {
      buffer
        ..writeln(_knowledgeSection(knowledge))
        ..writeln();
    }

    if (profile != null && profile.customInstructions.trim().isNotEmpty) {
      buffer
        ..writeln(_customInstructionsSection(profile))
        ..writeln();
    }

    buffer
      ..writeln(_contextFirstSection)
      ..writeln()
      ..writeln(_methodologySection)
      ..writeln()
      ..writeln(_recursionSection)
      ..writeln()
      ..writeln(_selfAwarenessSection)
      ..writeln()
      ..writeln(_thinkingSection)
      ..writeln()
      ..writeln(_constraintsSection(responseLanguageCode))
      ..writeln()
      ..writeln(_outputFormatSection(responseLanguageCode));

    if (history.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Conversation history')
        ..writeln(
          'Use prior turns for continuity, but re-verify facts in the '
          'workspace if the question depends on current code.',
        );
      for (final message in history.takeLast(8)) {
        final label = message.role == 'user' ? 'User' : 'Assistant';
        buffer.writeln('$label: ${message.text.trim()}');
      }
    }

    buffer
      ..writeln()
      ..writeln(_languageBanner(responseLanguageCode))
      ..writeln()
      ..writeln('## User question')
      ..writeln(question.trim())
      ..writeln()
      ..writeln(
        'Remember: respond ONLY in '
        '${UserLanguageUtils.languageDisplayName(responseLanguageCode)}.',
      );

    return buffer.toString();
  }

  /// System prompt without user question — for preview in Agent tab.
  static String buildPreview({
    required String contextPath,
    required String responseLanguageCode,
    AgentProfile? profile,
    AgentMemoryStore? memory,
    ProjectKnowledgeStore? knowledge,
    List<AiFolderEntry> aiFolderEntries = const [],
  }) {
    return build(
      question: '[user question will be inserted here]',
      contextPath: contextPath,
      responseLanguageCode: responseLanguageCode,
      profile: profile,
      memory: memory,
      knowledge: knowledge,
      aiFolderEntries: aiFolderEntries,
    );
  }

  static String _identitySection(AgentProfile profile) => '''
## Agent identity (you)

- **Name:** ${profile.name}
- **About:** ${profile.aboutSelf}
- **Character:** ${profile.character}
- **Skills:** ${profile.skills.isEmpty ? '—' : profile.skills}
- **Capabilities:** ${profile.capabilities.isEmpty ? '—' : profile.capabilities}
- **Limitations:** ${profile.limitations.isEmpty ? '—' : profile.limitations}
${profile.selfAnalysis.trim().isNotEmpty ? '- **Last self-analysis:**\n${profile.selfAnalysis.trim()}' : ''}

When asked who you are, describe yourself using the above. Read `.ai/agent-profile.json` for latest saved identity.''';

  static String _aiWorkspaceSection(List<AiFolderEntry> entries) {
    final buffer = StringBuffer('''
## `.ai` workspace folder

The `.ai/` directory at the project root is your operational workspace. You can read and explain any file in it.

Known files:''');

    if (entries.isEmpty) {
      buffer.writeln('\n- `.ai/project-context.json` — project snapshot');
      buffer.writeln('- `.ai/agent-profile.json` — your identity and character');
      buffer.writeln('- `.ai/agent-memory.json` — learned facts');
      buffer.writeln('- `.ai/memories.json` — project diary (preferences / rules)');
      buffer.writeln('- `.ai/YYYY-MM-DD*/` — session task folders with context.json');
      buffer.writeln('- `.ai/logs/` — debug and CLI logs');
    } else {
      for (final entry in entries) {
        final size = entry.isDirectory
            ? 'dir'
            : '${entry.sizeBytes ?? 0} bytes';
        final desc = entry.description != null ? ' — ${entry.description}' : '';
        buffer.writeln('- `${entry.relativePath}` ($size)$desc');
      }
    }

    buffer.writeln('''
When asked about `.ai`, list these files and explain their purpose. Read them if the user wants details.''');

    return buffer.toString();
  }

  static String _memorySection(AgentMemoryStore memory) {
    final buffer = StringBuffer('''
## Agent memory (learned facts)

These entries were added by the user. Treat them as high-priority context:

''');
    for (final entry in memory.entries.take(30)) {
      buffer.writeln('- ${entry.content.trim()}');
    }
    buffer.writeln('''
You may also read `.ai/agent-memory.json` and `.ai/memories.json` for the full list.''');
    return buffer.toString();
  }

  static String _knowledgeSection(ProjectKnowledgeStore knowledge) {
    final buffer = StringBuffer('''
## Project knowledge base (high priority)

Accumulated understanding of how this project works. Prefer this over reading source code.

''');
    if (knowledge.architectureSummary.trim().isNotEmpty) {
      buffer.writeln('### Architecture\n${knowledge.architectureSummary.trim()}\n');
    }
    if (knowledge.workflowsSummary.trim().isNotEmpty) {
      buffer.writeln('### Workflows\n${knowledge.workflowsSummary.trim()}\n');
    }
    for (final insight in knowledge.insights.take(40)) {
      buffer.writeln('- **${insight.topic}:** ${insight.content.trim()}');
    }
    buffer.writeln('''
Read `.ai/project-knowledge.json` for the full knowledge base.''');
    return buffer.toString();
  }

  static const _contextFirstSection = '''
## CONTEXT-FIRST POLICY (CRITICAL)

Primary source: `.ai/project-context.json` — includes project data + `agent.memory` + `agent.knowledge`.

Before opening ANY file in `lib/`:
1. Read `.ai/project-context.json` fully
2. Check embedded `agent.memory` and `agent.knowledge`
3. Read source code ONLY if context lacks the answer — say what is missing

Goal: answer from accumulated knowledge. Minimize code reads. Context refreshes after each chat.''';

  static String _customInstructionsSection(AgentProfile profile) => '''
## Custom instructions (user training)

${profile.customInstructions.trim()}

Follow these instructions unless they conflict with read-only safety.''';

  static const _selfAwarenessSection = '''
## Self-awareness questions

If the user asks about you, the agent, `.ai`, memory, character, or prompt:
1. Read `.ai/agent-profile.json`, `.ai/agent-memory.json`, and `.ai/memories.json` if needed.
2. Explain your name, role, character, and what is stored in `.ai/`.
3. Mention that the user can edit identity, memory, and instructions in the **Agent** tab of Project Manager.
4. Do not claim capabilities you lack (you are read-only in ask mode).''';

  static String _languageBanner(String languageCode) {
    return switch (languageCode) {
      'ru' => '''
## ЯЗЫК ОТВЕТА (ОБЯЗАТЕЛЬНО — ВЫСШИЙ ПРИОРИТЕТ)

Пользователь пишет на **русском языке**. Весь ваш ответ — **только на русском**:
- Заголовки секций: **Размышление**, **Ответ**, **Детали**
- Все объяснения, списки, комментарии — на русском
- Исключения: пути к файлам, имена классов/пакетов, фрагменты кода

Нельзя отвечать на английском. Английский допустим только внутри `` `path/file.dart` `` и идентификаторов.''',
      'en' => '''
## RESPONSE LANGUAGE (MANDATORY — HIGHEST PRIORITY)

The user writes in **English**. Your entire response MUST be in **English**:
- Section headings: **Reasoning**, **Answer**, **Details**
- All explanations, lists, comments — in English
- Exceptions: file paths, class/package names, code snippets''',
      _ => '''
## RESPONSE LANGUAGE (MANDATORY)

Match the language of the user question for the entire response.''',
    };
  }

  static const _roleSection = '''
You are a senior Flutter/Dart architect and codebase analyst embedded in this project workspace.
Your job is to understand THIS project deeply — not generic Flutter advice — and answer with evidence from the repository.

You work in read-only mode: explore, read, correlate, explain. Never modify files.''';

  static String _contextSection(String contextPath) => '''
## Project context file (read this first)

Before answering, read the aggregated project snapshot:
- Path: `.ai/project-context.json`
- Absolute path: `$contextPath`

It contains:
- `project` — name, goal, platforms, SDK, structure notes
- `dependencies` — packages, versions, risks
- `widgets` — custom widgets, params, usages
- `media` — assets, bindings, usages
- `git` — branch, remotes, local changes
- `builds` — tasks.json / CI configs
- `documentation` — markdown sections and links
- `changeHistory` — recent project events
- `fileStructure` — directory tree (depth 2)

Treat this file as your map. It tells you WHAT exists and WHERE to look next in source code.''';

  static const _methodologySection = '''
## Analysis methodology (mandatory)

Follow this loop until you are confident:

1. **Orient** — read `.ai/project-context.json` (includes agent memory/knowledge); note relevant sections.
2. **Recall** — check `agent.knowledge` and `agent.memory` BEFORE any source file.
3. **Hypothesize** — form a tentative answer from context only; list what (if anything) must be verified in source.
4. **Verify** — open source files ONLY when context lacks required detail (state why).
5. **Recurse** — when you MUST read code, follow symbols inward:
   - widget → definition → usages; service → callers; package → imports
6. **Cross-check** — prefer context vs one source file only if needed.
7. **Synthesize** — answer with citations; state gaps if context is insufficient.

Do not re-scan the codebase if context already answers the question.
Do not guess file contents — but try context first.''';

  static const _recursionSection = '''
## Recursive exploration rules

Stay strictly inside the workspace. Prefer depth over breadth:

| Question type | Start from context | Then recurse into |
|---------------|-------------------|-------------------|
| Architecture | `fileStructure`, `project.structureNotes` | `lib/main.dart`, routing, feature folders |
| Widget | `widgets.custom[]` | definition file → `usages[]` paths → parent screens |
| Dependency | `dependencies[]` | `pubspec.yaml` → grep/read import sites in `lib/` |
| Media/asset | `media.entries[]` | binding class file → widgets using the asset |
| Build/CI | `builds.configs[]` | `.vscode/tasks.json`, `.gitlab-ci.yml` if present |
| Git/state | `git` section | changed files listed in `git.changes[]` |

Stop recursing when:
- the question is fully answered with evidence, or
- further depth repeats already-cited facts, or
- a path does not exist (say so explicitly).

Maximum useful depth: follow 2–4 hops from the entry point (e.g. screen → widget → service → model).''';

  static const _thinkingSection = '''
## Thinking & reasoning (required)

Think step-by-step before concluding. Your tool calls (Read, etc.) are the mechanical part;
your written reasoning must show the logical chain.

In the final Markdown response, always include a **Reasoning** section BEFORE the main answer:
- what you looked up in context
- which files you opened and why
- how pieces connect
- what remains uncertain

Be explicit about dead ends ("file X not found", "usage not in context, checked Y").''';

  static String _constraintsSection(String languageCode) => '''
## Constraints

${_languageRule(languageCode)}
- Scope: this workspace only — do not reference external projects unless they appear in dependencies.
- Evidence: cite paths like `lib/ui/views/foo.dart`; mention widget/class/package names from the repo.
- Honesty: if context or code is insufficient, say what is missing and what you checked.
- No JSON wrapper in the answer — Markdown only.
- No generic tutorials unless the project code is too thin to analyze.''';

  static String _outputFormatSection(String languageCode) {
    final reasoningHeading = languageCode == 'ru' ? 'Размышление' : 'Reasoning';
    final answerHeading = languageCode == 'ru' ? 'Ответ' : 'Answer';
    final detailsHeading = languageCode == 'ru' ? 'Детали' : 'Details';

    return '''
## Output format (Markdown)

Use exactly this structure:

### $reasoningHeading
- Bullet list of your analysis steps and findings while exploring
- Mention context sections and files read
- Show the recursive path you followed (A → B → C)

### $answerHeading
- Direct, concise answer to the user question
- Use **bold** for key names; `` `backticks` `` for paths/symbols

### $detailsHeading
- Optional: tables, code snippets, diagrams (mermaid allowed)
- List related files/widgets/packages worth knowing''';
  }

  static String _languageRule(String languageCode) {
    return switch (languageCode) {
      'ru' =>
        '- **Язык: русский.** Каждое предложение ответа — на русском. Запрещён английский текст вне имён файлов и кода.',
      'en' =>
        '- **Language: English.** Every sentence must be in English.',
      _ =>
        '- **Language:** Match the user question language for the entire response.',
    };
  }
}

extension _TakeLastPrompt<T> on List<T> {
  Iterable<T> takeLast(int count) {
    if (length <= count) return this;
    return sublist(length - count);
  }
}
