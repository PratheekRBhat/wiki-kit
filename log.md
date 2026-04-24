# Log

Chronological, append-only log of every operation on the wiki. Latest entries go at the bottom.

Entry format:

```
## [YYYY-MM-DD] <op> | <subject>

- Touched: pages created / updated
- Notes: optional, 1-2 lines
```

Quick scan of recent activity:

```bash
grep "^## \[" log.md | tail -10
```

Ops: `ingest`, `read`, `discussed`, `query`, `query-filed`, `lint`, `refactor`, `meta`.

---

<!-- First entry: add a `meta | Wiki initialized` line when you fill in CLAUDE.md. -->
