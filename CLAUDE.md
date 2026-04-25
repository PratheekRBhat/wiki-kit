# CLAUDE.md — Wiki

Operating manual for any LLM agent working in this repo. Based on Andrej Karpathy's [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), simplified after real use.

**Read this file completely before taking any action.**

---

## Purpose

This is a **personal knowledge base**. Sources are a mix of articles, papers, talks, books, conference recordings, and whatever else earns a slot. The wiki is not a summary of any single source; it's a running synthesis across all of them, organised around the *ideas* rather than the sources.

The owner reads widely and wants the ideas to compound. Every ingest extends what's already here before it creates anything new. Topic pages are where the synthesis lives; source cards are reading notes; the wiki is greater than the sum of its sources.

**Foundational spine.** There's no designated foundational text. The wiki is built bottom-up from whatever sources the owner ingests. If a spine book or course ever earns the slot, it gets added to `raw/book/` and a note lands in this section.

### Owner baseline (optional)

The sharper the agent knows what to assume vs. explain, the less it wastes pages on things the owner already knows. The default baseline is: **explain things clearly, don't assume deep specialist knowledge in any domain, don't over-explain basics a literate technical reader already owns.**

If the owner wants to tighten this — e.g. "I'm a working SWE with 10 years in distributed systems; don't explain MVCC to me" — replace this paragraph with a sharper description. The agent honours whatever is written here.

### Scope (optional)

The default scope is unbounded: any domain the owner is learning. If the owner wants to narrow scope — e.g. "this wiki is for AI/ML only; route data-engineering sources to a sibling wiki" — describe the boundary here. When a source sits on the edge of the scope, the agent flags it and asks.

---

## The three layers

The whole wiki collapses to **three layers plus a navigation file**. That's the entire mental model. Keep it that way.

```
wiki/
├── CLAUDE.md         ← this file (operating manual)
├── README.md         ← human-facing overview
├── index.md          ← navigation catalog (agent maintains)
├── log.md            ← append-only operations log
├── raw/              ← BRONZE — immutable source material
│   ├── book/
│   ├── articles/
│   ├── papers/
│   └── talks/
├── utilities/        ← clipper templates + helper scripts
└── wiki/             ← agent-owned knowledge
    ├── sources/      ← SILVER — one card per source (reading notes)
    ├── digests/      ← daily-digest output — curated highlights per run date
    ├── glossary.md   ← aliases / alternate names redirecting to canonical slugs
    └── <topic>.md    ← GOLD — one flat file per idea, concept, technique
```

**Bronze — `raw/`.** Immutable source of truth. The *only* allowed mutation is flipping `ingested: false → true` in a raw file's frontmatter.

**Silver — `wiki/sources/<slug>.md`.** One card per external source. Reading notes for that specific source: TL;DR, key claims, what's novel vs the wiki's current state, a quote or two worth keeping, and the list of topic pages it fed into. A stable citation target, not a summary page.

**Gold — `wiki/<topic>.md`.** Flat. One file per distinct idea, technique, object, or tradeoff. Named with a short, durable slug. **No subdirectories.** If the owner types a term and it has its own page, the agent should find it in one step.

**Navigation — `index.md`.** The human-readable table of contents. Grouped for readability, but those groups are *tags for navigation*, not directories. A topic page with `tags: [technique]` shows up under Techniques in `index.md` and lives at `wiki/<slug>.md`.

**Glossary — `wiki/glossary.md`.** A lightweight redirect table only. Alternate names, abbreviations, and common misspellings that should resolve to a canonical topic page. Not a definitions page — definitions live on topic pages.

---

## The three rules

### 1. Extend over create

When a new source touches an existing topic, **extend the topic page first**. Only create a new topic page when the source introduces a genuinely distinct idea that deserves its own durable home.

Rule of thumb:

