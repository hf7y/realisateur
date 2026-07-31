
# CONTRACT — `range`

`range` — shelve, catalogue and retrieve the ecosystem's texts.

Revised 2026-07-30 from the `bashified` branch's contract of the same date, which had itself revised the generated stub. Every `backed by` below was re-probed rather than carried forward, and that re-probing moved four rows — three of them in the direction that *overstates* the gap. `ocrmypdf` is installed. Two of the three OCR out-of-memory asks are done, in the unit file itself. The source gate fails on four files, not three. A contract that quotes a same-day contract is still quoting.

The one structural finding this revision adds is in the runtime, not the prose: **`lib/verb.sh` defines no refusal path.** It has `verb_die` (2), `verb_need_summon` (3), `verb_gap` (4), `verb_broke` (5) and `verb_blind` (6). There is no `verb_refuse` and no exit 7 anywhere in the shipped code. Every `refused` row below is therefore enforced by documents, by construction, or by Python that exits 1 — not by the verb. That is stated once, here, rather than implied twenty times.

## How to read the HOW column

| HOW | meaning | exit when unmet | cost |
|---|---|---|---|
| **bash** | mechanized. Runs free, unattended, no model in the loop. | 5 if it ran and broke | free |
| **summon** | SHOULD DO — in scope, not yet mechanized. | 4 (GAP), naming its own escalation | metered, printed before spending |
| **refused** | WON'T DO — out of scope on principle. | 7 (REFUSED) | n/a, no summon exists |

`--summon` is available on 4 and forbidden on 7. A gap names its escalation; a refusal offers none, because having no escalation path is what refusing on principle means.

Language is not the test. `bash` means it runs free, unattended, with no model in the loop — five Python programs in `bin/` satisfy that and are counted as mechanized. `bin/quote-stream.py` does not, and is counted as metered.

## The obligations

### Publish — the consumer contract

| obligation | HOW | backed by |
|---|---|---|
| enforce the published schema — id, text, author, work, year, locator, theme, status — and fail loud on violation | bash | `bin/validate-quotes.py`, the registry's declared `BATCH_TEST_CMD` |
| keep quote ids stable, because briefs cite by id | bash | uniqueness enforced in `bin/validate-quotes.py`; "don't renumber existing entries" in README.md's consumer contract |
| publish only `verified` or `verified-secondary`, never `seed-unverified` | bash | the status filter behind `--export` |
| regenerate `quotes/quotes.txt` rather than let it be hand-edited | bash | `bin/validate-quotes.py --export`; "never hand-edit" in README.md |
| hold the exported line format steady across schema widenings | bash | the `text — author, work` line was unchanged when `verified-secondary` landed 2026-07-27; provenance stayed in the JSON |
| reject a `verified-secondary` whose `quoted_in` carries no page or section | bash | `bin/validate-quotes.py`, negative-tested |
| report verified-quotes-per-theme against the ≥2 bar **without failing** | bash | `--coverage` |
| gate on that bar when asked | bash | `--require-coverage` |
| push a selected quote to a watching consumer without the model authoring one | summon | `bin/quote-stream.py` — built and negative-tested, but default selection is a model call. Unreachable through `range`, which declares `VERB_CAN_SUMMON=0` |
| offer the same stream free when no model is wanted | bash | `bin/quote-stream.py --no-agent`, least-recently-streamed |

### Catalogue — briefs, maxims, and keeping the two apart

| obligation | HOW | backed by |
|---|---|---|
| require all four brief sections — Claim, Sources, Maps onto, Where it breaks | bash | `--require-briefs`, negative-tested against missing, empty and absent |
| reject a brief citing a quote id that is absent or unpublishable | bash | same gate, same test |
| report brief coverage without failing | bash | `--briefs` |
| refuse a maxim with no occasion | bash | `bin/file-maxim.py --add` rejects it; "a maxim with no occasion is a slogan", its own docstring |
| resolve every `related_quotes` / `related_briefs` reference | bash | `bin/file-maxim.py --check` |
| let an in-house aphorism sit in the quotes namespace | refused | separate file, schema, id namespace and export by construction; `--check` fails on id collision or byte-identical text |
| ship a brief with no named disanalogy | refused | `.scheduler/nightly-batch.md`: "a flattering story about the ecosystem, and those are worse than no brief" — file it in QUESTIONS.md rather than soften it |
| decide whether an analogy holds and where it breaks | summon | judgment. The gate checks that the section exists, never that it is true |

### Retrieve — sourcing, and the honesty policy as control flow

