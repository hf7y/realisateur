# THE WAITING ROOM

*Where **project** repos wait. Opened 2026-08-01 by `/ideate`, Zach present.*

## The distinction this file exists to record

Two kinds of repo were being treated as one, and the bashify pass ran the
same instrument over both.

- A **project repo**'s result is a **real-world deliverable** — a disc
  ripped, an order placed, nine speakers playing in a room, groceries
  actually bought. Its milestone names an event outside the computer.
  Distilling it to a reusable verb is not what finishing it means. **These
  park here**, pending the ecosystem redesign, and are **rescheduled for
  self-dev after it**.
- A **utility / assistant repo**'s design is **functions to be reused
  again**. Its milestone names a capability the ecosystem itself consumes.
  **These keep being bashified** — that IS their finished form.

**The classifier is the declared stability milestone**, not the repo's
subject matter. Read off `milestone-audit` 2026-08-01, not asserted: crt
runs on real potato hardware in a real room and chezz's players are real
people, so both are projects despite each containing an agent loop;
ecosim's product is a *sensor* (`silence-audit`, already installed into
realisateur's own lint) and vim-arcade is where coined verbs get spoken,
so both are utilities despite each having a human-facing surface. Those
four were the ambiguous ones and Zach decided them 2026-08-01.

**Parking is not reaping.** A reap suspends completed agentic activity and
deletes the material. Parking suspends the *scheduling* and keeps every
byte: the repo stays on disk, its prose stays in place, its `bashified`
branch stays pushed. Nothing here has been destroyed and nothing here is
finished.

## Parked — 10 project repos

Unregistered from scheduler at parking (Zach, 2026-08-01): `schedule/<name>.conf`
and the `_paced.conf` row removed, so `registered` once again means `live`.
Re-registration is the deliberate act that ends a stay here.

`bashified` heads probed 2026-08-01, and **every one matches its
`origin/bashified`** — the property that makes parking safe rather than a
promise. Note these differ from the heads recorded in FOCUS.md on
2026-07-30: eight of ten branches advanced after that entry was written, so
the FOCUS list is stale and this table supersedes it.

| project | verb | bashified head | milestone as of parking | waiting on |
|---|---|---|---|---|
| sequestria | `capte` | `dfb478e` | one real Instagram ad against a real storefront, and one real order by a real person | a decided brand direction; its own FOCUS calls recent commits "self-logging, not product" |
| nine-speakers | `chante` | `7e2319e` | nine channels playing in the office, levels balanced by microphone measurement | hardware and Zach's ears — no unattended run can advance it |
| wtul | ~~`grave`~~ **RETIRED 2026-08-02** → tag `parked/bashified` (`5e5f271`) | — | rips a disc end-to-end with correct metadata, logged in a form Zach can trust unchecked | Zach at the station with discs |
| vkv-inventory | `compte` | `5d29177` | the drill-down browse redesign merged to `main` (milestone line malformed — lacks a status token) | a real inventory and real users |
| aedile | `annonce` | `22c5f5d` | the scenario library replaces the PR-review gate without losing Tyler-visibility | Tyler, and a live wavebucks cycle |
| groc-mangr | `mange` | `7a51ce3` | Zach buys groceries before he otherwise would have — a real purchase, not a metric | Zach's actual shopping |
| home-assistant | `loge` | `d61880f` | circadian automations soak-tested, unavailable-bulb resolved, house reachable over HTTPS (milestone line malformed) | the house, and real soak time |
| abletim | ~~`cadence`~~ **RETIRED 2026-08-02** → tag `parked/bashified` (`0b25f52`) | — | marker-to-marker regions of a real `.als` cut to their own files on disk | a chosen entry path; spike unstarted |
| crt | `sonne` | `47ef553` | the voice loop reliable on real potato hardware, and the Book Game funnel end-to-end | potato hardware in a real room |
| chezz | `joue` | `ca6fb2c` | autopilot loop stable — players file ideas in-game, nightly runs ship or triage them | real players |

## Still bashified — 7 utility / assistant repos

Not parked. These keep going through `/bashify`, because a reusable
function is what they are *for*.

| repo | verb | why it is a utility |
|---|---|---|
| scheduler | `dose` | apportions scarce capacity; the ecosystem's own engine |
| realisateur | `juge` | perceives and judges; produces the surveys everything else is triaged by |
| senechal | `veille` | keeps watch over machine-wide config; every project files with it |
| gardien | `garde` | guards the estate's data; owns backup and the reap verb `fauche` |
| ecosim | `sonde` | probes what cannot be seen; its `silence-audit` is already installed into realisateur's lint |
| vim-arcade | `entraine` | trains the hands; the place where coined verbs get spoken |
| basheur | *(its own)* | the one live self-dev agent — the instrument that does the bashifying |
| bibliothecaire | `range` +6 | **added 2026-08-02** — see below; classified a utility and registered |

## Verb branches RETIRED — 2026-08-02

Parking a project stopped its *dispatch*; it never took its verb away. Three
products were still carrying one, so `bashify`'s output outlived the
classification that should have prevented it. Their `bashified` branches are
deleted and archived to a pushed `parked/bashified` tag in each repo.

