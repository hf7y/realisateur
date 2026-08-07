#!/usr/bin/env bash
# selfdev-gh-app.test.sh -- offline witness for bin/selfdev-gh-app.sh.
#
# The parts of that script that can be wrong SILENTLY are the crypto and the
# config resolution, not the HTTP: a malformed JWT comes back from GitHub as a
# bare 401 that reads exactly like a revoked key, and a config file that is
# read but not honoured looks like the App simply not being installed. So this
# file verifies the JWT against a throwaway keypair with openssl itself, and
# verifies precedence and refusal paths. NOTHING here touches the network --
# every case either stops before the first curl or points $SELFDEV_GH_API at a
# port nothing is listening on.
#
# Cases:
#   A  no App ID configured            -> FATAL naming SELFDEV_APP_ID, exit 5
#   B  App ID set, key missing         -> FATAL naming the key path, exit 5
#   C  key present but not a key       -> FATAL, exit 5 (openssl refuses)
#   D  --check with a real keypair     -> reports the config, key and tools OK
#   E  the JWT itself                  -> three dot-separated segments, header
#      is RS256/JWT, payload iss is the App ID, iat is in the PAST, exp within
#      GitHub's 10-minute ceiling, and the signature VERIFIES against the
#      public key (this is the case that would have caught a b64url that left
#      '=' padding or '+/' in place)
#   F  env var beats config file       -> SELFDEV_APP_ID wins over the conf
#   G  key with loose permissions      -> --check says BAD, exit 5
#
# Usage: bin/tests/selfdev-gh-app.test.sh   (exit 0 = all pass)
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/selfdev-gh-app.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
no()  { case "$2" in *"$3"*) bad "$1 (unexpected: $3)" ;; *) ok "$1" ;; esac; }
eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1 (got '$2', want '$3')"; }

# A throwaway RSA keypair. Same shape GitHub hands out (PKCS#1), generated
# here so the test carries no key material of its own.
openssl genrsa -traditional -out "$T/app.pem" 2048 2>/dev/null \
  || openssl genrsa -out "$T/app.pem" 2048 2>/dev/null \
  || { echo "FAIL: openssl could not generate a test key"; exit 1; }
chmod 600 "$T/app.pem"
openssl rsa -in "$T/app.pem" -pubout -out "$T/app.pub.pem" 2>/dev/null

# Every case runs with HOME redirected into the sandbox, so a real
# ~/.config/selfdev on the machine running this test can never leak in.
run() { env HOME="$T/home" XDG_CACHE_HOME="$T/cache" "$@"; }
mkdir -p "$T/home/.config/selfdev" "$T/cache"

echo "== selfdev-gh-app.test.sh =="

# --- A: no App ID -------------------------------------------------------------
out="$(run env SELFDEV_APP_CONF="$T/none.conf" "$SCRIPT" --token 2>&1)"; rc=$?
has "A names SELFDEV_APP_ID" "$out" "SELFDEV_APP_ID"
eq  "A exits 5" "$rc" "5"

# --- B: App ID, no key --------------------------------------------------------
out="$(run env SELFDEV_APP_CONF="$T/none.conf" SELFDEV_APP_ID=4520255 \
        SELFDEV_APP_KEY="$T/absent.pem" "$SCRIPT" --token 2>&1)"; rc=$?
has "B names the key path" "$out" "absent.pem"
eq  "B exits 5" "$rc" "5"

# --- C: a file that is not a key ---------------------------------------------
printf 'not a key\n' > "$T/junk.pem"; chmod 600 "$T/junk.pem"
out="$(run env SELFDEV_APP_CONF="$T/none.conf" SELFDEV_APP_ID=4520255 \
        SELFDEV_APP_KEY="$T/junk.pem" "$SCRIPT" --token 2>&1)"; rc=$?
eq  "C exits 5 on an unusable key" "$rc" "5"
no  "C does not print a token-shaped string" "$out" "ghs_"

