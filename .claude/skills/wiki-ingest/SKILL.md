---
name: wiki-ingest
description: Ingest a source (article, paper, talk, or book chapter) from raw/ into the wiki. Confirms scope against sibling wikis, reads the source, then writes topic pages and a source card, extending existing topics over creating new ones. Use when the owner says "ingest the X article", "ingest this paper", "ingest the talk", "ingest this chapter", or any variant pointing at a specific file in raw/. Heavy on teaching voice — topic pages must teach, not recite.
---

# wiki-ingest

Ingests a single source into this wiki. Rides on top of the schema in `CLAUDE.md`; this file is the *how-to*, not the *what*.

**Prerequisite every run:** re-read `CLAUDE.md` (the three layers, the three rules, and the Teaching voice section) and skim `index.md`. `CLAUDE.md` is the source of truth; the skill stays thin on purpose.

Scope: **one source at a time**, from `raw/<subdir>/`. Subdirs map to source format: `articles/`, `papers/`, `talks/`, `books/`, `conversations/`. Book chapters (`source_type: chapter`) live in `raw/books/` alongside their parent book card. The `source_type:` frontmatter field is preserved on every file as a query property.

**Book chapters go through `reading-companion` first.** If the source is a book chapter (a `source_type: chapter` card under a `source_type: book` home), `reading-companion` sets up the book, runs read-along, and only *then* hands off to this skill when the owner says "ingest Ch N". It also supplies a **pre-ingest brief** — running connections + prior-chapter callbacks — that this skill should fold into the topic pages it writes/extends. If you're invoked on a chapter without that brief, stop and ask whether `reading-companion` ran first.

---

## The 5-step loop

```
1. Scope check → does this belong here, or in a sibling wiki?
2. Read        → raw source + existing index.md
3. Write       → topic pages (extend first, create second), then source card
4. Integrate   → index.md, log.md, flip ingested flag
5. Verify      → links resolve, slate landed, flag flipped
```

### 1. Scope check

If `CLAUDE.md` defines scope boundaries or sibling wikis, check the source against them before anything else. If the source clearly belongs in a different wiki, stop and tell the owner. If it's borderline, ask. Cross-cutting sources may earn a page in two wikis — surface it before writing so the owner can confirm.

If no scope boundaries are defined, skip this step.

### 2. Read

- Read the raw source in full. For long papers, multiple passes.
- Read `index.md` so you know what already exists.
- **Similarity check via CLI.** Before deciding extend-vs-create, use the Obsidian CLI to surface existing pages that may cover the same ground:
  - `obsidian search query="<key concept from source>"` — content matches across the vault.
  - `obsidian search query="tag:#<likely-tag> path:wiki"` — narrow by tag and path.
  - `obsidian backlinks file="<candidate-page>"` — see what already cross-references a near-match.
  - Read any hits that look like near-matches. If an existing page covers 60%+ of what you'd write, **extend it** — don't create a new one. The "extend over create" rule only works if you actually check.
- Note any frontmatter gaps in the raw file (Freedium strips `author` / `published`, YouTube description truncates). Don't fix them in `raw/` — it's immutable. Backfill on the source card.
- Before moving on, decide *per topic*: extend an existing page, or create a new one? Default is extend. Create only when the source genuinely introduces a new idea the wiki has no home for. Flag tribal-debate topics (OOP vs FP, REST vs GraphQL, monorepo vs polyrepo, etc.) so the topic page stays even-handed. If you're unsure on a call, ask in-line — don't guess.

### 3. Write

In this order:

1. `mkdir -p wiki/sources/` if it doesn't exist.
2. **Extend existing topic pages first.** For each existing topic the source touches, add the new material (new section / paragraph / example / citation) and bump `updated:`. Add the source slug to the page's `sources:` frontmatter. Inline-cite the source the first time it's used on the page: `per [[sources/article-foo]]`.
3. **Create new topic pages** for genuinely new ideas. One idea per page. Flat slug, short, durable.
4. **Write the source card last.** By writing it last, all `[[topic]]` wikilinks in its "Where it contributed" section resolve to pages that already exist on disk. Set `raw_source:` to the path of the original raw file (e.g. `raw/articles/2026-05-12-go-errors.md`) — this is the backlink from the source card to its origin.

   When a source seeds a specific claim on a topic page, drop a `^block-id` on that claim and cite it from the source card as `[[topic#^block-id]]`. Coarse-grained "contributed to `[[topic]]`" still works; block refs are the upgrade when claim-level provenance matters.

