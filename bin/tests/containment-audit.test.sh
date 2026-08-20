#!/usr/bin/env bash
#
# Cases:
#   A no account in the band            -> BLIND, exit 6, never "contained"
#   B every account owns only its home  -> OK, exit 0
#   C an account owns a file elsewhere  -> DOWN, exit 5, and it is named
#   D an account's OWN crontab          -> OK: the clock lives on the consumer
#   E another account's crontab         -> DOWN: the exemption is one path
#   F a sudoers grant                   -> DOWN
#   G the sweep cannot read the tree    -> BLIND, never OK
#   H --json emits one object per check
#
# Usage: bin/tests/containment-audit.test.sh   (exit 0 = all pass)

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/containment-audit.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
harness_tmp

STUB="$T/stub"; mkdir -p "$STUB"

# The probes run through `bash -c`, so the world is three stubbed commands:
# getent names the band, find answers "what does this uid own", grep answers
# the sudoers question. FIND_OUT/GREP_OUT/FIND_RC drive each case.
cat > "$STUB/getent" <<EOF
#!/usr/bin/env bash
cat "$T/passwd"
EOF
cat > "$STUB/sudo" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = -n ] && shift
exec "$@"
EOF
cat > "$STUB/find" <<EOF
#!/usr/bin/env bash
acct=""
for a in "\$@"; do case "\$a" in /var/spool/cron/crontabs/*) acct="\${a##*/}" ;; esac; done
if [ -f "$T/owns.\$acct" ]; then cat "$T/owns.\$acct"; fi
exit \$(cat "$T/find_rc" 2>/dev/null || echo 0)
EOF
cat > "$STUB/grep" <<EOF
#!/usr/bin/env bash
if [ -f "$T/sudoers_hit" ]; then cat "$T/sudoers_hit"; exit 0; fi
exit 1
EOF
chmod +x "$STUB"/*
: > "$T/passwd"

run() { OUT="$(PATH="$STUB:/usr/bin:/bin" bash "$SCRIPT" "$@" 2>&1)"; RC=$?; }
reset() { rm -f "$T"/owns.* "$T/sudoers_hit" "$T/find_rc"; }

section "A. an empty band is BLIND, never contained"
reset; : > "$T/passwd"
run
rc "A1 exit 6" 6 "$RC"
has "A2 says BLIND" "$OUT" "BLIND"
hasnt "A3 never claims containment" "$OUT" "owns nothing"

printf 'crt:x:3001:3001::/home/crt:/bin/bash\nwtul:x:3002:3002::/home/wtul:/bin/bash\n' > "$T/passwd"

section "B. accounts that own only their homes"
reset
run
rc "B1 exit 0" 0 "$RC"
has "B2 each account is named contained" "$OUT" "owns nothing outside /home/crt"
has "B3 sudo is clean" "$OUT" "no self-dev account appears in sudoers"

section "C. a file outside the home is DOWN and is named"
reset; printf '/srv/shared/thing\nRC=0\n' > "$T/owns.crt"
run
rc "C1 exit 5" 5 "$RC"
has "C2 names the path" "$OUT" "/srv/shared/thing"
has "C3 and the account" "$OUT" "reach:crt"

section "D/E. the crontab exemption is exactly one path"
reset
# The stub only reports what find was NOT asked to exclude, so an own-crontab
# case reports nothing: the exemption is in the find invocation itself.
run
has "D1 an account's own crontab does not make it uncontained" "$OUT" "owns nothing outside /home/crt"
reset; printf '/var/spool/cron/crontabs/wtul\nRC=0\n' > "$T/owns.crt"
run
rc "E1 another account's crontab is DOWN" 5 "$RC"
has "E2 and it is named" "$OUT" "/var/spool/cron/crontabs/wtul"

section "F. a sudoers grant is DOWN"
reset; printf '/etc/sudoers.d/selfdev\n' > "$T/sudoers_hit"
run
rc "F1 exit 5" 5 "$RC"
has "F2 names the file" "$OUT" "/etc/sudoers.d/selfdev"

section "G. an unreadable tree is BLIND, not clean"
reset; printf '2' > "$T/find_rc"
run
rc "G1 exit 6" 6 "$RC"
has "G2 says the sweep could not read" "$OUT" "could not read"
hasnt "G3 never says the account owns nothing" "$OUT" "owns nothing outside /home/crt"

section "H. --json"
reset
run --json
has "H1 one object per check" "$OUT" '"check":"reach:crt"'
has "H2 carries the verdict" "$OUT" '"verdict":"OK"'

summary
