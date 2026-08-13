#!/usr/bin/env bash
# HERMETICITY: builds a throwaway git repository per case in a temp dir and runs
# the script against a range inside it. Nothing here reads the live ecosystem,
# this checkout's own history, or origin.
#
# markdown-cost.test.sh -- witness for bin/markdown-cost.sh.
#
# Offline, zero AI, no network: every case builds its own throwaway git
# repository in a temp dir, commits fixture files into it, and runs the script
# against a range inside that repository. Nothing here reads the live
# ecosystem, this checkout's own history, or origin.
#
# THE LOAD-BEARING ASSERTIONS ARE E1..E3. A gate that exits 0 when it could not
# resolve the range is worse than no gate: it reports "found nothing" as
# "nothing is wrong", which is the exact failure bin/lib/conf.sh's header
# records (a propagation pass that reached NOBODY, printed a tidy summary, and
# exited 0). If markdown-cost.sh ever exits 0 on an unreadable range, this file
# must go red.
#
# Negative-tested against an `exit 0` stub: 19 of the 31 assertions fail as
# they should. The 12 that survive are the expect-exit-0 and `hasnt` (absence)
# assertions, which a silent stub passes vacuously -- so each of those cases
# (A, C3, C4, D1, D2, D3) is paired with a positive assertion on the same
# fixture, and no case rests on absence alone.
#
# Cases:
#   A1 a code-only diff                          -> exit 0
#   A2 ...and says so in words, with the ratio
#   B1 a prose-heavy diff (over the threshold)   -> exit 1
#   B2 ...names the ratio
#   B3 ...names the file that cost the money
#   B4 the threshold is env-overridable: the same diff under a high
#      MARKDOWN_COST_MAX_PCT passes                -> exit 0
#   B5 deleting prose is free (deletions are not priced)
#   C1 a NEW top-level *.md                      -> exit 1
#   C2 ...names it, and names the allowlist
#   C3 EDITING an existing top-level *.md is fine (same file, second commit)
#   C4 a new *.md under a directory is not a new ROOT document
#   D1 an allowlisted new root doc (CLAUDE.md)   -> exit 0
#   D2 an allowlisted file's lines are not priced as prose (README.md)
#   D3 man/ is allowlisted at any depth
#   E1 an unresolvable range                     -> exit 2, never 0
#   E2 ...and says why on stderr
#   E3 outside a git repository                  -> exit 2
#   E4 a non-numeric MARKDOWN_COST_MAX_PCT       -> exit 2
#   E5 two positional arguments                  -> exit 2
#
# Usage: bin/tests/markdown-cost.test.sh   (exit 0 = all pass)
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/markdown-cost.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()   { echo "  ok   $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL $1"; fail=$((fail+1)); }
# has <name> <output> <pattern>   -- output must contain pattern
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
# hasnt <name> <output> <pattern> -- output must NOT contain pattern
hasnt(){ case "$2" in *"$3"*) bad "$1 (unexpected: $3)" ;; *) ok "$1" ;; esac; }
# rc <name> <expected-exit> <actual-exit>
rc()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }

G() { git -c user.email=t@test -c user.name=T -C "$1" "${@:2}"; }

# newrepo <name> -- a repo at $T/<name> with one base commit holding a
# pre-existing code file AND a pre-existing top-level CHANGES.md, so a later
# case can EDIT an existing document (C3) rather than only add one.
newrepo() {
  mkdir -p "$T/$1"
  G "$T/$1" init -q -b main
  printf 'echo base\n' > "$T/$1/base.sh"
  printf 'existing document\n' > "$T/$1/CHANGES.md"
  G "$T/$1" add -A
  G "$T/$1" commit -qm base
}

# lines <path> <n> <word> -- write n distinct lines (distinct so git counts
# them as n added lines, not one)
lines() { local i=1; : > "$2"; while [ "$i" -le "$1" ]; do printf '%s %d\n' "$3" "$i" >> "$2"; i=$((i+1)); done; }

# run <repo> [env...] -- sets RUN_OUT (stdout+stderr) and RUN_RC
run() { local r="$1"; shift; RUN_OUT="$(cd "$T/$r" && "$@" "$SCRIPT" main..HEAD 2>&1)"; RUN_RC=$?; }

echo "markdown-cost.test.sh"

echo "-- A. a code-only diff is free"
newrepo codeonly
lines 40 "$T/codeonly/feature.sh" 'echo line'
G "$T/codeonly" checkout -q -b work
G "$T/codeonly" add -A
G "$T/codeonly" commit -qm feature
run codeonly env
rc   "A1 a code-only diff exits 0"            0 "$RUN_RC"
has  "A2 it reports the ratio it measured"    "$RUN_OUT" "0 of 40 added line(s) are markdown -- 0%"
hasnt "A2 and raises no FLAG"                 "$RUN_OUT" "FLAG ["

