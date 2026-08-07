#!/usr/bin/env bash
# guard-estate.test.sh -- a test over the guard POPULATION, not over one guard.
#
# HERMETICITY: it never runs a guard against live state. Every executed check
# builds a throwaway git repo under mktemp, sets HOME, SCHED_ROOT, XDG_*,
# GH_TOKEN='' and cwd into it, and puts a stub `gh`/`ssh` ahead of the real
# ones on PATH, so a guard that reaches the network or the estate gets a
# deterministic refusal rather than whatever this machine happens to have.
# The only live thing it reads is this repository's own bin/ and bin/tests/,
# which is the branch under test, not the shared checkout.
#
# ============================================================================
# WHY A TEST OVER THE ESTATE AND NOT OVER A GUARD
# ============================================================================
#
# Every guard here already gets argued about one at a time, and one at a time
# the argument is always winnable: this one is hand-run but useful, that one
# exits 0 but the header explains why, this other one reads the live checkout
# but only because it is a survey. Each excuse is locally reasonable. The
# population is what got bad.
#
# MEASURED 2026-08-07, before this file existed, over the 16 guard-shaped
# scripts in bin/:
#
#   closeout-lint      12 branches reported as unmerged work at risk.
#                      ALL TWELVE had been merged weeks earlier -- squash-merge
#                      makes "is this commit reachable from a remote ref?"
#                      permanently unanswerable, so it gained one false alarm
#                      per merged PR forever. The same run printed
#                      "BLIND [worktrees] 13 linked worktree(s) NOT examined"
#                      -- one quiet line above twelve loud wrong ones.
#   hardcoded-home-lint  reported "no hardcoded home in code" while
#                      bashify/bin/bashify carried /home/<name>/... Its
#                      selector could not see extensionless executables. It
#                      had no test and no runner.
#   install-shims.test  passed for months by auditing the live shared checkout
#   verb-set.test      instead of the branch under test. Same for verb-set.
#   silence-audit      74 FLAGs, exit 0, pointed at an EMPTY temp repo -- it
#                      audited ~zach regardless of where it was pointed. Four
#                      of those FLAGs are its own source scanned by itself.
#                      CLAUDE.md's checklist has required it clean since it
#                      was written; it has never once been passable.
#   hygiene-lint       110 FLAGs across 13 projects, exit 0, from inside an
#                      empty temp repo.
#
# The through-line is one sentence: A GUARD THAT IS WRONG OFTEN ENOUGH TRAINS
# PEOPLE TO IGNORE IT, AND THEN A TRUE FINDING IS IGNORED TOO. Three suites
# sat red on main for weeks, documented so thoroughly in a header that they
# became furniture, and then blocked four PRs in one afternoon.
#
# So the bar cannot live in a document that each new guard's author is
# expected to have read. It has to FAIL when a guard is added below it. That
# is the only difference between this file and a paragraph in CONTRIBUTING.
#
# ============================================================================
# HOW THE POPULATION IS DERIVED -- and why not from a list
# ============================================================================
#
# Not from a list in this file. A list is an append point every concurrent PR
# must contend for (bin/suite-docs-lint.sh has the numbers: three conflict
# events in one day, all in one region of one file), and worse, a guard can be
# added below the bar simply by not adding it to the list -- which is the
# omission this whole file exists to make impossible.
#
# Derivation is by NAME SHAPE over bin/*.sh: -lint, -audit, -gate, -drift,
# -check, -scan, -survey, -wiring, -ledger. Anything matching MUST declare
# itself, including declaring `# GUARD: no -- <why>` if the name is a
# coincidence (install-silence-audit.sh installs one, it is not one). Anything
# NOT matching may opt IN by declaring `# GUARD:` -- markdown-cost.sh does.
#
# The dodge this closes: naming a new guard `bin/verify-things.sh` to escape
# the shape. It does not escape -- check A0 fails any bin/*.sh whose header
# says it "refuses", "flags", "audits" or "gates" without a `# GUARD:` line.
#
# ============================================================================
# THE FIVE PROPERTIES, and the specific past failure each one would have caught
# ============================================================================
#
#  A DECLARED         every guard-shaped script declares what question it
#                     answers. hardcoded-home-lint shipped with no runner and
#                     no test because nothing ever asked it to say so.
#  B RUNNER IS REAL   the runner it names must EXIST and must actually mention
#                     it. A guard nothing runs is documentation with an exit
#                     code; six of these were hand-run only.
#  C TEST IS REAL     the suite it names must exist and must mention it.
#                     silence-audit is named in CLAUDE.md's mandatory
#                     checklist and has never had a test.
#  D EXIT TRACKS      in the mode declared as gating, findings > 0 MUST mean
#    FINDINGS         rc != 0, and rc == 0 MUST mean no findings printed.
#                     This is the one Zach prioritised. silence-audit printing
#                     74 FLAGs and exiting 0 is the archetype; a guard whose
#                     exit code does not track its findings cannot gate
#                     anything, and every CI job that "ran" it proved nothing.
#  E BLIND != CLEAN   an admission of not-looking must not grade as clean, and
#                     must be printed before the findings. closeout-lint put
#                     "13 worktrees NOT examined" one line above twelve false
#                     alarms and exited 0. Its own noise buried its own
#                     admission.
#  F TREE-HONOURING   pointed at a temp tree, a guard must not report on the
#                     live checkout. This is the most common bug class in the
#                     estate right now: 9 of 11 guards probed on 2026-08-07
#                     ignored where they were pointed.
#  G FRESHNESS        see THE METABOLISM below.
#
# ============================================================================
# THE METABOLISM -- why the estate gets repainted instead of accumulating
# ============================================================================
#
# Zach, 2026-08-07: "a general metabolism where things are remade on a rhythm,
# like a bridge that gets repainted from end to end every season."
#
# A calendar reminder cannot do this and a documented ritual has already
# failed here repeatedly, so the rhythm is two assertions in check G, run by
# CI on every pull request:
#
#   RHYTHM      the NEWEST `# VERIFIED:` stamp in the estate must be no more
#               than GUARD_RHYTHM_DAYS old. If nobody has re-verified ANY
#               guard in that window, CI goes red -- on whatever PR is open at
#               the time, which is the point. Repainting is not something you
#               remember to do; it is something the build stops for.
#
#   SPAN        no single guard's stamp may be older than GUARD_SPAN_DAYS.
#               Without this you could satisfy RHYTHM forever by repainting
#               the same easy plank. This is what forces the painters to reach
#               the far end of the bridge.
#
# Why this pair and not "every guard must be stamped within N days": because
# that produces a BURST. Stamp twenty guards today and in N days all twenty
# expire at once, CI is red until someone re-verifies twenty things in an
# afternoon, and what actually happens is that the window gets widened or the
# check gets deleted. RHYTHM+SPAN has no burst: one repaint satisfies RHYTHM,
# and SPAN comes due one guard at a time in the order they were last touched.
#
# A stamp is `# VERIFIED: YYYY-MM-DD via <command>` -- the same shape
# CLAUDE.md already requires for claims about system state, now machine-read.
# The `via <command>` half is not decoration: re-stamping is meant to cost a
# re-probe. A stamp with no command is refused.
#
# WHAT REPAINTING MEANS is deliberately not defined here, because a definition
# would be prose and would decay. The mechanism only forces the guard to be
# opened, re-run, and either re-stamped or retired. Most repaints will end in
# retirement, which is the intended bias: this estate's failure mode is
# accumulation, not scarcity.
#
# ============================================================================
# THE THREE BOUNDS
# ============================================================================
#
# Some guards legitimately have no automatic runner, no dedicated suite, or no
# safely-executable gating mode. Pretending otherwise would just produce
# fictional declarations. So each is allowed AND COUNTED, against a bound that
# may shrink and must never grow -- the PROP_LEAK_BOUND idiom already used by
# bin/lib/propagation-set.sh. A ratchet, not an exemption: the next guard that
# wants to be hand-run only has to retire one that already is.
#
# usage: ./bin/tests/guard-estate.test.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$REPO/bin"
TESTS="$REPO/bin/tests"

