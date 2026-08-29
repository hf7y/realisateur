#!/usr/bin/env bash
# selfdev-hooks-provision.sh -- every self-dev account runs THE-FLOOR gate
# 3.2's closeout hooks (SubagentStop, Stop), the verb-pin hook (SessionStart, #708), the path guard (PreToolUse, #707), the credential hold (PreToolUse+UserPromptSubmit, #714), the memory budget guard+report (PreToolUse+SessionStart, #715) and the session marker (SessionStart+SessionEnd, hf7y/vim-arcade#207): wired in settings.json, and file.
#
# RUNNER: bin/tests/selfdev-hooks-provision.test.sh -- and an operator, on the host
# GUARD-TEST: bin/tests/selfdev-hooks-provision.test.sh
# GATE: strict
#
# THE SPLIT (#272): something else installs the hook FILE; this wires settings.json
# ("Zach's file"), which #282 crossed that boundary for with `permissions`. The file half
# is the verb build -- carried in bin/lib/carries.tsv, installed on the release tick --
# since #264 got off shims. A sibling of selfdev-permissions-provision.sh, not a merge (#294).
#
# SESSION MARKER (hf7y/vim-arcade#207): hooks/session-marker.sh was deleted
# 2026-08-22 (#511) as a no-op -- it was wired into NO account's settings.json
# on any host, so scheduler's lib/registry-lock.sh had been reading an
# always-absent $REGISTRY_DIR/<project>.interactive marker as "no human
# present" regardless of whether one was. That reader was never removed. This
# restores the writer and, unlike before, actually wires it below, so a live
# interactive session in a self-dev account's own checkout makes that
# project's unattended jobs defer instead of racing it.
#
# Env overrides (tests only): HOME_ROOT, ACCOUNTS, SUDO, SELFDEV_HOOK_SRC, SELFDEV_STOP_HOOK_SRC, SELFDEV_SESSIONSTART_HOOK_SRC, SELFDEV_PRETOOLUSE_HOOK_SRC, SELFDEV_CREDENTIAL_HOLD_HOOK_SRC, SELFDEV_MEMORY_BUDGET_HOOK_SRC, SELFDEV_SESSIONSTART_MEMORY_BUDGET_HOOK_SRC, SELFDEV_SESSION_MARKER_HOOK_SRC.

set -uo pipefail

CLI_NAME='selfdev-hooks-provision.sh'
CLI_SUMMARY='wire the SubagentStop, Stop, SessionStart, SessionEnd, PreToolUse and UserPromptSubmit hooks every self-dev account already has installed'
CLI_USAGE='  selfdev-hooks-provision.sh            report drift, change nothing
  selfdev-hooks-provision.sh --apply    write the block
  selfdev-hooks-provision.sh --strict   exit 1 if any account drifts
  selfdev-hooks-provision.sh --print    print the block and exit'
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

# One jq literal: the drift check and the write read the SAME value.
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
  ],
  "Stop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/stop-residue-gate.sh"
        }
      ]
    }
  ],
  "SessionStart": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/session-start-verb-pin.sh"
        },
        {
          "type": "command",
          "command": "~/.claude/hooks/session-start-memory-budget.sh"
        },
        {
          "type": "command",
          "command": "~/.claude/hooks/session-marker.sh acquire"
        }
      ]
    }
  ],
  "SessionEnd": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/session-marker.sh release"
        }
      ]
    }
  ],
  "PreToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/pretooluse-path-guard.sh"
        },
        {
          "type": "command",
          "command": "~/.claude/hooks/pretooluse-memory-budget.sh"
        }
      ]
    },
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/pretooluse-credential-hold.sh"
        }
      ]
    }
  ],
  "UserPromptSubmit": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/pretooluse-credential-hold.sh"
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
  exit 6
}

echo "selfdev-hooks-provision -- $(date '+%Y-%m-%d %H:%M')"
if [ "$APPLY" = 1 ]; then
  echo "(--apply: writing the block; every settings.json is backed up first)"
else
  echo "(read-only: reporting drift, changing nothing -- pass --apply to fix)"
fi
echo

