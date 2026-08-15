#!/usr/bin/env bash
# selfdev-permissions-provision.sh -- give every self-dev account the
# permissions block it was documented as having and never had, so an
# unattended run can record what it did instead of dying at the gate.
#
# GUARD: does every self-dev account's ~/.claude/settings.json carry a
#        permissions block with defaultMode and the deny floor?
# RUNNER: bin/tests/selfdev-permissions-provision.test.sh
# GUARD-TEST: bin/tests/selfdev-permissions-provision.test.sh
# GATE: strict
# VERIFIED: 2026-08-15 via bash bin/tests/selfdev-permissions-provision.test.sh and a --check run against all 14 accounts on monkey
#
# WHY THIS EXISTS. hf7y/realisateur#282: THE-FLOOR.md documents self-dev
# accounts as running `"permissions": {"defaultMode":"auto"}` with deny rules
# layered on for genuinely risky actions. bin/setup-selfdev-project.sh writes
# no permissions block at all, so none of them had one. Probed 2026-08-15:
# 13 of 14 accounts on monkey had no `permissions` key whatsoever.
#
# What that costs, from the worked example in #282 (vim-arcade@monkey's first
# night): the run built and shipped real work, and two writes were REFUSED --
# one recording what it had done, one creating the settings file that would
# have granted it. The gate fails closed, so nothing was half-written; the run
# simply could not record itself. Routing around it from Bash was considered
# and correctly rejected: an agent cannot self-grant, which is the entire
# point of the gate. Only a human-authorised pass like this one can.
#
# THE DENY FLOOR, and why each line is on it. Zach's instruction (2026-08-15)
# was "whatever allows them to keep going within unattended scope best" -- so
# this maximises autonomy and denies only what is IRREVERSIBLE or REACHES
# OUTSIDE the account. Everything else is allowed, because a gate that stops
# ordinary work unattended is the defect being fixed, not the fix.
#
#   git push --force / -f     Rewrites published history. Recoverable only
#                             from another clone, and the accounts share
#                             remotes. Never needed by ordinary work.
#   git push ... main         CLAUDE.md: main is protected and a direct push
#                             is rejected for everyone. An agent that tries is
#                             burning a run on a wall; 5 failed runs and 15
#                             stranded salvage branches came from exactly this.
#   gh pr merge --admin       Routes around a required check. That is a human
#                             decision with a reason, every time (#125), and
#                             #288 is what unattended merging already cost.
#   gh repo delete / archive   Irreversible, and reaches every consumer.
#   crontab                   A live crontab is shared machine state; an agent
#                             already modified one under a second user account
#                             (2026-07-25). notify-senechal is the channel.
#   sudo                      The account boundary IS the blast radius.
#   rm -rf on $HOME or /      Unrecoverable, no backup is proven (THE-FLOOR
#                             gate 2.2: no snapshot exists anywhere).
#   reading the App key and gh hosts.yml
#                             Credentials. The account authenticates through
#                             them; it never needs to READ them, and a read is
#                             how one ends up echoed into an issue body.
#
# THE ALLOW LIST is deliberately short. `.claude/**` writes are what #282 is
# about -- an account must be able to write its own harness state -- and the
# two network reads are what bibliothecaire already had.
#
# Usage:
#   selfdev-permissions-provision.sh              report drift, change nothing
#   selfdev-permissions-provision.sh --apply      write the block
#   selfdev-permissions-provision.sh --strict     exit 1 if any account drifts
#   selfdev-permissions-provision.sh --print      print the block and exit
#
# Runs ON the host that owns the accounts (monkey). Every read and write of
# another account's file goes through sudo; the script never edits a file it
# can reach without one, so it cannot quietly rewrite the invoking user's own
# settings.
#
# Env overrides (used by the test suite, not normally set):
#   HOME_ROOT=/home   where account home directories live
#   ACCOUNTS="a b"    the accounts to visit (default: the roster below)
#   SUDO=sudo         the privilege command (the suite sets it empty)

set -uo pipefail

CLI_NAME='selfdev-permissions-provision.sh'
CLI_SUMMARY='give every self-dev account the permissions block it was documented as having'
CLI_USAGE='  selfdev-permissions-provision.sh            report drift, change nothing
  selfdev-permissions-provision.sh --apply    write the block
  selfdev-permissions-provision.sh --strict   exit 1 if any account drifts
  selfdev-permissions-provision.sh --print    print the block and exit'
CLI_FLAGS='--apply --strict --print'
CLI_EXITS='  0  visited every account; no --strict, or --strict and none drifted
  1  --strict was given and at least one account lacks the block (checked
     after --apply, so --apply --strict verifies its own work)
  2  BLIND -- an account home exists but its settings could not be read or
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
  echo "$CLI_NAME: no self-dev account found under $HOME_ROOT -- nothing was checked. This is NOT a clean result." >&2
  exit 2
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

    # Drift is measured against the WHOLE block, not just the presence of a
    # `permissions` key. bibliothecaire had {"allow":["WebSearch","WebFetch"]}
    # and no defaultMode and no deny -- a key that exists and grants nothing
    # is exactly the "a guard that exists and grades nothing" shape (#294).
    if printf '%s' "$cur" | jq -e --argjson want "$PERMS" '.permissions == $want' >/dev/null 2>&1; then
      echo "  ok    $u"
      okc=$((okc+1))
      continue
    fi
    have="$(printf '%s' "$cur" | jq -c '.permissions // "absent"' 2>/dev/null)"
    echo "  DRIFT $u: permissions=$have"
    drift=$((drift+1))
    [ "$APPLY" = 1 ] || continue
  fi

  # WRITE. Merge, never replace: env/enabledPlugins/extraKnownMarketplaces are
  # this account's live config (the OAuth token lives in env) and clobbering
  # them would take the account off the air to fix its permissions.
  new="$(printf '%s' "$cur" | jq --argjson want "$PERMS" '.permissions = $want' 2>/dev/null)"
  if [ -z "$new" ]; then
    echo "        -> FAILED to build the new settings; left untouched"
    continue
  fi
  bak="$f.bak-$(date +%Y%m%d%H%M%S)"
  $SUDO test -f "$f" && $SUDO cp -p "$f" "$bak"
  if printf '%s\n' "$new" | $SUDO tee "$f" >/dev/null 2>&1; then
    $SUDO chown "$u:$u" "$f" 2>/dev/null
    $SUDO chmod 0600 "$f" 2>/dev/null
    # Verify by RE-READING. A write that reports success and did not land is
    # the failure this estate keeps paying for.
    if $SUDO cat "$f" 2>/dev/null | jq -e --argjson want "$PERMS" '.permissions == $want' >/dev/null 2>&1; then
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

[ "$blind" -eq 0 ] || { echo "$CLI_NAME: $blind account(s) unreadable -- counts above are NOT trustworthy."; exit 2; }
[ "$STRICT" = 1 ] && [ "$drift" -gt 0 ] && exit 1
exit 0
