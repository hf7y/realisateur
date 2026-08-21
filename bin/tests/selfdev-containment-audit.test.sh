#!/usr/bin/env bash
#
# TRAPS (the rest of this header is in the vault):
# WHY THIS FILE EXISTS. selfdev-containment-audit.sh needs root to look at
# another account's home or at /etc/sudoers.d, and this suite has neither.
# Every case below fakes `sudo -n` as a plain exec (CA_SUDO) and points the
# script at a throwaway fixture tree (CA_SCAN_ROOT, CA_SUDOERS_DIR,
# CA_GETENT) instead of the real host -- the same shape delivery-audit.test.sh
# uses for DA_SUDO/DA_HOST_SSH, for the same reason: a suite that could pass
# by reaching the real host is not testing the script's logic.
#
# usage: ./bin/tests/selfdev-containment-audit.test.sh

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO/bin/selfdev-containment-audit.sh"

harness_tmp
mkdir -p "$T/bin" "$T/home/accta" "$T/home/acctb" "$T/sudoers.d"

# A `sudo -n ...` stub that just execs the rest -- this suite runs as one
# uid, so it cannot prove privilege separation, only that the script's own
# branching (BLIND without sudo, FINDING/PASS with it) is correct.
cat > "$T/bin/sudo" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = -n ] && shift
exec "$@"
EOF
chmod +x "$T/bin/sudo"

# A `sudo -n` that always denies -- proves the BLIND path fires and nothing
# downstream is read as a clean result.
cat > "$T/bin/nosudo" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$T/bin/nosudo"

cat > "$T/passwd.txt" <<EOF
root:x:0:0::/root:/bin/bash
zach:x:1000:1000::/home/zach:/bin/bash
accta:x:3001:3001::$T/home/accta:/bin/bash
acctb:x:3010:3010::$T/home/acctb:/bin/bash
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
has "C2 names the offending account" "$OUT" "acctb (uid 3010) owns"

section "D. self-dev account named in sudoers.d -- FINDING"
echo '%acctb ALL=(ALL) NOPASSWD: /usr/bin/foo' > "$T/sudoers.d/oops"
OUT="$(PATH="$T/bin:$PATH" CA_SUDO="$T/bin/sudo" CA_GETENT="cat $T/passwd.txt" \
       CA_SCAN_ROOT="$T/home/acctb" CA_SUDOERS_DIR="$T/sudoers.d" "$SCRIPT")"
RC=$?
rc "D1 exit 1 when a self-dev account is in sudoers.d" "1" "$RC"
has "D2 names the file and the account" "$OUT" "acctb (uid 3010) referenced in"
rm -f "$T/sudoers.d/oops"

section "E. contract"
OUT="$("$SCRIPT" --help)"; RC=$?
rc "E1 --help exits 0" "0" "$RC"
has "E2 --help documents BLIND" "$OUT" "BLIND"
OUT="$("$SCRIPT" --bogus 2>&1)"; RC=$?
rc "E3 unknown flag is a usage error" "2" "$RC"

summary
