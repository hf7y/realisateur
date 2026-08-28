#!/usr/bin/env bash
# carry.sh -- perform the carries bin/tests/carry-drift.test.sh detects.
#
# The detector has had no actuator since realisateur#511 deleted
# bin/carry-drift.sh and left the test behind, so every drift has been fixed by
# hand. On 2026-08-25 a hand fix ran `git push origin main:bashified` and
# deleted 13 files bashified carries that main does not have -- lib/verb.sh,
# CONTRACT.md, GAPS.md, every man/*.1, the carried lints, runtime.yml.
#
# So: this moves ONLY the paths bin/lib/carries.tsv names, never the branch.
# It reads the same table the detector reads, from the same ref, so the two
# cannot disagree about what a carry is.
set -uo pipefail

CLI_NAME='carry.sh'
CLI_SUMMARY='copy each carries.tsv source from main onto bashified, and nothing else'
CLI_USAGE='  carry.sh            print which carried files have drifted
  carry.sh --check    the same; writes nothing (default)
  carry.sh --apply    build one commit on bashified carrying every drifted file'

# Self-locating through the symlink, and overridable so
# bin/tests/carry.test.sh can point it at a throwaway repo -- the shape
# ETIQUETTE_GRAMMAR uses in etiquette.sh, for the same reason: a tool that can
# only ever act on its own repo cannot be tested against a fixture.
HERE="${CARRY_REPO:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
REF_MAIN="${CARRY_REF_MAIN:-origin/main}"
REF_BASH="${CARRY_REF_BASH:-origin/bashified}"
BRANCH="${CARRY_BRANCH:-bashified}"
REMOTE="${CARRY_REMOTE:-origin}"

die()   { printf '%s: FAIL: %s\n' "$CLI_NAME" "$*" >&2; exit 1; }
blind() { printf '%s: BLIND: %s\n' "$CLI_NAME" "$*" >&2; exit 6; }
usage() { printf '%s: %s\n' "$CLI_NAME" "$*" >&2; printf 'usage:\n%s\n' "$CLI_USAGE" >&2; exit 2; }

MODE=--check
for a in "$@"; do
  case "$a" in
    --check|--apply) MODE="$a" ;;
    -h|--help) printf '%s -- %s\nusage:\n%s\n' "$CLI_NAME" "$CLI_SUMMARY" "$CLI_USAGE"; exit 0 ;;
    *) usage "unknown argument $a" ;;
  esac
done

cd "$HERE" || die "cannot enter $HERE"
git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"

# THE REPO AND THE REFS MUST BE OVERRIDDEN TOGETHER. This script takes its refs,
# remote and branch from the environment but its REPO from its own location, and
# on 2026-08-25 those disagreed in silence: bin/tests/carry.test.sh handed it a
# fixture's CARRY_REMOTE/CARRY_BRANCH/CARRY_REF_* while CARRY_REPO was still
# unset, so it resolved the REAL repo, pushed a REAL carry to origin/bashified,
# and reported success. Correct content, from a test run nobody asked for a
# push from. Overriding where to read without overriding where to write is now
# a usage error, not a surprise.
if [ -z "${CARRY_REPO:-}" ]; then
  for v in CARRY_REMOTE CARRY_BRANCH CARRY_REF_MAIN CARRY_REF_BASH; do
    [ -z "${!v:-}" ] || usage "$v is set but CARRY_REPO is not.
  Those name where to WRITE and where to READ; setting one without the other
  points this at a repo you did not mean. Set CARRY_REPO too."
  done
fi

# REFRESH BOTH REFS FIRST. A stale origin/bashified reports drift that was
# already carried, and a stale origin/main carries yesterday's content.
git fetch -q "$REMOTE" main "$BRANCH" 2>/dev/null || true
for r in "$REF_MAIN" "$REF_BASH"; do
  git rev-parse --verify -q "$r^{commit}" >/dev/null 2>&1 \
    || blind "$r is not readable here -- refusing to carry against a ref I cannot see"
done

# ONE SOURCE, read from REF_MAIN exactly as carry-drift.test.sh:114 reads it.
TABLE="$(git show "$REF_MAIN:bin/lib/carries.tsv" 2>/dev/null | grep -v '^#' | grep -v '^[[:space:]]*$')"
[ -n "$TABLE" ] || blind "carries.tsv is empty or unreadable on $REF_MAIN"

PROJECT_NAME="${CARRY_PROJECT_NAME:-$(basename "$HERE")}"  # a row naming another project is not this repo's to act on (realisateur#696)
RETIRED="$(git show "$REF_MAIN:bin/lib/retired-verbs.tsv" 2>/dev/null | grep -v '^#' | grep -v '^[[:space:]]*$')"

drifted=(); missing=(); n=0
while IFS=$'\t' read -r carried src; do
  [ -n "$carried" ] || continue
  n=$((n + 1))
  if ! git cat-file -e "$REF_MAIN:$src" 2>/dev/null; then
    missing+=("$src (source of $carried)"); continue
  fi
  # Two sentinels that can never be a sha and can never equal each other, so a
  # path missing on either side reads as drift rather than as a match.
  a="$(git rev-parse "$REF_BASH:$carried" 2>/dev/null || echo ABSENT-ON-CARRIED)"
  b="$(git rev-parse "$REF_MAIN:$src" 2>/dev/null || echo ABSENT-ON-SOURCE)"
  [ "$a" = "$b" ] || drifted+=("$carried"$'\t'"$src")
done <<< "$TABLE"

