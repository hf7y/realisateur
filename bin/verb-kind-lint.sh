#!/usr/bin/env bash
# verb-kind-lint.sh -- a command in the verb build says which CHANNEL it
# belongs to, in its own file, or it does not ship.
#
# GUARD: does every command in a verb build declare itself a workchain verb or a product, and is no product riding the workchain channel?
# RUNNER: bin/tests/verb-kind-lint.test.sh bin/cut-verb-build.sh
# GUARD-TEST: bin/tests/verb-kind-lint.test.sh
# GATE: default --build $TREE
# VERIFIED: 2026-08-11 via bash bin/tests/verb-kind-lint.test.sh and bash bin/tests/cut-verb-build-test.sh
#
# The run against the live build -- the one that produced the numbers in
# bin/verb-kind-lint.ratchet -- is stamped in that file instead of here,
# because it names a host-specific path and this file may not: see the
# one-reader argument at BUILD= below, which propagation.test.sh enforces by
# grepping every bin/*.sh for the pin path.
#
# ===========================================================================
# THIS RULE IS NOT NEW. IT WAS DECIDED 2026-08-05 AND NEVER MECHANIZED.
# ===========================================================================
#
# Read this section before changing the criterion below, because the estate
# has already stated it and a second statement in different words is the
# defect this repository keeps paying for.
#
# hf7y/vim-arcade's own bin/vim-arcade has said, in its header, since
# 2026-08-05:
#
#     "It is named `vim-arcade` now because it is not a verb. The rest of
#      this estate's commands are things you tell the machine to do; this is
#      a GAME, and a game has a name of its own. 'Play' was a description of
#      the user, not of the thing.
#
#      Zach, 2026-08-05: 'joue should not even exist -- vim arcade ships a
#      game which should be called something else, and that's what I should
#      have on my path.'"
#
# The command WAS `joue`, a French workchain verb, and it was renamed to
# `vim-arcade` precisely to mark it as not-a-verb. THE RENAME WAS THE SPLIT.
# What never happened is the mechanization: the product got its own name and
# went on riding the workchain channel anyway, because that channel was the
# only one that reached PATH.
#
# So this guard invents no criterion. It makes an existing, dated decision
# machine-readable, and asserts that every command states which side of it
# they fall on.
#
# THE CRITERION, IN THE ESTATE'S OWN WORDS, is semantic and not linguistic:
#
#     a VERB is a thing you tell the machine to do
#     a PRODUCT is a thing with a name of its own
#
# That is a better rule than "is the name French", and it is the reason
# `entraine` and `vim-arcade` can correctly ship from the same repository off
# the same sha (e02dc8ac on 2026-08-06T003928Z). `entraine` is something you
# tell the machine to do. `vim-arcade` is a thing. French-ness is a
# convention the workchain happens to follow, not the property that decides
# which channel an artifact ships on -- which is why the check below reads a
# declaration and not a wordlist.
#
# ===========================================================================
# THE VIOLATION, AND WHY IT IS STRUCTURAL RATHER THAN COSMETIC
# ===========================================================================
#
# Measured 2026-08-08 against build 2026-08-06T003928Z: 32 commands, 12
# projects. Thirty-one of the names are French verbs. One is not:
#
#     vim-arcade   entraine     a workchain verb, correctly in the build
#     vim-arcade   vim-arcade   the PRODUCT, riding the workchain
#
# `entraine` belongs where it is. `vim-arcade` is a product that entered the
# verb build because the verb build was the only channel that reached PATH.
#
# The two have OPPOSITE requirements, and provision/verbs-meta/build-verbs.yml
# states the workchain half in its own words: the build is "the thing
# consumers hold still against while agents merge, so it must NOT move every
# time an agent pushes. That stability is the feature."
#
# That is right for a verb and exactly wrong for a product. For vim-arcade
# Zach wants the fix he just made, and wants to be TOLD it exists. Same
# artifact, contradictory contracts. On 2026-08-08 mandark was pinned to
# 2026-08-06T003928Z while the channel carried 2026-08-07T040739Z, and
# nothing on that host moves the pin -- its crontab's scheduler block was
# emptied 2026-07-29 and never re-armed. Stability was working as designed,
# and the product was three days stale because of it.
#
# ===========================================================================
# WHY THE DECIDER IS A SELF-DECLARATION AND NOT A LIST OR A WORDLIST
# ===========================================================================
#
# Three deciders were available and two of them rot.
#
#   A WORDLIST ("is the name French?") is unownable. Nobody can say what
#   belongs in it, it has no test that is not circular, and the first
#   loanword settles nothing. It also mistakes the SYMPTOM for the rule:
#   French-ness is a convention the workchain happens to follow, not the
#   property that decides which channel an artifact ships on.
#
#   A CURATED ALLOWLIST in this repo is a shared append point every
#   concurrent PR must contend for. bin/suite-docs-lint.sh has the numbers
#   from 2026-08-07: three conflict events in one day, all in one region of
#   one file, two rounds of hand-resolution, a human asking twice. Worse, an
#   allowlist can be defeated by OMISSION -- the single failure mode this
#   guard exists to make impossible.
#
#   A SELF-DECLARATION has neither problem. The command states its own kind
#   in its own file, on its own project's `bashified` branch. No file in this
#   repository is touched when a project ships a new command, so there is
#   nothing to contend for, and a command that declares nothing FAILS rather
#   than defaulting into a channel.
#
# This is bin/suite-docs-lint.sh's shape, reused deliberately: the note moved
# into the file it describes, and the lint asserts both halves.
#
# That the declaration is ALREADY THERE, in prose, in exactly this place, is
# the strongest argument that this is the right place for it. See the dated
# decision at the top of this file: vim-arcade stated its own kind in its own
# header, in its own repository, where no other project's PR ever touches it.
# The project had already declared. Nothing could read it. All this guard
# adds is a form the build can act on.
#
# ===========================================================================
# THE RULE
# ===========================================================================
#
#   Every row of a build's manifest.tsv names <project>/bin/<verb>. That file
#   MUST carry, within its first 90 lines, exactly one of:
#
#       # KIND: verb        a workchain verb. Ships on the nightly cut, holds
#                           still between cuts, and that stillness is correct.
#       # KIND: product     a product. Ships on its OWN cadence, from its own
#                           channel, and must not be in this manifest at all.
#
#   Anything else -- no marker, an empty marker, `# KIND: yes`, or a marker
#   buried below the header window -- is UNDECLARED and is a violation.
#
# Ninety lines, matching bin/tests/guard-estate.test.sh: it is a HEADER
# contract, and a reader must meet it before the code. A marker at line 400
# is not a thing anyone reads; it is a thing someone added to silence a lint,
# which is the move BUILD-DISCIPLINE.md exists to refuse.
#
# ===========================================================================
# WHY THIS READS NO OPT-OUT FILE, AND bin/lib/not-a-verb.tsv IN PARTICULAR
# ===========================================================================
#
# #145 landed bin/lib/not-a-verb.tsv the night before this: a curated list,
# in this repository, of executables that are deliberately not verbs. The
# obvious question is whether this guard should honour it rather than have a
# second opinion about the same thing. It should not, and the reason is that
# the two files cannot both be about the same command.
#
# THE POPULATIONS ARE DISJOINT BY CONSTRUCTION.
#
#   lib/not-a-verb.tsv exempts a HALF declaration -- an executable bin/<n>
#   with no man/<n>.1, or the inverse. cut-verb-build.sh omits every half
#   declaration from the manifest, exempted or not; a row buys a
#   `# NOT-A-VERB` line in the manifest instead of a refusal.
#
#   This guard grades MANIFEST ROWS. A manifest row is a name that carried
#   BOTH halves.
#
# So no name is ever in both, and honouring the file here would be wiring up
# a lookup that cannot match -- a mechanism built and never fired, which is
# this estate's own recurring defect and not a reconciliation of anything.
# bin/tests/verb-kind-lint.test.sh asserts the disjointness instead of this
# comment asserting it, because a claim about two data files is checkable and
# a paragraph is not.
#
# THEY ALSO ANSWER DIFFERENT QUESTIONS, which is why neither subsumes the
# other:
#
#   not-a-verb.tsv   "nobody would ever type this name expecting the verb
#                     contract" -- an installer, a cron wrapper, a scraper.
#                    Its own header states that test.
#   # KIND: product  "people DO type this, it has a name of its own, and it
#                    needs a release cadence the workchain deliberately
#                    refuses to have."
#
# `bibliothecaire/page92.py` is the first. `vim-arcade` is the second. A rule
# that collapsed them would have to call vim-arcade "not a verb and therefore
# not shipped", which is the opposite of what is wanted for it.
#
# AND THE MECHANISMS ARE CHOSEN FOR DIFFERENT CONTENTION. A curated list is
# right for not-a-verb.tsv: the judgement is realisateur's to make ABOUT
# another project's file, and the project may not agree it is not a verb. It
# is wrong here, where the judgement is the project's own and the file it
# belongs in is the project's own -- which is the argument two screens up, and
# is why an omission from a list cannot defeat this check.
#
# ===========================================================================
# THE GRANDFATHER RATCHET -- and why it names pairs rather than counting them
# ===========================================================================
#
# All 32 commands in the build predate this rule. Failing the nightly cut on
# all 32 tomorrow morning would mean the fleet stops receiving verbs until
# twelve separate repositories have each merged a one-line change, so the
# realistic outcome is that somebody deletes the check. bin/thermostat-wiring.sh
# already priced that: "a check nobody expects to be green is a document with
# an exit code."
#
# So bin/verb-kind-lint.ratchet NAMES the pairs it forgives. Not a count.
#
# A count-based bound is defeated in the ordinary course of business: declare
# one old command and add one new undeclared one in the same night, and the
# number does not move. Naming the pairs means a command that was not in the
# build when the ratchet was accepted is refused on its FIRST night, whatever
# the count did -- which is the whole requirement, since the next product to
# ship down the workchain will be a new arrival and not one of these 32.
#
# The ratchet only ever shrinks. `--accept` drops entries whose command has
# since declared itself or left the build, and REFUSES to enrol a command
# that was not already in it. There is no flag that grows it; growing it is a
# hand edit, which is reviewable, which is the point.
#
# ===========================================================================
# WHAT IT REFUSES TO DO
# ===========================================================================
#
# Grade a build it could not read. A manifest row whose executable is absent
# is not "declared nothing" -- it is a build this lint cannot speak about,
# and the two must not produce the same verdict. That is the `garde` shape
# from realisateur/MONKEY.md section 5, where skipping unreachable
# destinations made "nothing pending" indistinguishable from "everything is
# proven". Absent must not read as proven. BLIND is exit 2, never 0, and the
# admission is printed ABOVE the findings -- closeout-lint put "13 worktrees
# NOT examined" one line above twelve false alarms and exited 0.
#
# usage:  verb-kind-lint.sh [--build <dir>] [--accept] [--quiet]
# exit:   0  every command declares itself, no product in the workchain build
#         1  violation(s) -- named, with project, command and reason
#         2  BLIND: no build, no manifest, no rows, or a row it could not read.
#            NEVER 0. "Found nothing" and "nothing is wrong" are different.
set -uo pipefail

