#!/usr/bin/env bash
# office-economy test suite. No agent, no network. The named assertion is the
# witness, not "the tests passed".
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin"
pass=0; fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL  %s\n         %s\n' "$1" "${2:-}"; fail=$((fail+1)); }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
W="$tmp/workers"; mkdir -p "$W"
export OFFICE_COMMISSIONES="$tmp/board.psv" OFFICE_WORKERS="$W"

printf 'office-economy tests\n\n== persona: identity + obfuscation ==\n'
"$BIN/persona" --seed 42 > "$tmp/p1"; "$BIN/persona" --seed 42 > "$tmp/p2"
diff -q "$tmp/p1" "$tmp/p2" >/dev/null && ok "same seed -> byte-identical worker" || bad "seed reproducibility"
[ "$("$BIN/persona" --seed 1)" != "$("$BIN/persona" --seed 2)" ] && ok "different seed -> different worker" || bad "seeds collide"
# THE OBFUSCATION GUARANTEE: no vendor/model marker anywhere, over many draws.
leak=""; for s in $(seq 1 40); do
  "$BIN/persona" --seed "$s" | grep -iEq 'claude|anthropic|\bmodel\b|\bai\b|assistant|gpt|llm' && leak="seed $s"
done
[ -z "$leak" ] && ok "no vendor/model marker in 40 identities" || bad "vendor marker leaked" "$leak"
# six traits, all in range
n=$("$BIN/persona" --seed 3 | grep -cE '^(industriousness|thoroughness|frugality|risk_tolerance|sociability|curiosity)=[0-9]+$')
[ "$n" -eq 6 ] && ok "six traits present, integer-valued" || bad "trait count" "got $n"
oob=$("$BIN/persona" --seed 3 | awk -F= '/^(ind|tho|fru|ris|soc|cur)/{if($2<0||$2>100)print}')
[ -z "$oob" ] && ok "traits within 0..100" || bad "trait out of range" "$oob"

printf '\n== fitness: reads the real ledger shape ==\n'
cat > "$tmp/led.psv" <<'EOF'
1|GENESIS|office|GENESIS|0||h|peg
2|t|TREASURY|APPROP|1000||h|seed
3|t|marius|HIRE|50||h|hired
4|t|marius|EARN|30||h|c
5|t|marius|RENT|1||h|tick
6|t|aulus|HIRE|50||h|hired
7|t|aulus|RENT|1||h|tick
8|t|aulus|RENT|1||h|tick
EOF
out="$("$BIN/fitness" marius --ledger "$tmp/led.psv")"
case "$out" in *"score=79"*) ok "fitness computes balance+activity (marius=79)";; *) bad "fitness score" "$out";; esac
# ranked --all: marius (earned) above aulus (only rent)
first="$("$BIN/fitness" --all --ledger "$tmp/led.psv" | head -1 | awk '{print $1}')"
[ "$first" = marius ] && ok "--all ranks the earner above the rent-payer" || bad "ranking" "top=$first"
# BLIND must not read as score 0
"$BIN/fitness" marius --ledger "$tmp/none" >/dev/null 2>&1; [ "$?" -eq 6 ] && ok "unreadable ledger is BLIND (6), not score 0" || bad "BLIND path"
"$BIN/fitness" ghost --ledger "$tmp/led.psv" >/dev/null 2>&1; [ "$?" -eq 3 ] && ok "unknown worker is exit 3, distinct from BLIND" || bad "unknown-worker exit"

printf '\n== commissio: the decision-economizer ==\n'
"$BIN/persona" --seed 11 > "$W/frugal.worker"
sed -i 's/^login=.*/login=frugal/;s/^frugality=.*/frugality=90/;s/^industriousness=.*/industriousness=20/;s/^risk_tolerance=.*/risk_tolerance=20/' "$W/frugal.worker"
"$BIN/persona" --seed 12 > "$W/eager.worker"
sed -i 's/^login=.*/login=eager/;s/^frugality=.*/frugality=20/;s/^industriousness=.*/industriousness=90/;s/^risk_tolerance=.*/risk_tolerance=90/' "$W/eager.worker"
"$BIN/commissio" post "index the archive and verify the hash chain end to end" 40 "office-worm verify returns chain intact" --as romulus >/dev/null 2>&1
"$BIN/commissio" post "tidy up" 5 "looks nicer" --as romulus >/dev/null 2>&1
"$BIN/commissio" post "draft the report" 35 "a report" --as romulus >/dev/null 2>&1
fm=$("$BIN/commissio" match frugal | wc -l); em=$("$BIN/commissio" match eager | wc -l)
[ "$fm" -eq 1 ] && ok "frugal worker takes only the well-paid, well-specified bounty (1)" || bad "frugal match" "took $fm"
[ "$em" -eq 3 ] && ok "eager worker takes all three incl cheap/vague (3)" || bad "eager match" "took $em"
[ "$em" -gt "$fm" ] && ok "personality changes the decision with no model in the loop" || bad "traits do not differentiate"
# match is deterministic
[ "$("$BIN/commissio" match frugal | md5sum)" = "$("$BIN/commissio" match frugal | md5sum)" ] && ok "match is deterministic" || bad "match nondeterministic"
"$BIN/commissio" settle 1 eager >/dev/null 2>&1
"$BIN/commissio" list | grep -q 'DONE.*@eager' && ok "settle marks DONE and records the assignee" || bad "settle"
"$BIN/commissio" match nobody >/dev/null 2>&1; [ "$?" -eq 4 ] && ok "match on an unknown worker is exit 4" || bad "unknown-worker match exit"

printf '\n== evolve: fitness is heritable ==\n'
cat > "$tmp/led2.psv" <<'EOF'
1|GENESIS|office|GENESIS|0||h|peg
2|t|marius|HIRE|50||h|h
3|t|marius|EARN|70||h|c
4|t|livia|HIRE|50||h|h
5|t|livia|EARN|10||h|c
6|t|aulus|HIRE|50||h|h
7|t|aulus|RENT|1||h|t
EOF
for w in marius livia aulus; do "$BIN/persona" --seed 7 | sed "s/^login=.*/login=$w/" > "$W/$w.worker"; done
rep="$("$BIN/evolve" --ledger "$tmp/led2.psv" --workers "$W" --seed 5)"
printf '%s\n' "$rep" | grep -q '^KEEP   marius' && ok "top earner is KEEP" || bad "evolve keep" "$rep"
printf '%s\n' "$rep" | grep -q '^RETIRE aulus' && ok "rent-only worker is RETIRE" || bad "evolve retire"
printf '%s\n' "$rep" | grep -q '^HIRE' && ok "a next-generation child is proposed from survivors" || bad "evolve hire"
[ "$("$BIN/evolve" --ledger "$tmp/led2.psv" --workers "$W" --seed 5 | md5sum)" = "$("$BIN/evolve" --ledger "$tmp/led2.psv" --workers "$W" --seed 5 | md5sum)" ] && ok "evolve is deterministic under --seed" || bad "evolve nondeterministic"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