# --- D: --check reports the local wiring -------------------------------------
cat > "$T/home/.config/selfdev/gh-app.conf" <<EOF
SELFDEV_APP_ID=4520255
SELFDEV_APP_KEY=$T/app.pem
SELFDEV_GH_OWNER=hf7y
EOF
# API pointed at a closed port: the local checks must still all report, and the
# witness must fail LOUD rather than the script hanging or exiting 0.
out="$(run env SELFDEV_GH_API="http://127.0.0.1:1" "$SCRIPT" --check 2>&1)"; rc=$?
has "D reports the app id"     "$out" "app id 4520255"
has "D reports the key"        "$out" "app.pem (mode 600)"
has "D reports openssl"        "$out" "openssl present"
has "D witness fails loud"     "$out" "WITNESS FAILED"
eq  "D exits 5 when the witness fails" "$rc" "5"
no  "D never claims success"   "$out" "WITNESS: GitHub authenticated"

# --- E: the JWT ---------------------------------------------------------------
# Minted through the script's own --jwt mode rather than reimplementing it --
# a test that recomputes the JWT its own way proves the test, not the script.
jwt="$(run "$SCRIPT" --jwt)"

segs="$(printf '%s' "$jwt" | awk -F. '{print NF}')"
eq "E JWT has three segments" "$segs" "3"

d64() { # base64url -> bytes, padding restored
  local s="${1//-/+}"; s="${s//_//}"
  case $(( ${#s} % 4 )) in 2) s="$s==" ;; 3) s="$s=" ;; esac
  printf '%s' "$s" | openssl base64 -d -A
}
hdr="$(d64 "$(printf '%s' "$jwt" | cut -d. -f1)")"
pay="$(d64 "$(printf '%s' "$jwt" | cut -d. -f2)")"
eq "E header alg is RS256" "$(printf '%s' "$hdr" | jq -r .alg)" "RS256"
eq "E header typ is JWT"   "$(printf '%s' "$hdr" | jq -r .typ)" "JWT"
eq "E payload iss is the App ID" "$(printf '%s' "$pay" | jq -r .iss)" "4520255"

now="$(date +%s)"
iat="$(printf '%s' "$pay" | jq -r .iat)"; exp="$(printf '%s' "$pay" | jq -r .exp)"
[ "$iat" -lt "$now" ] && ok "E iat is in the past (clock-skew margin)" \
                      || bad "E iat is not backdated (iat=$iat now=$now)"
[ $((exp - iat)) -le 600 ] && ok "E exp within GitHub's 10-minute ceiling" \
                           || bad "E exp is $((exp - iat))s after iat, GitHub caps at 600"

# The signature. This is the case that catches a base64url that forgot to
# strip '=' or translate '+/': GitHub would answer 401 and say nothing useful.
printf '%s' "$(printf '%s' "$jwt" | cut -d. -f1-2)" > "$T/signing"
d64 "$(printf '%s' "$jwt" | cut -d. -f3)" > "$T/sig.bin"
if openssl dgst -sha256 -verify "$T/app.pub.pem" -signature "$T/sig.bin" "$T/signing" >/dev/null 2>&1; then
  ok "E signature verifies against the public key"
else
  bad "E signature does NOT verify -- GitHub would answer 401"
fi

# --- F: env beats the config file --------------------------------------------
jwt2="$(run env SELFDEV_APP_ID=999 "$SCRIPT" --jwt)"
eq "F env SELFDEV_APP_ID wins over the conf file" \
   "$(d64 "$(printf '%s' "$jwt2" | cut -d. -f2)" | jq -r .iss)" "999"

# --- G: a world-readable private key is a defect, not a warning ---------------
cp "$T/app.pem" "$T/loose.pem"; chmod 644 "$T/loose.pem"
out="$(run env SELFDEV_APP_CONF="$T/none.conf" SELFDEV_APP_ID=4520255 \
        SELFDEV_APP_KEY="$T/loose.pem" SELFDEV_GH_API="http://127.0.0.1:1" \
        "$SCRIPT" --check 2>&1)"; rc=$?
has "G flags mode 644 as BAD" "$out" "must be 600"
eq  "G exits 5" "$rc" "5"

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
