#!/usr/bin/env bash
#
# TRAPS (the rest of this header is in the vault):
# Offline, zero AI, no network. Every case builds a fixture directory holding
# the two JSON documents the script reads (a `gh pr view` payload and an issue
# timeline) and puts a fake `gh` at the front of PATH that serves them. It
# never reads the live tracker, so it says the same thing on every host and in
# CI -- which is the property three suites in this repository lacked until
# 2026-08-07, when wiring them to CI is what made them admit it.

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
SUT="$ROOT/bin/claim-drift.sh"
is()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected [$3], got [$2]"; }

TMP="$(mktemp -d)" || { echo "cannot mktemp" >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT

# --- a `gh` that serves fixtures ---------------------------------------------
# It dispatches on the subcommand exactly as the real one would, and fails
# loudly on anything else: a shim that silently returns empty JSON would make
# every case pass by testing nothing.
mkdir -p "$TMP/shim"
cat > "$TMP/shim/gh" <<'SHIM'
#!/usr/bin/env bash
: "${GH_FIXTURE:?fake gh called with no fixture}"
case "$1 $2" in
  "pr view") cat "$GH_FIXTURE/pr.json" ;;
  "pr list") cat "$GH_FIXTURE/list.json" ;;
  "pr diff") cat "$GH_FIXTURE/diff.txt" 2>/dev/null ;;
  "api "*|"api") cat "$GH_FIXTURE/timeline.json" ;;
  *) echo "fake gh: unexpected invocation: $*" >&2; exit 3 ;;
esac
SHIM
chmod +x "$TMP/shim/gh"

# A `gh` that is there and FAILS -- auth expired, rate limit, no network.
mkdir -p "$TMP/deadgh"
printf '#!/bin/sh\nexit 1\n' > "$TMP/deadgh/gh"
chmod +x "$TMP/deadgh/gh"

# A PATH with no `jq` on it. It cannot simply be an empty directory: the
# script needs bash, readlink and dirname before it reaches any check at all,
# so emptying PATH tests "bash is missing", not "jq is missing" -- the first
# draft of this case did exactly that and scored 127. Each tool the absence
# under test does NOT concern is linked in by name, which also documents the
# script's real external dependencies.
mkdir -p "$TMP/nojq"
for t in bash readlink dirname tr cat; do ln -sf "$(command -v "$t")" "$TMP/nojq/$t"; done
ln -sf "$TMP/shim/gh" "$TMP/nojq/gh"

# mkcase <name> <pr-json> <timeline-json>
mkcase() {
  local d="$TMP/$1"; mkdir -p "$d"
  printf '%s\n' "$2" > "$d/pr.json"
  printf '%s\n' "$3" > "$d/timeline.json"
  echo "$d"
}

# commits <oid:date>... -> the commits array of a `gh pr view` payload
commits() {
  local out="" c
  for c in "$@"; do
    out="$out{\"oid\":\"${c%%:*}\",\"committedDate\":\"${c#*:}\"},"
  done
  printf '[%s]' "${out%,}"
}

pr_json() { # <number> <state> <isDraft> <createdAt> <headRefOid> <commits-json> [body]
  # The body defaults to a CONFORMING first line so the drift cases above keep
  # testing drift and nothing else. Section J supplies its own bodies; if the
  # default were non-conforming, every case would fail for two reasons at once
  # and neither verdict would be evidence about the other.
  # `${7-...}` and NOT `${7:-...}`: the colon form substitutes the default for
  # an EMPTY argument as well as an unset one, so case J5 -- the empty body --
  # silently received the conforming default and passed by testing nothing.
  local body="${7-DECISION: merge this, it is a clean fix.}"
  printf '{"number":%s,"title":"t","url":"https://x/pull/%s","state":"%s","isDraft":%s,"createdAt":"%s","headRefOid":"%s","commits":%s,"body":%s}' \
    "$1" "$1" "$2" "$3" "$4" "$5" "$6" "$(printf '%s' "$body" | jq -Rs .)"
}

# run <fixture-dir> [args...]
run() {
  local d="$1"; shift
  PATH="$TMP/shim:$PATH" GH_FIXTURE="$d" bash "$SUT" --repo o/r "$@" 2>&1
}
rc_of() { local d="$1"; shift; PATH="$TMP/shim:$PATH" GH_FIXTURE="$d" bash "$SUT" --repo o/r "$@" >/dev/null 2>&1; echo $?; }

