#!/usr/bin/env bash
# defere.sh -- file the thing you were about to write a paragraph about.
#
# TRAP: "no owner" may NOT silently mean Zach. There are three routing
#   states and refusing to choose is a usage error, not a quiet default.
# TRAP: a project that does not resolve against a live `gh repo view` is
#   refused with the --unroutable form PRINTED, never silently redirected.
#   A guessed destination is how a deferral disappears.
#
# usage: `--help`, from CLI_USAGE below. One source.
# exit codes: `--help`, from CLI_EXITS below. One source.

set -uo pipefail

CLI_NAME='defere.sh'
CLI_SUMMARY='file the thing you were about to write a paragraph about'
CLI_USAGE="  defere.sh '<one line>' --project <name>       file on hf7y/<name>
  defere.sh '<one line>' --human '<why>'        needs a person
  defere.sh '<one line>' --unroutable '<why>'   nothing can own it yet
  defere.sh --ledger                            print the DEFERRED block
  defere.sh --forget                            discard the accumulated block
  options: --body <text> --from <project> --repo owner/name --decider @who --dry-run"
CLI_FLAGS='--project --human --unroutable --body --from --repo --decider --dry-run --ledger --forget'
CLI_POSITIONAL=any
CLI_EXITS='  0  filed, or printed under --dry-run / --ledger
  1  could not file -- destination did not resolve, or gh refused
  2  usage error, including refusing to choose a route
  6  BLIND -- gh unavailable; nothing filed and nothing established'
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"

OWNER="${DEFERE_OWNER:-hf7y}"
# Who is asked when a route needs a person. Not derived from the running
# account: an agent account filing under its own name would be addressing the
# decision to itself, which is the ownerless case with a handle stuck on it.
DECIDER="${DEFERE_DECIDER:-zach}"
WHAT=''; PROJECT=''; HUMAN=''; UNROUTABLE=''; BODY=''; FROM=''; REPO=''
DRY=0; MODE=file

while [ $# -gt 0 ]; do
  case "$1" in
    --project)    PROJECT="${2:-}"; [ -n "$PROJECT" ] || cli_die '--project needs a project name'; shift 2 ;;
    --human)      HUMAN="${2:-}"; [ -n "$HUMAN" ] || cli_die '--human needs a reason a person is required'; shift 2 ;;
    --unroutable) UNROUTABLE="${2:-}"; [ -n "$UNROUTABLE" ] || cli_die '--unroutable needs a reason nothing can own it'; shift 2 ;;
    --body)       BODY="${2:-}"; shift 2 ;;
    --from)       FROM="${2:-}"; shift 2 ;;
    --repo)       REPO="${2:-}"; [ -n "$REPO" ] || cli_die '--repo needs owner/name'; shift 2 ;;
    --decider)    DECIDER="${2:-}"; [ -n "$DECIDER" ] || cli_die '--decider needs a handle'; DECIDER="${DECIDER#@}"; shift 2 ;;
    --dry-run)    DRY=1; shift ;;
    --ledger)     MODE=ledger; shift ;;
    --forget)     MODE=forget; shift ;;
    -*)           cli_die "unknown flag: $1" ;;
    *)            [ -z "$WHAT" ] || cli_die "more than one description given; quote it as one argument: $1"
                  WHAT="$1"; shift ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# THE LEDGER FILE -- per branch, inside .git, so it is never committed and
# never leaks between branches. A session that files six items and then has to
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
ledger_path() {
  local gd br
  gd="$(git rev-parse --git-dir 2>/dev/null)" || return 1
  br="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || br=detached
  printf '%s/defere-ledger.%s' "$gd" "$(printf '%s' "$br" | tr '/' '_')"
}

emit_block() {
  local lp
  lp="$(ledger_path)" || { echo 'defere: not in a git checkout, so there is no branch ledger.' >&2; return 1; }
  printf '<!-- DEFERRED -->\n'
  if [ -s "$lp" ]; then cat "$lp"; else printf -- '- none\n'; fi
  printf '<!-- /DEFERRED -->\n'
}

case "$MODE" in
  ledger) emit_block; exit $? ;;
  forget)
    lp="$(ledger_path)" || exit 1
    rm -f "$lp"; echo "defere: branch ledger discarded ($lp)"; exit 0 ;;
esac

# ---------------------------------------------------------------------------
# THE ROUTE -- exactly one, chosen explicitly.
# ---------------------------------------------------------------------------
[ -n "$WHAT" ] || cli_die "nothing to file: give the one-line description as the first argument"

nroute=0
[ -n "$PROJECT" ] && nroute=$((nroute+1))
[ -n "$HUMAN" ] && nroute=$((nroute+1))
[ -n "$UNROUTABLE" ] && nroute=$((nroute+1))
if [ "$nroute" -eq 0 ]; then
  cli_die "no route chosen. There is no default owner, on purpose -- an unroutable item silently assigned to a person is indistinguishable from one that genuinely needs them. Pick: --project <name> | --human '<why a person>' | --unroutable '<why nothing can own it>'"
fi
[ "$nroute" -eq 1 ] || cli_die 'choose exactly one of --project / --human / --unroutable'

