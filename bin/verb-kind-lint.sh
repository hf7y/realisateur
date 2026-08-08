#!/usr/bin/env bash
# verb-kind-lint.sh -- a command in the verb build says which CHANNEL it
# belongs to, in its own file, or it does not ship.
#
# GUARD: does every command in a verb build declare itself a workchain verb or a product, and is no product riding the workchain channel?
# RUNNER: bin/tests/verb-kind-lint.test.sh bin/cut-verb-build.sh
# GUARD-TEST: bin/tests/verb-kind-lint.test.sh
# GATE: default --build $TREE
# VERIFIED: 2026-08-08 via bash bin/verb-kind-lint.sh --build ~/.local/share/verb-builds/current and bash bin/tests/verb-kind-lint.test.sh
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
CLI_USAGE='  verb-kind-lint.sh                      lint the current build
  verb-kind-lint.sh --build <dir>        lint a build tree by path
  verb-kind-lint.sh --accept             shrink the grandfather ratchet to what is still needed
  verb-kind-lint.sh --quiet              violations only'
CLI_FLAGS='--build --accept --quiet'
CLI_POSITIONAL=any   # flag VALUES (--build <dir>) read as positionals to cli-guard.
CLI_EXITS='  0  every command declares itself; no product in the workchain build
  1  violation(s)
  2  BLIND -- could not read the build. NEVER "clean".'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${VERB_BUILD_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/verb-builds}"
BUILD="$BUILD_ROOT/current"
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
[ -d "$BUILD" ] || blind "no build tree at $BUILD"
MANIFEST="$BUILD/manifest.tsv"
[ -f "$MANIFEST" ] || blind "$BUILD carries no manifest.tsv -- it is not a build"
rows="$(grep -cv '^#' "$MANIFEST" 2>/dev/null || echo 0)"
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
  {
    echo "# verb-kind-lint.ratchet -- commands in the build that predate the"
    echo "# declaration rule and are forgiven for now. See bin/verb-kind-lint.sh."
    echo "#"
    echo "# SHRINKS ONLY. --accept drops entries whose command has declared itself"
    echo "# or left the build, and will not add one. Growing this file is a hand"
    echo "# edit, on purpose, so that it is reviewed."
    echo "# accepted $(date -u +%Y-%m-%dT%H:%M:%SZ)"
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
say "$CLI_NAME: $rows command(s), each declaring its channel; no product in the workchain build."
[ "${#GRANDFATHERED[@]}" -eq 0 ] || loud "$CLI_NAME: ${#GRANDFATHERED[@]} command(s) still owed a declaration, held by the ratchet."
exit 0
