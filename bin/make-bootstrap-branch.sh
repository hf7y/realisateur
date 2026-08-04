#!/usr/bin/env bash
# make-bootstrap-branch.sh -- rebuild THE PLAY's bootstrap branch, from any
# repo state, without an AI in the loop.
#
# WHY THIS EXISTS
# ---------------
# THE PLAY rests on one premise: a project's FOCUS.md is enough to direct the
# agent that runs it. Testing that premise means stripping two FOCUS.md files
# to briefs and letting the agents run from them. Run 2 did exactly that by
# hand, in a session, on 2026-07-29.
#
# A play you can only set up by hand is a play you get to run once. The prose
# below IS the setup -- held as data, in a script, so any future repo state can
# be returned to the starting line by a command rather than by a session that
# remembers what the last one did. That is the same reasoning as
# stamp-agent.sh's (a rule that lives only as prose decays; a rule that lives
# as a command does not), applied one level up: stamp-agent.sh mechanises
# "every agent gets a stamp", this mechanises "and here is what the stamps SAY".
#
# NO AI. Deterministic. Idempotent. Re-running it on an unchanged tree is a
# no-op that says so, so it is safe to run to FIND OUT whether you are at the
# starting line.
#
# USAGE
#   make-bootstrap-branch.sh                  # dry run -- print the plan
#   make-bootstrap-branch.sh --apply          # create/update the branch
#   make-bootstrap-branch.sh --verify         # exit 0 iff live == generated
#   make-bootstrap-branch.sh --date 2026-07-29 --apply
#   make-bootstrap-branch.sh --branch bootstrap/stamp-2026-07-29 --apply
#
# WHAT IT DOES, per participating project:
#   1. checks the tree is clean (a dirty tree is a failed run, not a handoff)
#   2. checks out $BRANCH, creating it from $BASE if absent
#   3. writes the stamped FOCUS.md via realisateur's stamp-agent.sh
#   4. commits ONLY that file, with -F (never -m: backticks in the prose
#      would execute inside double quotes -- this repo has been bitten)
#   5. returns the repo to the branch it was on
#
# It does NOT push, does NOT touch the rotation, does NOT touch crontab, and
# does NOT release schedule/FREEZE. Those are the live cutover and are
# deliberately a separate, human-sequenced step -- see THE-PLAY.md.
set -uo pipefail

REALISATEUR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHED_ROOT="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"
STAMP="$REALISATEUR_ROOT/bin/stamp-agent.sh"

BRANCH="${BOOTSTRAP_BRANCH:-bootstrap/stamp-2026-07-29}"
BASE="${BOOTSTRAP_BASE:-main}"
DATE="2026-07-29"
MODE="dry"

die() { echo "make-bootstrap-branch: $*" >&2; exit 2; }
say() { printf '%s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)  MODE="apply";  shift ;;
    --verify) MODE="verify"; shift ;;
    --branch) BRANCH="${2:-}"; shift 2 ;;
    --base)   BASE="${2:-}";   shift 2 ;;
    --date)   DATE="${2:-}";   shift 2 ;;
    -h|--help) sed -n '2,40p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -x "$STAMP" ] || die "stamp-agent.sh not executable at $STAMP -- a missing guard is a finding, not an inconvenience."