| project | verb | tag | note |
|---|---|---|---|
| abletim | `cadence` | `0b25f52` | empty stub — `verb_subcommands` was never populated |
| wtul | `grave` | `5e5f271` | already dead: `LEGACY_ROOT` named `/home/zach/Documents/wtul`, which does not exist |
| secretaire | `range` | `8daf452` | the verb **moved** to bibliothecaire as `trie` rather than dying |

Refs deleted, commits kept. `bin/lib/verb-set.sh` consults only `bashified`
and `origin/bashified`, so a tag preserves the archive **without** declaring
the verb. Deleting the remote-tracking ref matters as much as the local head —
skip the prune and the verb stays declared from a ref nobody can see.

**Declared verbs: 27 across 10 projects → 25 across 7.**

### Why this could happen at all, and what now prevents it

`bashify emit` and `bashify coin` already refuse a project with no
`scheduler/schedule/<project>.conf` — but **only at mint time, and never
again**. A project deregistered *after* being bashified kept its verb forever,
and nothing anywhere re-asked. `bin/install-verbs.sh` now re-checks
registration on every run and reports `UNREGISTERED`, so this cannot silently
regress. A guard that fires once is a guard that has already stopped guarding.

## Reclassified — bibliothecaire and secretaire

Both sat under "already reaped" while being resident, live, and — between them
— holding 7 of the 25 verbs on `PATH`. Neither was in the registry, so by the
classifier both read as products carrying a verb surface. Zach decided them
2026-08-02:

- **bibliothecaire is a UTILITY.** Registered in `scheduler/schedule/`
  (classification only — both tiers blank, no `_paced.conf` row, cron surface
  verified unchanged). It now declares 7 verbs, having absorbed `trie`.
  **Deferred:** its `main` still carries a live hardware-bound product — a
  physical scanner, an SMB share, three systemd timers. That scanner parts off
  into its own repo, leaving bibliothecaire a stable non-agent core utility.
  Until that lands the repo is a utility by intent and a product by content.
- **secretaire is a PRODUCT**, retired above.

This also dissolved a live collision: **both** declared `range`, with unrelated
meanings — "shelve, catalogue and retrieve the ecosystem's texts" versus "put
the morning's accounts in the order a missed message costs most". secretaire's
won on `PATH`; bibliothecaire's own verb was unreachable by name. Moving the
verb resolved it rather than picking a winner. The name `trie` is its original
one; only the name returned — the two-clause summary that got it renamed to
`range` on 07-31 did not.

quatre-vingt-douze (`cueille`) remains genuinely reaped: folded into
bibliothecaire as `glane`/`accroche` and removed from disk.

## What ends a stay here

The **ecosystem redesign** — the same one that owes an answer to "where is
self-dev re-hosted", deferred 2026-07-30 with an explicit revisit trigger
(*the redesign names its unit of isolation*). When it lands, each row above
is re-registered and rescheduled for self-dev. Until then a parked project
is not a forgotten one: this file is the record, and it is the only place
that answers "what is parked" in one read.

**Deliberately NOT done, so no later session mistakes it for an omission:**
no per-project FOCUS.md stamp. Zach chose the single ledger over ten
scattered stamps (2026-08-01), so this table is the record and a parked
project's own FOCUS.md says nothing about being parked. The cost is real —
open a parked repo alone and nothing in it tells you — and it is accepted
rather than overlooked.

---

## 2026-08-01, later the same day — five of these are no longer on disk

**"Parking is not reaping" above is now partly false, deliberately, and by
Zach's instruction ("fauche it").** Corrected here rather than rewritten
above, so the promise and its change are both readable.

`fauche` — gardien's reap verb, named in this file's own utility table since
it was written and built the same night — found five repositories provably
recoverable and emitted a removal script. Zach ran it.

| repository | was | now |
|---|---|---|
| crt | parked, 1.1 G on disk | `git clone https://github.com/hf7y/crt.git` |
| sequestria | parked, 1.5 M on disk | `git clone https://github.com/hf7y/sequestria.git` |
| groc-mangr | parked, 1.2 M on disk | `git clone https://github.com/hf7y/groc-mangr.git` |
| nine-speakers | parked, 1.7 M on disk | `git clone https://github.com/hf7y/nine-speakers.git` |
| front-door | not in the table above | `git clone https://github.com/hf7y/front-door.git` |

**~1.1 GB freed.** The `bashified` heads recorded in the table above are
still accurate and still on `origin` — that is what made this safe.

What changed is only the sentence "the repo stays on disk". Every byte is
still recoverable, the prose is in the vault (150 documents consigned the
same night), and the scheduler's `focus/`/`questions/` symlinks were swept
afterwards with nothing dangling.

**The remaining five parked project repos are untouched**: wtul,
vkv-inventory, aedile, home-assistant, chezz — none of which is on this host
in the first place. Re-registration is still the deliberate act that ends a
stay here, and for a reaped one it now begins with a clone.

Record: gardien `0d1f074`; decision and its answer at scheduler `58344a7`
and `b5753e3`.
