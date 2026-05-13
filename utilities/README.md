# utilities/

Tooling that helps sources get into `raw/` cleanly.

Two things live here:

1. Obsidian Web Clipper templates
2. Shell helpers that backfill content the clipper cannot reach

The normal flow is:

`clip -> prepare.sh -> ingest`

---

## Inventory

| File | Kind | Purpose |
| --- | --- | --- |
| `article_clipper.json` | clipper template | fallback article clipper |
| `arxiv_paper_clipper.json` | clipper template | arXiv abstract page clipper |
| `paper_clipper.json` | clipper template | generic paper clipper |
| `youtube_talk_clipper.json` | clipper template | YouTube talk clipper |
| `prepare.sh` | shell helper | backfills PDFs and transcripts |
| `youtube_transcript.sh` | shell helper | low-level transcript fetch via `yt-dlp` |
| `whisper.sh` | shell helper | optional higher-quality transcription via Whisper |

### Template targets

All templates now land in flat `raw/`.

| File | Template name | Trigger | Output path | `source_type` |
| --- | --- | --- | --- | --- |
| `article_clipper.json` | `Article` | fallback | `raw/` | `article` |
| `arxiv_paper_clipper.json` | `arXiv Paper` | `https://arxiv.org/*` | `raw/` | `paper` |
| `paper_clipper.json` | `Paper (generic)` | manual pick | `raw/` | `paper` |
| `youtube_talk_clipper.json` | `YouTube Talk` | `youtube.com/watch*`, `youtu.be/*` | `raw/` | `talk` |

Every template emits `ingested: false` so pending sources are easy to find.

---

## Installing The Templates

1. Open Obsidian Web Clipper settings.
2. Go to `Templates`.
3. Import each `*.json` file from this directory.
4. Put the specialty templates above the generic `Article` template.
5. Point each template at the vault that contains this repo.

Expected order:

1. `arXiv Paper`
2. `YouTube Talk`
3. `Paper (generic)`
4. `Article`

Test each template once and make sure the note lands in flat `raw/` with the expected frontmatter.

---

## Why The Templates Look Like This

### `article_clipper.json`

- No URL trigger, so it acts as the catch-all
- ISO date prefix in the filename for chronological sorting
- Captures common article metadata

### `arxiv_paper_clipper.json`

- Triggers only on arXiv pages
- Captures `arxiv_id` so `prepare.sh` can fetch the PDF
- Pulls the abstract from the page DOM

### `paper_clipper.json`

- Manual template for non-arXiv papers
- Supports optional `pdf_url`
- Keeps enough metadata for the agent to backfill the rest later

### `youtube_talk_clipper.json`

- Triggers on standard YouTube URLs
- Captures duration, channel, and description
- Leaves a transcript placeholder because the DOM does not contain the full transcript

---

## `prepare.sh`

`prepare.sh` reads `source_type:` and does the right thing:

| `source_type` | Action |
| --- | --- |
| `article` | no-op |
| `conversation` | no-op |
| `paper` | downloads a sibling PDF if needed |
| `talk` | injects a transcript |
| `book` | leaves the wrapper in place for `reading-companion` |

Examples:

```bash
utilities/prepare.sh
utilities/prepare.sh raw/talk-some-keynote.md
utilities/prepare.sh raw/paper-some-paper.md
utilities/prepare.sh -f raw/talk-some-keynote.md
utilities/prepare.sh -w raw/talk-some-keynote.md
utilities/prepare.sh -n
```

With no args, it also wraps orphan PDFs, audio files, videos, and ebooks dropped directly into `raw/`.

### Safety Notes

- For talks, it only rewrites the `## Transcript` section.
- For papers, it only adds a sibling PDF.
- It skips files already marked `ingested: true` in auto-discovery mode.

---

## Transcript Helpers

### `youtube_transcript.sh`

Use this when YouTube auto-captions are good enough:

```bash
utilities/youtube_transcript.sh "https://youtu.be/..."
```

### `whisper.sh`

Use this for better quality when the talk is dense, accented, non-English, or local-only:

```bash
brew install ffmpeg yt-dlp
export OPENAI_API_KEY="sk-..."
utilities/whisper.sh "https://youtu.be/..."
```

`prepare.sh -w` routes talk transcription through `whisper.sh`.

---

## Extending The Kit

If you add a new kind of source, keep the kit coherent:

1. Add or update a clipper template in `utilities/`
2. Document the frontmatter in [raw/README.md](../raw/README.md)
3. Teach `prepare.sh` about the new `source_type` if it needs backfill behavior
4. Update `CLAUDE.md` if the ingest or page-shape rules change

Default rule: keep `raw/` flat unless you have a genuinely better reason than "folders felt tidy".
