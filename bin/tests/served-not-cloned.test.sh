#!/usr/bin/env bash
# HERMETICITY: fully hermetic. Every case runs against a FABRICATED scheduler
# tree in a temp dir (SERVED_SCHEDULER_REPO) and a fabricated fleet crontab
# dump (SERVED_FLEET_CRONTABS) -- no ssh, no sudo, no network, no live host,
# and the real ~/Documents/Projects/scheduler is never read. The date boundary
# is driven through SERVED_SUNSET rather than by waiting two weeks. The one
# thing it cannot fabricate is a real `git ls-tree origin/bashified`, so it
# builds a real throwaway git repo with that ref in the temp dir.
#
# served-not-cloned.test.sh -- witness for the vision probe's EXIT CONTRACT,
# which is the whole mechanism: red until the redesign lands, green when it
# does, and gone at the sunset.
#
# WHY THE MET PATH IS THE IMPORTANT CASE. A check that is red today is easy to
# write and proves nothing -- `false` is red today. What has to be witnessed is
# that some reachable state turns it GREEN, or the file is an insult with an
# exit code rather than a specification. So the central case here fabricates
# the post-redesign world and asserts rc=0.
#
# Usage: bin/tests/served-not-cloned.test.sh   (exit 0 = all pass)
set -uo pipefail
BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$BIN/served-not-cloned.sh"

pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (output lacked '$3')" ;; esac; }

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- fabricate a scheduler tree ------------------------------------------
# $1 = dir, $2 = "before" | "after"
make_scheduler() {
  local d="$1" era="$2"
  mkdir -p "$d/bin" "$d/schedule"
  git -C "$d" init -q 2>/dev/null
  git -C "$d" config user.email t@t.invalid; git -C "$d" config user.name t

  if [ "$era" = before ]; then
    # the monolith, the runner entrypoint, no DONE branch
    printf 'x\n%.0s' $(seq 100) > "$d/bin/scheduler"
    cat > "$d/bin/usage-paced-runner.sh" <<'R'
#!/usr/bin/env bash
outcome="$(verdict.sh classify "$name" "$rc")"; vrc=$?
if [ "$vrc" -eq 3 ]; then echo gaveup; fi
R
    # two confs sharing a long identical block, one with a hardcoded issue ref
    local block; block="$(for i in $(seq 20); do echo "STANDING RULE $i: this is a long shared line of prose."; done)"
    printf 'BATCH_PROMPT="You are alpha.\n%s\nStart with #34."\n' "$block" > "$d/schedule/alpha.conf"
    printf 'BATCH_PROMPT="You are beta.\n%s\n"\n' "$block" > "$d/schedule/beta.conf"
    mkdir -p "$d/focus"; echo "generated" > "$d/focus/alpha.md"
    echo "blocked on things" > "$d/BLOCKERS.md"
    # liveness spread across the files a single roster is meant to replace
    printf 'EXEMPT: alpha@monkey\n' > "$d/schedule/FREEZE"
    printf 'alpha|1|1|/x/scheduler-run alpha batch\n' > "$d/schedule/_paced.conf"
    printf 'RUNNER_CRON="0 */6 * * *"\n' > "$d/schedule/_runner.conf"
  else
    # the redesign: no monolith, no runner, DONE brakes, distinct live briefs,
    # no generated markdown, no BLOCKERS.md
    cat > "$d/bin/usage-paced-runner-RETIRED.txt" <<'R'
retired
R
    mkdir -p "$d/bin"
    cat > "$d/bin/dispatch-core.sh" <<'R'
#!/usr/bin/env bash
outcome="$(verdict classify "$name" "$rc")"; vrc=$?
if [ "$vrc" -eq 0 ]; then echo "DONE brakes here"; fi
R
    printf 'BATCH_PROMPT="You are alpha. Your queue is generated live."\n' > "$d/schedule/alpha.conf"
    printf 'BATCH_PROMPT="You are beta. Something else entirely, no overlap."\n' > "$d/schedule/beta.conf"
    # ONE roster, and nothing else left deciding. Written as the redesign
    # would leave it: the files it replaces are gone, not merely outvoted.
    printf '# project | account@host | rate | state\nalpha | alpha@monkey | 1h | live\n' > "$d/schedule/ROSTER"
  fi

  # a real origin/bashified ref -- the one thing that cannot be faked with a
  # plain file, since the probe uses `git ls-tree`.
  mkdir -p "$d/.bashified-stage/bin"
  echo '#!/usr/bin/env bash' > "$d/.bashified-stage/bin/arme"
  # The `after` dose is a PROJECT-shaped dose: it resolves its argument against
  # schedule/ROSTER. A dose that only execs bin/*.sh is the one that exists
  # today and is what probe_selfserve reports UNMET.
  [ "$era" = after ] && printf '#!/usr/bin/env bash\n# resolve <project> against ROSTER\n' > "$d/.bashified-stage/bin/dose"
  ( cd "$d" && git add -A >/dev/null 2>&1 && git commit -qm x >/dev/null 2>&1 ) || true
  ( cd "$d" && git rm -rq --cached .bashified-stage >/dev/null 2>&1 ) || true
  # build a tree object containing bin/ from the stage, and point
  # refs/remotes/origin/bashified at a commit holding it
  ( cd "$d/.bashified-stage" \
      && GIT_DIR="$d/.git" GIT_INDEX_FILE="$d/.git/bashidx" git add -A . >/dev/null 2>&1 \
      && T="$(GIT_DIR="$d/.git" GIT_INDEX_FILE="$d/.git/bashidx" git write-tree)" \
      && C="$(GIT_DIR="$d/.git" git commit-tree "$T" -m bashified)" \
      && GIT_DIR="$d/.git" git update-ref refs/remotes/origin/bashified "$C" ) >/dev/null 2>&1
  rm -rf "$d/.bashified-stage"
  ( cd "$d" && git add -A >/dev/null 2>&1 && git commit -qm y >/dev/null 2>&1 ) || true
}

