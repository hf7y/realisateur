#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh" 2>/dev/null || {
  pass=0; fail=0
  section() { printf '\n%s\n' "$*"; }
  ok()  { pass=$((pass+1)); printf '  ok    %s\n' "$1"; }
  bad() { fail=$((fail+1)); printf '  FAIL  %s\n' "$1"; [ $# -gt 1 ] && printf '        %s\n' "$2"; return 0; }
  rc()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "want exit $2, got $3"; fi; }
  has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "missing: $3" ;; esac; }
  hasnt(){ case "$2" in *"$3"*) bad "$1" "present: $3" ;; *) ok "$1" ;; esac; }
  summary(){ printf '\n%s: %d passed, %d failed\n' "${0##*/}" "$pass" "$fail"; [ "$fail" -eq 0 ]; }
  T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
}
[ -n "${T:-}" ] || { T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; }

SCRIPT="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")/delivery-audit.sh"
mkdir -p "$T/bin"

# A gh stub that answers one PR with whatever body the case sets, so no case
# needs the network and none can pass by reaching the real tracker.
mkgh() { # mkgh <body>
  printf '%s' "$1" > "$T/body"
  cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *nameWithOwner*) echo "hf7y/fixture" ;;
  *actions/secrets/PRESENT*) exit 0 ;;
  *actions/secrets/*) exit 1 ;;
  *) printf '7\t%s\n' "$(base64 -w0 < "$TDIR/body")" ;;
esac
EOF
  chmod +x "$T/bin/gh"
}
mkssh() { # mkssh <exit-for-test-e> [crontab-output]
  cat > "$T/bin/ssh" <<EOF
#!/usr/bin/env bash
case "\$*" in
  *crontab*) printf '%s\n' "${2:-}" ;;
  *test\ -e*) exit ${1:-0} ;;
  *systemctl*) printf '%s\n' "${2:-}" ;;
esac
EOF
  chmod +x "$T/bin/ssh"
}
run() { TDIR="$T" DA_GH="$T/bin/gh" DA_HOST_SSH="$T/bin/ssh" bash "$SCRIPT" --pr 7 --repo hf7y/fixture 2>&1; }

BODY_HDR='NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->
'

section "A. a path claim is checked on the host it names"
mkgh "$BODY_HDR
<!-- DELIVERS -->
- host:monkey path:/usr/local/bin/dresse
<!-- /DELIVERS -->"
mkssh 0; OUT="$(run)"; R=$?
rc  "A1 a path that is there exits 0" 0 "$R"
has "A2 and says MET" "$OUT" "MET"
mkssh 1; OUT="$(run)"; R=$?
rc  "A3 a path that is absent exits 1" 1 "$R"
has "A4 and says the PR is not done" "$OUT" "this PR is not done"
has "A5 naming the path and the host" "$OUT" "/usr/local/bin/dresse"

section "B. a clock claim reads the crontab it names"
mkgh "$BODY_HDR
<!-- DELIVERS -->
- clock:root@monkey tag:realisateur:ausculte:CADENCE
<!-- /DELIVERS -->"
mkssh 0 "37 */4 * * * /usr/local/libexec/selfdev/ausculte-cadence.sh # realisateur:ausculte:CADENCE"
OUT="$(run)"; R=$?
rc  "B1 a tag present in the crontab exits 0" 0 "$R"
mkssh 0 "0 * * * * something-else"
OUT="$(run)"; R=$?
rc  "B2 a tag in no crontab exits 1" 1 "$R"
has "B3 and names the tag" "$OUT" "realisateur:ausculte:CADENCE"

section "C. could-not-look is BLIND, never met"
mkgh "$BODY_HDR
<!-- DELIVERS -->
- clock:root@monkey tag:whatever
<!-- /DELIVERS -->"
mkssh 0 ""
OUT="$(run)"; R=$?
rc  "C1 an unreadable crontab is BLIND (6)" 6 "$R"
has "C2 and says so" "$OUT" "BLIND"

section "D. a PR with no ledger is BLIND, not clean"
mkgh "$BODY_HDR"
mkssh 0; OUT="$(run)"; R=$?
rc  "D1 no DELIVERS block is BLIND (6)" 6 "$R"
has "D2 and says why" "$OUT" "no DELIVERS block"

section "E. \"- none\" is a complete answer"
mkgh "$BODY_HDR
<!-- DELIVERS -->
- none
<!-- /DELIVERS -->"
mkssh 0; OUT="$(run)"; R=$?
rc  "E1 exits 0" 0 "$R"
hasnt "E2 and claims nothing" "$OUT" "UNMET  #"

section "F. a secret claim asks GitHub"
mkgh "$BODY_HDR
<!-- DELIVERS -->
- secret:PRESENT repo:hf7y/ecosim
<!-- /DELIVERS -->"
mkssh 0; OUT="$(run)"; R=$?
rc  "F1 a secret that is set exits 0" 0 "$R"
mkgh "$BODY_HDR
<!-- DELIVERS -->
- secret:ECOSYSTEM_ISSUES_TOKEN repo:hf7y/ecosim
<!-- /DELIVERS -->"
OUT="$(run)"; R=$?
rc  "F2 a secret that is not set exits 1" 1 "$R"

section "G. usage"
OUT="$(bash "$SCRIPT" --days notanumber 2>&1)"; R=$?
rc "G1 a non-numeric window is a usage error (2)" 2 "$R"

summary
