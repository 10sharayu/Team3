# ADR-0001 — Partition the `trades` table by `trade_date`

- Status: Accepted
- Date: 2026-06-02
- Deciders: ReconX team

## Context

`trades` is our highest-volume table — ~50k inserts/day, 5-year retention =
~91M rows at steady state. The vast majority of queries (dashboards,
recon runs, analyst lookups) filter by a date range (often single day or
single month). A single unpartitioned table forces full-table scans for
date-range deletes and complicates archival of older trade data for the
5-year-retention SLA.

Alternatives considered:
- **No partitioning, rely on a btree index on `trade_date`** — index still
  has to be scanned across the full 91M-row range for archival/cleanup
  jobs, and index bloat grows unbounded over 5 years.
- **Partition by `id` range (fixed-size chunks)** — doesn't align with how
  analysts and jobs actually query (by date), so pruning wouldn't help the
  hot path.
- **Partition by `trade_date`, monthly** — chosen; aligns partition
  boundaries with the access pattern and the archival unit.

Constraints / forces:
- Postgres 16 requires the partition key to be part of any unique/primary
  key on the partitioned table.
- 10 concurrent recon analysts run ad-hoc date-bounded queries during
  business hours; query latency on those queries is the primary SLA.
- 5-year retention means old partitions must be droppable without locking
  current-month writes.

## Decision

Partition `trades` by RANGE on `trade_date`, with one partition per calendar
month. The primary key includes `trade_date` to satisfy Postgres' partitioning
constraint. Child partitions are named `trades_yYYYYmMM` and are pre-created
for the next 12 months by a monthly maintenance job.

A `trades_default` partition catches any out-of-range inserts so the table
never rejects writes; the maintenance job alerts on unexpected default-partition
inserts.

## Consequences

**Positive**
- Partition pruning eliminates 11/12 of the data on a typical month-filtered query.
- Archival becomes a DDL operation (`DETACH PARTITION`), not a row-level delete.
- Indexes are smaller per partition, faster to maintain.

**Negative**
- Composite PK `(id, trade_date)` complicates JPA `@Id` mapping (see ADR-0007).
- Cross-partition unique constraints (e.g., `trade_ref`) require a workaround.
- Pre-creating partitions is a recurring ops task — must be automated.

---

### Prompt used to draft this ADR

```
You are an enterprise software architect. Write an Architecture Decision Record
(ADR) in the Michael Nygard format (Title, Status, Context, Decision,
Consequences) for the following decision.

System: ReconX, a near-prod trade reconciliation platform.
Stack: PostgreSQL 16, Spring Boot 3, Kafka, React.
Scale: ~50,000 trades/day, 5-year retention, 10 concurrent recon analysts.

Decision to record: Partition the `trades` table by RANGE on `trade_date`,
one partition per calendar month, with a default partition for out-of-range
inserts.

Alternatives we considered: (1) no partitioning, rely on a btree index on
trade_date; (2) partition by id range in fixed-size chunks.

Constraints / forces: Postgres 16 requires the partition key in any unique
key; 10 concurrent analysts run date-bounded queries during business hours;
5-year retention requires droppable old partitions without locking current
writes.

Format: Markdown, Nygard 5-section template, no fluff. Keep under 300 words.
Include a "Status: Accepted | Date: <YYYY-MM-DD>" line.
```
