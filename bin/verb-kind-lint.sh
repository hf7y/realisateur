#!/usr/bin/env bash
# verb-kind-lint.sh -- a command in the verb build says which CHANNEL it
# belongs to, in its own file, or it does not ship.
#
# RUNNER: bin/tests/verb-kind-lint.test.sh bin/cut-verb-build.sh
# GUARD-TEST: bin/tests/verb-kind-lint.test.sh
# GATE: default --build $TREE
#
# THE CRITERION, semantic and not linguistic, decided 2026-08-05:
#     a VERB is a thing you tell the machine to do
#     a PRODUCT is a thing with a name of its own
# French-ness is a convention the workchain follows, not the property that
# decides which channel an artifact ships on -- so this reads a DECLARATION
# (`# KIND: verb` / `# KIND: product` in the command's own file, within the
# first 90 lines) and not a wordlist. A list in this repo would rot; the
# project's own file cannot go stale about itself.
#
# TRAP: it reads no opt-out file, and bin/lib/not-a-verb.tsv in particular.
#   The populations are disjoint by construction -- not-a-verb.tsv names
#   things that never enter the build, this lints things that did -- so
#   honouring it here would wire two mechanisms that can never overlap.
#
# TRAP: the ratchet NAMES the pairs it forgives rather than counting them.
#   A count-based bound is defeated in the ordinary course of business:
#   declare one, add one, and the count is unchanged while the debt moved.
#   It only ever shrinks; `--accept` drops entries whose command now declares.
#
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
  3  BLIND -- could not read the build. NEVER "clean".'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# --build IS REQUIRED. There is deliberately no default.
#
# This resolved the host's own adopted-build pin (the path PROP_PIN_PATH
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
          exit 3; }

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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
# The grandfathered set is named EVERY run -- an entry that goes quiet is one
# nobody ever retires -- but on ONE line, not one loud line each carrying fix
# instructions. All of them live in 12 OTHER projects' repositories and cannot
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
if [ "${#GRANDFATHERED[@]}" -gt 0 ]; then
  loud "  OWED  ${#GRANDFATHERED[@]} undeclared, held by the ratchet: ${GRANDFATHERED[*]}"
  loud "        each needs '# KIND: verb' or '# KIND: product' in its own project's file"
fi
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
if [ "${#GRANDFATHERED[@]}" -eq 0 ]; then
  say "$CLI_NAME: $rows command(s), each declaring its channel; no product in the workchain build."
else
  loud "$CLI_NAME: $rows command(s) -- ${#DECLARED_VERBS[@]} declaring their channel, ${#GRANDFATHERED[@]} still OWED and held by the ratchet. No product in the workchain build."
fi
exit 0