if ! have gh; then
  echo "defere: BLIND -- gh is not on PATH. Nothing was filed, and nothing has been established about where this work went." >&2
  echo "        Do NOT write this into a PR body as an ownerless line: lib/body-grammar.sh" >&2
  echo "        refuses one, because that is the shape that shipped hf7y/realisateur#327" >&2
  echo "        as a no-op. Re-run this where gh works, then cite the issue number." >&2
  exit 6
fi

if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || REPO=''
fi
# The calling project's NAME comes from the remote, not from the directory:
# this repository is routinely worked from a git worktree under
# .claude/worktrees/agent-<hex>, and a deferral stamped "from
# agent-a77f87cd21106fde6" names nothing anyone can act on.
if [ -z "$FROM" ]; then
  if [ -n "$REPO" ]; then FROM="${REPO##*/}"
  else FROM="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo unknown)")"
  fi
fi

TITLE=''; DEST=''; LABEL=''; LEDGER_KIND=''
if [ -n "$PROJECT" ]; then
  DEST="$OWNER/$PROJECT"
  LABEL='deferred'
  TITLE="$WHAT"
  LEDGER_KIND=project
  # PROBED, NOT ASSUMED.
  if ! gh repo view "$DEST" --json name -q .name >/dev/null 2>&1; then
    cat >&2 <<EOF
defere: '$PROJECT' does not resolve to a repository ($DEST is not readable from here).
        NOT redirecting this to a person -- a guessed destination is worse than an
        admitted gap. Either name the right project, or say so out loud:

          defere '$WHAT' --unroutable 'no repo resolves for <owner>; the ownership map has a hole here'
EOF
    exit 1
  fi
elif [ -n "$HUMAN" ]; then
  DEST="${REPO:-$OWNER/$FROM}"
  LABEL='needs-human'
  TITLE="$WHAT"
  BODY="${BODY:+$BODY

}Why this needs a person: $HUMAN"
  LEDGER_KIND=human
else
  DEST="${REPO:-$OWNER/$FROM}"
  LABEL='unroutable'
  TITLE="$WHAT"
  BODY="${BODY:+$BODY

}Why nothing can own this yet: $UNROUTABLE

UNROUTABLE is its own state. It is not a soft way of assigning this to a
person, and it must not be triaged into one without the ownership gap it
records being closed or named."
  LEDGER_KIND=unroutable
fi

# The issue this files must satisfy the same grammar bin/gh-sign.sh enforces
# on `issue create` -- otherwise the front door emits bodies the front door
# refuses. Each route implies its own declaration:
#   --project      routed and owned; nothing to weigh -> NO-DECISION
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
case "$LEDGER_KIND" in
  project) DECLARE="NO-DECISION: @$DECIDER -- routed to $DEST and owned there; nothing here needs a call" ;;
  *)       DECLARE="DECISION: @$DECIDER -- $WHAT" ;;
esac

FULLBODY="$DECLARE

$BODY

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

---
Deferred from **$FROM**${REPO:+ (}${REPO}${REPO:+)} by \`defere\` on $(date -u +%Y-%m-%d).
Filed because the work was left behind deliberately and a paragraph is not a queue.
See realisateur \`bin/lib/body-grammar.sh\` for why this exists."

if [ "$DRY" -eq 1 ]; then
  printf 'defere: DRY RUN -- nothing filed.\n\n'
  printf '  repo:   %s\n  label:  %s\n  title:  %s\n\n  body:\n' "$DEST" "$LABEL" "$TITLE"
  printf '%s\n' "$FULLBODY" | sed 's/^/    /'
  exit 0
fi

# A missing label must not lose the issue. `gh issue create` fails outright on
# an unknown label, so create it first and ignore an already-exists error --
# the alternative is an issue that silently never gets filed, which is the
# original failure wearing a different hat.
gh label create "$LABEL" --repo "$DEST" --color ededed \
   --description 'work deferred from another run; see body' >/dev/null 2>&1 || true

URL="$(gh issue create --repo "$DEST" --title "$TITLE" --body "$FULLBODY" --label "$LABEL" 2>&1)" || {
  printf 'defere: gh refused to file on %s:\n%s\n' "$DEST" "$URL" >&2
  printf '        NOTHING was filed. There is no ownerless line to fall back on --\n' >&2
  printf '        lib/body-grammar.sh refuses one. Fix the destination and re-run.\n' >&2
  exit 1
}
URL="$(printf '%s' "$URL" | grep -oE 'https://[^ ]+' | tail -1)"
NUM="${URL##*/}"

case "$LEDGER_KIND" in
  project) LINE="- $DEST#$NUM -- $WHAT" ;;
  human)   LINE="- $DEST#$NUM -- $WHAT (needs a person: $HUMAN)" ;;
  *)       LINE="- $DEST#$NUM -- UNROUTABLE: $WHAT ($UNROUTABLE)" ;;
esac

if lp="$(ledger_path)"; then
  printf '%s\n' "$LINE" >> "$lp"
fi

printf 'defere: filed %s  [%s]\n' "$URL" "$LABEL"
printf '        ledger line (already accumulated; `defere --ledger` prints the block):\n'
printf '%s\n' "$LINE"
exit 0
