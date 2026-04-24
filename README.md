# wiki-kit

A general-purpose, LLM-maintained personal knowledge base. Clone it, point an agent at it, start ingesting.

Based on Andrej Karpathy's [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), refined through real use.

## What this is

An interlinked collection of markdown notes that compound as you work through material over time — articles, papers, blog posts, conference talks, and occasionally a book or lecture series. The wiki is not a summary of any single source; it's a running synthesis across all of them, organised around the *ideas* rather than the sources.

No book or course is designated as a required spine. The wiki is built bottom-up from whatever sources earn a slot.

All generation, linking, and upkeep is done by an LLM agent following the conventions in [`CLAUDE.md`](./CLAUDE.md). You own `raw/` (by adding sources) and the direction (by deciding what to ingest and what to ask). The agent owns `wiki/`.

## Layout

Three layers plus navigation. That's it.

- `raw/` — **Bronze**. Immutable source material.
  - `book/`, `articles/`, `papers/`, `talks/`
- `wiki/sources/` — **Silver**. One reading-notes card per external source.
- `wiki/<topic>.md` — **Gold**. Flat. One file per distinct idea, technique, model, or tradeoff. No subdirectories.
- `index.md` — navigation catalog (agent-maintained).
- `log.md` — chronological operations log.
- `wiki/glossary.md` — aliases / alternate names pointing at canonical topic slugs.
- `CLAUDE.md` — the agent's operating manual (the load-bearing file).

Topic pages are categorised by **tags**, not directories — `tags: [concept]`, `tags: [technique]`, `tags: [architecture]`, `tags: [model]`, `tags: [system]`, `tags: [tradeoff]`, `tags: [question]`. `index.md` groups by tag for scanning.

## Setup

This is a working wiki, not an install script.

1. **Clone / copy** this repo into the location you want your wiki to live.
2. **Open it in Obsidian, Cursor, or Claude Code** — it's just markdown either way. The pre-configured `.obsidian/` folder gives you graph-view color-coding by tag and sensible hotkeys if you use Obsidian.
3. **Set up [Obsidian Web Clipper](https://obsidian.md/clipper)** if you plan to clip sources from the web. Templates are in `utilities/`; see [`utilities/README.md`](./utilities/README.md).
4. **Install `yt-dlp`** if you plan to ingest YouTube talks: `brew install yt-dlp` (or equivalent).
5. **Start ingesting.** Drop a source into `raw/` and tell the agent "ingest this."

That's it. No placeholders to fill, no script to run.

## Usage

- **Add sources.** Drop them into `raw/articles/`, `raw/papers/`, `raw/talks/`, or `raw/book/`. The clipper templates handle the web-to-file step for articles / arXiv / YouTube; `utilities/prepare.sh` backfills PDFs and transcripts.
- **Ingest.** Tell the agent to ingest a specific file, a folder, or "all pending". The agent reads, decides what to extend vs create, writes the topic pages and source card, updates `index.md`, appends to `log.md`.
- **Query.** Ask questions against the wiki. The agent reads `index.md` first, then drills into the relevant topic pages.
- **Lint.** Periodically ask the agent to lint — surfaces orphans, contradictions, stale claims, candidates for promotion.

Example prompts:

- "Ingest the article I just dropped in `raw/articles/`."
- "Ingest the paper I dropped in `raw/papers/`."
- "Let's start [book]." *(triggers the `reading-companion` skill for multi-chapter reads)*
- "Compare X and Y based on what we have so far."
- "Lint the wiki."

## What comes pre-loaded

- **`CLAUDE.md`** — the operating manual. General-purpose; works out of the box. Two optional sections near the top (*Owner baseline*, *Scope*) are where you'd sharpen the agent's defaults if you want to.
- **`.claude/skills/wiki-ingest/`** — the ingest skill. Heavy on teaching voice.
- **`.claude/skills/reading-companion/`** — multi-chapter book / lecture-series companion. Seeds a book home card, supports read-along discussion, hands off to `wiki-ingest` per chapter.
- **`utilities/`** — Obsidian Web Clipper templates for articles, arXiv papers, and YouTube talks, plus `prepare.sh` (post-clip backfill) and `youtube_transcript.sh` (caption fetcher).
- **`.obsidian/`** — pre-configured vault: graph-view colors per tag, hotkeys, sensible defaults.
- **`examples/`** — reference specialisations showing how `CLAUDE.md` can be narrowed for specific domains. Optional reading; the wiki works as-is without them.

## Specialising the wiki (optional)

If you want to narrow the wiki to a specific domain — AI/ML, data engineering, cooking, personal finance, whatever — the main things to edit in `CLAUDE.md`:

- **Purpose** — rewrite the opening paragraph to describe your specific domain.
- **Owner baseline** — replace the default with a sharper "assume X, don't explain Y, do explain Z" paragraph.
- **Scope** — if you want hard boundaries, spell them out. If you're running multiple bounded wikis side-by-side, describe the sibling wikis here so the agent can route borderline sources.
- **Tag vocabulary** — override the default tags if your domain wants different categories. Update `index.md` groups and `.obsidian/graph.json` color groups to match.
- **Source types** — if your domain has canonical inputs beyond `article | paper | talk | book`, add new types: new `raw/` subdir, new clipper template in `utilities/`, add to `CLAUDE.md`'s frontmatter schema.

See [`examples/`](./examples/) for concrete specialisations across a few sample domains.

## Scale expectations

Comfortable range for the index-as-search strategy (no embeddings needed):

- ~40–150 source cards
- ~100–250 topic pages

Total: roughly 150–400 pages. Beyond that you'll want to think about splitting into multiple bounded wikis, or introducing light retrieval — but most personal wikis never get there.

## Credits

- [Andrej Karpathy's LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — the source pattern.
- [Obsidian Web Clipper](https://obsidian.md/clipper) — the capture side of the pipeline.
