#!/usr/bin/env bash
# cutover-check.test.sh -- witness for bin/cutover-check.sh.
# HERMETIC behind CUTOVER_SSH: it grades the GRADING, never the estate.
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/bin/cutover-check.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp
echo "cutover-check.test.sh"

cat > "$T/ssh" <<'EOF'
#!/usr/bin/env bash
[ -n "${FACTS_FILE:-}" ] || { echo "stub ssh: no FACTS_FILE" >&2; exit 255; }
[ "$FACTS_FILE" = UNREACHABLE ] && { echo "ssh: connect to host port 22: No route to host" >&2; exit 255; }
cat "$FACTS_FILE"
EOF
chmod +x "$T/ssh"
run() { FACTS_FILE="$1" CUTOVER_SSH="$T/ssh" "$SCRIPT" --host fixture 2>&1; }

# Every MUST-KEEP token for one account; C grades per account.
keep() {
  local a="$1"
  printf 'KEEPCLAUDE %s\nKEEPGH %s\nKEEPREGISTRY %s\nKEEPVERDICT %s\nKEEPTMP %s\nKEEPSELFDEVGRP %s\nKEEPLINGER %s\n' \
    "$a" "$a" "$a" "$a" "$a" "$a" "$a"
}

# --- a host that has fully crossed ------------------------------------------
{
  echo PROBE-OK
  echo "BUILD 2026-09-08T053342Z"
  echo "ACCT dog"; echo "ACCT vkv23"
  echo "ROOTROSTER ok"; echo "SERVICEREAD ok"; echo "GATE ok"
  echo "LIBGHAPP ok"; echo "HOSTCRED ok"; echo "CLAUDETOK ok"
  echo "ROOTCRONROW"; echo "DISPATCHED"
  keep dog; keep vkv23
} > "$T/clean"

OUT="$(run "$T/clean")"; RC=$?
rc  "A0 a crossed host exits 0"                 0 "$RC"
has "A1 names the roster read"                  "$OUT" "A1 root reads the roster"
has "A6 names the carried library"              "$OUT" "A6 the build carries lib/gh-app-token.sh"
has "A9 a real DISPATCH is what counts"         "$OUT" "A9 the host state dir records a real DISPATCH"
has "A10 no verdict under /root"                "$OUT" "A10 no verdict state under /root"
has "C1 MUST-KEEP passes per account"           "$OUT" "C1 every account keeps ~/.claude/settings.json (2/2)"
hasnt "A0b a clean host claims no FAIL"         "$OUT" "FAIL"

# --- the host still in front of the migration -------------------------------
{
  echo PROBE-OK
  echo "BUILD 2026-09-01T030800Z"
  echo "ACCT crt"; echo "ACCT wtul"
  echo "ROOTROSTER fail"
  echo "GHROSTER present"
  echo "CLONE crt"; echo "CLONE wtul"
  echo "ACCTCRON crt"; echo "PRIVATEPIN wtul"; echo "ACCTSTATE crt"
  echo "CLONEPATHCONF _paced.monkey.conf"
  echo "SETUPDIR crt"; echo "ACCTLIBEXEC crt"; echo "ACCTLIBEXEC wtul"
  echo "TICKSTATUS crt"; echo "ACCTTICKCRON crt"; echo "ACCTAPPCONF crt"
  echo "ACCTGATE wtul"; echo "NIGHTLYREPO crt"; echo "INSTEADOF wtul"
  echo "HANDRUN crt"
  echo "ROOTVERDICT"; echo "ROOTBATCH"; echo "LEGACYSCHED"
  keep crt; keep wtul
} > "$T/dirty"

OUT="$(run "$T/dirty")"; RC=$?
rc  "B0 a host with residue exits 1"            1 "$RC"
has "B1 names the clones"                       "$OUT" "crt wtul"
has "B2 names the RUNNER row"                   "$OUT" "B2 no per-account RUNNER crontab row"
has "B7 names the per-account libexec"          "$OUT" "B7 no per-account ~/.local/libexec/selfdev/"
has "B13 names the insteadof rewrite"           "$OUT" "B13 no url.*.insteadof rewrite"
has "A10 the split-brain is a FAIL when present" "$OUT" "FAIL  A10"
has "A12 the legacy schedule dir is a FAIL"     "$OUT" "FAIL  A12"
has "A6 an old build has no gh-app-token"       "$OUT" "FAIL  A6"
has "B5 scopes the conf to THIS host"           "$OUT" "_paced.monkey.conf"

# --- C is not decorative: drop one MUST-KEEP path, the report MUST go red ----
grep -v '^KEEPVERDICT vkv23$' "$T/clean" > "$T/cut"
OUT="$(run "$T/cut")"; RC=$?
rc  "C0 losing ONE must-keep path fails the host" 1 "$RC"
has "C4 says which, and how many of how many"   "$OUT" "C4 every account keeps its own scheduler-verdict dir -- only 1 of 2 account(s)"

# --- BLIND is never clean ---------------------------------------------------
OUT="$(run UNREACHABLE)"; RC=$?
rc  "D1 an unreachable host is BLIND"           6 "$RC"
has "D2 and says BLIND"                         "$OUT" "BLIND"
has "D3 and says nothing was verified"          "$OUT" "nothing was verified"
hasnt "D4 and claims no passing rows"           "$OUT" "no account carries a scheduler clone"

printf 'garbage\n' > "$T/truncated"
OUT="$(run "$T/truncated")"; RC=$?
rc  "D5 a probe that did not complete is BLIND too" 6 "$RC"

# --- the row file is the contract -------------------------------------------
OUT="$(CUTOVER_ROWS=/nonexistent FACTS_FILE="$T/clean" CUTOVER_SSH="$T/ssh" "$SCRIPT" --host fixture 2>&1)"; RC=$?
rc  "E1 no row file is BLIND, not a clean run"  6 "$RC"

printf 'X1\tA\tSOMETOKEN\tmaybe\ta label\ta why\n' > "$T/badrows"
OUT="$(CUTOVER_ROWS="$T/badrows" FACTS_FILE="$T/clean" CUTOVER_SSH="$T/ssh" "$SCRIPT" --host fixture 2>&1)"; RC=$?
rc  "E2 an unknown expect is a FAIL, not a skip" 1 "$RC"
has "E3 and says the row graded nothing"        "$OUT" "graded nothing"

# --- the shipped row file is well-formed ------------------------------------
ROWS="$ROOT/bin/lib/cutover-rows.tsv"
badrow=0; nrow=0
while IFS=$'\t' read -r id sec token expect label why; do
  case "$id" in ''|\#*) continue ;; esac
  nrow=$((nrow + 1))
  case "$sec" in A|B|C) ;; *) badrow=$((badrow + 1)); echo "    bad section '$sec' on $id" ;; esac
  case "$expect" in absent|present|all) ;; *) badrow=$((badrow + 1)); echo "    bad expect '$expect' on $id" ;; esac
  [ -n "$token" ] && [ -n "$label" ] && [ -n "$why" ] || { badrow=$((badrow + 1)); echo "    empty field on $id"; }
done < "$ROWS"
eq  "F1 every shipped row is well-formed"       "$badrow" 0
[ "$nrow" -ge 25 ] && ok "F2 the floor is $nrow rows, which is enough to be worth trusting" \
                   || bad "F2 only $nrow rows -- the 10-row version is what Zach did not trust"

summary
