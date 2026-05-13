---
name: lint
description: Audit the wiki for orphan pages, broken wikilinks, stale claims, index drift, and other quality issues. Iterates the .base files in bases/ for checks Bases can express, runs additional inline checks for what Bases can't reach (precise orphans, broken links, index drift, thin pages). Produces a dated markdown report at bases/lint-reports/<YYYY-MM-DD>.md; does not auto-fix. Use when the owner says "lint the wiki", "audit the wiki", "what's stale", "check the wiki", or periodically (every ~5 ingests).
---

# lint

Audits the wiki for quality issues and produces a dated markdown report. Does not auto-fix — the owner reviews and triages each finding individually.

**Prerequisite every run:** re-read `CLAUDE.md` (especially the Lint operation section) and skim `index.md` for current state.

---

## Two layers of checks

1. **Bases-backed checks** — queries Obsidian Bases can express. Iterate the `.base` files in `bases/`, capture results, surface in the report. The bases are the source of truth for these queries; this skill never re-derives them inline.
2. **Inline checks** — checks Bases can't express (link-graph traversal, cross-file date joins, file-content scanning). Run by reading wiki files directly via grep/file ops.

The skill never auto-fixes. The report is a punch list the owner works through.

---

## The checks

### 1. Pending ingests — *base*

`bases/pending-ingest.base`. Raw files where `ingested: false`. Surface count + the queue length in the report.

### 2. Drafts older than 14 days — *base*

`bases/drafts.base`. Topic pages stuck in `status: draft` past the freshness window.

### 3. Mono-sourced topics — *base, inline fallback*

`bases/mono-sourced.base` attempts `sources.length == 1`. If Bases doesn't evaluate `.length` on multitext properties cleanly, the base returns nothing — in that case fall back to inline: grep each `wiki/<topic>.md` for `sources:` and count list items. Surface topic pages with exactly one source where newer un-ingested sources exist in `raw/` for the same domain (candidates for extension).

### 4. Stale topics — *base proxy + inline precise*

`bases/stale-topics.base` is a proxy (`status == stable` AND `updated` > 90 days). The precise check is cross-file: a topic's `updated:` is older than the most recent contributing source's `clipped:` date. Bases can't join across files; do it inline:

```
for each wiki/<topic>.md:
  read topic.updated and topic.sources[]
  for each source slug:
    read wiki/sources/<slug>.md → clipped
  if max(source.clipped) > topic.updated: surface as stale
```

Report both the base's proxy results AND the precise inline results, labeled distinctly.

### 5. Orphan pages — *base proxy + inline precise*

`bases/orphans.base` uses `file.backlinks.length == 0` (native if Bases supports it) plus a `related == ""` fallback view. Run the base; capture results.

Inline precise check: for each `wiki/<topic>.md`:

1. Collect the canonical slug AND every value in `aliases:`.
2. Grep all of `wiki/`, `wiki/sources/`, `index.md` for wikilink forms referencing any of those names: `[[<name>]]`, `[[<name>#...]]`, `[[<name>|...]]`, `![[<name>...]]`. Exclude the page itself.
3. If zero matches → orphan.

Distinguish two states in the report:

- **Unindexed orphans** — no inbound wikilinks AND not in `index.md`. These are likely lost pages.
- **Indexed orphans** — no inbound wikilinks but listed in `index.md`. Less urgent; the page is discoverable, just not cross-referenced.

### 6. Broken wikilinks — *inline*

Extract every wikilink target from `wiki/`, `wiki/sources/`, and `index.md`. For each target, resolve against:

- `wiki/<target>.md` exists, or
- `wiki/sources/<target>.md` exists, or
- `<target>` appears in any topic page's `aliases:` field.

Anything unresolved → broken. Surface with the source file and line number.

Strip `#section` and `|display-text` suffixes before resolving. A `^block-id` suffix means the target page must exist AND have that block ID; checking block-id existence is a stretch goal — for v1, just check page existence.

### 7. Index drift — *inline*

Two sub-checks:

- **Pages missing from `index.md`**: every `wiki/<topic>.md` should appear as a wikilink somewhere in `index.md`. Diff and surface.
- **Index entries pointing at deleted pages**: every wikilink in `index.md` should resolve. Surface broken entries with line numbers.

MOC pages (`<domain>-moc.md`) belong in the "Maps of Content" group in `index.md`; flag any MOC missing from that group.

### 8. Thin pages — *inline*

Topic pages shorter than 200 words (frontmatter excluded). Either flesh out or delete. Report each with current word count.

Exclude `index.md`, `log.md`, MOC pages (different shape, often shorter), and source cards from this check.

### 9. Untyped pages — *inline*