[[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "--date must be YYYY-MM-DD, got: $DATE"

# ===========================================================================
# THE BOOTSTRAP PROSE. This block is the artifact; everything else is
# plumbing. Edit here, re-run --apply, and the branch is rebuilt to match.
#
# Each project is a bash function emitting stamp-agent.sh arguments, one per
# line, NUL-free -- read back with mapfile so a --role containing spaces
# survives without quoting games.
# ===========================================================================

prose_scheduler() {
  cat <<'ARGS'
--role
**scheduler is metabolism.** It turns quota into cycles and cycles into commits. It is *pure mechanism* by standing doctrine (2026-07-22, realisateur/UNIVERSE.md): **it enforces weights, it never sets them.** The judgment of WHAT deserves turns is not yours — it belongs to realisateur, and reaches you through your own front door like any other request.
--bar
**Install the schedule system on this host, then register `realisateur` into the rotation. That is the entire turn.** There is no crontab to inherit: it was emptied deliberately before this run, so bringing dispatch back up from `schedule/_runner.conf` is step one and not an assumption. Done means the tick line is installed, `realisateur` is in this host's rotation file, and a dispatch has actually fired with a run-log line to show it.
--item
**Install the tick.** Derive it from `schedule/_runner.conf` and install it with `bin/sync-crontab.sh --apply`. Do not hand-write a crontab line — this host's crontab was hand-installed on 2026-07-24 and has drifted from every conf since. Witness: `crontab -l` shows a line whose text you did not type.
--item
**Register realisateur** into this host's rotation file (`schedule/_paced.<host>.conf`). One line. Witness: a `DISPATCH ... realisateur` in `~/.local/share/scheduler-paced-runner/run.log`.
--item
**Write your verdict before you run out of room.** `bin/verdict.sh` — `CONTINUE` if the bar is unmet and reachable, `DONE` if met, `IMPOSSIBLE` if you have found a reason it cannot be met from here. An absent verdict means truncated, not failed, and you will simply be dispatched again. Claiming `IMPOSSIBLE` slows the whole ecosystem down, so claim it only with the probe that proves it.
--item
**Then stop.** You do not add participants three through N. Every further participant arrives as a request from realisateur, which stamps it first. If you find yourself registering a third project, you have exceeded the turn.
--law
**You are mechanism, not judgment.** You never set a weight, never pick what deserves turns, never decide which project comes online next. Those arrive through the front door.
--law
**A control is not data.** `schedule/FREEZE` gates dispatch; `schedule/RUN-MARKER` only records it. Never gate on the marker, never treat the freeze as a note.
--law
**The milestone is the merge.** This branch is done when it merges to `main` — not when the work looks finished on the branch.
ARGS
}

prose_realisateur() {
  cat <<'ARGS'
--role
**realisateur is perception and judgment.** It senses (offline surveys), triages (park-by-default), and records. It is the brain: it decides WHAT gets built and WHO comes online next. **It never decides alone and it never executes.** Zach is the only decider; realisateur puts the choice in front of him. It does not dispatch work itself — it asks scheduler through scheduler's own front door. Reaching around that door into another project's files is the failure this role exists to prevent.
--bar
**Bring the remaining agents online one at a time, by asking scheduler — and stamp each one as it arrives.** Each new participant must be in the rotation AND carry a bootstrap FOCUS.md written by `bin/stamp-agent.sh`. An unstamped participant is not online; `stamp-agent.sh --check` is what says so.
--item
**Verify scheduler registered itself and you** — by a DISPATCH line in the runner log, not by scheduler's own report. A status claim is stale by construction; re-probe it.
--item
**Decide the order the remaining agents come online, and record why.** One at a time. The order is a judgment and judgments get written down.
--item
**For each: stamp it first, then ask scheduler to register it.** `bin/stamp-agent.sh <project> --apply`, then scheduler's front door. Never edit scheduler's files yourself.
--item
**Re-derive weights fresh.** The pre-migration weights are a frozen judgment about an ecosystem that no longer exists. Do not restore them from memory or from git.
--item
**Write your verdict before you run out of room** — `CONTINUE`, `DONE`, or `IMPOSSIBLE`. Absent means truncated, and you will be dispatched again.
--law
**Law 1 — admission control.** Intake is free, building is quota-gated, so the backlog diverges regardless of build speed. Only pruning changes its sign. Park by default.
--law
**Law 2 — the reservoir is not debt.** A free-fed reservoir is supposed to grow. Debt is only parked ideas masquerading as active commitments.
--law
**Law 3 — retirement pressure.** Surfaces only ratchet up, because no session is ever ABOUT removing one. This file being short instead of 2517 lines IS Law 3. The next agent to append session residue here has broken it.
--law
**You direct scheduler through its front door**, never by editing its files. **You stamp every agent you bring online** — an agent without a role stamp invents one.
--law
**The milestone is the merge.** This branch is done when it merges to `main`.
ARGS
}

PROJECTS=(scheduler realisateur)

# Resolve a project's repo from its scheduler conf -- ONE source of truth,
# the same one stamp-agent.sh reads. Never a path retyped here.
repo_path() {
  local conf="$SCHED_ROOT/schedule/$1.conf"
  [ -f "$conf" ] || return 1
  grep -oP '(?<=PROJECT_REPO_PATH=")[^"]*' "$conf" 2>/dev/null | head -1
}

focus_rel() {
  local repo="$1"
  if   [ -f "$repo/.scheduler/FOCUS.md" ]; then echo ".scheduler/FOCUS.md"
  elif [ -f "$repo/.claude/FOCUS.md" ];    then echo ".claude/FOCUS.md"
  else echo ".scheduler/FOCUS.md"; fi
}

rc_total=0

for proj in "${PROJECTS[@]}"; do
  say "=== $proj"
  repo="$(repo_path "$proj")" || { say "  SKIP -- no schedule/$proj.conf"; rc_total=1; continue; }
  [ -n "$repo" ] && [ -d "$repo" ] || { say "  SKIP -- repo path unresolvable: ${repo:-<empty>}"; rc_total=1; continue; }

  mapfile -t args < <("prose_$proj")
  rel="$(focus_rel "$repo")"

  # Generate to a temp file WITHOUT touching the tree: stamp-agent.sh's
  # default is dry-run-to-stdout, so this is the generated artifact.
  gen="$(mktemp)"
  if ! STAMP_DATE="$DATE" "$STAMP" "$proj" "${args[@]}" > "$gen" 2>/dev/null; then
    rm -f "$gen"; say "  FAIL -- stamp-agent.sh refused these arguments"; rc_total=1; continue
  fi
  # stamp-agent.sh's dry run brackets the file in `=== ... ===` banner lines
  # (header, an optional "replacing an existing N-line file", and a footer).
  # Strip exactly those to recover the file itself. Anchored to the full
  # banner shape, not a bare `===`, so a `===`-containing prose line could
  # not be silently eaten.
  sed -i -E '/^=== .* ===$/d' "$gen"

  if [ "$MODE" = "verify" ]; then
    if [ -f "$repo/$rel" ] && diff -q "$repo/$rel" "$gen" >/dev/null 2>&1; then
      say "  MATCH -- $rel is byte-identical to the generated stamp"
    else
      say "  DRIFT -- $rel differs from the generated stamp (or is missing)"
      diff -u "$repo/$rel" "$gen" 2>/dev/null | head -40
      rc_total=1
    fi
    rm -f "$gen"; continue
  fi

  if [ "$MODE" = "dry" ]; then
    say "  would write $rel ($(wc -l < "$gen") lines) on branch $BRANCH (base $BASE)"
    if [ -f "$repo/$rel" ] && diff -q "$repo/$rel" "$gen" >/dev/null 2>&1; then
      say "  (already identical -- --apply would be a no-op)"
    fi
    rm -f "$gen"; continue
  fi

  # ---- apply ----
  # A dirty tree is a failed run, not a handoff. Refuse rather than commit
  # someone else's uncommitted work onto a bootstrap branch under our message.
  if [ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]; then
    say "  REFUSED -- $repo has a dirty tree. Commit or stash first."
    git -C "$repo" status --porcelain | sed 's/^/    /'
    rm -f "$gen"; rc_total=1; continue
  fi

  orig_branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if git -C "$repo" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git -C "$repo" checkout --quiet "$BRANCH" || { say "  FAIL -- checkout $BRANCH"; rm -f "$gen"; rc_total=1; continue; }
  else
    git -C "$repo" checkout --quiet -b "$BRANCH" "$BASE" || { say "  FAIL -- branch $BRANCH from $BASE"; rm -f "$gen"; rc_total=1; continue; }
    say "  created $BRANCH from $BASE"
  fi

  mkdir -p "$(dirname "$repo/$rel")"
  cp "$gen" "$repo/$rel"
  rm -f "$gen"

  if [ -z "$(git -C "$repo" status --porcelain -- "$rel")" ]; then
    say "  no-op -- $rel already at the generated content on $BRANCH"
  else
    msgf="$(mktemp)"
    {
      echo "bootstrap: stamp $proj's FOCUS.md for THE PLAY"
      echo
      echo "Regenerated by realisateur bin/make-bootstrap-branch.sh --date $DATE."
      echo "The prose is data inside that script, so this branch is reproducible"
      echo "from any repo state rather than being a one-off session artifact."
      echo "Verify with: make-bootstrap-branch.sh --verify"
      echo
      echo "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
    } > "$msgf"
    git -C "$repo" add -- "$rel"
    # -F, never -m: this prose contains backticks, which execute inside
    # double quotes. That has already happened once in this ecosystem.
    if git -C "$repo" commit --quiet -F "$msgf" -- "$rel"; then
      say "  committed $rel on $BRANCH ($(git -C "$repo" rev-parse --short HEAD))"
    else
      say "  FAIL -- commit refused"; rc_total=1
    fi
    rm -f "$msgf"
  fi

  [ -n "$orig_branch" ] && [ "$orig_branch" != "$BRANCH" ] && \
    git -C "$repo" checkout --quiet "$orig_branch" && say "  returned to $orig_branch"
done

say
case "$MODE" in
  dry)    say "DRY RUN -- nothing written. Re-run with --apply." ;;
  verify) [ "$rc_total" -eq 0 ] && say "VERIFY OK -- every live stamp matches its generated form." \
                                || say "VERIFY FAILED -- at least one stamp has drifted." ;;
  apply)  [ "$rc_total" -eq 0 ] && say "APPLIED -- branch $BRANCH is at the starting line in every repo." \
                                || say "APPLIED WITH FAILURES -- see above; the branch may be partial." ;;
esac
exit "$rc_total"
