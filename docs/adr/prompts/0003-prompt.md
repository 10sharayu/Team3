# Architecture Decision Records (ADRs)

This directory holds ADRs for ReconX in [Michael Nygard's format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions):
Title, Status, Context, Decision, Consequences.

## Why we do this

An ADR captures the "why" behind a decision at the moment it was made, so a
future engineer (or the next cohort) isn't left reverse-engineering intent
from a schema diff six months later. Each ADR should record exactly one
decision, name the alternatives that were rejected, and name the constraints
that drove the choice. "Architecture for the project" is not an ADR;
"we partition `trades` by `trade_date` because our queries are date-bounded"
is.

## AI-policy expectation

When Claude (or another model) is used to draft an ADR, the prompt used to
generate it is committed alongside the output — either inline in a footer
of the ADR itself, or as a sibling file under `docs/adr/prompts/`. The
prompt is part of the review artifact, not just the polished text. Reviewers
should reject ADRs that read as generic boilerplate; a one-line prompt
produces a generic ADR, which is not acceptable.

## Prompt template

Use this template as the starting point for every new ADR. Fill in the
bracketed fields with the specific decision, alternatives, and constraints
before sending it to Claude.

```
You are an enterprise software architect. Write an Architecture Decision Record
(ADR) in the Michael Nygard format (Title, Status, Context, Decision,
Consequences) for the following decision.

System: ReconX, a near-prod trade reconciliation platform.
Stack: PostgreSQL 16, Spring Boot 3, Kafka, React.
Scale: ~50,000 trades/day, 5-year retention, 10 concurrent recon analysts.

Decision to record: <ONE LINE DESCRIBING THE DECISION>

Alternatives we considered: <LIST 2-3>

Constraints / forces: <LIST 2-3>

Format: Markdown, Nygard 5-section template, no fluff. Keep under 300 words.
Include a "Status: Accepted | Date: <YYYY-MM-DD>" line.
```

## Naming convention

`docs/adr/NNNN-short-kebab-case-title.md`, numbered sequentially starting at
`0001`. Never renumber or delete a superseded ADR — mark it
`Status: Superseded by ADR-XXXX` and add a new one instead.

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](0001-partition-trades-by-date.md) | Partition the `trades` table by `trade_date` | Accepted |
| [0002](0002-jsonb-metadata.md) | Use JSONB for `instruments.metadata` | Accepted |
| [0003](0003-gin-over-btree.md) | GIN (`jsonb_path_ops`) index over btree on `instruments.metadata` | Accepted |
