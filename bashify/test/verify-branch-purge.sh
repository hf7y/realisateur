#!/usr/bin/env bash
# verify-branch-purge.sh -- the guard that re-asks the question after emit.
#
# THE LOAD-BEARING ASSERTIONS ARE F3 AND F5.
#
# F3: an exemption naming a file that no longer matches must be reported STALE
#     and must exit 1. An exemption list is the single easiest place in a
#     codebase to leave a dead entry standing forever, and a dead entry is
#     indistinguishable from a live one to every reader after the first.
#
# F5: the lib/verb.sh exemption must apply ONLY while the file is byte-
#     identical to the skeleton. bashify.sh already makes byte-identity load-
#     bearing for this same exemption; a looser test here silently widens it,
#     and a widened exemption is how a runtime forks into four dialects
#     without anything noticing for a month.
#
# Hermetic: fixture repos and a fixture schedule dir in a temp dir. Never reads
# the live ecosystem, never writes outside its temp dir.
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"   # bashify/
GUARD="$ROOT/lib/branch-purge.sh"
SKEL="$ROOT/skel/lib/verb.sh"

pass=0; fail=0
ok()   { printf '  ok   %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export BASHIFY_SCHED="$WORK/sched"
export BASHIFY_EXEMPT="$WORK/exempt.tsv"
mkdir -p "$BASHIFY_SCHED/schedule"
: > "$BASHIFY_EXEMPT"
G() { git -c user.email=t@t -c user.name=t -C "$1" "${@:2}"; }

# mkbranch <name> -- repo with a bashified branch; echoes its path
mkbranch() {
  local d="$WORK/repos/$1"
  mkdir -p "$d"; G "$d" init -q -b main
  echo x > "$d/README.md"; G "$d" add -A; G "$d" commit -qm init
  G "$d" checkout -q -b bashified
  printf 'PROJECT_REPO_PATH=%s\n' "$d" > "$BASHIFY_SCHED/schedule/$1.conf"
  printf '%s' "$d"
}
commit() { G "$1" add -A; G "$1" commit -qm f >/dev/null 2>&1; }

echo "== F. the promise, re-asked after emit =="

# F1 -- a branch that has grown a vendor-naming file must FAIL.
r="$(mkbranch fixdirty)"
mkdir -p "$r/bin"
printf '#!/usr/bin/env bash\nclaude -p "do the thing"\n' > "$r/bin/later"
commit "$r"
"$GUARD" fixdirty >/dev/null 2>&1
check "F1 a branch carrying a vendor mention exits 1" "$?" "1"
check "F1 and the file is named in the report" \
  "$("$GUARD" fixdirty 2>/dev/null | grep -c 'bin/later')" "1"

# F2 -- a recorded exemption, with a reason, clears it.
printf 'fixdirty\tbin/later\tEXEMPT-SUMMON-DOC\tthe mention documents the summon mechanism\n' > "$BASHIFY_EXEMPT"
"$GUARD" fixdirty >/dev/null 2>&1
check "F2 a recorded exemption clears the finding" "$?" "0"

# F3 -- THE STALE CASE. The exemption stays; the file stops matching.
printf '#!/usr/bin/env bash\necho plain\n' > "$r/bin/later"
commit "$r"
out="$("$GUARD" fixdirty 2>&1)"; rc=$?
check "F3 an exemption whose file no longer matches is STALE" \
  "$(printf '%s' "$out" | grep -c 'STALE EXEMPTIONS')" "1"
check "F3 and a stale exemption exits 1, not 0" "$rc" "1"
: > "$BASHIFY_EXEMPT"

echo
echo "== G. the derived exemption, and its limit =="

# F4 -- lib/verb.sh byte-identical to the skeleton is exempt with NO tsv entry.
r="$(mkbranch fixruntime)"
mkdir -p "$r/lib"
cp "$SKEL" "$r/lib/verb.sh"
commit "$r"
check "F4 the skeleton runtime names an agent (so the case is real)" \
  "$([ "$(grep -ciE 'agent' "$SKEL")" -gt 0 ] && echo yes)" "yes"
"$GUARD" fixruntime >/dev/null 2>&1
check "F4 byte-identical lib/verb.sh is exempt without a tsv entry" "$?" "0"

# F5 -- THE LIMIT. One byte of drift and the exemption stops applying.
printf '\n# a local change\n' >> "$r/lib/verb.sh"
commit "$r"
out="$("$GUARD" fixruntime 2>&1)"; rc=$?
check "F5 a DRIFTED lib/verb.sh is no longer exempt" "$rc" "1"
check "F5 and the report says drift, not a generic vendor hit" \
  "$(printf '%s' "$out" | grep -c 'DRIFTED')" "1"

echo
echo "== H. refusing to be silent =="

# H1 -- a clean branch passes.
r="$(mkbranch fixclean)"
mkdir -p "$r/bin"
printf '#!/usr/bin/env bash\necho tidy\n' > "$r/bin/tidy"
commit "$r"
"$GUARD" fixclean >/dev/null 2>&1
check "H1 a genuinely clean branch exits 0" "$?" "0"

# H2 -- a name matching nothing must not exit 0.
"$GUARD" no-such-project-anywhere >/dev/null 2>&1
check "H2 a name matching nothing exits 1, never 0" "$?" "1"

# H3 -- the compound case, end to end on a real branch fixture. `subagent`
# must be caught: this is the token that decided the anchoring in surface.sh.
r="$(mkbranch fixcompound)"
mkdir -p "$r/bin"
printf '#!/usr/bin/env bash\n# dispatched by the subagent runner\necho hi\n' > "$r/bin/thing"
commit "$r"
"$GUARD" fixcompound >/dev/null 2>&1
check "H3 'subagent' on a branch is caught, not missed by an anchor" "$?" "1"

echo
printf 'passed %d, failed %d\n' "$pass" "$fail"
exit $(( fail > 0 ? 1 : 0 ))
