#!/usr/bin/env bash
# verify-runtime.sh -- the shared runtime, provoked.
#
# WHY THIS EXISTS. `skel/lib/verb.sh` is sourced by every bashified utility in
# the ecosystem and, until 2026-08-02, had NO test of its own. It drifted into
# four dialects across seven repos while its own header said it existed "so
# nineteen utilities cannot drift into nineteen dialects" -- and nothing could
# have noticed, because nothing ever ran it.
#
# The de-fork merged those dialects into one union. That merge is only safe if
# the union is BACKWARD COMPATIBLE with what the old copies offered, so section
# A asserts the pre-existing surface survives and sections B-D assert the
# adopted supersets actually work. A union that silently dropped a function
# would break a verb in a repo nobody was looking at.
#
# Hermetic: builds throwaway verbs in a temp dir. Sources nothing from PATH.
#
# usage: ./bashify/test/verify-runtime.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
RUNTIME="$ROOT/skel/lib/verb.sh"
[ -f "$RUNTIME" ] || { echo "runtime under test not found: $RUNTIME"; exit 1; }

pass=0; fail=0
ok()   { printf '  ok   %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/lib" "$WORK/bin"
cp "$RUNTIME" "$WORK/lib/verb.sh"
export XDG_DATA_HOME="$WORK/share"

# mkverb <name> <preamble...> -- a minimal verb that sources the runtime, then
# runs whatever body is piped in on stdin.
mkverb() {
  local name="$1"; shift
  { printf '#!/usr/bin/env bash\nSELF="%s"\nVERB_NAME=%s\nVERB_SUMMARY="a test verb"\n' "$WORK" "$name"
    printf '%s\n' "$@"
    printf '. "$SELF/lib/verb.sh"\n'
    cat
  } > "$WORK/bin/$name"
  chmod +x "$WORK/bin/$name"
}
rc() { "$WORK/bin/$1" "${@:2}" >/dev/null 2>&1; printf '%s' "$?"; }

# CAPTURE, then match. Never `verb ... | grep -q`.
#
# This file runs under `set -o pipefail`, so a pipeline takes the exit status
# of its LAST FAILING member -- which for `gapper 2>&1 | grep -q x` is gapper's
# exit 4, not grep's 0. The assertion then reports "the message is missing"
# about a message that was printed correctly, which is the harness damaging its
# own evidence. Cost three false failures on this file's first run; the same
# shape as the range-test draft that grepped un-de-escaped troff and reported
# five documented flags as absent.
says()  { local out; out="$("$WORK/bin/$1" "${@:3}" 2>&1)"; printf '%s' "$out" | grep -q -- "$2"; }

printf -- '-- A. the pre-existing surface survives the union\n'
# Every function and variable the 105-line and 155-line copies offered. If the
# merge dropped one, a verb in some repo breaks the moment it is propagated.
for fn in verb_die verb_gap verb_broke verb_blind verb_need_summon verb_parse verb_usage; do
  grep -qE "^$fn\(\)" "$RUNTIME" && ok "A: $fn() still defined" || bad "A: $fn() MISSING from the union"
done
# Not anchored to column 0: VERB_SUMMON_COST is now assigned inside the cost
# if/else and is indented. An anchored pattern called a set variable missing.
for v in VERB_NAME VERB_SUMMARY VERB_CAN_SUMMON VERB_SUMMON_COST VERB_SUMMON VERB_JSON VERB_QUIET; do
  grep -qE "^[[:space:]]*$v=" "$RUNTIME" && ok "A: $v still set" || bad "A: $v MISSING from the union"
done

printf -- '-- B. exit vocabulary, including the adopted 7\n'
mkverb refuser 'VERB_CAN_SUMMON=0' <<'EOF'
verb_parse "$@"
verb_refuse "this is out of scope on principle"
EOF
check "B1 verb_refuse exits 7" "$(rc refuser)" "7"
out="$("$WORK/bin/refuser" 2>&1)"
printf '%s' "$out" | grep -q 'REFUSED' && ok "B2 it says REFUSED" || bad "B2 it says REFUSED"
# The load-bearing half of the 4-vs-7 rule: a refusal must state that no summon
# lifts it, or --force/--summon degrade into a general-purpose "do it anyway".
printf '%s' "$out" | grep -q 'No summon lifts it' \
  && ok "B3 it states that no summon lifts a refusal" || bad "B3 it states that no summon lifts a refusal"
mkverb gapper 'VERB_CAN_SUMMON=0' <<'EOF'
verb_parse "$@"
verb_gap "not built yet"
EOF
check "B4 verb_gap still exits 4" "$(rc gapper)" "4"
# This exact string is doctested by man/bashify.1's EXAMPLES and by
# bibliothecaire's man/verse.1. Adopting gardien's phrasing here broke both.
# The 4-vs-7 doctrine came across in the comments; the output string did not.
says gapper 'no tooling exists for this yet' \
  && ok "B5 the gap wording pages doctest is unchanged" \
  || bad "B5 the gap wording pages doctest is unchanged"

printf -- '-- C. the write vocabulary is OPT-IN\n'
# A read-only verb accepting --force would advertise a power it does not have.
mkverb reader 'VERB_CAN_SUMMON=0' <<'EOF'
verb_parse "$@"
printf 'dry=%s force=%s\n' "$VERB_DRYRUN" "$VERB_FORCE"
EOF
check "C1 --dry-run rejected when VERB_CAN_WRITE=0" "$(rc reader --dry-run)" "2"
check "C2 -n rejected when VERB_CAN_WRITE=0"        "$(rc reader -n)"        "2"
check "C3 --force rejected when VERB_CAN_WRITE=0"   "$(rc reader --force)"   "2"
check "C4 -f rejected when VERB_CAN_WRITE=0"        "$(rc reader -f)"        "2"
"$WORK/bin/reader" --help 2>&1 | grep -q -- '--dry-run' \
  && bad "C5 --help hides write flags a read-only verb lacks" \
  || ok "C5 --help hides write flags a read-only verb lacks"

mkverb writer 'VERB_CAN_SUMMON=0' 'VERB_CAN_WRITE=1' <<'EOF'
verb_parse "$@"
printf 'dry=%s force=%s\n' "$VERB_DRYRUN" "$VERB_FORCE"
EOF
check "C6 --dry-run accepted when VERB_CAN_WRITE=1" "$(rc writer --dry-run)" "0"
check "C7 --dry-run sets VERB_DRYRUN" "$("$WORK/bin/writer" --dry-run)" "dry=1 force=0"
check "C8 -f sets VERB_FORCE"         "$("$WORK/bin/writer" -f)"        "dry=0 force=1"
check "C9 both together"              "$("$WORK/bin/writer" -n -f)"     "dry=1 force=1"
"$WORK/bin/writer" --help 2>&1 | grep -q -- '--dry-run' \
  && ok "C10 --help lists write flags when the verb declares them" \
  || bad "C10 --help lists write flags when the verb declares them"

printf -- '-- D. cost is MEASURED, not typed\n'
# An explicit cost must win, or a verb that knows its own cost (bashify) is
# silently overwritten by a file it never heard of.
mkverb told 'VERB_CAN_SUMMON=1' 'VERB_SUMMON_COST="a stated cost"' <<'EOF'
verb_parse "$@"
EOF
"$WORK/bin/told" --help 2>&1 | grep -q 'a stated cost' \
  && ok "D1 an explicit VERB_SUMMON_COST wins" || bad "D1 an explicit VERB_SUMMON_COST wins"

mkverb untold 'VERB_CAN_SUMMON=1' <<'EOF'
verb_parse "$@"
EOF
"$WORK/bin/untold" --help 2>&1 | grep -q 'UNMEASURED' \
  && ok "D2 with no measurement it says UNMEASURED, not a number" \
  || bad "D2 with no measurement it says UNMEASURED, not a number"

# The cost file is keyed on VERB_NAME, so this must write and read as the SAME
# verb. The first draft recorded as `recorder` and read as `untold`, then
# blamed the runtime for per-verb cost files -- which are the correct design.
mkverb untold_writer 'VERB_CAN_SUMMON=1' 'VERB_NAME=untold' <<'EOF'
verb_parse "$@"
verb_record_cost "17s of one call, measured today"
EOF
"$WORK/bin/untold_writer" >/dev/null 2>&1
says untold '17s of one call' --help \
  && ok "D3 a recorded cost is read by the NEXT caller of that verb" \
  || bad "D3 a recorded cost is read by the next caller of that verb"
# Bookkeeping must never be able to break the verb that called it.
mkverb unwritable 'VERB_CAN_SUMMON=1' 'VERB_COST_FILE=/proc/nonexistent/cost' <<'EOF'
verb_parse "$@"
verb_record_cost "x"
printf 'survived\n'
EOF
check "D4 an unwritable cost file does not kill the verb" "$("$WORK/bin/unwritable")" "survived"

printf -- '-- E. VERB_EXITS lets a verb name only what it reaches\n'
mkverb narrow 'VERB_CAN_SUMMON=0' 'VERB_EXITS="0 kept  2 usage  7 refused"' <<'EOF'
verb_parse "$@"
EOF
h="$("$WORK/bin/narrow" --help 2>&1)"
printf '%s' "$h" | grep -q 'exit: 0 kept  2 usage  7 refused' \
  && ok "E1 VERB_EXITS is honoured verbatim" || bad "E1 VERB_EXITS is honoured verbatim"
printf '%s' "$h" | grep -q 'needs-summon' \
  && bad "E2 it does not advertise codes the verb cannot reach" \
  || ok "E2 it does not advertise codes the verb cannot reach"
"$WORK/bin/reader" --help 2>&1 | grep -q '7 refused' \
  && ok "E3 the DEFAULT vocabulary now includes 7" || bad "E3 the default vocabulary includes 7"

printf -- '-- F. the cost boundary is untouched by all of the above\n'
check "F1 --summon still rejected by a non-spending verb" "$(rc reader --summon)" "2"
check "F2 -s still rejected as a near-miss"               "$(rc reader -s)"       "2"
check "F3 -S still rejected as a near-miss"               "$(rc reader -S)"       "2"
# -f is now a real flag on writing verbs. It must NOT have become a near-miss
# escape hatch for the cost flag on one, which would be the worst possible
# interaction between the two features merged here.
check "F4 -s is still rejected on a WRITING verb too"     "$(rc writer -s)"       "2"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
