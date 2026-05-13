---
name: seed-mocs
description: Generate Maps of Content (MOCs) from domain frontmatter on topic pages. Scans the vault for clusters with N+ pages, proposes MOC candidates, generates wiki/<domain>-moc.md files with frontmatter and link sections grouped by tag. Use when the owner says "seed mocs", "audit clusters", "what mocs should we have?", "build mocs", or any variant requesting MOC generation/audit. Content-agnostic — works on any wiki using the same frontmatter conventions.
---

# seed-mocs

Scans topic pages for `domain:` values, tallies cluster sizes, proposes MOC candidates, and generates `wiki/<domain>-moc.md` files per the convention in `CLAUDE.md`. Content-agnostic by design — the skill knows the shape, not the subject matter.

**Prerequisite every run:** re-read `CLAUDE.md` (the MOC page-shape spec and the `### Linking` subsection) and skim `index.md` to see what MOCs already exist.

---

## Overview

MOCs are the middle navigation layer between `index.md` (vault-wide catalog) and individual topic pages (single idea). One MOC per domain cluster. They do not synthesize — they orient. A reader who lands on `streaming-moc.md` should know in one glance which pages exist in the cluster and roughly what each covers.

This skill is content-agnostic: it reads frontmatter, counts primary-domain occurrences, surfaces candidates, and writes the scaffolded file. The hook paragraph is always a TODO placeholder — filling it in is the owner's job.

---

## The flow

### 1. Scan

Read every `wiki/*.md` excluding:

- `wiki/sources/` (source cards — no `domain:`)
- `wiki/digests/` (derived artifacts)
- Any file matching `*-moc.md` (already a MOC — skip to avoid self-reference)

For each file, extract:

- `domain:` list (block-list YAML)
- `tags:` list
- `title:` field (or H1 if `title:` is missing)
- First sentence of body (after frontmatter, after H1) — used for the entry description

### 2. Tally

Build a count per domain value using **primary domain only** (first element in the `domain:` list). This is the cluster-size signal.

Also track all-domains membership (any position in the list) separately — used later in step 6 for populating MOC entries.

Print the tally for the owner's review before doing anything else.

### 3. Surface candidates

Default threshold: domains with primary-count >= 3.

Configurable via argument: `--threshold N` (e.g., `seed-mocs --threshold 5` raises the bar).

Surface each candidate with: domain name, primary count, total count (any-position), and whether a MOC already exists at `wiki/<domain>-moc.md`.

### 4. Prompt per candidate

For each candidate domain, ask the owner: **seed / skip / defer**.

- **seed** — generate the MOC file now.
- **skip** — skip this domain for this run (not recorded anywhere).
- **defer** — add a note in `log.md` that this cluster exists but was intentionally skipped for now.

Do not bulk-seed without per-domain confirmation. Do not guess.

### 5. Generate `wiki/<domain>-moc.md`

For each seeded domain, write a file at `wiki/<domain>-moc.md` with:

**Frontmatter:**

```yaml
---
title: <Domain> — Map of Content
tags: [moc]
domain:
  - <domain-name>
status: stable
updated: YYYY-MM-DD
---
```

**H1:** `# <Domain> — Map of Content`

**Hook paragraph (always a TODO placeholder):**

```
> TODO: 2–3 sentences on what this cluster covers — orientation, not synthesis. Replace this paragraph.
```

**H2 subsections** grouped by tag, in order:

- `## Systems` — pages with `tags: [system]`
- `## Concepts` — pages with `tags: [concept]`
- `## Tradeoffs` — pages with `tags: [tradeoff]`
- `## Patterns` — pages with `tags: [pattern]`
- `## Practices` — pages with `tags: [practice]`
- `## Tools` — pages with `tags: [tool]`
- `## Open questions` — pages with `tags: [question]`

Include only sections that have at least one entry. Omit empty sections entirely.

Each entry: `- [[slug]] — <short description>`. The description is the page title (if different from slug, include it) plus a 6–10 word condensation of the hook sentence.

### 6. Populate entries

Populate each section with pages where the MOC's domain appears **anywhere** in the page's `domain:` list (not just primary). This captures cross-cutting pages — a page primarily in `agentic-systems` that also lists `ai-systems` should appear in both MOCs.

Sort entries alphabetically by slug within each section.

### 7. Update `index.md`

Add the new MOC(s) to a **"Maps of Content"** top-level group in `index.md`. Create the group if it does not exist. Format:

```markdown
## Maps of Content

- [[streaming-moc]] — navigation hub for the streaming cluster (Kafka, Flink, backpressure, exactly-once).
- [[observability-moc]] — navigation hub for the observability cluster (traces, metrics, logs, SLOs).
```

One-line description per MOC. Place the group before the existing "Languages" / "Systems" groups.

### 8. Append to `log.md`

```
## [YYYY-MM-DD] meta | seed-mocs — <list of domains seeded>

- Created: wiki/<domain>-moc.md (x N)
- Updated: index.md (Maps of Content group added/extended)
- Notes: Seeded N MOCs from domain clusters with primary-count >= <threshold>. Hook paragraphs are TODO placeholders — fill in manually.
```

---

## Re-running behavior

If `wiki/<domain>-moc.md` already exists when the owner seeds a domain:

**Prompt:** `<domain>-moc.md` exists — regenerate / merge new entries / skip?

- **regenerate** — overwrite the file entirely. Warn that human-polished prose in the hook will be lost.
- **merge** — add any entries for new topic pages not already listed. Leave existing prose untouched.
- **skip** (default) — leave the file as-is.

**Never silently overwrite a file that exists.** The hook paragraph may have been hand-written. Clobbering it is not the move.

---

## Out of scope

- **Inventing new domain values.** If a topic page lacks a matching domain in the vocab, flag it; do not create a new domain name. That's the owner's call.
- **Writing the hook prose.** The skill plants a TODO. Fill it in manually.
- **Touching source cards.** `wiki/sources/*.md` have `tags: [source]` and no `domain:`; they never appear in MOC entries.
- **Running on sibling wikis.** a sibling wiki and a sibling wiki have their own structure. This skill operates only on the current vault.
- **Tier B / Tier C clusters.** The default threshold is 3. Lower it or pass `--threshold 1` to force-seed a named domain — the owner decides when.

---

## Gotchas

- **Domain values are case-sensitive.** `agentic-systems` and `Agentic-systems` are different. The canonical vocab in `CLAUDE.md` is kebab-lowercase. Check for casing inconsistencies before tallying.
- **MOCs themselves get a `domain:` field.** `streaming-moc.md` has `domain: [streaming]`. This means the MOC would appear in its own cluster on a second scan. The scan step excludes `*-moc.md` files to prevent this.
- **A page with multiple `domain:` values appears in multiple MOCs.** That is correct behavior, not a bug. The tally uses primary domain for threshold decisions; entry population uses any-domain for completeness.
- **Hook paragraphs are user responsibility.** The skill plants a blockquote TODO. Running `seed-mocs` again with `merge` mode will not overwrite that TODO if the user has replaced it with real prose (merge only adds new entries, it does not touch the hook section).
- **`index.md` "Maps of Content" group.** Create it if absent. Do not rename existing index groups.