# --- the ratchets -----------------------------------------------------------
# Measured 2026-08-07 AFTER the retirement pass in this branch. Each may be
# lowered. Raising one is the change this file exists to make visible.
GUARD_OPERATOR_BOUND="${GUARD_OPERATOR_BOUND:-5}"   # no automatic runner
GUARD_UNTESTED_BOUND="${GUARD_UNTESTED_BOUND:-4}"   # no dedicated suite
GUARD_UNGATED_BOUND="${GUARD_UNGATED_BOUND:-7}"     # not safely executable here

# UNDECLARED is a bound and not zero for exactly one reason, which will expire.
# bin/closeout-lint.sh is being rewritten concurrently on
# hf7y/realisateur#99 (squash-merge false alarms, worktree blindness). Adding a
# header to it from this branch would collide with that rewrite, so it is
# counted instead of edited. When #99 lands, give closeout-lint.sh its five
# declarations and set this to 0. It exists to make that a visible debt rather
# than a silent omission -- an undeclared guard is invisible to checks B..G.
GUARD_UNDECLARED_BOUND="${GUARD_UNDECLARED_BOUND:-1}"

# --- the metabolism ---------------------------------------------------------
GUARD_RHYTHM_DAYS="${GUARD_RHYTHM_DAYS:-30}"
GUARD_SPAN_DAYS="${GUARD_SPAN_DAYS:-365}"

