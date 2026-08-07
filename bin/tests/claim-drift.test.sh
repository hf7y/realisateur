#!/usr/bin/env bash
# HERMETICITY: offline, zero AI, no network. Every case builds a fixture
# directory holding the two JSON documents the script reads (a `gh pr view`
# payload and an issue timeline) and puts a fake `gh` at the front of PATH that
# serves them, under one `mktemp -d`. Case F runs with a FAILING `gh` to pin
# BLIND, and case G with `jq` absent -- so both unavailability paths are
# exercised rather than inherited from whatever the runner happens to have.
# No live PR, no live repository, no live tracker.
#
# claim-drift.test.sh -- witness for bin/claim-drift.sh.
#
# Offline, zero AI, no network. Every case builds a fixture directory holding
# the two JSON documents the script reads (a `gh pr view` payload and an issue
# timeline) and puts a fake `gh` at the front of PATH that serves them. It
# never reads the live tracker, so it says the same thing on every host and in
# CI -- which is the property three suites in this repository lacked until
# 2026-08-07, when wiring them to CI is what made them admit it.
#
# THE LOAD-BEARING CASE IS B1. It is the original incident, replayed: a PR
# opened NOT as a draft (so it carries no `ready_for_review` event to anchor
# against), reported as done, and then grown. Live proof that the shape is real
# rather than hypothetical: hf7y/realisateur#98 was opened non-draft at
# 2026-08-07T21:29:10Z and took four more commits afterwards. A mechanism that
# only anchors on `ready_for_review` sees NOTHING there, because that event
# does not exist -- which is why B1 exists and why it is not the same test as
# A2.
#
# C1/D1 are the other half of the bar, and they are assertions about what the
# mechanism must NOT do. Growth after "done" is legitimate -- addressing review
# is the ordinary case -- so a draft PR and a PR converted BACK to draft must
# stay silent even under --strict. A guard that flags legitimate work gets
# routed around within a week, and then it protects nothing while looking like
# it does.
#
# Cases:
#   A1 ready_for_review, no commits after       -> CURRENT, exit 0
#   A2 ready_for_review, commits after          -> DRIFTED
#   A3 ...and --strict gates on it              -> exit 1
#   A4 ...and it prints the immutable claim sha and the head it moved to
#   B1 opened non-draft, commits after          -> DRIFTED (THE INCIDENT)
#   B2 ...and names the anchor as the opening, not a ready event
#   C1 draft PR, commits galore, --strict       -> exit 0, UNCLAIMED
#   C2 ...and says so in words
#   D1 ready, then converted BACK to draft      -> exit 0 under --strict
#   E1 ready, grown, re-readied                 -> CURRENT again, exit 0
#   F1 gh unavailable                           -> BLIND, exit 6 under --strict
#   F2 ...and says it cannot see, not that nothing drifted
#   G1 a MERGED pr                              -> SETTLED, never DRIFTED
#   H1 unknown flag                             -> exit 2
#   H2 no PR and no --all                       -> exit 2
#   I1 the surfacing half exists: a workflow invokes this script on
#      pull_request. Without it the script is a thing someone must remember to
#      run, which is the prose discipline this replaces.
#   I2 ...and it re-runs on the events that CHANGE the answer
#      (ready_for_review / converted_to_draft are NOT in the default set).

set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
SUT="$ROOT/bin/claim-drift.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }
is()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected [$3], got [$2]"; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "output lacks [$3]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1" "output should not contain [$3]" ;; *) ok "$1" ;; esac; }

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

pr_json() { # <number> <state> <isDraft> <createdAt> <headRefOid> <commits-json>
  printf '{"number":%s,"title":"t","url":"https://x/pull/%s","state":"%s","isDraft":%s,"createdAt":"%s","headRefOid":"%s","commits":%s}' \
    "$1" "$1" "$2" "$3" "$4" "$5" "$6"
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

echo
printf 'claim-drift.test.sh: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
