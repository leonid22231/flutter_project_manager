# Context sync via GitHub — result

## What was added

- `Project.contextId` — editable sync folder key (internal `id` unchanged)
- App setting **Repository for saving** (GitHub URL) + enable + interval
- Overview section: view/edit/generate ID, sync now, status
- `ContextSyncGitService` — clone/pull/commit/push via system `git`
- Merge: Cursor CLI agent mode if enabled, else additive JSON/text merge
- Auto sync on project open, `.ai` file watch (3s debounce), periodic timer

## Remote layout

```
<github-repo>/<contextId>/...contents of project .ai...
```

## How to use

1. Settings → enable Context sync → paste GitHub repo URL (SSH/HTTPS with local git credentials)
2. Test repository access
3. Open a project → Overview → set shared ID if needed → Sync now
4. On another device, add the same project path and set the same context ID

## Tests

`test/context_sync_test.dart` — ID utils, migration, additive merge (9 tests passed)