CLI_NAME='verb-kind-lint.sh'
CLI_SUMMARY='every command in a verb build declares its channel, and no product rides the workchain'
CLI_USAGE='  verb-kind-lint.sh --build <dir>        lint the build tree at <dir> (REQUIRED)
  verb-kind-lint.sh --build <dir> --accept
                                         shrink the grandfather ratchet to what is still needed
  verb-kind-lint.sh --build <dir> --quiet
                                         violations only'
CLI_FLAGS='--build --accept --quiet'
CLI_POSITIONAL=any   # flag VALUES (--build <dir>) read as positionals to cli-guard.
CLI_EXITS='  0  every command declares itself; no product in the workchain build
  1  violation(s)
  2  BLIND -- could not read the build. NEVER "clean".'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# --build IS REQUIRED. There is deliberately no default.
#
# This resolved the host's own adopted-build pin (the path PROP_PIN_PATH
# names in bin/lib/propagation-set.sh), so a bare run graded "whatever this
# machine happens to have adopted". Two things were wrong with it and only
# one is cosmetic.
#
# That the sentence above cannot simply WRITE the path is the guard working:
# propagation.test.sh greps every bin/*.sh for it, prose included, because a
# second reader is a second reader whether or not it is reachable code.
#
# bin/lib/propagation-set.sh names the pin as a fact with ONE reader
# (prop_current_pin), and lists by name the two scripts allowed to resolve
# the layout directly because they own it: install-verb-build.sh and
# ecosim-sensor-tick.sh. This guard owns no part of that layout -- it grades
# a directory. Becoming a third reader would buy nothing and cost the
# one-fact-one-reader property that file exists to hold.
#
# And every caller already names its tree: cut-verb-build.sh section 6a
# passes the tree it JUST assembled (never the host's adopted build -- they
# are different trees and grading the wrong one is the whole defect), the
# GATE line above passes $TREE, and this guard's suite passes a fixture. The
# default had no caller. It was a way to be pointed at something by accident,
# which is what #140 took away from silence-audit for the same reason: honour
# the tree you are pointed at, and refuse to guess one.
BUILD=''
RATCHET="${VERB_KIND_RATCHET:-$ROOT/bin/verb-kind-lint.ratchet}"
ACCEPT=0
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --build)  BUILD="${2:?--build needs a directory}"; shift ;;
    --accept) ACCEPT=1 ;;
    --quiet)  QUIET=1 ;;
    *) printf '%s: unknown argument: %s\n' "$CLI_NAME" "$1" >&2; exit 2 ;;
  esac
  shift
