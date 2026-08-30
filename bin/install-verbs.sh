#!/usr/bin/env bash
# install-verbs.sh -- the DECLARED SET of the ecosystem's verb surface, and
# whether this host actually has it.
#
# TRAPS (the rest of this header is in the vault):
# WHY THIS EXISTS
# ---------------
# `installe` (senechal's verb) is the mechanism: it links one verb into
# ~/.local/bin, records it in a manifest, refuses to clobber anything it does
# not own, and can retire what it installed. This script does NOT replace it
# and never creates a link itself -- every write goes through `installe`.
# THE RULE THIS ENFORCES:
#   check the DECLARED set, never the intersection, or absence reports clean.
# An intersection walk cannot see an ABSENT link -- it never iterates the file
# that is not there -- so with no overlap at all it reports clean.

set -uo pipefail

CLI_NAME='install-verbs.sh'
CLI_SUMMARY='report (and with --apply, install) the declared verb surface, via installe'
CLI_USAGE='  install-verbs.sh           preflight: report the declared set vs this host
  install-verbs.sh --apply   install what is ABSENT, by calling installe'
CLI_FLAGS='--apply'
CLI_POSITIONAL=none
CLI_EXITS='  0  every declared verb is present and points at the project that declares it
  1  findings: something declared is ABSENT, SHADOWED, BROKEN, UNOWNED, FOREIGN
     or declared twice'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"
. "$(dirname "${BASH_SOURCE[0]}")/lib/verb-set.sh"

# Overridable for tests only (bin/tests/*, which also override HOME so nothing
# real is written). Without the override a test silently runs against the real
# ~/.local/bin. INSTALLE_* names are shared
# with `installe` on purpose -- two tools disagreeing about where verbs live is
# the drift this file exists to catch.
PROJECTS="${INSTALLE_PROJECTS:-$HOME/Documents/Projects}"
BIN="${INSTALLE_BIN:-$HOME/.local/bin}"
MANIFEST="${INSTALLE_MANIFEST:-${XDG_DATA_HOME:-$HOME/.local/share}/installe/manifest.tsv}"
INSTALLE="${INSTALLE_CMD:-installe}"

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

findings=0
note() { printf '%s\n' "$*"; }
row()  { printf '%-9s %-16s %-16s %s\n' "$1" "$2" "$3" "${4:-}"; }
flag() { findings=$((findings + 1)); }

manifest_target() {
  [ -f "$MANIFEST" ] || return 0
  awk -F'\t' -v n="$1" '$1 == n {print $2; exit}' "$MANIFEST"
}

note "install-verbs -- the declared verb surface"
note "  projects:  $PROJECTS"
note "  installed: $BIN"
note "  manifest:  $MANIFEST"
note "  mode:      $( ((APPLY)) && echo APPLY || echo 'preflight (nothing is written)')"
note ""

[ -d "$PROJECTS" ] || { echo "$CLI_NAME: FATAL: no such directory: $PROJECTS" >&2; exit 1; }

# installe is the only thing allowed to write a link. Its absence is a finding,
# not an invitation to `ln -s` here -- hand-installing is the defect this whole
# script exists to make impossible.
have_installe=1
command -v "$INSTALLE" >/dev/null 2>&1 || have_installe=0

declare -A OWNER=()      # verb -> first project declaring it
declare -A ALSO=()       # verb -> other projects declaring it
n_declared=0

while IFS=$'\t' read -r project verb; do
  [ -n "$verb" ] || continue
  n_declared=$((n_declared + 1))
  if [ -n "${OWNER[$verb]:-}" ]; then
    ALSO[$verb]="${ALSO[$verb]:-}${ALSO[$verb]:+ }$project"
  else
    OWNER[$verb]="$project"
  fi
done < <(verb_set_declared)

note "-- declared set (derived from each project's bashified branch) --------"
last=""
line=""
while IFS=$'\t' read -r project verb; do
  [ -n "$verb" ] || continue
  if [ "$project" != "$last" ]; then
    [ -n "$last" ] && note "  $last: $line"
    last="$project"; line=""
  fi
  line="${line}${line:+ }$verb"
done < <(verb_set_declared)
[ -n "$last" ] && note "  $last: $line"

note ""
note "  $n_declared verb(s) declared by $(verb_set_declared | cut -f1 | sort -u | grep -c .) project(s)"
note ""

if [ "$n_declared" = 0 ]; then
  # Zero declared is never "clean". It means discovery broke -- exactly the
  # shape of deploy-drift-check's "nothing to check / exit 0".
  echo "$CLI_NAME: FATAL: no project declares a verb. That is a discovery failure, not a clean host." >&2
  exit 1
fi

# -------------------------------------------------------------- name clashes --
# Two projects declaring the same name is a defect in its own right: only one
# can own it on PATH, and which one wins is whichever was installed last. The
# generator now refuses to coin into this (bin/lib/verb-set.sh), but existing
# collisions have to be resolved by renaming one verb.
if [ "${#ALSO[@]}" -gt 0 ]; then
  note "-- COLLISION: one name, more than one project ------------------------"
  for v in $(printf '%s\n' "${!ALSO[@]}" | sort); do
    row COLLISION "$v" "${OWNER[$v]}" "also declared by: ${ALSO[$v]} -- rename one; only one can own the name"
    flag
  done
  note ""
fi

