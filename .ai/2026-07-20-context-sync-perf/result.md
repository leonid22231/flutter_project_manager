# Context sync performance fix

## What changed

1. **Cursor kept for smart multi-context merge** — only when the same paths differ (`diff.changed`). Additive baseline first, then Cursor refines conflict paths.
2. **Asymmetric-only diffs** (files only on local or only on remote) → fast additive merge, no Cursor.
3. **Cheap git pull** — existing clone skips `ls-remote`; fetch + HEAD compare; pull only if behind.
4. **Cancel before push** — `shouldContinue` aborts write/push when project switched.
5. **Wider ignore** — history/progress logs, index-session, chat-export, backups, conflicts/.
6. **Throttle** — cooldown 5m, project-select debounce 3s; `_autoCursorSyncDone` only after success.

## Files

- `lib/services/context_sync_git_service.dart`
- `lib/services/context_sync_service.dart`
- `lib/services/context_ai_cursor_merge_service.dart`
- `lib/state/project_manager_state.dart`