pass=0; fail=0
ok()  { printf '  ok   %s\n' "$*"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }

# How far into a file a declaration may be. Same reasoning as
# suite-docs-lint.sh: it is a HEADER contract; a reader must meet it before
# the code.
HEAD_LINES=90

hdr() { head -n "$HEAD_LINES" "$1" | sed -n "s/^#[[:space:]]*$2:[[:space:]]*//p" | head -1; }

# Name shapes that make a script a guard whether or not it says so.
is_guard_shaped() {
  case "$1" in
    *-lint.sh|*-audit.sh|*-gate.sh|*-drift.sh|*-check.sh|*-scan.sh|*-survey.sh|*-wiring.sh|*-ledger.sh) return 0 ;;
  esac
  return 1
}

# ============================================================================
# A. DECLARED
# ============================================================================
echo "== A. EVERY GUARD DECLARES ITSELF =="

GUARDS=""
undeclared=0
for f in "$BIN"/*.sh; do
  [ -e "$f" ] || continue
  n="$(basename "$f")"
  g="$(hdr "$f" GUARD)"
  if [ -n "$g" ]; then
    case "$g" in
      no\ --*|no--*)
        # An explicit opt-out with a reason. install-silence-audit.sh is not a
        # guard; it installs one.
        continue ;;
      no|no\ *)
        bad "A1 $n: '# GUARD: no' without a reason -- say why the name is not a guard"
        continue ;;
    esac
    GUARDS="$GUARDS $n"
    continue
  fi
  if is_guard_shaped "$n"; then
    undeclared=$((undeclared + 1))
    printf '  note %s: guard-shaped name with no '"'"'# GUARD:'"'"' header -- UNDECLARED, invisible to B..G\n' "$n"
  fi
done
if [ "$undeclared" -gt "$GUARD_UNDECLARED_BOUND" ]; then
  bad "A1 $undeclared undeclared guard-shaped script(s); bound is $GUARD_UNDECLARED_BOUND"
else
  ok "A1 undeclared guards: $undeclared <= $GUARD_UNDECLARED_BOUND"
fi

# A0 -- the rename dodge, closed BEHAVIOURALLY rather than by prose.
#
# The first draft of this check read the header for words like "refuses" and
# "gates on". It flagged ten installers and provisioners, every one of them a
# false positive -- which is the exact failure this whole file is about,
# reproduced inside the file itself within an hour of writing it. Deleted.
#
# What replaces it is the guard's OUTPUT VOCABULARY, taken from the body, not
# the prose: a script that emits `FLAG [`, `N FLAG(s)` or `violation(s)` is
# reporting findings to a reader, whatever it is called. Measured over bin/ on
# 2026-08-07 this matches five files, four of which are already guard-shaped;
# the fifth is markdown-cost.sh, which is a guard with a non-guard name. Zero
# false positives.
for f in "$BIN"/*.sh; do
  [ -e "$f" ] || continue
  n="$(basename "$f")"
  case " $GUARDS " in *" $n "*) continue ;; esac
  [ -n "$(hdr "$f" GUARD)" ] && continue
  is_guard_shaped "$n" && continue
  if grep -qE 'FLAG \[|FLAG\(s\)|violation\(s\)' "$f"; then
    bad "A0 $n: emits findings (FLAG/violation) but declares no '# GUARD:' line -- a guard does not stop being one by being renamed"
  fi
done

set -- $GUARDS
NGUARDS=$#
if [ "$NGUARDS" -eq 0 ]; then
  echo "guard-estate: BLIND: derived zero guards -- this run tested NOTHING." >&2
  exit 2
fi
ok "A2 population derived: $NGUARDS guard(s)"

# ============================================================================
# B. RUNNER IS REAL
# ============================================================================
echo
echo "== B. THE RUNNER IT NAMES EXISTS AND ACTUALLY NAMES IT BACK =="
operator=0
for n in $GUARDS; do
  r="$(hdr "$BIN/$n" RUNNER)"
  base="${n%.sh}"
  case "$r" in
    "")            bad "B1 $n: no '# RUNNER:' line" ;;
    operator\ --*) operator=$((operator + 1)); ok "B1 $n: operator-run (counted)" ;;
    operator*)     bad "B1 $n: '# RUNNER: operator' with no reason" ;;
    *)
      # May name several paths, space-separated.
      for p in $r; do
        case "$p" in --*|\(*) break ;; esac
        if [ ! -e "$REPO/$p" ]; then
          bad "B2 $n: names runner '$p', which does not exist in this tree"
        elif ! grep -q "$base" "$REPO/$p"; then
          bad "B3 $n: '$p' exists but never mentions '$base' -- the runner does not run it"
        else
          ok "B1 $n: run by $p"
        fi
      done ;;
  esac
done
if [ "$operator" -gt "$GUARD_OPERATOR_BOUND" ]; then
  bad "B4 $operator guard(s) have no automatic runner; bound is $GUARD_OPERATOR_BOUND. A guard nothing runs is documentation. Retire one before adding one."
else
  ok "B4 operator-run guards: $operator <= $GUARD_OPERATOR_BOUND"
fi

# ============================================================================
# C. TEST IS REAL
# ============================================================================
echo
echo "== C. THE SUITE IT NAMES EXISTS AND ACTUALLY NAMES IT BACK =="
untested=0
for n in $GUARDS; do
  t="$(hdr "$BIN/$n" GUARD-TEST)"
  base="${n%.sh}"
  case "$t" in
    "")        bad "C1 $n: no '# GUARD-TEST:' line" ;;
    none\ --*) untested=$((untested + 1)); ok "C1 $n: untested (counted)" ;;
    none*)     bad "C1 $n: '# GUARD-TEST: none' with no reason" ;;
    *)
      p="${t%% *}"
      if [ ! -e "$REPO/$p" ]; then
        bad "C2 $n: names suite '$p', which does not exist"
      elif ! grep -q "$base" "$REPO/$p"; then
        bad "C3 $n: '$p' exists but never mentions '$base'"
      else
        ok "C1 $n: covered by $p"
      fi ;;
  esac
done
if [ "$untested" -gt "$GUARD_UNTESTED_BOUND" ]; then
  bad "C4 $untested guard(s) have no suite; bound is $GUARD_UNTESTED_BOUND"
else
  ok "C4 untested guards: $untested <= $GUARD_UNTESTED_BOUND"
fi

# ============================================================================
# D/E/F. THE EXECUTED CHECKS
# ============================================================================
#
# One hermetic sandbox, reused. HOME, cwd, SCHED_ROOT and XDG_DATA_HOME all
# point inside it; `gh` and `ssh` are stubs that fail loudly; PATH does not
# include this repo. A guard run here can see NOTHING it is supposed to
# report on -- so every finding it prints about the live estate is proof it
# went and read the live estate instead of the tree it was given.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home" "$WORK/tree" "$WORK/stub" "$WORK/sched/schedule"
printf '#!/bin/sh\necho "stub gh: no credential in this sandbox" >&2\nexit 1\n' > "$WORK/stub/gh"
printf '#!/bin/sh\necho "stub ssh: no network in this sandbox" >&2\nexit 255\n' > "$WORK/stub/ssh"
chmod +x "$WORK/stub/gh" "$WORK/stub/ssh"
(
  cd "$WORK/tree" || exit 1
  git init -q -b main .
  git config user.email t@t; git config user.name t
  echo "a temp tree with nothing in it to find" > README.md
  git add README.md
  git commit -qm init
) >/dev/null 2>&1

# Sets the GLOBALS `OUT` and `RC`. Deliberately not `out=$(run_sandboxed ...)`:
# command substitution runs the function in a SUBSHELL, so an rc assigned
# inside it never reaches the caller. The first draft of this file did exactly
# that and died on `RC: unbound variable` -- which is the good outcome; had RC
# merely been stale, every D assertion would have been graded against another
# guard's exit code and this file would have reported a green estate.
run_sandboxed() {
  local s="$1"; shift
  OUT="$(cd "$WORK/tree" && env -i \
      PATH="$WORK/stub:/usr/local/bin:/usr/bin:/bin" \
      HOME="$WORK/home" \
      SCHED_ROOT="$WORK/sched" \
      XDG_DATA_HOME="$WORK/home/.local/share" \
      GH_TOKEN= GITHUB_TOKEN= \
      TERM=dumb \
      timeout 60 bash "$s" "$@" 2>&1)"
  RC=$?
}

# findings_count -- read the guard's OWN self-report. Not a heuristic over
# every line: a guard's summary line is the number it is asking to be
# believed, and D is precisely the assertion that the exit code agrees with
# the number the guard itself printed.
findings_count() {
  printf '%s\n' "$1" \
    | grep -oEi '[0-9]+ (total )?(FLAG|violation|finding|unmet|drift|failure)' \
    | grep -oE '^[0-9]+' | sort -rn | head -1
}
has_blind() { printf '%s\n' "$1" | grep -qE '(^|[^A-Za-z])BLIND([^A-Za-z]|$)'; }

echo
echo "== D. EXIT CODE TRACKS FINDINGS =="
echo "== E. BLIND DOES NOT GRADE AS CLEAN, AND IS PRINTED FIRST =="
echo "== F. A GUARD HONOURS THE TREE IT IS POINTED AT =="
ungated=0
for n in $GUARDS; do
  mode="$(hdr "$BIN/$n" GATE)"
  case "$mode" in
    "")        bad "D0 $n: no '# GATE:' line -- say which invocation is the gating one" ; continue ;;
    none\ --*) ungated=$((ungated + 1)); ok "D0 $n: not executed here (counted)"; continue ;;
    none*)     bad "D0 $n: '# GATE: none' with no reason"; continue ;;
    strict)    run_sandboxed "$BIN/$n" --strict ;;
    default)   run_sandboxed "$BIN/$n" ;;
    *)         bad "D0 $n: '# GATE: $mode' is not one of default|strict|none -- <why>"; continue ;;
  esac
  rc=$RC; out="$OUT"
  cnt="$(findings_count "$out")"; cnt="${cnt:-0}"

  # D -- the priority assertion.
  if [ "$cnt" -gt 0 ] && [ "$rc" -eq 0 ]; then
    bad "D1 $n: printed $cnt finding(s) and exited 0. A guard whose exit code does not track its findings cannot gate anything."
  elif [ "$cnt" -eq 0 ] && [ "$rc" -ne 0 ] && ! has_blind "$out"; then
    # A non-zero exit with no findings and no admission of blindness is the
    # mirror image of D1: it is unreadable. A caller cannot tell a refusal
    # from a failure from a finding. (Non-zero WITH a BLIND line is correct
    # and is what E1 rewards -- silence-audit uses 3, hardcoded-home-lint 2;
    # this deliberately does not care which number, only that the output says
    # which of the three world-states it is in.)
    bad "D2 $n: exited $rc having reported neither a finding nor a BLIND"
  else
    ok "D1 $n: rc=$rc, findings=$cnt -- consistent"
  fi

  # E -- not-looking outranks nothing-found, and outranks it IN THE OUTPUT.
  if has_blind "$out"; then
    if [ "$rc" -eq 0 ]; then
      bad "E1 $n: admitted BLIND and exited 0 -- could-not-look graded as clean"
    else
      ok "E1 $n: BLIND, rc=$rc"
    fi
    # A FINDING LINE, not the word. The first draft matched `FLAG` anywhere
    # and fired on hygiene-lint's preamble sentence "Grep 'FLAG' to count" --
    # a guard-about-guards producing a false alarm about false alarms within
    # ten minutes of being written. The shape of a finding here is a leading
    # marker at the start of a line, optionally bracketed with a category.
    first_blind="$(printf '%s\n' "$out" | grep -nE '^[[:space:]]*BLIND[[:space:]:[]|: BLIND:' | head -1 | cut -d: -f1)"
    first_flag="$(printf '%s\n' "$out"  | grep -nE '^[[:space:]]*(FLAG|WARN|GAP)[[:space:]:[]' | head -1 | cut -d: -f1)"
    if [ -n "$first_flag" ] && [ -n "$first_blind" ] && [ "$first_blind" -gt "$first_flag" ]; then
      bad "E2 $n: first BLIND at line $first_blind is BELOW the first finding at line $first_flag -- the admission is buried under the noise (closeout-lint printed 13 unexamined worktrees one line above twelve false alarms)"
    fi
  fi

  # F -- the most common bug class in this estate.
  if printf '%s\n' "$out" | grep -q "$REPO"; then
    bad "F1 $n: pointed at $WORK/tree with HOME=$WORK/home, it reported on $REPO. It read the live checkout, not the tree it was given."
  elif printf '%s\n' "$out" | grep -qE '/home/[a-z][a-z0-9_-]*/Documents/Projects'; then
    bad "F1 $n: pointed at a temp tree, it reported on a path under a named user's home"
  else
    ok "F1 $n: honoured the tree it was pointed at"
  fi
