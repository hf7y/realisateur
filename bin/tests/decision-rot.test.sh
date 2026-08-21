#!/usr/bin/env bash
# decision-rot.test.sh -- witness for bin/decision-rot.sh.
#
#
# WHAT IS PINNED, and why each case exists rather than being a nice-to-have:
#
#   * THE TWO TRAPS THAT ALREADY ATE ANSWERS.
#     B: an answer on a CLOSED issue. It must count as ANSWERED (so `--state
#        open` can never be reintroduced for the answer scan) and must NOT
#        count as ROT (closed is the estate's own signal for handled).
#     C: an agent's own stamped comment under the shared `hf7y` token, which
#        is byte-indistinguishable from Zach's except for the trailing stamp.
#        A repo where the ONLY owner comments are stamped has zero answers.
#   * D: the stamp is read on the LAST NON-BLANK LINE ONLY. A stamp quoted
#        mid-body out of another comment must not disqualify a real answer,
#        and trailing blank lines must not hide a real stamp.
#   * E: silent zero. A `gh` failure must exit 6, never 0-with-no-rot.
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/decision-rot.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# The fake gh. `--json` calls print $FIXTURE; $GH_FAIL makes it die like the
# real one does on a token or rate-limit failure.
mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [ -n "${GH_FAIL:-}" ]; then echo "$GH_FAIL" >&2; exit 1; fi
cat "$FIXTURE"
EOF
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"
export DECISION_ROT_OWNER=owner

run() { FIXTURE="$1" bash "$SCRIPT" "${@:2}"; }

STAMP='<!-- agent: hf7y/realisateur 2026-08-15 -->'

echo "decision-rot.test.sh"