echo "-- B. a prose-heavy diff is not"
newrepo prosey
mkdir -p "$T/prosey/docs"
lines 90 "$T/prosey/docs/essay.md" 'a paragraph about the system'
lines 10 "$T/prosey/small.sh" 'echo line'
G "$T/prosey" checkout -q -b work
G "$T/prosey" add -A
G "$T/prosey" commit -qm prose
run prosey env
rc  "B1 a 90%-prose diff exits 1"             1 "$RUN_RC"
has "B2 it names the ratio and threshold"     "$RUN_OUT" "90 of 100 added line(s) are markdown -- 90% (threshold 30%)"
has "B2 it FLAGs the ratio"                   "$RUN_OUT" "FLAG [markdown-ratio]"
has "B3 it names the file that cost it"       "$RUN_OUT" "docs/essay.md:90"

run prosey env MARKDOWN_COST_MAX_PCT=95
rc  "B4 a higher threshold from the env passes the same diff" 0 "$RUN_RC"
has "B4 and the report states the threshold it used"          "$RUN_OUT" "threshold 95%"

# Deletions are free: reaping prose is the behaviour we want, not the one we
# tax. A commit that ONLY removes markdown must not be billed for it.
newrepo reaper
lines 60 "$T/reaper/CHANGES.md" 'an old paragraph'
G "$T/reaper" add -A
G "$T/reaper" commit -qm grow
G "$T/reaper" checkout -q -b work
: > "$T/reaper/CHANGES.md"          # 60 markdown lines deleted, none added
lines 10 "$T/reaper/reaped.sh" 'echo line'
G "$T/reaper" add -A
G "$T/reaper" commit -qm reap
run reaper env
rc  "B5 deleting 60 lines of prose is free"  0 "$RUN_RC"
has "B5 the deletions are not in the count"  "$RUN_OUT" "0 of 10 added line(s) are markdown"

# B6: THE REWRITE-AS-REAP. B5 only covers a diff that adds NO prose. A real
# reap replaces a long stale passage with a short correct one, so it is
# markdown-only and therefore 100% markdown -- over any threshold, forever.
# That flagged hf7y/realisateur#231, which removed 330 lines of prose
# defending retired mechanisms and put back 155, and it would have flagged
# every future reap identically. A guard that fails the work it exists to
# encourage stops being read.
newrepo rewriter
lines 200 "$T/rewriter/DOC.md" 'a long stale passage about a retired mechanism'
G "$T/rewriter" add -A
G "$T/rewriter" commit -qm grow
G "$T/rewriter" checkout -q -b work
lines 40 "$T/rewriter/DOC.md" 'the short correct replacement'
G "$T/rewriter" add -A
G "$T/rewriter" commit -qm reap
run rewriter env
rc  "B6 a markdown-only rewrite that nets NEGATIVE passes"  0 "$RUN_RC"
has "B6 and it is reported as a reap, with the net"         "$RUN_OUT" "net prose: -160 line(s)"
hasnt "B6 and raises no ratio FLAG"                         "$RUN_OUT" "FLAG [markdown-ratio]"

# The exemption is self-limiting: prose that GROWS still pays, even though
# this diff also deletes. Otherwise "delete a line, add a hundred" would buy
# an exemption, which is the same dodge inverted.
newrepo grower
lines 20 "$T/grower/DOC.md" 'a short passage'
G "$T/grower" add -A
G "$T/grower" commit -qm seed
G "$T/grower" checkout -q -b work
lines 150 "$T/grower/DOC.md" 'a much longer passage that replaced it'
G "$T/grower" add -A
G "$T/grower" commit -qm grow
run grower env
rc  "B7 a markdown-only rewrite that nets POSITIVE still exits 1" 1 "$RUN_RC"
has "B7 and still FLAGs the ratio"  "$RUN_OUT" "FLAG [markdown-ratio]"

# B8: THE LAUNDERING CASE. Netting repo-wide is not enough on its own --
# deleting one obsolete document buys room for a brand-new essay somewhere
# else, and the total still reads negative. Found by fixture against the
# exemption's own first version, before it had shipped a week. So the test is
# per FILE as well as in total: no markdown file may grow.
newrepo launderer
mkdir -p "$T/launderer/docs"
lines 300 "$T/launderer/docs/OLD.md" 'an obsolete paragraph'
G "$T/launderer" add -A
G "$T/launderer" commit -qm seed
G "$T/launderer" checkout -q -b work
rm "$T/launderer/docs/OLD.md"
lines 250 "$T/launderer/docs/NEW.md" 'a brand new essay line'
G "$T/launderer" add -A
G "$T/launderer" commit -qm launder
run launderer env
rc  "B8 a big delete does NOT buy a big new document elsewhere" 1 "$RUN_RC"
has "B8 and the grown file is named"  "$RUN_OUT" "docs/NEW.md:+250"
has "B8 and it says why this is not a reap"  "$RUN_OUT" "these grew, so this is not a reap"

