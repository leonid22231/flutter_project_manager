# Index button no-op + "command line is too long"

## Causes
1. Agent chat toolbar used `Spacer` inside `Wrap` → Flutter ParentDataWidget exception; toolbar/actions unreliable.
2. Index could leave `_isIndexing == true` on thrown errors → further clicks no-op.
3. Cursor CLI passed the full prompt as argv with `runInShell: true` → Windows cmd ~8191 limit → "The command line is too long."

## Fixes
- Replace toolbar `Spacer` with `SizedBox`; Index empty-state chip calls real `onIndex`.
- `_indexProject`: try/finally, snackbar success/error, reload side data.
- `CursorCliPromptDelivery`: long prompts written to `.ai/logs/cursor-prompt-*.md`, short pointer in argv (QA, stream runner, learning JSON, widget analysis).