done

# How far into a file the declaration may be. See the header.
HEAD_LINES="${VERB_KIND_HEAD_LINES:-90}"

say()   { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
loud()  { printf '%s\n' "$*"; }
blind() { printf 'BLIND: %s\n' "$*" >&2
          printf '%s: refusing to grade a build it could not read. This is NOT "clean".\n' "$CLI_NAME" >&2
          exit 2; }

# --- the build --------------------------------------------------------------
# No --build is a USAGE error (2), not a verdict. It is the same exit code as
# BLIND on purpose: both mean "this run graded nothing", and the one thing
# neither may ever be mistaken for is clean.
[ -n "$BUILD" ] || { printf '%s: --build <dir> is required; there is no default build.\n' "$CLI_NAME" >&2
                     printf '%s\n' "$CLI_USAGE" >&2; exit 2; }
[ -d "$BUILD" ] || blind "no build tree at $BUILD"
MANIFEST="$BUILD/manifest.tsv"
[ -f "$MANIFEST" ] || blind "$BUILD carries no manifest.tsv -- it is not a build"
# `grep -c` PRINTS 0 and EXITS 1 when it matches nothing, so the obvious
# `|| echo 0` fallback appends a SECOND zero and rows becomes "0\n0". The
# empty-manifest case still reached BLIND, but by accident: `[ "0\n0" -gt 0 ]`
# is an integer-expression ERROR, and bash's own diagnostic printed above the
# admission. Right verdict, wrong mechanism, and a reader had to decode a
# shell error to see it. `|| true` swallows the exit status without adding
# output; the empty guard covers grep failing to print at all.
rows="$(grep -cv '^#' "$MANIFEST" 2>/dev/null || true)"
[ -n "$rows" ] || rows=0
[ "$rows" -gt 0 ] || blind "$MANIFEST has no rows. A build with no commands is an unreadable build, not an ecosystem with none."

# --- the ratchet ------------------------------------------------------------
# One entry per line: `undeclared <project>/<verb>`. Comments and blanks
# ignored, so the file can explain itself.
FORGIVEN=""
if [ -f "$RATCHET" ]; then
  FORGIVEN=" $(grep -vE '^[[:space:]]*(#|$)' "$RATCHET" \
                | sed -n 's/^[[:space:]]*undeclared[[:space:]]\+//p' \
                | tr '\n' ' ')"
fi
forgiven() { case "$FORGIVEN" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# --- read every row ---------------------------------------------------------
# TWO PASSES, and the order is the point. Pass one collects; pass two prints
# BLIND lines, then findings. A guard that streams its output prints them in
# whatever order the manifest happens to be sorted in, and the admission ends
# up under the noise.
declare -a BLIND_LINES=() PRODUCTS=() UNDECLARED=() GRANDFATHERED=() DECLARED_VERBS=()

while IFS=$'\t' read -r project verb sha url; do
  [ -n "${verb:-}" ] || continue
  case "$project" in ''|*/*|.|..) BLIND_LINES+=("manifest row names an unusable project: '$project'"); continue ;; esac
  case "$verb"    in ''|*/*|.|..) BLIND_LINES+=("manifest row names an unusable command: '$verb'"); continue ;; esac
  f="$BUILD/$project/bin/$verb"
  if [ ! -f "$f" ]; then
    # NOT a violation. install-verb-build.sh already refuses a build with a
    # missing executable; here it means this lint cannot read the
    # declaration, which is a different sentence from "there is none".
    BLIND_LINES+=("$project/$verb: the manifest names bin/$verb but no such file is in the build -- cannot read its declaration")
    continue
  fi
  kind="$(head -n "$HEAD_LINES" "$f" 2>/dev/null \
            | sed -n 's/^#[[:space:]]*KIND:[[:space:]]*//p' | head -1)"
  # Trim, and take the first word so `# KIND: product -- ships from its own
  # release` is a valid declaration with a reason attached.
  kind="${kind%%[[:space:]]*}"
  case "$kind" in
    verb)    DECLARED_VERBS+=("$project/$verb") ;;
    product) PRODUCTS+=("$project/$verb") ;;
    '')      if forgiven "$project/$verb"; then GRANDFATHERED+=("$project/$verb")
             else UNDECLARED+=("$project/$verb|no '# KIND: verb' or '# KIND: product' in its first $HEAD_LINES lines"); fi ;;
    *)       # A marker that is not a kind is worse than none: it looks
             # declared to a reader. Never forgiven by the ratchet, which
             # forgives silence only.
             UNDECLARED+=("$project/$verb|'# KIND: $kind' is not a channel. Say 'verb' or 'product'.") ;;
  esac