echo "-- C. a new top-level document"
newrepo newroot
lines 50 "$T/newroot/big.sh" 'echo line'
printf 'a brand new root document\n' > "$T/newroot/PLAN-2026-08-07.md"
G "$T/newroot" checkout -q -b work
G "$T/newroot" add -A
G "$T/newroot" commit -qm addroot
run newroot env
rc  "C1 a new top-level .md exits 1 even at a low ratio" 1 "$RUN_RC"
has "C2 it names the document"       "$RUN_OUT" "FLAG [new-root-document]"
has "C2 by path"                     "$RUN_OUT" "PLAN-2026-08-07.md"
has "C2 and prints the allowlist"    "$RUN_OUT" "allowlist: README.md CLAUDE.md man/*"

# C3: editing the document that was already there is how a record stays
# current. It must cost nothing beyond the ratio.
newrepo editroot
G "$T/editroot" checkout -q -b work
printf 'one more line\n' >> "$T/editroot/CHANGES.md"
lines 50 "$T/editroot/more.sh" 'echo line'
G "$T/editroot" add -A
G "$T/editroot" commit -qm edit
run editroot env
rc    "C3 EDITING an existing top-level .md exits 0" 0 "$RUN_RC"
hasnt "C3 and is not a new root document"            "$RUN_OUT" "FLAG [new-root-document]"

# C4: a new .md inside a directory is a document with a home. Only the ROOT is
# rationed.
newrepo nesteddoc
mkdir -p "$T/nesteddoc/notes"
printf 'a nested note\n' > "$T/nesteddoc/notes/thing.md"
lines 50 "$T/nesteddoc/more.sh" 'echo line'
G "$T/nesteddoc" checkout -q -b work
G "$T/nesteddoc" add -A
G "$T/nesteddoc" commit -qm nested
run nesteddoc env
rc    "C4 a new .md under a directory exits 0" 0 "$RUN_RC"
hasnt "C4 and is not a new root document"      "$RUN_OUT" "FLAG [new-root-document]"

echo "-- D. the allowlist (one list, both checks)"
# D1: CLAUDE.md is the project's own front door. Adding it must not be
# rationed -- this is the new-root-document call site reading the allowlist.
newrepo allowroot
printf 'project instructions\n' > "$T/allowroot/CLAUDE.md"
lines 50 "$T/allowroot/more.sh" 'echo line'
G "$T/allowroot" checkout -q -b work
G "$T/allowroot" add -A
G "$T/allowroot" commit -qm claude
run allowroot env
rc    "D1 a NEW allowlisted root document exits 0" 0 "$RUN_RC"
hasnt "D1 and raises no FLAG at all"               "$RUN_OUT" "FLAG ["

# D2: the ratio's call site reads the SAME list. 90 lines of README.md would be
# a 90% prose diff if the allowlist were only consulted by the other check.
newrepo allowratio
G "$T/allowratio" checkout -q -b work
lines 90 "$T/allowratio/README.md" 'how to use this'
lines 10 "$T/allowratio/small.sh" 'echo line'
G "$T/allowratio" add -A
G "$T/allowratio" commit -qm readme
run allowratio env
rc    "D2 90 lines of README.md are not priced as prose" 0 "$RUN_RC"
has   "D2 and the numerator really was zero"             "$RUN_OUT" "0 of 100 added line(s) are markdown"

# D3: man/ at any depth.
newrepo allowman
mkdir -p "$T/allowman/man/verbs"
lines 90 "$T/allowman/man/verbs/thing.md" 'the manual page'
lines 10 "$T/allowman/small.sh" 'echo line'
G "$T/allowman" checkout -q -b work
G "$T/allowman" add -A
G "$T/allowman" commit -qm man
run allowman env
rc    "D3 anything under man/ is allowlisted" 0 "$RUN_RC"

echo "-- E. it must never answer 'found nothing' with exit 0"
newrepo unresolvable
G "$T/unresolvable" checkout -q -b work
printf 'echo x\n' >> "$T/unresolvable/base.sh"
G "$T/unresolvable" add -A
G "$T/unresolvable" commit -qm x
RUN_OUT="$(cd "$T/unresolvable" && "$SCRIPT" no-such-ref..HEAD 2>&1)"; RUN_RC=$?
rc  "E1 an unresolvable range exits 2, not 0" 2 "$RUN_RC"
has "E2 and says which range it could not read" "$RUN_OUT" "cannot read the diff for 'no-such-ref..HEAD'"

mkdir -p "$T/notarepo"
RUN_OUT="$(cd "$T/notarepo" && "$SCRIPT" 2>&1)"; RUN_RC=$?
rc  "E3 outside a git repository exits 2" 2 "$RUN_RC"
has "E3 and says so"                      "$RUN_OUT" "not inside a git repository"

RUN_OUT="$(cd "$T/unresolvable" && MARKDOWN_COST_MAX_PCT=lots "$SCRIPT" main..HEAD 2>&1)"; RUN_RC=$?
rc  "E4 a non-numeric threshold exits 2, not silently 30%" 2 "$RUN_RC"
has "E4 and names the value it rejected"                   "$RUN_OUT" "got 'lots'"

RUN_OUT="$(cd "$T/unresolvable" && "$SCRIPT" main..HEAD extra 2>&1)"; RUN_RC=$?
rc  "E5 a second positional argument exits 2" 2 "$RUN_RC"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