echo "-- A. answered and still OPEN is rot; unanswered and open is not"
cat > "$T/a.json" <<EOF
[
 {"number":1,"title":"answered and open","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"build it","createdAt":"2026-08-01T00:00:00Z"}]},
 {"number":2,"title":"nobody answered this","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"somebodyelse"},"body":"any word on this?","createdAt":"2026-08-01T00:00:00Z"}]},
 {"number":3,"title":"no comments at all","state":"OPEN","labels":[],"comments":[]}
]
EOF
OUT="$(run "$T/a.json" o/r)"; RC=$?
rc  "A1 exits 1 (rot found)" 1 "$RC"
has "A2 counts one answered" "$OUT" "1        1"
has "A3 names the rotting issue" "$OUT" "#1"
hasnt "A4 an unanswered open issue is not rot" "$OUT" "#2"
hasnt "A5 a commentless open issue is not rot" "$OUT" "#3"

echo "-- B. TRAP 1: an answer on a CLOSED issue -- answered, but handled"
cat > "$T/b.json" <<EOF
[
 {"number":8,"title":"test dry-run (chezz#8 shape)","state":"CLOSED","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"yes, that is what it does","createdAt":"2026-07-30T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/b.json" o/r)"; RC=$?
rc    "B1 exits 0 (closed is handled, not rot)" 0 "$RC"
has   "B2 still COUNTS as answered -- the answer scan is --state all" "$OUT" "1        0"
hasnt "B3 is not listed as rotting" "$OUT" "#8"

echo "-- C. TRAP 2: an agent's own comment under the shared owner token"
cat > "$T/c.json" <<EOF
[
 {"number":9,"title":"only the agent has spoken","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"Filed as requested: hf7y/realisateur#289.\n\n$STAMP","createdAt":"2026-08-01T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/c.json" o/r)"; RC=$?
rc    "C1 exits 0 -- a stamped comment is not an answer" 0 "$RC"
has   "C2 zero answered" "$OUT" "0        0"
hasnt "C3 not listed as rotting" "$OUT" "#9"

echo "-- C''. a RELAYED answer counts, or a spoken decision dies with the session"
cat > "$T/c3.json" <<EOF
[
 {"number":10,"title":"agent wrote down what Zach said out loud","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"DECISION (Zach, in conversation): delete it.\n\n<!-- decision-by: zach 2026-08-21 -->\n\n$STAMP","createdAt":"2026-08-03T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/c3.json" o/r)"; RC=$?
rc  "C''1 exits 1 -- the relay IS an answer, and it is still open" 1 "$RC"
has "C''2 counts it answered" "$OUT" "1        1"
has "C''3 dated from the relay" "$OUT" "answered 2026-08-03"
# Without the marker this is case C: stamped, therefore silent. That contrast
# is the whole point -- #430 was answered four times and never counted once.
cat > "$T/c4.json" <<EOF
[
 {"number":10,"title":"same comment, no marker","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"DECISION (Zach, in conversation): delete it.\n\n$STAMP","createdAt":"2026-08-03T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/c4.json" o/r)"; RC=$?
rc  "C''4 the same relay WITHOUT the marker still does not count" 0 "$RC"

echo "-- C'. the same issue, once the human actually replies, IS rot"
cat > "$T/c2.json" <<EOF
[
 {"number":9,"title":"agent stamped, then the human replied","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"Filed as requested.\n\n$STAMP","createdAt":"2026-08-01T00:00:00Z"},
              {"author":{"login":"owner"},"body":"do the second shape","createdAt":"2026-08-02T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/c2.json" o/r)"; RC=$?
rc  "C'1 exits 1" 1 "$RC"
has "C'2 dated from the HUMAN comment, not the stamped one" "$OUT" "answered 2026-08-02"

echo "-- D. the stamp is the LAST NON-BLANK LINE ONLY"
cat > "$T/d.json" <<EOF
[
 {"number":10,"title":"quotes a stamp mid-body then answers","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"you wrote:\n\n$STAMP\n\nignore that, build it","createdAt":"2026-08-03T00:00:00Z"}]},
 {"number":11,"title":"stamped, with trailing blank lines","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"done\n\n$STAMP\n\n  \n","createdAt":"2026-08-03T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/d.json" o/r)"; RC=$?
rc  "D1 exits 1" 1 "$RC"
has   "D2 exactly one answered -- the mid-body quote does not disqualify" "$OUT" "1        1"
has   "D3 the mid-body-quote issue is the rotting one" "$OUT" "#10"
hasnt "D4 trailing blank lines do not hide the stamp" "$OUT" "#11"

echo "-- E. SILENT ZERO: a gh failure exits 6, never 0"
OUT="$(GH_FAIL='API rate limit exceeded' run "$T/a.json" o/r 2>&1)"; RC=$?
rc  "E1 exits 6 on a gh failure" 6 "$RC"
has "E2 says the count is untrustworthy" "$OUT" "NOT trustworthy"
OUT="$(GH_FAIL='GraphQL: Could not resolve to a Repository' run "$T/a.json" --all 2>&1)"; RC=$?
rc  "E3 a missing repo across --all is exit 6, not a quiet short count" 6 "$RC"
OUT="$(GH_FAIL='Issues are disabled for this repo' run "$T/a.json" o/r 2>&1)"; RC=$?
rc  "E4 issues-disabled is soft (exit 0, nothing to grade)" 0 "$RC"
has "E5 and says so on stderr" "$OUT" "issues disabled"

echo "-- F. machine-readable output a future gate can threshold on"
OUT="$(run "$T/a.json" o/r --json)"; RC=$?
rc  "F1 exits 1 the same as the human form" 1 "$RC"
S="$(printf '%s' "$OUT" | jq -c 'select(.kind=="summary")')"
has "F2 summary carries the rotting count" "$S" '"rotting":1'
has "F3 summary carries the answered count" "$S" '"answered":1'
has "F4 summary carries the error count" "$S" '"errors":0'
R="$(printf '%s' "$OUT" | jq -c 'select(.kind=="rotting")')"
has "F5 each rotting line carries its issue number" "$R" '"number":1'
has "F6 each rotting line carries its age in days" "$R" '"age_days"'

echo "-- G. the argument contract (cli-guard)"
bash "$SCRIPT" --not-a-real-flag >/dev/null 2>&1; rc "G1 unknown flag exits 2" 2 "$?"
bash "$SCRIPT" >/dev/null 2>&1;                   rc "G2 no argument exits 2" 2 "$?"
bash "$SCRIPT" --help >/dev/null 2>&1;            rc "G3 --help exits 0" 0 "$?"
has "G4 --help states the rot exit code" "$(bash "$SCRIPT" --help 2>&1)" "1  rot found"

echo
summary
[ "$fail" -eq 0 ] || exit 1
