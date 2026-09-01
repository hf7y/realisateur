#!/usr/bin/env bash
# decision-rot.test.sh -- witness for bin/decision-rot.sh.
#
# WHAT IS PINNED, and why each case exists rather than being a nice-to-have:
#
#   * B: an answer on a CLOSED issue counts as ANSWERED (so `--state open` is
#        never reintroduced for the answer scan) and NOT as ROT.
#     C: an agent's own stamped comment, byte-indistinguishable from Zach's
#        but for the trailing stamp. Only-stamped comments means zero answers.
#   * D: the stamp is the LAST NON-BLANK LINE ONLY -- a mid-body quote must
#        not disqualify a real answer, nor trailing blanks hide a real stamp.
#   * E: silent zero. A `gh` failure must exit 6, never 0-with-no-rot.
#   * C'': a stamped RELAY counts; without its marker it does not (#430).
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
# The fake roster service. lib/arming.sh reads it over curl now, not out of a
# repo (hf7y/scheduler#429); $ROSTER_FAIL makes the door refuse to answer,
# which is BLIND -- E1 and I13 are the assertions that it stays BLIND rather
# than becoming "nothing is armed".
cat > "$T/bin/curl" <<'EOF'
#!/usr/bin/env bash
if [ -n "${ROSTER_FAIL:-}" ]; then echo "$ROSTER_FAIL" >&2; exit 7; fi
cat "$ROSTER_FIXTURE"
EOF
chmod +x "$T/bin/curl"
export PATH="$T/bin:$PATH"
export DECISION_ROT_OWNER=owner

cat > "$T/roster.default" <<'EOF'
{"rows": [
  {"project":"r",      "account":"r",      "host":"monkey","rate":"20m","state":"live"},
  {"project":"parked", "account":"parked", "host":"monkey","rate":"6h", "state":"parked"}
]}
EOF
export ROSTER_FIXTURE="$T/roster.default"

run() { FIXTURE="$1" bash "$SCRIPT" "${@:2}"; }

STAMP='<!-- agent: hf7y/realisateur 2026-08-15 -->'

# FIXTURE COMMENTS ARE DATED AFTER 2026-08-14 ON PURPOSE: 16 cases flipped to
# "uncounted" when the era arrived, and the dates are incidental to what A-D
# pin, so the clock moved and the assertions did not (era pinned in C''').

echo "decision-rot.test.sh"

