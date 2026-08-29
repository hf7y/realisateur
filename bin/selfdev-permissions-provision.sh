#!/usr/bin/env bash
# selfdev-permissions-provision.sh -- give every self-dev account the
# permissions block it was documented as having, and the per-account
# TMPDIR that keeps its Bash-tool shell out of the shared /tmp namespace,
# so an unattended run can record what it did instead of dying at the gate.
#
# RUNNER: bin/tests/selfdev-permissions-provision.test.sh
# GUARD-TEST: bin/tests/selfdev-permissions-provision.test.sh
# GATE: strict
#
# TRAPS (the rest of this header is in the vault):
# #282's worked example (vim-arcade@monkey's first night): the run shipped
# real work and two writes were REFUSED. The gate fails closed and an agent
# cannot self-grant; only a human-authorised pass closes it.
# Runs ON the host that owns the accounts; every read and write of another
# account's file goes through sudo.
# #620's TMPDIR fix (provision-selfdev-user.sh) writes to ~/.profile, which
# is read by a LOGIN shell. The Bash tool's own shell is neither login nor
# interactive (`case $- in *i*)`, so ~/.bashrc bails too) -- it never sources
# either file, so a settings.json-only account never gets TMPDIR at all, and
# an already-provisioned account only carries the fix in shells it doesn't
# actually use for tool calls. settings.json's own `env` block is read at
# session start regardless of shell type; asserting TMPDIR there closes the
# gap the shell-init files cannot reach.
#

set -uo pipefail

CLI_NAME='selfdev-permissions-provision.sh'
CLI_SUMMARY='give every self-dev account its permissions block and its private TMPDIR'
CLI_USAGE='  selfdev-permissions-provision.sh            report drift, change nothing
  selfdev-permissions-provision.sh --apply    write the block
  selfdev-permissions-provision.sh --strict   exit 1 if any account drifts
  selfdev-permissions-provision.sh --print    print the block and exit'
CLI_FLAGS='--apply --strict --print'
CLI_EXITS='  0  visited every account; no --strict, or --strict and none drifted
  1  --strict was given and at least one account lacks the block (checked
     after --apply, so --apply --strict verifies its own work)
  6  BLIND -- an account home exists but its settings could not be read or
     parsed, or the roster matched no account at all. NEVER 0.'
CLI_POSITIONAL=any
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

HOME_ROOT="${HOME_ROOT:-/home}"
SUDO="${SUDO-sudo}"

# The roster is DERIVED from the account homes that actually carry a .claude
# directory, not typed. A typed list is what produced the 2026-07-27 shim gap
# (three shims existed because three were typed). Override with ACCOUNTS= for
# a scoped run.
DEFAULT_ACCOUNTS=''
if [ -z "${ACCOUNTS:-}" ]; then
  for d in "$HOME_ROOT"/*/; do
    u="$(basename "$d")"
    [ "$u" = "zach" ] && continue          # the human's own account is not a self-dev account
    $SUDO test -d "$d/.claude" 2>/dev/null || continue
    DEFAULT_ACCOUNTS="$DEFAULT_ACCOUNTS $u"
  done
  ACCOUNTS="$DEFAULT_ACCOUNTS"
fi

APPLY=0; STRICT=0; PRINT=0
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    --strict) STRICT=1 ;;
    --print) PRINT=1 ;;
  esac
done

# THE BLOCK. Held here as one jq literal so there is one source of truth for
# it -- the drift check and the write read the SAME value, which is the
# difference between a guard and two guesses.
read -r -d '' PERMS <<'JSON'
{
  "defaultMode": "auto",
  "allow": [
    "WebSearch",
    "WebFetch"
  ],
  "deny": [
    "Bash(git push --force:*)",
    "Bash(git push -f:*)",
    "Bash(git push origin main:*)",
    "Bash(git push origin HEAD:main:*)",
    "Bash(gh pr merge --admin:*)",
    "Bash(gh repo delete:*)",
    "Bash(gh repo archive:*)",
    "Bash(crontab:*)",
    "Bash(sudo:*)",
    "Bash(rm -rf /:*)",
    "Bash(rm -rf ~:*)",
    "Bash(rm -rf $HOME:*)",
    "Read(//etc/selfdev/app.pem)",
    "Read(//home/*/.config/gh/hosts.yml)"
  ]
}
JSON

if [ "$PRINT" = 1 ]; then printf '%s\n' "$PERMS"; exit 0; fi

set -- $ACCOUNTS
[ "$#" -gt 0 ] || {
  echo "BLIND: no self-dev account found under $HOME_ROOT -- nothing was checked." >&2
  echo "$CLI_NAME: nothing was measured. This is NOT a clean result." >&2
  exit 6
}

echo "selfdev-permissions-provision -- $(date '+%Y-%m-%d %H:%M')"
if [ "$APPLY" = 1 ]; then
  echo "(--apply: writing the block; every settings.json is backed up first)"
else
  echo "(read-only: reporting drift, changing nothing -- pass --apply to fix)"
