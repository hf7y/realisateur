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
# usage:
#   relink-verbs-to-build.sh            dry run; prints what would change
#   relink-verbs-to-build.sh --apply    do it
#
# exit: 0 every declared verb resolves into the build; 1 refused or any failure
set -uo pipefail

APPLY=0
case "${1:-}" in
  --apply) APPLY=1 ;;
  ''|-n|--dry-run) APPLY=0 ;;
  *) printf 'usage: %s [--apply]\n' "${0##*/}" >&2; exit 2 ;;
esac

BUILD_ROOT="${BUILD_ROOT:-$HOME/.local/share/verb-builds}"
CUR="$BUILD_ROOT/current"
BIN="${BIN:-$HOME/.local/bin}"
MANIFEST="$CUR/manifest.tsv"
INSTALLE="$CUR/senechal/bin/installe"

die() { printf 'relink-verbs-to-build.sh: %s\n' "$*" >&2; exit 1; }

[ -d "$CUR" ]      || die "no installed build at $CUR -- run install-verb-build.sh --latest --apply"
[ -f "$MANIFEST" ] || die "build at $CUR has no manifest.tsv; refusing to guess the verb set"
[ -x "$INSTALLE" ] || die "the build carries no executable installe at $INSTALLE"
grep -q 'verb-builds' "$INSTALLE" ||
  die "$INSTALLE never mentions verb-builds: this build predates senechal#22, re-cut it"

printf '== build %s\n' "$(readlink "$CUR")" >&2
[ "$APPLY" -eq 1 ] || printf '== DRY RUN (pass --apply to change anything)\n' >&2

moved=0; already=0; failed=0; total=0
while IFS=$'\t' read -r project verb _rest; do
  case "${project:-}" in ''|'#'*) continue ;; esac
  [ -n "${verb:-}" ] || continue
  total=$((total + 1))

  want="$CUR/$project/bin/$verb"
  if [ ! -x "$want" ]; then
    printf 'FAIL   %-20s build has no executable %s\n' "$verb" "$want" >&2
    failed=$((failed + 1)); continue
  fi

  have="$(readlink "$BIN/$verb" 2>/dev/null || true)"
  case "$have" in
    "$CUR/"*|"$BUILD_ROOT/current/"*) already=$((already + 1)); continue ;;
  esac

  if [ "$APPLY" -eq 1 ]; then
    if "$INSTALLE" --quiet verb "$project" "$verb" >/dev/null 2>&1; then
      now="$(readlink "$BIN/$verb" 2>/dev/null || true)"
      case "$now" in
        "$CUR/"*|"$BUILD_ROOT/current/"*)
          printf 'MOVED  %-20s %s\n' "$verb" "${have:-<none>}" >&2
          moved=$((moved + 1)) ;;
        *)
          printf 'FAIL   %-20s installe exited 0 but %s -> %s\n' "$verb" "$BIN/$verb" "${now:-<none>}" >&2
          failed=$((failed + 1)) ;;
      esac
    else
      printf 'FAIL   %-20s installe verb %s %s refused\n' "$verb" "$project" "$verb" >&2
      failed=$((failed + 1))
    fi
  else
    printf 'WOULD  %-20s %s -> %s\n' "$verb" "${have:-<none>}" "$want" >&2
    moved=$((moved + 1))
  fi
done < "$MANIFEST"

printf '== %d declared verb(s): %d %s, %d already on the build, %d failed\n' \
  "$total" "$moved" "$([ "$APPLY" -eq 1 ] && echo moved || echo 'to move')" "$already" "$failed" >&2

[ "$failed" -eq 0 ] || exit 1
exit 0
