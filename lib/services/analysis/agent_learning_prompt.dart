/// Prompts for agent learning and self-analysis (JSON output).
class AgentLearningPrompt {
  const AgentLearningPrompt._();

  static String buildLearningPrompt({
    required String question,
    required String answer,
    required String languageCode,
  }) {
    final langNote = languageCode == 'ru'
        ? 'Пиши значения полей JSON на русском.'
        : 'Write JSON field values in English.';

    return '''
You are the project knowledge curator for a Flutter workspace.

Read FIRST (do not skip):
- `.ai/project-context.json` — full project + agent memory + knowledge
- `.ai/agent-memory.json`
- `.ai/project-knowledge.json`

Then extract NEW durable facts from the Q&A below. Merge with existing knowledge — do NOT duplicate.

$langNote

Return ONLY valid JSON (no markdown wrapper):
{
  "memory": ["short atomic fact about how the project works"],
  "insights": [
    {"topic": "Architecture|Widget|Dependency|Build|Git|Agent", "content": "detailed insight", "sources": ["path or context section"]}
  ],
  "architectureSummary": "optional updated 2-5 sentence architecture summary or empty string",
  "workflowsSummary": "optional updated workflows/build/dev summary or empty string"
}

Rules:
- Add 1-5 memory facts max, only if genuinely new
- Add 0-3 insights max, update topics when refining existing knowledge
- Focus on HOW things connect (A uses B, screen X calls service Y)
- Prefer facts answerable without re-reading source code next time
- If nothing new, return {"memory":[],"insights":[],"architectureSummary":"","workflowsSummary":""}

User question:
$question

Assistant answer:
$answer
''';
  }

  static String buildSelfAnalysisPrompt({required String languageCode}) {
    final langNote = languageCode == 'ru'
        ? 'Пиши значения полей JSON на русском.'
        : 'Write JSON field values in English.';

    return '''
Analyze YOURSELF as the Project Manager AI agent for this workspace.

Read ONLY these files (do not scan `lib/` or other source folders):
- `.ai/agent-profile.json`
- `.ai/agent-memory.json`
- `.ai/project-knowledge.json`
- `.ai/project-context.json` (agent section only)
- List files in `.ai/` (one directory listing, no recursion into project code)

Rules:
- Maximum 6 tool calls total. Stop reading after you have the `.ai` snapshot.
- Do NOT explore the codebase, dependencies, or widgets for self-analysis.
- Be concise but honest about memory/knowledge gaps.

$langNote

Return ONLY valid JSON:
{
  "selfAnalysis": "Markdown: who you are, what you know about this project, memory stats, skills, limits, .ai folder contents",
  "skills": "comma-separated or short paragraph",
  "capabilities": "what you can do for the user",
  "limitations": "what you cannot do",
  "aboutSelf": "1-3 sentences intro for the user"
}

Be honest about gaps in memory/knowledge. Mention that context auto-refreshes after each chat.
''';
  }
}
