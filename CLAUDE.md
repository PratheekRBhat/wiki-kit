# CLAUDE.md — Wiki

Operating manual for any LLM agent working in this repo. Based on Andrej Karpathy's [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), refined through real use.

Read this file completely before taking any action.

---

## Purpose

This is a **personal knowledge base**. Sources are a mix of articles, papers, talks, books, course material, docs, and the occasional saved conversation. The wiki is not a summary of any single source. It is a running synthesis organised around ideas.

The owner reads widely and wants the ideas to compound. Every ingest extends what is already here before it creates anything new. Topic pages are where synthesis lives. Source cards are reading notes. The wiki should end up more useful than the pile of sources that fed it.

**Foundational spine.** There is no designated spine book or course. The wiki is built bottom-up from whatever sources the owner keeps. If a book earns a place, it enters through the same source-card and topic-page flow as everything else.

### Owner baseline

The default assumption is: explain clearly, do not assume deep specialist knowledge in every domain, and do not over-explain basics a technically literate reader already owns.

Replace this section with a sharper baseline if needed. The agent should honor whatever is written here.

### Scope

The default kit is intentionally broad. Narrow it here if the wiki is meant to cover a specific domain only.

If you run multiple bounded wikis side by side, document the sibling vaults here and state the routing rule. If a source sits on the boundary, flag it and ask before ingesting.

---

## Vault conventions

This vault is opened in Obsidian.

- **Filenames are kebab-case slugs**, one note per file. Slugs are stable under reorganisation — wikilinks stay valid.
- **Tags drive `index.md` grouping.** `tags: [concept | language | framework | system | tool | pattern | practice | tradeoff | question]` on topic pages, `tags: [source]` on source cards. Tags stay lowercase.
- **Frontmatter wikilinks** use the quoted block-list form (`related:\n  - "[[page-a]]"`) — easier to scan and edit than inline.
- **`AGENTS.md` is a symlink to this file** (if present). Update by editing `CLAUDE.md`; the symlink does the rest.

## The three layers

The whole wiki collapses to **three layers plus a navigation file**. That's the entire mental model. Keep it that way.

```
wiki/
├── CLAUDE.md         ← this file
├── README.md         ← human-facing overview
├── index.md          ← navigation catalog (agent maintains)
├── log.md            ← append-only operations log
├── bases/            ← Obsidian Bases (.base files) — saved queries over the vault
├── raw/              ← BRONZE — immutable source material
│   ├── articles/     ← source_type: article
│   ├── papers/       ← source_type: paper
│   ├── books/        ← source_type: book + chapter
│   ├── talks/        ← source_type: talk
│   └── conversations/← source_type: conversation
├── utilities/        ← clipper templates + helper scripts
└── wiki/             ← agent-owned knowledge
    ├── sources/      ← SILVER — one card per source (reading notes)
    ├── digests/      ← daily-digest output — curated highlights per run date
    └── <topic>.md    ← GOLD — one flat file per idea, concept, system, tool, pattern
```

**`raw/` is sub-divided by source type.** Source files live in `raw/<source_type>/` subdirs. The `source_type:` frontmatter field is preserved on every file as a query property; subdir and frontmatter always agree. Chapters live in `raw/books/` alongside their parent book card. Skills walk `raw/` recursively.

**Bronze — `raw/`.** Immutable source of truth. The *only* allowed mutation is flipping `ingested: false → true` in frontmatter.

**Silver — `wiki/sources/<slug>.md`.** One card per external source. Reading notes: TL;DR, key claims, what was novel, and which topic pages it fed. A stable citation target, not a summary page.

**Gold — `wiki/<topic>.md`.** Flat. One file per distinct idea, language, framework, system, tool, pattern, or tradeoff. No subdirectories.

**Navigation — `index.md`.** Human-readable table of contents, grouped by tags for scanning.

---

## The three rules

### 1. Extend over create

When a new source touches an existing topic, **extend the topic page first**. Only create a new topic page when the source introduces a genuinely distinct idea that deserves its own durable home.

### 2. Flat topic layer

