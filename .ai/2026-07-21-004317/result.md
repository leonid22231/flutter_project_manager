# Fixes applied

## Semantic index retention
- Single-line prompt pointer with forward-slash paths (`cursor_cli_prompt_delivery.dart`)
- Parse notes/questions from `answer`, then agent steps, then combined (`project_semantic_index_service.dart`)
- Log empty / recovered parses per batch
- Pause auto context-sync during index; abort in-flight sync; preserve ignored `index/**` across `replaceTree`
- UI reloads notes/questions after each batch; throttle live step setState

## Red screen (logs)
- Assertion: `framework.dart` MediaQuery descendant + cascade of `mouse_tracker !\_debugDuringDeviceUpdate`
- Cause: every THINK log → notifyListeners → LogConsoleOverlay setState during mouse updates while indexing
- Fix: throttle AppLogService notifies (120ms); defer overlay setState to post-frame

## Files
- lib/services/analysis/cursor_cli_prompt_delivery.dart
- lib/services/project_semantic_index_service.dart
- lib/services/context_sync_service.dart
- lib/state/project_manager_state.dart
- lib/ui/views/agent_view.dart
- lib/services/app_log_service.dart
- lib/ui/widgets/log_console_overlay.dart
- lib/app.dart
