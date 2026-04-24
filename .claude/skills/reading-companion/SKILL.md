---
name: reading-companion
description: Read a book or lecture series chapter-by-chapter with the owner. Seeds a book home card on first touch, supports mid-chapter discussion without committing wiki writes, tracks progress, and hands off to wiki-ingest when a chapter is ready. Use when the owner says "let's start [book]", "let's read [series]", "what's [author] saying here", "what does [author] mean by this", "compare this to Ch N", or any read-along / mid-chapter discussion. Does NOT write topic pages — that's wiki-ingest's job.
---

# reading-companion

Pairs with `wiki-ingest`. Where `wiki-ingest` handles one-shot sources (article / paper / talk / single chapter), this skill is for working through a **multi-part long-form source** — a book, a lecture series, a structured course — over weeks.

Does three things well:

1. **Seeds a book home card** on first touch (one source card for the whole book or series, distinct from per-chapter/per-episode cards).
2. **Runs read-along discussions** — chat-native, no wiki writes unless asked.
3. **Tracks progress** so "where am I in [book]?" is a single grep away, and hands off cleanly to `wiki-ingest` when a chapter or episode is ready to land.

**Prerequisite every run:** re-read `CLAUDE.md` (especially the three layers, the three rules, and the Teaching voice section). Skim `index.md` and any existing `wiki/sources/book-*.md` for context.

**Hard boundary:** this skill does **not** write to `wiki/<topic>.md`. Topic-page synthesis is `wiki-ingest`'s job and only fires when the owner says "ingest Ch N" (or equivalent).

---

## Scope

**In scope:**

- Books with ordered chapters.
- Lecture / video series that behave like books — MIT OCW courses, Coursera specialisations, YouTube lecture playlists with a clear arc.
- Structured courses with ordered modules.

**Out of scope** (stays with `wiki-ingest`):

- Individual papers (even long ones), standalone talks, or single blog posts.
- A single chapter or episode ingest, once we're past the "let's discuss the chapter" phase.

**Triggers this skill fires on:**

- "Let's start [book/series]" / "Set up [book] for reading."
- "What's [author] saying here?" / "What does this section mean?" / "Walk me through this algorithm box."
- "How does this compare to Ch N?" / "Hasn't [author] already covered this?"
- "Where are we in [book]?" / "What's next?"
- "Let's talk through Ch 3 before I ingest it."

**Triggers that hand off to `wiki-ingest`:**

- "Ingest Ch N" / "Let's file lecture 4" / "Write up this chapter."

---

## The four modes

```
1. Setup        → first-touch; seed book/series home card
2. Read-along   → mid-reading discussion; no wiki writes
3. Progress     → update book card's reading state
4. Handoff      → "ingest Ch N" → wiki-ingest takes over
```

### 1. Setup (first touch only)

Triggered by: "Let's start [book]", "Set up [series]", or the first time the owner references a book/series that has no `wiki/sources/book-<slug>.md` card.

Do this once, then never again for that book.

**Steps:**

1. Confirm the book or series is available. PDFs live in `raw/book/`; lecture series are typically on YouTube or a hosted platform — in that case we don't need local raw files for the whole series, just for each episode as we ingest it (`raw/talks/<slug>.md`). If it's not reachable, ask where to find it.
2. Propose a short slug (`book-kleppmann-ddia`, `book-nystrom-crafting-interpreters`, `course-mit-missing-semester`). Confirm if ambiguous.
3. Read the table of contents (book) or the full episode list (series). You need the chapter/episode titles — skim the ToC page or the series playlist. Don't guess.
4. Seed `wiki/sources/book-<slug>.md` with the schema below.
5. Append a `read` op to `log.md`: "started [book/series]".

**Book / series home card schema:**

Frontmatter lives in `CLAUDE.md`'s "Page shapes" → "Book / series home card" section. Use that schema. For a lecture series, `source_type: book` still fits (treat the whole series as one "book"); `chapters:` becomes the episode list:

```yaml
chapters:
  - { n: 1, slug: "course-overview-the-shell", status: unread }
  - { n: 2, slug: "shell-tools-and-scripting", status: unread }
  - { n: 3, slug: "editors-vim",               status: unread }
  # ...
```

Status meanings:

- `unread` — not yet touched.
- `in-progress` — currently reading/watching; `current:` points at where.
- `read` — finished, not yet ingested. Fair game for discussion.
- `ingested` — per-chapter source card exists at `wiki/sources/ch-NN-<book-slug>.md` and topic pages have been extended.

**Book card body:**

