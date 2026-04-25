---
name: daily-digest
description: Process all pending sources in raw/ (run prepare.sh, then wiki-ingest on each), then write a curated highlights digest at wiki/digests/YYYY-MM-DD.md. Use when the owner says "run the digest", "process today's clippings", "catch up the wiki", or when triggered by a scheduled task.
---

# daily-digest

Batches an ingest session across everything pending in `raw/`, then writes a short editorial "what was interesting" at `wiki/digests/<date>.md`. The digest is the new artifact; everything else rides on existing skills.

**Prerequisite every run:** re-read `CLAUDE.md` (especially "Operations" and "Teaching voice") and skim `index.md` for current wiki state.

---

## The 5-step flow

```
1. Prepare  → utilities/prepare.sh (wraps orphans, fetches PDFs + transcripts)
2. Ingest   → wiki-ingest per source that's still ingested: false
3. Track    → collect topic pages created / extended across the run
4. Digest   → write wiki/digests/<date>.md with 3–5 curated highlights
5. Log      → digest op in log.md
```

### 1. Prepare

Run `utilities/prepare.sh` from the repo root. This does three things in one pass:

- **Orphan-wrap**: any manually-dropped PDFs or audio files in `raw/{articles,papers,talks}/` without a companion `.md` get a stub frontmatter wrapper auto-generated (with `clipped:` set from the file's mtime).
- **Backfill**: PDFs downloaded for papers, transcripts fetched for talks (YouTube auto-captions by default; `-w` flag routes through Whisper for higher quality).
- **Skip**: sources already marked `ingested: true`, or already fully prepared.

If the digest was triggered with a Whisper preference, pass `-w` through. If the queue looks large, optionally dry-run first (`prepare.sh -n`) to estimate scope.

### 2. Ingest

For each file where `ingested: false`:

- Invoke the `wiki-ingest` skill on it. Let it do its thing: read, decide extend vs create, write topic pages, write source card, flip the flag, log.
- **One source at a time.** Do not batch-read the raw pile into a single context — that's how you lose track of which source seeded what.
- If any source raises an ambiguous-scope question, **stop and ask the owner** before continuing. The digest flow doesn't get to silently resolve ambiguity.
- If a single source fails (thin content, unreachable source, etc.), log the failure and continue with the rest. Don't let one bad source block the whole digest.

### 3. Track

Maintain a running manifest across step 2:

- **Sources processed** — source card slugs.
- **Topic pages created** — new slugs (with a one-line note on what the idea is).
- **Topic pages extended** — existing slugs (with a one-line note on which section got the extension).
- **Questions raised** — any `[question]`-tagged pages seeded or flagged during ingest.
- **Failures** — anything that couldn't land.

This manifest is the raw material for the digest.

### 4. Digest

**Skip the digest write if fewer than 2 topic pages were touched.** Ingest already happened (step 2); a "digest" of one topic is just the topic page itself. In the skip case, still log a `digest` op with `skipped: queue thin (<2 topics)`.

Otherwise, write `wiki/digests/<YYYY-MM-DD>.md`:

```yaml
---
date: YYYY-MM-DD
sources:
  - <source-slug-1>
  - <source-slug-2>
topics:
  - "[[topic-a]]"
  - "[[topic-b]]"
updated: YYYY-MM-DD
---
```

**Body: 3–5 curated highlights.** Not every topic page touched gets a highlight. Pick the 3–5 that were most interesting, most load-bearing, or that form the best through-line. Each highlight is:

- A short, hook-y heading (2–5 words). *"Why branching is cheap"*, not *"Content-addressed storage in Git"*.
- 1–2 paragraphs of writeup, in the wiki's teaching voice (hook, motivate, trace, ground — see `CLAUDE.md`).
- A wikilink to the full topic page at the end: *"→ [[git-content-addressed-storage]] for the full trace."*

Optional tail: a **"What else landed"** bullet list — topic pages touched but not highlighted, each as a one-liner with a wikilink. Skip if there are none.

**The digest IS:**
- An editorial "what was interesting today" — your perspective as the agent on what stood out.
- A way for the owner to scan what they learned in 60 seconds and decide whether to go deeper.
- Written in the wiki's teaching voice — not a Wikipedia stub, not a list of page titles.

**The digest is NOT:**
- A summary of every source (that's what source cards are for).
- A restating of topic page content (link to them, don't duplicate).
- A TL;DR (the owner doesn't need an executive summary of their own wiki).

If the topic pages span wildly different domains, don't force a through-line. The digest can just be 3–5 independent highlights. Honest beats forced.

### 5. Log

Append to `log.md`:

```
## [YYYY-MM-DD] digest | <N sources, M topics touched>

- Created: wiki/digests/YYYY-MM-DD.md
- Sources: <source-slug-1>, <source-slug-2>, ...
- Topics: [[topic-a]] (new), [[topic-b]] (extended §section), ...
- Notes: 1–2 lines on the through-line of the day's sources, if there was one.
```

---

## Running on a schedule

This skill is designed to run unattended on a cadence. Three sane options, depending on your setup:

**Claude Code Routines (cloud).** Runs on Anthropic's infrastructure and survives closed laptops. Requires a Pro/Max/Team plan and Claude Code on the web. Rate limits: Pro 5/day, Max 15/day, Team/Enterprise 25/day — well within a single daily digest. Set up via the Claude Code web UI; point the routine at this skill with a prompt like *"run the daily-digest skill"*.

**Claude Cowork scheduled tasks (desktop).** macOS/Windows only. Use the `/schedule` slash command inside Cowork. Runs only while the desktop app is open and the machine is awake — skipped runs execute once you wake the machine back up.

**Cron + `claude -p` headless.** Most portable, works on Linux, no platform lock-in. Example crontab:

```cron
0 22 * * * cd /path/to/your/wiki && claude -p "run the daily-digest skill" >> .digest.log 2>&1
```

Pick what fits. The skill itself doesn't care how it's triggered — only that the trigger lands in the wiki directory and invokes an agent with access to this skill.

---

## When in doubt

- **Pending queue is empty** → log `digest | skipped: queue empty` and exit cleanly.
- **All sources in the queue fail** → log failures individually, log `digest | all sources failed` at the end. Don't write a digest file for an empty output.
- **Digest would have 2+ topics but they're all thin extensions (one line each)** → write the digest anyway, but be honest in the highlights ("not much new here today; [[X]] got a small note on Y, [[Z]] got a citation"). A slow day is still a day.
- **Owner runs the digest after a long gap** → the queue might be 20+ pending sources. Process them all. Name the digest after the run date, not the earliest `clipped:` date.
- **Two days' worth of sources land in one digest run** → fine. The digest is keyed by *when the digest ran*, not by when sources were clipped. Don't try to retroactively split.
- **A source looks like it belongs in a different wiki** (if multiple bounded wikis are in play) → flag to the owner, don't silently ingest.