echo "claim-drift.test.sh"
echo

# --- A: anchored on ready_for_review -----------------------------------------
echo "A. ready_for_review is the commitment point"
A1D=$(mkcase a1 \
  "$(pr_json 1 OPEN false 2026-08-01T10:00:00Z aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111 \
      "$(commits aaaa0000aaaa:2026-08-01T10:00:00Z aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111:2026-08-01T11:00:00Z)")" \
  '[{"event":"ready_for_review","created_at":"2026-08-01T12:00:00Z"}]')
out=$(run "$A1D" 1); rc=$(rc_of "$A1D" --strict 1)
has A1 "$out" "CURRENT"
is  A1b "$rc" 0

A2D=$(mkcase a2 \
  "$(pr_json 2 OPEN false 2026-08-01T10:00:00Z bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222 \
      "$(commits aaaa0000aaaa:2026-08-01T10:00:00Z cccc3333cccc:2026-08-01T13:00:00Z bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222:2026-08-01T14:00:00Z)")" \
  '[{"event":"ready_for_review","created_at":"2026-08-01T12:00:00Z"}]')
out=$(run "$A2D" 2)
has A2  "$out" "DRIFTED"
is  A3  "$(rc_of "$A2D" --strict 2)" 1
has A4a "$out" "aaaa0000aaaa"   # the sha the claim was made about
has A4b "$out" "bbbb2222"       # where the branch actually is now
has A4c "$out" "2 commit"

# --- B: THE INCIDENT -- opened non-draft, no ready_for_review event ----------
echo
echo "B. a PR opened non-draft claims completion at its opening"
B1D=$(mkcase b1 \
  "$(pr_json 98 OPEN false 2026-08-07T21:29:10Z 796094233c224299204bd631cbcc18c3d7d40549 \
      "$(commits a49d0f4d3c689ef78846581c21302c66b0261507:2026-08-07T21:28:26Z f0ad298d:2026-08-07T21:58:34Z 5bef4fdd:2026-08-07T22:10:00Z 14213c6c:2026-08-07T22:20:00Z 796094233c224299204bd631cbcc18c3d7d40549:2026-08-07T22:30:00Z)")" \
  '[{"event":"cross-referenced","created_at":"2026-08-07T21:31:11Z"}]')
out=$(run "$B1D" 98)
has B1a "$out" "DRIFTED"
has B1b "$out" "4 commit"
is  B1c "$(rc_of "$B1D" --strict 98)" 1
has B2  "$out" "opened non-draft"

# --- C: a draft claims nothing, so it can never drift ------------------------
echo
echo "C. growth under a draft is not a stale claim"
C1D=$(mkcase c1 \
  "$(pr_json 3 OPEN true 2026-08-01T10:00:00Z dddd4444 \
      "$(commits eeee:2026-08-01T10:00:00Z ffff:2026-08-02T10:00:00Z dddd4444:2026-08-03T10:00:00Z)")" \
  '[]')
out=$(run "$C1D" 3)
is  C1 "$(rc_of "$C1D" --strict 3)" 0
has C2a "$out" "UNCLAIMED"
hasnt C2b "$out" "DRIFTED"

# --- D: converting back to draft withdraws the claim -------------------------
echo
echo "D. converting back to draft is a withdrawal, and clears the flag"
D1D=$(mkcase d1 \
  "$(pr_json 4 OPEN true 2026-08-01T10:00:00Z 9999 \
      "$(commits eeee:2026-08-01T10:00:00Z 9999:2026-08-05T10:00:00Z)")" \
  '[{"event":"ready_for_review","created_at":"2026-08-02T10:00:00Z"},{"event":"convert_to_draft","created_at":"2026-08-04T10:00:00Z"}]')
is D1 "$(rc_of "$D1D" --strict 4)" 0

# --- E: re-readying re-commits, and the anchor moves with it -----------------
echo
echo "E. re-readying moves the anchor -- growth is allowed, silence is not"
E1D=$(mkcase e1 \
  "$(pr_json 5 OPEN false 2026-08-01T10:00:00Z 7777 \
      "$(commits eeee:2026-08-01T10:00:00Z 7777:2026-08-03T10:00:00Z)")" \
  '[{"event":"ready_for_review","created_at":"2026-08-02T10:00:00Z"},{"event":"convert_to_draft","created_at":"2026-08-02T20:00:00Z"},{"event":"ready_for_review","created_at":"2026-08-04T10:00:00Z"}]')