- Three sources on caching → one `caching.md` hub plus separate pages for the *distinct ideas* they each highlight (`lru-eviction.md`, `write-through-vs-write-back.md`, `cache-invalidation.md`). Not three "source-about-caching" pages.
- A new source that reframes something already covered → extend the existing section with the new framing, add the source to `sources:` frontmatter, cite it inline (`per [[sources/paper-foo]]`). Don't clone the page.
- A new source that introduces a term the wiki has never seen → create the new topic page.

### 2. Flat topic layer

Never create subdirectories under `wiki/` except the two explicit exceptions: `sources/` (source cards) and `digests/` (daily-digest output). Everything else is a flat `wiki/<slug>.md`. The taxonomy lives in tags and in `index.md` grouping. Flat slugs are stable under reorganisation; directory moves break wikilinks.

Tag vocabulary:

- `[concept]` — an idea or mental model.
- `[technique]` — a method, procedure, or approach.
- `[architecture]` — a structural pattern or system design.
- `[model]` — a specific named thing (a framework, a product, a recipe, a workflow, a work of reference).
- `[system]` — a larger assembled whole (a platform, a pipeline, an organisation).
- `[tradeoff]` — a tension between two or more valid options.
- `[question]` — an open problem without a settled answer.
- `[source]` — reserved for source cards.

If a slug collides (two meanings of the same term), disambiguate the *less common* one with a suffix.

### 3. Source cards are reading notes, not summaries

A source card exists to:

- Let the owner return to a specific source and remember what was in it in 60 seconds.
- Be a stable citation target (`per [[sources/paper-foo]]`) from topic pages.
- Capture per-source reflections that don't belong on a synthesised topic page — novel angles, quotable lines, contradictions with earlier sources, claims that haven't aged well.

A source card is **not** a full rewrite of the source, and **not** the place where synthesis lives. Synthesis lives on topic pages.

---

## Page shapes

### Source card — `wiki/sources/<slug>.md`

Slug format: `article-<short-title>`, `paper-<short-title>`, `talk-<short-title>`, `book-<short-title>`, `ch-<NN>-<book-slug>` for book chapters. For video lectures, `talk-<speaker>-<short-title>` works cleanly.

```yaml
---
source_type: article | paper | talk | book | chapter
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
```

Body:

1. **TL;DR** — 2–3 sentences. What the source is arguing or teaching, not what it mentions.
2. **Key claims** — 3–7 numbered claims, as tight as possible.
3. **What's novel vs prior wiki state** — which topic pages this seeded or extended, and in what way. This is the paper-trail for the "extend over create" rule.
4. **Quote worth keeping** — 0–3 short, sharp quotes. Optional but welcome.
5. **Where it contributed** — bullet list mirroring `contributed_to`, with a 3–10 word note per page.

### Book / series home card — `wiki/sources/book-<slug>.md`

Used for multi-chapter / multi-episode long-form sources (books, lecture series, structured courses). Managed by the `reading-companion` skill; the body shape (Thesis, Reading plan, Progress, Running connections) is documented there. Frontmatter:

```yaml
---
source_type: book
title: Book or Series Title
author: "Author Name(s)"
publisher: "Publisher"
published: YYYY
isbn: "ISBN if book"
url: <url if series or book home page>
tags: [source, book]
chapters:
  - { n: 1, slug: "<chapter-slug>",  status: unread }
  - { n: 2, slug: "<chapter-slug>",  status: unread }
  # ...
current: null
started: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

Status values: `unread` → `in-progress` → `read` → `ingested`.

Per-chapter source cards use `source_type: chapter` and follow the standard source card body shape above.

### Topic page — `wiki/<topic>.md`

```yaml
---
title: Human-readable title
tags: [concept | technique | architecture | model | system | tradeoff | question, <extra-tags>]
sources:
  - paper-foo
  - article-bar
  - talk-baz
related:
  - "[[other-topic]]"