done
if [ "$ungated" -gt "$GUARD_UNGATED_BOUND" ]; then
  bad "D3 $ungated guard(s) declare no executable gating mode; bound is $GUARD_UNGATED_BOUND"
else
  ok "D3 ungated guards: $ungated <= $GUARD_UNGATED_BOUND"
fi

# ============================================================================
# G. THE METABOLISM
# ============================================================================
echo
echo "== G. FRESHNESS -- RHYTHM AND SPAN =="
today_s="$(date -u +%s)"
oldest=-1; oldest_name=""
for n in $GUARDS; do
  v="$(hdr "$BIN/$n" VERIFIED)"
  case "$v" in
    "") bad "G1 $n: no '# VERIFIED: YYYY-MM-DD via <command>' stamp"; continue ;;
  esac
  d="${v%% *}"
  rest="${v#* }"
  if ! printf '%s' "$d" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    bad "G1 $n: '# VERIFIED: $v' does not start with a YYYY-MM-DD date"; continue
  fi
  case "$rest" in
    via\ ?*) : ;;
    *) bad "G2 $n: stamp names no command. 'via <command>' is what makes re-stamping cost a re-probe rather than a keystroke."; continue ;;
  esac
  s="$(date -u -d "$d" +%s 2>/dev/null)" || { bad "G1 $n: '$d' is not a date this system can read"; continue; }
  if [ "$s" -gt "$((today_s + 86400))" ]; then
    bad "G1 $n: stamped $d, which is in the future"; continue
  fi
  age=$(( (today_s - s) / 86400 ))
  if [ "$age" -gt "$oldest" ]; then oldest="$age"; oldest_name="$n"; fi
  if [ "$age" -gt "$GUARD_SPAN_DAYS" ]; then
    bad "G4 SPAN: $n was last verified $age days ago (> $GUARD_SPAN_DAYS). Re-probe it and re-stamp it, or retire it. This is the far end of the bridge."
  fi
