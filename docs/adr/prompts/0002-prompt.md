### TICKET-ADV015 — Use Claude to generate ADRs

**Goal:** Author at least three Architecture Decision Records in the
Michael Nygard format covering real decisions made today (e.g., partition
by trade_date, JSONB for metadata, GIN over btree), using Claude to draft
each and committing the prompt alongside the output.

**What**
- At least three ADRs under `docs/adr/` in Michael Nygard format (Context / Decision / Status / Consequences) covering today's real choices (partition-by-trade_date, JSONB-for-metadata, GIN-over-btree). The Claude prompt used to draft each is committed alongside.

**Why**
- ADRs are how future-you (and the next cohort) recover the "why" behind a schema choice without doing software archaeology. Committing the prompt teaches the AI-policy expectation: prompt + output go in the PR, not just the polished output.

**Observe**
- `docs/adr/0001-*.md`, `0002-*.md`, `0003-*.md` exist; each has a `## Status` line saying "Accepted"; each has a sibling `prompt.md` capturing the Claude conversation.

**Done when:**
- At least three ADRs exist at `docs/adr/0001-*.md`, `0002-*.md`, `0003-*.md`.
- Each ADR has the five Nygard sections (Title, Status, Context, Decision, Consequences) and is specific to ReconX (named scale numbers, named alternatives, named constraints).
- The prompt template you used is committed at `docs/adr/README.md` so future ADRs follow the same shape.

<details>