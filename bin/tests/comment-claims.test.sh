#!/usr/bin/env bash
set -uo pipefail  # contract test for bin/comment-claims.sh. HERMETICITY: full -- every case runs against a fixture git tree built here; the real bin/lib/comment-claims.jq and the real bin/lib/stale-paths.jq predicates run, and nothing reaches the network.
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/comment-claims.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
harness_tmp

mk() {   # one fixture tree per case, so a case cannot inherit another's ratchet. `git add` without a commit is enough: the lint reads `git ls-files`, and a commit would need an identity a bare runner does not have.
  R="$T/$1"; mkdir -p "$R/bin/tests" "$R/schedule"; git -C "$R" init -q 2>/dev/null
}
add() { git -C "$R" add -A >/dev/null 2>&1; }
run() { bash "$SCRIPT" "$R" 2>&1; }

echo "comment-claims.test.sh"

section "A. a header field naming a file this tree does not have is a finding"
mk a
printf '#!/usr/bin/env bash\n# RUNNER: bin/tests/never-existed.test.sh\ntrue\n' > "$R/bin/subject.sh"
add
out="$(run)"; code=$?
rc  "A1 exit 1"                        1 "$code"
has "A2 the claim is located"          "$out" "bin/subject.sh:2"
has "A3 the missing file is named"     "$out" "bin/tests/never-existed.test.sh"
has "A4 and the kind is header"        "$out" "header"

section "B. a header field naming a file it does have is clean"
mk b
printf '#!/usr/bin/env bash\n# RUNNER: bin/tests/subject.test.sh\ntrue\n' > "$R/bin/subject.sh"
printf '#!/usr/bin/env bash\ntrue\n' > "$R/bin/tests/subject.test.sh"
add
out="$(run)"; code=$?
rc    "B1 exit 0"           0 "$code"
hasnt "B2 nothing reported" "$out" "subject.test.sh"

section "C. a KEY=VALUE the file its block names contradicts is a finding"
mk c
printf '# schedule/_usage.conf actually sets\n# USAGE_CEILING=0.99 and that is the brake.\n' > "$R/bin/runner.sh"
printf 'USAGE_CEILING=0.90\n' > "$R/schedule/_usage.conf"
add
out="$(run)"; code=$?
rc  "C1 exit 1"                              1 "$code"
has "C2 the claim is quoted"                 "$out" "USAGE_CEILING=0.99"
has "C3 the file's ACTUAL value is reported" "$out" "0.90"
has "C4 ...and the file that holds it"       "$out" "schedule/_usage.conf"

section "D. the same claim, agreeing with the file, is clean"
mk d
printf '# schedule/_usage.conf actually sets\n# USAGE_CEILING=0.90 and that is the brake.\n' > "$R/bin/runner.sh"
printf 'USAGE_CEILING=0.90\n' > "$R/schedule/_usage.conf"
add
out="$(run)"; code=$?
rc    "D1 exit 0"           0 "$code"
hasnt "D2 nothing reported" "$out" "USAGE_CEILING"

section "E. 0.9 and 0.90 are the same ceiling, not a contradiction"
mk e
printf '# schedule/_usage.conf sets USAGE_CEILING=0.9 today.\n' > "$R/bin/runner.sh"
printf 'USAGE_CEILING=0.90\n' > "$R/schedule/_usage.conf"
add
out="$(run)"; code=$?
rc    "E1 exit 0 -- compared as numbers, not as strings" 0 "$code"
hasnt "E2 nothing reported"                              "$out" "USAGE_CEILING"

section "F. UNRESOLVABLE IS NOT FALSE: a claim naming no file in this tree"
mk f
printf '# On dexter the runner sets USAGE_CEILING=0.99 in its own copy.\n' > "$R/bin/runner.sh"
printf 'USAGE_CEILING=0.90\n' > "$R/schedule/_usage.conf"
add
out="$(run)"; code=$?
rc    "F1 exit 0 -- no file named, so nothing was resolved" 0 "$code"
hasnt "F2 and the untouched file is NOT adjudicated"        "$out" "USAGE_CEILING"

