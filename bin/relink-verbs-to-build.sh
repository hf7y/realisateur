#!/usr/bin/env bash
# relink-verbs-to-build.sh -- move every ~/.local/bin verb off a `bashified`
# WORKTREE of a dev clone and onto the installed verb build.
#
# WHY THIS EXISTS, AND WHY IT IS NOT `install-verb-build.sh --link`
# -----------------------------------------------------------------
# `--link` refuses any name it does not already own:
#
#     *) row SKIP "$verb" "not ours -> $tgt"; skipped=...; continue ;;
#
# On a host where `installe` owns all 28 verbs that is EVERY name, and the run
# reports "28 left alone" and exits 0. That is a successful-looking no-op --
# precisely the exit-0 no-op BUILD-DISCIPLINE.md forbids. `--link` was written
# to stop short of this decision, not to make it.
#
# The migration route is `installe verb <project> <name>` itself, which since
# senechal#22 (merged 2026-08-05) links from
# ~/.local/share/verb-builds/current/<project>/bin/<verb> instead of running
# `git worktree add`. This script is a loop over the build's own manifest,
# driven by the build's own `installe`, so the thing that installs a verb and
# the thing that declares one cannot drift apart.
#
# WHAT IT REFUSES
# ---------------
# - A missing or manifest-less build: linking to a build that is not there
#   would break every verb on the host at once.
# - A build whose `installe` predates senechal#22. Using the OLD installe to
#   migrate would bootstrap the new world with the binary that creates
#   worktrees. Checked by behaviour (does it mention verb-builds at all),
#   not by a version string.
# - A verb whose build file is absent or not executable: reported LOUDLY and
#   counted as a failure, never silently passed over.
#
# It also re-reads the symlink after each `installe` call rather than trusting
# exit 0 -- SPRINT-RECORD-2026-08-05 §7.4 records a build where `-f && -x`
# passed and nothing could actually run.
#
# ============================================================================
# --adopt-existing, AND THE RULE THAT DECIDES WHEN AN OVERWRITE IS LEGITIMATE
# ============================================================================
#
# MEASURED on ecosim@monkey, 2026-08-07: 19 of 33 verbs relinked, 14 FAILED.
#
#     installe: REFUSED: arpente is already on the path at ~/.local/bin/arpente
#     and installe did not put it there ... --force overwrites it
#
# The 14 were exactly the verbs that ALREADY HAD A CLONE-BACKED SHIM -- which
# is to say, exactly the population this script's own header says it exists to
# move. It could only link names that had never been installed. Every account
# provisioned the old way was stuck at ~58% consumption, and the script
# reported that as a failure it could do nothing about.
#
# THE FIX IS NOT `--force` ON EVERY CALL. installe's refusal is a real guard:
# ~/.local/bin holds hand-placed files, scheduler-generated loops and vendored
# binaries, and "overwrite is a removal wearing a friendlier name" is its own
# words. A blanket force in a loop over 33 names is a script that removes
# whatever it finds. So the DECISION is made here, per verb, against a stated
# rule, and only the verbs that pass it are forced.
#
# THE RULE. A name is ADOPTABLE only if ALL FOUR hold:
#
#   1. THE BUILD PROVIDES IT. The build's own manifest declares (project,
#      verb) and $CUR/<project>/bin/<verb> is executable. We are not choosing
#      what the name should mean; the build already did, and this script's
#      only job is to make the name resolve there.
#
#   2. IT IS A SYMLINK, never a regular file. A symlink is a pointer and
#      re-pointing it loses nothing; a regular file at that path is somebody's
#      CONTENT. This is installe's own line and it is restated here so the
#      refusal survives even if this script is ever pointed at a different
#      installer.
#
#   3. IT DOES NOT ALREADY RESOLVE INTO THE CURRENT BUILD. That is `already`,
#      not an adoption, and it is counted separately.
#
#   4. ITS TARGET IS ONE OF THE THREE STALE CHANNELS THIS SCRIPT EXISTS TO
#      RETIRE, and nothing else:
#        a. under $PROJECTS (default ~/Documents/Projects) -- a dev clone or a
#           bashified worktree of one. This is the case in the header: `main`
#           acting as a deploy ref through the back door.
#        b. under $BUILD_ROOT but not `current` -- a link nailed to a
#           superseded build, which will never advance again.
#        c. DANGLING: the target does not exist. A broken shim cannot be made
#           worse, and repairing one is the least destructive act available.
#
# ANYTHING ELSE IS STILL REFUSED, loudly and by name -- a symlink into /usr, a
# distro package, a vendored binary, a hand-written script, a regular file.
# installe's guard stands for every one of them, which is the whole point of
# writing the rule down instead of passing --force.
#
# AND IT IS OPT-IN. Without --adopt-existing an adoptable verb is reported as
# NEEDS-ADOPT and counted as a failure, so the default run still refuses to
# overwrite anything and the operator has to ask. A silent force is how a
# migration script becomes an incident.
#
# WHY THIS IS SAFE AGAINST A LIVE 6-HOURLY RUNNER. The 14 include the live
# dispatch verbs (arme, dose, jauge, rapporte, relis) and `installe` itself.
#   - Each adoption is one `ln -sfn`-equivalent inside installe, per name. The
#     window in which a name does not resolve is a single syscall pair, not
#     the length of this loop, and a runner that misses it re-runs in 6h.
#   - Relinking `installe` cannot pull the rug out from under this script: the
#     installer invoked below is $CUR/senechal/bin/installe, the BUILD's copy,
#     addressed by path and never through ~/.local/bin. Whatever happens to
#     the shim, the loop keeps running the same binary it started with.
#   - Both old and new targets are executable verb implementations. A
#     dispatch that resolves either side of the switch runs a working verb.
#
# usage:
#   relink-verbs-to-build.sh                     dry run; prints what would change
#   relink-verbs-to-build.sh --apply             link the verbs nothing else owns
#   relink-verbs-to-build.sh --apply --adopt-existing
#                                                also re-point shims that match
#                                                the rule above
#
# exit: 0 every declared verb resolves into the build; 1 refused or any failure
set -uo pipefail

