#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO/bin/selfdev-containment-audit.sh"

harness_tmp
mkdir -p "$T/bin" "$T/home/accta" "$T/home/acctb" "$T/sudoers.d"

cat > "$T/bin/sudo" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = -n ] && shift
exec "$@"
EOF
chmod +x "$T/bin/sudo"

cat > "$T/bin/nosudo" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$T/bin/nosudo"

MYUID="$(id -u)"   # acctb's real uid: only a real file proves it
export CA_UID_MIN="$MYUID" CA_UID_MAX="$MYUID"
OTHER_A=65530; OTHER_B=65531   # band is MYUID alone: a line sharing it joins
[ "$MYUID" = "$OTHER_A" ] && OTHER_A=65528
[ "$MYUID" = "$OTHER_B" ] && OTHER_B=65529
cat > "$T/passwd.txt" <<EOF
root:x:0:0::/root:/bin/bash
zach:x:$OTHER_A:$OTHER_A::/home/zach:/bin/bash
accta:x:$OTHER_B:$OTHER_B::$T/home/accta:/bin/bash
acctb:x:$MYUID:$MYUID::$T/home/acctb:/bin/bash
EOF

section "A. no root -- BLIND, never a silent pass"
OUT="$(PATH="$T/bin:$PATH" CA_SUDO="$T/bin/nosudo" CA_GETENT="cat $T/passwd.txt" \
       CA_SCAN_ROOT="$T/home" CA_SUDOERS_DIR="$T/sudoers.d" "$SCRIPT" 2>&1)"
RC=$?
rc "A1 exit 6 when sudo -n is denied" "6" "$RC"
has "A2 says BLIND, not PASS" "$OUT" BLIND
hasnt "A3 does not claim contained" "$OUT" "contained --"

section "B. clean estate -- every account only touches its own home"
touch "$T/home/acctb/mine.txt" # hardcoded-home-ok: fixture path under $T, not a real host path
echo "zach ALL=(ALL) NOPASSWD: ALL" > "$T/sudoers.d/zach"
OUT="$(PATH="$T/bin:$PATH" CA_SUDO="$T/bin/sudo" CA_GETENT="cat $T/passwd.txt" \
       CA_SCAN_ROOT="$T/home/acctb" CA_SUDOERS_DIR="$T/sudoers.d" "$SCRIPT")"
RC=$?
rc "B1 exit 0 when nothing crosses a boundary" "0" "$RC"
has "B2 reports PASS for homebound" "$OUT" "PASS  no self-dev account owns a file outside its own home"
has "B3 reports PASS for sudoers" "$OUT" "PASS  no self-dev account referenced"

section "C. cross-account file -- FINDING, not silence"
OUT="$(PATH="$T/bin:$PATH" CA_SUDO="$T/bin/sudo" CA_GETENT="cat $T/passwd.txt" \
       CA_SCAN_ROOT="$T/home" CA_SUDOERS_DIR="$T/sudoers.d" "$SCRIPT")"
RC=$?
rc "C1 exit 1 on a cross-account file" "1" "$RC"
has "C2 names the offending account" "$OUT" "acctb (uid $MYUID) owns"

section "D. self-dev account named in sudoers.d -- FINDING"
echo '%acctb ALL=(ALL) NOPASSWD: /usr/bin/foo' > "$T/sudoers.d/oops"
OUT="$(PATH="$T/bin:$PATH" CA_SUDO="$T/bin/sudo" CA_GETENT="cat $T/passwd.txt" \
       CA_SCAN_ROOT="$T/home/acctb" CA_SUDOERS_DIR="$T/sudoers.d" "$SCRIPT")"
RC=$?
rc "D1 exit 1 when a self-dev account is in sudoers.d" "1" "$RC"
has "D2 names the file and the account" "$OUT" "acctb (uid $MYUID) referenced in"
rm -f "$T/sudoers.d/oops"

section "E. contract"
OUT="$("$SCRIPT" --help)"; RC=$?
rc "E1 --help exits 0" "0" "$RC"
has "E2 --help documents BLIND" "$OUT" "BLIND"
OUT="$("$SCRIPT" --bogus 2>&1)"; RC=$?
rc "E3 unknown flag is a usage error" "2" "$RC"

summary
