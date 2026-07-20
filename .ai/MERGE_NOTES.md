# MERGE_NOTES

Merged at: 2026-07-20T15:13:30Z
Strategy: additive union (JSON by id/key, text by unique lines; prefer more complete / local on scalar conflicts).

## Local-only files kept
- `logs/cursor-prompt-1784560393361.md`

## Remote-only files kept
- (none)

## Content conflicts resolved
- `memories.json` — Local id-superset (+`context-id-uuid-v5`); 0 content conflicts on shared ids. Union = local + merge memory `mem-20260720-context-sync-merge-v3`.
- `2026-07-20/context.json` — Remote more complete structure (tags/steps/attachments); local newer `updated_at`/title/summary (UUID v5). Merged: remote base + local scalars + union steps/tags/attachments.
- `2026-07-20/history.log` — Local strict line-superset (+2 UUID lines). Kept union (= local) + merge marker.
- `2026-07-20/result.md` — Different documents; concatenated remote (context-sync) + local (UUID section).
- `logs/cursor-cli-2026-07-20.log` — Local strict line-superset (+5 widget-enrichment lines at 22:13). Kept local.

## Identical on both sides
28 shared files unchanged (config, agent-profile, project-context, index/*, session artifacts, etc.).

## Notes
- Previous merge at 2026-07-20T14:59:17Z; local then added contextId UUID v5 work and widget-enrichment log lines before this sync.
- Task: temp-20260720-221322. Session: 1784560401468.