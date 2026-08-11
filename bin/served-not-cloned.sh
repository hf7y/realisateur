#!/usr/bin/env bash
# served-not-cloned.sh -- seven probes asking one question about the whole
# estate: does mechanism reach an account by being SERVED, or by being COPIED?
#
# GUARD: is the scheduler served to accounts as a verb, or still cloned into each one?
# RUNNER: bin/tests/served-not-cloned.test.sh
# GUARD-TEST: bin/tests/served-not-cloned.test.sh
# GATE: strict
#   `--strict` is the SUNSET CHECK ALONE: no scheduler checkout, no GitHub, no
#   ssh, no fleet -- just today's date against SUNSET. That is what makes the
#   self-destruct real rather than a paragraph. From 2026-08-24 the tests
#   workflow goes red on every pull request and the ONLY thing that clears it
#   is deleting this file. The seven vision probes stay operator-run, because
#   they need a scheduler checkout CI does not have; a run that cannot see the
#   estate is BLIND, and BLIND is never green here.
# VERIFIED: 2026-08-10 via bash bin/served-not-cloned.sh --fleet (0/7 met, 7 to go, 0 blind)
#
# ############################################################################
# THE VISION, IN ONE SENTENCE
# ############################################################################
#
#   The scheduler stops being a thing every account CLONES and becomes a verb
#   every account is SERVED.
#
# That is a claim about the whole ecosystem, not about one repo's file layout,
# and the rest of this header is why.
#
# ############################################################################
# WHY THIS IS THE ECOSYSTEM'S SHAPE AND NOT THE SCHEDULER'S PROBLEM
# ############################################################################
#
# Every project here has already learned the same lesson under a different
# name, and each time it was learned it was written down as a door:
#
#   bibliothecaire   `consulte` files an issue on its queue. The asking
#                    account needs no clone of bibliothecaire and no push
#                    access to any branch of it. Before the door existed, a
#                    request sat staged and uncommitted on a clone for two
#                    days because the account that wanted to ask held no
#                    credential (2026-08-04).
#   senechal         `notify-senechal` files through senechal's own front
#                    door and confirms the note reached its remote. The rule
#                    it encodes: the project that GENERATES machine config
#                    owns it; senechal owns KNOWING it exists.
#   realisateur      the verb release channel. `cut-verb-build.sh` assembles
#                    a dated build; `install-verb-build.sh` verifies every
#                    verb the manifest promises and repoints ONE symlink,
#                    atomically, or discards the build; `selfdev-release-tick`
#                    is the consumer's clock. An account holds a small
#                    near-immutable bootstrap and is SERVED everything else.
#
# Three doors, one shape: A FRONT DOOR WITH A CLOCK, INSTEAD OF A CLONE WITH
# A HOPE. The scheduler is the last large thing in the estate that still
# travels as a copy, and it is the one that dispatches every other project's
# work -- so its distribution model is the estate's distribution model.
#
# ############################################################################
# WHAT THE COPY ACTUALLY COSTS -- measured 2026-08-10, not supposed
# ############################################################################
#
#  1. A DIRTY FILE IS AN INDEFINITE OUTAGE. Ten accounts each hold a full
#     clone of a 3,465-line `bin/scheduler` plus 24 scripts, and dispatch runs
#     out of it. `usage-paced-runner.sh`'s pull-before-dispatch is fail-loud-
#     not-block by design, so ONE uncommitted file in one account's clone
#     means that account silently never receives another instruction update.
#     vim-arcade has been in exactly that state, and the dirty file is
#     `BLOCKERS.md` -- the file recording what blocks us IS what blocks us
#     (hf7y/scheduler#61, #70, #75). Under a served model there is no
#     per-account clone to go dirty; the failure mode stops being fixed and
#     starts being impossible.
#
#  2. THE INSTRUCTION GETS RETYPED. Commit 9cfd130 hand-typed one identical
#     32-line STANDING RULES block into three accounts' BATCH_PROMPTs,
#     byte-for-byte, with no shared source. Measured across the live fleet the
#     same day: vim-arcade and ecosim share 65 identical prompt lines,
#     vim-arcade and bibliothecaire 27, bibliothecaire and ecosim 27. An edit
#     to one silently stops applying to the others, and nothing says so.
#
#  3. THE BRIEF GOES STALE AND NOTHING NOTICES. ecosim's live prompt says
#     "Start with #34"; that issue is CLOSED. vim-arcade's names #74 and #75;
#     both CLOSED. A prompt typed once and dispatched forever cannot track the
#     state it points at. Generated-from-live-state retires the whole class.
#
#  4. NOBODY CAN NAME WHAT IS RUNNING. A clone is whatever that account last
#     happened to pull. A build is a dated id every account can report, hold
#     while others move past it, and roll back to BY NAME. "I am on
#     2026-08-10T032316Z" is a bug report; "I am on some sha" is archaeology.
#
# ############################################################################
# WHY THIS FILE FAILS TODAY, ON PURPOSE, AND WHY IT DELETES ITSELF
# ############################################################################
#
# bin/thermostat-wiring.sh -- the estate's other vision probe -- refuses to be
# a conformance test, and its reasoning is right and worth quoting:
#
#     "A check nobody expects to be green is a document with an exit code."
#
# Seven suites had been red long enough that red stopped meaning anything;
# `pivot.sh`'s `ci` MOVE exists because of it. So thermostat-wiring is a
# RATCHET: it asserts only that the vision is no further away than last time.
#
# This file is the other half, and it is deliberately the thing that one
# argues against -- a check that is red on day one -- with the one addition
# that makes red honest: A DEADLINE. It is not a permanent conformance test.
# It is a COMMITMENT with an expiry stamped into it.
#
#   * Until SUNSET it exits 1 while the vision is unmet. Red means "we said we
#     would do this and have not yet", which is information, and it is only
#     information because it cannot last.
#   * On the day the redesign lands it exits 0.
#   * FROM SUNSET ONWARD it exits 4 no matter what the probes say, and the
#     only thing that makes it green again is `git rm` on this file.
#
# That is the difference between a red check and a rotting one. A ratchet
# tolerates a vision indefinitely; this refuses to. If the redesign has not
# happened by SUNSET, the correct response is still deletion -- delete it and
# say in the commit message that the estate chose not to do this. A vision
# nobody will commit to a date on is not a plan, and carrying its probe around
# for another month would be the same prose-instead-of-mechanism failure the
# redesign exists to end.
#
# usage:  served-not-cloned.sh [--fleet] [--strict] [--quiet]
# exit:   0 vision met      1 UNMET (expected until the redesign lands)
#         2 BLIND (a probe could not be run -- never counted as met)
#         4 SUNSET REACHED -- delete this file
#         --strict is the sunset check alone: no repo, no network. The CI gate.
set -uo pipefail