```markdown
# <Book / Series Title>

**Thesis.** 1–2 sentences on what this book/series is actually teaching. Not
marketing copy — the author's real claim or pedagogical angle.

## Why this earned a slot

A paragraph on why this book is worth the investment over alternatives. What
specifically will compound in the wiki from reading it. (E.g. "Kleppmann ties
every data-system tradeoff back to first principles — this seeds the
distributed-systems spine of the wiki in a way no blog post or paper can.")

## Reading plan

How we're reading it. Usually "in order", but sometimes there's a smarter
route ("DDIA is in order; skip the intro chapter if already comfortable with
ACID/BASE, but keep Ch 5 — it anchors the replication thread that recurs
throughout"). Capture any skip / reorder decisions here.

## Progress

- Started: YYYY-MM-DD
- Currently reading: Ch N / Lecture N (timestamp or page X)
- Ingested so far: Ch 1, Ch 2 (as of YYYY-MM-DD)

## Running connections

Appended during read-along sessions. One-liners noting where a chapter touches
an existing wiki topic or another source. These become concrete cross-references
at ingest time — but capturing them here means they don't get lost between
sessions.

- Ch 5 leader-follower replication ↔ [[replication]] (already in the wiki
  from an earlier article ingest) — Kleppmann derives it from the single-leader
  writes / multi-follower reads framing; prior source stated it more tersely.
- Ch 7 isolation levels ↔ [[mvcc]] — Kleppmann's snapshot isolation discussion
  connects cleanly to the Postgres MVCC grounding already on that page.
```

The **Running connections** section is the load-bearing bit. It's the memory of the reading arc; when a chapter is later ingested, these one-liners convert into explicit cross-references on topic pages.

### 2. Read-along (the default mode)

Triggered by: "What's the author saying here?", "What does this mean?", "Walk me through this algorithm box", "Explain Ch 3 §2", "Compare this to Ch 1", or anything that sounds like "help me understand what I'm reading."

**Rules:**