done < <(grep -v '^#' "$MANIFEST")

# --- report: BLIND first, always --------------------------------------------
if [ "${#BLIND_LINES[@]}" -gt 0 ]; then
  for b in "${BLIND_LINES[@]}"; do loud "  BLIND $b"; done
  loud ""
  blind "${#BLIND_LINES[@]} manifest row(s) could not be read. The rest of this build is UNGRADED."
fi

violations=0

say "== A. EVERY COMMAND IN THE BUILD DECLARES ITS CHANNEL =="
for d in ${DECLARED_VERBS+"${DECLARED_VERBS[@]}"}; do say "  ok    $d: verb"; done
for g in ${GRANDFATHERED+"${GRANDFATHERED[@]}"}; do
  # Printed EVERY run, at findings volume, even though it does not fail the
  # build. A grandfathered entry that goes quiet is one nobody ever retires.
  loud "  OWED  $g: undeclared, held by the ratchet -- add '# KIND: verb' or '# KIND: product' to its own bin/$([ -n "$g" ] && printf '%s' "${g#*/}")"
done
for u in ${UNDECLARED+"${UNDECLARED[@]}"}; do
  loud "  UNDECLARED ${u%%|*}: ${u#*|}"
  violations=$((violations + 1))
done

say ""
say "== B. NO PRODUCT RIDES THE WORKCHAIN BUILD =="
for p in ${PRODUCTS+"${PRODUCTS[@]}"}; do
  loud "  PRODUCT ${p}: declares '# KIND: product' but is in the workchain manifest."
  loud "          A product ships on its own cadence; this channel is built NOT to move"
  loud "          between nightly cuts (provision/verbs-meta/build-verbs.yml: \"that"
  loud "          stability is the feature\"). Cut it from its own channel instead."
  violations=$((violations + 1))
done
[ "${#PRODUCTS[@]}" -eq 0 ] && say "  ok    no product in this build's manifest"

# --- the ratchet's own hygiene ----------------------------------------------
# An entry whose command has declared itself, or has left the build, is stale.
# Left in place it would silently re-forgive that name if it ever regressed,
# which is a ratchet quietly loosening itself.
STALE=""
if [ -n "$FORGIVEN" ]; then
  for e in $FORGIVEN; do
    still=0
    for u in ${UNDECLARED+"${UNDECLARED[@]}"}; do [ "${u%%|*}" = "$e" ] && still=1; done
    for g in ${GRANDFATHERED+"${GRANDFATHERED[@]}"}; do [ "$g" = "$e" ] && still=1; done
    [ "$still" -eq 1 ] || STALE="$STALE $e"
  done
fi
if [ -n "$STALE" ]; then
  say ""
  say "== C. RATCHET ENTRIES THAT ARE NO LONGER NEEDED =="
  for s in $STALE; do say "  stale $s: declared itself or left the build -- drop it (--accept does)"; done
fi

# --- --accept: shrink, or refuse --------------------------------------------
if [ "$ACCEPT" -eq 1 ]; then
  # Only entries already in the ratchet AND still undeclared survive. A
  # command that is undeclared but was NOT in the ratchet is deliberately not
  # written: --accept is not a way to enrol today's mistake.
  #
  # THE EXISTING PROSE IS CARRIED OVER, and that is not a nicety. This block
  # used to print a fixed six-line header and then the entries, which meant
  # regenerating the file DELETED every hand-written justification in it --
  # including the paragraph the file's own last line mandates ("DO NOT add a
  # second entry of this kind without the same paragraph"). A ratchet whose
  # only regeneration path silently erases the reasons its entries exist
  # converts, on first use, into a bare list of names nobody can review. The
  # reasons are the reviewable part; the names are derivable.
  #
  # Read BEFORE the redirect: `{ ...; } > "$RATCHET"` truncates the file
  # before the block runs, so anything read inside it reads nothing.
  header=''
  if [ -f "$RATCHET" ]; then
    header="$(grep -E '^[[:space:]]*(#|$)' "$RATCHET" | grep -vE '^# accepted ')"
  fi
  if [ -z "$header" ]; then
    header="$(printf '%s\n' \
      "# verb-kind-lint.ratchet -- commands in the build that predate the" \
      "# declaration rule and are forgiven for now. See bin/verb-kind-lint.sh." \
      "#" \
      "# SHRINKS ONLY. --accept drops entries whose command has declared itself" \
      "# or left the build, and will not add one. Growing this file is a hand" \
      "# edit, on purpose, so that it is reviewed.")"
  fi
  {
    printf '%s\n' "$header"
    echo "# accepted $(date -u +%Y-%m-%dT%H:%M:%SZ) against a build of $rows command(s)"
    for g in ${GRANDFATHERED+"${GRANDFATHERED[@]}"}; do echo "undeclared $g"; done
  } > "$RATCHET" || { printf '%s: cannot write %s\n' "$CLI_NAME" "$RATCHET" >&2; exit 1; }
  n="${#GRANDFATHERED[@]}"
  loud ""
  loud "$CLI_NAME: ratchet now forgives $n command(s)."
  [ "$violations" -eq 0 ] || loud "$CLI_NAME: $violations violation(s) NOT forgiven -- --accept does not enrol them."
  exit 0
