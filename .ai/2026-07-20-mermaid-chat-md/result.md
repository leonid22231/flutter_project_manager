# Mermaid + chat markdown

## Added
- `MermaidRenderService` → Kroki `POST /mermaid/svg` with dark theme, in-memory cache
- `MermaidDiagramView` — SVG, zoom, source/copy/retry
- `MarkdownContent` `pre` builder — mermaid diagrams + highlighted code blocks with language header
- Chat bubbles wider (up to 920px), better typography/spacing

## Note
Diagram render: primary `mermaid.ink`, fallback `kroki.io`. Needs network.