fi
echo

drift=0; blind=0; okc=0

for u in "$@"; do
  f="$HOME_ROOT/$u/.claude/settings.json"
  # Per-account, not a literal like PERMS: each account's TMPDIR points at
  # its OWN home, never another tenant's.
  tmpdir="$HOME_ROOT/$u/tmp"

  if ! $SUDO test -f "$f" 2>/dev/null; then
    # No settings file at all is drift, not BLIND: the state is known (there
    # is no block) and --apply can create one.
    echo "  DRIFT $u: no settings.json at all"
    drift=$((drift+1))
    [ "$APPLY" = 1 ] || continue
    cur='{}'
  else
    cur="$($SUDO cat "$f" 2>/dev/null)"
    if ! printf '%s' "$cur" | jq -e . >/dev/null 2>&1; then
      # Unparseable is BLIND, never "drift": overwriting a file we cannot read
      # would destroy state we never saw.
      echo "  BLIND $u: settings.json is unreadable or not valid JSON -- NOT overwriting it"
      blind=$((blind+1))
      continue
    fi

    # Drift is measured against the WHOLE permissions block, not just the
    # presence of a `permissions` key. bibliothecaire had
    # {"allow":["WebSearch","WebFetch"]} and no defaultMode and no deny -- a
    # key that exists and grants nothing is exactly the "a guard that exists
    # and grades nothing" shape (#294). env.TMPDIR rides the same drift check
    # (#620): a settings.json that already has the permissions block but not
    # TMPDIR is still drifted.
    if printf '%s' "$cur" | jq -e --argjson want "$PERMS" --arg tmpdir "$tmpdir" \
        '.permissions == $want and .env.TMPDIR == $tmpdir' >/dev/null 2>&1; then
      echo "  ok    $u"
      okc=$((okc+1))
      continue
    fi
    have="$(printf '%s' "$cur" | jq -c '.permissions // "absent"' 2>/dev/null)"
    havetmp="$(printf '%s' "$cur" | jq -r '.env.TMPDIR // "absent"' 2>/dev/null)"
    echo "  DRIFT $u: permissions=$have env.TMPDIR=$havetmp"
    drift=$((drift+1))
    [ "$APPLY" = 1 ] || continue
  fi

  # A settings.json TMPDIR that points nowhere is worse than none -- create
  # the directory itself before pointing an account's shell at it. 0700: the
  # directory permission is what keeps a cross-tenant read out even if a
  # file inside it is created world-readable (#620).
  if ! $SUDO test -d "$tmpdir" 2>/dev/null; then
    $SUDO mkdir -p "$tmpdir" 2>/dev/null
    $SUDO chown "$u:$u" "$tmpdir" 2>/dev/null
    $SUDO chmod 700 "$tmpdir" 2>/dev/null
  fi

  # WRITE. Merge, never replace: env/enabledPlugins/extraKnownMarketplaces are
  # this account's live config (the OAuth token lives in env) and clobbering
  # them would take the account off the air to fix its permissions. env is
  # merged key-by-key for the same reason -- only .env.TMPDIR is asserted.
  new="$(printf '%s' "$cur" | jq --argjson want "$PERMS" --arg tmpdir "$tmpdir" \
    '.permissions = $want | .env.TMPDIR = $tmpdir' 2>/dev/null)"
  if [ -z "$new" ]; then
    echo "        -> FAILED to build the new settings; left untouched"
    continue
  fi
  # 0600 ON THE BACKUP: `cp -p` copies the source's mode (#409).
  bak="$f.bak-$(date +%Y%m%d%H%M%S)"
  if $SUDO test -f "$f"; then
    $SUDO cp -p "$f" "$bak" && $SUDO chmod 600 "$bak"
    $SUDO chmod 600 "$f"
  fi
  if printf '%s\n' "$new" | $SUDO tee "$f" >/dev/null 2>&1; then
    $SUDO chown "$u:$u" "$f" 2>/dev/null
    $SUDO chmod 0600 "$f" 2>/dev/null
    # Verify by RE-READING. A write that reports success and did not land is
    # the failure this estate keeps paying for.
    if $SUDO cat "$f" 2>/dev/null | jq -e --argjson want "$PERMS" --arg tmpdir "$tmpdir" \
        '.permissions == $want and .env.TMPDIR == $tmpdir' >/dev/null 2>&1; then
      echo "        -> written (backup: $bak)"
      drift=$((drift-1)); okc=$((okc+1))
    else
      echo "        -> WROTE but the re-read does not match -- treat as drifted"
    fi
  else
    echo "        -> FAILED to write (need sudo on this host?)"
  fi
done

echo
echo "== $okc with the block, $drift drifted, $blind BLIND, out of $# account(s) =="

[ "$blind" -eq 0 ] || { echo "$CLI_NAME: $blind account(s) unreadable -- counts above are NOT trustworthy."; exit 6; }
[ "$STRICT" = 1 ] && [ "$drift" -gt 0 ] && exit 1
exit 0
