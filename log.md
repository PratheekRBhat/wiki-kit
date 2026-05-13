# Log

Chronological, append-only log of wiki operations. Latest entries go at the bottom.

Entry format:

```text
## [YYYY-MM-DD] <op> | <subject>

- Touched: pages created / updated
- Notes: optional, 1-3 lines
```

Ops:

- `ingest`
- `read`
- `discussed`
- `query`
- `query-filed`
- `lint`
- `digest`
- `refactor`
- `meta`

Quick scan:

```bash
grep "^## \\[" log.md | tail -10
```

---

<!-- First useful entry is usually a `meta | Wiki initialized` line after the owner customizes CLAUDE.md or starts ingesting. -->