drift=0; blind=0; okc=0

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/propagation-set.sh"  # THE FILES, NOT ONLY THE BLOCK: refreshed from a local CLONE -- #385/#386 lost 13 of 15 accounts to this, FOUR live versions and none of them main's. PROP_HOST_PIN, not the literal layout: propagation-set.sh owns it.
declare -A HOOK_SRC=(
  [subagent-closeout.sh]="${SELFDEV_HOOK_SRC:-$PROP_HOST_PIN/realisateur/hooks/subagent-closeout.sh}"
  [stop-residue-gate.sh]="${SELFDEV_STOP_HOOK_SRC:-$PROP_HOST_PIN/realisateur/hooks/stop-residue-gate.sh}"
  [session-start-verb-pin.sh]="${SELFDEV_SESSIONSTART_HOOK_SRC:-$PROP_HOST_PIN/realisateur/hooks/session-start-verb-pin.sh}"
  [pretooluse-path-guard.sh]="${SELFDEV_PRETOOLUSE_HOOK_SRC:-$PROP_HOST_PIN/realisateur/hooks/pretooluse-path-guard.sh}"
  [pretooluse-credential-hold.sh]="${SELFDEV_CREDENTIAL_HOLD_HOOK_SRC:-$PROP_HOST_PIN/realisateur/hooks/pretooluse-credential-hold.sh}"
  [pretooluse-memory-budget.sh]="${SELFDEV_MEMORY_BUDGET_HOOK_SRC:-$PROP_HOST_PIN/realisateur/hooks/pretooluse-memory-budget.sh}"
  [session-start-memory-budget.sh]="${SELFDEV_SESSIONSTART_MEMORY_BUDGET_HOOK_SRC:-$PROP_HOST_PIN/realisateur/hooks/session-start-memory-budget.sh}"
  [session-marker.sh]="${SELFDEV_SESSION_MARKER_HOOK_SRC:-$PROP_HOST_PIN/realisateur/hooks/session-marker.sh}"
)
hook_drift=0
hook_sum() { $SUDO md5sum "$1" 2>/dev/null | cut -d' ' -f1; }
declare -A HOOK_WANT_SUM=()
for hn in "${!HOOK_SRC[@]}"; do
  HOOK_WANT_SUM[$hn]="$(hook_sum "${HOOK_SRC[$hn]}")"
  [ -n "${HOOK_WANT_SUM[$hn]}" ] || echo "  BLIND the hook file source is unreadable at ${HOOK_SRC[$hn]} -- not checked"
done

for u in "$@"; do
  f="$HOME_ROOT/$u/.claude/settings.json"

  for hn in "${!HOOK_SRC[@]}"; do
    want_sum="${HOOK_WANT_SUM[$hn]}"
    [ -n "$want_sum" ] || continue
    hf="$HOME_ROOT/$u/.claude/hooks/$hn"
    got_sum="$(hook_sum "$hf")"
    if [ "$got_sum" = "$want_sum" ]; then
      :
    else
      echo "  DRIFT $u: hook FILE is ${got_sum:-absent}, build has ${want_sum} ($hn)"
      hook_drift=$((hook_drift+1))
      if [ "$APPLY" = 1 ]; then
        if $SUDO install -m 755 -D "${HOOK_SRC[$hn]}" "$hf" 2>/dev/null; then
          $SUDO chown "$u:$u" "$hf" 2>/dev/null || true
          echo "        -> refreshed from the build ($hn)"
        else
          echo "        -> FAILED to refresh the hook file ($hn)"
        fi
      fi
    fi
  done

  if ! $SUDO test -f "$f" 2>/dev/null; then
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

  new="$(printf '%s' "$cur" | jq --argjson want "$HOOKS" '.hooks = $want' 2>/dev/null)"
  if [ -z "$new" ]; then
    echo "        -> FAILED to build the new settings; left untouched"
    continue
  fi
  # 0600 ALWAYS: `cp -p` copies the source's mode, and two live settings.json
  # were 664 -- world-readable copies of a live token (#409).
  bak="$f.bak-$(date +%Y%m%d%H%M%S)"
  if $SUDO test -f "$f"; then
    $SUDO cp -p "$f" "$bak" && $SUDO chmod 600 "$bak"
    $SUDO chmod 600 "$f"
  fi
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
[ "$hook_drift" -gt 0 ] && echo "== $hook_drift account(s) ran a hook FILE that is not the build's =="
echo "== $okc with the block, $drift drifted, $blind BLIND, out of $# account(s) =="

[ "$blind" -eq 0 ] || { echo "$CLI_NAME: $blind account(s) unreadable -- counts above are NOT trustworthy."; exit 6; }
[ "$STRICT" = 1 ] && [ "$drift" -gt 0 ] && exit 1
exit 0
