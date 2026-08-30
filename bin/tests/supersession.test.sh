#!/usr/bin/env bash
set -uo pipefail  # contract test for bin/supersession.sh (#754). HERMETICITY: full -- a fake `gh` serves the issue state, the contents lookup and the merged-PR search from fixtures; the ledger is a fixture; the only real tree read is this repo's own, which is what a `path:` row in this repo means.
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/supersession.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
harness_tmp

mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = search ]; then cat "${SEARCH_FIXTURE:-/dev/null}"; exit 0; fi
if [ "$1" = issue ]; then printf '%s\n' "${ISSUE_STATE:-CLOSED}"; exit 0; fi
if [ "$1" = api ]; then
  [ -n "${API_ERROR:-}" ] && { echo "$API_ERROR" >&2; exit 1; }
  case "$2" in *"$PRESENT_API") echo '{}'; exit 0 ;; esac
  echo 'gh: Not Found (HTTP 404)' >&2; exit 1
fi
echo "unexpected gh call: $*" >&2; exit 1
EOF
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"
export PRESENT_API='__nothing__'
echo 'here' > "$T/present"
printf '[]\n' > "$T/none.json"

run() { SEARCH_FIXTURE="${SEARCH_FIXTURE:-$T/none.json}" SUPERSEDED_TSV="$T/led.tsv" bash "$SCRIPT" "$@"; }
led() { printf '%s\n' "$@" > "$T/led.tsv"; }

echo "supersession.test.sh"

section "A. RESIDUE -- the retired end is still there"
led "path:$T/present	path:bin/supersession.sh	hf7y/realisateur#754	the old one outlived its replacement"
out="$(run --local 2>&1)"; code=$?
rc  "A1 exit 1"                              1 "$code"
has "A2 says RESIDUE"                        "$out" "RESIDUE"
has "A3 names the superseded thing"          "$out" "path:$T/present"
has "A4 names what replaced it"              "$out" "path:bin/supersession.sh replaced it"
has "A5 names the witness"                   "$out" "hf7y/realisateur#754"
has "A6 carries the note"                    "$out" "outlived its replacement"

section "B. finished -- retired gone, armed there -- is clean and silent"
led "path:$T/absent	path:bin/supersession.sh	hf7y/realisateur#754	done"
out="$(run --local 2>&1)"; code=$?
rc    "B1 exit 0"                            0 "$code"
hasnt "B2 no finding printed"                "$out" "RESIDUE"
hasnt "B3 and none of the other kind either" "$out" "UNARMED"
has   "B4 the row was still counted"         "$out" "TOTAL 1 row(s) 0 finding(s)"

section "C. UNARMED -- built, and the switch was never flipped"
led "path:$T/absent	path:bin/no-such-file.sh	hf7y/realisateur#754	the arming never landed"
out="$(run --local 2>&1)"; code=$?
rc  "C1 exit 1"                              1 "$code"
has "C2 says UNARMED"                        "$out" "UNARMED"
has "C3 names the thing that is absent"      "$out" "path:bin/no-such-file.sh is absent"

section "D. a dash end is nothing to check, not a missing ref"
led "path:$T/absent	-	hf7y/realisateur#696	a deletion with no replacement"
out="$(run --local 2>&1)"; code=$?
rc    "D1 a finished deletion is clean"      0 "$code"
led "-	path:bin/no-such-file.sh	hf7y/realisateur#754	a new arming, nothing retired"
out="$(run --local 2>&1)"; code=$?
rc  "D2 an unlanded arming is still a finding" 1 "$code"
has "D3 and reads as never landed"           "$out" "declared and never landed"

section "E. a ref kind with no resolver is BLIND, never clean"
led "socket:/run/nope	-	hf7y/realisateur#754	invented kind"
out="$(run --local 2>&1)"; code=$?
rc  "E1 exit 6"                              6 "$code"
has "E2 names the ref it could not resolve"  "$out" "socket:/run/nope"

section "F. a gh failure that is NOT a 404 must not read as absent"
led "branch:salvage/whatever	-	hf7y/realisateur#746	a branch nobody can look up right now"
out="$(SUPERSEDED_TSV="$T/led.tsv" API_ERROR='API rate limit exceeded' \
       bash "$SCRIPT" --local 2>&1)"; code=$?
rc  "F1 exit 6, not 0"                       6 "$code"
has "F2 says why it could not look"          "$out" "rate limit"

section "G. a merged PR retires: entry is checked exactly like a ledger row"
led "# nothing declared here"
cat > "$T/search.json" <<'EOF'
[{"number":808,"repository":{"nameWithOwner":"hf7y/realisateur"},
  "body":"NO-DECISION: x\n<!-- DELIVERS -->\n- retires: path:bin/supersession.sh -> path:bin/no-such-file.sh -- the swap\n<!-- /DELIVERS -->"}]
EOF
out="$(SEARCH_FIXTURE="$T/search.json" run 2>&1)"; code=$?
rc  "G1 exit 1 -- both ends are wrong"       1 "$code"
has "G2 RESIDUE on the retired end"          "$out" "RESIDUE  path:bin/supersession.sh"
has "G3 UNARMED on the armed end"            "$out" "UNARMED  path:bin/no-such-file.sh"
has "G4 the PR is the witness"               "$out" "hf7y/realisateur#808"
has "G5 the note survives the parse"         "$out" "the swap"

section "G2. another repo's tree is read over the API, not this one's"
led "# nothing declared here"
cat > "$T/cross.json" <<'EOF'
[{"number":9,"repository":{"nameWithOwner":"hf7y/scheduler"},
  "body":"<!-- DELIVERS -->\n- retires: path:bin/served-not-cloned.sh -- still there\n<!-- /DELIVERS -->"}]
EOF
out="$(SEARCH_FIXTURE="$T/cross.json" PRESENT_API='bin/served-not-cloned.sh' run 2>&1)"; code=$?
rc  "G2a exit 1"                              1 "$code"
has "G2b the other repo's file reads present" "$out" "RESIDUE  path:bin/served-not-cloned.sh"

section "H. --local reads the ledger and nothing else"
led "path:$T/absent	-	hf7y/realisateur#696	done"
out="$(SEARCH_FIXTURE="$T/search.json" run --local 2>&1)"; code=$?
rc    "H1 exit 0"                            0 "$code"
hasnt "H2 the searched PR was never judged"  "$out" "#808"

section "I. an unreadable ledger is BLIND, not an empty clean run"
out="$(SUPERSEDED_TSV="$T/no-such-ledger.tsv" bash "$SCRIPT" --local 2>&1)"; code=$?
rc  "I1 exit 6"  6 "$code"
has "I2 names the ledger"                    "$out" "no-such-ledger.tsv"

section "J. the argument contract"
out="$(run --nope 2>&1)"; code=$?
rc  "J1 an unknown flag is a usage error"    2 "$code"
out="$(run extra 2>&1)"; code=$?
rc  "J2 so is a positional"                  2 "$code"

section "K. the shipped ledger parses, and every row's kinds have a resolver"
out="$(SUPERSEDED_TSV="$(cd "$(dirname "$0")/../lib" && pwd)/superseded.tsv" \
       ISSUE_STATE=CLOSED bash "$SCRIPT" --local 2>&1)"; code=$?
case $code in 0|1) ok "K1 the real ledger is readable and graded (exit $code)" ;;
  *) bad "K1 the real ledger did not grade" "exit $code: $out" ;; esac
hasnt "K2 no row uses a kind with no resolver" "$out" "no resolver"

summary
