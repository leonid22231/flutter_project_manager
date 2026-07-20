# Agent self-learning & context-first Q&A

## Implemented

### Auto context refresh (every Q&A turn)
1. Before question: `AgentContextOrchestrator.refreshFullContext()` rebuilds `.ai/project-context.json` with project scan + agent profile/memory/knowledge.
2. After answer: `learnFromInteraction()` extracts facts via Cursor CLI JSON agent → merges into `agent-memory.json` + `project-knowledge.json` → refreshes context again.

### Context-first answering
- `ProjectQaAgentPrompt` includes CONTEXT-FIRST policy, accumulated knowledge, memory, and recursive methodology.
- Agent is instructed to answer from `.ai/project-context.json` and stored knowledge before reading `lib/`.

### Agent tab (editable self)
Sections: Identity, Skills, Self-analysis, Instructions, Memory, Knowledge, `.ai` folder, Prompt preview.
- **Analyze myself** button runs `runSelfAnalysis()` and updates profile fields.
- Knowledge architecture/workflows/insights editable; memory add/delete.

### Files
- `lib/services/agent_context_orchestrator.dart`
- `lib/services/agent_profile_service.dart`
- `lib/services/analysis/agent_learning_prompt.dart`
- `lib/services/analysis/cursor_cli_project_qa_service.dart`
- `lib/services/analysis/project_qa_agent_prompt.dart`
- `lib/services/project_context_service.dart`
- `lib/ui/views/agent_view.dart`
- `lib/models/agent_profile.dart`, `project_knowledge.dart`

## How to verify
1. Enable Cursor CLI in settings.
2. Open Analysis → ask a project question → check `.ai/project-knowledge.json` and `agent-memory.json` grow.
3. Ask a follow-up → reasoning should show fewer file reads.
4. Agent tab → **Analyze myself** → edit skills/memory/knowledge → Save.