status: draft | stable | stale
updated: YYYY-MM-DD
---
```

Body shape depends on topic type, but the teaching arc is consistent (see [Teaching voice](#teaching-voice) below):

- **Hook** — 1–3 sentences. Why this idea matters, or what problem it solves. Concrete.
- **Core** — the actual explanation. Mechanism, math or detail when it earns its place, variants. Always ground in a real thing.
- **Grounding** — at least one concrete example (a specific system, a specific workflow, a specific failure mode). No hand-waving.
- **Connections** — links to `[[related]]` topics, with a sentence each explaining the connection.
- **Open questions** — optional, promote to their own `[question]`-tagged page if they earn it.

For pages tagged `[tradeoff]`, the body is structured around the tension: **The tension** → **Option A** → **Option B** → **Decision heuristics** → **Real-world examples**.

For pages tagged `[question]`, the body is short: **Question** → **Context** → **Current state**.

### Frontmatter conventions

- **Wikilinks in frontmatter use the quoted block-list form.** `related: [[page]]` is Obsidian-tolerant but not YAML-strict. Use:

  ```yaml
  related:
    - "[[page-a]]"
    - "[[page-b]]"
  ```

- **`sources:` is a flat inline list of source slugs** (e.g. `paper-foo`, `article-bar`, `ch-02-book-slug`). The slugs match the filenames under `wiki/sources/`.
- **`tags:` doubles as the `index.md` group.**
- **`updated: YYYY-MM-DD`** always.

### Linking

- Obsidian-style wikilinks. `[[caching]]` not `[[caching.md]]` not markdown links.
- **Link on first mention.** First time `[[write-through-cache]]` appears on a page → wikilink. Subsequent mentions on the same page → plain text.
- Source cards get cited inline as `[[sources/paper-foo]]` from topic pages, to signal "this is a source, not a topic."

---

## Operations

### Ingest a source

Trigger: the owner drops a source into `raw/articles/`, `raw/papers/`, `raw/talks/`, or `raw/book/` and says "ingest this".

Follow the `wiki-ingest` skill under `.claude/skills/wiki-ingest/`. The short version:

1. **Read** the raw source in full. For long papers or dense chapters, multiple passes. Decide per-topic whether to extend an existing page or create a new one; ask if a call isn't obvious.
2. **Write** the source card *and* the topic pages it feeds. Topic pages first (so the source card's wikilinks resolve), source card last.
3. **Integrate.** Update `index.md` with any new entries. Append to `log.md`. Flip the raw file's `ingested:` flag.
4. **Verify.** Every wikilink resolves, every page in the slate landed, raw file flipped.

Typical ingest touches 2–8 files. A source that introduces a genuinely new subgraph can touch more. If a single article balloons past ~10 files, stop and ask — extend-over-create is probably being violated.

### Read a book or lecture series

Trigger: the owner says "let's start [book]", "let's read [series]", or any read-along question mid-chapter ("what's the author saying here?", "walk me through this section").

Follow the `reading-companion` skill under `.claude/skills/reading-companion/`. It handles:

- **Setup** — first-touch seeding of a `wiki/sources/book-<slug>.md` card with chapter/episode list, thesis, reading plan.
- **Read-along** — mid-chapter discussion in chat, no topic-page writes.
- **Progress** — updating the book card's chapter status + running connections.
- **Handoff** — when the owner says "ingest Ch N", the skill does the pre-ingest brief (running connections, prior chapter callbacks) and hands off to `wiki-ingest`.

`reading-companion` is the **only** operation that writes to `wiki/sources/book-*.md` and uses the `read` / `discussed` log ops. It never writes `wiki/<topic>.md` — that's `wiki-ingest`'s job.

### Query

Trigger: the owner asks a question.

1. Read `index.md` first to locate relevant topic pages.
2. Read the linked topic pages; chase wikilinks. Source cards are fine to consult when a specific source's framing is the right answer.
3. If the answer needs synthesis across multiple pages, say so and cite them inline.
4. If the answer is valuable enough to preserve, **ask the owner if it should be filed as a new topic page or extend an existing one**. If yes, write it, update `index.md`, log as `query-filed`.
5. Answer format is whatever teaches best: prose, tables, a Mermaid diagram, a slide deck, worked-through math or code. Pick the one that actually teaches.

### Daily digest

Trigger: the owner says "run the digest", "process today's clippings", "catch up the wiki", or a scheduled task fires the skill.

Follow the `daily-digest` skill under `.claude/skills/daily-digest/`. The short version:

1. **Prepare** — run `utilities/prepare.sh` (wraps orphans, backfills PDFs + transcripts).
2. **Ingest** — `wiki-ingest` per source still marked `ingested: false`.
3. **Track** — collect topic pages created/extended across the run.
4. **Digest** — if 2+ topic pages were touched, write `wiki/digests/<date>.md` with 3–5 curated highlights in the wiki's teaching voice.
5. **Log** — append a `digest` op to `log.md`.

Digests are derived artifacts, not part of the knowledge graph. Topic pages do **not** link back to digests.

### Lint

Trigger: the owner says "lint the wiki", or periodically (every ~5 ingests).

Check for:

- **Orphan pages** — topics with no inbound wikilinks and no `index.md` entry.
- **Missing topic pages** — a term mentioned in 3+ pages without its own page is a candidate for promotion.
- **Stale claims** — topic pages whose `updated` is older than the most recent contributing source. Some domains move fast; a page from 18 months ago may be overdue a pass.
- **Broken wikilinks** — `[[foo]]` where `foo.md` doesn't exist under `wiki/` or `wiki/sources/`.
- **Contradictions** — topic pages making conflicting claims.
- **Index drift** — pages not listed in `index.md`, or entries pointing at deleted pages.
- **Thin pages** — pages shorter than a tweet. Either delete or extend.
- **Mono-sourced topics** — a topic page sourced by only one source where newer material exists in `raw/`. Flag for re-ingest.
- **Glossary drift** — aliases in `glossary.md` pointing at slugs that no longer exist, or frequent alternate names not yet in the glossary.

Produce the lint report as markdown. Don't auto-fix — propose and let the owner approve.

---

## Teaching voice

**This is load-bearing.** The wiki exists so the owner can *learn*, not so they can read a textbook cold. Dense ≠ dry. The voice should feel like a senior practitioner at a whiteboard with you — direct, curious, a little wry — not like a Wikipedia stub written by committee.

This is the longest section of this file, and it's where topic-page quality is made or lost. The worked examples below use widely-known technical concepts as stand-ins; the *shape* of each pattern transfers to whatever the actual source is about.

### Open with a hook, not a definition

The first sentence of a topic page decides whether the reader continues.

**Bad — starts with the definition:**

> A database index is an auxiliary data structure that maintains a sorted copy of one or more columns to accelerate equality and range lookups.

Correct. Forgettable. The reader has already stopped.

**Good — starts with the problem, earns the definition:**

> Scanning a million-row table to find ten matching rows is a lot of wasted I/O — 99.999% of it useless. Indexes are the fix: a separate data structure kept in lockstep with the table, ordered by the column you're looking up, so finding those ten rows takes ~log₂(n) disk reads instead of n.

Same definition earned. The motivation *is* the opening.

### Motivate every claim — show the stakes

A claim without stakes is trivia. A claim with stakes teaches a tradeoff.

**Bad:**

> HTTPS negotiates a session key using public-key crypto, then switches to symmetric encryption.

True. So what?

**Good:**

> HTTPS uses public-key crypto only to negotiate a session key, then switches to symmetric encryption for the rest of the session, and the reason is load-bearing. Public-key operations (RSA, ECDHE) cost 100–1000× more CPU per byte than symmetric (AES). Running an entire connection through RSA would make loading a page feel like dial-up. The asymmetric handshake pays the cost once to bootstrap trust; AES carries the data.

Now the reader knows *why* the design choice exists and *what breaks* if you change it.

### Trace the mechanism, don't just name it

Naming a mechanism is the first move, not the last one. Walk through a small, concrete trace that lets the reader *feel* what happens.

**Bad:**

> Git stores content in a content-addressed object store.

**Good:**

> Naive version control: every commit stores full copies of every file. Ten thousand commits of a 100 MB repo = 1 TB of storage. Git's trick: content-address every file by its SHA-1 hash. Identical content (unchanged files across commits, the same file copied to two paths, a file reintroduced after deletion) stores exactly once. A commit is just a tree of hashes plus a pointer to its parent — a tiny object itself. Checkouts reconstruct by walking hashes. The 1 TB collapses to ~100 MB. More importantly, branching costs ~40 bytes (one ref file pointing at a commit hash). That's why Git branches are free and SVN branches weren't.

The reader now has the right mental model. Bonus: they know *why* branching is cheap.

### Show the math when it earns its place

A well-chosen equation teaches faster than prose. A token-dump of notation to look rigorous is worse than nothing.

**Good rule:** if you can state the equation and the *shape* of its variables in 3 lines, include it. If you need half a page to define the variables, rewrite around the intuition instead.

Good shape:

> Amdahl's law: `speedup = 1 / ((1 - p) + p / n)`, where `p` is the parallelisable fraction of work and `n` is the number of workers. At `p = 0.5`, even infinite workers cap speedup at 2×; at `p = 0.95`, you need 20 workers to reach 10× and you asymptote around 20×. The law is why "throw more cores at it" plateaus fast — the serial fraction dominates the moment you scale up. Any perf work on code with `p < 0.9` should be attacking the serial fraction, not buying cores.

### Ground in a real thing

Abstract concepts without a real-world anchor don't compound. Every concept page lands in at least one real, named system, workflow, product, or work.

**Bad:**

> MVCC (multi-version concurrency control) lets readers and writers operate concurrently without blocking.

**Good:**

> PostgreSQL's MVCC is the canonical example: every row carries `xmin` / `xmax` fields marking the transactions that inserted and (later) deleted it. Readers see the snapshot visible to their transaction; writers create new row versions rather than overwriting. Concurrent readers and writers never block each other. The cost is storage bloat (old versions linger until autovacuum sweeps them) and transaction-ID wraparound concerns at extreme scale. You get serialisable isolation without read locks; you pay for it in housekeeping overhead.

### Earn the tradeoff

Every tradeoff page must answer "under what regime does each option win?". Vague tradeoffs are worse than no tradeoffs.

**Bad:**

> Cache-aside is simpler but has staler reads than write-through.

**Good:**

> Cache-aside wins when reads dominate writes and stale data is tolerable for a short window — think user profiles on a social site, where a minute-stale avatar is fine. The app reads from cache, falls through to the DB on miss, writes to cache on fill. Writes go straight to the DB and invalidate the cache entry. Simple, failure-tolerant (cache down ≠ reads fail), but has a stale-read window equal to the invalidation latency. Write-through wins when the workload can't tolerate stale reads (payment flags, inventory counters) — every write goes cache-then-DB synchronously, so cache and DB are never out of sync. The cost is write latency (two hops) and the cache becoming a hard dependency: cache down = writes blocked. The awkward middle (heavy reads with occasional hot-write patches) often layers both — write-through on the paths that need it, cache-aside everywhere else.

### Voice

- **Practitioner, not professor.** "Here's the trick" beats "The underlying mechanism exploits…". Contractions are fine. A dry aside is fine. Don't write like you're being graded.
- **Short sentences when the idea is heavy.** Let the reader breathe between beats. Run-on sentences mask sloppy thinking.
- **Use analogies, sparingly.** A good analogy is a shortcut to the right mental model. A stretched analogy is a liability — bail out before it breaks.
- **Show the "aha".** If a source has a moment where the whole topic clicks, capture *that specific moment* on the topic page. Readers come back for the aha, not the section headings.

### Voice anti-patterns (don't)

- **Textbook openings.** "X is a Y…". Banned.
- **Paper-abstract voice.** Don't mimic the source's framing; rewrite it in the voice a teammate would use at a whiteboard.
- **Hedge words.** "Generally", "in most cases", "often" — use sparingly; they hide unexamined claims.
- **Throat-clearing.** "It is important to note that…", "In this section, we will discuss…". Just say the thing.
- **Hype words.** "Blazing fast", "cutting edge", "game-changing", "revolutionise". Banned — even when the source uses them.
- **Sourceless superlatives.** "The most popular", "the de facto standard". Either cite it or drop the claim.
- **"We" / "you" overuse.** A well-placed "you" lands. Every-paragraph "you" reads like a tutorial video.
- **Bullet walls.** If a section is 10+ consecutive bullets, it's a list pretending to be an explanation. Convert some to prose.
- **Empty scaffolds.** "## Conclusion" that restates the page. "## Further Reading" with two items. Cut.

### What "good" looks like

A good topic page should feel like one of these:

- **A 3am Slack DM** from a smart teammate who's just figured something out and wants to show you the trace.
- **A cold-open whiteboard walk** — first sentence is the problem, last sentence is the thing the reader wants to remember.
- **The one-page handout** you'd want before walking into a design review on the topic.

If the page feels like Wikipedia, rewrite the opening. If it reads like a paper abstract, rewrite the voice. If it reads like a course syllabus, delete and start over.

---

## Logging conventions

Every operation appends to `log.md`:

```
## [YYYY-MM-DD] <op> | <subject>

