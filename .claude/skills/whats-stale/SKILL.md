---
name: whats-stale
description: Surface topic pages that have aged past freshness thresholds, formatted as an actionable refresh queue. Combines the bases/stale-topics.base proxy (status==stable + updated >90 days) with the precise cross-file check (topic.updated < max(source.clipped)) that lint runs. Use when the owner says "what's stale", "stale topics", "what needs refreshing", "refresh queue", or any variant asking about pages overdue for re-ingest or polish.
---

# whats-stale

Surfaces stale topic pages as a prioritized refresh queue. Two complementary checks — a fast proxy from `stale-topics.base` and a precise cross-file date join — are merged, deduped, and classified before output.

**Read budget:** all `wiki/*.md` with non-empty `sources:` (for the precise check), plus their referenced source cards in `wiki/sources/`. Do not read `raw/` files, `index.md`, `log.md`, or `CLAUDE.md`.

---

## The flow

### Step 1 — Run the base proxy

Read `bases/stale-topics.base`. The base returns topic pages where `status == "stable"` AND `updated` is older than 90 days. This is a coarse filter — it will include legitimately stable pages alongside genuinely stale ones, but it catches everything badly overdue.

Capture the result as a list of slugs with their `domain:` and `updated:` values.

### Step 2 — Run the precise cross-file check

For each topic page in `wiki/` that has a non-empty `sources:` list:

```
read topic.updated and topic.sources[]
for each source slug in topic.sources:
  read wiki/sources/<slug>.md → clipped date
max_clipped = max(clipped dates across all source cards)
if max_clipped > topic.updated:
  flag as underweight (a source the topic hasn't absorbed yet)
```

This is the check Bases can't express — it requires joining topic.updated against source card clipped dates across files. The lint skill runs the same logic for its precise stale-topics check.

Capture results as: slug, domain, topic.updated, max_clipped, count of source cards newer than topic.updated.

### Step 3 — Merge and classify

Merge the two result sets. Deduplicate by slug. Classify each entry:

- **Stale** — appears in both the proxy (Step 1) AND the precise check (Step 2). Old page, and at least one source card has been clipped more recently than the topic was last updated. Highest priority.
- **Possibly stale** — proxy only (Step 1). Old page, but no source card is newer — the page may genuinely be stable, or it may simply not have had new sources added. Lower priority; judgment call.
- **Underweight** — precise check only (Step 2). A source card's clipped date is newer than the topic's updated date, but the page isn't old enough to trip the 90-day proxy. The topic has absorbed a source but hasn't been updated to reflect it, or a new source was clipped without triggering a page update. Medium priority.

### Step 4 — Format the refresh queue

Output as a markdown refresh queue, sorted by severity (Stale first, then Underweight, then Possibly stale), then by age within each group (oldest first).

```markdown
# Refresh Queue — YYYY-MM-DD

## Stale (proxy + precise match)

| Slug | Domain | Last Updated | Newer Sources | Suggested action |
|------|--------|-------------|---------------|-----------------|
| kafka | streaming | 2025-08-01 | 2 | Re-check article-kafka-diskless-2025; sections on tiered storage may be outdated |

## Underweight (newer source not yet absorbed)

| Slug | Domain | Last Updated | Newer Sources | Suggested action |
|------|--------|-------------|---------------|-----------------|
| flink | streaming | 2026-02-10 | 1 | article-flink-watermarks-2026 clipped 2026-04-01; review for new material to absorb |

## Possibly stale (proxy only — no newer sources)

| Slug | Domain | Last Updated | Notes |
|------|--------|-------------|-------|
| zero-copy | streaming | 2025-06-15 | Stable topic; low urgency |
```

For the Stale and Underweight entries, name the specific source card(s) that are newer. This is the most actionable part of the output — the owner can go directly to those source cards and decide if the new material warrants a topic page update.

---

## Out of scope

- Actually refreshing pages, extending them with new material, or updating timestamps.
- Batch-deleting or archiving stale pages (that's an audit decision, not a retrieval one).
- Comparing topic-page content to source-card content semantically (would require reading both in full for every entry; do it per-page, not in bulk).

---

## Gotchas

- **90-day proxy produces false positives.** Some topics are genuinely durable — `zero-copy`, `lsm-tree`, established language concepts — and may sit at `status: stable` untouched for years without being wrong. The "Possibly stale" bucket exists precisely for this: surface it, but don't call it urgent.
- **`clipped:` vs `published:` on source cards.** Use `clipped:` (when the owner clipped it) not `published:` (when the source was written). The clipped date is when the knowledge entered the pipeline; a source published in 2020 and clipped in 2026 is a 2026 input.
- **Topics with no `sources:` list skip the precise check.** These are either seed pages (never had a source) or pages that lost their source list. Surface them as a footnote: "N topic pages have no sources: list and were excluded from the precise check."
- **Source cards with no `clipped:` date.** Skip that source card for the date join and note it; missing clipped dates are a lint signal (the lint skill catches them separately).
- **The base may not be runnable directly.** If Obsidian Bases isn't available (CLI context, no plugin), fall back to the inline equivalent: grep `wiki/*.md` for `status: stable` and parse `updated:`, then filter to entries where `(today - updated).days > 90`. The result is equivalent to the base.
