#!/usr/bin/env bash
# answered.test.sh -- unit test for bin/lib/answered.sh's issue_answered(),
# which etiquette.sh and decision-rot.sh both read comments through.
#
# WHY THIS EXISTS (realisateur#553): issue_answered folded "no qualifying
# comment at all" and "a qualifying comment exists but predates the stamp
# era" into the same return (1), so a pre-era human answer was silently
# indistinguishable from no answer. Zach answered chezz#4 three times because
# of it. This pins the three-way split directly against the function, not
# just against etiquette.sh's summary line.
#
# HERMETIC: a fake `gh` on PATH answers `api .../comments` from a fixture.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
LIB="$(cd "$(dirname "$0")/.." && pwd)/lib/answered.sh"
[ -r "$LIB" ] || { echo "FAIL: $LIB missing"; exit 1; }
harness_tmp

mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
# api repos/<o>/<r>/issues/<n>/comments -- $DATE_FIXTURE names the ISO date
# the fixed --jq expression should resolve to, or nothing for no comments.
if [ "$1" = "api" ]; then
  [ -n "${GH_API_FAIL:-}" ] && exit 1
  [ -s "${DATE_FIXTURE:-/dev/null}" ] && cat "$DATE_FIXTURE"
  exit 0
fi
exit 64
EOF
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"
# shellcheck source=bin/lib/answered.sh
. "$LIB"

echo "answered.test.sh"

section "issue_answered's four-way split"

: > "$T/date.txt"
DATE_FIXTURE="$T/date.txt" issue_answered o/r 1
rc "1 no qualifying comment at all -- NOT ANSWERED (1)" 1 "$?"

echo "2026-08-19" > "$T/date.txt"
DATE_FIXTURE="$T/date.txt" issue_answered o/r 2
rc "2 a post-era comment -- ANSWERED (0)" 0 "$?"

echo "2026-08-01" > "$T/date.txt"
DATE_FIXTURE="$T/date.txt" issue_answered o/r 3
rc "3 a pre-era comment -- DISCARDED (3), not folded into 1" 3 "$?"

GH_API_FAIL=1 DATE_FIXTURE="$T/date.txt" issue_answered o/r 4
rc "4 gh itself fails -- BLIND (2), never claimed as answered or unanswered" 2 "$?"

section "the era boundary is inclusive of the cutoff date itself"
echo "$ANSWERED_STAMP_ERA" > "$T/date.txt"
DATE_FIXTURE="$T/date.txt" issue_answered o/r 5
rc "5 a comment ON the era date counts as ANSWERED, not DISCARDED" 0 "$?"

echo
summary
