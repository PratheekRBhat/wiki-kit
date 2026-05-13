# raw/

Immutable source material. The agent reads from here and should not rewrite it, except for flipping `ingested: false` to `ingested: true` when an ingest finishes.

---

## Layout

- `*.md` — flat source files. `source_type:` differentiates articles, papers, talks, books, chapters, and conversations.
- Articles are blog posts, docs, or long-form essays.
- Papers are academic papers and whitepapers. Pair them with a sibling PDF when possible.
- Talks are conference talks, videos, podcasts, or recorded lectures. Pair them with a transcript when possible.
- Conversations are saved LLM chat writeups created by the `save-conversation` skill.

See [utilities/README.md](../utilities/README.md) for clipper setup and helper scripts.

---

## Frontmatter Convention

Every source file has YAML frontmatter. The exact shape depends on `source_type`.

### Article

```yaml
---
type: Raw
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

### Paper

```yaml
---
type: Raw
source_type: "paper"
title: "..."
authors: [...]
url: "..."
arxiv_id: "..."
pdf_url: "..."
site: "..."
published: YYYY-MM-DD
clipped: YYYY-MM-DD
abstract: "..."
ingested: false
---
```

### Talk

```yaml
---
type: Raw
source_type: "talk"
title: "..."
channel: "..."
url: "..."
audio_file: "..."
duration: "PT_H_M_S"
published: YYYY-MM-DD
clipped: YYYY-MM-DD
ingested: false
---
```

Either `url:` or `audio_file:` must be present. If both exist, `audio_file:` wins.

### Book

```yaml
---
type: Raw
source_type: "book"
title: "..."
file: "..."
url: "..."
clipped: YYYY-MM-DD
ingested: false
---
```

Books still flow through `reading-companion`. This raw wrapper is just the bronze-layer source.

### Conversation

```yaml
---
type: Raw
source_type: "conversation"
title: "..."
participants:
  - "user"
  - "assistant"
original_app: "..."
url: ""
clipped: YYYY-MM-DD
conversation_kind: "debug"
why_kept: "..."
ingested: false
---
```

Conversation kinds: `debug | research | learning | decision | other`.

---

## The `ingested` Flag

This is the work queue.

- `ingested: false` means pending.
- `ingested: true` means the source has already been synthesized into the wiki.

List pending raw files:

```bash
grep -L "ingested: true" raw/*.md
```

---

## Orphan Auto-Wrap

Not every source starts as a clean markdown clip. Sometimes the owner drops a PDF, audio file, or ebook directly into `raw/`.

`utilities/prepare.sh` handles that. In auto-discovery mode it scans for non-`.md` files without companion wrappers and creates a stub `.md` beside them.

Source type is inferred from file extension:

- `.pdf` → `paper`
- audio or video formats such as `.mp3`, `.m4a`, `.wav`, `.mp4`, `.mov`, `.webm`, `.mkv` → `talk`
- `.epub`, `.mobi`, `.azw3` → `book`
- everything else → `article`

This keeps the bronze layer flat and still gives the agent something structured to ingest.

---

## Ingest Workflow

When the owner says "ingest this", the agent:

1. Finds the pending source in `raw/`
2. Reads frontmatter and body
3. Backfills missing metadata on the source card if needed
4. Extends existing topic pages first
5. Creates new topic pages only for truly new ideas
6. Writes the source card
7. Flips `ingested: true`
8. Updates `index.md`
9. Appends to `log.md`

The raw file itself stays otherwise unchanged.

---

## Body Gaps

Clipper output is not always enough on its own.

- Papers usually need the PDF body.
- Talks usually need a transcript.

That is what `utilities/prepare.sh` is for:

```bash
utilities/prepare.sh
utilities/prepare.sh raw/paper-some-source.md
utilities/prepare.sh raw/talk-some-talk.md
utilities/prepare.sh -f raw/talk-some-talk.md
```

Run it before ingest when the source depends on a PDF or transcript.

---

## Naming Conventions

The clipper templates usually emit names like:

- `YYYY-MM-DD-<title>.md` for articles
- `paper-<title>.md` for papers
- `talk-<title>.md` for talks
- `conversation-<title>.md` for saved chats

The filenames do not need to be pretty. Frontmatter and source-card slugs are what actually matter.
