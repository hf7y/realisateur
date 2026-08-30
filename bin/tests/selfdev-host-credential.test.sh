#!/usr/bin/env bash
# selfdev-host-credential.test.sh -- the host-wide credential layout, read off
# the host it describes. Every other suite in this family builds /etc/selfdev as
# a FIXTURE, deliberately, so the real layout was asserted only in prose: a mode
# change, or a per-account copy coming back, moved nothing red.
#
# RUNNER: .github/workflows/tests.yml (suites), where /etc/selfdev is absent and
# this says BLIND. It does its work on the self-dev host, under any account.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
# shellcheck source=bin/lib/selfdev-app-key.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/selfdev-app-key.sh"

DIR="$SELFDEV_APP_DIR"
GROUP="$SELFDEV_APP_GROUP"

section "A. the host-wide credential layout under $DIR"

if [ ! -d "$DIR" ]; then
  echo "  BLIND $DIR does not exist on $(hostname -s) -- this is not a self-dev host."
  echo "        Nothing was checked. Run this on the host that dispatches."
  summary; exit $?
fi

if members="$(getent group "$GROUP" 2>/dev/null)"; then
  ok "group $GROUP exists ($(printf '%s' "$members" | cut -d: -f4 | tr ',' ' ' | wc -w) member(s))"
else
  bad "group $GROUP exists" \
      "without it nothing can read $DIR. Remedy: sudo selfdev-app-key.sh --apply"
fi

# 0640 root:selfdev. Not 0644: the key and the token are secrets, and the group
# IS the access control. Not 0600: every account has to read them.
for f in app.pem claude-token; do
  p="$DIR/$f"
  if [ ! -e "$p" ]; then
    bad "$p is in place" \
        "it is missing on a host that has $DIR, so this host was provisioned and
        then lost it. Remedy: sudo selfdev-app-key.sh --apply --from <pem> --app-id <id>
        (app.pem) / sudo selfdev-claude-token.sh --install <file> (claude-token)"
    continue
  fi
  eq "$p is 0640 root:$GROUP" "$(stat -c '%a %U:%G' "$p")" "640 root:$GROUP"
  [ "$(stat -c '%a %U:%G' "$p")" = "640 root:$GROUP" ] || printf '        %s\n' \
    "Remedy: sudo chown root:$GROUP $p && sudo chmod 0640 $p"
done

# ONE COPY, NOT N (realisateur#171/#209): a rotation that misses one leaves an
# account minting tokens from a revoked key. A copy here means that regressed.
section "B. the per-account copies stay retired"
copy="$HOME/.config/selfdev/app.pem"
if [ -e "$copy" ]; then
  bad "$(id -un) carries no per-account copy of the App key" \
      "$copy is back. It is a second thing to rotate and nothing rotates it.
        Remedy: prove the host-wide key is readable here, then
        sudo selfdev-app-key.sh --retire-copies"
else
  ok "$(id -un) reads the host-wide key, and carries no copy of its own"
fi

summary
