#!/usr/bin/env bash
set -uo pipefail  # selfdev-home-check.test.sh -- witness for bin/selfdev-home-check.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
[ -x "$REPO_BIN/selfdev-home-check.sh" ] || { echo "FAIL: selfdev-home-check.sh not executable"; exit 1; }
harness_tmp

mkdir -p "$T/bin/lib"   # a stub checkout: the script plus cli-guard, and a fake "land-selfdev.sh" so CLASS 3 detection does not depend on the real bin/ directory's contents
cp "$REPO_BIN/selfdev-home-check.sh" "$T/bin/"
cp "$REPO_BIN/lib/cli-guard.sh" "$T/bin/lib/"
printf '#!/usr/bin/env bash\necho stub\n' > "$T/bin/land-selfdev.sh"
chmod +x "$T/bin/land-selfdev.sh"
SCRIPT="$T/bin/selfdev-home-check.sh"

run() { local r="$1"; shift; HOME_ROOT="$T/$r" SUDO='' "$SCRIPT" "$@" 2>&1; }   # SUDO='' keeps every case here off real sudo

mkhome() { # mkhome <root> <account> <extra top-level names...>
  local r="$1" acct="$2"; shift 2
  mkdir -p "$T/$r/$acct/.claude" "$T/$r/$acct/Documents" "$T/$r/$acct/tmp"
  local n; for n in "$@"; do
    case "$n" in
      *.sh) cp "$T/bin/land-selfdev.sh" "$T/$r/$acct/$n" ;;
      *)    : > "$T/$r/$acct/$n" ;;
    esac
  done
}

mkhome h1 clean
mkhome h1 residue dose-now.log handoff-body.md
mkhome h1 tooled land-selfdev.sh
mkhome h1 both dose-now.log land-selfdev.sh
mkdir -p "$T/h1/zach/.claude"; : > "$T/h1/zach/stray-file"   # the human's own account

out="$(run h1)"; run h1 >/dev/null 2>&1; got=$?
has  "A: a clean account reports ok"                 "$out" "ok    clean"
has  "B: residue is reported as DRIFT"               "$out" "DRIFT residue: outside the declared set: dose-now.log handoff-body.md"
has  "C: a stray host-tool copy is reported as TOOL, not DRIFT" \
     "$out" "TOOL  tooled: unmanaged copy of a host tool"
has  "C: names the file"                             "$out" "land-selfdev.sh"
has  "D: an account with both gets a TOOL line"       "$out" "TOOL  both"
has  "D: and a DRIFT line for the rest"               "$out" "DRIFT both: outside the declared set: dose-now.log"
hasnt "E: zach (the human's own account) is never visited" "$out" " zach"
rc   "F: no --strict is green even with findings"    0 "$got"

mkhome h1 tmpful
: > "$T/h1/tmpful/tmp/anything-at-all"
out2="$(run h1)"
hasnt "G: tmp's own contents never surface as a finding" "$out2" "anything-at-all"
has   "G: an otherwise-clean account with a full tmp is still ok" "$out2" "ok    tmpful"

run h1 --strict >/dev/null 2>&1; got=$?
rc "H: --strict exits 1 when something drifted" 1 "$got"

mkdir -p "$T/h2/onlyclean/.claude" "$T/h2/onlyclean/Documents" "$T/h2/onlyclean/tmp" "$T/h2/onlyclean/reports"
run h2 --strict >/dev/null 2>&1; got=$?
rc "H: --strict is green when nothing drifted" 0 "$got"

mkdir -p "$T/h3/bare"; : > "$T/h3/bare/loose-file"
out3="$(run h3 bare)"
has "I: naming an account bypasses the .claude discovery rule" "$out3" "DRIFT bare: outside the declared set: loose-file"

out4="$(run h3 ghost)"; run h3 ghost >/dev/null 2>&1; got=$?
has "J: a nonexistent account is BLIND"   "$out4" "BLIND ghost: no home"
rc  "J: BLIND exits 6 even without --strict" 6 "$got"

mkdir -p "$T/h4/zach/.claude"
out5="$(run h4)"; run h4 >/dev/null 2>&1; got=$?
has "K: an estate with only the human account is BLIND" "$out5" "BLIND"
rc  "K: exits 6" 6 "$got"

summary
