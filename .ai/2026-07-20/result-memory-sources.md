# Memory tab empty while memories.json has data

## Cause
UI loaded only `.ai/agent-memory.json`. Diary lived in `.ai/memories.json`; sessions in `.ai/YYYY-MM-DD*/`.

## Fix
`AgentProfileService.loadMemory` merges:
1. `agent-memory.json` (editable)
2. `memories.json` (read-only in UI, tags `memories.json`)
3. session `context.json` / `result.md` summaries (read-only, tags `session`)

Save/delete only touch native `agent-memory.json` entries.
