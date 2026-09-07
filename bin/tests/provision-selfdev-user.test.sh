#!/usr/bin/env bash
# provision-selfdev-user.test.sh -- witness for bin/provision-selfdev-user.sh,
# specifically the private-scratch stanza (#620): a shared /tmp let one
# tenant's stale file satisfy another tenant's read (realisateur#620). The
# fix is the block this script writes into ~/.profile (TMPDIR=$HOME/tmp,
# umask 077) plus the account's own 0700 ~/tmp dir.
#
# HERMETICITY: this never touches a real account, /home, /etc/sudoers.d, or
# the real claude/gh binaries.
#   - HOME_ROOT points the whole run at a throwaway tree ($T), the same knob
#     selfdev-permissions-provision.sh and selfdev-hooks-provision.sh use.
#   - A stub `sudo` on PATH strips `-u USER`/`-H`/`-n` and execs the rest AS
#     THIS TEST'S OWN USER (there is no real fixture Linux account to drop
#     privilege to); useradd/chown/loginctl/rm are no-ops (this sandbox owns
#     no real account to create, chown to, or linger); `install -o/-g` drops
#     the ownership flags and keeps the rest.
#   - The account is made to look ALREADY PROVISIONED (stub `id` reports it
#     existing at a fixed uid in the self-dev band) so useradd is never
#     reached -- this script cannot actually create a Linux user without
#     root, and this suite must not need root.
#   - The final "witness" line always calls `claude -p ...` via
#     `env -i PATH=/usr/local/bin:/usr/bin:/bin claude ...` -- deliberately
#     hardcoded system paths, chosen upstream to match what cron would see.
#     Never let that resolve to the REAL claude binary that lives at
#     /usr/bin/claude on this host: the stub `sudo` recognizes the `env ...
#     claude` shape and answers "ok" itself, never execing it. Same for the
#     `gh auth status` witness, though this suite additionally routes
#     SELFDEV_GH_HOSTS at a path that does not exist so that whole block is
#     skipped (gap, not a call) rather than relying on the stub alone.
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/provision-selfdev-user.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp
FIXTURE_PROJECT="fixture620"
FIXTURE_UID="3005"

STUB="$T/stub"; mkdir -p "$STUB"

cat > "$STUB/sudo" <<STUBSH
#!/usr/bin/env bash
# see the header of provision-selfdev-user.test.sh for what and why
args=("\$@")
i=0
while [ \$i -lt \${#args[@]} ]; do
  case "\${args[\$i]}" in
    -u) i=\$((i+2)); continue ;;
    -n|-H) i=\$((i+1)); continue ;;
    *) break ;;
  esac
done
rest=("\${args[@]:\$i}")
echo "SUDO: \${rest[*]}" >> "$T/sudo.log"

case "\${rest[0]:-}" in
  useradd|loginctl|chown|rm) exit 0 ;;
  install)
    out=(); j=0
    while [ \$j -lt \${#rest[@]} ]; do
      case "\${rest[\$j]}" in
        -o|-g) j=\$((j+2)); continue ;;
        *) out+=("\${rest[\$j]}"); j=\$((j+1)) ;;
      esac
    done
    exec "\${out[@]}"
    ;;
  env)
    case "\${rest[*]}" in
      *claude*) echo ok; exit 0 ;;
      *gh*) exit 0 ;;
      *) exec "\${rest[@]}" ;;
    esac
    ;;
  *) exec "\${rest[@]}" ;;
esac
STUBSH
chmod +x "$STUB/sudo"

cat > "$STUB/id" <<STUBSH
#!/usr/bin/env bash
# fixture id: only $FIXTURE_PROJECT is "known"; a bare "id -u" (no name)
# still answers for real, the same as the check at line 19/83 needs.
if [ "\$#" -eq 1 ] && [ "\$1" = "-u" ]; then exec /usr/bin/id -u; fi
if [ "\$#" -eq 2 ] && [ "\$1" = "-u" ] && [ "\$2" = "$FIXTURE_PROJECT" ]; then echo "$FIXTURE_UID"; exit 0; fi
if [ "\$#" -eq 1 ] && [ "\$1" = "$FIXTURE_PROJECT" ]; then exit 0; fi
exec /usr/bin/id "\$@"
STUBSH
chmod +x "$STUB/id"

TOKENFILE="$T/fixture-claude-token"
printf 'sk-ant-oat01-FIXTURE\n' > "$TOKENFILE"

run_apply() {
  : > "$T/sudo.log"
  HOME_ROOT="$T/home" \
  SELFDEV_TOKEN_FILE="$TOKENFILE" \
  SELFDEV_GH_HOSTS="$T/no-such-hosts.yml" \
  PATH="$STUB:$PATH" \
  "$SCRIPT" "$FIXTURE_PROJECT" --apply 2>&1
}

mkdir -p "$T/home/$FIXTURE_PROJECT"

section "A. --apply writes the private-scratch stanza on a fresh account"
OUT="$(run_apply)"; RC=$?
PROFILE="$T/home/$FIXTURE_PROJECT/.profile"