done
# `newest` above is tracking the LARGEST age; the freshest stamp is the
# smallest one. Recompute plainly rather than being clever about it.
fresh=99999; fresh_name=""
for n in $GUARDS; do
  v="$(hdr "$BIN/$n" VERIFIED)"; d="${v%% *}"
  printf '%s' "$d" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || continue
  s="$(date -u -d "$d" +%s 2>/dev/null)" || continue
  age=$(( (today_s - s) / 86400 ))
  if [ "$age" -lt "$fresh" ]; then fresh="$age"; fresh_name="$n"; fi
done
if [ "$fresh" -eq 99999 ]; then
  bad "G3 RHYTHM: not one guard in the estate carries a readable stamp"
elif [ "$fresh" -gt "$GUARD_RHYTHM_DAYS" ]; then
  bad "G3 RHYTHM: the freshest stamp in the whole estate is $fresh days old ($fresh_name) (> $GUARD_RHYTHM_DAYS). Nothing has been repainted in that window. Pick the oldest guard, re-run it, and re-stamp or retire it."
else
  ok "G3 RHYTHM: freshest stamp is $fresh day(s) old ($fresh_name) <= $GUARD_RHYTHM_DAYS"
fi
[ -n "$oldest_name" ] && ok "G4 SPAN: oldest stamp is ${oldest} day(s) ($oldest_name) <= $GUARD_SPAN_DAYS"

echo
echo "guard-estate: $NGUARDS guard(s); $pass ok, $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