APPLY=0
ADOPT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    -n|--dry-run) APPLY=0 ;;
    --adopt-existing) ADOPT=1 ;;
    *) printf 'usage: %s [--apply] [--adopt-existing]\n' "${0##*/}" >&2; exit 2 ;;
  esac
  shift
done

BUILD_ROOT="${BUILD_ROOT:-$HOME/.local/share/verb-builds}"
CUR="$BUILD_ROOT/current"
BIN="${BIN:-$HOME/.local/bin}"
MANIFEST="$CUR/manifest.tsv"
INSTALLE="$CUR/senechal/bin/installe"
# The dev-clone root, read from the SAME variable installe reads it from, so
# the two cannot disagree about where a dev clone lives.
PROJECTS="${INSTALLE_PROJECTS:-$HOME/Documents/Projects}"

die() { printf 'relink-verbs-to-build.sh: %s\n' "$*" >&2; exit 1; }

[ -d "$CUR" ]      || die "no installed build at $CUR -- run install-verb-build.sh --latest --apply"
[ -f "$MANIFEST" ] || die "build at $CUR has no manifest.tsv; refusing to guess the verb set"
[ -x "$INSTALLE" ] || die "the build carries no executable installe at $INSTALLE"
grep -q 'verb-builds' "$INSTALLE" ||
  die "$INSTALLE never mentions verb-builds: this build predates senechal#22, re-cut it"

# classify() reports its REASON on fd 3 rather than stdout, so the state word
# stays machine-readable in `$(...)` while the human sentence travels with it.
WHYFILE="$(mktemp)"; trap 'rm -f "$WHYFILE"' EXIT

printf '== build %s\n' "$(readlink "$CUR")" >&2
[ "$APPLY" -eq 1 ] || printf '== DRY RUN (pass --apply to change anything)\n' >&2
[ "$ADOPT" -eq 1 ] && printf '== --adopt-existing: shims matching the adoption rule will be RE-POINTED\n' >&2

# classify <verb> -- prints one word on stdout and, for a refusal, the reason
# on fd 3. THE RULE FROM THE HEADER, in one place, so the dry run and the
# apply run cannot disagree about what would happen. Nothing here writes.
#
#   free    nothing is at $BIN/<verb>; a plain link, no force needed
#   already it resolves into the current build; nothing to do
#   adopt   a symlink into a stale channel this script exists to retire
#   refuse  anything else -- installe's guard stands and we say why
classify() {
  local verb="$1" dest="$BIN/$1" have
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then echo free; return 0; fi
  # Rule 2, checked FIRST and before anything is resolved: a regular file at
  # that path is content somebody wrote. --force re-points a name; it never
  # deletes a file. Same refusal installe makes, restated so it survives a
  # change of installer.
  if [ ! -L "$dest" ]; then
    echo refuse
    printf 'a regular file, not a symlink -- move it aside yourself if you mean to\n' >&3
    return 0
  fi
  have="$(readlink "$dest")"
  # Rule 3.
  case "$have" in
    "$CUR/"*|"$BUILD_ROOT/current/"*) echo already; return 0 ;;
  esac
  # Rule 4, the three stale channels and nothing else.
  #
  # 4c FIRST, deliberately. A dangling link is dangling wherever it pointed,
  # and that is the more useful thing to print: a link into a dev clone that
  # still resolves and one whose target was deleted are different findings for
  # the operator even though they get the same treatment here. Ordering the
  # path cases first would have reported the deleted one as merely stale.
  if [ ! -e "$dest" ]; then
    # -L true and -e false: the link exists and its target does not.
    echo adopt; printf 'a DANGLING shim -- its target %s does not exist\n' "$have" >&3; return 0
  fi
  case "$have" in
    "$PROJECTS/"*)
      echo adopt; printf 'a dev clone or bashified worktree under %s\n' "$PROJECTS" >&3; return 0 ;;
    "$BUILD_ROOT/"*)
      echo adopt; printf 'pinned to a superseded build under %s\n' "$BUILD_ROOT" >&3; return 0 ;;
  esac
  echo refuse
  printf 'a symlink to %s, which is none of the stale channels this script retires\n' "$have" >&3
}