- Touched: pages created / updated
- Notes: 1–3 lines. What the source was, scope decision, contradictions, followups.
```

`<op>` is one of: `ingest`, `read`, `discussed`, `query`, `query-filed`, `lint`, `digest`, `refactor`, `meta`.

- `ingest` — a source was synthesised into topic pages (`wiki-ingest` skill).
- `read` — a book/series was started, or a chapter/episode was finished (not yet ingested) (`reading-companion` skill).
- `discussed` — a substantive read-along conversation worth remembering (`reading-companion` skill, sparingly).
- `query` — a question was asked and answered from the wiki.
- `query-filed` — a query answer was promoted to a topic page.
- `lint` — a lint pass was run.
- `digest` — a daily-digest run (`daily-digest` skill). Covers the batched ingest + the digest write; a single op per run.
- `refactor` — a structural change (slug rename, page split/merge).
- `meta` — a change to `CLAUDE.md`, the structure, or conventions.

Example:

```
## [YYYY-MM-DD] ingest | paper-foo

- Created: wiki/<topic-a>.md, wiki/<topic-b>.md, wiki/sources/paper-foo.md
- Updated: index.md, raw/papers/<file>.md (ingested: false → true)
- Notes: Foundational seed for the <subdomain> cluster. Kept <topic-b> as its
  own page because later sources on the same theme will want a clean hub to
  extend.
```

The `^## \[` prefix makes `log.md` grep-friendly:

```bash
grep "^## \[" log.md | tail -10
```

---

## What to ask the owner before doing

- Before **creating** a new topic page rather than extending — if the call isn't obvious, flag it and ask. Default is extend.
- Before **large refactors** (renaming slugs, merging pages, splitting a page in two).
- Before ingesting a source whose topic sits on the edge of the wiki's scope — if a scope is defined, check first.
- When a new source **contradicts** an established topic page — flag, don't silently overwrite.
- Before fabricating practical experience notes on a topic page ("the owner has done X" — don't invent this).

## What to just do

- Extend topic pages during an ingest (per approved slate).
- Add cross-references between topics.
- Update `index.md` and `log.md`.
- Flag open questions by creating `[question]`-tagged pages.
- Propose promoting a recurring term to its own topic page when it's earned one.

---

## Evolving this file

`CLAUDE.md` is a living document. When a convention emerges organically during use, codify it here. When something stops being useful, remove it. Changes to this file get a `meta`-op entry in `log.md`.