# ############################################################################
# THE SUNSET. Two weeks from the day this was written (2026-08-10), Zach-set.
# Overridable ONLY to let the test suite exercise both sides of the date --
# bin/tests/served-not-cloned.test.sh does exactly that. Moving it in the file
# is not a maintenance action; it is a decision to re-commit, and it should
# come with a commit message that says so.
# ############################################################################
SUNSET="${SERVED_SUNSET:-2026-08-24}"

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

CLI_NAME='served-not-cloned.sh'
CLI_SUMMARY='is the scheduler served to accounts as a verb, or still cloned into each one? red until the redesign lands, then deletes itself'
CLI_USAGE='  served-not-cloned.sh            probe locally (scheduler checkout + GitHub)
  served-not-cloned.sh --fleet    also probe the live accounts over ssh
  served-not-cloned.sh --strict   the SUNSET check alone -- no repo, no network; this is the CI gate'
CLI_FLAGS='--fleet --strict --quiet'
CLI_EXITS='  0  the vision is met -- this file has done its job, delete it
  1  UNMET -- expected until the redesign lands
  2  BLIND -- a probe could not be run. NEVER "all clear"
  4  SUNSET reached: delete this file, whatever the probes say'
CLI_POSITIONAL=none
. "$ROOT/bin/lib/cli-guard.sh"
cli_guard "$@"

FLEET=0; QUIET=0; STRICT=0
for a in "$@"; do
  case "$a" in
    --fleet) FLEET=1 ;;
    --strict) STRICT=1 ;;
    --quiet) QUIET=1 ;;
    *) echo "$CLI_NAME: unknown flag $a" >&2; exit 2 ;;
  esac
done

