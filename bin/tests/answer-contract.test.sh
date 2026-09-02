#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
. "$ROOT/lib/answer-contract.sh"

section "A. the function exists and returns text"
out="$(answer_contract_text)"
[ -n "$out" ] && ok "A1 answer_contract_text prints something" || bad "A1 answer_contract_text printed nothing"

section "B. rules A-D, by name"
has "B1 A -- direction, not instruction" "$out" 'Direction, not instruction'
has "B2 A -- re-derive from current state" "$out" 'CURRENT state'
has "B3 B -- re-probe the premise" "$out" 'Re-probe the premise'
has "B4 B -- splits by reversibility" "$out" 'reversible'
has "B5 B -- names the irreversible half" "$out" 'irreversible'
has "B6 C -- extract standing direction silently" "$out" 'standing direction'
has "B7 D -- no clean-check reports" "$out" 'No clean-check reports'

section "C. stable across calls (no timestamp, no randomness baked in)"
eq "C1 two calls print the same text" "$(answer_contract_text)" "$out"

summary
exit $?
