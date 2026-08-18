#!/usr/bin/env bash
#
# discipline.test.sh -- the guard that replaced restamp-discipline's "a pass
# that reached nothing is not a clean pass".
#
# The failure this is built against is NOT "prints the wrong text". It is
# "prints NOTHING, or half, and exits 0" -- discipline silently absent, which
# is the first failure pattern BUILD-DISCIPLINE.md names and the exact way the
# stamped baseline rotted for weeks while hygiene-lint reported OK.
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="$REPO/bin/discipline.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

printf 'discipline.sh\n'

# --- A: it prints the real thing ---------------------------------------------
out="$("$CMD" 2>&1)"; rc=$?
eq "A1  exits 0 against the real BUILD-DISCIPLINE.md" "$rc" "0"

rows="$(printf '%s\n' "$out" | grep -c '^- \[ \]')"
if [ "$rows" -ge 8 ]; then ok "A2  prints a full checklist ($rows rows)"
else bad "A2  prints a full checklist" "only $rows rows"; fi

# The two halves must BOTH be present. The 2026-08-14 post-mortem found copies
# carrying the checklist and missing the entire protocols block, which is how a
# project never learns about the senechal cross-write.
printf '%s' "$out" | grep -q '^## Build discipline' \
  && ok "A3  carries the build-discipline half" || bad "A3  carries the build-discipline half"
printf '%s' "$out" | grep -q '^## Ecosystem protocols' \
  && ok "A4  carries the ecosystem-protocols half" || bad "A4  carries the ecosystem-protocols half"

# The protocol COMMAND NAMES must survive, because install-shims.sh derives
# every shim from these backticked tokens. If they vanish, working guards are
# deleted as a side effect of a docs edit.
for c in notify-senechal check-project-busy consulte; do
  printf '%s' "$out" | grep -q "$c" \
    && ok "A5  names \`$c\`" || bad "A5  names \`$c\`"
done

# --- B: the halves are actually split ----------------------------------------
printf '%s' "$("$CMD" --checklist)" | grep -q '^## Ecosystem protocols' \
  && bad "B1  --checklist stops before the protocols" || ok "B1  --checklist stops before the protocols"
printf '%s' "$("$CMD" --protocols)" | grep -q '^- \[ \] Fails' \
  && bad "B2  --protocols excludes the checklist" || ok "B2  --protocols excludes the checklist"

# --- C: FAILS LOUD. This is the point of the file. ---------------------------
# A missing source must not read as an empty baseline.
mkdir -p "$T/fake/bin"; cp "$CMD" "$T/fake/bin/"
out="$("$T/fake/bin/discipline.sh" 2>&1)"; rc=$?
eq "C1  a missing BUILD-DISCIPLINE.md exits nonzero" "$rc" "1"
printf '%s' "$out" | grep -q 'FINDING' \
  && ok "C1b and says a missing checkout is a FINDING, in words" \
  || bad "C1b and says a missing checkout is a FINDING, in words" "$out"

# A source whose heading moved must not silently yield nothing.
printf '# nothing here\n' > "$T/fake/BUILD-DISCIPLINE.md"
out="$("$T/fake/bin/discipline.sh" 2>&1)"; rc=$?
eq "C2  an empty extraction exits nonzero" "$rc" "1"
printf '%s' "$out" | grep -qi 'EMPTY' \
  && ok "C2b and names the empty extraction" || bad "C2b and names the empty extraction" "$out"

# A TRUNCATED baseline is the nastiest case: it looks like success.
{ printf '## The baseline\n```\n## Build discipline\n'
  printf -- '- [ ] one\n- [ ] two\n'
  printf '```\n'; } > "$T/fake/BUILD-DISCIPLINE.md"
out="$("$T/fake/bin/discipline.sh" 2>&1)"; rc=$?
eq "C3  a truncated checklist exits nonzero rather than printing part" "$rc" "1"
printf '%s' "$out" | grep -q 'partial' \
  && ok "C3b and refuses to pass a partial discipline off as the whole one" \
  || bad "C3b and refuses to pass a partial discipline off as the whole one" "$out"

# --- D: usage ----------------------------------------------------------------
"$CMD" --help >/dev/null 2>&1; eq "D1  --help exits 0" "$?" "0"
"$CMD" --nope  >/dev/null 2>&1; eq "D2  an unknown flag exits nonzero" "$?" "1"
[ "$("$CMD" --path)" = "$REPO/BUILD-DISCIPLINE.md" ] \
  && ok "D3  --path names the one source" || bad "D3  --path names the one source"

summary
