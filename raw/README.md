# raw/

Immutable source material. The agent **reads** from here and **never writes** here.

The **only** allowed mutation is flipping `ingested: false → true` in a raw file's frontmatter at the end of an ingest.

---

## Layout

- `book/` — books and long-form courses. Optional — populated only if a long-form source is adopted (a specific book, a structured course, a lecture series with companion notebooks). Empty otherwise.
- `articles/` — blog posts and long-form articles. Clipped via [Obsidian Web Clipper](https://obsidian.md/clipper) using `utilities/article_clipper.json`.
- `papers/` — academic papers. Clipped from arXiv via `utilities/arxiv_paper_clipper.json` (captures metadata + abstract). **Always accompany the clip with the PDF** (e.g. `paper-<slug>.pdf`) — the HTML page doesn't contain the paper body; the PDF is the canonical source.
- `talks/` — conference talks and YouTube videos. Clipped via `utilities/youtube_talk_clipper.json` (captures metadata + description). **Always accompany the clip with the transcript** — YouTube's DOM doesn't contain the transcript at clip time. Use `utilities/youtube_transcript.sh` (see below) or paste manually from YouTube's transcript panel.

See [`utilities/README.md`](../utilities/README.md) for Web Clipper template setup.

---

## Frontmatter convention

Every source file has YAML frontmatter emitted by the clipper template. The exact shape depends on `source_type`:

### Article (`source_type: article`)

```yaml
---
source_type: "article"
title: "..."
author: "..."
site: "..."
url: "..."
published: YYYY-MM-DD
clipped: YYYY-MM-DD
description: "..."
tags: []
ingested: false
---
```

### Paper (`source_type: paper`)

```yaml
---
source_type: "paper"
title: "..."
authors: [...]
url: "..."              # landing page / abstract page
arxiv_id: "..."         # optional; if present, PDF auto-fetched from arxiv.org
pdf_url: "..."          # optional; direct PDF URL when not on arXiv
site: "..."             # optional; only set by the generic paper clipper
published: YYYY-MM-DD
clipped: YYYY-MM-DD
abstract: "..."         # may be empty for non-arXiv papers
ingested: false
---
```

**How the PDF gets fetched.** `prepare.sh`'s paper handler tries these in order:

1. `<slug>.pdf` already exists next to the `.md` → skip (honors manual drops).
2. `arxiv_id` set → `curl`s `https://arxiv.org/pdf/<arxiv_id>`.
3. `pdf_url` set → `curl`s that URL directly.
4. `url` set and it points at a PDF (`.pdf` extension, or HEAD request returns `Content-Type: application/pdf`) → downloads it.
5. None of the above → error with a clear "set `pdf_url` / `arxiv_id` / drop the PDF manually" message.

The manual-drop path is first-class — for paywalled papers, publisher landing pages that hide the PDF behind auth (ACM, IEEE, Springer), or PDFs with no web presence (drafts, friends emailing you a file), just drop `paper-<slug>.pdf` alongside the `.md` and `prepare.sh` won't try to fetch anything.

### Talk (`source_type: talk`)

```yaml
---
source_type: "talk"
title: "..."
channel: "..."
url: "..."                # YouTube / podcast URL (for clipped sources)
audio_file: "..."         # local audio filename next to this MD (for manual drops)
duration: "PT_H_M_S"
published: YYYY-MM-DD
clipped: YYYY-MM-DD
ingested: false
---
```

Either `url:` or `audio_file:` must be set. If both are present, `audio_file:` wins. Local audio files always transcribe via Whisper (auto-captions only exist for YouTube URLs).

---

## Manually-dropped files (orphan auto-wrap)

Not every source goes through the Web Clipper. Sometimes you drop a PDF a friend emailed you, an mp3 of a downloaded podcast, or a paper pulled from a paywalled journal — no clipper involved, no frontmatter.

`prepare.sh` handles this automatically. Before its main scan, it looks for non-`.md` files in `raw/articles/`, `raw/papers/`, and `raw/talks/` that don't have a companion `.md` next to them. For each orphan, it auto-generates a stub `.md` with:

- `source_type` inferred from the subdirectory.
- `title` from the filename (rough — the ingest agent refines this on the source card).
- `clipped:` set to the file's `mtime` formatted as `YYYY-MM-DD`.
- `ingested: false`.
- For talks: `audio_file: <filename>` so the transcript step routes to Whisper.

After that, the file joins the normal pipeline. You can edit the stub frontmatter if you want a sharper title or other metadata; the auto-wrap is just "get it into the queue."

`raw/book/` is deliberately skipped — books go through the `reading-companion` skill, which seeds its own book-home card with a different schema.

---

## The `ingested` flag — the work queue

Every clipped source lands with `ingested: false`. This is the queue.

- **Pending:** `ingested: false` — the source has been clipped but not yet incorporated into the wiki.
- **Done:** `ingested: true` — the agent has processed this source, written a `wiki/sources/<slug>.md` card, and created or extended the related topic pages in `wiki/`.

List the queue any time:

```bash
grep -L "ingested: true" raw/articles/*.md raw/papers/*.md raw/talks/*.md
```

The agent flips the flag to `true` at the end of an ingest and appends an entry to `log.md`.

---

## Ingest workflow (how the agent processes `raw/`)

When the owner says "ingest the new articles" (or points at a specific file), the agent:

1. **Finds pending sources.** Greps for `ingested: false` under `raw/`. Picks the one(s) named, or the full set if asked for "all".
2. **Reads frontmatter + body.** For each source file.
3. **Backfills missing metadata from the body.** Frontmatter fields can be empty when the upstream site lacks proper Schema.org / Open Graph markup (Medium mirrors, arXiv, etc.). The agent scans the body for author names, publish dates, and other metadata and notes them for the source card — it does not edit the `raw/` file.
4. **Extends existing topic pages first.** For every idea the source touches that already has a `wiki/<topic>.md`, the agent updates that page (new section, new framing, new citation). This is where the real synthesis happens.
5. **Creates new topic pages** only for genuinely new ideas — a term or concept the wiki has never seen. `tags:` on the page determines its group in `index.md`.
6. **Writes the source card** at `wiki/sources/<slug>.md` *last*. Reading notes for the source: TL;DR, key claims, what's novel vs the wiki's prior state, a quote or two, the list of topic pages it contributed to.
7. **Flags contradictions explicitly.** If the new source contradicts an existing topic page, both pages get updated with a note. The agent does not silently overwrite.
8. **Flips `ingested: true`** in the `raw/` frontmatter. (This is the **one** write the agent makes to `raw/` — the flag only.)
9. **Updates `index.md`** with any new topic pages.
10. **Appends to `log.md`** with op `ingest`.

A batch ingest ("ingest all pending") does this per source, serially.

---

## Metadata gaps — known cases

Some sites systematically fail the clipper. Good to know when a clip comes through thin:

- **Freedium (Medium paywall bypass).** `freedium-mirror.cfd` strips most Medium metadata — `author` and `published` will usually be empty. **Fix:** clip from the original Medium URL, not the Freedium mirror. Freedium is great for reading, bad for metadata.
- **arXiv abstract pages.** `authors` and `published` don't match arXiv's DOM structure by default. Authors are usually in the body; published date appears as "Submitted on …" text. Agent extracts both at ingest.
- **Substack / self-hosted blogs.** Highly variable. First clip will reveal what comes through. The agent's body scan is the safety net.
- **YouTube.** Description is truncated to what renders without clicking "Show more". Duration is ISO 8601 (`PT#H#M#S`). Transcript is never in the DOM — has to be pasted or generated separately.

## Body content gaps

The clipper templates capture everything that's accessible in the page's rendered HTML. Two source types have body content that **isn't** in the HTML and needs a separate step before ingest:

- **Papers** — arXiv's abstract page only contains the abstract. The paper body lives in the PDF at `https://arxiv.org/pdf/<arxiv_id>`. A paper needs the PDF dropped alongside the clipped MD (same slug) so the ingest agent can read both.
- **Talks** — YouTube's page DOM doesn't contain the transcript. A talk needs its `## Transcript` section filled in before ingest, otherwise the agent only has the description (~1-3 sentences) to work with.

Both gaps are handled by one command:

```bash
utilities/prepare.sh
```

With no arguments, it scans every `.md` under `raw/` that isn't yet `ingested: true` and backfills what's missing — `curl`s the PDF for papers, splices a transcript into talks via `utilities/youtube_transcript.sh`. Articles are a no-op.

You can also point it at specific files or directories:

```bash
utilities/prepare.sh raw/talks/talk-foo.md
utilities/prepare.sh raw/papers
utilities/prepare.sh -f raw/talks/talk-foo.md   # force re-fetch
```

See [`utilities/README.md`](../utilities/README.md) for the full usage, safety notes, and quality caveats.

## Pre-ingest checklist

Before running `ingest` on any pending source:

- [ ] Run `utilities/prepare.sh` (or target specific files). That one command covers every source type.
- [ ] (Optional) Skim `raw/` for the clipped MDs and verify the frontmatter looks reasonable — the agent will backfill missing metadata from the body at ingest time, but it's useful to know what's thin going in.

---

## Naming conventions

The clipper templates produce filenames following these patterns:

- Articles: `{{date}}-{{title|safe_name}}.md` — date prefix for chronological sort.
- Papers: `paper-{{title|safe_name}}.md` — title prefix, no date (papers are timeless).
- Talks: `talk-{{title|safe_name}}.md` — same.

Filenames can be messy (double spaces, punctuation quirks from `safe_name`). That's fine — humans and the agent both work off frontmatter, not filenames.