SCHED="${SERVED_SCHEDULER_REPO:-$HOME/Documents/Projects/scheduler}"
SELFDEV_HOST="${SERVED_FLEET_HOST:-monkey}"
GH_OWNER="${SERVED_GH_OWNER:-hf7y}"
DUP_THRESHOLD="${SERVED_DUP_THRESHOLD:-15}"

met=0; unmet=0; blind=0
say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
row() { # row <verdict> <name> <detail>
  case "$1" in
    MET)   met=$((met+1));   say "    MET    $2  $3" ;;
    UNMET) unmet=$((unmet+1)); say "    UNMET  $2  $3" ;;
    BLIND) blind=$((blind+1)); say "    BLIND  $2  $3" ;;
  esac
}

# ---------------------------------------------------------------------------
# The probes. Each one is a single yes/no about the SERVED model, phrased so
# that "met" is a fact about the world and not about a document.
# ---------------------------------------------------------------------------

# 1. MONOLITH -- the 3,465-line bin/scheduler is gone from the ref accounts
#    would clone. Its own sunset decision is hf7y/scheduler#34: the five
#    French verbs already cover its four real jobs.
probe_monolith() {
  [ -d "$SCHED/.git" ] || { row BLIND monolith "no scheduler checkout at $SCHED"; return; }
  if [ -f "$SCHED/bin/scheduler" ]; then
    row UNMET monolith "bin/scheduler is $(wc -l < "$SCHED/bin/scheduler") lines on main"
  else
    row MET monolith "bin/scheduler is gone"
  fi
}

# 2. DOSECUT -- dispatch exists as a VERB on the cut, not only as a script in
#    a repo. `dose` is "apportion this ecosystem's scheduled work", which is
#    the paced dispatcher's job description already.
probe_dosecut() {
  [ -d "$SCHED/.git" ] || { row BLIND dosecut "no scheduler checkout at $SCHED"; return; }
  local verbs
  verbs="$(git -C "$SCHED" ls-tree --name-only origin/bashified bin/ 2>/dev/null)" \
    || { row BLIND dosecut "cannot read origin/bashified"; return; }
  [ -n "$verbs" ] || { row BLIND dosecut "origin/bashified carries no bin/"; return; }
  if grep -q '^bin/dose$' <<<"$verbs"; then
    # Declared is not enough: the dispatcher's own entrypoint has to BE it.
    if grep -rqs 'usage-paced-runner\.sh' "$SCHED/bin" 2>/dev/null; then
      row UNMET dosecut "dose is declared, but usage-paced-runner.sh is still the dispatch entrypoint"
    else
      row MET dosecut "dose is the declared dispatch verb and no runner script shadows it"
    fi
  else
    row UNMET dosecut "origin/bashified declares no bin/dose"
  fi
}

