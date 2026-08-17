#!/usr/bin/env bash
# repo-settings-provision.sh -- make delete_branch_on_merge and
# allow_auto_merge live on every scheduler-registered project's GitHub repo,
# not just the one they happened to be turned on by hand for.
#
# RUNNER: bin/tests/repo-settings-provision.test.sh
# GUARD-TEST: bin/tests/repo-settings-provision.test.sh
# GATE: strict
#
# TRAPS (the rest of this header is in the vault):
# WHY THIS EXISTS. claim-drift.sh --convention states, as settled ecosystem
# fact: "allow_auto_merge=true, delete_branch_on_merge=true ... live on
# hf7y/realisateur since 2026-08-08." That was true of realisateur alone --
# applied once, by hand, against one repo. It was never turned into something
# that runs against the REGISTRY, so every sibling project silently kept
# whatever GitHub defaulted it to. Found 2026-08-10 (senechal, via /cloture):
# hf7y/senechal had both settings OFF, `gh pr merge --auto` produced squash
# merges that satisfied the intent, and 22 already-merged PR branches sat on
# origin forever because nothing ever deleted them (the reconciliation cost
# a whole /triage-run's Phase 1 to clean up by hand). "Live on realisateur"
# read as an ecosystem fact; it was one repo's setting.
#

set -uo pipefail

CLI_NAME='repo-settings-provision.sh'
CLI_SUMMARY='make delete_branch_on_merge + allow_auto_merge live on every registered repo'
CLI_USAGE='  repo-settings-provision.sh              report drift, change nothing
  repo-settings-provision.sh <name>...    report drift for named project(s)
  repo-settings-provision.sh --apply [<name>...]   fix the drift found
  repo-settings-provision.sh --strict [<name>...]  exit 1 if drift found'
CLI_FLAGS='--apply --strict'
CLI_EXITS='  0  scanned at least one repo and saw all of them; no --strict given,
     or --strict given and nothing drifted
  1  --strict was given and at least one repo had drift (before or after
     --apply, if both are given -- --apply then --strict verifies the fix)
  2  BLIND -- at least one repo could not be read, or the registry named no
     project with a REPO_URL at all. NEVER 0: could-not-look is not clean,
     and it is not gated behind --strict, because a run that saw nothing has
     established nothing whether or not the caller asked it to gate.'
CLI_POSITIONAL=any
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

SCHED_ROOT="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"
GH_BIN="${GH_BIN:-gh}"

APPLY=0
STRICT=0
want=()
for a in "$@"; do
  case "$a" in
    --apply)  APPLY=1 ;;
    --strict) STRICT=1 ;;
    *)        want+=("$a") ;;
  esac
done

# --- discover registered projects with a REPO_URL --------------------------
names=()
slugs=()
for conf in "$SCHED_ROOT"/schedule/*.conf; do
  [ -f "$conf" ] || continue
  name="$(basename "$conf" .conf)"
  case "$name" in _*) continue ;; esac
  if [ "${#want[@]}" -gt 0 ]; then
    skip=1; for w in "${want[@]}"; do [ "$w" = "$name" ] && skip=0; done
    [ "$skip" -eq 1 ] && continue
  fi
  url="$(sed -n 's/^REPO_URL=["'\'']\?\([^"'\'']*\)["'\'']\?[[:space:]]*$/\1/p' "$conf" | head -1)"
  [ -n "$url" ] || continue
  # Two shapes seen in the registry: https://github.com/OWNER/REPO.git and
  # git@github.com:OWNER/REPO.git. Reduce both to OWNER/REPO, gh's own slug
  # form, rather than teaching every downstream call two URL shapes.
  slug="$(printf '%s\n' "$url" \
    | sed -e 's#^git@github\.com:##' -e 's#^https://github\.com/##' -e 's#\.git$##')"
  [ -n "$slug" ] || continue
  names+=("$name"); slugs+=("$slug")
done
cli_require_matched want names

echo "repo-settings-provision -- $(date '+%Y-%m-%d %H:%M')"
if [ "$APPLY" = 1 ]; then
  echo "(--apply: fixing drift found below via 'gh repo edit')"
else
  echo "(read-only: reporting drift, changing nothing -- pass --apply to fix)"
fi
echo

drifted=0
blind=0
i=0
while [ "$i" -lt "${#names[@]}" ]; do
  name="${names[$i]}"; slug="${slugs[$i]}"; i=$((i+1))

  json="$("$GH_BIN" api "repos/$slug" --jq '{d: .delete_branch_on_merge, a: .allow_auto_merge}' 2>/dev/null)"
  if [ -z "$json" ]; then
    echo "  BLIND $name ($slug): could not read repo settings (no access, or repo does not exist)"
    blind=$((blind+1))
    continue
  fi
  d="$(printf '%s' "$json" | sed -n 's/.*"d":\([a-z]*\).*/\1/p')"
  a="$(printf '%s' "$json" | sed -n 's/.*"a":\([a-z]*\).*/\1/p')"

  bad=0
  [ "$d" = "true" ] || bad=1
  [ "$a" = "true" ] || bad=1

  if [ "$bad" -eq 0 ]; then
    echo "  ok    $name ($slug): delete_branch_on_merge=true allow_auto_merge=true"
    continue
  fi

  echo "  DRIFT $name ($slug): delete_branch_on_merge=$d allow_auto_merge=$a"
  drifted=$((drifted+1))

  if [ "$APPLY" = 1 ]; then
    args=()
    [ "$d" = "true" ] || args+=(--delete-branch-on-merge)
    [ "$a" = "true" ] || args+=(--enable-auto-merge)
    if "$GH_BIN" repo edit "$slug" "${args[@]}" >/dev/null 2>&1; then
      echo "        applied: gh repo edit $slug ${args[*]}"
    else
      echo "        FAILED to apply -- check gh auth/permissions for $slug"
    fi
  fi
done

echo
echo "== ${drifted} drifted, ${blind} BLIND, out of ${#names[@]} project(s) with a REPO_URL =="

# BLIND IS NEVER 0, AND IS NEVER GATED BEHIND --strict.
#
# The first draft of this script exited 0 on both shapes of not-looking, and
# bin/tests/guard-estate.test.sh case E1 caught it: "admitted BLIND and exited
# 0 -- could-not-look graded as clean". It reached that verdict on the emptier
# of the two shapes, which is the one worth naming: pointed at a SCHED_ROOT
# with no schedule/*.conf in it at all, the loop below simply never ran, the
# summary read "0 drifted, 0 BLIND, out of 0 project(s)", and the exit code
# said the estate was compliant. It is the "a run that matched no suites is a
# broken glob, not a clean tree" defect from .github/workflows/tests.yml, in a
# second script.
#
# Ordering: a drift found under --strict outranks partial blindness, because
# it is the more actionable of the two and the caller asked to gate on it; the
# BLIND lines are still in the output above either way. What must never happen
# is either one reaching exit 0.
if [ "${#names[@]}" -eq 0 ]; then
  echo "BLIND: no registered project with a REPO_URL under $SCHED_ROOT/schedule/ -- nothing was checked."
  echo "repo-settings-provision: nothing was measured. This is NOT a clean result."
  exit 2
fi
[ "$STRICT" = 1 ] && [ "$drifted" -gt 0 ] && exit 1
[ "$blind" -gt 0 ] && exit 2
exit 0
