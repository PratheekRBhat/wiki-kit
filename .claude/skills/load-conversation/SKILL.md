---
name: load-conversation
description: Search and retrieve past LLM conversations from the wiki. Surfaces relevant prior sessions by topic, project, codebase context, or conversation kind — then loads the full session detail into the current context. Also surfaces dangling followups from prior sessions. Use when the owner says "what did we discuss about X?", "find the debug session for Y", "load conversations about Z", "any prior sessions on this?", "what conversations do we have for <project>?", or any variant asking to retrieve or recall a past LLM conversation.
---

# load-conversation

Retrieves past conversation writeups from `raw/conversations/` and surfaces them as context for the current session. The counterpart to `save-conversation` — save captures, load retrieves.

**Why this exists:** conversations are bidirectional. Articles and papers are read-once-ingest-done. Conversations carry session-specific detail (error messages, config values, reasoning chains, environment specifics, dead ends) that topic pages deliberately strip during synthesis. The raw writeup is often the thing you actually need when you're re-encountering the same problem six months later.

**Key principle:** `raw/conversations/` stays a first-class retrieval surface after ingestion. `ingested: true` means "durable ideas extracted to topic pages," not "this file can be ignored."

---

## The flow

### Step 1 — Parse the query

The user's request implies filters. Extract what you can:

- **Topic:** a wiki concept, system, tool, or slug ("kafka", "distributed tracing", "flink memory")
- **Project / service:** a codebase context ("data-forge", "api-client", "gong pipeline")
- **Conversation kind:** debug, research, learning, decision, implementation
- **Time range:** "last month", "from April", "recent" (map to `clipped:` date filtering)
- **Freeform keywords:** anything that doesn't fit the above ("the session where we fixed the rebalancing bug")

If the query is vague ("any conversations about kafka?"), cast wide. If it's specific ("find the debug session where we fixed the Flink direct memory leak in data-forge"), use every filter.

### Step 2 — Search

Run searches in parallel, merge results:

**CLI search (content + tags):**
```bash
obsidian search query="tag:#conversation <topic-or-keyword>" limit=10
```

**Base query (structured):**
```bash
obsidian base:query path="bases/conversations.base" format=md
```

**Frontmatter-targeted search (when project/service context is given):**
```bash
obsidian search query="tag:#conversation codebase_context <project>" limit=10
```

**Related-topics search (pre-ingest cross-references):**
```bash
grep -rl "related_topics:" raw/conversations/ | xargs grep -l "<topic-slug>"
```

Merge and deduplicate by filename.

### Step 3 — Rank and present candidates

For each hit, extract from frontmatter (without reading the full body):
- `title:`
- `key_insight:` — the primary scan line
- `conversation_kind:`
- `original_app:`
- `clipped:`
- `codebase_context.project:` (if present)

Present as a ranked list. Ranking heuristics:
1. `related_topics:` includes the queried topic → high relevance
2. `key_insight:` contains the query terms → high relevance
3. `codebase_context.project:` matches → high relevance (if project was in the query)
4. `conversation_kind:` matches → medium relevance (if kind was in the query)
5. `clipped:` recency → tiebreaker (more recent = slightly higher)

Format:
```markdown
## Conversations matching "<query>"

1. **dbt Gong materialization tests** (learning, Codex, 2026-04-28)
   Insight: How dbt model names, target-specific materialization, and schema YAML interact when the same logical tables exist in both Spark and ClickHouse.
   Project: data-forge / gong-pipeline

2. **Shared logging libraries** (research, Claude Code, 2026-05-01)
   Insight: ...
```

If zero hits: say so clearly. Suggest broadening the search (drop the project filter, try adjacent topic slugs, check `index.md` for related pages whose conversations might be relevant).

### Step 4 — Load selected conversation(s)

On selection (user picks by number or name):

1. Read the full `raw/conversations/<slug>.md` — frontmatter AND body.
2. Surface the body as context for the current session. Don't summarize it — present the key sections so the detail is available.
3. If the conversation has `related_topics:`, briefly note which topic pages it connects to. Offer to run `topic-overview` on any of them for the current wiki state.

### Step 5 — Surface dangling followups

Check the loaded conversation for an "Actionable followups" section (the universal suffix added by `save-conversation`). If present:

1. Read each followup item.
2. Check if it's been addressed: search the wiki for topic pages or source cards that reference the conversation or cover the followup's subject.
3. Present the status:

```markdown
## Dangling followups from this session

- [ ] "Audit the Flink job for the same rebalancing pattern" — no wiki coverage found
- [x] "Check if the auth middleware has the same session timeout issue" — covered in [[agent-harness-security]]
```

This is the "memory across sessions" feature. It turns saved conversations into an accountability surface — things we said we'd do but might have forgotten.

### Step 6 — Offer next actions

After loading, suggest:
- **"Ingest this conversation"** — if it hasn't been ingested yet and the ideas are worth synthesizing into topic pages. Hand off to `wiki-ingest`.
- **"Topic overview on `[[related-topic]]`"** — if the conversation connects to a topic page, offer to run the full retrieval routine for current state.
- **"Save the current session too"** — if the current conversation is building on the loaded one and producing new insights worth capturing.

Don't force any of these. Present as options; the owner decides.

---

## Loading multiple conversations

If the query surfaces 2-3 highly relevant conversations (e.g., "all debug sessions for data-forge"), the user might want to load multiple. Handle this by:

1. Reading each selected conversation.
2. Presenting a **cross-session summary**: common themes, contradictions between sessions, unresolved followups that appear in multiple sessions.
3. Noting which conversations have been ingested (ideas already in the wiki) vs which haven't (session detail only lives in raw).

Don't merge them into one blob. Present each distinctly, then the cross-session observations.

---

## Out of scope

- **Writing or modifying conversations.** That's `save-conversation`'s job.
- **Ingesting conversations into topic pages.** That's `wiki-ingest`'s job. This skill can suggest it, but doesn't execute it.
- **Modifying frontmatter on conversation files.** Read-only retrieval.
- **Searching non-conversation sources.** This skill is conversation-specific. For general wiki retrieval, use `topic-overview` or direct CLI search.

---

## Gotchas

- **`key_insight:` may be missing on older conversations.** The field was added recently. Fall back to `title:` + `why_kept:` for conversations that predate it. Flag the gap so the owner can backfill if he wants.
- **`codebase_context:` may be missing.** Same story — newer field. Don't filter on it exclusively; use it as a boost signal when present.
- **`related_topics:` is pre-ingest.** It reflects what the conversation was ABOUT, not what it contributed to the wiki. Post-ingest, the source card's `contributed_to:` has the authoritative topic links. Check both.
- **Ingested conversations have TWO useful artifacts.** The raw writeup (full session detail) and the source card (compressed citation). Load the raw writeup for session detail; mention the source card for wiki-graph context.
- **The "Actionable followups" section is optional.** Conversations saved before the universal-suffix convention won't have it. Don't fail — just skip the followup check and note "no followups section found."
- **Don't read every conversation file to rank.** Use CLI search + base query to narrow first, read frontmatter for ranking, read full body only on selection. The vault might grow to hundreds of conversations; linear scans won't scale.
