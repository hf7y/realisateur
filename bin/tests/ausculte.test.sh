#!/usr/bin/env bash
#
# SUBJECT: bin/ausculte.sh -- the composite "can Zach stop looking?" probe.
#
# TRAPS. Hermetic: every probe ausculte composes is replaced by a stub in a
# fake bin/ dir, so this suite cannot pass because the fleet happened to be
# healthy -- which is the failure the script under test exists to refuse.
# The exit ladder is the whole contract, so each rung is pinned separately:
# a DOWN must outrank a BLIND (a thing known broken is more actionable than a
# thing unseen), and a BLIND must never be reported as OK.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin/lib"
cp "$HERE/../ausculte.sh" "$TMP/bin/"
cp "$HERE/../lib/cli-guard.sh" "$TMP/bin/lib/"

# stub <name> <exit> [stdout] -- stand in for a probe ausculte shells out to.
stub() { printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\nexit %s\n' "${3:-}" "$2" > "$TMP/bin/$1"; chmod +x "$TMP/bin/$1"; }

# curl/ssh/gh are the network. Stubbed failing by default so nothing reaches out.
mkdir -p "$TMP/stub"
for c in curl ssh gh; do printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/stub/$c"; chmod +x "$TMP/stub/$c"; done
run() { PATH="$TMP/stub:$PATH" bash "$TMP/bin/ausculte.sh" "$@" 2>&1; }

echo "ausculte contract"

# --- the ladder ----------------------------------------------------------
stub decision-rot.sh 0
run rot >/dev/null; check "a clean probe exits 0" "$?" "0"

stub decision-rot.sh 1 "answered and still open"
run rot >/dev/null; check "a probe reporting rot is DOWN (5)" "$?" "5"

# THE ONE THAT MATTERS. cli-guard exits 2 on a usage error, which means
# ausculte called the probe WRONG. That is a defect in ausculte, not a fleet
# finding, and reporting it as DOWN would send someone hunting a healthy fleet.
stub decision-rot.sh 2 "usage"
out="$(run rot)"; check "a usage error from a probe is BLIND, not DOWN" "$?" "6"
case "$out" in *"fix ausculte"*) ok "...and it says the fault is ausculte's" ;;
  *) bad "usage error names itself" "got: $out" ;; esac

# --- BLIND is never folded into OK ---------------------------------------
rm -f "$TMP/bin/decision-rot.sh"
out="$(run rot)"; check "a missing probe is BLIND (6), never OK" "$?" "6"
case "$out" in *"NOT \"all clear\""*) ok "...and the summary refuses to read as all-clear" ;;
  *) bad "blind summary" "got: $out" ;; esac

# --- DOWN outranks BLIND -------------------------------------------------
stub decision-rot.sh 1 "rot found"
stub silence-audit.sh 2 "usage"
run rot silence >/dev/null
check "one probe DOWN and one BLIND exits DOWN" "$?" "5"

# --- usage ---------------------------------------------------------------
run nosuchprobe >/dev/null; check "an unknown probe is a usage error (2)" "$?" "2"

echo
summary
