---
name: topic-overview
description: Given a topic slug, run the full retrieval routine to answer "what do we know about X?" — reads the topic page, its MOC for cluster context, its source cards, its top inbound wikilinks, then synthesizes an answer in the wiki's teaching voice. Use when the owner says "topic overview <slug>", "tell me about <slug>", "what do we know about <slug>", "deep dive on <slug>", or any variant asking for an integrated view of a topic.
---

# topic-overview

Retrieves and synthesizes everything the wiki knows about a given topic. The output is not a dump of file contents — it's a curated answer in the wiki's teaching voice, drawing on topic, MOC context, source cards, and backlinks together.

**Read budget:** `wiki/<slug>.md` (required), up to 5 `wiki/<domain>-moc.md` files, up to all source cards in `sources:`, up to 3 referencing pages from backlinks. Do not read `index.md`, `log.md`, `CLAUDE.md`, sibling wiki files, or `raw/` unless the topic page explicitly references them.

---

## The flow

### Step 1 — Resolve the slug

The argument `<arg>` may be the canonical slug or an alias. Resolution order:

1. Check if `wiki/<arg>.md` exists — if yes, resolved.
2. If not, grep `wiki/*.md` for `aliases:` blocks containing `<arg>`. Use the matching file's slug.
3. If still no match, tell the owner the slug didn't resolve and suggest close candidates (from `index.md` or a filename glob).

Never guess. If resolution is ambiguous (two pages with overlapping aliases), surface both and ask.

### Step 2 — Read the topic page

Read `wiki/<resolved-slug>.md` in full. Extract:

- `domain:` — list of domains (drives which MOCs to check)
- `tags:` — topic type (concept, system, tool, etc.)
- `aliases:` — all known aliases (needed for backlink search in Step 5)
- `sources:` — list of source slugs (drives Step 4)
- `related:` — cross-referenced topic pages
- Body — hook, mechanism, tradeoffs, examples, open questions

Note any `status:` value. A `status: stale` page is useful as a starting point but may have outdated claims — flag this in the synthesis.

### Step 3 — Read MOC cluster context

For each value in `domain:`, check if `wiki/<domain>-moc.md` exists. If yes, read it.

The MOC gives cluster context: what other topics live in the same domain, how they relate, and where this topic sits in the overall cluster. Use this for orientation in the synthesis — it tells you what the topic is adjacent to, not what it says.

The five Tier A MOCs are: `streaming-moc`, `data-engineering-moc`, `observability-moc`, `agentic-systems-moc`, `ai-systems-moc`. Other domains don't yet have MOCs; if none exists, skip this step for that domain.

### Step 4 — Read source cards

For each slug in the topic page's `sources:` list, read `wiki/sources/<slug>.md`.

Source cards are reading notes — TL;DR, key claims, what was novel. Use them to:
- Understand where the knowledge came from and what specific sources argued.
- Surface any per-source nuances that didn't make it onto the topic page (contradictions, hedged claims, dated context).

Don't restate the source card wholesale. Extract the specific framing or claim that enriches the synthesis.

### Step 5 — Find inbound wikilinks

Grep `wiki/`, `wiki/sources/`, and `index.md` for references to this page. Build the search patterns from the canonical slug and every alias:

- `[[<slug>]]`, `[[<slug>#section]]`, `[[<slug>|display text]]`
- `![[<slug>]]`, `![[<slug>#section]]` (embed forms)
- Same patterns for each alias in `aliases:`

Exclude the topic page itself from results.

Read the top 3 most relevant referencing pages — prioritize pages whose backlink appears in their body (not just frontmatter `related:` or `sources:` lists), since body mentions mean the page actively reasons about this topic. Skip `index.md` catalog entries (low signal — they're navigation, not argumentation).

### Step 6 — Synthesize

Answer the implicit question: "what do we know about `<slug>`?" in the wiki's teaching voice.

Structure:

1. **What it is and why it matters** — hook from the topic page. The problem it solves, the mechanism, the stakes.
2. **The mechanism or core behavior** — one concrete trace or example. Ground in a real language, framework, or system.
3. **Key tradeoffs or gotchas** — pulled from the topic page and sharpened by source-card nuances. Include source attribution where a specific source argued a point distinctly.
4. **How it relates to adjacent topics** — from `related:`, MOC context, and backlink pages. One sentence per connection; link to the relevant pages.
5. **Open questions / what the wiki doesn't yet know** — from the topic page's open questions section or from source-card notes flagging limitations.
6. **Sources consulted** — a terse list of source cards read, in case the owner wants to drill deeper.

Keep the synthesis proportional to what the wiki actually has. If the topic page is thin (one source, short body), say so rather than padding. If source cards contradict the topic page, surface the contradiction explicitly — don't paper it over.

Teaching voice anti-patterns to avoid here: definition-first openings, bullet walls, paper-abstract phrasing, hedged claims that hide the actual tradeoff. See `CLAUDE.md` → Teaching voice.

---

## Out of scope

- Editing the topic page or any source cards.
- Creating new topic pages or extending existing ones.
- Modifying frontmatter, status fields, or timestamps.
- Comparing two topics (that's a separate synthesis task — do it ad-hoc in chat, don't invoke this skill twice and stitch).
- Reading `raw/` source files.

---

## Gotchas

- **Alias resolution can be ambiguous.** If `[[postgres]]` is an alias for `postgresql.md` and also appears as a term in another page's body, the grep for aliases returns both. Narrow to frontmatter-only alias matches.
- **MOC context is orientation, not synthesis.** The MOC tells you the cluster shape; the synthesis comes from the topic page and source cards.
- **Source cards are reading notes, not summaries.** Cite them for their framing; don't restate them as if they were the truth.
- **`index.md` backlinks are catalog entries.** A reference in `index.md` means the page is indexed, not that it's meaningfully connected to another topic. De-emphasize in the synthesis; don't exclude (it confirms the page is in the vault).
- **`status: stale` is a flag.** If the topic page is marked stale, note it at the top of the synthesis. The content may still be accurate, but the owner should know.
- **Missing MOC for the domain.** Eleven domains don't yet have Tier A MOCs. If `domain:` contains one of these, skip Step 3 for that domain and note it in the synthesis ("no MOC for `databases` yet — cluster context from `related:` links only").