echo "== 1. BEFORE THE REDESIGN: RED, AND SPECIFIC ABOUT WHY ==================="
BEFORE="$TMP/before"; make_scheduler "$BEFORE" before
# The load-bearing part of this fixture is the `Documents/Projects/scheduler/bin`
# substring the probe greps for -- NOT the home prefix, which is written from
# $TMP so bin/hardcoded-home-lint.sh has nothing to flag. A path under one
# named user's home is not a default even in a fixture.
printf '0 */6 * * * %s/alpha/Documents/Projects/scheduler/bin/scheduler-run alpha batch\n' "$TMP" > "$TMP/crontabs-before"
rc=0
O="$(SERVED_SCHEDULER_REPO="$BEFORE" SERVED_FLEET_CRONTABS="$TMP/crontabs-before" \
     SERVED_SUNSET=2099-01-01 bash "$SCRIPT" 2>&1)" || rc=$?
eq "unmet vision exits 1" "$rc" 1
has "the monolith is named"        "$O" "UNMET  monolith"
has "the dispatch verb is named"   "$O" "UNMET  dosecut"
has "duplicated briefs are named"  "$O" "UNMET  sharedbrief"
has "a hardcoded issue ref is named" "$O" "UNMET  livebrief"
has "the discarded verdict is named" "$O" "UNMET  donebrakes"
has "the markdown surface is named"  "$O" "UNMET  headless"
has "the per-account clone is named" "$O" "UNMET  clonefree"
has "and it prints the sunset every run" "$O" "sunset 2099-01-01"

echo
echo "== 2. AFTER THE REDESIGN: GREEN ========================================="
# The case that makes this file a specification rather than a complaint.
AFTER="$TMP/after"; make_scheduler "$AFTER" after
printf '0 */6 * * * /usr/bin/env dose alpha batch\n' > "$TMP/crontabs-after"
rc=0
O="$(SERVED_SCHEDULER_REPO="$AFTER" SERVED_FLEET_CRONTABS="$TMP/crontabs-after" \
     SERVED_SUNSET=2099-01-01 bash "$SCRIPT" 2>&1)" || rc=$?
