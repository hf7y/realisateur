# office-economy — worker identity, personality, fitness, and a bounty board

*Staged by realisateur, 2026-07-30, for adoption into the office on `nomac`.
Authored here (realisateur's organ is authoring contracts) rather than
written into romulus's live tree. Nothing here is in force until Zach or
romulus adopts it. It reads the office's **real** ledger format
(`office-state/ledger/ledger.psv`, `id|ts|account|type|amount|_|hash|note`,
pegged 10000 tokens/wavebuck) — not a fiction.*

## What this is for

Three problems, one design:

1. **Identity that does not read as "an AI."** A worker is `Marius Faber,
   archivist`, not `claude-worker-3`. The record carries no `model` field and
   no vendor name. Individuation (every worker has different traits) is itself
   the obfuscation: a room of workers that behave identically reads as one
   model wearing nine hats; a room that behaves differently reads as people.

2. **Personality as a small vector of scores**, so an evolutionary model has
   something to select on. Six traits, integer 0–100:
   `industriousness thoroughness frugality risk_tolerance sociability
   curiosity`. A worker record is flat `key=value` — sourceable, greppable,
   one worker per file under `workers/<login>.worker`.

3. **Decision-making that costs no tokens.** This is the load-bearing idea.
   An agent asking *"what should I work on?"* is an open-ended, token-priced
   deliberation. `commissio` replaces it with *"which posted bounties clear my
   personality filter and pay above my frugality threshold?"* — a deterministic
   match of traits against a board. **The personality IS the decision
   procedure.** No model is in the loop to pick work; the traits pick it.
   That is the "pre-built means of economizing agent decision-making."

## The verbs (unix-like, pipeable, quiet by default)

Each is a basheur contract (`contracts/*.contract`) with a working impl
(`bin/<verb>`). Commentary goes to stderr; results go to stdout, line-oriented,
so they compose:

| verb | one line | mechanized? |
|---|---|---|
| `persona` | roll a fresh worker identity + traits | yes — urandom + wordlists |
| `fitness` | score a worker from the real ledger | yes — pure computation |
| `commissio` | the bounty board: post / list / match / settle | yes — escrow + trait match |
| `evolve` | rank by fitness, select, mutate, propose new hires | yes — ranking + recombination |

Composability is the point: `persona` feeds a new hire, `fitness` feeds
`evolve`, `evolve` calls `persona` for the next generation, and `commissio
match <login>` is what a woken worker consults instead of reasoning. The whole
loop can run with no agent in it — which is exactly the de-animation thesis
applied to the office itself.

## Why these are contracts, not just scripts

Every verb here is written to become non-agentic. `persona` and `fitness` are
already pure bash. `commissio match` and `evolve` are deterministic functions
of traits and ledger — no judgment, no tokens. The one thing that legitimately
stays agentic is *doing* a commissio's actual work; everything about *choosing*
and *pricing* and *selecting* is mechanized here. That is the boundary the
office keeps blurring, drawn on purpose.

## Not adopted, and what it would take

- Provisioning a worker means `office-account add` (a director action; hiring
  is not self-service). `persona` emits the record; a director installs it.
- `fitness` and `commissio` read/write under `office-state/`; on nomac that is
  romulus's tree. Adoption is a director decision, not an unattended write.
- Open question for Zach: whether a worker's balance is savings or expiring
  spend authority (personnel manual §2.3 [OPEN]) changes how `fitness` should
  weight a hoard. Marked in `contracts/fitness.contract`.
