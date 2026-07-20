# Adaptive / resizable UI fix

## Log root cause
`RenderFlex overflowed by 26px` at `agent_side_panel.dart:348` — Save + Improve Profile buttons in a non-wrapping `Row` inside ~276px side panel.

## Fixes
- `AdaptiveActionBar` (Wrap + dense button styles) for side panel actions
- `ResizableBlockFrame` — drag handle to resize mermaid/code block height
- Mermaid SVG clipped + fitted inside resizable viewport with InteractiveViewer
- Markdown chat: `fitContent: false` + maxWidth constraint
- Agent side panel width drag-resize (220–560px)
- Markdown previews capped height with scroll
