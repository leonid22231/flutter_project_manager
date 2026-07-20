# Semantic index: why almost no notes/questions (Kiosk)

## What logs show

- Project: `C:\Work\EvoSoft\kiosk` (contextId `9d5a4717-…`)
- Inventory: **1061 paths, 51 batches**, phase `finalized`
- On disk now: **14 notes + 2 questions** — all from last batch `windows/sber_intergration/*` (same `updatedAt` as session end)
- Mid-run the agent read `file-notes.json` with ~**30** windows notes already stored — then context-sync finished and most notes disappeared

## Root causes

1. **Prompt path lost on Windows** (`CursorCliPromptDelivery` + `runInShell: true`)  
   Pointer is multiline (`…file:\n<path>`). Agent repeatedly: “no file path after the colon” (~26 times). Often recovers by searching `.ai/logs/cursor-prompt-*.md`; sometimes fails → batch yields no JSON.

2. **Notes parsed only from `result.answer`**  
   Large `{"notes":[…]}` appears in THINK (assistant segments). If final `result` is empty/short, `_parseNotesQuestions(result.answer)` merges **nothing** even when steps contain full JSON. Only ~17/51 batches even dumped JSON in logs.

3. **Context sync during indexing**  
   Sync for the same project ran mid-inventory (e.g. during assets / packages / windows). `replaceTree` rewrites whole `.ai` including `index/file-notes.json` and `open-questions.json` (only `index-session.json` is ignored in *diff*, not protected on replace). Timeline: sync “Push finished / Sync completed” immediately before last batch JSON → accumulated notes wiped; only last merge remains.

4. **UI during run shows 0 notes**  
   `onProgress` updates `session` only and keeps old `notes`/`questions` (usually empty until final `load()`). Easy to see “no notes” while indexing.

## Surviving artifacts

- 14 notes: mostly `ignored` Sber logs/binaries  
- 2 open questions: WinCLI `OPT*.R` / `F12X24.BIN`  
- Session incorrectly `finalized` despite open questions (likely race with sync / empty load at phase decision)

## Recommended fixes

1. Single-line prompt pointer with forward-slashed path; avoid shell-eating newlines  
2. Parse JSON from `answer` **and** progress steps / partial output  
3. Pause / skip context-sync while semantic index is running; never replace `index/*` from sync (or treat as local-only)  
4. Reload notes/questions in `onProgress` after each batch merge  
5. Log when answer has no parseable notes but steps do
