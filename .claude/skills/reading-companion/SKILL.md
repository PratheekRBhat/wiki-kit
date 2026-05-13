---
name: reading-companion
description: Read a book or lecture series chapter-by-chapter with the owner. Seeds a book home card on first touch, supports mid-chapter discussion without committing wiki writes, tracks progress, and hands off to wiki-ingest when a chapter is ready. Use when the owner says "let's start SICP", "let's read [book]", "what's Hunt & Thomas getting at here", "what does this pattern actually mean", "compare this to Ch N", or any read-along / mid-chapter discussion. Does NOT write topic pages — that's wiki-ingest's job.
---

# reading-companion

Pairs with `wiki-ingest`. Where `wiki-ingest` handles one-shot sources (article / paper / talk / single chapter), this skill is for working through a **multi-part long-form source** — a book like *The Pragmatic Programmer*, *Refactoring*, *SICP*, a lecture series, a structured course — over weeks.

Does three things well:

1. **Seeds a book home card** on first touch (one source card for the whole book, distinct from per-chapter cards).
2. **Runs read-along discussions** — chat-native, no wiki writes unless asked.
3. **Tracks progress** so "where am I in *Refactoring*?" is a single grep away, and hands off cleanly to `wiki-ingest` when a chapter is ready to land.

**Prerequisite every run:** re-read `CLAUDE.md` (especially the three layers, the three rules, the wiki-scope fence, and the Teaching voice section). Skim `index.md` and any existing `wiki/sources/book-*.md` for context.

**Hard boundary:** this skill does **not** write to `wiki/<topic>.md`. Topic-page synthesis is `wiki-ingest`'s job and only fires when the owner says "ingest Ch N" (or equivalent).

---

## Scope

**In scope:**
- Books (e.g. *The Pragmatic Programmer*, *Refactoring* (Fowler), *SICP*, *Designing Software-Intensive Systems*, *A Philosophy of Software Design*, *Clean Architecture*).
- Lecture / video series that behave like books — MIT 6.001 (SICP), CS 61A, Destroy All Software screencasts.
- Structured courses with ordered modules.

**Out of scope** (stays with `wiki-ingest`):
- Individual articles, blog posts, conference talks, or papers.
- A single chapter ingest, once we're past the "let's discuss the chapter" phase.

**Wiki-scope fence still applies.** If `CLAUDE.md` defines scope boundaries, check the book against them. If the book's subject belongs in a sibling wiki, flag it and ask before seeding. Don't silently expand scope.

**Triggers this skill fires on:**
- "Let's start [book/series]" / "Let's read *Refactoring*" / "Set up [book] for reading."
- "What's [author] saying here?" / "What does this pattern mean?" / "Walk me through this refactoring."
- "How does this compare to Ch N?" / "Hasn't the author already covered this?"
- "Where are we in [book]?" / "What's next?"
- "Let's talk through Ch 3 before I ingest it."

**Triggers that hand off to `wiki-ingest`:**
- "Ingest Ch N" / "Let's file Ch 3" / "Write up this chapter."

---

## The four modes

```
1. Setup        → first-touch; seed book home card
2. Read-along   → mid-reading discussion; no wiki writes
3. Progress     → update book card's reading state
4. Handoff      → "ingest Ch N" → wiki-ingest takes over
```

### 1. Setup (first touch only)

Triggered by: "Let's start *Pragmatic Programmer*", "Set up *Refactoring*", or the first time the owner references a book that has no `wiki/sources/book-<slug>.md` card.

Do this once, then never again for that book.

**Steps:**