# ------------------------------------------------------------- registration --
# THE CLASSIFICATION, RE-CHECKED. A verb is a UTILITY's finished form; a
# product's finished form is an event outside the computer (vault:realisateur/WAITING-ROOM.md).
SCHEDULE_DIR="${SCHEDULE_DIR:-$PROJECTS/scheduler/schedule}"
note "-- registration (the registry is what 'utility' means here) -----------"
if [ ! -d "$SCHEDULE_DIR" ]; then
  # BLIND, never clean. If the registry cannot be read, every project would
  # otherwise report UNREGISTERED -- turning "I cannot see the registry" into
  # "nothing here is a utility", which is the strong claim made from an
  # absence. One finding for the blindness; none for the projects.
  note "  BLIND: cannot read the registry at $SCHEDULE_DIR"
  note "         Not reporting anything UNREGISTERED from that -- an unreadable"
  note "         registry is not an empty one. Set SCHEDULE_DIR if it moved."
  flag
else
  for project in $(verb_set_declared | cut -f1 | sort -u); do
    n="$(verb_set_declared | awk -F'\t' -v p="$project" '$1 == p' | wc -l)"
    if [ -f "$SCHEDULE_DIR/$project.conf" ]; then
      printf '  %-13s %-16s %s\n' registered "$project" "$n verb(s)"
    else
      printf '  %-13s %-16s %s\n' UNREGISTERED "$project" \
        "$n verb(s), but no $SCHEDULE_DIR/$project.conf -- a verb is a utility's finished form; register it or retire the branch"
      flag
    fi
  done
fi
note ""

# ------------------------------------------------------------------- per verb --
note "-- this host ---------------------------------------------------------"
row STATUS verb project detail

to_install=()
for v in $(printf '%s\n' "${!OWNER[@]}" | sort); do
  project="${OWNER[$v]}"
  repo="$PROJECTS/$project"
  tree="$(verb_set_worktree_of "$repo")"
  want=""
  [ -n "$tree" ] && want="$(readlink -f -- "$tree/bin/$v" 2>/dev/null || printf '%s' "$tree/bin/$v")"
  dest="$BIN/$v"

  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    # THE CASE THE INTERSECTION CHECK CANNOT SEE.
    if [ -n "$tree" ]; then
      row ABSENT "$v" "$project" "declared, not on PATH (fix: installe verb $project $v)"
    else
      row ABSENT "$v" "$project" "declared, not on PATH, bashified not checked out (installe verb $project $v does both)"
    fi
    to_install+=("$project:$v")
    flag
    continue
  fi

  if [ -L "$dest" ]; then
    tgt="$(readlink -f -- "$dest" 2>/dev/null || true)"
    if [ -z "$tgt" ] || [ ! -e "$tgt" ]; then
      row BROKEN "$v" "$project" "symlink -> $(readlink "$dest") which does not exist"
      flag
      continue
    fi
    # Under a collision there is no single right answer, so do not assert one:
    # naming a "wrong" target would invent a winner the declarations do not
    # support. The COLLISION row above is the finding; this one states the fact.
    if [ -n "${ALSO[$v]:-}" ]; then
      row CONTESTED "$v" "$project" "-> $tgt (contested by: ${ALSO[$v]}; whichever lost is unreachable by name)"
      continue
    fi
    if [ -n "$want" ] && [ "$tgt" != "$want" ]; then
      row SHADOWED "$v" "$project" "on PATH but -> $tgt, not $want"
      flag
      continue
    fi
    owned="$(manifest_target "$v")"
    if [ -z "$owned" ]; then
      # Right target, but installe did not put it there, so `installe retire`
      # will refuse it and no record says why it exists. A hand-made link that
      # happens to be correct is still the failure mode being retired -- it is
      # the shape of the symlink whose deletion caused the July outage.
      row UNOWNED "$v" "$project" "correct target, not in installe's manifest (hand-made; adopt with: installe verb $project $v)"
      flag
      continue
    fi
    row OK "$v" "$project" "-> $tgt"
    continue
  fi

  row FOREIGN "$v" "$project" "$dest is a regular file, not a symlink -- a human put it there; refusing to touch it"
  flag
done

# --------------------------------------------------------------------- apply --
if ((APPLY)) && [ "${#to_install[@]}" -gt 0 ]; then
  note ""
  note "-- apply (via installe; this script never creates a link itself) -----"
  if [ "$have_installe" = 0 ]; then
    echo "$CLI_NAME: FATAL: installe is not on PATH, and nothing here will hand-install in its place." >&2
    echo "  A missing guard is a finding, not an inconvenience. Link it first:" >&2
    echo "    ln -s $PROJECTS/senechal-verbs/bin/installe $BIN/installe" >&2
    exit 1
  fi
  for pair in "${to_install[@]}"; do
    project="${pair%%:*}"; v="${pair#*:}"
    note "  installe verb $project $v"
    if "$INSTALLE" verb "$project" "$v"; then
      note "    installed"
    else
      note "    FAILED (exit $?) -- left alone; installe said why above"
    fi
  done
fi

# ------------------------------------------------------------------- verdict --
note ""
if [ "$have_installe" = 0 ]; then
  note "NOTE: installe is not on PATH. Preflight still reports the declared set,"
  note "      but nothing can be installed until it is."
fi
if [ "$findings" = 0 ]; then
  note "OK -- all $n_declared declared verb(s) present and pointing at the project that declares them."
else
  note "$findings finding(s) above."
  if ((APPLY)); then
    note "Re-run to confirm what the apply actually closed -- an apply is not a verdict."
  else
    note "Preflight only. Nothing was written. Re-run with --apply to install the ABSENT rows."
  fi
fi
exit $(( findings > 0 ? 1 : 0 ))