[ "$n" -gt 0 ] || blind "carries.tsv named zero carried files"

# A source that does not exist is a FINDING, not something to carry over: the
# row outlived its file, and guessing which is wrong is not this tool's call.
if [ "${#missing[@]}" -gt 0 ]; then
  printf '%s: %d row(s) name a source that is gone from %s:\n' "$CLI_NAME" "${#missing[@]}" "$REF_MAIN" >&2
  printf '  %s\n' "${missing[@]}" >&2
  printf '%s: fix carries.tsv, or restore the file. Carrying nothing.\n' "$CLI_NAME" >&2
  exit 1
fi

retiring=()
while IFS=$'\t' read -r rproj rverb rwhy; do
  [ -n "$rproj" ] && [ -n "$rverb" ] || continue
  [ "$rproj" = "$PROJECT_NAME" ] || continue
  for p in "bin/$rverb" "man/$rverb.1"; do
    git cat-file -e "$REF_BASH:$p" 2>/dev/null || continue
    retiring+=("$p"$'\t'"$rverb retired: ${rwhy:-(no reason recorded)}")
  done
done <<< "$RETIRED"

if [ "${#drifted[@]}" -eq 0 ] && [ "${#retiring[@]}" -eq 0 ]; then
  printf '%s: %d carried file(s), none drifted; no declared retirement pending\n' "$CLI_NAME" "$n"
  exit 0
fi

if [ "${#drifted[@]}" -gt 0 ]; then
  printf '%s: %d of %d carried file(s) have drifted:\n' "$CLI_NAME" "${#drifted[@]}" "$n"
  while IFS=$'\t' read -r carried src; do
    [ -n "$carried" ] || continue
    printf '  %s  <-  %s\n' "$carried" "$src"
  done < <(printf '%s\n' "${drifted[@]}")
fi
if [ "${#retiring[@]}" -gt 0 ]; then
  printf '%s: %d file(s) staged for retirement (bin/lib/retired-verbs.tsv, project %s):\n' \
         "$CLI_NAME" "${#retiring[@]}" "$PROJECT_NAME"
  while IFS=$'\t' read -r p why; do
    [ -n "$p" ] || continue
    printf '  RETIRE  %s  (%s)\n' "$p" "$why"
  done < <(printf '%s\n' "${retiring[@]}")
fi

[ "$MODE" = --apply ] || { printf '%s: NOT carried (need --apply)\n' "$CLI_NAME"; exit 0; }

# --- build the commit with PLUMBING, not a checkout --------------------------
# No second worktree and no branch switch in the caller's tree: read
# bashified's tree into a temp index, replace only the carried paths, write it
# back. A checkout here would also fight whatever the caller has in flight.
OLD="$(git rev-parse "$REF_BASH")"
IDX="$(mktemp)"; trap 'rm -f "$IDX"' EXIT
GIT_INDEX_FILE="$IDX" git read-tree "$REF_BASH" || die "could not read $REF_BASH into a temp index"

while IFS=$'\t' read -r carried src; do
  [ -n "$carried" ] || continue
  # The MODE comes from main's entry, so a carried hook stays executable.
  mode="$(git ls-tree "$REF_MAIN" -- "$src" | awk '{print $1}')"
  [ -n "$mode" ] || die "no tree entry for $src on $REF_MAIN"
  blob="$(git rev-parse "$REF_MAIN:$src")"
  GIT_INDEX_FILE="$IDX" git update-index --add --cacheinfo "$mode,$blob,$carried" \
    || die "could not stage $carried"
done < <(printf '%s\n' "${drifted[@]}")

while IFS=$'\t' read -r p why; do  # --force-remove: purely against the temp index, no working-tree file to stat
  [ -n "$p" ] || continue
  GIT_INDEX_FILE="$IDX" git update-index --force-remove -- "$p" \
    || die "could not stage removal of $p"
done < <(printf '%s\n' "${retiring[@]}")

TREE="$(GIT_INDEX_FILE="$IDX" git write-tree)" || die "could not write the carried tree"
if [ "$TREE" = "$(git rev-parse "$REF_BASH^{tree}")" ]; then
  printf '%s: the carried tree is identical -- nothing to push\n' "$CLI_NAME"
  exit 0
fi

MSG=''
if [ "${#drifted[@]}" -gt 0 ]; then
  MSG="carry: $(printf '%s\n' "${drifted[@]}" | cut -f1 | tr '\n' ' ' | sed 's/ $//') from ${REF_MAIN#origin/}"
fi
if [ "${#retiring[@]}" -gt 0 ]; then
  ret_paths="$(printf '%s\n' "${retiring[@]}" | cut -f1 | tr '\n' ' ' | sed 's/ $//')"
  MSG="${MSG:+$MSG; }retire: $ret_paths"
fi
COMMIT="$(git commit-tree "$TREE" -p "$OLD" -m "$MSG")" || die "could not commit the carried tree"

# --force-with-lease against the sha we read, so a bashified that moved while
# we worked is a refusal rather than a silent overwrite.
git push -q "$REMOTE" "$COMMIT:refs/heads/$BRANCH" \
  --force-with-lease="refs/heads/$BRANCH:$OLD" \
  || die "push refused -- $BRANCH moved since $OLD was read. Re-run."
printf '%s: carried %d file(s), retired %d file(s), onto %s (%s)\n' \
       "$CLI_NAME" "${#drifted[@]}" "${#retiring[@]}" "$BRANCH" "${COMMIT:0:8}"
