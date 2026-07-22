# ADR-0002 — Use JSONB for `instruments.metadata`

- Status: Accepted
- Date: 2026-06-02
- Deciders: ReconX team

## Context

`instruments` holds ~50k trades/day worth of referenced instrument records,
each carrying a metadata payload whose shape varies by asset class
(equities, FX, fixed income, derivatives — currently 4 classes, with more
expected as new desks onboard). Fields like `isin`, `cusip`, `strike`,
`underlying`, and `settlement_terms` apply to some asset classes and not
others. Recon analysts and downstream services need to query into specific
metadata fields (e.g., "all derivatives with `underlying = 'AAPL'`"), not
just read the blob back whole.

Alternatives considered:
- **Fully normalized tables per asset class** — cleanest for query planning
  and constraints, but requires a schema migration and a new table for
  every new asset class/field, which doesn't fit our 10-person team's
  release cadence for a fast-evolving instrument set.
- **EAV (entity-attribute-value) table** — flexible, but joins explode at
  50k trades/day and analysts already find EAV painful to query ad hoc.
- **JSONB column on `instruments`** — chosen; flexible schema, queryable
  with native operators, no migration needed to add a field.

Constraints / forces:
- Asset-class-specific fields are added by desks faster than we can ship
  migrations (roughly monthly).
- Recon analysts need to filter/query into metadata fields directly from
  SQL, not just deserialize application-side.
- Postgres 16 JSONB supports indexing (GIN) and containment operators,
  unlike plain JSON.

## Decision

Add a `metadata JSONB NOT NULL DEFAULT '{}'` column to `instruments` to hold
asset-class-specific fields. Common, universally-present fields (`id`,
`asset_class`, `trade_date`, `notional`) stay as typed columns; only the
variable, asset-class-specific attributes go into `metadata`. Application
code validates the expected shape per `asset_class` at the service layer
before insert, since Postgres doesn't enforce a schema on JSONB.

## Consequences

**Positive**
- New asset-class fields ship without a DDL migration or downtime.
- `metadata @> '{"underlying": "AAPL"}'` style containment queries work
  directly from SQL and from the recon dashboard's query builder.
- One column serves 4+ asset classes instead of 4+ sparse, mostly-null
  typed columns.

**Negative**
- No DB-level schema enforcement on `metadata` — a bad application-layer
  write can insert an inconsistent shape; caught only by service-layer
  validation and code review, not the database.
- Field-level queries are slower than a native typed column without a
  supporting index (addressed in ADR-0003).
- Reporting tools that expect flat columns need a view or app-layer
  flattening step.

---

### Prompt used to draft this ADR

```
You are an enterprise software architect. Write an Architecture Decision Record
(ADR) in the Michael Nygard format (Title, Status, Context, Decision,
Consequences) for the following decision.

System: ReconX, a near-prod trade reconciliation platform.
Stack: PostgreSQL 16, Spring Boot 3, Kafka, React.
Scale: ~50,000 trades/day, 5-year retention, 10 concurrent recon analysts.

Decision to record: Store asset-class-specific instrument attributes in a
`metadata JSONB` column on `instruments`, rather than typed columns or a
separate EAV table, keeping only universally-present fields as typed
columns.

Alternatives we considered: (1) fully normalized table per asset class;
(2) EAV (entity-attribute-value) table for variable attributes.

Constraints / forces: desks add new asset-class fields roughly monthly,
faster than our migration cadence; analysts need to query into metadata
fields directly from SQL, not just deserialize app-side; Postgres 16 JSONB
supports GIN indexing and containment operators.

Format: Markdown, Nygard 5-section template, no fluff. Keep under 300 words.
Include a "Status: Accepted | Date: <YYYY-MM-DD>" line.
```