moved=0; already=0; failed=0; total=0; adopted=0; needs_adopt=0
while IFS=$'\t' read -r project verb _rest; do
  case "${project:-}" in ''|'#'*) continue ;; esac
  [ -n "${verb:-}" ] || continue
  total=$((total + 1))

  # Rule 1. The build must provide it, or there is nothing to point at and
  # the question of overwriting never arises.
  want="$CUR/$project/bin/$verb"
  if [ ! -x "$want" ]; then
    printf 'FAIL   %-20s build has no executable %s\n' "$verb" "$want" >&2
    failed=$((failed + 1)); continue
  fi

  have="$(readlink "$BIN/$verb" 2>/dev/null || true)"
  why=''
  state="$(classify "$verb" 3>"$WHYFILE")"
  why="$(cat "$WHYFILE")"

  case "$state" in
    already) already=$((already + 1)); continue ;;
    refuse)
      printf 'REFUSE %-20s %s\n' "$verb" "$why" >&2
      failed=$((failed + 1)); continue ;;
    adopt)
      if [ "$ADOPT" -ne 1 ]; then
        # LOUD, and counted as a failure, because this is precisely the
        # population the script was silently failing on. "14 failed" with no
        # route forward is what this replaces.
        printf 'NEEDS-ADOPT %-15s %s\n' "$verb" "$why" >&2
        printf '       %-20s re-run with --adopt-existing to re-point it\n' '' >&2
        needs_adopt=$((needs_adopt + 1)); failed=$((failed + 1)); continue
      fi ;;
  esac

  if [ "$APPLY" -ne 1 ]; then
    printf 'WOULD  %-20s [%s] %s -> %s%s\n' "$verb" "$state" "${have:-<none>}" "$want" \
      "$([ -n "$why" ] && printf ' (%s)' "$why")" >&2
    moved=$((moved + 1)); continue
  fi

  # --force ONLY for a name the rule above cleared. `free` is linked with no
  # force at all, so the common path never carries the flag.
  if [ "$state" = adopt ]; then
    set -- --quiet --force verb "$project" "$verb"
  else
    set -- --quiet verb "$project" "$verb"
  fi

  if "$INSTALLE" "$@" >/dev/null 2>&1; then
    # Re-read the link rather than trusting exit 0 -- SPRINT-RECORD-2026-08-05
    # §7.4, a build where `-f && -x` passed and nothing could run.
    now="$(readlink "$BIN/$verb" 2>/dev/null || true)"
    case "$now" in
      "$CUR/"*|"$BUILD_ROOT/current/"*)
        if [ "$state" = adopt ]; then
          # The REASON travels with the line. "ADOPT arpente" alone is an
          # overwrite with no stated justification; the operator reading this
          # log a week later needs to see which of the three rules cleared it.
          printf 'ADOPT  %-20s was %s (%s)\n' "$verb" "${have:-<none>}" "$why" >&2
          adopted=$((adopted + 1))
        else
          printf 'MOVED  %-20s %s\n' "$verb" "${have:-<none>}" >&2
        fi
        moved=$((moved + 1)) ;;
      *)
        printf 'FAIL   %-20s installe exited 0 but %s -> %s\n' "$verb" "$BIN/$verb" "${now:-<none>}" >&2
        failed=$((failed + 1)) ;;
    esac
  else
    printf 'FAIL   %-20s installe %s refused\n' "$verb" "$*" >&2
    failed=$((failed + 1))
  fi
done < "$MANIFEST"

printf '== %d declared verb(s): %d %s (%d by adoption), %d already on the build, %d failed\n' \
  "$total" "$moved" "$([ "$APPLY" -eq 1 ] && echo moved || echo 'to move')" \
  "$adopted" "$already" "$failed" >&2
if [ "$needs_adopt" -gt 0 ]; then
  printf '== %d verb(s) need --adopt-existing: a shim owned by nothing points into a dev\n' "$needs_adopt" >&2
  printf '== clone, a superseded build, or nowhere. Re-run with --apply --adopt-existing.\n' >&2
fi

[ "$failed" -eq 0 ] || exit 1
exit 0