out=$(run "$E1D" 5)
has E1a "$out" "CURRENT"
is  E1b "$(rc_of "$E1D" --strict 5)" 0

# --- F: unreadable is not clean ----------------------------------------------
echo
echo "F. a tracker it cannot read is BLIND, never 'nothing drifted'"
outF=$(PATH="$TMP/deadgh:$PATH" bash "$SUT" --repo o/r --strict 2 2>&1); rcF=$?
is    F1  "$rcF" 6
has   F2a "$outF" "BLIND"
hasnt F2b "$outF" "CURRENT"

outG=$(PATH="$TMP/nojq" GH_FIXTURE="$A2D" "$TMP/nojq/bash" "$SUT" --repo o/r --strict 2 2>&1); rcG=$?
is  F3 "$rcG" 6
has F4 "$outG" "jq"

# --- G: a merged PR is settled -----------------------------------------------
echo
echo "G. a merged PR's head is immutable"
G1D=$(mkcase g1 \
  "$(pr_json 6 MERGED false 2026-08-01T10:00:00Z 6666 \
      "$(commits eeee:2026-08-01T10:00:00Z 6666:2026-08-09T10:00:00Z)")" \
  '[]')
out=$(run "$G1D" 6)
has  G1a "$out" "SETTLED"
hasnt G1b "$out" "DRIFTED"
is   G1c "$(rc_of "$G1D" --strict 6)" 0

# --- H: the argument contract -------------------------------------------------
echo
echo "H. the argument contract"
is H1 "$(rc_of "$A1D" --not-a-real-flag 1)" 2
PATH="$TMP/shim:$PATH" GH_FIXTURE="$A1D" bash "$SUT" --repo o/r >/dev/null 2>&1
is H2 "$?" 2

# --- I: the surfacing half ----------------------------------------------------
# The script is the sensor; the workflow is what makes it fire without anyone
# remembering to. Asserting only the script would pass on a repository where
# nothing ever runs it -- the "built but not wired" failure this estate keeps
# repeating.
echo
echo "I. wired to fire on its own"
wf=$(grep -rl 'claim-drift.sh' "$ROOT/.github/workflows/" 2>/dev/null | head -1)
if [ -n "$wf" ]; then
  ok I1
  body=$(cat "$wf")
  has I2a "$body" "ready_for_review"
  has I2b "$body" "converted_to_draft"
  has I2c "$body" "synchronize"
else
  bad I1 "no workflow in .github/workflows/ invokes claim-drift.sh"
  bad I2a "(no workflow)"; bad I2b "(no workflow)"; bad I2c "(no workflow)"
fi

# --- J. the decision line -----------------------------------------------------
# A READY pull request is a completion claim (section A). This asserts the
# second half of the convention: a claim must also say what it asks of the
# reader. Not a style rule -- Zach's stated failure mode is "if it's a PR not a
# draft, I'm just going to merge it without reading", so a ready PR whose first
# line does not classify itself is one he cannot triage without opening it.
#
# The classification is the AUTHOR's, declared, not inferred: no guard can read
# intent. Both forms are one line and both are checkable.
echo
echo "J. a ready PR classifies itself in line one"

J_TL='[{"event":"opened","created_at":"2026-01-01T00:00:00Z"}]'
jcase() { # <name> <isDraft> <body> -> fixture dir
  mkcase "$1" "$(pr_json 9 OPEN "$2" 2026-01-01T00:00:00Z aaaa "$(commits aaaa:2026-01-01T00:00:00Z)" "$3")" "$J_TL"
}

J1=$(jcase j1 false 'DECISION: adopt the ratchet as a build-blocking floor?')
has J1 "$(run "$J1" 9)" 'CURRENT'
hasnt  J1b "$(run "$J1" 9)" 'UNDECIDED'

J2=$(jcase j2 false '**DECISION:** bolded is still a decision.')
hasnt  J2 "$(run "$J2" 9)" 'UNDECIDED'

J3=$(jcase j3 false 'NO-DECISION: green fix, nothing to weigh.')
hasnt  J3 "$(run "$J3" 9)" 'UNDECIDED'