- **No writes to `wiki/<topic>.md`.** Ever. Topic pages are synthesis; synthesis happens at ingest time.
- **Writes to the book card are fine**, but only for `Progress` and `Running connections`.
- **Answer in chat.** The canvas is conversation, not the wiki.
- **Use the wiki as background context.** Read `index.md` and chase wikilinks for existing treatment of what the chapter touches. Then answer — grounded in what the wiki already knows + what the chapter is adding.
- **Flag connections out loud.** "Kleppmann's leader-follower setup here is the same thing we captured in [[replication]] when we ingested that earlier article — but he derives it from the single-writer framing, which is cleaner than how the article justified it." Then offer to log the connection to the book card.
- **Stay in the teaching voice** (see `CLAUDE.md`'s Teaching voice section). Even in chat. No textbook openings, no definition-first dumps. Hook, trace, ground, earn tradeoffs. The register can be more conversational than a topic page — contractions, quick asides — but the discipline is the same.

**Pattern to avoid:** restating the chapter back to the owner. They're reading it too. Add something: a tighter framing, a connection to existing wiki material, a reason-to-care the author buried in the middle of a paragraph, a flag that an algorithm box has a subtle off-by-one, a pointer to a better resource on one specific sub-topic.

Example contrast:

- **Bad:** "Kleppmann is introducing log-structured storage."
- **Good:** "Here's the thing Kleppmann doesn't lean into hard enough in §3.1: size-tiered compaction isn't cosmetic — it's what keeps write amplification bounded as the LSM-tree grows. Without it, every flush re-writes the whole dataset. That's the actual reason LSM-trees beat B-trees on write-heavy workloads, not raw append speed."

**Log the discussion?** Only if it was a big enough conversation that the owner would want to find it again. Use op `discussed`:

```
## [YYYY-MM-DD] discussed | Kleppmann Ch 3 §3.1 — log-structured storage

- Notes: Read-along of §3.1. Worked through compaction tradeoffs + flagged
  connection to [[lsm-tree]] from an earlier article ingest. Also
  sanity-checked the write-amplification math. No wiki writes.
  Connection added to book-kleppmann-ddia.md running connections.
```

Most read-along sessions don't earn a log entry. Use judgement.

### 3. Progress (lightweight bookkeeping)

Triggered by: "Where are we?", "What's next?", finishing a chapter ("just finished Ch 3"), or starting one ("starting Ch 4 tonight").

**On starting a chapter:**

- Update the book card's `chapters:` entry to `status: in-progress`.
- Update top-level `current:` to `{ n: N, page: 1 }` (or timestamp for video).
- Bump `updated:`.

**On finishing a chapter (not ingesting yet):**

- Flip `chapters[N].status` to `read`.
- Clear `current:` (or point to the next chapter if moving on immediately).
- Bump `updated:`.
- Update the body's Progress section.
- Append to `log.md` with op `read`:
  ```
  ## [YYYY-MM-DD] read | Kleppmann Ch 3 — Storage and Retrieval
  - Notes: Finished reading, not yet ingested. Dense chapter — plan on a
    fat ingest (seeds lsm-tree / compaction / b-tree subgraph).
  ```

**On "where are we?":**

Read the book card, answer from it. Don't recompute — the card is the source of truth.

### 4. Handoff to `wiki-ingest`

Triggered by: "Ingest Ch N", "Write up lecture 4", "Let's file this chapter."

Your job here is the **pre-ingest warm-up**, then you hand over.

**Steps:**

1. Read the book card's **Running connections** for Ch N. These are the cross-references that must land on topic pages.
2. Read every previously-ingested chapter's source card (`wiki/sources/ch-<M>-<book>.md` for each `M < N` where `status: ingested`). Note any callbacks worth reinforcing — "Ch 4 encoding assumes Ch 2's data-model framing" etc.
3. Gather those into a short "pre-ingest brief" — 3–6 bullets listing the cross-references and callbacks that must show up on topic pages.
4. Hand off: invoke `wiki-ingest` on the chapter. The chapter is a `source_type: chapter` source card at `wiki/sources/ch-NN-<book-slug>.md`. Standard ingest flow applies.
5. After `wiki-ingest` finishes:
   - Flip `chapters[N].status` to `ingested` in the book card.
   - Update the book card's **Progress** section.
   - The `ingest` op in `log.md` is `wiki-ingest`'s responsibility; nothing extra needed.

Reading previous chapter source cards *before* ingesting is the thing that makes cross-chapter continuity actually happen. Skip it and the wiki ends up with N independent chapter ingests that don't talk to each other — exactly the fragmented state we collapsed the structure to avoid.

---

## Anti-patterns (don't)

- **Writing topic pages during read-along.** That's an ingest. If you feel the pull to write [[replication]] mid-chapter, ask "want to ingest Ch N now?" instead. Either land it properly or leave it for later.
- **Ingesting partial chapters.** A chapter (or episode) is the ingest unit. Mid-chapter "ingest what we've covered so far" creates fragmented source cards and breaks cross-chapter callbacks. Finish the chapter.
- **Textbook-voice summaries.** If your chat answer reads like a compressed version of the chapter itself, you've failed. Add value, don't mirror.
- **Letting the book card drift from reality.** If the chapter numbering changes in a new edition, fix it on the card.
- **Skipping the pre-ingest brief.** Running connections + previous chapter source cards exist for exactly this moment.

---

## Log ops

See `CLAUDE.md`'s "Logging conventions" for the full op list. Reading-companion owns the `read` and `discussed` ops; hands off to `wiki-ingest` for `ingest`.

Example reading arc on one book (grep-able from `log.md`):

```
## [YYYY-MM-DD] read      | started Kleppmann (Designing Data-Intensive Applications)
## [YYYY-MM-DD] read      | Kleppmann Ch 1 — Reliable, Scalable, Maintainable
## [YYYY-MM-DD] ingest    | ch-01-kleppmann-ddia
## [YYYY-MM-DD] read      | Kleppmann Ch 2 — Data Models and Query Languages
## [YYYY-MM-DD] discussed | Kleppmann Ch 3 §3.1 — log-structured storage
## [YYYY-MM-DD] ingest    | ch-03-kleppmann-ddia
```

Readable at a glance: when we started, which chapters are read but not ingested, which are fully landed.

---

## When in doubt

- **Does this book already have a home card?** Check `wiki/sources/book-*.md` before seeding a new one.
- **Owner asks a pure topic question mid-chapter** (e.g. "what's MVCC actually doing?" while reading a transactions chapter) → answer using the wiki. If the wiki has a page, cite it. If not, answer in chat and flag it as a candidate for the next ingest.
- **The chapter is dense and the owner wants section-by-section** → stay in read-along. Follow their pace; don't front-run.
- **Owner asks for a preview of a chapter before reading** → short and punchy (3–5 bullets on the chapter's thesis + key moves, a roadmap not a paraphrase). Not a spoiler.
- **A chapter lands and extends wildly across the wiki** (e.g. a data-systems chapter touching [[replication]], [[partitioning]], creating [[leader-follower]], [[quorum-reads]], [[vector-clocks]]) → that's expected for the denser chapters. `wiki-ingest` handles the volume; reading-companion's only job was the pre-ingest brief.
- **Series episode ingest** (e.g. a lecture from an MIT course) → same flow. Pre-fetch the transcript into `raw/talks/<slug>.md` using `utilities/prepare.sh`, then invoke `wiki-ingest` as if it were a chapter.
