# Glossary

A lightweight redirect table. Alternate names, abbreviations, and common misspellings resolve to a canonical topic slug. Not a definitions page — definitions live on the topic pages themselves.

## How it works

- Each entry is one line: `**Alias** → [[canonical-slug]] — optional brief context.`
- Grouped alphabetically by alias.
- The agent maintains this file alongside topic pages: when a new topic page lands, scan for common abbreviations / full-name variants and add entries here.
- When a topic slug is renamed (lint-time refactor), all glossary entries pointing at the old slug must update.

## When to add an entry

- **Abbreviations** used interchangeably with a full name (e.g. "MVCC" ↔ "multi-version concurrency control").
- **Alternate spellings** that are historically common (e.g. "colour" / "color", "LaTeX" / "Latex").
- **Author-specific names** for a concept the wiki has a page for (e.g. "Kleppmann's 'storage engines' ↔ [[storage-engine]]").
- **Common misspellings** frequent enough to be worth redirecting.

## When NOT to add an entry

- Every synonym or near-synonym — this is a redirect table, not a thesaurus.
- Terms that already match a topic slug exactly. No entry needed.
- One-off phrasing from a single source. If it doesn't recur, skip.

---

<!-- Entries go below. Example format:
**MVCC** → [[multi-version-concurrency-control]] — database isolation technique.
**DDIA** → [[sources/book-kleppmann-ddia]] — the Kleppmann book.
-->

_Empty. Entries land as topic pages accumulate._
