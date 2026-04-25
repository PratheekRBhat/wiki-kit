---
description: Save an LLM conversation as a source in raw/conversations/. Writes a writeup (RCA / findings / explainer / ADR), not a transcript or summary.
---

You are saving an LLM conversation to the wiki's raw layer as a new source. The body is **not** a transcript and **not** a summary — it's a *writeup* whose shape matches what the conversation actually was.

User's hint (if any): $ARGUMENTS

## Step 1 — Get the content

Ask the user for the conversation source. Accept any of:

- **Pasted transcript** — they paste the back-and-forth into the chat.
- **File path** — they point at a file (markdown export from Claude.ai, JSON from ChatGPT, plain text, anything readable).
- **Current context** — they say "the conversation we just had" or similar. Only valid if the conversation actually happened in *this* Claude Code session and you can reconstruct it from your context window. If you have to invent or guess, ask for a paste instead.

If the user's `$ARGUMENTS` already pointed at one of these (e.g. a file path), proceed without re-asking.

## Step 2 — Get metadata

Ask the user (combine into one prompt; let them answer terse):

1. **Title** — short, durable. If they don't have one, propose 2–3 options based on the content and let them pick.
2. **Originating app** — Claude Code, Claude.ai, ChatGPT, Cursor, Perplexity, etc. If obvious from the source, just confirm rather than ask.
3. **URL** — only if they have a shared link. Optional.
4. **`why_kept`** — one line on why this earned a slot. Future-you will thank you. Optional but encouraged.
5. **Conversation kind** — pick one: `debug`, `research`, `learning`, `decision`, `other`. If you can clearly tell from the content, propose it and let the user override.

## Step 3 — Write the writeup

The body is **not** a transcript and **not** a summary. It's a writeup whose shape matches the conversation kind. Use the wiki's teaching voice (re-read `CLAUDE.md`'s "Teaching voice" section before writing).

Pick the shape based on `conversation_kind`:

### `debug` — RCA-style

```markdown
## Problem

What was broken. Symptom, environment, what the user was actually trying to do.

## What we tried

Each hypothesis pursued, what evidence ruled it in or out. Honest about dead ends — they teach as much as the fix.

## Root cause

The actual cause, traced to the mechanism. Not just *what* but *why* it manifested as the observed symptom.

## Fix

What was changed and why this resolves it. Note any tradeoffs (e.g. "this fixes the leak but adds a startup cost of N seconds").

## Followups / open threads

Anything left dangling — related code paths to audit, monitoring to add, regressions to watch for.
```

### `research` — findings-style

```markdown
## The question

What were we actually trying to figure out. Concrete; not "explore X" but "decide between A and B for use case C".

## What we found

The substantive answer. Cite the sources or reasoning that got us there. If the answer is "it depends", spell out *what* it depends on.

## Open threads

Questions raised but not resolved. Promote to `[question]`-tagged topic pages at ingest if they earn it.
```

### `learning` — narrative explainer

```markdown
## Hook / motivation

Why this idea matters. Concrete problem, failure mode, or moment of confusion that led to the conversation.

## The thing

The actual explanation. Mechanism, not just name. Walk through it with a concrete trace.

## Worked example

A specific example — a real system, a real piece of code, a real scenario. Not abstract.

## Gotchas / edges

Where the simple story breaks down. The "ah, but…" cases that didn't fit the main explanation.
```

### `decision` — ADR-style

```markdown
## Context

The situation that forced a decision. Constraints, deadlines, stakeholders.

## Options considered

Each option with its tradeoffs. Don't sandbag the rejected ones — write them as if you were arguing for them.

## Decision

What was chosen. Not just *what* but *why* — the specific factor that tipped the balance.

## Consequences

What this commits us to. What becomes harder. What follow-on work this triggers.
```

### `other`

Pick whichever shape teaches best. Be honest about why you picked it.

### Voice rules (apply across all shapes)

- Teach, don't transcribe. The reader is future-you, not someone who needs the back-and-forth.
- Hook the opening. No "In this conversation, we discussed…". Start with the problem or the finding.
- Trace mechanisms; don't just name them.
- Ground in concrete details — actual error messages, actual config values, actual stack traces. The conversation has them; preserve them.
- Capture the aha moment if there was one.
- Anti-patterns (per `CLAUDE.md`'s Teaching voice): no "we", no Wikipedia openings, no marketing words, no throat-clearing.

If the conversation had quotable lines that capture an idea sharply, include them under a "## Quote worth keeping" section near the bottom — same convention as a source card.

## Step 4 — Frontmatter

```yaml
---
source_type: conversation
title: "<title>"
participants:
  - "user"
  - "<other-participant>"   # e.g. "claude-opus-4.7", "chatgpt-gpt-4o", "gemini-2.5-pro"
original_app: "<app>"        # Claude Code, Claude.ai, ChatGPT, Cursor, ...
url: "<url-if-shared>"       # empty string if not shared
clipped: <YYYY-MM-DD>        # today's date
conversation_kind: "<kind>"  # debug | research | learning | decision | other
why_kept: "<one-line>"       # empty string if not provided
tags: []
ingested: false
---
```

## Step 5 — Save

Slug: `conversation-<short-title-slug>`. Slugify lowercase, hyphens for spaces, strip punctuation. Keep it short — 3–5 words max.

Path: `raw/conversations/<slug>.md`.

Write the file: frontmatter, then the writeup body.

## Step 6 — Report

Tell the user:

- The file path written.
- The conversation kind chosen.
- A one-sentence description of what the writeup covers.
- A reminder that the source isn't ingested yet — they can run `wiki-ingest` on it whenever, or let `daily-digest` pick it up automatically.

**Do not** trigger ingest. **Do not** touch `wiki/`. **Do not** modify `index.md` or `log.md`. This command's job is just to land a clean source in `raw/conversations/`.
