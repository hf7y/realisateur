#!/usr/bin/env bash
# defere.sh -- file the thing you were about to write a paragraph about.
#
#
# ============================================================================
# WHY THIS EXISTS, AND WHY IT IS THE PRIMARY DELIVERABLE
# ============================================================================
#
# On 2026-08-07 eight agents deferred roughly ten real work items across
# hf7y/realisateur#95..#104. Every one of them wrote a careful, well-argued
# paragraph explaining what it was leaving behind and why. Not one ran
# `gh issue create`.
#
# Read that again, because the usual diagnosis is wrong. This was not
# laziness and it was not forgetting. Writing "**Orphaned shims** on monkey
# accounts (`ecosystem-survey`, `milestone-audit`, `steward-survey`) -- named,
# left." is STRICTLY MORE EFFORT than filing an issue would have been. The
# agents did the expensive thing and skipped the cheap one.
#
# So the incentive is backwards, and no amount of guarding fixes a backwards
# incentive -- a guard raises the cost of the wrong path, which in a system
# where the wrong path is already the expensive one just makes everything
# cost more. The only lever that changes behaviour is making the RIGHT path
# cheaper than the paragraph. That is this script, and the guard
# (the DEFERRED grammar in bin/lib/body-grammar.sh, refused at the write by
# bin/gh-sign.sh) is secondary to it.
#
#   defere 'orphaned ecosystem-survey shim on chezz@monkey' --project chezz
#
# One line. It files the issue, and prints the ledger line the guard wants,
# and appends that line to a per-branch ledger so `defere --ledger` at the end
# of the session emits the whole block ready to paste into the PR body. The
# compliant path now costs less typing than the sentence describing it.
#
# ============================================================================
# THE ROUTING STATES -- and why "no owner" may not silently mean "Zach"
# ============================================================================
#
# Zach, 2026-08-07: "issues keep coming to Zach, but they should really be
# bouncing around the self-dev users in a healthy ecosystem."
#
# Everything lands on him because there is no other default. An UNROUTABLE
# finding and a genuinely-needs-a-human finding arrive in the same queue
# looking identical -- which is exactly the BLIND-grading-as-CLEAN conflation
# guard-estate check E exists to stop, one level up. A queue that receives
# both cannot be triaged, so it stops being read, and then the true items in
# it are missed along with the noise.
#
# There is therefore NO DEFAULT ROUTE. Every invocation must name one of
# three states, and refusing to choose is a usage error rather than a quiet
# assignment:
#
#   --project <name>   the owning project. THE COMMON CASE, and the one the
#                      brief is really about. A file path or a host usually
#                      determines it without judgement: `bashify/lib/coin.sh`
#                      -> bashify; a shim on chezz@monkey -> chezz; a health
#                      script -> senechal. Files on hf7y/<name>, labelled
#                      `deferred`, where that project's own self-dev run can
#                      find it.
#
#   --human <why>      it needs a person: a decision, a credential, a `sudo`,
#                      a judgement about risk. Files on the CALLING repo
#                      labelled `needs-human`. This queue is allowed to be
#                      small and is supposed to be.
#
#   --unroutable <why> nothing can own it yet, and saying so is the honest
#                      answer. Files on the CALLING repo labelled
#                      `unroutable`. IT IS NOT A SYNONYM FOR --human. The
#                      count of these is itself a finding -- a rising
#                      unroutable count means the ownership map has a hole,
#                      which is information you lose the moment you let it
#                      drain into a person's inbox.
#
# ROUTING IS PROBED, NOT ASSUMED. hf7y/realisateur#102 established that every
# uid 3000-3099 account on monkey has a matching `hf7y/<name>` repository --
# none missing, none invented. That convention is the routing table, and this
# script does not cache it: `--project X` resolves to `hf7y/X` and is checked
# with a live `gh repo view`. A project that does not resolve is refused with
# the `--unroutable` form printed, NOT silently redirected. A guessed
# destination is worse than an admitted gap (MEMORY: liveness probes, not
# flags).
#
# ============================================================================
# IT FILES BY DEFAULT, WHICH INVERTS THIS ESTATE'S USUAL --apply IDIOM
# ============================================================================
#
# Deliberate, and worth naming because it looks like a violation of
# BUILD-DISCIPLINE's "every guard stops one step short of the irreversible
# thing". Two reasons it is not:
#
#   1. This is not a guard. Nothing here is irreversible or destructive: the
#      worst outcome is a spurious issue, which costs one click to close.
#   2. An `--apply` flag would restore the exact cost asymmetry the script
#      exists to remove. The failure mode being fixed is UNFILED work; making
#      filing take two attempts optimises against the wrong error.
#
# `--dry-run` prints exactly what would be filed and files nothing, for when
# you want to see the shape first.
#
# ============================================================================
# THE MODEL IT COPIES: bibliothecaire's `consulte`
# ============================================================================
#
# This is not a new pattern. `consulte` files a GitHub issue on
# hf7y/bibliothecaire labelled `request`, and bibliothecaire's own scheduled
# run works that queue -- one project, issue-driven intake, actually
# functioning today. The gap was never the mechanism; it was that the
# mechanism was built once, for one consumer, and never generalised. This is
# the generalisation of the CLIENT half. The WORKER half -- something on the
# other end that drains the queue -- exists only for bibliothecaire, and for
# realisateur it does not exist at all (there is no `realisateur` account on
# monkey). See the report accompanying this change: a filed item with no
# worker is still better than a paragraph, because it is addressable and it
# accumulates visibly, but it is not the same as done.
#
# usage: `--help`, from CLI_USAGE below. One source.
#
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
# remember all six to write the PR body has re-created the problem in a
# smaller box, so the accumulation is the script's job, not the author's.
# ---------------------------------------------------------------------------
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
#   --human        a person is required, and named     -> DECISION
#   --unroutable   the ownership map has a hole        -> DECISION
# The DEFERRED block is `- none` because filing IS the destination: this issue
# is where the work went, so it has left nothing further behind.
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
