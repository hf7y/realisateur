#!/usr/bin/env bash
# selfdev-hooks-provision.sh -- give every self-dev account the SubagentStop
# closeout hook it was installed with and never wired, so THE-FLOOR gate 3.2 is MET in substance, not just in the hook file's existence.
#
# RUNNER: bin/tests/selfdev-hooks-provision.test.sh
# GUARD-TEST: bin/tests/selfdev-hooks-provision.test.sh
# GATE: strict
#
# hf7y/realisateur#272: install-shims.sh installs the hook file on every
# account but will not wire settings.json itself ("Zach's file"); #282 already
# crossed that boundary for `permissions`, applied here to #272's gap. A
# sibling of selfdev-permissions-provision.sh (same shape, #321), not a merge into it -- different questions, per #294.
#
# Env overrides (test suite only): HOME_ROOT, ACCOUNTS, SUDO. See --help.

set -uo pipefail

CLI_NAME='selfdev-hooks-provision.sh'
CLI_SUMMARY='wire the SubagentStop closeout hook every self-dev account already has installed'
CLI_USAGE='  selfdev-hooks-provision.sh            report drift, change nothing
  selfdev-hooks-provision.sh --apply    write the block
  selfdev-hooks-provision.sh --strict   exit 1 if any account drifts
  selfdev-hooks-provision.sh --print    print the block and exit'
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

# DERIVED, not typed -- a typed list is what produced the 2026-07-27 shim gap.
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

# One jq literal: the drift check and the write read the SAME value. Wires the path install-shims.sh already installs.
read -r -d '' HOOKS <<'JSON'
{
  "SubagentStop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/subagent-closeout.sh"
        }
      ]
    }
  ]
}
JSON

if [ "$PRINT" = 1 ]; then printf '%s\n' "$HOOKS"; exit 0; fi

set -- $ACCOUNTS
[ "$#" -gt 0 ] || {
  echo "BLIND: no self-dev account found under $HOME_ROOT -- nothing was checked." >&2
  echo "$CLI_NAME: nothing was measured. This is NOT a clean result." >&2
  exit 2
}

echo "selfdev-hooks-provision -- $(date '+%Y-%m-%d %H:%M')"
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
    # no file is DRIFT, not BLIND: state is known, --apply can create one
    echo "  DRIFT $u: no settings.json at all"
    drift=$((drift+1))
    [ "$APPLY" = 1 ] || continue
    cur='{}'
  else
    cur="$($SUDO cat "$f" 2>/dev/null)"
    if ! printf '%s' "$cur" | jq -e . >/dev/null 2>&1; then
      # unparseable is BLIND, never DRIFT: never overwrite state we can't read
      echo "  BLIND $u: settings.json is unreadable or not valid JSON -- NOT overwriting it"
      blind=$((blind+1))
      continue
    fi

    if printf '%s' "$cur" | jq -e --argjson want "$HOOKS" '.hooks == $want' >/dev/null 2>&1; then
      echo "  ok    $u"
      okc=$((okc+1))
      continue
    fi
    have="$(printf '%s' "$cur" | jq -c '.hooks // "absent"' 2>/dev/null)"
    echo "  DRIFT $u: hooks=$have"
    drift=$((drift+1))
    [ "$APPLY" = 1 ] || continue
  fi

  # merge, never replace: clobbering env/permissions would take the account off the air or reopen #282
  new="$(printf '%s' "$cur" | jq --argjson want "$HOOKS" '.hooks = $want' 2>/dev/null)"
  if [ -z "$new" ]; then
    echo "        -> FAILED to build the new settings; left untouched"
    continue
  fi
  bak="$f.bak-$(date +%Y%m%d%H%M%S)"
  $SUDO test -f "$f" && $SUDO cp -p "$f" "$bak"
  if printf '%s\n' "$new" | $SUDO tee "$f" >/dev/null 2>&1; then
    $SUDO chown "$u:$u" "$f" 2>/dev/null
    $SUDO chmod 0600 "$f" 2>/dev/null
    # verify by re-reading: success-that-did-not-land is the recurring failure
    if $SUDO cat "$f" 2>/dev/null | jq -e --argjson want "$HOOKS" '.hooks == $want' >/dev/null 2>&1; then
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