Never create subdirectories under `wiki/` except `sources/` and `digests/`. Everything else is a flat `wiki/<slug>.md`. The taxonomy lives in tags and `index.md` grouping. Flat slugs are stable under reorganisation; directory moves break wikilinks.

### 3. Source cards are reading notes, not summaries

A source card exists to:
- Let the owner return to a specific source and remember what was in it in 60 seconds.
- Be a stable citation target (`per [[sources/article-foo]]`) from topic pages.
- Capture per-source reflections — novel angles, quotable lines, contradictions with earlier sources.

Synthesis lives on topic pages, not on source cards.

---

## Page shapes

### Source card — `wiki/sources/<slug>.md`

Slug format: `article-<short-title>`, `paper-<short-title>`, `talk-<short-title>`, `book-<short-title>`, `ch-<NN>-<book-slug>` for book chapters.

```yaml
---
source_type: article | paper | talk | book | chapter | conversation
title: Human-readable title
author: "Author Name(s)"
url: <original url, if applicable>
published: YYYY-MM-DD
clipped: YYYY-MM-DD
tags: [source]
contributed_to:
  - "[[topic-a]]"
  - "[[topic-b]]"
updated: YYYY-MM-DD
---

# Human-readable title
```

Body shape (TL;DR, key claims, what's novel, quotes, where it contributed) is documented in the `wiki-ingest` skill.

### Book / series home card — `wiki/sources/book-<slug>.md`

Book cards are source cards with progress tracking — not spines, not privileged outlines. Managed by the `reading-companion` skill, which documents the full frontmatter schema and body shape. Status pipeline: `unread` → `in-progress` → `read` → `ingested`.

### Topic page — `wiki/<topic>.md`

```yaml
---
title: Human-readable title
aliases:
  - <variant>
tags: [concept | language | framework | system | tool | pattern | practice | tradeoff | question, <extra-tags>]
domain:
  - primary-domain
  - secondary-domain
sources:
  - article-foo
  - book-bar
related:
  - "[[other-topic]]"
status: draft | stable | stale
updated: YYYY-MM-DD
---

# Human-readable title
```

`tags:` is the routing layer — drives `index.md` grouping, Obsidian Graph view colour-coding, and tag-based search.

`domain:` is the cluster axis — determines which MOC(s) this page joins and how Bases pivot the knowledge graph. Multi-valued (list); always use block-list form even for a single value. Primary domain first.

**Define your domain vocabulary as your wiki grows.** Start adding `domain:` when topic pages naturally cluster around themes. The `seed-mocs` skill will propose MOC candidates once 3+ topic pages share a domain value. Don't pre-define a vocabulary before you have content — let the content reveal the clusters.

Body shape depends on topic type, but the teaching arc is consistent (see `utilities/teaching-voice.md`):

- **Hook** — 1–3 sentences. Why this idea matters, or what problem it solves.
- **Core** — the actual explanation. Mechanism, variants, tradeoffs.
- **Grounding** — at least one concrete example.
- **Connections** — links to `[[related]]` topics, with a sentence each.
- **Open questions** — optional, promote to `[question]`-tagged pages if they earn it.

For pages tagged `[tradeoff]`: **The tension** → **Option A** → **Option B** → **Decision heuristics** → **Real-world examples**.

### MOC page — `wiki/<domain>-moc.md`

One MOC per domain cluster (`streaming-moc.md`, `observability-moc.md`, etc.). The middle navigation layer between `index.md` (vault-wide) and topic pages (single idea). Managed by the `seed-mocs` skill, which documents the full schema and population rules. MOCs get their own `domain:` field, and pages with multi-valued domain appear in each relevant MOC.

### Frontmatter conventions

- **Wikilinks in frontmatter** use the quoted block-list form.
- **`sources:` is a flat inline list of source slugs.**
- **`tags:` doubles as the `index.md` group.**
- **`updated: YYYY-MM-DD`** always.

### Aliases convention

`aliases:` on a topic page lets Obsidian resolve wikilinks using a variant slug. Always use block-list form, even for a single alias.

- **Canonical = the common engineering form.** `kafka` canonical, `apache-kafka` alias. `postgres` canonical, `postgresql` alias.
- **Pluralization.** Add singular/plural pairs when the wiki uses both.
- **Reactive, not proactive.** Add an alias when the case shows up — in writing, querying, or a broken `[[link]]`.
- Obsidian's wikilink resolution is already case-insensitive; aliases handle slug variants, not casing.

### Linking

- Obsidian-style wikilinks. `[[rust]]` not `[[rust.md]]`.
- **Link on first mention.** First time `[[ownership]]` appears on a page → wikilink. Subsequent mentions → plain text.
- Source cards get cited inline as `[[sources/article-foo]]` from topic pages.
- **MOCs are a navigation surface** alongside topic pages and source cards.

### Embeds and block references

**Embeds (`![[topic#section]]`)** render the target section's content live inside the embedding note. Use deliberately: daily digests pulling a live section, MOCs embedding hook paragraphs, cross-page synthesis. The trade: embeds couple to the target heading — renaming it silently breaks the embed.

**Block references (`[[topic#^block-id]]`)** give stable, claim-level citation. Drop a `^block-id` at the end of a paragraph to make it citable. Source cards cite specific claims as `[[topic#^block-id]]` rather than just the page slug.

**Discipline:** when ingesting a source that seeds a specific claim, drop a `^block-id` on that claim and cite it from the source card. Coarse "contributed to `[[topic]]`" still works; block refs are the upgrade when claim-level provenance matters.

---

## Operations

Each operation has a dedicated skill with the full procedure.

| Operation | Trigger | Skill |
|---|---|---|
| Ingest a source | "ingest this" | `wiki-ingest` |
| Read a book | "let's read [book]" | `reading-companion` |
| Save a conversation | "save this conversation" | `save-conversation` |
| Load a conversation | "what did we discuss about X?" | `load-conversation` |
| Daily digest | "run the digest" | `daily-digest` |
| Lint | "lint the wiki" | `lint` |
| Topic overview | "tell me about `<slug>`" | `topic-overview` |
| What's stale | "what's stale" | `whats-stale` |
| Inbound links | "backlinks `<slug>`" | `inbound-links` |
| Seed MOCs | "seed mocs" | `seed-mocs` |

### Query (no skill — inline)

Trigger: the owner asks a question.

1. Read `index.md` first to locate relevant topic pages.
2. Read the linked topic pages; chase wikilinks.
3. If the answer needs synthesis across multiple pages, say so and cite inline.
4. If the answer is valuable enough to preserve, ask the owner if it should be filed as a new topic page or extend an existing one.

---

## Teaching voice

**This is load-bearing.** Re-read `utilities/teaching-voice.md` before writing any topic page. That file has the full voice guide with worked examples.

Short reminder: hook before definition, motivate every claim with stakes, trace the mechanism, ground in a real system, earn the tradeoff, even-handed on tribal debates. Practitioner voice — not professor, not bootcamp, not paper abstract.

---

## Logging conventions

Every operation appends to `log.md`:

```
## [YYYY-MM-DD] <op> | <subject>

- Touched: pages created / updated
- Notes: 1–3 lines. What the source was, scope decision, contradictions, followups.
```

`<op>` is one of: `ingest`, `read`, `discussed`, `query`, `query-filed`, `lint`, `digest`, `refactor`, `meta`.

---

## What to ask before doing

- Before **creating** a new topic page rather than extending — if the call isn't obvious, default is extend.
- Before **large refactors** (renaming slugs, merging pages, splitting a page in two).
- Before ingesting a source whose topic is borderline against stated scope boundaries.
- When a new source **contradicts** an established topic page — flag, don't silently overwrite.

## What to just do

- Extend topic pages during an ingest (per approved slate).
- Add cross-references between topics.
- Update `index.md` and `log.md`.
- Flag open questions by creating `[question]`-tagged pages.
- Propose promoting a recurring term to its own topic page when it's earned one.

---

## Evolving this file

`CLAUDE.md` is a living document. When a convention emerges organically during use, codify it here. When something stops being useful, remove it. Changes to this file get a `meta`-op entry in `log.md`.
