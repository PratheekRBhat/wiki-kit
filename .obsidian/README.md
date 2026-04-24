# .obsidian/

Pre-configured Obsidian vault. Open this repo as an Obsidian vault and these settings take effect on first launch.

## What's pre-configured

- **`app.json`** — core editor settings: live preview mode, 2-space tabs, `shortest` wikilink format, `raw/attachments/` as the attachment folder so image pastes don't clutter `wiki/`.
- **`appearance.json`** — defaults. Override with whatever theme you like.
- **`graph.json`** — graph view with color-coded nodes by tag. The colour groups match the default tag vocabulary in `CLAUDE.md`:
  - `concept` → blue
  - `technique` → green
  - `architecture` → purple
  - `model` → orange
  - `system` → red
  - `tradeoff` → yellow
  - `question` → pink
  - `source` → grey
- **`hotkeys.json`** — `Cmd+G` opens the graph view; `Cmd+Alt+←/→` navigate history.

## Customising

If you override the tag vocabulary in `CLAUDE.md`, also update the `colorGroups` in `graph.json` to match — otherwise new tags will show as default-coloured nodes in the graph.

Workspace state (pane layout, last-open files) is deliberately `.gitignore`d so multiple machines don't fight over it. The useful pre-config (settings, hotkeys, graph) is version-controlled.
