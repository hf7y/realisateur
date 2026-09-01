#!/usr/bin/env bash
# reprise.test.sh -- a merge is not a delivery, and the difference is the point.
#
# HERMETICITY: no network, no gh, no live repo. `gh` is a stub on PATH whose
# answers are set per case, and REPRISE_REPO/REPRISE_TABLE point at a fixture
# so --apply can never reach the real origin. The one case that must NOT be
# tested against a live tracker is the FAIL case, because the assertion is that
# NOTHING is deleted -- a live run that got it wrong would delete for real.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
REPRISE="$REPO/bin/reprise.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# --- the stub tracker -------------------------------------------------------
# MERGED and PRESENT are independent on purpose: the whole contract is what
# happens when they disagree.
mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'STUB'
#!/usr/bin/env bash
if [ "$1 $2" = "pr create" ]; then
  prev=''
  for a in "$@"; do
    [ "$prev" = --body ] && [ -n "${GH_PR_CREATE_BODY:-}" ] && printf '%s' "$a" > "$GH_PR_CREATE_BODY"
    prev="$a"
  done
  exit 0
fi
case "$*" in
  *"/pulls/"*)     printf '%s\n' "${STUB_MERGED:-false}" ;;
  *"/contents/"*)  [ "${STUB_PRESENT:-no}" = yes ] || exit 1; printf 'abc123\n' ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$T/bin/gh"
PATH="$T/bin:$PATH"; export PATH

# --- the fixture repo -------------------------------------------------------
FIX="$T/repo"; mkdir -p "$FIX/bin/lib"
printf 'live\n' > "$FIX/bin/moved.sh"
TABLE="$FIX/bin/lib/handoffs.tsv"
printf '# fixture\nbin/moved.sh\thf7y/receiver\t42\tbin/moved.sh\n' > "$TABLE"
export REPRISE_REPO="$FIX" REPRISE_TABLE="$TABLE"

run() { STUB_MERGED="$1" STUB_PRESENT="$2" bash "$REPRISE" "${3:---check}" 2>&1; }
rcof() { STUB_MERGED="$1" STUB_PRESENT="$2" bash "$REPRISE" "${3:---check}" >/dev/null 2>&1; printf '%s' $?; }

echo "reprise.test.sh"

section "A. an unmerged PR owes, and collects nothing"
OUT="$(run false no)"
has "it reports the row as OWED"            "$OUT" "OWED"
eq  "and exits 0 -- waiting is not a fault" "$(rcof false no)" "0"
[ -f "$FIX/bin/moved.sh" ] && ok "the file is untouched" || bad "the file is untouched" "it was deleted while owed"

section "B. MERGED but ABSENT at the destination is a FAILURE, not a collection"
# This is the case the whole script exists for (#368): deleting here on the
# strength of a merge alone leaves the file in neither repo.
OUT="$(run true no)"
has "it names the merge"                    "$OUT" "MERGED but"
has "and says deleting would strand it"     "$OUT" "neither repo"
eq  "and exits 1, never 0"                  "$(rcof true no)" "1"
[ -f "$FIX/bin/moved.sh" ] && ok "NOTHING was deleted" || bad "NOTHING was deleted" "a merge alone was enough -- the trap this suite exists for"

section "C. MERGED and PRESENT is collectable"
OUT="$(run true yes)"
has "it reports the row as LANDED"          "$OUT" "LANDED"
has "and counts it collectable"             "$OUT" "1 collectable"
eq  "--check still exits 0"                 "$(rcof true yes)" "0"
has "--check says it did not act"           "$OUT" "NOT collected"
[ -f "$FIX/bin/moved.sh" ] && ok "--check deleted nothing" || bad "--check deleted nothing" "a check wrote"

section "D. BLIND is not a quiet zero"
OUT="$(REPRISE_TABLE=$T/nope bash "$REPRISE" --check 2>&1)"; rc=$?
has "a missing table says so"               "$OUT" "BLIND"
eq  "and exits 6, not 0"                    "$rc" "6"

section "E. a row with no destination path cannot pass"
printf '# fixture\nbin/moved.sh\thf7y/receiver\t42\n' > "$TABLE"
OUT="$(run true yes)"
has "it refuses the malformed row"          "$OUT" "names no destination"
eq  "and exits 1"                           "$(rcof true yes)" "1"

section "F. --apply's own PR body satisfies the ledger grammar it will be graded against"
git -C "$FIX" init -q -b main  # a body missing DELIVERS is what gh-sign refuses -- the collection commit landed with no PR ever opened for it, silently
git -C "$FIX" config user.email t@test.invalid
git -C "$FIX" config user.name test
printf 'live\n' > "$FIX/bin/moved.sh"
printf '# fixture\nbin/moved.sh\thf7y/receiver\t42\tbin/moved.sh\n' > "$TABLE"
git -C "$FIX" add -A && git -C "$FIX" commit -q -m fixture
git init -q --bare "$T/origin.git"
git -C "$FIX" remote add origin "$T/origin.git"
git -C "$FIX" push -q -u origin main
git -C "$FIX" fetch -q origin
BODYFILE="$T/pr-body"; rm -f "$BODYFILE"
STUB_MERGED=true STUB_PRESENT=yes GH_PR_CREATE_BODY="$BODYFILE" bash "$REPRISE" --apply >/dev/null 2>&1
[ -f "$BODYFILE" ] && ok "F1 --apply calls gh pr create" || bad "F1 --apply calls gh pr create" "no body was captured"
BODY="$(cat "$BODYFILE" 2>/dev/null)"
has "F2 the body carries a DEFERRED block"  "$BODY" "<!-- DEFERRED -->"
has "F3 the body carries a DELIVERS block"  "$BODY" "<!-- DELIVERS -->"

summary
