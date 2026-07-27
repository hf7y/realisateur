#!/usr/bin/env bash
# restamp-discipline.sh -- propagate the realisateur baseline (build-discipline
# checklist + ecosystem protocols) into every registered project's CLAUDE.md,
# mechanically, from ONE source.
#
# THE PROBLEM IT SOLVES (Zach's question, 2026-07-26): "how can all projects
# know about things like the senechal cross-write?" They could not. Two gaps:
#
#   1. SCOPE. Only the build-discipline checklist was ever propagated. The
#      ecosystem protocols -- cross-write machine config via senechal's front
#      door, commit FOCUS/QUESTIONS via focus-commit, busy-probe before
#      writing into another repo -- lived ONLY in realisateur's own two
#      command files. No other project had any channel that would tell them.
#   2. REMEDIATION. `hygiene-lint.sh` did detect checklist drift, but only as
#      an advisory NOTE, and nothing ever restamped. gardien/crt/senechal sat
#      4 rows stale for a day with the lint correctly complaining into a log.
#      Detection is not propagation.
#
# WHAT IT RETIRES: the hand-restamp, and `hygiene-lint`'s [checklist-drift]
# NOTE as an ACTIONABLE item (the NOTE stays useful as an independent check
# that this script actually ran -- two mechanisms, one source, which is the
# point). Once this runs each pass, drift is not detected-and-fixed, it is
# structurally impossible.
#
# WHY A COPY AND NOT A SYMLINK/IMPORT: the nightly jobs run in a dedicated
# clone, and shared hosts (dexter/mandark) may have no realisateur checkout
# at all. A symlink to an absolute path outside the repo dangles there, and a
# dangling symlink does not error -- it makes the discipline silently absent,
# BUILD-DISCIPLINE.md's own first failure pattern. Plain text travels
# anywhere and shows up in a diff. Full reasoning in BUILD-DISCIPLINE.md
# under "The baseline".
#
# Usage:
#   restamp-discipline.sh                dry run -- report per-project drift,
#                                         write nothing (DEFAULT, deliberately)
#   restamp-discipline.sh --apply        write + commit + push each changed repo
#   restamp-discipline.sh [--apply] <name>...   restrict to named projects
#
# Exit 0 = every project in scope is in sync (dry run) or was brought into
# sync (--apply). Exit 1 = drift exists (dry run) or a write/commit/push
# failed (--apply). No exit-0 no-op.
set -uo pipefail

SCHED_ROOT="/home/zach/Documents/Project Archive/scheduler"
SELF_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BD_MD="$SELF_DIR/BUILD-DISCIPLINE.md"
BEGIN_MARK='<!-- >>> realisateur-baseline'
END_MARK='<!-- <<< realisateur-baseline -->'

die() { printf 'restamp-discipline: FAIL: %s\n' "$*" >&2; exit 1; }

apply=0
want=()
for a in "$@"; do
  case "$a" in
    --apply) apply=1 ;;
    -*) die "unknown option: $a" ;;
    *) want+=("$a") ;;
  esac
done

[ -f "$BD_MD" ] || die "one source not found: $BD_MD"
[ -d "$SCHED_ROOT/schedule" ] || die "scheduler schedule/ not found at $SCHED_ROOT"

# --- extract the ONE SOURCE block ------------------------------------------
# Everything between the markers, inclusive. Extracting inclusively matters:
# the markers are what makes the region re-findable on the NEXT run, so a
# stamped copy that lost them would be re-appended rather than replaced.
tmp="$(mktemp -d)" || die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT
block="$tmp/block.md"

awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
  index($0, b) == 1 { on = 1 }
  on { print }
  index($0, e) == 1 && on { exit }
' "$BD_MD" > "$block"

grep -qF "$BEGIN_MARK" "$block" || die "no baseline begin-marker in $BD_MD"
grep -qF "$END_MARK"   "$block" || die "no baseline end-marker in $BD_MD -- refusing to stamp a truncated block"
rows="$(grep -c '^- \[ \]' "$block")"
[ "$rows" -gt 0 ] || die "extracted block has zero checklist rows -- refusing to stamp an empty baseline"

echo "restamp-discipline -- $(date '+%Y-%m-%d %H:%M')"
echo "source: BUILD-DISCIPLINE.md ($(wc -l < "$block") lines, $rows checklist rows)"
[ "$apply" -eq 1 ] && echo "mode: APPLY (writes, commits, pushes)" || echo "mode: DRY RUN (writes nothing -- pass --apply to act)"

