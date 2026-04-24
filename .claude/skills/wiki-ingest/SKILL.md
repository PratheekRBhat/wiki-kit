---
name: wiki-ingest
description: Ingest a source (article, paper, talk, or book chapter) from raw/ into the wiki. Reads the source, writes topic pages and a source card, extending existing topics over creating new ones. Use when the owner says "ingest the X paper", "ingest this article", "ingest the talk", "ingest this chapter", or any variant pointing at a specific file in raw/. Heavy on teaching voice — topic pages must teach, not recite.
---

# wiki-ingest

Ingests a single source into the wiki. Rides on top of the schema in `CLAUDE.md`; this file is the *how-to*, not the *what*.

**Prerequisite every run:** re-read `CLAUDE.md` (the three layers, the three rules, and the Teaching voice section) and skim `index.md`. `CLAUDE.md` is the source of truth; the skill stays thin on purpose.

Scope: **one source at a time**, from `raw/articles/`, `raw/papers/`, `raw/talks/`, or `raw/book/`.

**Book chapters and lecture episodes go through `reading-companion` first.** If the source is a book chapter or a lecture-series episode (a `source_type: chapter` card under a `source_type: book` home), `reading-companion` sets up the book/series, runs read-along, and only *then* hands off to this skill when the owner says "ingest Ch N" / "ingest lecture N". It also supplies a **pre-ingest brief** — running connections + prior-chapter callbacks — that this skill should fold into the topic pages it writes/extends. If you're invoked on a chapter without that brief, stop and ask whether `reading-companion` ran first.

---

## The 4-step loop

```
1. Read       → raw source + existing index.md
2. Write      → topic pages (extend first, create second), then source card
3. Integrate  → index.md, log.md, flip ingested flag
4. Verify     → links resolve, slate landed, flag flipped
```

### 1. Read

- Read the raw source in full. Papers get multiple passes (abstract → figures → experiments → back to intro → related work). Don't skip the experiments section — the ablations are where the real claims get tested.
- Read `index.md` so you know what already exists. This is what makes "extend over create" actually work.
- Note any frontmatter gaps in the raw file (Freedium strips `author` / `published`, arXiv clippers often miss authors, YouTube description truncates). Don't fix them in `raw/` — it's immutable. Backfill on the source card.
- Before moving on, decide *per topic*: extend an existing page, or create a new one? Default is extend. Create only when the source genuinely introduces a new idea the wiki has no home for. If you're unsure on a call, ask in-line — don't guess.

### 2. Write

In this order:

1. `mkdir -p wiki/sources/` if it doesn't exist.
2. **Extend existing topic pages first.** For each existing topic the source touches, add the new material (new section / paragraph / example / citation) and bump `updated:`. Add the source slug to the page's `sources:` frontmatter. Inline-cite the source the first time it's used on the page: `per [[sources/paper-foo]]`.
3. **Create new topic pages** for genuinely new ideas. One idea per page. Flat slug, short, durable.
4. **Write the source card last.** By writing it last, all `[[topic]]` wikilinks in its "Where it contributed" section resolve to pages that already exist on disk.