has "A1 reports the action by name" "$OUT" "private TMPDIR and umask 077"
[ -f "$PROFILE" ] && ok "A2 ~/.profile was written" || bad "A2 ~/.profile was written"
has "A3 the marker is present" "$(cat "$PROFILE" 2>/dev/null)" "# selfdev: private scratch"
has "A4 references the issue" "$(cat "$PROFILE" 2>/dev/null)" "realisateur#620"
has "A5 exports TMPDIR at \$HOME/tmp, not a shared /tmp" "$(cat "$PROFILE" 2>/dev/null)" 'export TMPDIR="$HOME/tmp"'
has "A6 sets a restrictive umask" "$(cat "$PROFILE" 2>/dev/null)" "umask 077"
hasnt "A7 never points TMPDIR at the shared /tmp itself" "$(cat "$PROFILE" 2>/dev/null)" 'TMPDIR="/tmp"'

[ -d "$T/home/$FIXTURE_PROJECT/tmp" ] && ok "A8 the account's own tmp dir was created" \
                                       || bad "A8 the account's own tmp dir was created"
PERM="$(stat -c%a "$T/home/$FIXTURE_PROJECT/tmp" 2>/dev/null)"
eq "A9 the account's own tmp dir is 0700, not group/world readable" "$PERM" "700"

rc "A10 --apply on a fresh account exits 0 (BAD stays 0)" 0 "$RC"

section "B. idempotent: a second --apply does not duplicate the block"
run_apply >/dev/null 2>&1
OUT2="$(run_apply)"
COUNT="$(grep -c '^# selfdev: private scratch' "$PROFILE" 2>/dev/null || true)"
eq "B1 the marker appears exactly once after two applies" "$COUNT" "1"
has "B2 the second run says so, rather than silently rewriting" "$OUT2" "already present, left alone"

section "C. hermeticity: the claude witness is answered by the stub, never the real binary"
LOGGED="$(cat "$T/sudo.log")"
has "C1 the witness call was routed through sudo's env -i shape" "$LOGGED" "env -i"
has "C2 the stub's canned 'ok' satisfied the witness check" "$OUT" "can spend a token under a cron-shaped environment"
hasnt "C3 the witness never fell through to a real failure" "$OUT" "could NOT spend a token"

section "D. --host <hostname> drives the target over ssh (realisateur#895)"
# A fake ssh in the same shape bin/tests/dresse.test.sh already proved: eat the
# -o flags, keep the host, then eval the remote command STRING in this shell.
# tar's stdin is still open (this runs on the far side of the real
# `tar | ssh` pipe), so the remote `tar -x` really extracts the shipped tree,
# and the recursive `bash .../provision-selfdev-user.sh` that follows runs the
# very same stubs (sudo, id) already on PATH -- proving the transport
# reproduces local execution rather than a second, untested code path.
cat > "$STUB/ssh" <<'FAKE'
#!/usr/bin/env bash
a=(); while [ $# -gt 0 ]; do case "$1" in -o) shift 2 ;; *) a+=("$1"); shift ;; esac; done
printf 'FAKESSH host=%s\n' "${a[0]}"
eval "${a[1]}"
FAKE
chmod +x "$STUB/ssh"

HOSTPROJECT="fixture895"
mkdir -p "$T/home/$HOSTPROJECT"
run_host_apply() {
  HOME_ROOT="$T/home" \
  SELFDEV_TOKEN_FILE="$TOKENFILE" \
  SELFDEV_GH_HOSTS="$T/no-such-hosts.yml" \
  SELFDEV_SSH_BIN="$STUB/ssh" \
  PATH="$STUB:$PATH" \
  "$SCRIPT" "$HOSTPROJECT" --apply --host monkey 2>&1
}
OUTD="$(run_host_apply)"; RCD=$?
has "D1 says which target it is acting on" "$OUTD" "on monkey, driven over ssh"
has "D2 the call really went over the ssh transport" "$OUTD" "FAKESSH host=monkey"
rc  "D3 a real provisioning run through --host still exits 0" 0 "$RCD"
PROFILE_D="$T/home/$HOSTPROJECT/.profile"
has "D4 the shipped, unmodified copy did the real work (wrote the stanza)" \
    "$(cat "$PROFILE_D" 2>/dev/null)" "# selfdev: private scratch"

section "E. --host: an unreachable target is FATAL (exit 6), not a raw ssh code"
cat > "$STUB/ssh" <<'FAKE'
#!/usr/bin/env bash
exit 255
FAKE
chmod +x "$STUB/ssh"
OUTE="$(HOME_ROOT="$T/home" SELFDEV_SSH_BIN="$STUB/ssh" PATH="$STUB:$PATH" \
        "$SCRIPT" "$HOSTPROJECT" --apply --host ghost 2>&1)"; RCE=$?
eq  "E1 an unreachable host exits 6, not ssh's own 255" "$RCE" "6"
has "E2 the message names the host and says FATAL" "$OUTE" "FATAL could not reach ghost"

summary
