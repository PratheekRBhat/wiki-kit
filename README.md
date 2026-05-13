# wiki-kit

A general-purpose, LLM-maintained personal knowledge base. Clone it, point an agent at it, start ingesting.

Based on Andrej Karpathy's [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), refined through real use.

## What this is

An interlinked collection of markdown notes that compound as you work through material over time — articles, papers, blog posts, conference talks, and occasionally a book or lecture series. The wiki is not a summary of any single source; it's a running synthesis across all of them, organised around the *ideas* rather than the sources.

No book or course is designated as a required spine. The wiki is built bottom-up from whatever sources earn a slot.

All generation, linking, and upkeep is done by an LLM agent following the conventions in [`CLAUDE.md`](./CLAUDE.md). You own `raw/` (by adding sources) and the direction (by deciding what to ingest and what to ask). The agent owns `wiki/`.

## Layout

Three layers plus navigation.

```
wiki-kit/
├── CLAUDE.md          operating manual
├── README.md          this file
├── index.md           navigation catalog (agent-maintained)
├── log.md             append-only operations log
├── bases/             Obsidian Bases — 6 saved queries over the vault
│   ├── pending-ingest.base
│   ├── drafts.base
│   ├── mono-sourced.base
│   ├── stale-topics.base
│   ├── orphans.base
│   └── conversations.base
├── raw/               Bronze — immutable source material
│   ├── articles/
│   ├── papers/
│   ├── books/
│   ├── talks/
│   └── conversations/
├── utilities/         clipper templates, helper scripts, cheatsheet, teaching voice
└── wiki/              agent-owned knowledge
    ├── sources/       Silver — one reading-notes card per source
    ├── digests/       daily-digest output
    └── <topic>.md     Gold — flat, one file per distinct idea
```

`raw/` is subdivided by `source_type`. The frontmatter field and subdir always agree; skills walk `raw/` recursively.

Topic pages are tagged, not nested: `tags: [concept | language | framework | system | tool | pattern | practice | tradeoff | question]`. `index.md` groups by tag. Topic pages also carry an optional `domain:` list for cluster-based navigation via MOCs (Maps of Content).

## Setup

1. **Clone / copy** this repo into the location you want your wiki to live.
2. **Open it in Obsidian and Claude Code** — it's just markdown either way.
3. **Install the Obsidian skills plugin for Claude Code.** This gives the agent first-class access to the Obsidian CLI (search, backlinks, base queries, vault operations):
   ```
   /plugin marketplace add kepano/obsidian-skills
   /plugin install obsidian@obsidian-skills
   /reload-plugins
   ```
4. **Set up [Obsidian Web Clipper](https://obsidian.md/clipper)** if you plan to clip sources from the web. Templates are in `utilities/`; see [`utilities/README.md`](./utilities/README.md).
5. **Install `yt-dlp`** if you plan to ingest YouTube talks: `brew install yt-dlp` (or equivalent).
6. **Start ingesting.** Drop a source into `raw/<source_type>/` and tell the agent "ingest this."

## Skills

Ten skills cover the full workflow. Invoke via Claude Code or any Claude agent that has read `CLAUDE.md`.

| Skill | What it does |
|---|---|
| `wiki-ingest` | Ingest a source from `raw/` — confirms scope, uses CLI to check for similar existing pages, extends/creates topic pages and source card. |
| `reading-companion` | Read a book chapter-by-chapter; seeds a home card, tracks progress, runs discussion. |
| `save-conversation` | Save an LLM conversation to `raw/conversations/` with structured metadata (key_insight, codebase_context, related_topics). |
| `load-conversation` | Search and retrieve past conversations across sessions. Surfaces dangling followups. |
| `daily-digest` | Batch-ingest all pending `raw/` sources, then write a curated digest note. |
| `lint` | Audit for orphan pages, broken wikilinks, stale claims, missing frontmatter, index drift. |
| `topic-overview` | Full retrieval routine for "what do we know about X?" — reads page, MOC, sources, backlinks, synthesises. |
| `whats-stale` | Surface topic pages past freshness thresholds as an actionable refresh queue. |
| `inbound-links` | Find every wikilink pointing at a topic page, including alias-mediated, block-ref, and embed forms. |
| `seed-mocs` | Generate/refresh Maps of Content from `domain:` frontmatter across all topic pages. |

## Usage

**Standard workflow:**

1. A source lands in `raw/<source_type>/` (manually or via Obsidian Web Clipper).
2. Tell the agent to ingest it. `wiki-ingest` confirms scope, searches for existing similar pages via the Obsidian CLI, decides what to extend vs create, writes topic pages and the source card.
3. Ask questions against the wiki. The agent reads `index.md`, drills into topic pages, chases wikilinks.
4. As domain clusters form, run `seed-mocs` to generate Maps of Content for navigation.
5. Periodically run `lint` and `whats-stale` to keep the vault clean.

**Conversation lifecycle:** `save-conversation` captures a session to `raw/conversations/`. `load-conversation` retrieves it later — surfacing session detail, key insights, and dangling followups across sessions. `wiki-ingest` can then promote it into topic pages if the ideas are worth keeping.

Example prompts:

- "Ingest the article I just dropped in `raw/`."
- "Let's start *[book]*."
- "Compare X and Y based on what we have so far."
- "Lint the wiki."
- "What's stale?"
- "Deep dive on `kafka`."
- "What did we discuss about the auth middleware?"

## Obsidian setup

Open this folder as an Obsidian vault. Key features:

- **Bases** (core, v1.9+) — 6 `.base` files in `bases/` are pre-built saved queries. Enable the Bases plugin and they work out of the box.
- **Obsidian Web Clipper** — templates in `utilities/` clip sources directly into `raw/<source_type>/`.
- **Obsidian CLI** — first-class retrieval surface for the agent: search, backlinks, tag queries, base queries. See `utilities/obsidian-search-cheatsheet.md`.

Property types are declared in `.obsidian/types.json` for reliable Bases queries and graph filtering. `aliases:` on topic pages lets Obsidian resolve wikilink variants (`k8s` -> `kubernetes`). No separate glossary file.

## Specialising the wiki (optional)

Narrow it to a specific domain — AI/ML, data engineering, cooking, personal finance, whatever — by editing `CLAUDE.md`:

- **Purpose** — rewrite for your domain.
- **Owner baseline** — sharper "assume X, don't explain Y, do explain Z."
- **Scope** — hard boundaries if running multiple bounded wikis side-by-side.
- **Domain vocabulary** — define as clusters emerge. `seed-mocs` proposes MOC candidates when 3+ pages share a domain.
- **Tag vocabulary** — override default tags if your domain needs different categories.

See [`examples/`](./examples/) for concrete specialisations.

## Scale expectations

Comfortable range for the index-as-search strategy (no embeddings needed):

- ~40-150 source cards
- ~100-250 topic pages

Total: roughly 150-400 pages. Beyond that, split into multiple bounded wikis or introduce light retrieval.

## Credits

- [Andrej Karpathy's LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — the source pattern.
- [Obsidian Web Clipper](https://obsidian.md/clipper) — the capture side.
- [Obsidian Skills for Claude Code](https://github.com/kepano/obsidian-skills) — CLI, Bases, and markdown skills.