| obligation | HOW | backed by |
|---|---|---|
| probe open-access finding aids without spending a model | bash | `bin/find-open-copy.py` — OpenAlex, HAL, Unpaywall, archive.org. "No AI, no judgment" |
| never conflate a failed probe with "no open copy" | bash | same file: exit 1 on probe failure, 0 on found-or-not-found, with the reason stated |
| cap fetches per work so one unreachable text cannot spend the night | bash | 20-fetch cap in `bin/find-open-copy.py` |
| reconcile `sources/` on disk against `sources/LEDGER.md`, and report | bash | `--sources`; clone-aware since 2026-07-28 via the untracked `sources/.source-cache` marker |
| gate on that reconciliation when asked | bash | `--require-sources`. The split is real and load-bearing: `--sources` printed four defects on this run and **exited 0** |
| catch an empty or partial file rather than counting it as held | bash | `--require-sources` — currently four: a 0-byte Insectes PDF, a 114-byte Beer "PDF", `anjF8-6H.pdf.part`, and one unlisted PDF on disk |
| repair those four | summon | carried open in `.scheduler/FOCUS.md`; none fixed |
| hold the research posture — sequential, 2s apart, honest UA, bounded, open sources | summon | enforced inside `find-open-copy.py` **for its own probes only**. Nothing checks a run's total fetch count against the declared budget; the milestone allowance and its return to ≤20 are prose |
| widen those limits during an unattended run | refused | "Never widen these unattended" — README.md and the charter, identically |
| invent, "improve," or attribute a quote from memory | refused | README.md's honesty policy; the seed set is `seed-unverified` for this reason and never ships |
| treat a blog, content farm, LLM output or aggregator as a source at any tier | refused | "If the only route to a famous line is an aggregator, the line does not ship" |
| work around a bot wall, unwrap DRM, fake a session, replay cookies, script a login | refused | README.md's source-access amendment, 2026-07-27 |
| retain a licensed copy after the quote is taken | refused | "The rule is not 'never download'; it is **never retain**" |
| write a brief on a gated primary text from memory or summary | refused | Zach's standing call 2026-07-27: skip it |
| check wording against the primary text and record `verified_via` and a locator | summon | the validator checks the fields are present and well-formed; only a reader checks the wording |
| reach licensed material through an authenticated front door | summon | undetermined — permission plausibly exists, plumbing does not. A human drops into `sources/` today; the Tulane TDM request is sent, unanswered |
| own the deletion of licensed material rather than leaving it to habit | summon | undetermined — `gardien` named as likely owner; **parked deliberately**, not dropped. `sources/` is gitignored but not backup-excluded |

### Shelve — the scanner intake, which is live machinery that deletes files

All three timers were confirmed firing on this run (`intake` 15-minutely, `intake-ocr`, `intake-health` daily at 10:00).

| obligation | HOW | backed by |
|---|---|---|
| drain the write-only SMB drop box on a timer | bash | `--accept` on `bibliothecaire-intake.timer` |
| identify items by content, not filename | bash | sha256 identity; "a Mac writes `Untitled 3.pdf` more than once" |
| never snapshot an image-only scan | bash | the `needs-ocr` lifecycle state — an empty snapshot would satisfy the reaper's gate and license deleting the only copy |
| never snapshot without a pinned quote found verbatim in the extracted text | bash | `--snapshot`; "the honesty policy expressed as control flow" |
| never delete an original without proof gardien holds it | bash | `--reap` / `--check-backup-proof`, against gardien's own post-rsync marker |
| read an unanswerable backup probe as "no" | bash | unreachable host, stale snapshot, or out-of-path file each exit nonzero and delete nothing. Scans accumulate — the correct failure direction |
| re-probe the pipeline and say what it saw, per check | bash | `--healthcheck` prints one `I looked and I saw` / `I looked and I did NOT see` / `I could not look` line per check |
| report `I could not look` as anything but red | refused | charter rule 2: "UNKNOWN is red. Silencing a privileged probe turns 'denied' into 'clean'" — this is the BLIND clause, already enforced |
| report this pipeline's state from a document, including its own attestation log | refused | charter rule 1: "if you did not run the command this session, you do not know" |
| notice when the health timer itself has stopped | bash | `--healthcheck` reds at attestation age > 26h |
| carry the delegated root-only check with its age and `not re-probed here` | bash | the unprivileged path; the root timer runs daily at 10:00 |
| detect drift between installed units and this repo | bash | unit-drift check inside `--healthcheck` |
| distinguish a real printed page from an EPUB estimate | bash | the `form` field, the `-estimated` filename suffix, and the file's own header — three times over |
| bound OCR so it cannot take the host down | bash | **revised.** `MemoryHigh=2G`, `MemoryMax=3G`, `MemorySwapMax=1G`, `OOMPolicy=stop` and `OMP_THREAD_LIMIT=1` are on `bibliothecaire-intake-ocr.service`, and `ocr_jobs()` clamps the configured jobs to what memory allows, loudly. Two of the three asks from the 2026-07-28 global OOM are closed |
| dispatch OCR through scheduler rather than self-dispatching | summon | the third ask, still open — the unit is its own timer, so this project's heaviest job is invisible to the pacer |
| install and retire its own machine footprint | bash | `smb/install-intake-share.sh` and `systemd/install.sh`, each with `--uninstall`, reachable as `range install-intake-share` and `range install` |