# 3. SHAREDBRIEF -- no two confs' prompts are near-identical copies. This is
#    the 9cfd130 shape: one block, three hand-typed homes, no shared source.
probe_sharedbrief() {
  local dir="$SCHED/schedule" f a b shared worst=0 pair=""
  [ -d "$dir" ] || { row BLIND sharedbrief "no $dir"; return; }
  local -a confs=() texts=()
  for f in "$dir"/*.conf; do
    case "$(basename "$f")" in _*) continue ;; esac
    local t
    t="$(bash -c "BATCH_PROMPT=''; SWEEP_PROMPT=''; source '$f' 2>/dev/null; printf '%s\n%s' \"\$BATCH_PROMPT\" \"\$SWEEP_PROMPT\"" 2>/dev/null)"
    [ -n "$(tr -d '[:space:]' <<<"$t")" ] || continue
    confs+=("$(basename "$f" .conf)"); texts+=("$t")
  done
  [ "${#confs[@]}" -ge 2 ] || { row BLIND sharedbrief "fewer than two confs carry a prompt"; return; }
  local i j
  for ((i = 0; i < ${#confs[@]}; i++)); do
    for ((j = i + 1; j < ${#confs[@]}; j++)); do
      shared="$(comm -12 \
        <(printf '%s\n' "${texts[i]}" | awk 'length($0)>=20' | sort -u) \
        <(printf '%s\n' "${texts[j]}" | awk 'length($0)>=20' | sort -u) | wc -l)"
      if [ "$shared" -gt "$worst" ]; then worst="$shared"; pair="${confs[i]}/${confs[j]}"; fi
    done
  done
  if [ "$worst" -ge "$DUP_THRESHOLD" ]; then
    row UNMET sharedbrief "$pair share $worst identical prompt lines"
  else
    row MET sharedbrief "worst overlap is $worst lines (threshold $DUP_THRESHOLD)"
  fi
}

# 4. LIVEBRIEF -- no conf's prompt hardcodes an issue number. A pointer typed
#    once and dispatched forever cannot track what it points at.
probe_livebrief() {
  local dir="$SCHED/schedule" f hits=""
  [ -d "$dir" ] || { row BLIND livebrief "no $dir"; return; }
  for f in "$dir"/*.conf; do
    case "$(basename "$f")" in _*) continue ;; esac
    local t
    t="$(bash -c "BATCH_PROMPT=''; SWEEP_PROMPT=''; source '$f' 2>/dev/null; printf '%s\n%s' \"\$BATCH_PROMPT\" \"\$SWEEP_PROMPT\"" 2>/dev/null)"
    grep -qE '#[0-9]+' <<<"$t" && hits="$hits $(basename "$f" .conf)"
  done
  if [ -n "$hits" ]; then
    row UNMET livebrief "hardcoded issue refs in:$hits"
  else
    row MET livebrief "no conf prompt names a fixed issue number"
  fi
}

# 5. DONEBRAKES -- the verdict changes what happens next. `verdict.sh
#    classify` already returns 0 for DONE, meaning "bar met; stop dispatching,
#    this is success" -- and no dispatcher branches on it. DONE was recorded 9
#    times across 4 accounts in one day and stopped nothing; bibliothecaire
#    recorded it on six consecutive runs and was re-dispatched every time
#    (hf7y/scheduler#54). The agents answer correctly and nothing listens.
#
#    SEARCHED ACROSS THE TREE, NOT IN ONE NAMED FILE. The first draft of this
#    probe read `bin/usage-paced-runner.sh` specifically -- so it went BLIND
#    forever the moment the redesign retired that file, and the check could
#    never have gone green. Its own test suite caught that, which is the
#    argument for testing the MET path rather than only the red one: a probe
#    whose success condition depends on the thing the vision deletes is not a
#    probe, it is a trap.
probe_donebrakes() {
  [ -d "$SCHED/bin" ] || { row BLIND donebrakes "no $SCHED/bin to search"; return; }
  local hit
  hit="$(grep -rlE 'vrc"? -eq 0' "$SCHED/bin" "$SCHED/lib" 2>/dev/null | head -1)"
  if [ -n "$hit" ]; then
    row MET donebrakes "DONE has a branch in ${hit#$SCHED/}"
  else
    row UNMET donebrakes "no 'vrc -eq 0' branch anywhere: DONE is computed, logged and discarded"
  fi
}

# 6. HEADLESS -- the scheduler writes no markdown feedback surface of its own.
#    A headless dispatcher has no local file it MUST write to report, which is
#    what makes the #61 freeze structurally impossible rather than merely
#    fixed. Counted as the generated trees plus BLOCKERS.
probe_headless() {
  [ -d "$SCHED" ] || { row BLIND headless "no $SCHED"; return; }
  local n
  n="$(find "$SCHED/focus" "$SCHED/questions" "$SCHED/services" -name '*.md' 2>/dev/null | wc -l)"
  local blockers=0
  [ -f "$SCHED/BLOCKERS.md" ] && blockers=1
  if [ "$n" -eq 0 ] && [ "$blockers" -eq 0 ]; then
    row MET headless "no generated markdown surface, no BLOCKERS.md"
  else
    row UNMET headless "$n generated .md file(s); BLOCKERS.md present=$blockers"
  fi
}

# 7. CLONEFREE -- the live fleet. No account dispatches out of its own
#    scheduler clone. This is the probe the whole file is named for, and it is
#    the only one that needs the host, so it is opt-in via --fleet and BLIND
#    without it rather than quietly skipped.
# 8. ONEROSTER -- "live" is ONE fact in ONE file, not an agreement between
#    several. Zach, 2026-08-11: "it checks one source of truth. and that's
#    maintained by me."
#
#    TODAY a project dispatches only if THREE files agree, and every one of
#    them says so in its own header, in the imperative, because the trap has
#    fired before:
#      schedule/_paced.<host>.conf   the row's enabled flag is 1
#      schedule/FREEZE               an UNCOMMENTED `EXEMPT: <p>@<host>` line
#      schedule/<p>.conf             CRON_HOST/CRON_ACCOUNT name this host
#    chezz's park needed edits in two of them -- "either one alone leaves it
#    dark, which is the point of having two" -- and _paced.conf's own TRAP 1
#    records the inverse: DELETING a row ARMS a fixed nightly cron rather than
#    disarming it. Both directions of a two-key switch have now bitten.
#
#    A single roster cannot have a disagreement, which is the whole claim.
probe_oneroster() {
  [ -d "$SCHED/.git" ] || { row BLIND oneroster "no scheduler checkout at $SCHED"; return; }
  local roster="$SCHED/schedule/ROSTER"
  if [ ! -f "$roster" ]; then
    local n=0
    [ -f "$SCHED/schedule/FREEZE" ] && n=$((n+1))
    ls "$SCHED"/schedule/_paced*.conf >/dev/null 2>&1 && n=$((n+1))
    ls "$SCHED"/schedule/_runner*.conf >/dev/null 2>&1 && n=$((n+1))
    row UNMET oneroster "no schedule/ROSTER; liveness still spread across $n file kind(s)"
    return
  fi
  # Present is not enough. If the files it replaces still decide anything, it
  # is a fourth opinion rather than the source -- which is strictly worse.
  local stale=""
  [ -f "$SCHED/schedule/FREEZE" ] && grep -qE '^[[:space:]]*EXEMPT:' "$SCHED/schedule/FREEZE" 2>/dev/null && stale="$stale FREEZE"
  grep -qhE '^[a-z0-9-]+\|[01]\|' "$SCHED"/schedule/_paced*.conf 2>/dev/null && stale="$stale _paced"
  if [ -n "$stale" ]; then
    row UNMET oneroster "schedule/ROSTER exists but$stale still carries live rows -- a fourth opinion, not a source"
  else
    row MET oneroster "schedule/ROSTER is the only file deciding what dispatches"
  fi
}

# 9. SELFSERVE -- `dose <project>` is reachable and self-installing on the
#    self-dev host. Zach, 2026-08-11: "I should be able to ssh zach@monkey and
#    run dose ecosim and the newest ecosim self-installs, updates, starts
#    clearing issues."
#
#    TWO THINGS MAKE THIS FAIL TODAY and both are invisible from inside the
#    repo, which is why this is a probe and not a paragraph:
#      1. ~/.local/bin is NOT on monkey's non-interactive PATH, so
#         `ssh monkey dose ...` cannot find a verb installed there even when
#         it is installed correctly. Measured 2026-08-11: PATH over ssh is
#         /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin plus
#         games and snap. Nothing under $HOME.
#      2. zach@monkey's scheduler checkout is on a FEATURE BRANCH
#         (probe-after-runnability-20260806) five days behind main -- so a
#         dose that read its truth from the local clone would read stale
#         config on the very host the command is typed on. Reading the roster
#         from GitHub is what makes it a bomb rather than a clone-follower.
#
#    Local half only (the repo half); the fleet half belongs to --fleet.
probe_selfserve() {
  [ -d "$SCHED/.git" ] || { row BLIND selfserve "no scheduler checkout at $SCHED"; return; }
  local verbs
  verbs="$(git -C "$SCHED" ls-tree --name-only origin/bashified bin/ 2>/dev/null)" \
    || { row BLIND selfserve "cannot read origin/bashified"; return; }
  grep -q '^bin/dose$' <<<"$verbs" || { row UNMET selfserve "origin/bashified declares no bin/dose"; return; }
  # A project-shaped dose takes a PROJECT, not only a script name. The
  # generated verb's subcommand table is the honest place to ask.
  local dosefile
  dosefile="$(git -C "$SCHED" show origin/bashified:bin/dose 2>/dev/null)" \
    || { row BLIND selfserve "cannot read origin/bashified:bin/dose"; return; }
  if grep -qE 'ROSTER|roster' <<<"$dosefile"; then
    row MET selfserve "dose resolves a project against the roster"
  else
    row UNMET selfserve "dose dispatches to bin/*.sh only -- no project form, no roster read"
  fi
}

probe_clonefree() {
  local out
  # SERVED_FLEET_CRONTABS: read the fleet's crontab content from a file
  # instead of over ssh. Exists so bin/tests/served-not-cloned.test.sh can
  # exercise BOTH sides of this probe with no host, no ssh and no sudo --
  # same reasoning as install-verbs.sh's INSTALLE_* and the tick's TICK_*.
  # Without it the MET path would be untested, and "passes on the redesign"
  # would be a claim rather than a witnessed fact.
  if [ -n "${SERVED_FLEET_CRONTABS:-}" ]; then
    [ -f "$SERVED_FLEET_CRONTABS" ] \
      || { row BLIND clonefree "SERVED_FLEET_CRONTABS names $SERVED_FLEET_CRONTABS, which does not exist"; return; }
    out="$(cat "$SERVED_FLEET_CRONTABS")"
  elif [ "$FLEET" -eq 0 ]; then
    row BLIND clonefree "not probed (--fleet not given); an unprobed fleet is not a served one"
    return
  else
    out="$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$SELFDEV_HOST" \
          'sudo -n bash -c '"'"'for a in $(getent passwd | awk -F: "\$3>=3000 && \$3<=3099 {print \$1}"); do crontab -l -u "$a" 2>/dev/null; done'"'"'' 2>/dev/null)" \
      || { row BLIND clonefree "could not reach $SELFDEV_HOST"; return; }
  fi
  [ -n "$out" ] && grep -q . <<<"$out" || { row BLIND clonefree "$SELFDEV_HOST returned no crontab content"; return; }
  local n
  n="$(grep -c 'Documents/Projects/scheduler/bin' <<<"$out")"
  if [ "$n" -eq 0 ]; then
    row MET clonefree "no account dispatches out of its own scheduler clone"
  else
    row UNMET clonefree "$n crontab line(s) exec into a per-account scheduler clone"
  fi
}

# ---------------------------------------------------------------------------
# THE SUNSET CHECK RUNS FIRST AND WINS. Past the date, what the probes say is
# no longer the question -- the question is why this file still exists.
# ---------------------------------------------------------------------------
today="$(date +%F)"
say "served-not-cloned -- $today  (sunset $SUNSET)"
say "  scheduler: $SCHED"
say

if [[ "$today" > "$SUNSET" ]] || [ "$today" = "$SUNSET" ]; then
  cat >&2 <<EOF
SUNSET REACHED ($SUNSET).

  This file was a two-week commitment to one change: the scheduler stops being
  a thing every account CLONES and becomes a verb every account is SERVED.
  The window is over, and the correct action is the same either way:

      git rm bin/served-not-cloned.sh bin/tests/served-not-cloned.test.sh

  If the redesign landed, delete it because it is done -- and say so in the
  commit. If it did not, delete it because the estate decided not to do this,
  and say THAT in the commit. Both are honest. Carrying the probe into a third
  week is not: it would be a paragraph with an exit code, which is the exact
  failure the redesign exists to end.

  Moving SUNSET forward in the file is a decision to re-commit, not
  maintenance. Do it deliberately, in a commit that argues for it.
EOF
  exit 4
fi

# --strict stops here: the sunset has been checked and did not fire, and the
# seven probes below need a scheduler checkout this mode promises not to need.
# Saying "the sunset has not arrived" is the whole of what CI is being asked.
if [ "$STRICT" -eq 1 ]; then
  say "  sunset $SUNSET not reached -- this file may still stand. (Vision probes not run: --strict.)"
  exit 0
fi

probe_monolith
probe_dosecut
probe_sharedbrief
probe_livebrief
probe_donebrakes
probe_headless
probe_clonefree
probe_oneroster
probe_selfserve

total=$((met + unmet + blind))
say
say "served-not-cloned: $met/$total met, $unmet to go, $blind blind -- sunset $SUNSET"

# BLIND is never success. An unprobed claim is not a met one, and this file
# exists precisely because "we could not see" kept being filed as "fine".
if [ "$blind" -gt 0 ]; then
  say "  BLIND is not met. Re-run with --fleet, or from a host that can reach $SELFDEV_HOST."
  exit 2
fi
[ "$unmet" -eq 0 ] || exit 1

cat <<EOF

  MET -- all $total probes pass. The scheduler is served, not cloned.

  This file has done its job. Delete it:
      git rm bin/served-not-cloned.sh bin/tests/served-not-cloned.test.sh
EOF