Topic pages are where the wiki earns its keep. They must *teach* — see [The teaching bar](#the-teaching-bar) below.

### 3. Integrate

1. **`index.md`** — add every new topic page under the correct group (matching its `tags:`). Use the one-line-description format: `- [[slug]] — short, punchy description.`
2. **`log.md`** — append an entry in the standard format (see `CLAUDE.md` for the shape).
3. **Flip the ingested flag.** In the raw file's frontmatter: `ingested: false → true`. This is the **only** allowed modification under `raw/`.

### 4. Verify

- `ls wiki/ wiki/sources/` — confirm every proposed page landed where it should.
- `grep '^ingested:' raw/<type>/<file>.md` — confirm `true`.
- Skim the source card's "Where it contributed" list against files on disk — must match.
- Scan for dangling wikilinks:
  ```bash
  grep -rhoE '\[\[[a-z0-9/-]+\]\]' wiki/ | sort -u
  ```
  Cross-reference against actual filenames. Break any, you're not done.

Report the landing to the owner: pages created / extended, meta updates, flag flip, follow-up questions. Suggest 1–2 next ingests if momentum makes sense.

---

## The teaching bar

**This is the load-bearing part of the skill.** The wiki exists so the owner can *learn from it later*, not so it exists. A topic page that merely covers the material has failed. A topic page that teaches it has done the job.

Keep `CLAUDE.md`'s "Teaching voice" section in mind while writing. The short version:

> Open with a hook. Motivate every claim. Trace the mechanism. Ground in a real thing. Show the math when it earns its place. Show the aha.

Below are concrete patterns for good and bad topic-page writing. Internalise these before writing. The examples use widely-known technical concepts as stand-ins — substitute whatever fits the actual source.

### Openings: hook, don't define

The first sentence of a topic page decides whether the owner reads the rest.

**Bad — starts with the definition:**

> A database index is an auxiliary data structure that maintains a sorted copy of one or more columns to accelerate equality and range lookups.

Correct. Forgettable. The reader has already stopped.

**Good — starts with the problem, earns the definition:**

> Scanning a million-row table to find ten matching rows is a lot of wasted I/O — 99.999% of it useless. Indexes are the fix: a separate data structure kept in lockstep with the table, ordered by the column you're looking up, so finding those ten rows takes ~log₂(n) disk reads instead of n.

Same definition earned. The motivation *is* the opening.

### Claims: always show stakes

A claim without stakes is trivia. A claim with stakes teaches a tradeoff.

**Bad:**

> HTTPS negotiates a session key using public-key crypto, then switches to symmetric encryption.

True. So what?

**Good:**

> HTTPS uses public-key crypto only to negotiate a session key, then switches to symmetric encryption for the rest of the session, and the reason is load-bearing. Public-key operations (RSA, ECDHE) cost 100–1000× more CPU per byte than symmetric (AES). Running an entire connection through RSA would make loading a page feel like dial-up. The asymmetric handshake pays the cost once to bootstrap trust; AES carries the data.

Now the reader knows *why* the design choice exists and *what breaks* if you change it.

### Mechanisms: trace, don't name

Naming a mechanism is the first move, not the last one. Walk through a small, concrete trace that lets the reader *feel* what happens.

**Bad:**

> Git stores content in a content-addressed object store.

**Good:**

> Naive version control: every commit stores full copies of every file. Ten thousand commits of a 100 MB repo = 1 TB of storage. Git's trick: content-address every file by its SHA-1 hash. Identical content (unchanged files across commits, the same file copied to two paths, a file reintroduced after deletion) stores exactly once. A commit is just a tree of hashes plus a pointer to its parent — a tiny object itself. Checkouts reconstruct by walking hashes. The 1 TB collapses to ~100 MB. More importantly, branching costs ~40 bytes (one ref file pointing at a commit hash). That's why Git branches are free and SVN branches weren't.

The reader now has the right mental model. Bonus: they know *why* branching is cheap.

### Math: only when it earns the space

A well-chosen equation teaches faster than prose. A token-dump of notation to look rigorous is worse than nothing.

**Good rule:** if you can state the equation and the *shape* of its variables in 3 lines, include it. If you need half a page to define the variables, rewrite around the intuition instead.

Good shape:

> Amdahl's law: `speedup = 1 / ((1 - p) + p / n)`, where `p` is the parallelisable fraction of work and `n` is the number of workers. At `p = 0.5`, even infinite workers cap speedup at 2×; at `p = 0.95`, you need 20 workers to reach 10× and you asymptote around 20×. The law is why "throw more cores at it" plateaus fast — the serial fraction dominates the moment you scale up. Any perf work on code with `p < 0.9` should be attacking the serial fraction, not buying cores.

### Grounding: pick a real thing, name it

Abstract concepts without a real-world anchor don't compound. Every concept page lands in at least one real, named system, workflow, product, or work.

**Bad:**

> MVCC (multi-version concurrency control) lets readers and writers operate concurrently without blocking.

**Good:**

> PostgreSQL's MVCC is the canonical example: every row carries `xmin` / `xmax` fields marking the transactions that inserted and (later) deleted it. Readers see the snapshot visible to their transaction; writers create new row versions rather than overwriting. Concurrent readers and writers never block each other. The cost is storage bloat (old versions linger until autovacuum sweeps them) and transaction-ID wraparound concerns at extreme scale. You get serialisable isolation without read locks; you pay for it in housekeeping overhead.

### Tradeoffs: earn them

Every tradeoff page must answer "under what regime does each option win?". Vague tradeoffs are worse than no tradeoffs.

**Bad:**

> Cache-aside is simpler but has staler reads than write-through.

**Good:**

> Cache-aside wins when reads dominate writes and stale data is tolerable for a short window — think user profiles on a social site, where a minute-stale avatar is fine. The app reads from cache, falls through to the DB on miss, writes to cache on fill. Writes go straight to the DB and invalidate the cache entry. Simple, failure-tolerant (cache down ≠ reads fail), but has a stale-read window equal to the invalidation latency. Write-through wins when the workload can't tolerate stale reads (payment flags, inventory counters) — every write goes cache-then-DB synchronously, so cache and DB are never out of sync. The cost is write latency (two hops) and the cache becoming a hard dependency: cache down = writes blocked. The awkward middle (heavy reads with occasional hot-write patches) often layers both — write-through on the paths that need it, cache-aside everywhere else.

### Voice anti-patterns (don't do these)

- **Textbook openings.** "X is a Y…". Banned across the wiki.
- **Paper-abstract voice.** Don't mimic the source's framing; rewrite it in the voice a teammate would use at a whiteboard.
- **Hedge words.** "Generally", "in most cases", "often" — use sparingly; they hide unexamined claims.
- **Throat-clearing.** "In this section, we will discuss…", "It is important to note that…". Just say the thing.
- **Hype words.** "State of the art", "cutting edge", "revolutionary", "blazing fast". Banned — even when the source uses them.
- **Bullet walls.** If a section is 10+ consecutive bullets, it's a list pretending to be an explanation. Convert some to prose.
- **Empty scaffolds.** "## Conclusion" that restates the page. "## Further Reading" with two items. Cut.
- **"We" / "you" overuse.** A single "you" on a page can land. Paragraph-after-paragraph "you" reads like a tutorial video. Switch to third-person / impersonal voice.

### What a finished topic page should feel like

Pick one, then rewrite until the page reads like it:

- **A 3am Slack DM** from a smart teammate who just figured something out and wants to show you the trace.
- **A cold-open whiteboard walk.** First sentence = problem. Last sentence = the thing to remember.
- **The one-page handout** you'd want before walking into a design review on the topic.

If the page reads like a paper abstract or a course syllabus, rewrite the opening. If it reads like a Wikipedia stub, rewrite the whole body.

---

## Typical page slates

Use these as starting points, not gospel. Right-size based on what the source actually delivers.

**Article** (10–20 min read, single angle — explainer, benchmark report, opinion)

- 0–2 **extended** existing topic pages
- 0–2 **new** topic pages (only if genuinely new ideas)
- 1 source card
- index.md + log.md

**Paper** (typically introduces a new technique / architecture / dataset / benchmark)

- 0–3 **extended** existing topic pages
- 1–5 **new** topic pages (the technique, a distinct variant, the evaluation setup)
- 1 source card
- 0–2 open-question pages (tagged `[question]`)
- index.md + log.md

**Talk** (conference / lecture / podcast, often sharper opinions than a paper or article)

- Closer to the article slate.
- Talks often carry the best "one-liner" quotes — capture them faithfully on the source card rather than sanding them smooth.

**Book chapter** (`ch-NN-<book>` source card)

- 2–6 **extended** existing topic pages
- 2–5 **new** topic pages (chapters seed a lot)
- 1 source card (the chapter is a source; there's no separate chapter page)
- index.md + log.md

If a single article's slate exceeds ~10 files, stop and ask. The "extend over create" rule is probably being violated.

---

## Frontmatter patterns

Per `CLAUDE.md`. Two reminders worth pinning here because they bite in practice:

- **Wikilinks in frontmatter:** quoted block-list form. `related: [[page]]` on a single line is Obsidian-tolerant but not YAML-strict. Use:
  ```yaml
  related:
    - "[[page-a]]"
    - "[[page-b]]"
  ```
- **Source slug = filename under `wiki/sources/`.** Pick a short, readable slug (`paper-btree-analysis`, `article-cache-aside-explainer`). Use it consistently: source filename, `sources:` fields on topic pages, inline wikilinks as `[[sources/paper-btree-analysis]]`.

---

## Log format

Per `CLAUDE.md`:

```
## [YYYY-MM-DD] ingest | <source-slug> (<author or short handle>)

- Created: wiki/<topic>.md (x2), wiki/sources/<slug>.md
- Updated: wiki/<existing-topic>.md (which section), index.md, raw/<type>/<file>.md (ingested: false → true)
- Notes: 2–4 lines. What the source was, scope decision, contradictions,
  followups. Useful for the future reader grep-reading log.md — not a page summary.
```

---

## Gotchas (learned live)

- **Never modify `raw/` except the `ingested` flag.** Missing author, bad title, broken clipper output — all fix on the source card or in `utilities/`, never in `raw/`.
- **Flag contradictions; don't silently overwrite.** In fast-moving domains a topic page written 18 months ago may be genuinely outdated, but the right move is still to *flag and ask*, not silently rewrite.
- **Link on first mention only.** First `[[write-through-cache]]` on a page → wikilink. Subsequent mentions → plain text. Re-linking is noise.
- **`wiki/sources/` may not exist on the first ingest.** `mkdir -p` it. Don't assume.
- **Source-slug casing and punctuation stick forever.** Pick carefully on the first ingest that cites a source; renaming later breaks every `sources:` list that references it.
- **Metadata backfill patterns** (body scan, not raw edit):
  - Freedium clips lose `author` and `published` — byline is in the first paragraph.
  - arXiv clips lose `authors` and full `published` — scrape from the abstract block or the PDF.
  - YouTube clips truncate `description` at ~5 lines — the full description is accessible via `yt-dlp --get-description <url>` if the transcript pass didn't already grab it.

---

## When in doubt

- **Ambiguous scope** → ask. Don't silently pick a direction the owner would have pushed back on.
- **A topic page you're about to create already exists under a slightly different slug** → extend the existing one. Rename-and-refactor is a lint pass, not an ingest task.
- **A source sits between this wiki and another** (if you're running multiple bounded wikis) → ask where it should land. Cross-posting the source card to both wikis is allowed; duplicating topic pages is not.
- **A source is low-quality / hype / already-covered** → ask before ingesting. A source card alone, with a terse "not promoted to topic pages because…" note, is a legitimate outcome. Not every clipped thing earns a full slate.
