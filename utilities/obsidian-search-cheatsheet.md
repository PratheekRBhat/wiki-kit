# Obsidian Search Cheatsheet

Quick reference for finding things in this vault. Not a tutorial — assumes you know what you're looking for.

---

## Obsidian search syntax

Open with `Ctrl/Cmd+Shift+F`. These operators compose — boolean, path, and content filters all work together.

| Operator | What it does | Example |
|---|---|---|
| `tag:#name` | Pages with a specific tag | `tag:#system` |
| `path:` | Filter by directory or path segment | `path:wiki/sources` |
| `file:` | Filter by filename (slug match) | `file:kafka` |
| `content:` | Match in body text (not frontmatter) | `content:"backpressure"` |
| `line:` | Both terms appear on the same line | `line:(kafka backpressure)` |
| `"exact phrase"` | Literal phrase match | `"copy-on-write"` |
| `/regex/` | Regular expression match | `/updated: 2025-\d+/` |
| `OR` | Either term | `tag:#system OR tag:#tool` |
| `-` | Exclude (prefix) | `path:wiki -path:sources` |
| `()` | Group for precedence | `(kafka OR flink) tag:#system` |

Obsidian search is case-insensitive by default. Frontmatter values are matched by `content:` but not by `tag:` (use `tag:` only for proper `tags:` list values).

---

## Obsidian CLI commands

Use the `obsidian:obsidian-cli` skill for programmatic vault operations — reading notes, listing files, frontmatter queries, and vault-wide search. Don't re-derive these here; see the skill directly.

Common use cases the CLI covers:
- Read a single note by slug
- List notes matching a frontmatter property value
- Search vault-wide and get results with context
- Get a note's frontmatter as structured data

When a search question needs results piped into further processing (e.g., collecting all `sources:` slugs from stale pages), reach for the CLI skill rather than manual grep.

---

## Bases catalog

Six saved queries in `bases/`. Open any `.base` file in Obsidian to run it. The lint skill also reads these — don't duplicate the results.

| Base file | What it surfaces | When to use it |
|---|---|---|
| `pending-ingest.base` | `raw/` files with `ingested: false` | Before a digest run; to check ingest backlog |
| `drafts.base` | Topic pages with `status: draft` untouched for 14+ days | Periodic cleanup; finding half-finished pages to promote or delete |
| `mono-sourced.base` | Topic pages backed by exactly one source entry | Finding pages most in need of a second source or extension |
| `stale-topics.base` | `status: stable` pages not updated in 90+ days (proxy) | First pass for the refresh queue; see also `whats-stale` skill for the precise check |
| `orphans.base` | Topic pages with zero inbound backlinks (or no `related:` entries as a proxy fallback) | Finding pages that exist but are disconnected from the graph |
| `conversations.base` | All conversation sources — clipped, ingested, pending | Scanning saved sessions before starting a related conversation |

Notes on the proxy-based bases: `stale-topics.base` uses a 90-day threshold — it will catch all badly stale pages but also legitimately stable ones. `orphans.base` uses `file.backlinks.length == 0` natively; if Bases doesn't evaluate that, the fallback view uses `related == ""` which is weaker. The lint skill and `whats-stale` skill run the precise cross-file checks that Bases can't express.

---

## MOCs catalog

MOCs are the middle navigation layer between `index.md` (vault-wide) and topic pages (single idea). One MOC per domain cluster. The `seed-mocs` skill generates them from `domain:` frontmatter once a cluster reaches 3+ pages. Run `seed-mocs` to see what clusters are ready.

---

## Common recipes

### "All system pages in a given domain"

```
tag:#system path:wiki content:"<domain-name>"
```

Or open the relevant `mocs/<domain>-moc.md` and scan the Systems section — faster when you want context alongside the list.

### "Pages updated in the last 7 days"

Obsidian's native search doesn't support relative date math on frontmatter. Use the CLI skill with a frontmatter query filtering `updated >= YYYY-MM-DD`, or run:

```bash
grep -rl "updated: $(date +%Y-%m)" wiki/
```

Replace the date prefix as needed.

### "What references `[[<slug>]]`?"

Run the `inbound-links` skill: `inbound-links <slug>`. Returns every wikilink, embed, and alias-mediated reference to the page, grouped by source directory with context snippets.

### "What's stale this month?"

Run the `whats-stale` skill. It combines the `stale-topics.base` proxy with the precise cross-file date check (topic.updated < max(source.clipped)), then formats results as a refresh queue sorted by severity.

### "Topic pages with `status: draft` past 14 days"

Open `bases/drafts.base` in Obsidian. The base runs the filter directly and shows days-stale per page.

### "Pages that have no inbound links"

Open `bases/orphans.base` — the primary view uses `file.backlinks.length == 0`. For the precise check (including alias resolution), run `lint` — check 5 in the lint report.

### "Source cards that contributed to `[[<slug>]]`"

```
path:wiki/sources content:"[[<slug>]]"
```

Or check `wiki/<slug>.md`'s `sources:` frontmatter list, then read each card.

### "What do we know about X?"

Run `topic-overview <slug>`. The skill reads the topic page, its MOC cluster context, its source cards, top inbound wikilinks, and synthesizes an answer. Faster than manually chasing wikilinks.

### "Find all pages in a domain without a MOC"

```bash
grep -l "domain:" wiki/*.md | xargs grep -L "moc" | head -20
```

Then check `index.md`'s Maps of Content group to see which clusters lack coverage.

### "Pages using a specific source"

```
path:wiki content:"<source-slug>"
```

Replace the source slug with the one you're looking for. The `content:` operator matches both frontmatter `sources:` entries and inline `[[sources/...]]` citations.

### "Find saved conversations about X"

Run the `load-conversation` skill with the topic or keyword. It searches `raw/conversations/` by tag, `key_insight:`, `related_topics:`, and `codebase_context:` in one pass.
