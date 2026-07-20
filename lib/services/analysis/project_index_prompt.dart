/// Prompts for semantic project indexing via Cursor CLI (ask mode).
class ProjectIndexPrompt {
  const ProjectIndexPrompt._();

  static String buildInventoryBatch({
    required String languageCode,
    required String batchLabel,
    required List<String> relativePaths,
    required int batchIndex,
    required int totalBatches,
  }) {
    final lang = languageCode == 'ru'
        ? 'Write all human-readable strings (role, summary, question, whyNeeded) in Russian.'
        : 'Write all human-readable strings in English.';

    final paths = relativePaths.map((p) => '- `$p`').join('\n');

    return '''
You are indexing a Flutter/desktop project for Project Manager.

$lang

## CRITICAL RULES
1. Prefer QUESTIONS over guesses. If purpose is unclear → emit a question.
2. Do NOT invent product intent, business rules, or "probably used for…".
3. Only state what is evident from reading the files (names, imports, comments, structure).
4. confidence must be "high" | "medium" | "low" | "unknown". Use "unknown" when unsure.
5. Return ONLY valid JSON (no markdown fence around the JSON object).

## Batch
$batchLabel (batch ${batchIndex + 1}/$totalBatches)

Paths to cover in this batch:
$paths

Read these paths (and nearby siblings only if needed to understand a file). Cover as many as you can.

## Output JSON schema
{
  "notes": [
    {
      "path": "relative/path",
      "role": "short role label",
      "summary": "what this file/dir is for (facts only)",
      "confidence": "high|medium|low|unknown",
      "sources": ["evidence: import X / class Y / comment Z"]
    }
  ],
  "questions": [
    {
      "id": "stable-slug-or-uuid",
      "path": "relative/path or null",
      "question": "clear question for the human",
      "whyNeeded": "why the index cannot proceed without this",
      "options": ["optional suggested answers"]
    }
  ]
}

If everything is clear, return "questions": [].
If a path is binary/generated/noise, note role="ignored" with short summary.
''';
  }

  static String buildDeepenPass({
    required String languageCode,
    required List<Map<String, String>> answeredPairs,
    required List<String> focusPaths,
  }) {
    final lang = languageCode == 'ru'
        ? 'Write summaries and any new questions in Russian.'
        : 'Write summaries and any new questions in English.';

    final answersBlock = answeredPairs.isEmpty
        ? '(no new answers)'
        : answeredPairs
            .map((p) =>
                '- Q(${p['id']}): ${p['question']}\n  A (${p['kind']}): ${p['answer']}')
            .join('\n');

    final focus = focusPaths.isEmpty
        ? '(project-wide deepen using answers)'
        : focusPaths.map((p) => '- `$p`').join('\n');

    return '''
You are continuing semantic indexing of a Flutter project.

$lang

## CRITICAL RULES
1. Use the user's answers as ground truth.
2. Still prefer NEW questions over invention for anything still unclear.
3. Do not contradict user answers.
4. kind=unknown/skipped means leave that area marked uncertain — do not invent.
5. Return ONLY valid JSON (no markdown fence).

## User answers
$answersBlock

## Focus paths (update notes for these when relevant)
$focus

## Output JSON schema
{
  "notes": [
    {
      "path": "relative/path",
      "role": "short role",
      "summary": "updated factual summary incorporating answers",
      "confidence": "high|medium|low|unknown",
      "sources": ["user answer", "file evidence"]
    }
  ],
  "questions": [
    {
      "id": "new-id",
      "path": "relative/path or null",
      "question": "follow-up only if still unclear",
      "whyNeeded": "...",
      "options": []
    }
  ],
  "done": false
}

Set "done": true only if no important open ambiguities remain for the covered scope.
''';
  }
}
