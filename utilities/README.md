# utilities/

Tooling that helps sources get into `raw/` cleanly. Two kinds of thing live here:

1. **[Obsidian Web Clipper](https://obsidian.md/clipper) templates** — one per `source_type`. They capture clean markdown + frontmatter into the right `raw/` subdirectory when you hit the clipper button.
2. **Shell helpers** — post-clip backfill for body content the clipper can't reach (paper PDFs, YouTube transcripts).

The normal flow is: **clip → `prepare.sh` → ingest**.

---

## Inventory

| File | Kind | Purpose |
| --- | --- | --- |
| `article_clipper.json` | Clipper template | Fallback article clipper (no URL trigger) → `raw/articles/` |
| `arxiv_paper_clipper.json` | Clipper template | arXiv paper abstract page → `raw/papers/` |
| `paper_clipper.json` | Clipper template | Generic paper clipper for non-arXiv sources → `raw/papers/` |
| `youtube_talk_clipper.json` | Clipper template | YouTube video page → `raw/talks/` |
| `prepare.sh` | Shell helper | One-stop post-clip backfill: PDFs for papers, transcripts for talks |
| `youtube_transcript.sh` | Shell helper | Low-level: fetches and cleans a YouTube transcript via `yt-dlp` |
| `whisper.sh` | Shell helper | Optional: higher-quality transcripts via OpenAI Whisper API (paid) |

### Clipper templates (quick reference)

| File | Template name | Triggers on | Lands in | `source_type` |
| --- | --- | --- | --- | --- |
| `article_clipper.json` | `Article` | *(fallback — no URL trigger)* | `raw/articles/` | `article` |
| `arxiv_paper_clipper.json` | `arXiv Paper` | `https://arxiv.org/*` | `raw/papers/` | `paper` |
| `paper_clipper.json` | `Paper (generic)` | *(no URL trigger — pick manually)* | `raw/papers/` | `paper` |
| `youtube_talk_clipper.json` | `YouTube Talk` | `youtube.com/watch*`, `youtu.be/*` | `raw/talks/` | `talk` |

All three emit YAML frontmatter with `ingested: false` so the ingest agent has a grep-able work queue. See [`raw/README.md`](../raw/README.md) for the full frontmatter shape per type.

---

## Installing the templates in Web Clipper

1. Open the Web Clipper browser extension → click the gear icon (Settings).
2. Go to the **Templates** tab.
3. For each `*.json` file in this directory: click **Import** (or the `⋯` / overflow menu → **Import from JSON**) and point at the file.
4. **Order matters.** In the template list, specialty templates must appear **above** the generic `Article` catch-all so their URL triggers match first. Drag to reorder:
   1. `arXiv Paper`
   2. `YouTube Talk`
   3. `Paper (generic)`
   4. `Article`
   (`Paper (generic)` has no URL trigger — its position doesn't technically matter, but keeping it above `Article` makes the list read as "specialty types first, catch-all last".)
5. Confirm each template's **vault** is set to the Obsidian vault pointing at this repo.

Test each by clipping a sample page from the matching type — an arXiv paper, a YouTube video, and any article — and verify the file lands in the right `raw/<subdir>/` folder with the expected frontmatter.

---

## Why each template looks the way it does

### `article_clipper.json`

- **Empty `triggers`** — intentional. This makes it the default template for URLs that don't match the specialty triggers.
- **Filename** `{{date}}-{{title|safe_name}}` — ISO-date prefix so `raw/articles/` sorts chronologically.
- **`site`, `url`, `description`** come through from standard Open Graph / Schema.org markup on most sites.
- **`author` and `published` often come through empty.** This is upstream site variability, not a template bug (see "Known metadata gaps" below). The ingest agent backfills from body content.

### `arxiv_paper_clipper.json`

- **Trigger** `https://arxiv.org/*` — fires only on arXiv abstract pages.
- **Filename** `paper-{{title|safe_name}}` — `paper-` prefix for easy visual grouping; no date prefix (papers don't age the same way articles do).
- **`arxiv_id` uses** `{{url|split:"/"|last}}` — extracts the ID from the end of URLs like `https://arxiv.org/abs/2602.01331`.
- **`abstract`** uses a CSS selector `blockquote.abstract` + `strip_tags` to pull arXiv's rendered abstract block.
- **`authors` and `published` can come through empty.** arXiv's DOM doesn't emit the Schema.org fields the clipper looks for by default. Authors are in the body ("Mingju Chen, Guibin Zhang, …") and the publish date appears as a "Submitted on …" line — the agent extracts both at ingest.
- **For the full PDF:** arXiv pages link to `/pdf/<id>`. `prepare.sh` downloads it automatically; or do it manually with `curl`. Both the clipped markdown and the PDF coexisting is fine — the markdown has searchable metadata and abstract, the PDF has the full content.

### `paper_clipper.json`

- **No URL trigger.** You pick this template manually from the clipper UI when the paper isn't on arXiv (bioRxiv, SSRN, OpenReview, university PDFs, random paper someone sent you the link to).
- **Filename** `paper-{{title|safe_name}}` — same prefix as arXiv papers so they sort together.
- **`url`** is the landing page you're on. **`pdf_url`** starts empty — fill it in by hand if you know the direct PDF URL (e.g. a bioRxiv paper's "Download PDF" link). Otherwise leave it blank.
- **For the PDF itself** you have three options, in order of laziest to most careful:
  - **Lazy**: leave `pdf_url` empty. If `url` happens to be a direct-PDF link (`.pdf` extension or `Content-Type: application/pdf`), `prepare.sh` will fetch from `url` automatically. If not, it'll error politely.
  - **Explicit**: set `pdf_url` to the direct PDF URL. `prepare.sh` fetches from there.
  - **Manual**: download the PDF yourself, save it as `raw/papers/paper-<slug>.pdf` next to the `.md`. `prepare.sh` sees the file, skips fetching. Required for paywalled PDFs (ACM, IEEE, Springer) and anything behind auth.
- The generic clipper doesn't try to be smart about publisher DOMs — it captures whatever Open Graph / Schema.org metadata the site emits. Some sites emit almost nothing; that's OK, the agent backfills from the PDF body at ingest.

### `youtube_talk_clipper.json`

- **Triggers** `youtube.com/watch*` and `youtu.be/*` — catches both URL formats.
- **Filename** `talk-{{title|safe_name}}` — `talk-` prefix.
- **`duration`** via `{{schema:@VideoObject:duration}}` — YouTube emits Schema.org's `VideoObject` markup reliably, so duration comes through as ISO 8601 (`PT13M51S`). Kept as `text` since converting to human-readable is cheap at ingest time.
- **`channel` and `published`** come through cleanly for the same reason.
- **Description is truncated** to what renders in the DOM without clicking "Show more". Not worth fighting.
- **Transcript is never in the DOM.** The template leaves a placeholder; `prepare.sh` fills it via `youtube_transcript.sh`.

---

## Post-clip helpers

The Web Clipper captures whatever is in the page DOM. For papers and talks, the key body content lives **outside** the DOM (the paper body is in the PDF; the transcript is loaded by a separate YouTube API). `prepare.sh` closes that gap in one call.

### `prepare.sh` — the daily driver

Reads each source's `source_type` frontmatter and does the right thing:

| `source_type` | Action |
| --- | --- |
| `article` | no-op (body is complete at clip time) |
| `paper` | downloads the PDF next to the clipped MD. Priority: existing file → `arxiv_id` → `pdf_url` → direct-PDF `url` → error. |
| `talk` | appends a transcript under `## Transcript` via `youtube_transcript.sh` (or `whisper.sh` with `-w`) |

**Prerequisites:**

```bash
brew install yt-dlp        # for talks
# curl is already on macOS
```

**Usage:**

```bash
# Backfill everything pending (ingested: false across raw/)
utilities/prepare.sh

# One specific file
utilities/prepare.sh raw/talks/talk-foo.md

# One directory
utilities/prepare.sh raw/papers

# Multiple targets
utilities/prepare.sh raw/talks/talk-one.md raw/papers/paper-two.md

# Force re-fetch (overwrite PDFs, replace transcripts)
utilities/prepare.sh -f raw/talks/talk-foo.md

# Use Whisper (paid API) instead of YouTube auto-captions for talks
utilities/prepare.sh -w raw/talks/talk-dense-accent.md

# Dry run — preview pending work without fetching anything
utilities/prepare.sh -n
```

Run `utilities/prepare.sh -h` for full help.

**Dry-run mode (`-n`):** reports what the script *would* do without actually downloading. Useful as a preflight before a big batch — especially with `-w`, to eyeball how many talks will hit the Whisper API before committing. Sample output:

```
• paper: raw/papers/paper-foo.md
  ok    raw/papers/paper-foo.md — would download https://arxiv.org/pdf/2602.01331
• talk: raw/talks/talk-bar.md
  ok    raw/talks/talk-bar.md — would fetch transcript via youtube_transcript.sh
  skip  raw/talks/talk-baz.md — transcript already present

dry run — no changes made
summary: pending=2 complete=1 failed=0
```

**Pre-pass: orphan auto-wrap (auto-discovery mode only).**

When run with no args, before the main scan, `prepare.sh` looks for manually-dropped files in `raw/{articles,papers,talks}/` that don't have a companion `.md`. For each orphan it creates a stub frontmatter wrapper:

- `source_type` inferred from subdirectory.
- `title` from filename.
- `clipped:` set to the file's `mtime`.
- For talks, `audio_file:` pointing at the file so the transcript step routes through Whisper.

This handles PDFs friends emailed you, podcast episodes you downloaded, paywalled papers you pulled by hand — anything that didn't go through the Web Clipper. `raw/book/` is skipped (books go through `reading-companion`). The pre-pass does NOT run when you target specific files — if you name paths, it respects your scope and doesn't silently create stubs elsewhere.

**What it does per file:**

- Reads the frontmatter to get `source_type`, `arxiv_id` / `pdf_url` / `url` (papers), `url` / `audio_file` (talks), and `ingested`.
- For papers: if `<slug>.pdf` already exists alongside the `.md`, skips (add `-f` to overwrite). Otherwise fetches the PDF via the priority chain (`arxiv_id` → `pdf_url` → direct-PDF `url`). Errors politely if none of those work — drop the PDF manually in that case.
- For talks: if the `## Transcript` section already has non-placeholder content, skips. Otherwise calls `youtube_transcript.sh` (or `whisper.sh` if `-w` is set **or** `audio_file:` is set in frontmatter) and splices the result into the section. Local audio files always route through Whisper.
- Prints a per-file status line (`ok` / `skip` / `error`) and a final summary.
- Exits non-zero if any file failed, so it's safe to use in pipelines.

**Safety notes:**

- The script **never touches `raw/` content beyond what it's explicitly backfilling.** For talks it rewrites only the `## Transcript` section; for papers it only adds a sibling `.pdf`. Frontmatter, body text, and other sections are preserved byte-for-byte.
- On transcript fetch failure, the source `.md` is left untouched (the script writes to a temp file first, then moves on success).
- With no args, it auto-skips files already marked `ingested: true`, so it's safe to re-run after each new batch of clips.

### `youtube_transcript.sh` — low-level helper

The script `prepare.sh` calls under the hood for talks. Use it directly when you want the transcript in a non-standard place (clipboard, stdout, a different file):

```bash
# Print to stdout
utilities/youtube_transcript.sh "https://youtu.be/..."

# Pipe to clipboard
utilities/youtube_transcript.sh "..." | pbcopy

# Non-English video
utilities/youtube_transcript.sh -l es "..."
```

See `utilities/youtube_transcript.sh -h` for the full help.

**Limitations (apply whether invoked directly or via `prepare.sh`):**

- Uses YouTube's *auto-generated* captions. Quality varies — thick accents and domain jargon sometimes come through garbled. For high-stakes transcripts, use `whisper.sh` (see below) or `prepare.sh -w`.
- YouTube's auto-captions are emitted in a rolling-window format (phrases built up word-by-word). The script dedupes, but residual repetition is possible. If a transcript looks ugly, the agent can clean it at ingest time — don't obsess over making `raw/` perfect.
- Fails cleanly (non-zero exit, clear stderr message) when the video has no captions (live streams, some age-restricted/regional videos).

### `whisper.sh` — optional higher-quality transcripts

Drop-in upgrade over `youtube_transcript.sh`. Sends audio to OpenAI's Whisper API instead of relying on YouTube's auto-captions. Worth it for dense technical talks, thick accents, non-English audio, or podcasts (YouTube captions don't exist there).

**Costs ~$0.006/min** (as of 2026). A 45-min talk is ~$0.27. Small per-source; adds up at batch.

**Prerequisites:**

```bash
brew install ffmpeg yt-dlp
export OPENAI_API_KEY="sk-..."     # see below for setup options
```

Get a key at [platform.openai.com](https://platform.openai.com/).

**Usage:**

```bash
# Direct — transcribe a YouTube URL, print to stdout
utilities/whisper.sh "https://www.youtube.com/watch?v=..."

# A local audio file (podcast episode, recorded meeting, downloaded mp3)
utilities/whisper.sh ./podcast-episode.mp3

# Non-English audio
utilities/whisper.sh -l es ./spanish-talk.m4a

# Via prepare.sh — route all pending talks through Whisper instead of auto-captions
utilities/prepare.sh -w
utilities/prepare.sh -w raw/talks/talk-dense-accent.md
```

See `utilities/whisper.sh -h` for the full help.

**What it does:**

1. If given a URL, downloads audio via `yt-dlp`.
2. Re-encodes to 32 kbps mono mp3 via `ffmpeg` (Whisper doesn't need high fidelity — smaller files transcribe faster and cost the same).
3. If the compressed audio still exceeds Whisper's 25 MB per-request limit (rare — happens at ~2+ hours), transparently chunks into 20-minute segments.
4. Sends each chunk to the Whisper API, receives SRT back, strips SRT scaffolding into a line-per-phrase transcript — same output shape as `youtube_transcript.sh`, so it's a drop-in replacement.
5. Prints an estimated cost to stderr before transcription (informational).

**API key setup options:**

- **Shell rc** (simplest, persistent): add `export OPENAI_API_KEY="sk-..."` to `~/.zshrc` or `~/.bashrc` and restart your shell.
- **Per-project dotenv**: put `OPENAI_API_KEY=sk-...` in a `.env.local` file at the repo root, then `source .env.local` before running (or use [`direnv`](https://direnv.net/) to auto-source).
- **Per-command**: `OPENAI_API_KEY=sk-... utilities/whisper.sh ...` — fine for one-offs, tedious for batch.

The repo `.gitignore` excludes `.env` and `.env.*` as a safety net. Don't commit your key.

**Failure modes:**

- `OPENAI_API_KEY not set` → set it, see above.
- `yt-dlp failed to download audio` → usually a stale or region-locked URL. Try downloading manually and pass the file path instead.
- `Whisper API call failed` → check key validity, rate limits, and your OpenAI balance. The script exits non-zero and leaves no partial output.

---

## Known metadata gaps

| Source | What doesn't come through | Why | Workaround |
| --- | --- | --- | --- |
| Freedium mirror (`freedium-mirror.cfd`) | `author`, `published` | Freedium strips Medium's Schema.org | Clip from the original Medium URL instead |
| Medium (original) | Usually fine | — | — |
| arXiv abstract page | `authors`, `published` | DOM shape doesn't match default variable paths | Ingest agent extracts from body |
| Substack / self-hosted blogs | Variable | Site-by-site | First clip reveals what's missing |
| YouTube | Full description, transcript | DOM limitations | Run `prepare.sh` |

None of these are template bugs — they're upstream. The ingest agent treats empty frontmatter fields as a prompt to backfill from the body on first read. Don't worry about perfect frontmatter at clip time; worry about *having* the source.

---

## Adding a new template

Sometimes you'll want a specialty template for a site you use heavily (e.g. a dedicated Substack / Distill.pub / Lil'Log template that knows the site's DOM quirks and sets better defaults).

Rough recipe:

1. Copy an existing template JSON as a starting point.
2. Change:
   - `name` — label in the Clipper UI.
   - `noteContentFormat` — the body markdown (use `\n` for newlines, escape `"` as `\"`).
   - `properties` — YAML frontmatter fields. **Note:** property values use *double-escaped* quotes (`\\\"`) inside filter arguments because the template parser re-processes them, whereas `noteContentFormat` uses single-escaped quotes (`\"`). Copy the pattern from an existing file.
   - `triggers` — URL patterns (wildcards with `*` supported).
   - `noteNameFormat` — filename pattern.
   - `path` — destination subdirectory under `raw/` (use `raw/articles/`, `raw/papers/`, or `raw/talks/` to stay consistent).
3. Drop the new JSON into `utilities/`.
4. Import into Web Clipper and reorder so specialty templates sit above generic ones.
5. Update the table at the top of this file.

If a new `source_type` (beyond `article` / `paper` / `talk`) genuinely makes sense — e.g. `docs` for framework docs, `notebook` for Colab/Jupyter, `thread` for Twitter/X threads, `recipe`, `patent` — also:

1. Add the new type to `CLAUDE.md` frontmatter schema.
2. Add a new subdirectory under `raw/`.
3. Document the expected frontmatter shape in `raw/README.md`.
4. Update the ingest workflow in `CLAUDE.md` if the new type needs non-standard handling.
5. Log a `meta` entry in `log.md`.

---

## Why these files live in `utilities/` rather than `.obsidian/`

- They're **source-controlled first-class artifacts**, not vault-local settings.
- A fresh clone can re-import them without digging through Obsidian internals.
- They're documented alongside the rest of the wiki structure rather than hidden in a dotfolder.