section "G. UNRESOLVABLE: the named file does not assign the key at all"
mk g
printf '# schedule/_usage.conf is where USAGE_UNSET_KEY=7 would go.\n' > "$R/bin/runner.sh"
printf 'USAGE_CEILING=0.90\n' > "$R/schedule/_usage.conf"
add
out="$(run)"; code=$?
rc    "G1 exit 0 -- a key the file never sets is unresolvable" 0 "$code"
hasnt "G2 nothing reported"                                    "$out" "USAGE_UNSET_KEY"

section "H. a TEST FIXTURE is not an authority on a production value"
mk h
printf '# bin/tests/paced-witness.test.sh exercises CRON_ACCOUNT=vim-arcade here.\n' > "$R/schedule/vim-arcade.conf"
printf 'CRON_ACCOUNT=root\n' > "$R/bin/tests/paced-witness.test.sh"
add
out="$(run)"; code=$?
rc    "H1 exit 0 -- a witness sets a value to exercise a branch" 0 "$code"
hasnt "H2 nothing reported"                                      "$out" "CRON_ACCOUNT"

section "I. a \${KEY:-X} built-in default IS the value the file gives the key"
mk i
printf '# bin/gate.sh sets STALE_DAYS=14 unless overridden.\n' > "$R/bin/runner.sh"
printf '#!/usr/bin/env bash\nSTALE_DAYS="${STALE_DAYS:-14}"\n' > "$R/bin/gate.sh"
add
out="$(run)"; code=$?
rc    "I1 exit 0 -- reading only the literal RHS would call this false" 0 "$code"
hasnt "I2 nothing reported"                                             "$out" "STALE_DAYS"

section "J. an absent path in ORDINARY PROSE is not a finding"
mk j
printf '#!/usr/bin/env bash\n# realisateur#511 deleted bin/carry-drift.sh and kept the test, so\n# every carry has been fixed by hand since.\ntrue\n' > "$R/bin/carry.sh"
add
out="$(run)"; code=$?
rc    "J1 exit 0 -- an accurate obituary is not a stale claim" 0 "$code"
hasnt "J2 nothing reported"                                    "$out" "carry-drift.sh"

section "K. the ratchet holds a recorded finding and fails a new one"
mk k
printf '#!/usr/bin/env bash\n# RUNNER: bin/tests/gone-a.test.sh\ntrue\n' > "$R/bin/one.sh"
add
out="$(bash "$SCRIPT" "$R" --accept 2>&1)"
has "K1 --accept records the floor" "$out" "ACCEPTED"
out="$(run)"; code=$?
rc  "K2 the recorded finding no longer fails"  0 "$code"
has "K3 ...and says how many are held"         "$out" "1 held"
printf '#!/usr/bin/env bash\n# RUNNER: bin/tests/gone-b.test.sh\ntrue\n' > "$R/bin/two.sh"
add
out="$(run)"; code=$?
rc    "K4 a NEW finding fails"                 1 "$code"
has   "K5 ...and only the new one is named"    "$out" "gone-b.test.sh"
hasnt "K6 REGRESSION does not relist the held" "$out" "+ bin/one.sh"

section "L. BLIND, never clean"
mkdir -p "$T/notarepo"
out="$(bash "$SCRIPT" "$T/notarepo" 2>&1)"; code=$?
rc  "L1 not a git tree is exit 6"   6 "$code"
has "L2 ...and says BLIND"          "$out" "BLIND"
mk l
printf 'USAGE_CEILING=0.90\n' > "$R/schedule/_usage.conf"
add
out="$(run)"; code=$?
rc  "L3 a tree with no comment in it is BLIND, not clean" 6 "$code"
has "L4 ...and says it read nothing"                      "$out" "read nothing"
out="$(bash "$SCRIPT" "$T/does-not-exist" 2>&1)"; code=$?
rc "L5 an unreadable root is exit 6" 6 "$code"

section "M. the argument contract"
rc "M1 an unknown flag is a usage error"  2 "$(bash "$SCRIPT" --nope >/dev/null 2>&1; echo $?)"
rc "M2 two roots is a usage error"        2 "$(bash "$SCRIPT" "$T/a" "$T/b" >/dev/null 2>&1; echo $?)"
rc "M3 --summon is refused, not ignored"  2 "$(bash "$SCRIPT" --summon >/dev/null 2>&1; echo $?)"

echo
summary