Topic pages are where the wiki earns its keep. They must *teach* — see [The teaching bar](#the-teaching-bar) below.

### 4. Integrate

1. **`index.md`** — add every new topic page under the correct group (matching its `tags:`). Use the one-line-description format: `- [[slug]] — short, punchy description.`
2. **`log.md`** — append an entry in the standard format (see `CLAUDE.md` for the shape).
3. **Flip the ingested flag.** In the raw file's frontmatter: `ingested: false → true`. This is the **only** allowed modification under `raw/`.

### 5. Verify

- `ls wiki/ wiki/sources/` — confirm every proposed page landed where it should.
- `grep '^ingested:' raw/<subdir>/<file>.md` — confirm `true`.
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

**Re-read `CLAUDE.md`'s "Teaching voice" section before writing.** The worked examples there (dependency injection, Rust data races, Go GC tri-color, Python pattern matching, Clojure persistent vectors, monorepo vs polyrepo) show the shape of each pattern. Don't freestyle — follow the patterns.

Short rule reminder:

- **Open with a hook, not a definition.** Motivation first, definition earned.
- **Motivate every claim.** Show stakes. "So what?" must always answer.
- **Trace the mechanism.** Walk a small concrete example; don't just name.
- **Ground in a real language / framework / tool.** Every concept page has at least one real, named anchor.
- **Show the code when it earns its place.** A 5-line snippet beats three paragraphs.
- **Earn the tradeoff.** "Under what team / project conditions does each option win?" must be answered.
- **Tribal-debate topics: even-handed, not neutral.** Best-faith reasoning on both sides; separate factual claims from preference claims.

If the page feels like Wikipedia or a tutorial, rewrite the opening.

---

## Typical page slates

Use these as starting points, not gospel. Right-size based on what the source actually delivers.

**Article** (10-min read, single angle)
- 0–2 **extended** existing topic pages
- 0–2 **new** topic pages (only if genuinely new ideas)
- 1 source card
- index.md + log.md

**Paper** (academic / research, usually introduces a language feature, a tool, or a formalism)
- 0–3 **extended** existing topic pages
- 1–3 **new** topic pages
- 1 source card
- 0–2 open-question pages (tagged `[question]`)
- index.md + log.md

**Talk** (conference / keynote, often sharper opinions than articles)
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
- **Source slug = filename under `wiki/sources/`.** Pick a short, readable slug (`article-go-error-handling`, `book-pragmatic-programmer`). Use it consistently: source filename, `sources:` fields on topic pages, inline wikilinks as `[[sources/article-go-error-handling]]`.

---

## Log format

See `CLAUDE.md`'s "Logging conventions" for the general format and op list. Ingest-specific shape:

```
## [YYYY-MM-DD] ingest | <source-slug> (<author or short handle>)

- Created: wiki/<topic>.md (x2), wiki/sources/<slug>.md
- Updated: wiki/<existing-topic>.md (which section), index.md, raw/<subdir>/<file>.md (ingested: false → true)
- Notes: 2–4 lines. What the source was, scope decision, contradictions,
  followups. Useful for the future you grep-reading log.md — not a page summary.
```

---

## Gotchas (learned live)

- **Never modify `raw/` except the `ingested` flag.** Missing author, bad title, broken clipper output — all fix on the source card or in `utilities/`, never in `raw/`.
- **Flag contradictions; don't silently overwrite.** Especially true in SWE, where competing schools of thought are the norm, not the exception.
- **Link on first mention only.** First `[[ownership]]` on a page → wikilink. Subsequent mentions → plain text. Re-linking is noise.
- **`wiki/sources/` may not exist on the first ingest.** `mkdir -p` it. Don't assume.
- **Source-slug casing and punctuation stick forever.** Pick carefully on the first ingest; renaming later breaks every `sources:` list that references it.
- **Metadata backfill patterns** (body scan, not raw edit):
  - Freedium clips lose `author` and `published` — byline is in the first paragraph.
  - arXiv clips lose `authors` and full `published` — scrape from the abstract block or the PDF.
  - YouTube clips truncate `description` at ~5 lines — the full description is accessible via `yt-dlp --get-description <url>` if the transcript pass didn't already grab it.

---

## When in doubt

- **Ambiguous scope** → ask. Don't silently pick a direction the owner would have pushed back on.
- **Wrong wiki** → stop at the scope-check step and ask before touching anything.
- **A topic page you're about to create already exists under a slightly different slug** → extend the existing one. Rename-and-refactor is a lint pass, not an ingest task.
- **A source is a hot take on a tribal topic** → capture the take faithfully on the source card, but rewrite the topic page in an even-handed voice. Single-source-opinion-driven topic pages are a failure mode.
- **A source is low-quality / marketing / already-covered** → ask before ingesting. A source card alone, with a terse "not promoted to topic pages because…" note, is a legitimate outcome. Not every clipped thing earns a full slate.
