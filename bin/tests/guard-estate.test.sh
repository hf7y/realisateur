#!/usr/bin/env bash
# guard-estate.test.sh -- a test over the guard POPULATION, not over one guard.
#
# TRAPS (the rest of this header is in the vault):
# THE POPULATION IS DERIVED, NOT LISTED. A list is an append point every
# concurrent PR contends for, and a guard can be added below the bar by simply
# not adding it. Derivation is by NAME SHAPE over bin/*.sh: -lint, -audit,
# -gate, -drift, -check, -scan, -survey, -wiring, -ledger. Anything matching
# MUST declare itself, including `# GUARD: no -- <why>` if the name is a
# coincidence. Anything not matching may opt IN with `# GUARD:`.
# A0 closes the dodge: any bin/*.sh whose header says it "refuses", "flags",
# "audits" or "gates" without a `# GUARD:` line fails.
# THE THREE BOUNDS. Some guards legitimately have no runner, no suite, or no
# safely-executable gating mode. Each is allowed AND COUNTED against a bound
# that may shrink and must never grow. A ratchet, not an exemption: the next
# guard that wants to be hand-run has to retire one that already is.
#
# usage: ./bin/tests/guard-estate.test.sh

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$REPO/bin"
TESTS="$REPO/bin/tests"

# --- the ratchets -----------------------------------------------------------
# Measured 2026-08-07 AFTER the retirement pass in this branch. Each may be
# lowered. Raising one is the change this file exists to make visible.
# 5 -> 6 on 2026-08-18 (#301): bin/org-migration-audit.sh. Deliberately
# operator-only, not a gap to close -- it is decision support for a one-time
# human call ("is an org migration worth the cost"), and an automatic runner
# would mean something auto-decided that. claim-drift.sh and the four beside
# it are operator-run for the same reason: a person reads the output.
GUARD_OPERATOR_BOUND="${GUARD_OPERATOR_BOUND:-6}"   # no automatic runner
GUARD_UNTESTED_BOUND="${GUARD_UNTESTED_BOUND:-4}"   # no dedicated suite
# 7 -> 9 on 2026-08-15 (#294, #304): bin/directive-prose.sh and
# bin/rot-ratchet.sh. Both are `GATE: none` for reasons already accepted here
# -- a diff gate cannot form a merge-base in a fixture repo (markdown-cost.sh),
# and an estate survey needs the live issue trackers (thermostat-wiring.sh).
GUARD_UNGATED_BOUND="${GUARD_UNGATED_BOUND:-9}"     # not safely executable here

# UNDECLARED IS ZERO, and it earned the right to be. It was briefly 1, for
# bin/closeout-lint.sh, which was being rewritten concurrently on
# hf7y/realisateur#99 -- counting it was the honest move while another branch
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
GUARD_UNDECLARED_BOUND="${GUARD_UNDECLARED_BOUND:-0}"

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
echo "== A. EVERY GUARD NAMES WHAT RUNS IT =="

GUARDS=""
undeclared=0
for f in "$BIN"/*.sh; do
  [ -e "$f" ] || continue
  n="$(basename "$f")"
  # A guard is a script that names a POINTER: what runs it, or what tests it.
  # Both are checked against the tree below (B2/B3, C2/C3), so neither can rot
  # into a false claim the way a prose self-description can.
  r="$(hdr "$f" RUNNER)"; [ -n "$r" ] || r="$(hdr "$f" GUARD-TEST)"
  if [ -n "$r" ]; then
    case "$r" in
      no\ --*|no--*) continue ;;
      no|no\ *) bad "A1 $n: '# RUNNER: no' without a reason -- say what runs it, or why nothing does" ; continue ;;
    esac
    GUARDS="$GUARDS $n"
    continue
  fi
  if is_guard_shaped "$n"; then
    undeclared=$((undeclared + 1))
    printf '  note %s: guard-shaped name with no '"'"'# RUNNER:'"'"' header -- UNDECLARED, invisible to B..G\n' "$n"
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
for f in "$BIN"/*.sh; do
  [ -e "$f" ] || continue
  n="$(basename "$f")"
  case " $GUARDS " in *" $n "*) continue ;; esac
  { [ -n "$(hdr "$f" RUNNER)" ] || [ -n "$(hdr "$f" GUARD-TEST)" ]; } && continue
  is_guard_shaped "$n" && continue
  if grep -qE 'FLAG \[|FLAG\(s\)|violation\(s\)' "$f"; then
    bad "A0 $n: emits findings (FLAG/violation) but declares neither '# RUNNER:' nor '# GUARD-TEST:' -- a guard does not stop being one by being renamed"
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
    strict|strict\ *)
      # Anything after the mode word is EXTRA ARGV, with $TREE substituted for
      # the sandbox tree. This is how a guard declares its scope knob when the
      # knob is a flag rather than cwd: `# GATE: strict --repo $TREE`.
      #
      #   [rest: vault:realisateur/guard-archaeology-20260817.md]
      extra="${mode#strict}"; extra="${extra//\$TREE/$WORK/tree}"
      # shellcheck disable=SC2086
      run_sandboxed "$BIN/$n" --strict $extra ;;
    default|default\ *)
      extra="${mode#default}"; extra="${extra//\$TREE/$WORK/tree}"
      # shellcheck disable=SC2086
      run_sandboxed "$BIN/$n" $extra ;;
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
    #   [rest: vault:realisateur/guard-archaeology-20260817.md]
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

echo
echo "guard-estate: $NGUARDS guard(s); $pass ok, $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