# The failure this closes: a wall of prose with the ask buried in it.
J4=$(jcase j4 false 'This PR reworks the gate and also touches the ledger. Merging it
would make the ratchet blocking, which you may or may not want.')
has J4 "$(run "$J4" 9)" 'UNDECIDED'
is  J4b "$(rc_of "$J4" --strict 9)" 1

J5=$(jcase j5 false '')
has J5 "$(run "$J5" 9)" 'UNDECIDED'

# Leading blank lines and markdown furniture must not defeat it -- the rule is
# the first NON-EMPTY line, stripped of emphasis, not literally byte one.
J6=$(jcase j6 false '

## DECISION: still counts after a heading and blank lines.')
hasnt J6 "$(run "$J6" 9)" 'UNDECIDED'

# A DRAFT claims nothing (section A), so it is exempt. Requiring a decision of
# a draft would make the convention self-contradictory: draft is precisely the
# state for work that is not yet asking anything of anyone.
J7=$(jcase j7 true 'no decision here at all, and that is fine')
has J7 "$(run "$J7" 9)" 'UNCLAIMED'
hasnt  J7b "$(run "$J7" 9)" 'UNDECIDED'
is  J7c "$(rc_of "$J7" --strict 9)" 0

# The word must open the line, not merely appear in it. Otherwise any PR that
# mentions the convention in passing exempts itself -- the exact false positive
# guard-estate's check E hit and had to fix.
J8=$(jcase j8 false 'We should probably add a DECISION: line to this one day.')
has J8 "$(run "$J8" 9)" 'UNDECIDED'

echo
echo "L. OVERCAUTIOUS -- a DECISION line nobody needed to write"
# Real incident, 2026-08-10: a read-only survey script (new file) plus a
# prose-to-vault move (existing .md, net line-count DOWN) got a DECISION
# line and blocked auto-merge for a change that altered no running thing.

DIFF_NEW_ONLY='diff --git a/bin/new-thing.sh b/bin/new-thing.sh
new file mode 100755
index 0000000..1111111
--- /dev/null
+++ b/bin/new-thing.sh
+#!/usr/bin/env bash
+echo hi
'
DIFF_MD_SHRINK='diff --git a/NOTES.md b/NOTES.md
index 2222222..3333333 100644
--- a/NOTES.md
+++ b/NOTES.md
@@ -1,5 +1,1 @@
-line one
-line two
-line three
-line four
+one line left
'
DIFF_SCRIPT_CHANGED='diff --git a/bin/sync-crontab.sh b/bin/sync-crontab.sh
index 4444444..5555555 100644
--- a/bin/sync-crontab.sh
+++ b/bin/sync-crontab.sh
@@ -10,3 +10,4 @@
 existing line
+one new line in an EXISTING script
'

L1=$(jcase l1 false 'DECISION: does this survey shape look right?')
printf '%s' "$DIFF_NEW_ONLY$DIFF_MD_SHRINK" > "$L1/diff.txt"
has L1 "$(run "$L1" 9)" 'OVERCAUTIOUS'

# NO-DECISION already says "no judgement needed" -- must not double-flag.
L2=$(jcase l2 false 'NO-DECISION: green fix, nothing to weigh.')
printf '%s' "$DIFF_NEW_ONLY" > "$L2/diff.txt"
hasnt L2 "$(run "$L2" 9)" 'OVERCAUTIOUS'

# A real behavior change (an EXISTING script edited, not just new/doc files)
# must NOT be flagged -- this is the guard against false positives, and the
# whole reason it stops at new-file-or-shrinking-.md rather than "small diff".
L3=$(jcase l3 false 'DECISION: does the new cron cadence look right?')
printf '%s' "$DIFF_SCRIPT_CHANGED" > "$L3/diff.txt"
hasnt L3 "$(run "$L3" 9)" 'OVERCAUTIOUS'

# --strict must never gate on it -- it is a suggestion, not a verdict.
is L4 "$(rc_of "$L1" --strict 9)" 0

echo
echo "K. the convention is single-sourced"
convout=$(bash "$SUT" --convention 2>&1); rcK=$?
is  K1 "$rcK" 0
has K2 "$convout" 'draft'
has K3 "$convout" 'DECISION:'
# The canonical text must be reachable without reading the source, or spawners
# will keep retyping it from memory -- which is how it drifted in the first place.
has K4 "$convout" 'NO-DECISION:'

echo
summary