fi

loud ""
if [ "$violations" -gt 0 ]; then
  loud "$CLI_NAME: $violations violation(s) over $rows command(s) in $(awk -F'\t' '!/^#/{print $1}' "$MANIFEST" | sort -u | wc -l | tr -d ' ') project(s)."
  exit 1
fi
# THE CLEAN LINE MAY NOT OVERSTATE WHAT WAS VERIFIED, and the unconditional
# version of it did. It read "$rows command(s), each declaring its channel"
# whatever the ratchet was holding, so on the day this landed -- 33 rows, all
# 33 grandfathered, none declaring anything -- it printed
#
#   verb-kind-lint.sh: 33 command(s), each declaring its channel; ...
#   verb-kind-lint.sh: 33 command(s) still owed a declaration, held by the ratchet.
#
# two contradictory sentences, the false one first. A summary that claims the
# property the OWED lines directly above it deny is the same defect those OWED
# lines exist to prevent: a guard exiting 0 while saying something untrue about
# what it found. So the sentence is only spoken when it is true, and otherwise
# the counts are split and the debt is named in the same breath.
if [ "${#GRANDFATHERED[@]}" -eq 0 ]; then
  say "$CLI_NAME: $rows command(s), each declaring its channel; no product in the workchain build."
else
  loud "$CLI_NAME: $rows command(s) -- ${#DECLARED_VERBS[@]} declaring their channel, ${#GRANDFATHERED[@]} still OWED and held by the ratchet. No product in the workchain build."
fi
exit 0
