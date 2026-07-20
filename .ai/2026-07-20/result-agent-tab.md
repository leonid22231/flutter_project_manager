# Agent tab rework — result

## Done

- Requirements moved to `.ai/2026-07-20/agent-tab-requirements.md`; `temp_task.txt` deleted
- **Agent** tab = Cursor-like chat + context side panel
- **Analysis** = project-context index only + link to Agent
- Modes: ask / plan / agent + read/write scope in toolbar
- Learning candidates → `.ai/learning-pending.json` with confirm/discard
- Chat history → `.ai/chat-history.jsonl` (+ export markdown)
- Index meta → `.ai/index-meta.json` with freshness / included sources
- Side panel: Profile, Memory/Knowledge, Learning, Index+Sync, `.ai`, Advanced prompt

## Key files

- `lib/ui/views/agent_view.dart`
- `lib/ui/views/agent_side_panel.dart`
- `lib/ui/views/analysis_view.dart`
- `lib/services/agent_chat_history_service.dart`
- `lib/services/agent_learning_pending_service.dart`
- `lib/services/agent_index_meta_service.dart`
- `lib/services/agent_context_orchestrator.dart` (pending learning)
- `lib/services/analysis/cursor_cli_project_qa_service.dart` (mode + scopes)
