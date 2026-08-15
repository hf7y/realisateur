#!/usr/bin/env bash
# lib/body-grammar.sh -- the grammar of an agent-written issue or PR body.
#
# ONE definition, sourced by everything that has an opinion about a body:
# bin/gh-sign.sh checks it at the write, bin/claim-drift.sh reads the same
# declaration when it grades an open PR. Before this file the first-line rule
# lived in claim-drift.sh (twice -- `declares_itself` and `declaration_kind`
# differ only in return shape) and the DEFERRED rule lived in
# deferral-ledger.sh, and neither could see the other.
#
# Pure bash. No subprocess, no external command: gh-sign.sh runs in front of
# every gh call including cron's, under a minimal PATH where `sed` and `grep`
# were "command not found".
#
# RULES, each with a code that is printed and never renumbered:
#   MISPLACED-DECISION  a `DECISION:`/`NO-DECISION:` line that is not the
#                       first non-empty line. The convention makes the FIRST
#                       line the whole signal; one buried at line 40 is a
#                       decision nobody was asked to make.
#   UNLEDGERED          no `<!-- DEFERRED -->` block. Silence and
#                       nothing-was-deferred are indistinguishable.
#   MULTI-LEDGER        more than one block; a reader cannot tell which is current.
#   UNCLOSED            opened, never closed -- everything after reads as an entry.
#   EMPTY-LEDGER        the block has no entries. Write `- none` and mean it.
#   NO-DESTINATION      an entry naming neither an issue nor `NO-OWNER: <why>`.

GRAMMAR_NO_OWNER_MIN="${GRAMMAR_NO_OWNER_MIN:-25}"

# Printed by the refusal, where a reader actually needs it -- not behind a
# `--template` flag on a separate command they would have to already know about.
grammar_template() {
  cat <<'EOF'
<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

...or, one line each, naming where the work went. `defere` writes these:

<!-- DEFERRED -->
- hf7y/chezz#12 -- orphaned ecosystem-survey shim on chezz@monkey
- NO-OWNER: free the 4th bootstrap slot -- changes what four live accounts
  must hold before they can fetch anything; needs a human decision
<!-- /DEFERRED -->
EOF
}

# decision | no-decision | none -- what the body's first non-empty line opens
# with, markdown furniture stripped. The word must OPEN the line: matching it
# anywhere lets a body that merely quotes the convention exempt itself.
grammar_declaration() {
  local line stripped
  while IFS= read -r line; do
    case "$line" in *[![:space:]]*) ;; *) continue ;; esac
    stripped="${line#"${line%%[![:space:]#>*_-]*}"}"
    case "$stripped" in
      [Nn][Oo]-[Dd][Ee][Cc][Ii][Ss][Ii][Oo][Nn]:*) printf 'no-decision\n'; return ;;
      [Dd][Ee][Cc][Ii][Ss][Ii][Oo][Nn]:*)          printf 'decision\n';    return ;;
    esac
    printf 'none\n'; return
  done <<<"$1"
  printf 'none\n'
}

# Print one `CODE  message` line per violation; return the count (capped at
# 125 so it survives being used as an exit status). Never exits: the caller
# decides whether a finding refuses a write or annotates a PR.
grammar_check() {
  local body="$1" line stripped n=0 lineno=0 first_seen=0
  local open=0 close=0 in_block=0 entries=0 entry='' fenced=0

  _find() { printf '%s  %s\n' "$1" "$2"; n=$((n + 1)); }

  # An entry is a bullet plus its continuation lines; judge it when the next
  # bullet (or the closing marker) arrives, not per physical line.
  _judge_entry() {
    [ -n "$entry" ] || return 0
    entries=$((entries + 1))
    case "$entry" in
      *[a-zA-Z0-9_.-]/[a-zA-Z0-9_.-]*'#'[0-9]*) entry=''; return 0 ;;
      *http*://*) entry=''; return 0 ;;
      '- none'|'- none.'|'-none') entry=''; return 0 ;;
    esac
    case "$entry" in
      *NO-OWNER:*)
        local why="${entry#*NO-OWNER:}"
        why="${why#"${why%%[![:space:]]*}"}"
        if [ "${#why}" -lt "$GRAMMAR_NO_OWNER_MIN" ]; then
          _find NO-DESTINATION "\`NO-OWNER:\` with no reason (>= $GRAMMAR_NO_OWNER_MIN chars saying why nothing can own it): ${entry:0:70}"
        fi ;;
      *)
        _find NO-DESTINATION "names no issue and does not say NO-OWNER: ${entry:0:70}" ;;
    esac
    entry=''
  }

  while IFS= read -r line; do
    lineno=$((lineno + 1))
    case "$line" in '```'*) fenced=$((1 - fenced)); continue ;; esac
    [ "$fenced" -eq 1 ] && continue

    stripped="${line#"${line%%[![:space:]]*}"}"

    case "$stripped" in
      '<!-- DEFERRED -->'|'<!--DEFERRED-->')
        open=$((open + 1)); in_block=1; continue ;;
      '<!-- /DEFERRED -->'|'<!--/DEFERRED-->')
        _judge_entry; close=$((close + 1)); in_block=0; continue ;;
    esac

    if [ "$in_block" -eq 1 ]; then
      case "$stripped" in
        '- '*|'* '*|[0-9]*'. '*) _judge_entry; entry="$stripped" ;;
        '') _judge_entry ;;
        *) [ -n "$entry" ] && entry="$entry $stripped" ;;
      esac
      continue
    fi

    case "$line" in *[![:space:]]*) ;; *) continue ;; esac
    local decl="${stripped#"${stripped%%[![:space:]#>*_-]*}"}"
    case "$decl" in
      [Dd][Ee][Cc][Ii][Ss][Ii][Oo][Nn]:*|[Nn][Oo]-[Dd][Ee][Cc][Ii][Ss][Ii][Oo][Nn]:*)
        [ "$first_seen" -eq 1 ] && _find MISPLACED-DECISION \
          "line $lineno opens with a decision, but the first non-empty line did not. The convention reads line 1 only." ;;
    esac
    first_seen=1
  done <<<"$body"

  [ "$in_block" -eq 1 ] && { _judge_entry; _find UNCLOSED 'the DEFERRED block is never closed (<!-- /DEFERRED --> missing).'; }
  [ "$open" -eq 0 ] && _find UNLEDGERED 'no <!-- DEFERRED --> block. Say what was left behind, or "- none".'
  [ "$open" -gt 1 ] && _find MULTI-LEDGER "$open DEFERRED blocks -- a reader cannot tell which is current. Keep one."
  [ "$open" -ge 1 ] && [ "$entries" -eq 0 ] && _find EMPTY-LEDGER 'the DEFERRED block is empty. Write "- none" and mean it, or list what was left.'

  [ "$n" -gt 125 ] && n=125
  return "$n"
}