echo "-- A. answered and still OPEN is rot; unanswered and open is not"
cat > "$T/a.json" <<EOF
[
 {"number":1,"title":"answered and open","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"build it","createdAt":"2026-08-17T00:00:00Z"}]},
 {"number":2,"title":"nobody answered this","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"somebodyelse"},"body":"any word on this?","createdAt":"2026-08-17T00:00:00Z"}]},
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
  "comments":[{"author":{"login":"owner"},"body":"yes, that is what it does","createdAt":"2026-08-15T00:00:00Z"}]}
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
  "comments":[{"author":{"login":"owner"},"body":"Filed as requested: hf7y/realisateur#289.\n\n$STAMP","createdAt":"2026-08-17T00:00:00Z"}]}
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
  "comments":[{"author":{"login":"owner"},"body":"DECISION (Zach, in conversation): delete it.\n\n<!-- decision-by: zach 2026-08-21 -->\n\n$STAMP","createdAt":"2026-08-19T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/c3.json" o/r)"; RC=$?
rc  "C''1 exits 1 -- the relay IS an answer, and it is still open" 1 "$RC"
has "C''2 counts it answered" "$OUT" "1        1"
has "C''3 dated from the relay" "$OUT" "answered 2026-08-19"
# Without the marker this is case C: stamped, therefore silent.
cat > "$T/c4.json" <<EOF
[
 {"number":10,"title":"same comment, no marker","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"DECISION (Zach, in conversation): delete it.\n\n$STAMP","createdAt":"2026-08-19T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/c4.json" o/r)"; RC=$?
rc  "C''4 the same relay WITHOUT the marker still does not count" 0 "$RC"

echo "-- C'. the same issue, once the human actually replies, IS rot"
cat > "$T/c2.json" <<EOF
[
 {"number":9,"title":"agent stamped, then the human replied","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"Filed as requested.\n\n$STAMP","createdAt":"2026-08-17T00:00:00Z"},
              {"author":{"login":"owner"},"body":"do the second shape","createdAt":"2026-08-18T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/c2.json" o/r)"; RC=$?
rc  "C'1 exits 1" 1 "$RC"
has "C'2 dated from the HUMAN comment, not the stamped one" "$OUT" "answered 2026-08-18"

echo "-- D. the stamp is the LAST NON-BLANK LINE ONLY"
cat > "$T/d.json" <<EOF
[
 {"number":10,"title":"quotes a stamp mid-body then answers","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"you wrote:\n\n$STAMP\n\nignore that, build it","createdAt":"2026-08-19T00:00:00Z"}]},
 {"number":11,"title":"stamped, with trailing blank lines","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"done\n\n$STAMP\n\n  \n","createdAt":"2026-08-19T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/d.json" o/r)"; RC=$?
rc  "D1 exits 1" 1 "$RC"
has   "D2 exactly one answered -- the mid-body quote does not disqualify" "$OUT" "1        1"
has   "D3 the mid-body-quote issue is the rotting one" "$OUT" "#10"
hasnt "D4 trailing blank lines do not hide the stamp" "$OUT" "#11"

echo "-- C'''. UNCOUNTED: a pre-era comment is not an answer, and not a silence"
# #553: same "no" as an issue with no comments, so chezz#4 was asked twice.
cat > "$T/u.json" <<EOF
[
 {"number":20,"title":"answered before the stamp era","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"standing yes","createdAt":"2026-08-11T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/u.json" o/r)"; RC=$?
rc    "C'''1 exits 0 -- unknowable is not an answer, so it is not rot" 0 "$RC"
has   "C'''2 zero answered"                       "$OUT" "0        0"
has   "C'''3 ...but it is COUNTED as uncounted"   "$OUT" "UNCOUNTED"
has   "C'''4 ...and NAMED, with its date"         "$OUT" "#20    comment 2026-08-11"
has   "C'''5 ...and says what to do about it"     "$OUT" 'label it `answered`'

OUT="$(run "$T/u.json" o/r --json)"
S="$(printf '%s' "$OUT" | jq -c 'select(.kind=="summary")')"
has "C'''6 the summary carries the uncounted count" "$S" '"uncounted":1'
U="$(printf '%s' "$OUT" | jq -c 'select(.kind=="uncounted")')"
has "C'''7 each uncounted line names its issue"     "$U" '"number":20'
has "C'''8 ...and the date it declined to count"    "$U" '"comment_at":"2026-08-11"'

# THE OVERRIDE (#568): it must outrank UNCOUNTED.
cat > "$T/u2.json" <<EOF
[
 {"number":21,"title":"answered on another issue","state":"OPEN","labels":[{"name":"answered"}],
  "comments":[{"author":{"login":"owner"},"body":"standing yes","createdAt":"2026-08-11T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/u2.json" o/r)"; RC=$?
rc    "C'''9 the label makes it answered, and open, so it is rot" 1 "$RC"
has   "C'''10 counted answered"                    "$OUT" "1        1"

cat > "$T/u3.json" <<EOF
[
 {"number":30,"title":"closed, pre-era comment","state":"CLOSED","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"standing yes","createdAt":"2026-08-11T00:00:00Z"}]},
 {"number":31,"title":"answered and open, so rot","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"do it","createdAt":"2026-08-19T00:00:00Z"}]}
]
EOF
OUT="$(run "$T/u3.json" o/r)"; RC=$?
hasnt "C4-1 a CLOSED uncounted issue is not listed"       "$OUT" "#30"
has   "C4-2 ...and the open rot still is"                 "$OUT" "#31"
eq    "C4-3 ...so tail -1 is a ROTTING row, which is what ausculte reports" \
      "$(printf '%s' "$OUT" | tail -1 | grep -c answered)" "1"
S3="$(run "$T/u3.json" o/r --json | jq -c 'select(.kind=="summary")')"
has   "C4-4 uncounted_open counts only the open one"      "$S3" '"uncounted_open":0'
has   "C4-5 ...while uncounted still counts all states"   "$S3" '"uncounted":1'
# Not `hasnt "UNCOUNTED"` -- that word is a column header and is always there.
hasnt "C'''11 ...and not listed as uncounted"      "$OUT" "#21    comment"
S="$(run "$T/u2.json" o/r --json | jq -c 'select(.kind=="summary")')"
has   "C'''12 ...and the uncounted count is zero"  "$S" '"uncounted":0'

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

# --- the roster covers every repo with a backlog (2026-08-22) ---------------
# 200 open issues estate-wide; 64 sat in ELEVEN repos NO SENSOR LOOKED AT.
# decision-rot walks ROSTER, so a repo absent from it can hold an answered and
# abandoned decision forever while `ausculte rot` reads OK -- the estate's own
# disease, in the file whose header already named it: "uid 3000-3099 misses the
# ecosystem repos that carry decisions and never dispatch."
section "H. roster coverage"
. "$(cd "$(dirname "$0")/.." && pwd)/lib/roster-set.sh"
_missing=""
for _p in dcp-gate-site musc-2300 scriba-senatus french-textbook abletim \
          etalon vitae space-canon verbs front-door basheur; do
  case " ${ROSTER[*]} " in *" $_p "*) ;; *) _missing="$_missing $_p" ;; esac
done
[ -z "$_missing" ] \
  && ok "H1 every repo that carries a backlog is swept, armed or not" \
  || bad "H1 every repo with a backlog is in ROSTER" "unswept:$_missing"

# WIRED IS NOT ARMED, and the two arrays are what keep them apart. A repo that
# drifts from ECOSYSTEM into PROJECTS starts spending quota every night.
_armed=""
for _p in dcp-gate-site musc-2300 space-canon; do
  case " ${ROSTER_PROJECTS[*]} " in *" $_p "*) _armed="$_armed $_p" ;; esac
done
[ -z "$_armed" ] \
  && ok "H2 the newly swept repos are NOT in the dispatching set" \
  || bad "H2 swept is not armed" "in ROSTER_PROJECTS, and so spending quota:$_armed"

# --- I. a parked repo is not rotting (Zach, 2026-08-26) ---------------------
section "I. rot is only rot where something dispatches"

cat > "$T/i.json" <<EOF
[
 {"number":1,"title":"answered and open","state":"OPEN","labels":[],
  "comments":[{"author":{"login":"owner"},"body":"build it","createdAt":"2026-08-17T00:00:00Z"}]}
]
EOF

OUT="$(run "$T/i.json" o/r)"; RC=$?
rc  "I1 answered+open in a LIVE repo is rot" 1 "$RC"
has "I2 ...and the rotting block names it" "$OUT" "ROTTING"

OUT="$(run "$T/i.json" o/parked)"; RC=$?
rc  "I3 the SAME issue in a PARKED repo is not rot -- exit 0" 0 "$RC"
has "I4 ...it is reported as NOT-MINE, never dropped" "$OUT" "NOT-MINE"
has "I5 ...and says which, so parked is not confused with unrostered" "$OUT" "(parked)"
hasnt "I6 ...and no rotting block is printed" "$OUT" "ROTTING --"

OUT="$(run "$T/i.json" o/nowhere)"; RC=$?
rc  "I7 a repo with NO roster row is not rot either" 0 "$RC"
has "I8 ...and is named absent, not parked" "$OUT" "(absent)"

OUT="$(ROSTER_FAIL='curl: (7) connection refused' run "$T/i.json" o/r 2>&1)"; RC=$?
rc  "I9 an unreadable roster is BLIND (6), never clean and never rot" 6 "$RC"
has "I10 ...and says it classified none of them" "$OUT" "Classifying none"

OUT="$(run "$T/i.json" o/r)"
_f3="$(printf '%s\n' "$OUT" | awk '$1 == "TOTAL" { print $3 }')"
[ "$_f3" = "1" ] \
  && ok "I11 ROTTING is still field 3 of TOTAL (ausculte parses it by position)" \
  || bad "I11 ROTTING is field 3 of TOTAL" "got [$_f3]"

OUT="$(run "$T/i.json" --json o/parked)"
has "I12 --json carries the not-mine rows" "$OUT" '"kind":"not-mine"'
has "I13 ...and the summary counts them" "$OUT" '"not_mine":1'

if grep -qE '\-X (PUT|POST|PATCH|DELETE)|--method|--field|-f ' \
     "$(cd "$(dirname "$0")/.." && pwd)/lib/arming.sh"; then
  bad "I14 lib/arming.sh holds no write path" "a write verb appeared in it"
else
  ok "I14 lib/arming.sh holds no write path -- an agent cannot edit the ROSTER through it"
fi

echo
summary
[ "$fail" -eq 0 ] || exit 1
