#!/usr/bin/env bash
# landing-drift.test.sh -- witness for bin/landing-drift.sh, offline.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/landing-drift.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp
mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "api "*/contents/*) [ -n "${HAS_AUTOMERGE:-}" ] && { echo abc123; exit 0; }; exit 1 ;;
  "api "*)            [ -n "${GH_FAIL:-}" ] && { echo "$GH_FAIL" >&2; exit 1; }
                      printf '%s\n' "$SETTINGS"; exit 0 ;;
  "pr list")          [ -n "${GH_FAIL:-}" ] && { echo "$GH_FAIL" >&2; exit 1; }
                      cat "$PRS"; exit 0 ;;
esac
echo "fake gh: unexpected call: $*" >&2; exit 1
EOF
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"
export SETTINGS=$'main\ttrue\ttrue'

echo '[]' > "$T/none.json"
cat > "$T/pile.json" <<'EOF'
[{"isDraft":false,"mergeStateStatus":"CLEAN","createdAt":"2020-01-01T00:00:00Z"},
 {"isDraft":false,"mergeStateStatus":"CLEAN","createdAt":"2020-01-02T00:00:00Z"}]
EOF
cat > "$T/unknown.json" <<'EOF'
[{"isDraft":false,"mergeStateStatus":"UNKNOWN","createdAt":"2020-01-01T00:00:00Z"}]
EOF
cat > "$T/fresh.json" <<'EOF'
[{"isDraft":true,"mergeStateStatus":"CLEAN","createdAt":"2020-01-01T00:00:00Z"},
 {"isDraft":false,"mergeStateStatus":"BLOCKED","createdAt":"2020-01-01T00:00:00Z"}]
EOF

run() { PRS="$1" bash "$SCRIPT" "${@:2}" 2>&1; }

echo "landing-drift.test.sh"

section "A. a pile is a finding"
OUT="$(run "$T/pile.json" o/r)"; RC=$?
rc  "A1 exits 1" 1 "$RC"
has "A2 counts both" "$OUT" "2"
has "A3 names the flag" "$OUT" "stranded"

section "B. nothing open is clean"
OUT="$(run "$T/none.json" o/r)"; RC=$?
rc  "B1 exits 0" 0 "$RC"
has "B2 says so" "$OUT" "0 finding(s)"

section "C. a gh failure is BLIND, not clean"
OUT="$(GH_FAIL='HTTP 401' run "$T/none.json" o/r)"; RC=$?
rc  "C1 exits 6" 6 "$RC"
has "C2 admits it" "$OUT" "BLIND"

section "D. UNKNOWN mergeability is BLIND, not an empty pile"
OUT="$(run "$T/unknown.json" o/r)"; RC=$?
rc  "D1 exits 6" 6 "$RC"
has "D2 names the state" "$OUT" "UNKNOWN"

section "E. a default branch that is not main is drift"
OUT="$(SETTINGS=$'master\ttrue\ttrue' run "$T/none.json" o/r)"; RC=$?
rc  "E1 exits 1" 1 "$RC"
has "E2 names the flag" "$OUT" "branch"

section "F. a draft, and a pull request nothing can merge, are not a pile"
OUT="$(run "$T/fresh.json" o/r)"; RC=$?
rc  "F1 exits 0" 0 "$RC"

section "G. the route is read, not assumed"
OUT="$(HAS_AUTOMERGE=1 run "$T/none.json" o/r --json)"; RC=$?
rc  "G1 exits 0" 0 "$RC"
has "G2 reports the workflow route" "$OUT" '"route":"workflow"'
OUT="$(run "$T/none.json" o/r --json)"
has "G3 reports the agent route without one" "$OUT" '"route":"agent"'

section "H. the argument contract"
bash "$SCRIPT" >/dev/null 2>&1; rc "H1 no argument is a usage error" 2 "$?"
bash "$SCRIPT" --nope >/dev/null 2>&1; rc "H2 unknown flag is a usage error" 2 "$?"

summary
