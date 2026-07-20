# MERGE_NOTES

Merged at: 2026-07-20T14:59:17Z
Strategy: additive union (JSON by id/key, text by unique lines; prefer more complete / local on scalar conflicts).

## Local-only files kept
- `logs/cursor-prompt-1784559424115.md`

## Remote-only files kept
- (none)

## Content conflicts resolved
- `index/index-session.json` — Local more complete (phase=`inventory`, processedFiles=239/283, batch 17/20, folder=`pubspec.lock`, newer `updatedAt`). Remote was batch 12/20 at `lib` (114/283). Kept local.
- `index/file-notes.json` — Local strict path-superset (125 vs 35 notes; 0 content conflicts on shared paths). Kept local (union == local).
- `index/open-questions.json` — Local strict id-superset (6 vs 2 questions; 0 content conflicts). Kept local (union == local).
- `logs/cursor-cli-2026-07-20.log` — Local strict line-superset (+4 semantic-index start lines at 21:54–21:57). Kept local.

## Identical on both sides
28 shared files unchanged (config, agent-profile, project-context, memories.json, session artifacts, etc.).

## Notes
- Previous merge at 2026-07-20T14:53:40Z left remote at batch 12; local continued indexing to batch 17 before this sync.