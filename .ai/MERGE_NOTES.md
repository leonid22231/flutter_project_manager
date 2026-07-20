# MERGE_NOTES

Merged at: 2026-07-20T16:20:53Z
Strategy: additive union (JSON by id/key, text by unique lines; prefer local LF on newline-only conflicts; chronological unique-line union for disjoint logs).

## Local-only files kept
- `2026-07-11\history.log`
- `logs\build-history-2026-07-11.log`
- `logs\cursor-cli-2026-07-11.log`
- `logs\cursor-prompt-1784560714588.md`
- `logs\cursor-prompt-1784560784406.md`

## Remote-only files kept
- `2026-07-20\history.log`
- `logs\build-history-2026-07-20.log`

## Content conflicts resolved
- `logs/cursor-cli-2026-07-20.log` — Disjoint timelines (local 11 lines @23:08–23:13; remote 94 lines @20:14–22:13; 0 overlap). Chronological unique-line union (105 lines).
- `logs/flutter_debug.log` — Disjoint (local 116 Jul-11 lines; remote 2 Jul-20 lines; 0 overlap). Chronological unique-line union (118 lines).
- `memories.json` — Text-identical after newline normalize; appended merge memory `mem-20260720-context-sync-merge-v4`.

## Newline-only (kept local LF)
- `2026-07-11\context.json`
- `2026-07-11\result-builds-rework.md`
- `2026-07-11\result-project-analysis.md`
- `2026-07-11\result-widgets-analysis.md`
- `2026-07-11\result.md`
- `config.json`
- `temp-20260711-agent-learning\result.md`

## Identical on both sides
22 shared files unchanged (byte-identical including line endings).

## Notes
- Previous merge at 2026-07-20T15:13:30Z (v3); this sync mainly reunites device-local logs and session artifacts that diverged after v3.
- Task: temp-20260720-232053-context-sync. Session: 1784564394216.