---
name: inbound-links
description: Find every inbound wikilink to a topic page, including alias-mediated, block-ref, and embed forms. Returns a grouped list (by source dir) with context snippets. Use when the owner says "backlinks <slug>", "inbound links <slug>", "what references <slug>", "who links to <slug>", or any variant asking what cites a given topic.
---

# inbound-links

Finds and groups every inbound reference to a topic page across the vault. Covers canonical slug, all aliases, and all wikilink forms including block-refs and embeds.

**Read budget:** `wiki/<slug>.md` for alias extraction (required), then grep-only over `wiki/`, `wiki/sources/`, `index.md`. Read the full content of referencing files only if a context snippet isn't sufficient to understand the nature of the reference.

---

## The flow

### Step 1 — Resolve the slug

Same resolution as `topic-overview`:

1. Check if `wiki/<arg>.md` exists — if yes, resolved.
2. If not, grep `wiki/*.md` frontmatter for `aliases:` blocks containing `<arg>`.
3. If still no match, report unresolved and suggest close candidates.

### Step 2 — Build search patterns

From the canonical slug and every alias in `aliases:`, build the full set of wikilink forms to search for:

For each name in `{slug} ∪ aliases`:
- `[[<name>]]` — standard wikilink
- `[[<name>#` — section link (partial match to catch all section variants)
- `[[<name>|` — aliased display link (partial match)
- `![[<name>` — embed (partial match, catches section and plain forms)

Run a case-insensitive grep — Obsidian wikilink resolution is case-insensitive, so `[[Kafka]]` and `[[kafka]]` are the same link.

### Step 3 — Grep the vault

Run the patterns against:
- `wiki/*.md` — topic pages (high signal)
- `wiki/sources/*.md` — source cards (medium signal; these cite the topic as a contribution target)
- `index.md` — navigation catalog (low signal; catalog entries are not topic-to-topic arguments)

Capture for each hit:
- Source file path
- Line number
- ~80 characters of surrounding context (the line content)

Exclude the topic page itself from results.

### Step 4 — Group and format results

Group hits by source directory, then sort alphabetically by source file within each group.

```markdown
## Inbound links to `[[<slug>]]`

Resolved from: `wiki/<slug>.md` (aliases: [<alias1>, <alias2>])
Total references: N

### Topic pages (wiki/)

| Source | Line | Context |
|--------|------|---------|
| [[kafka]] | 14 | `...builds on [[zero-copy]] to minimize...` |
| [[flink]] | 42 | `![[zero-copy#sendfile]]` |

### Source cards (wiki/sources/)

| Source | Line | Context |
|--------|------|---------|
| [[sources/article-kafka-internals]] | 8 | `contributed_to: [[zero-copy]]` |

### Index catalog (index.md)

| Line | Context |
|------|---------|
| 23 | `- [[zero-copy]] — avoiding unnecessary user-space copies...` |
```

If a group has zero hits, omit it entirely.

### Step 5 — Classify and interpret

After the table, add a brief interpretation:

- **High-signal references** — topic pages whose body mentions the slug (not just frontmatter `related:` or `sources:` lists). These pages actively reason about the topic.
- **Frontmatter-only references** — topic pages where the slug appears only in `related:` or `sources:` frontmatter fields. These are declared connections, not in-text arguments. Still useful for graph navigation, but lower signal for synthesis.
- **Source card citations** — `contributed_to:` entries are how source cards declare what they fed into. Expected and normal; not a surprising link.
- **Index catalog** — catalog entry. Confirms the page is indexed; not a meaningful graph connection.

If the total reference count is zero: the page is a graph orphan. Note this clearly — the owner may want to run `lint` to catch it formally, or add it to `index.md` and `related:` on adjacent pages.

---

## Out of scope

- The link graph visualization — Obsidian's native graph view does this interactively. This skill is for scripted/agent retrieval where you need the list, not the picture.
- Backlink frequency analytics or ranking by citation count (could be added as `inbound-links <slug> --sort frequency`).
- Filtering results by domain (potential future flag: `inbound-links <slug> --domain streaming`).
- Outbound links from the target page (that's `wiki/<slug>.md`'s `related:` field — just read it).

---

## Gotchas

- **Alias search must be frontmatter-scoped for resolution, but vault-wide for hits.** When resolving which file owns an alias, grep only frontmatter (between `---` delimiters). When searching for inbound links, grep the full file content — an alias can appear as a wikilink anywhere in the body.
- **Block-ref citations (`[[slug#^block-id]]`) are high-value hits.** A block-ref means another page is citing a specific claim, not just the topic generally. Call these out explicitly in the output — they indicate strong provenance links.
- **Embed forms (`![[slug]]`) appear in digest notes and MOC pages.** MOC embeds are structural (the MOC pulls in the topic's hook paragraph) — low-signal for graph connectivity. Digest embeds are even lower signal (derived artifacts). Note the context to distinguish.
- **`index.md` is flat text with wikilinks, not a graph node.** References there are catalog entries. Include them in the output for completeness but don't count them toward "N pages reference this topic."
- **Partial matches on section and display forms.** The `[[<slug>#` and `[[<slug>|` patterns are partial — they'll catch `[[kafka#replication|Kafka replication]]` and `[[kafka#log-compaction]]` in a single grep pass. Don't over-filter; show the full line context so the owner can see what the reference is about.