### The verb itself

| obligation | HOW | backed by |
|---|---|---|
| expose this project's real tooling through `range` | summon | `bin/range` wraps two installers. Five working programs in `bin/` are unreachable. The gap is in the **front door**, not in the mechanization — this project's mechanized surface is large and its verb surface is two subcommands wide |
| declare a summon on the one subcommand that spends | summon | `VERB_CAN_SUMMON=0` while `quote-stream.py` calls the model. Wiring stream selection in without setting the flag would ship a `--help` that says it cannot cost money while it does |
| speak the exit vocabulary — 4 GAP, 5 BROKEN, 6 BLIND, 7 REFUSED | summon | `lib/verb.sh` defines gap/broke/blind and puts needs-summon on **3**; it defines **no refusal and no exit 7**. Below it, four Python programs signal every failure with `sys.exit(1)` across five sites, so "the ledger is unreadable" and "the schema is violated" are indistinguishable to a caller |
| be invocable as a verb at all | summon | `command -v range` returns nothing. Nothing from this project is on `PATH` |
| keep the mechanized promises inside a repo | summon | `~/.local/bin/bibliothecaire-nightly-batch-loop.sh`, 420 bytes, executable, owned by this project, tracked in no repo. It would vanish with the home directory |
| know what mechanizing this cost, or saved | summon | undetermined — no before-measurement exists. Closing it needs a measurement, not an estimate |

### Archive — the receiving wing

| obligation | HOW | backed by |
|---|---|---|
| receive another project's retired prose into `archive/<project>/<date>-<topic>.md` | summon | `archive/INDEX.md` exists and drops are filed; `intake/` is specified as "a door, not a shelf" and nothing checks that it has been emptied |
| export an ingest command other projects call | refused | an exported verb makes this repo a runtime dependency of all 18 registered projects — "that rule's own failure mode at 18× scale" |
| quote anything in `archive/` into `quotes/quotes.json`, or cite it from a brief | refused | operational records: no author, no locator, not under the honesty policy |
| summarize or reach into another project's prose | refused | a **receiving** archive only |
| write into a consumer's repo rather than flagging the handoff | refused | charter hard rule; the consumer's own gated FOCUS.md line is carried as a human step |
| fork crt's scan, grade or STT code for the book-catalog wing | refused | wing (b) is greenfield and "shares at most `books.db`'s data" |
| build the book-catalog wing | summon | undetermined — a LATER milestone with no obligations stated beyond that constraint. What settles it is a milestone declaration naming what the wing owes crt |

### Housekeeping the repo cannot currently answer

| obligation | HOW | backed by |
|---|---|---|
| exit a run with a clean tree | summon | dirty right now — `bin/validate-quotes.py`, `quotes/quotes.json`, `quotes/quotes.txt` modified and uncommitted. Per BUILD-DISCIPLINE a dirty tree at exit is a failed run |
| know who wrote a commit | summon | undetermined — three consecutive `scheduler sweep: adopted dirty …` backstops on 2026-07-30 at 03:48, each recording "author unknown". Nothing establishes it |

## Universal clauses

These bind every row above.

- **Exit 0 only if the promise was kept.** Never an exit-0 no-op. A check that could not run has not passed. (`--sources` exiting 0 on four real defects is the *reporting* promise kept, not the gating one; `--require-sources` is the row that must fail.)
- **4 — GAP.** In scope, not mechanized. Names its own escalation.
- **5 — BROKEN.** It ran and it broke.
- **6 — BLIND.** Cannot read its domain. "I cannot see" is never reported as "nothing to report" — the intake healthcheck's `I could not look` line is this clause already made concrete, and it is red.
- **7 — REFUSED.** Out of scope on principle. *Not yet expressible by this runtime: `lib/verb.sh` has no refusal path, so today every refusal above is enforced by document or by construction rather than by the verb.*
- **Cannot spend without `--summon`.** It has no short form, no abbreviation, and is never implied. `range` currently declares `VERB_CAN_SUMMON=0`, so the flag does not exist here at all — and the one program that spends is not reachable through the verb.
- `--summon` is available on 4 and forbidden on 7.

---

Four rows moved on re-probe (`ocrmypdf`, the OCR memory bounds, the source-defect count, the report/gate split); the shipped runtime's missing exit-7 path is the new finding. Residue for run 15 is appended to `residue/project-contract.sh` — including the two inventory traps that would have produced a wrong contract here: grepping `add_argument` on a hand-rolled argv parser, and taking the inventory from the working tree when the verb lives only on `origin/bashified`.