Topic pages missing a `domain:` field. Phase 1 backfilled every existing page; this check catches new pages that landed without domain assignment.

Surface as: `wiki/<page>.md — no domain field; suggest [<best-guess-cluster>]` if the page's tags + content make the call obvious.

---

## Manual review prompts

These would be lint signals but need semantic reasoning that's not worth automating. Surface them as a closing checklist for the owner's eyeball:

- **Contradictions** — any topic pages whose recent edits introduced claims conflicting with prior content?
- **Missing topic pages** — any terms appearing across 3+ pages that warrant their own page?
- **Scope creep** — any topics drifting into research-heavy AI territory that belong in a sibling wiki?
- **Uncited source contributions** — once block-ref discipline is in place (per `wiki-ingest`), surface source cards whose `contributed_to:` entries don't have corresponding block-refs on the target pages.

---

## Output shape

Path: `bases/lint-reports/<YYYY-MM-DD>.md`. Create the `lint-reports/` directory if missing.

```markdown
# Lint report — YYYY-MM-DD

## Summary

| Check                  | Count |
|------------------------|-------|
| Pending ingests        | N     |
| Drafts (>14 days)      | M     |
| Mono-sourced topics    | O     |
| Stale (proxy / precise)| P / Q |
| Orphans (unindexed / indexed) | R / S |
| Broken wikilinks       | T     |
| Index drift            | U     |
| Thin pages             | V     |
| Untyped pages          | W     |

## Pending ingests

(list)

## Drafts (>14 days)

(list)

## Mono-sourced topics

(list)

## Stale topics

### Proxy (`status: stable` + `updated` > 90d)

(list from base)

### Precise (topic updated < latest source clipped)

(list from inline check)

## Orphan pages

### Unindexed orphans (likely lost)

- `wiki/foo.md` — zero inbound wikilinks, not in index.md

### Indexed orphans (probably fine, eyeball anyway)

- `wiki/bar.md` — zero inbound wikilinks but listed in index.md

## Broken wikilinks

- `wiki/baz.md:42` references `[[nonexistent]]` (no file, no alias)

## Index drift

### Pages missing from `index.md`

- `wiki/quux.md`

### `index.md` entries pointing at deleted pages

- `index.md:47` references `[[gone]]`

## Thin pages

- `wiki/short.md` — 47 words

## Untyped pages

- `wiki/new.md` — no `domain:` field

## Manual review prompts

- Contradictions: any?
- Missing topic pages: any terms in 3+ pages that should have their own page?
- Scope creep: any topics drifting toward a sibling wiki?
- Uncited source contributions (post block-ref): any source cards whose `contributed_to:` entries lack target-page block-refs?
```

If a section's count is zero, omit the section entirely — keep the report scannable.

---

## Log entry

Append a `lint` op to `log.md`:

```
## [YYYY-MM-DD] lint | <one-line summary stats>

- Report: bases/lint-reports/YYYY-MM-DD.md
- Surfaced: <N orphans>, <M broken links>, <O thin pages>, ...
- Notes: 1–2 lines on the most actionable findings. Skip if nothing notable.
```

---

## Gotchas

- **Aliases matter.** Always include `aliases:` values when checking inbound wikilinks and resolving broken-link targets. A page with `aliases: [postgres]` is referenced by `[[postgres]]` even though the file is `postgresql.md`.
- **`index.md` mentions aren't wikilinks for the orphan check.** Index entries are catalog references, not topic-to-topic links. A page can be in `index.md` and still be an orphan in the graph sense (indexed orphan). Surface both states.
- **Block-ref check is partial.** Verifying `[[topic#^block-id]]` resolves correctly requires checking the block ID exists on the target page. v1 just checks page existence; full block-id resolution is a stretch.
- **MOCs are not topic pages.** Exclude `<domain>-moc.md` from thin-page and untyped checks (they have different shape).
- **Bases unreachable** → if the Bases plugin isn't installed or the `.base` files are unparseable, fall back to inline equivalents where possible. Surface a "Bases not available" warning at the top of the report rather than failing the whole run.
- **Don't fix.** No matter how tempting. Lint reports; the owner fixes. Auto-fix is a separate skill (doesn't exist yet).

---

## When in doubt

- **Lint surfaces 100+ items** → still write the full report. the owner decides what to triage. A long report is honest, not noise.
- **A check raises an ambiguous result** (e.g., orphan that's also indexed) → surface both states under their distinct headings.
- **the owner says "lint and fix the orphans"** → run lint, write report, then ask which orphans to act on. Don't bulk-delete or bulk-extend without explicit per-item approval.
- **A previous lint report exists for today** → overwrite it; the report is keyed by date, and re-running gives a more current snapshot. (If the owner wants history, that's `log.md`'s job, not the report file.)