# --- discover registered projects ------------------------------------------
projects=()
for conf in "$SCHED_ROOT"/schedule/*.conf; do
  name="$(basename "$conf" .conf)"
  case "$name" in _*) continue ;; esac
  grep -q '^PROJECT_REPO_PATH=' "$conf" || continue
  if [ "${#want[@]}" -gt 0 ]; then
    skip=1; for w in "${want[@]}"; do [ "$w" = "$name" ] && skip=0; done
    [ "$skip" -eq 1 ] && continue
  fi
  projects+=("$name")
done
[ "${#projects[@]}" -eq 0 ] && die "no registered projects matched"

drifted=0; synced=0; failed=0; skipped=0

for name in $(printf '%s\n' "${projects[@]}" | sort); do
  conf="$SCHED_ROOT/schedule/$name.conf"
  repo="$(grep -oP '(?<=PROJECT_REPO_PATH=")[^"]*' "$conf")"
  claude="$repo/CLAUDE.md"

  if [ ! -d "$repo/.git" ]; then
    printf '  %-22s SKIP -- no git repo at %s\n' "$name" "$repo"
    skipped=$((skipped+1)); continue
  fi
  if [ ! -f "$claude" ]; then
    printf '  %-22s SKIP -- no CLAUDE.md (scaffold gap, not drift)\n' "$name"
    skipped=$((skipped+1)); continue
  fi

  # Build what the file SHOULD look like.
  out="$tmp/$name.CLAUDE.md"
  if grep -qF "$BEGIN_MARK" "$claude"; then
    mode="replace"
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v bf="$block" '
      index($0, b) == 1 { while ((getline l < bf) > 0) print l; close(bf); skip = 1; next }
      skip && index($0, e) == 1 { skip = 0; next }
      skip { next }
      { print }
    ' "$claude" > "$out"
  elif grep -q '^## Build discipline (realisateur baseline' "$claude"; then
    # ADOPTION path: an older hand-stamped copy with no markers. Replace from
    # its heading up to (not including) the next top-level `## ` heading, so
    # the project's own following sections survive untouched.
    mode="adopt"
    awk -v bf="$block" '
      /^## Build discipline \(realisateur baseline/ {
        while ((getline l < bf) > 0) print l; close(bf); skip = 1; next
      }
      skip && /^## / { skip = 0 }
      skip { next }
      { print }
    ' "$claude" > "$out"
  else
    mode="append"
    { cat "$claude"; printf '\n'; cat "$block"; } > "$out"
  fi

  if cmp -s "$claude" "$out"; then
    printf '  %-22s in sync\n' "$name"
    synced=$((synced+1)); continue
  fi

  delta="$(diff <(cat "$claude") <(cat "$out") | grep -c '^[<>]' || true)"
  drifted=$((drifted+1))

  if [ "$apply" -eq 0 ]; then
    printf '  %-22s DRIFT (%s, %s changed line(s)) -- run with --apply\n' "$name" "$mode" "$delta"
    continue
  fi

  # --- protocol: never write into a repo whose own automation is mid-run ---
  busy="$("$SELF_DIR/bin/check-project-busy.sh" "$name" 2>&1)"
  case "$busy" in
    BUSY*) printf '  %-22s DEFERRED -- %s\n' "$name" "$busy"
           skipped=$((skipped+1)); continue ;;
  esac

  cp "$out" "$claude" || { printf '  %-22s FAIL -- could not write CLAUDE.md\n' "$name"; failed=$((failed+1)); continue; }

  msg="$tmp/$name.msg"
  cat > "$msg" <<EOF
CLAUDE.md: restamp the realisateur baseline ($mode)

Mechanical propagation from realisateur/BUILD-DISCIPLINE.md, the one
source, via realisateur/bin/restamp-discipline.sh. Do not hand-edit the
delimited region -- the next pass overwrites it.

This stamp carries the ecosystem protocols alongside the build-discipline
checklist: machine-wide config is cross-written to senechal via
\`notify-senechal\`, FOCUS/QUESTIONS commits go through \`focus-commit\`,
and \`check-project-busy\` runs before writing into another project's repo.
Those rules previously existed only inside realisateur's own command
files, so no other project had any way to learn them.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF

  if ! git -C "$repo" add CLAUDE.md 2>&1; then
    printf '  %-22s FAIL -- git add\n' "$name"; failed=$((failed+1)); continue
  fi
  if ! git -C "$repo" commit -q -F "$msg" 2>&1; then
    printf '  %-22s FAIL -- git commit\n' "$name"; failed=$((failed+1)); continue
  fi
  sha="$(git -C "$repo" rev-parse --short HEAD)"

  # Push is part of the job, not a nicety: the nightly runs work in a
  # dedicated clone of the REMOTE, so a baseline that is only committed
  # locally never reaches the consumer that has to follow it.
  if ! git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    printf '  %-22s STAMPED %s -- but branch tracks nothing, NOT pushed (nightly clone will not see it)\n' "$name" "$sha"
    failed=$((failed+1)); continue
  fi
  if git -C "$repo" push -q 2>&1; then
    printf '  %-22s STAMPED %s (%s, pushed)\n' "$name" "$sha" "$mode"
  else
    printf '  %-22s STAMPED %s -- PUSH FAILED, committed locally only; resolve by hand\n' "$name" "$sha"
    failed=$((failed+1))
  fi
done

echo
echo "== $synced in sync / $drifted drifted / $skipped skipped / $failed failed =="

if [ "$failed" -gt 0 ]; then
  echo "Some repos did not reach their remote. The baseline is only real where"
  echo "the consumer reads it -- resolve these before treating the pass as done."
  exit 1
fi
if [ "$apply" -eq 0 ] && [ "$drifted" -gt 0 ]; then
  echo "Dry run: $drifted project(s) would be restamped. Re-run with --apply."
  exit 1
fi
exit 0
