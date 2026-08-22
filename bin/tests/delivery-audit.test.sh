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

# A gh stub, so no case can pass by reaching the real tracker.
mkgh() { # mkgh <body> [merged_at]
  printf '%s' "$1" > "$T/body"
  printf '%s' "${2:-2026-08-01T00:00:00Z}" > "$T/merged_at"
  cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *nameWithOwner*) echo "hf7y/fixture" ;;
  *actions/secrets/PRESENT*) exit 0 ;;
  *actions/secrets/*) exit 1 ;;
  *contents/MISSING*) exit 1 ;;
  *contents/*)
    [ -f "$TDIR/home" ] || exit 1
    base64 -w0 < "$TDIR/home" ;;
  *) printf '7\t%s\t%s\n' "$(cat "$TDIR/merged_at")" "$(base64 -w0 < "$TDIR/body")" ;;
esac
EOF
  chmod +x "$T/bin/gh"
}
mkcurl() { # mkcurl <cut_at> -- "" makes it BLIND, no last_cut
  printf '%s' "${1:-}" > "$T/cut_at"
  cat > "$T/bin/curl" <<'EOF'
#!/usr/bin/env bash
cut_at="$(cat "$TDIR/cut_at" 2>/dev/null)"
[ -n "$cut_at" ] && printf '{"last_cut":{"at":"%s"}}\n' "$cut_at"
EOF
  chmod +x "$T/bin/curl"
}
mkcurl ""
mkssh() { # mkssh <exit-for-test-e> [crontab-output]
  cat > "$T/bin/ssh" <<EOF
#!/usr/bin/env bash
case "\$*" in
  *crontab*) printf '%s\n' "${2:-}" ;;
  *bash\ -s*) exit ${1:-0} ;;
  *systemctl*) printf '%s\n' "${2:-}" ;;
esac
EOF
  chmod +x "$T/bin/ssh"
}
run() { TDIR="$T" DA_GH="$T/bin/gh" DA_HOST_SSH="$T/bin/ssh" DA_CURL="$T/bin/curl" bash "$SCRIPT" --pr 7 --repo hf7y/fixture 2>&1; }
runsudo() { # runsudo <DA_SUDO>
  TDIR="$T" DA_GH="$T/bin/gh" DA_HOST_SSH="$T/bin/ssh" DA_CURL="$T/bin/curl" DA_SUDO="$1" \
    bash "$SCRIPT" --pr 7 --repo hf7y/fixture 2>&1
}

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

section "A2. absent and unreadable are different answers"
mkdir -p "$T/sealed/inner"; : > "$T/sealed/inner/thing"
mkgh "$BODY_HDR
<!-- DELIVERS -->
- path:$T/sealed/inner/thing
<!-- /DELIVERS -->"
OUT="$(TDIR=$T DA_GH="$T/bin/gh" DA_HOST_SSH="$T/bin/ssh" bash "$SCRIPT" --pr 7 --repo hf7y/fixture 2>&1)"; R=$?
rc  "A2a a visible, present path is MET" 0 "$R"

chmod 000 "$T/sealed"
# Refuses, so BLIND means "could not look", not "this runner lacks sudo".
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/bin/nosudo"; chmod +x "$T/bin/nosudo"
OUT="$(TDIR=$T DA_GH="$T/bin/gh" DA_HOST_SSH="$T/bin/ssh" DA_SUDO="$T/bin/nosudo" \
       bash "$SCRIPT" --pr 7 --repo hf7y/fixture 2>&1)"; R=$?
rc  "A2b a path behind a sealed ancestor is BLIND (6), not UNMET" 6 "$R"
has "A2c and says absence was not established" "$OUT" "absence NOT established"

cat > "$T/bin/yessudo" <<YS
#!/usr/bin/env bash
[ "\$1" = -n ] && shift
[ "\$1" = true ] && exit 0
chmod 755 "$T/sealed"; "\$@"; r=\$?; chmod 000 "$T/sealed"; exit \$r
YS
chmod +x "$T/bin/yessudo"
OUT="$(TDIR=$T DA_GH="$T/bin/gh" DA_HOST_SSH="$T/bin/ssh" DA_SUDO="$T/bin/yessudo" \
       bash "$SCRIPT" --pr 7 --repo hf7y/fixture 2>&1)"; R=$?
rc  "A2b2 the other direction: a prober that CAN see resolves it, not BLIND" 0 "$R"
chmod 755 "$T/sealed"

mkgh "$BODY_HDR
<!-- DELIVERS -->
- path:$T/sealed/inner/no-such-thing
<!-- /DELIVERS -->"
OUT="$(TDIR=$T DA_GH="$T/bin/gh" DA_HOST_SSH="$T/bin/ssh" bash "$SCRIPT" --pr 7 --repo hf7y/fixture 2>&1)"; R=$?
rc  "A2d a genuinely missing path under a readable parent is still UNMET (1)" 1 "$R"

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

section "H. matches: asks whether the deployed bytes are the merged bytes"
mkdir -p "$T/deployed"
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/bin/nosudo"; chmod +x "$T/bin/nosudo"

printf 'hello world' > "$T/deployed/thing"
printf 'hello world' > "$T/home"
mkgh "$BODY_HDR
<!-- DELIVERS -->
- matches:$T/deployed/thing home:GOOD
<!-- /DELIVERS -->" "2026-08-10T00:00:00Z"
mkcurl "2026-08-01T00:00:00Z"
OUT="$(run)"; R=$?
rc  "H1 equal bytes exits 0" 0 "$R"
has "H2 and says MET" "$OUT" "MET    #7  matches:"

printf 'different bytes' > "$T/deployed/thing"
mkgh "$BODY_HDR
<!-- DELIVERS -->
- matches:$T/deployed/thing home:GOOD
<!-- /DELIVERS -->" "2026-08-01T00:00:00Z"
mkcurl "2026-08-15T00:00:00Z"
OUT="$(run)"; R=$?
rc  "H3 a mismatch is UNMET once a build has cut since the merge" 1 "$R"
has "H4 and says the PR is not done" "$OUT" "this PR is not done"

mkgh "$BODY_HDR
<!-- DELIVERS -->
- matches:$T/deployed/thing home:GOOD
<!-- /DELIVERS -->" "2026-08-20T00:00:00Z"
mkcurl "2026-08-01T00:00:00Z"
OUT="$(run)"; R=$?
rc  "H5 a mismatch before the next cut is PENDING, not UNMET" 0 "$R"
has "H6 and says PENDING" "$OUT" "PENDING"

mkgh "$BODY_HDR
<!-- DELIVERS -->
- matches:$T/deployed/nosuchfile home:GOOD
<!-- /DELIVERS -->" "2026-08-01T00:00:00Z"
mkcurl "2026-08-15T00:00:00Z"
OUT="$(run)"; R=$?
rc  "H7 an absent deployed file is UNMET" 1 "$R"
has "H8 and says not deployed" "$OUT" "is not deployed"

mkdir -p "$T/sealed3/inner"; printf 'x' > "$T/sealed3/inner/thing"; chmod 000 "$T/sealed3"
mkgh "$BODY_HDR
<!-- DELIVERS -->
- matches:$T/sealed3/inner/thing home:GOOD
<!-- /DELIVERS -->" "2026-08-01T00:00:00Z"
OUT="$(runsudo "$T/bin/nosudo")"; R=$?
rc  "H9 a sealed deployed path is BLIND (6), not UNMET" 6 "$R"
chmod 755 "$T/sealed3"

printf 'different bytes' > "$T/deployed/thing"
mkgh "$BODY_HDR
<!-- DELIVERS -->
- matches:$T/deployed/thing home:MISSING
<!-- /DELIVERS -->" "2026-08-01T00:00:00Z"
OUT="$(run)"; R=$?
rc  "H10 an unreadable home: source is BLIND" 6 "$R"

mkgh "$BODY_HDR
<!-- DELIVERS -->
- matches:$T/deployed/thing home:GOOD
<!-- /DELIVERS -->" "2026-08-01T00:00:00Z"
mkcurl ""
OUT="$(run)"; R=$?
rc  "H11 an unreadable release channel is BLIND when bytes differ" 6 "$R"

summary