eq "the met vision exits 0" "$rc" 0
has "and it says so" "$O" "9/9 met"
has "and it asks to be deleted" "$O" "git rm"

echo
echo "== 3. THE SUNSET WINS OVER EVERYTHING ==================================="
# Past the date the probes stop being the question. Asserted from BOTH states,
# because a sunset that only fires while red is not a sunset -- it is a to-do.
for era in before after; do
  rc=0
  O="$(SERVED_SCHEDULER_REPO="$TMP/$era" SERVED_FLEET_CRONTABS="$TMP/crontabs-$era" \
       SERVED_SUNSET=2000-01-01 bash "$SCRIPT" 2>&1)" || rc=$?
  eq "past sunset exits 4 even when the vision is '$era'" "$rc" 4
  has "and it demands deletion ($era)" "$O" "git rm bin/served-not-cloned.sh"
done
rc=0
O="$(SERVED_SCHEDULER_REPO="$BEFORE" SERVED_FLEET_CRONTABS="$TMP/crontabs-before" \
     SERVED_SUNSET="$(date +%F)" bash "$SCRIPT" 2>&1)" || rc=$?
eq "the sunset day itself is already expired" "$rc" 4
has "it says both outcomes are honest" "$O" "decided not to do this"
has "and that moving the date is a decision" "$O" "re-commit"

echo
echo "== 3b. THE LIVE SUNSET, WITH NO OVERRIDE ================================"
# THIS is the case that makes the self-destruct real. Every case above drives
# the date through SERVED_SUNSET, so none of them can ever fire on their own --
# a suite that only tests a sunset it controls has tested nothing about the
# actual deadline. This one runs `--strict` with NO override, so it reads the
# date compiled into the script against today.
#
# From 2026-08-24 it goes red on every pull request, and the only thing that
# clears it is `git rm` on bin/served-not-cloned.sh and this file. That is the
# whole point: the deletion is enforced by the build rather than remembered.
# If you are reading this because CI went red on a change that has nothing to
# do with the scheduler -- that is not a bug, that is the sunset. Delete both
# files and say in the commit whether the redesign landed.
rc=0
O="$(bash "$SCRIPT" --strict 2>&1)" || rc=$?
if [ "$rc" -eq 0 ]; then
  ok "the live sunset has not been reached yet"
else
  bad "SUNSET REACHED -- delete bin/served-not-cloned.sh and this suite (rc=$rc). $O"
fi
has "and --strict names the date it is holding" "$O" "sunset"

echo
echo "== 4. BLIND IS NEVER MET ================================================"
# The recorded pathology: a pass that reached zero targets and exited 0.
rc=0
O="$(SERVED_SCHEDULER_REPO="$AFTER" SERVED_SUNSET=2099-01-01 bash "$SCRIPT" 2>&1)" || rc=$?
eq "an unprobed fleet exits 2, not 0" "$rc" 2
has "and says BLIND is not met" "$O" "BLIND is not met"

rc=0
O="$(SERVED_SCHEDULER_REPO="$TMP/nonexistent" SERVED_FLEET_CRONTABS="$TMP/crontabs-after" \
     SERVED_SUNSET=2099-01-01 bash "$SCRIPT" 2>&1)" || rc=$?
eq "a missing scheduler checkout is BLIND, not met" "$rc" 2

rc=0
O="$(SERVED_SCHEDULER_REPO="$AFTER" SERVED_FLEET_CRONTABS="$TMP/no-such-file" \
     SERVED_SUNSET=2099-01-01 bash "$SCRIPT" 2>&1)" || rc=$?
eq "a fleet dump that is not there is BLIND, not met" "$rc" 2

echo
echo "== 5. THE ARGUMENT CONTRACT ============================================="
rc=0; O="$(bash "$SCRIPT" --nonsense 2>&1)" || rc=$?
eq "an unknown flag exits 2" "$rc" 2
rc=0; O="$(bash "$SCRIPT" --help 2>&1)" || rc=$?
eq "--help exits 0" "$rc" 0
has "--help documents the sunset exit" "$O" "SUNSET"

echo
echo "served-not-cloned.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
