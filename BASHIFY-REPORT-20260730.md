# The bashify pass — 2026-07-30

*Unattended session, Zach-directed. Noun → verb, worldwide, in one night.*

## What exists now

**19 of 19 projects have a `bashified` branch, pushed to GitHub.** Each
contains a verb-named shell utility, a man page, a contract, a contract
test, and a `GAPS.md`. Nothing else — the purge is total, and it is
mechanically verified rather than asserted (see "the guard" below).

| project | verb | subcommands | contract |
|---|---|---|---|
| scheduler | **dose** — apportion scarce capacity | 25 | 7/7 |
| realisateur | **juge** — perceive and judge | 21 | 7/7 |
| senechal | **veille** — keep watch | 19 | 7/7 |
| crt | **sonne** — ring the handset | 48 | 7/7 |
| ecosim | **sonde** — probe what cannot be seen | 5 | 7/7 |
| gardien | **garde** — guard the estate's data | 4 | 7/7 |
| wtul | **grave** — engrave the disc | 4 | 7/7 |
| vkv-inventory | **compte** — count and locate | 3 | 7/7 |
| bibliothecaire | **range** — shelve and retrieve | 2 | 7/7 |
| aedile | **annonce** — announce public operations | 0 | 7/7 |
| abletim | **cadence** — drive and time | 0 | 7/7 |
| chezz | **joue** — play and score | 0 | 7/7 |
| groc-mangr | **mange** — keep the larder | 0 | 7/7 |
| home-assistant | **loge** — house the configuration | 0 | 7/7 |
| nine-speakers | **chante** — make the nodes sing | 0 | 7/7 |
| quatre-vingt-douze | **cueille** — gather page 92 | 0 | 7/7 |
| secretaire | **trie** — sort the mail | 0 | 7/7 |
| sequestria | **capte** — capture the brand | 0 | 7/7 |
| vim-arcade | **entraine** — train the hands | 0 | 7/7 |

All verbs confirmed unclaimed on `PATH` before assignment, and all are
pure ASCII — an accented command name is unusable at a prompt, which
ruled out the obvious French spellings (`répartis`, `édifie`).

## The naming rule, now applied worldwide

**French noun = animate. French imperative verb = inanimate.** One
language, so there is no seam; the part of speech alone tells you whether
the thing you are invoking is an agent.

The second half is the cost boundary: **`--summon`**, long form only.
`-s` collides with existing tools and `-S` differs from it by a single
shift key, which is an unacceptable property for the only flag that
spends real money. Typing the word out is the deliberateness. A utility
that *cannot* spend does not carry the flag at all — so `--help` alone
answers "can this cost me anything?"

## The measured findings

These are the point of the exercise. All probed 2026-07-30, not quoted.

**1. Ten of nineteen projects had no callable entry point at all.**
Not a bad one — none. Over half the ecosystem could not be invoked by a
human at a shell prompt in any way. That is the honest measure of how
much of this work was ever mechanised, and the answer is: less than half
of it had even a front door.

**2. `realisateur`'s own tooling fails the contract worst.**
`bin/ecosystem-survey.sh --not-a-real-flag` **exits 0** and runs the full
survey anyway. `check-project-busy.sh` does the same. The exit-0 no-op
that `BUILD-DISCIPLINE.md` forbids is sitting in the sensors that audit
everyone else. Scored **0 of 8** against the contract.

**3. Legacy `scheduler` hangs on a bad flag.** `-s` is `sweep`, which
blocks on an interactive editor — a contract test with no timeout would
have hung the whole sweep. `dose` rejects it in milliseconds. This is the
single clearest before/after in the pass.

**4. The purge guard caught a real leak before it shipped.**
The first `aedile` build exposed a subcommand named `AnthropicClient.js`
— on a branch whose stated guarantee is that no such name appears. It was
pushed before being caught, and has since been force-overwritten. The
fix was not to edit the file but to **mechanise the guarantee**: nothing
commits unless a `grep` over the whole tree comes back empty. It then
immediately caught two more (`crt`, `aedile`) whose `GAPS.md` reproduced
vendor-named *paths*, and one more class — my own generated prose
explaining "there is no agent here", which is itself a trace.

**5. Discovery assumptions are the quiet killer.** A first glob that
only read `bin|scripts|tools` found **3 of senechal's 23** scripts and
would have shipped a utility silently missing most of the project.
senechal keeps its tooling in `health/` and `remedies/`. Fixed in the
generator, not per-project.

## What is deliberately NOT done

- **No cost baseline exists.** Token spend was authorised but not used:
  every one of these utilities is a *subtraction* from code that already
  ran, so there is no summon and no before-number to measure. **This pass
  therefore does not close basheur's `U0`**, whose load-bearing box is
  "token cost measured on both sides". That still needs a genuinely
  agent-backed contract.
- **Nothing installed on `PATH`.** No verb is wired into the machine, no
  crontab, no symlink. Wiring is a separate, human decision.
- **The verbs mostly wrap rather than reimplement.** A subcommand execs
  the legacy script it was discovered from. That is honest — it is a
  coherent front door over what exists — but it is not yet a rewrite.

## Why every branch says "do not extract me"

The purge is total *because* these are branches. Every removed cause is
one `git log <default-branch>` away in the same repository. Extracting a
`bashified` branch into a standalone repo would destroy the archive that
makes the purge safe, and leave defensive code standing with no visible
reason — which is how hard-won guards get deleted by the next reader.
Each `README.md` and man page says so.

## Tooling

`bashify/bashify.sh` — reads a project, discovers real tooling, emits the
branch. Uses `git worktree` throughout, so no project's working tree is
ever touched; `gardien` and `senechal` were bashified while Zach had live
interactive sessions open in both, and neither tree was disturbed.

`bashify/skel/lib/verb.sh` — the shared runtime. The argument grammar,
the cost boundary, and the failure vocabulary exist in exactly one place,
so nineteen utilities cannot drift into nineteen dialects.

`bashify/skel/test/contract-test.sh` — the contract test. Takes any
command, so the *same* assertions run against legacy tooling and the new
verb. Every invocation is wrapped in `timeout`; a failure is scored and
reported, never fatal to the sweep.
