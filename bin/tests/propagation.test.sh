#!/usr/bin/env bash
# propagation.test.sh -- THE DEV/PROD DOCTRINE, AS A GUARD.
#
# Zach, 2026-08-07, directing this work: "creates a test script rather than
# prose to document the philosophy." So the propagation doctrine is not a
# markdown section a future session may or may not read. It is these
# assertions, and CI globs bin/tests/*.sh, so violating it stops a merge.
#
# The doctrine, six sentences, one per section:
#
#   1. EVERY ARTIFACT HAS EXACTLY ONE DECLARED CHANNEL.
#      bin/selfdev-gh-app.sh was written on 2026-08-06 for accounts that had
#      no way to receive it, and nothing anywhere noticed.
#
#   2. `main` IS NOT A DEPLOY REF, AND THE LEAK MAY NOT GROW.
#      Ten realisateur commands reach accounts as shims that exec into the
#      realisateur clone. That is `main` deploying through the back door. The
#      count is bounded and the bound may only be lowered.
#
#   3. A CHANNEL WITH NO CLOCK IS NOT A CHANNEL.
#      Probed 2026-08-07: scheduler was current on every armed account because
#      usage-paced-runner.sh pulls it every tick. realisateur was 15 commits
#      behind on all four self-dev accounts because nothing pulled it ever.
#      Same repos, same hosts, same credentials. The only difference was a
#      clock.
#
#   4. A STOPPED CLOCK IS A FINDING, NOT A SILENCE.
#      The checker must detect that the fixer died -- offline, no ssh, no
#      network -- or the estate learns about dead propagation the way it
#      learned about this one: a human reading a sha by hand.
#
#   5. PULL, NOT PUSH.
#      The consumer owns its clock. Asserted mechanically, because a doctrine
#      that is only written down gets edged back the first time push is more
#      convenient.
#
#   6. "FOUND NOTHING" IS NOT "NOTHING IS WRONG."
#      MONKEY.md 5's `garde` reported "nothing pending -- every set is already
#      copied and proven" with nothing reachable.
#
# HERMETIC. No network, no ssh, no sudo, no read of the live machine. Fixture
# homes under a temp dir, a fake installer, HOME/TICK_STATE/VERB_BUILD_ROOT
# redirected. A suite that needed the real estate to be healthy could not tell
# its own passing from the estate's.
#
# Usage: bin/tests/propagation.test.sh   (exit 0 = all pass)
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TICK="$REPO/bin/selfdev-release-tick.sh"
SET_LIB="$REPO/bin/lib/propagation-set.sh"
[ -x "$TICK" ]    || { echo "FAIL: $TICK not executable"; exit 1; }
[ -f "$SET_LIB" ] || { echo "FAIL: $SET_LIB missing"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
has()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1 (unexpectedly present: $3)" ;; *) ok "$1" ;; esac; }
rc()    { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }

echo "propagation.test.sh"
. "$SET_LIB"

# ===========================================================================
echo
echo "-- 1. EVERY ARTIFACT HAS EXACTLY ONE DECLARED CHANNEL ------------------"
# ===========================================================================
# The ratchet. A new script in bin/ cannot be merged without someone deciding
# how it reaches the accounts that will use it. One file to edit, one line to
# add -- and CI red until it is added.

unclassified=""
for f in "$REPO"/bin/*.sh; do
  n="$(basename "$f")"
  prop_channel "$n" >/dev/null || unclassified="$unclassified $n"
done
if [ -z "$unclassified" ]; then
  ok "every bin/*.sh is classified in bin/lib/propagation-set.sh"
else
  bad "UNCLASSIFIED, so they reach no account by any path:$unclassified"
  echo "       Add each to PROP_BOOTSTRAP_SCRIPTS, PROP_PROVISION_SCRIPTS,"
  echo "       PROP_PAYLOAD_SCRIPTS or PROP_LOCAL_SCRIPTS. The question is:"
  echo "       would it still be needed on a host with NO PAYLOAD INSTALLED?"
  echo "       yes -> bootstrap.  stands an account up once -> provision."
  echo "       no -> payload (a verb).  never leaves this repo -> local."
fi

ALL="$PROP_BOOTSTRAP_SCRIPTS $PROP_PROVISION_SCRIPTS $PROP_PAYLOAD_SCRIPTS $PROP_LOCAL_SCRIPTS"

# Classified twice is worse than classified zero times: two channels means two
# answers to "which copy is running", which is the one question a bug report
# must be able to answer.
dupes=""
for n in $ALL; do
  c=0; for m in $ALL; do [ "$m" = "$n" ] && c=$((c+1)); done
  [ "$c" -gt 1 ] && dupes="$dupes $n"
done
[ -z "$dupes" ] && ok "no script is declared in two channels" \
                || bad "declared in more than one channel:$dupes"

# Retirement must propagate to the roster. VERB-DISTRIBUTION.md 6 records the
# identical bug inside cut-verb-build.sh: a project that CHANGED was handled,
# a project that LEFT was not, so every consumer kept installing a verb the
# manifest no longer named. A roster naming a deleted file is that shape.
ghosts=""
for n in $ALL; do [ -f "$REPO/bin/$n" ] || ghosts="$ghosts $n"; done
[ -z "$ghosts" ] && ok "the roster names no script that has been deleted" \
                 || bad "roster names files that no longer exist:$ghosts"

# The bootstrap is the set that is COPIED onto every consumer. Copies rot; the
# only thing that makes a copy acceptable is that it is small and near-
# immutable. Bound it, or "just add it to the bootstrap" becomes the path of
# least resistance and the copy set becomes the toolset again.
n_boot=$(echo $PROP_BOOTSTRAP_SCRIPTS | wc -w)
if [ "$n_boot" -le 4 ]; then
  ok "bootstrap is $n_boot script(s), within the declared bound of 4"
else
  bad "bootstrap has grown to $n_boot scripts. Every one is COPIED into every"
  echo "       account and rots there. Move work into the payload, or raise this"
  echo "       bound HERE, deliberately, in a commit that says why."
fi

# ===========================================================================
echo
echo "-- 2. main IS NOT A DEPLOY REF, AND THE LEAK MAY NOT GROW --------------"
# ===========================================================================
# The prize in separating dev from prod is that `main` gets to STAY FAST. If
# four live accounts pull `main` on a tick, every commit is a deployment and
# `main` must turn conservative to protect them -- backwards for a repo whose
# value is iteration speed.
#
# realisateur's bashified branch declares three verbs. Ten payload-class
# scripts reach accounts as shims that exec into the realisateur CLONE
# instead. That is `main` deploying through the back door, and it is measured
# debt, not an accepted design.
n_leak=$(echo $PROP_PAYLOAD_PENDING | wc -w)
if [ "$n_leak" -le "$PROP_LEAK_BOUND" ]; then
  ok "clone-backed payload leak is $n_leak, within the bound of $PROP_LEAK_BOUND"
else
  bad "the clone-backed leak GREW to $n_leak (bound $PROP_LEAK_BOUND)."
  echo "       Each of these is a command whose live version comes from a git clone"
  echo "       of main, not from a named build. Fix by adding bin/<n> + man/<n>.1"
  echo "       to a bashified branch -- never by raising this bound."
fi
# The bound is a RATCHET: lowering it is the intended direction, so the test
# also insists the bound tracks reality rather than drifting above it.
if [ "$PROP_LEAK_BOUND" -le 10 ]; then
  ok "the leak bound has not been raised above its 2026-08-07 measurement (10)"
else
  bad "PROP_LEAK_BOUND was raised to $PROP_LEAK_BOUND. This bound only goes down."
fi

# No payload-class script may also be bootstrap. That would be the exact move
# that dissolves the split: "it is easier to copy it than to make it a verb".
for n in $PROP_PAYLOAD_SCRIPTS; do
  for m in $PROP_BOOTSTRAP_SCRIPTS; do
    [ "$n" = "$m" ] && bad "$n is both payload and bootstrap -- the split is dissolving"
  done
done
ok "no payload script has been reclassified into the bootstrap"

# ===========================================================================
echo
echo "-- 3. A CHANNEL WITH NO CLOCK IS NOT A CHANNEL -------------------------"
# ===========================================================================
# Each declared channel names the mechanism that ticks it, and that mechanism
# must exist. This assertion would have been RED on 2026-08-06, when the
# release channel's only consumer-side cadence was a human remembering.
for pair in "release-payload:$REPO/bin/selfdev-release-tick.sh" \
            "release-fetch:$REPO/bin/install-verb-build.sh" \
            "release-cut:$REPO/bin/cut-verb-build.sh"
do
  ch="${pair%%:*}"; mech="${pair#*:}"
  [ -x "$mech" ] && ok "channel '$ch' has a mechanism: $(basename "$mech")" \
                 || bad "channel '$ch' names $mech, which does not exist"
done

CH="$T/cronhome"; mkdir -p "$CH"
O="$(HOME="$CH" TICK_STATE="$CH/state" "$TICK" --install-cadence 2>&1)"; R=$?
has "--install-cadence prints a cron line" "$O" "* * * "
has "the cron line runs --apply, not --check" "$O" "--apply"
has "the cron line is tagged for attribution" "$O" "realisateur:selfdev-release:TICK"
has "--install-cadence without --apply installs nothing" "$O" "not installed (--check)"
rc "--install-cadence --check exits 0 (it reported, it did not fail)" 0 "$R"

# ===========================================================================
echo
echo "-- 4. A STOPPED CLOCK IS A FINDING -------------------------------------"
# ===========================================================================
# The property land-selfdev.sh:175 never had: it could go un-run forever and
# nothing anywhere was observably worse off.

# A fake installer, so the clock rows can be graded with no network at all.
mkinst() { # mkinst <path> <exit-code> <stdout>
  cat > "$1" <<EOF
#!/usr/bin/env bash
echo "$3"
exit $2
EOF
  chmod +x "$1"
}
INST_CURRENT="$T/inst-current.sh"; mkinst "$INST_CURRENT" 0 "verbs: up to date (build 2026-08-07T040739Z)"
INST_NEWER="$T/inst-newer.sh";     mkinst "$INST_NEWER"   1 "verbs: a newer build is available"
INST_BLIND="$T/inst-blind.sh";     mkinst "$INST_BLIND"   3 "install-verb-build.sh: BLIND -- cannot fetch"

mkdir -p "$T/s_fresh" "$T/s_old" "$T/s_none"
printf '2026-08-07T12:00:00Z rc=0 pin=2026-08-07T040739Z 2 ok\n' > "$T/s_fresh/selfdev-release-tick.status"
printf '2026-07-01T12:00:00Z rc=0 pin=old 2 ok\n' > "$T/s_old/selfdev-release-tick.status"
touch -d '40 hours ago' "$T/s_old/selfdev-release-tick.status"

tick() { # tick <state-dir> <installer> [args...]
  local s="$1" i="$2"; shift 2
  HOME="$T/emptyhome" TICK_STATE="$s" TICK_INSTALLER="$i" \
    VERB_BUILD_ROOT="$T/emptyhome/.local/share/verb-builds" \
    "$TICK" "$@" 2>&1
}
mkdir -p "$T/emptyhome"

O="$(tick "$T/s_none" "$INST_CURRENT")"
has "an account that has NEVER ticked is a gap, by name" "$O" "NO CLOCK"
has "the no-clock row prints the command that installs one" "$O" "--install-cadence --apply"

O="$(tick "$T/s_old" "$INST_CURRENT")"; R=$?
has "a tick that stopped 40h ago is reported CLOCK DEAD" "$O" "CLOCK DEAD"
has "the dead-clock row states the limit it breached" "$O" "limit 26h"
has "the dead-clock row says nothing else would have noticed" "$O" "nothing else would have said so"
rc "a dead clock exits 1, not 0" 1 "$R"

O="$(tick "$T/s_fresh" "$INST_CURRENT")"; R=$?
has "a tick within the window is ok" "$O" "clock alive"
rc "current pin + live clock exits 0" 0 "$R"

# Offline: the whole clock grading must survive with ssh and sudo absent.
O="$(PATH="/usr/bin:/bin" tick "$T/s_old" "$INST_CURRENT")"
has "clock grading works with ssh and sudo unavailable" "$O" "CLOCK DEAD"

# ===========================================================================
echo
echo "-- 5. PULL, NOT PUSH ---------------------------------------------------"
# ===========================================================================
# Push needs a human holding the right credential, does not scale past four
# accounts, and leaves no trace on the consumer side. The account must own its
# clock. Asserted against the source, because this is exactly the property
# that erodes the first time reaching in is more convenient.

# Everything from the first line to the --survey function is the tick's own
# path. --survey is the one read-only operator view and is allowed ssh.
APPLY_PATH="$(sed -n '1,/^run_survey()/p' "$TICK")"
hasnt "the tick's own path contains no 'sudo -u'" "$APPLY_PATH" "sudo -u "
hasnt "the tick's own path contains no ssh" "$APPLY_PATH" "ssh -o"

# The cron line goes in the invoking account's OWN crontab -- `crontab -`, not
# `sudo -u <acct> crontab`.
CADENCE_FN="$(sed -n '/^install_cadence()/,/^}/p' "$TICK")"
has "the cadence is written to the invoking account's own crontab" "$CADENCE_FN" "crontab -"
hasnt "the cadence is not written into another account's crontab" "$CADENCE_FN" "sudo"
has "the cadence is verified by re-reading crontab -l, not by the write's rc" "$CADENCE_FN" "crontab -l"

# --survey may read, but must not adopt or write.
SURVEY_FN="$(sed -n '/^run_survey()/,/^}/p' "$TICK")"
hasnt "--survey never adopts a build" "$SURVEY_FN" "--apply"
hasnt "--survey never repoints a symlink" "$SURVEY_FN" "ln -s"

# ===========================================================================
echo
echo "-- 5b. THE SWITCH IS DELEGATED, NEVER REIMPLEMENTED --------------------"
# ===========================================================================
# install-verb-build.sh verifies every verb the manifest promises and discards
# an incomplete build rather than switching to it -- 17 hermetic cases already
# cover that. A second implementation of the atomic switch would be a second
# answer to "which build am I on", and hand-rewriting a tested atomic switch
# is how the 2026-07-29 total dispatch outage happened.
TICK_SRC="$(cat "$TICK")"
hasnt "the tick contains no symlink switching of its own" "$TICK_SRC" "ln -sfn"
hasnt "the tick contains no atomic-rename of its own" "$TICK_SRC" "mv -Tf"
has "the tick delegates adoption to install-verb-build.sh" "$TICK_SRC" '"$inst" --latest --apply'

# ===========================================================================
echo
echo "-- 5c. FAIL-OPEN ON OPERATION, FAIL-CLOSED ON ADOPTION -----------------"
# ===========================================================================
# An unreachable release channel must not stop the account. It keeps running
# the build it already has -- fully verified when installed -- and says BLIND
# loudly. BUILD-DISCIPLINE's rule is "fail LOUD", not "fail STOPPED": halting
# a nightly tick on a network blip is just a different silent failure.

mkdir -p "$T/pinned/.local/share/verb-builds/2026-08-06T043915Z"
ln -sfn "$T/pinned/.local/share/verb-builds/2026-08-06T043915Z" \
        "$T/pinned/.local/share/verb-builds/current"
PIN_BEFORE="$(readlink "$T/pinned/.local/share/verb-builds/current")"

O="$(HOME="$T/pinned" TICK_STATE="$T/s_fresh" TICK_INSTALLER="$INST_BLIND" \
     VERB_BUILD_ROOT="$T/pinned/.local/share/verb-builds" "$TICK" --check 2>&1)"; R=$?
rc "an unreachable release channel exits 3 BLIND, not 0 and not 1" 3 "$R"
has "BLIND says it is not 'up to date'" "$O" "not 'up to date'"
has "BLIND names the fail-open choice explicitly" "$O" "fail-open on operation"
PIN_AFTER="$(readlink "$T/pinned/.local/share/verb-builds/current")"
[ "$PIN_BEFORE" = "$PIN_AFTER" ] \
  && ok "a BLIND channel left the account's pin exactly where it was" \
  || bad "a BLIND channel changed the pin ($PIN_BEFORE -> $PIN_AFTER)"

# BLIND must outrank "a newer build exists". Reporting "could not look" with
# the same code as "looked, and you are behind" is the whole garde failure.
O="$(HOME="$T/pinned" TICK_STATE="$T/s_fresh" TICK_INSTALLER="$INST_NEWER" \
     VERB_BUILD_ROOT="$T/pinned/.local/share/verb-builds" "$TICK" --check 2>&1)"; R=$?
rc "a reachable channel with a newer build exits 1" 1 "$R"
has "the newer-build row names this account's pin" "$O" "a newer build exists"

# Fail-CLOSED on adoption: a refused install must leave the pin alone and say
# the account is still in a known state.
INST_REFUSE="$T/inst-refuse.sh"
cat > "$INST_REFUSE" <<'EOF'
#!/usr/bin/env bash
case " $* " in
  *" --check "*) echo "verbs: a newer build is available"; exit 1 ;;
esac
echo "install-verb-build.sh: build is INCOMPLETE (3 missing verbs). Discarded, and current is unchanged." >&2
exit 1
EOF
chmod +x "$INST_REFUSE"
O="$(HOME="$T/pinned" TICK_STATE="$T/s_apply" TICK_INSTALLER="$INST_REFUSE" \
     VERB_BUILD_ROOT="$T/pinned/.local/share/verb-builds" "$TICK" --apply 2>&1)"; R=$?
has "a refused adoption is reported as refused, not as done" "$O" "adoption refused"
has "a refused adoption names the state the account is left in" "$O" "known verified state"
PIN_AFTER="$(readlink "$T/pinned/.local/share/verb-builds/current")"
[ "$PIN_BEFORE" = "$PIN_AFTER" ] \
  && ok "a refused adoption left the pin untouched (fail-closed)" \
  || bad "a refused adoption moved the pin ($PIN_BEFORE -> $PIN_AFTER)"
[ -f "$T/s_apply/selfdev-release-tick.status" ] \
  && ok "--apply recorded itself, so the next --check can grade the clock" \
  || bad "--apply wrote no status file; the clock cannot be graded"

# ===========================================================================
echo
echo "-- 5d. BLIND MUST ARRIVE IN TIME TO BE A VERDICT -----------------------"
# ===========================================================================
# realisateur#54. install-verb-build.sh reached the right verdict against an
# unroutable host and took 2m15s to do it (measured 2026-08-07 against
# 192.0.2.1, TEST-NET-1) -- the kernel's TCP retry, unbounded. A human hits
# Ctrl-C; a nightly cron tick does not, so the fail-open design above quietly
# became "stall for two minutes every night, in the dark".
#
# Asserted with a 1-second bound so the suite stays fast and offline. What is
# being tested is that the bound EXISTS and is honoured, not the wall time.
INST="$REPO/bin/install-verb-build.sh"
t0=$(date +%s)
O="$(VERB_BUILD_ROOT="$T/blindroot" VERB_BUILD_NET_TIMEOUT=1 \
     "$INST" --check --remote https://192.0.2.1/verbs.git 2>&1)"; R=$?
t1=$(date +%s)
rc "an unroutable remote reaches BLIND (exit 3), not a hang" 3 "$R"
has "BLIND names the bound it hit" "$O" "within 1s"
if [ $((t1 - t0)) -le 10 ]; then
  ok "BLIND arrived in $((t1-t0))s -- the network reach is bounded, not left to TCP retry"
else
  bad "BLIND took $((t1-t0))s despite a 1s bound; the timeout is not on the reach"
fi
has "the fetch bound is configurable rather than hardcoded" "$(cat "$INST")" "VERB_BUILD_NET_TIMEOUT"
has "a credential prompt cannot be the second way to hang" "$(cat "$INST")" "GIT_TERMINAL_PROMPT=0"

# ===========================================================================
echo
echo "-- 6. FOUND NOTHING IS NOT NOTHING IS WRONG ----------------------------"
# ===========================================================================
# A consumer that cannot even find its bootstrap must not report "up to date".
O="$(HOME="$T/nobootstrap" TICK_STATE="$T/s_fresh" TICK_INSTALLER="$T/does-not-exist" \
     VERB_BUILD_ROOT="$T/nobootstrap/verb-builds" "$TICK" --check 2>&1)"; R=$?
has "a missing installer is BOOTSTRAP INCOMPLETE, by name" "$O" "BOOTSTRAP INCOMPLETE"
has "it says the account cannot obtain a build at all" "$O" "cannot obtain a build at all"
rc "a missing bootstrap exits non-zero" 1 "$R"

O="$(TICK_SURVEY_HOST="no-such-host.invalid" TICK_STATE="$T/s_fresh" \
     HOME="$T/emptyhome" "$TICK" --survey 2>&1)"; R=$?
rc "an unreachable survey host exits 3 BLIND, not 0" 3 "$R"
has "the unreachable survey says nothing was verified" "$O" "Nothing was verified"

# ===========================================================================
echo
echo "-- 7. THE ARGUMENT CONTRACT --------------------------------------------"
# ===========================================================================
"$TICK" --not-a-real-flag >/dev/null 2>&1; rc "unknown flag exits 2" 2 $?
"$TICK" --help >/dev/null 2>&1;            rc "--help exits 0" 0 $?
O="$("$TICK" --help 2>&1)"
has "--help documents the BLIND exit" "$O" "BLIND"
has "--help says --check is the default and writes nothing" "$O" "--check (default)"

echo
echo "propagation.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
