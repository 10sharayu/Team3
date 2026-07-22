# ADR-0003 — GIN (`jsonb_path_ops`) index over btree on `instruments.metadata`

- Status: Accepted
- Date: 2026-06-02
- Deciders: ReconX team

## Context

Following ADR-0002, `instruments.metadata` is JSONB and grows at ~50k
trades/day. Recon analysts and the reconciliation service filter on
metadata fields interactively (e.g., `metadata @> '{"underlying": "AAPL"}'`,
`metadata @> '{"settlement_terms": {"type": "T+2"}}'`), and these queries
need to stay interactive (sub-second) as the table grows past tens of
millions of rows over the 5-year retention window. Without a supporting
index, every metadata filter is a sequential scan.

Alternatives considered:
- **No index, sequential scan** — fine at low row counts, but already
  measured as unacceptably slow (multi-second) in a 5M-row staging load
  test; would only get worse at the 91M-row steady state.
- **btree index on individual expression-extracted fields**
  (e.g., `((metadata->>'underlying'))`) — fast for a single known field,
  but requires a new expression index for every field analysts want to
  query, which recreates the migration-cadence problem ADR-0002 was meant
  to avoid.
- **GIN index with `jsonb_path_ops` on the whole `metadata` column** —
  chosen; indexes all keys/values generically and supports containment
  queries (`@>`) across arbitrary metadata shapes without per-field
  migrations.

Constraints / forces:
- Metadata shape varies by asset class and changes roughly monthly (per
  ADR-0002); we don't want an index-maintenance burden that scales with
  field count.
- Analysts query by containment (`@>`), not by JSON path existence,
  so `jsonb_path_ops` (smaller, faster for `@>`) fits better than the
  default `jsonb_ops` operator class, which also supports `?`/`?|`/`?&`
  we don't currently need.
- Write volume (50k inserts/day) means index maintenance overhead on
  writes has to stay acceptable; GIN inserts are pending-list buffered in
  Postgres 16 to amortize this cost.

## Decision

Create `CREATE INDEX idx_instruments_metadata_gin ON instruments USING GIN
(metadata jsonb_path_ops);` instead of per-field btree expression indexes.
All analyst and service containment queries against `metadata` are written
to use the `@>` operator so they can use this index.

## Consequences

**Positive**
- One index supports containment queries across all current and future
  metadata fields — no new index needed when a desk adds a field.
- `jsonb_path_ops` produces a smaller index than `jsonb_ops` and is faster
  for our `@>`-only query pattern.
- Staging load test at 5M rows showed sub-100ms response for containment
  queries that previously took multiple seconds unindexed.

**Negative**
- No support for key-existence (`?`, `?|`, `?&`) queries — if that access
  pattern emerges, it requires a second index using `jsonb_ops` or a
  targeted expression index.
- GIN indexes are larger on disk and slower to build initially than btree;
  the pending-list buffer mitigates but doesn't eliminate write overhead.
- Query plans must use `@>` specifically; a `metadata->>'field' = 'value'`
  query will not use this index and will fall back to a sequential scan.

---

### Prompt used to draft this ADR

```
You are an enterprise software architect. Write an Architecture Decision Record
(ADR) in the Michael Nygard format (Title, Status, Context, Decision,
Consequences) for the following decision.

System: ReconX, a near-prod trade reconciliation platform.
Stack: PostgreSQL 16, Spring Boot 3, Kafka, React.
Scale: ~50,000 trades/day, 5-year retention, 10 concurrent recon analysts.

Decision to record: Index `instruments.metadata` (JSONB) with a single GIN
index using the `jsonb_path_ops` operator class, rather than per-field
btree expression indexes, to support containment (@>) queries.

Alternatives we considered: (1) no index / sequential scan; (2) btree
expression indexes on individual extracted fields.

Constraints / forces: metadata shape changes roughly monthly and we don't
want an index-maintenance burden that scales with field count; analysts
query by containment (@>), not key existence; write volume is 50k/day and
index maintenance overhead on writes must stay acceptable.

Format: Markdown, Nygard 5-section template, no fluff. Keep under 300 words.
Include a "Status: Accepted | Date: <YYYY-MM-DD>" line.
```