1. Confirm the book is in `raw/books/`. If it's a PDF, note the filename. If it's not there, ask the owner where to find it (don't assume).
2. **Check wiki scope.** If `CLAUDE.md` defines scope boundaries, verify the book fits. If it belongs in a sibling wiki, flag and ask before seeding.
3. Propose a short slug (`book-pragmatic-programmer`, `book-fowler-refactoring`, `book-sicp`, `book-ousterhout-philosophy`). Confirm with the owner if ambiguous.
4. Read the table of contents. You need the chapter list with titles — skim the ToC PDF page or the book's opening matter. Don't guess.
5. Seed `wiki/sources/book-<slug>.md` with the schema below.
6. Append a `read` op to `log.md`: "started [book]".

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
# <Book Title>

**Thesis.** 1–2 sentences on what this book is actually arguing. Not marketing
copy — the author's real claim. (E.g. "Good software is the product of
deliberate, pragmatic habits. Most chapters are really about making small,
reversible, principled decisions — the topic-specific material is the vehicle.")

## Why this source is worth reading

A paragraph on why this long-form source is worth reading now. Treat it as one
source among many: what ideas, contrasts, or examples might compound in the wiki,
without letting the book become the vault's organising spine.

## Reading plan

How we're reading it. Usually "in order", but sometimes a smarter route
(e.g. "Ousterhout is short — read straight through. Fowler's *Refactoring*
is a reference: read Ch 1–4 in order, then dip into specific refactorings
as they come up in real code."). Capture any skip / reorder decisions here.

## Progress

- Started: YYYY-MM-DD
- Currently reading: Ch N (page X)
- Ingested so far: Ch 1, Ch 2 (as of YYYY-MM-DD)

## Running connections

Appended during read-along sessions. One-liners noting where a chapter touches
an existing wiki topic or another source. These become concrete cross-references
at ingest time — but capturing them here means they don't get lost between
sessions.

- Ch 2 "DRY" ↔ [[dry]] (short existing page from the original ingest) —
  Hunt & Thomas frame it much more broadly than the one-liner suggests;
  worth extending.
- Ch 6 concurrency discussion ↔ [[rust-ownership]], [[go-goroutines]] —
  they talk at a higher level than either; at ingest time, link both ways.
```

The **Running connections** section is the load-bearing bit. It's the memory of the reading arc; when a chapter is later ingested, these one-liners convert into explicit cross-references on topic pages.

### 2. Read-along (the default mode)

Triggered by: "What's the author saying here?", "What does this pattern mean?", "Walk me through this refactoring", "Explain Ch 3 section 2", "Compare this to Ch 1", or anything that sounds like "help me understand what I'm reading."

**Rules:**
- **No writes to `wiki/<topic>.md`.** Ever. Topic pages are synthesis; synthesis happens at ingest time.
- **Writes to the book card are fine**, but only for `Progress` and `Running connections`.
- **Answer in chat.** The canvas is conversation, not the wiki.
- **Use the wiki as background context.** Read `index.md` and chase wikilinks for existing treatment of what the chapter touches. Then answer — grounded in what the wiki already knows + what the chapter is adding.
- **Flag connections out loud.** "Fowler's 'Extract Function' here is the lever we already describe on [[refactoring]], but note he's pairing it with 'Inline Variable' — the pair is where the real payoff is, and we don't capture that pairing yet." Then offer to log it to the book card.
- **Stay in the teaching voice** (see `CLAUDE.md`'s Teaching voice section). Even in chat. No textbook openings, no definition-first dumps. Hook, trace, ground, earn tradeoffs. The register can be more conversational than a topic page.

**Pattern to avoid:** restating the chapter back to the owner. He's reading it too. Add something: a tighter framing, a connection to existing wiki material, a reason-to-care the author buried in the middle of a paragraph, a flag that a claim has aged (e.g. "Ousterhout's argument against comments-that-duplicate-the-code is right; his critique of TDD has aged less well — worth holding lightly"), a real-world example the book is too abstract to give.

**Log the discussion?** Only if it was a big enough conversation that the owner would want to find it again. Use op `discussed`:

```
## [YYYY-MM-DD] discussed | Pragmatic Programmer Ch 2 §9 — DRY

- Notes: Read-along of §9. Worked through the "knowledge" vs "code"
  framing of DRY (broader than most people take it to be), flagged
  connection to [[dry]] — worth extending at ingest time.
  No wiki writes. Connection added to book-pragmatic-programmer.md
  running connections.
```

Most read-along sessions don't earn a log entry. Use judgement.

### 3. Progress (lightweight bookkeeping)

Triggered by: "Where are we?", "What's next?", finishing a chapter ("just finished Ch 3"), or starting one ("starting Ch 4 tonight").

**On starting a chapter:**
- Update the book card's `chapters:` entry to `status: in-progress`.
- Update top-level `current:` to `{ n: N, page: 1 }`.
- Bump `updated:`.

**On finishing a chapter (not ingesting yet):**
- Flip `chapters[N].status` to `read`.
- Clear `current:` (or point to the next chapter if moving on immediately).
- Bump `updated:`.
- Update the body's Progress section.
- Append to `log.md` with op `read`:
  ```
  ## [YYYY-MM-DD] read | Pragmatic Programmer Ch 2 — A Pragmatic Approach
  - Notes: Finished reading, not yet ingested. Touches DRY, orthogonality,
    reversibility — probably three separate topic-page extensions at ingest.
  ```

**On "where are we?":**
Read the book card, answer from it. Don't recompute — the card is the source of truth.

### 4. Handoff to `wiki-ingest`

Triggered by: "Ingest Ch N", "Write up Ch 5", "Let's file this chapter."

Your job here is the **pre-ingest warm-up**, then you hand over.

**Steps:**

1. Read the book card's **Running connections** for Ch N. These are the cross-references that must land on topic pages.
2. Read every previously-ingested chapter's source card (`wiki/sources/ch-<M>-<book>.md` for each `M < N` where `status: ingested`). Note any callbacks worth reinforcing — "Ch 4 'Pragmatic Paranoia' extends Ch 2's reversibility argument" etc.
3. Gather those into a short "pre-ingest brief" — 3–6 bullets listing the cross-references and callbacks that must show up on topic pages.
4. Hand off: invoke `wiki-ingest` on the chapter. The chapter is a `source_type: chapter` source card at `wiki/sources/ch-NN-<book-slug>.md`. Standard ingest flow applies (including the scope check — if the chapter's substance is actually DE or AI, push back).
5. After `wiki-ingest` finishes:
   - Flip `chapters[N].status` to `ingested` in the book card.
   - Update the book card's **Progress** section.
   - The `ingest` op in `log.md` is `wiki-ingest`'s responsibility; nothing extra needed.

Reading previous chapter source cards *before* ingesting is the thing that makes cross-chapter continuity actually happen. Skip it and the wiki ends up with N independent chapter ingests that don't talk to each other — exactly the fragmented state we collapsed the structure to avoid.

---

## Anti-patterns (don't)

- **Writing topic pages during read-along.** That's an ingest. If you feel the pull to write [[dry]] mid-chapter, ask "want to ingest Ch N now?" instead.
- **Ingesting partial chapters.** A chapter is the ingest unit. Finish it.
- **Textbook-voice summaries.** If your chat answer reads like a compressed version of the chapter itself, you've failed. Add value, don't mirror. ("Fowler is introducing Extract Function" — bad. "Fowler spends 3 pages on Extract Function because it's the refactoring every other refactoring leans on — half the rest of the catalog is 'Extract Function, then do X to the extracted bit'. That's the bit worth internalising" — good.)
- **Treating a book as the wiki spine.** Books are long-form sources, not privileged outlines. Capture useful ideas on topic pages; don't reorganise the wiki around chapter order.
- **Silently expanding wiki scope.** If `CLAUDE.md` defines scope boundaries, respect them. Flag boundary cases rather than silently ingesting.
- **Letting the book card drift from reality.** If the chapter list is wrong (different edition, etc.), fix it.
- **Skipping the pre-ingest brief.** Running connections + previous chapter source cards exist for exactly this moment.

---

## Log ops

See `CLAUDE.md`'s "Logging conventions" for the full op list. Reading-companion owns the `read` and `discussed` ops; hands off to `wiki-ingest` for `ingest`.

Example reading arc on one book (grep-able from `log.md`):

```
## [2026-04-22] read      | started Pragmatic Programmer (20th ed.)
## [2026-04-25] read      | Pragmatic Programmer Ch 1 — A Pragmatic Philosophy
## [2026-04-25] ingest    | ch-01-pragmatic-programmer
## [2026-04-28] read      | Pragmatic Programmer Ch 2 — A Pragmatic Approach
## [2026-04-29] discussed | Pragmatic Programmer Ch 2 §9 — DRY
## [2026-04-30] ingest    | ch-02-pragmatic-programmer
```

Readable at a glance: when we started, which chapters are read but not ingested, which are fully landed.

---

## When in doubt

- **Does this book already have a home card?** Check `wiki/sources/book-*.md` before seeding a new one.
- **Does this book fit this wiki?** Run the scope check from `CLAUDE.md`. Broad SWE and DE books belong here; genuinely research-heavy AI books may not.
- **the owner asks a pure topic question mid-chapter** (e.g. "what actually is dependency injection again?" while reading Ch 4) → answer using the wiki. If the wiki has a page, cite it. If not, answer in chat and flag it as a candidate for the next ingest.
- **The chapter is dense and he wants section-by-section** → stay in read-along. Follow his pace.
- **He asks for a preview of a chapter before reading** → short and punchy (3–5 bullets on the chapter's thesis + key moves, a roadmap not a paraphrase).
- **A chapter lands and extends wildly across the wiki** → expected for the denser chapters. `wiki-ingest` handles the volume; reading-companion's only job was the pre-ingest brief.
