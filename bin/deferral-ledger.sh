#!/usr/bin/env bash
# deferral-ledger.sh -- does this pull request say where the work it deferred went?
#
# GUARD: does this pull request say where the work it deferred went?
# RUNNER: .github/workflows/deferral-ledger.yml bin/tests/deferral-ledger.test.sh
# GUARD-TEST: bin/tests/deferral-ledger.test.sh
# GATE: strict --body-file $TREE/PR_BODY.md
# VERIFIED: 2026-08-07 via bash bin/deferral-ledger.sh --strict 95 96 97 98 99 100 101 102 103 104 (10 unledgered; 6 of them deferring named work in prose with no destination)
#
# ============================================================================
# THE FAILURE THIS CLOSES
# ============================================================================
#
# Eight agents ran against this repository on 2026-08-07. Every one of them
# ended its pull request with a section headed some variant of "deliberately
# left alone", and every one of those sections named real, correctly-deferred
# work. Not one of them FILED any of it. The items were reported in prose to a
# coordinating session, which relayed them in prose to a human. Roughly ten
# work items passed through that channel in one night and became paragraphs.
#
# Measured, not asserted -- run this against #95..#104 and it names them:
#
#   #96  "removing ecosim's url.insteadOf rewrite is deliberately left out"
#   #97  "silence-audit's 58 FLAGs are pre-existing and out of scope"
#   #98  "gating a release cut on CI green is the obvious next hardening"
#   #104 "orphaned shims on monkey accounts -- named, left"
#   #104 "VERBS_READ_TOKEN lacks Checks: Read ... Not attempted"
#   #104 "the slot is not freed in this PR"
#
# Each of those deferrals was CORRECT. Deferring was the right call every
# time; #104 not freeing a bootstrap slot that four live accounts depend on is
# exactly the restraint this estate wants. The defect is not the deferral. The
# defect is that the definition of "done" in force that night was "my PR is
# green", and that definition lets an agent defer five real items and still be
# done. Nothing anywhere disagreed.
#
# So: AN AGENT THAT DEFERS WORK MUST LEAVE THAT WORK SOMEWHERE WITH A CLOCK,
# OR IT IS NOT DONE. This is the checking half of that sentence. The other
# half -- and the more important one -- is bin/defere.sh, which makes filing
# the item CHEAPER than writing the paragraph about not filing it. A guard
# raises the cost of the wrong path; only the helper lowers the cost of the
# right one, and of the two, the helper is the one that changes behaviour.
#
# closeout-lint.sh states this same gap and declines it, in its own header:
# "whether a session actually FILED any decision is not mechanically
# detectable from outside the session". That is true of a SESSION. It is not
# true of a PULL REQUEST, because a PR body is an artifact that outlives the
# session, is addressable, and can be re-read by anyone later. Moving the
# question from the session to the PR is what makes it checkable at all.
#
# ============================================================================
# THE LIMIT, STATED UP FRONT BECAUSE IT IS NOT SMALL
# ============================================================================
#
# THIS CANNOT DETECT WORK AN AGENT NEVER MENTIONS. Silence is undetectable
# from outside, and any guard claiming otherwise is theatre. What this catches
# is a DECLARED deferral with no destination -- an agent that was honest in
# prose and filed nothing. That is the whole of tonight's failure, which is
# why it is worth catching, but it is not the whole of the risk.
#
# The undeclared half has a different answer, and it is claim-drift.sh's:
# absence of declared deferrals is itself a claim, falsifiable in retrospect.
# If a PR's ledger says `none` and the work resurfaces next week, the claim
# was false and the record says so. Nothing here makes that automatic.
#
# ============================================================================
# TWO DETECTORS, AND WHY IT IS NOT ONE
# ============================================================================
#
# 1. THE LEDGER (the declaration). A PR body must carry:
#
#      <!-- DEFERRED -->
#      - none
#      <!-- /DEFERRED -->
#
#    ...or one line per item, each carrying an issue reference (`#N`,
#    `owner/repo#N`, an issue URL) or `NO-OWNER:` and a reason. The
#    delimiters are HTML comments, so they do not render; the entries do
#    render, as an ordinary list -- a reviewer reads exactly what the guard
#    reads. `bin/defere.sh` prints these lines for you as a side effect of
#    filing, so the compliant path costs no typing at all.
#
#    Missing block = UNLEDGERED. That is the default state of every pull
#    request in this repository's history, and it is why the failure was
#    invisible: silence and nothing-was-deferred were indistinguishable.
#
# 2. THE PROSE (the lie detector). Requiring only a declaration would be
#    satisfied by writing `- none` above a section that defers six things. So
#    the body is also scanned for DEFERRAL LINES: a list item or bolded
#    paragraph whose own text says it is leaving work behind ("left alone",
#    "not attempted", "out of scope", "named, left", "deliberately left out",
#    "the obvious next hardening", "must be copied", ...) AND that carries no
#    destination.
#
# WHY LINE-LEVEL AND NOT SECTION-LEVEL. The obvious design reads the
# "deliberately left alone" heading and demands a link beside every bullet
# under it. The first draft did that and it was wrong, in the specific way
# this estate keeps being wrong: it cannot tell a deferred WORK ITEM from a
# SCOPE STATEMENT. #102's "Deliberately excluded" lists the toolchain repos --
# a boundary being drawn, not a task being postponed -- and demanding an issue
# for it manufactures a false alarm. #104's "orphaned shims -- named, left",
# in an identically-shaped section, IS a task. The heading cannot separate
# them; the LINE can, because the line that postpones work says so.
#
# WHY NOT A PHRASE ANYWHERE IN THE DOCUMENT. Because this very file, and any
# report about this mechanism, quotes every one of those phrases. guard-estate
# check E's first draft matched the word `FLAG` anywhere and fired on its own
# preamble within ten minutes of being written. So: fenced code blocks are
# stripped before scanning, only LIST ITEMS and BOLD-LED paragraph lines are
# eligible, and a line carrying a destination is never a finding no matter
# what words it uses. Case P4 of the suite is a body that discusses this guard
# at length and must come out clean.
#
# ============================================================================
# WHAT IT DELIBERATELY DOES NOT DO
# ============================================================================
#
# It does not judge whether a deferral was correct, whether the destination is
# a good one, or whether anyone will ever work it. It cannot: those are
# judgments. It asserts one thing -- that the work was WRITTEN DOWN SOMEWHERE
# ADDRESSABLE before the author called themselves done.
#
# NO-OWNER is a first-class, PASSING answer, on purpose. Some work genuinely
# has no owner yet, and forcing it into a tracker nobody reads is worse than
# saying so out loud -- an unroutable item silently assigned to a default
# owner is the same conflation as BLIND grading as clean, one level up. What
# is refused is naming work and saying nothing at all about where it went.
#
# It blocks nothing. This repository is private on a plan where both the
# branch-protection and rulesets APIs answer 403 (probed 2026-08-07 for
# claim-drift), so a red check cannot prevent a merge and is not meant to.
#
# ============================================================================
# WHY NOT INSIDE claim-drift.sh
# ============================================================================
#
# They are adjacent -- both police a completion claim against the PR carrying
# it -- and folding this in was seriously considered. Three reasons it is not:
#
#   1. DIFFERENT ANCHOR. claim-drift's entire subject is the draft-state
#      TIMELINE: an instant, and what happened after it. This reads the body's
#      CONTENT at one moment and has no timeline. One guard with two anchors
#      answers two questions, and `# GUARD:` is one line for a reason.
#   2. DIFFERENT EVENT SET. A PR body changes on `edited`, with no commit and
#      no `synchronize`. claim-drift must NOT re-run on `edited` (editing
#      prose does not move a head) and this must. Merged, one of them fires
#      on the wrong events.
#   3. DIFFERENT BLINDNESS. claim-drift is blind without a tracker, always.
#      This runs fully offline against `--body-file`, which is what lets its
#      suite be hermetic and lets it be pointed at a body before a PR exists.
#
# ============================================================================
# USAGE
#   deferral-ledger.sh <pr-number>...        audit the named PRs
#   deferral-ledger.sh --all                 audit every OPEN pull request
#   deferral-ledger.sh --body-file <path>    audit a body on disk (offline)
#   deferral-ledger.sh --strict ...          exit 1 on findings, 6 on BLIND
#   deferral-ledger.sh --repo <owner/name>   default: the checkout's own remote
#   deferral-ledger.sh --template            print the block to paste, exit 0
#
# EXIT CODES
#   0  audited; no --strict, or --strict and nothing found
#   1  --strict and at least one finding
#   2  usage error (lib/cli-guard.sh)
#   6  BLIND -- a body that exists was not read. Not a pass.
set -uo pipefail

CLI_NAME='deferral-ledger.sh'
CLI_SUMMARY='does this pull request say where the work it deferred went?'
CLI_USAGE='  deferral-ledger.sh <pr-number>...        audit the named PRs
  deferral-ledger.sh --all                 audit every OPEN pull request
  deferral-ledger.sh --body-file <path>    audit a body on disk (offline)
  deferral-ledger.sh --strict ...          exit 1 on findings, 6 on BLIND
  deferral-ledger.sh --repo <owner/name>   default: the checkout own remote
  deferral-ledger.sh --template            print the block to paste'
CLI_FLAGS='--all --strict --repo --body-file --template'
CLI_POSITIONAL=any
CLI_EXITS='  0  audited; no --strict, or --strict and nothing found
  1  --strict and at least one finding
  6  BLIND -- a body that exists was not read'
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"

REPO=''
ALL=0
STRICT=0
BODY_FILE=''
PRS=()

print_template() {
  cat <<'TPL'
<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

...or, when something was left behind, one line each. `defere` writes these:

<!-- DEFERRED -->
- hf7y/chezz#12 -- orphaned ecosystem-survey shim on chezz@monkey
- NO-OWNER: free the 4th bootstrap slot -- changes what four live accounts
  must hold before they can fetch anything; needs a human decision
<!-- /DEFERRED -->
TPL
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)      REPO="${2:-}"; [ -n "$REPO" ] || cli_die '--repo needs owner/name'; shift 2 ;;
    --body-file) BODY_FILE="${2:-}"; [ -n "$BODY_FILE" ] || cli_die '--body-file needs a path'; shift 2 ;;
    --all)       ALL=1; shift ;;
    --strict)    STRICT=1; shift ;;
    --template)  print_template; exit 0 ;;
    *)           case "$1" in
                   ''|*[!0-9]*) cli_die "not a pull request number: $1" ;;
                 esac
                 PRS+=("$1"); shift ;;
  esac
done

# A run that examines nothing is not a clean run -- the found-nothing /
# nothing-is-wrong conflation this estate keeps paying for. Same stance, and
# deliberately the same wording, as claim-drift.sh.
if [ "$ALL" -eq 0 ] && [ "${#PRS[@]}" -eq 0 ] && [ -z "$BODY_FILE" ]; then
  cli_die 'nothing to audit: give one or more PR numbers, --all, or --body-file'
fi
if [ -n "$BODY_FILE" ] && { [ "$ALL" -eq 1 ] || [ "${#PRS[@]}" -gt 0 ]; }; then
  cli_die '--body-file audits one body on disk; it does not combine with PR numbers or --all'
fi

findings=0
clean=0
blind=0
BLIND_LINES=()
FIND_LINES=()

note_blind() { blind=$((blind+1)); BLIND_LINES+=("  BLIND $*"); }
note_find()  { findings=$((findings+1)); FIND_LINES+=("  FLAG  $*"); }
note_evid()  { FIND_LINES+=("          $*"); }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# THE READER -- everything below works on a body already in a file. Nothing
# here touches the network, which is why the suite is hermetic and why
# --body-file is the gating invocation guard-estate executes.
# ---------------------------------------------------------------------------

# A destination is an addressable place with a tracker behind it, or an
# explicit refusal to name one. Nothing else counts: "TODO", "later" and
# "follow-up" are the words that produced the incident.
has_destination() {
  case "$1" in
    *NO-OWNER:*) return 0 ;;
  esac
  printf '%s\n' "$1" | grep -qE '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+' && return 0
  printf '%s\n' "$1" | grep -qE '(^|[^A-Za-z0-9_&/.-])#[0-9]+' && return 0
  printf '%s\n' "$1" | grep -qE 'https?://[A-Za-z0-9._-]+/[^ )]+/(issues|pull)/[0-9]+' && return 0
  return 1
}

# A NO-OWNER entry has to say WHY, or it is "TODO" with a hyphen in it. Twenty
# characters is not a quality bar; it is a refusal to accept the empty gesture.
NO_OWNER_MIN=20

# THE PHRASE LIST. Every entry was taken from an actual line in
# hf7y/realisateur#95..#104 or from the shapes the coordinating session
# reported agents using. It is a list of things a line says about ITSELF when
# it is postponing work -- not a list of topic words.
DEFER_LINE_RE='left alone|named,? left|deliberately (left|not|excluded)|left out\b|left (for|to) (a |the )?(human|zach|someone|whoever|another)|not attempted|not fixed|not freed|not done (here|in this)|out of scope|worth filing|flagging rather than fixing|not mine|still (red|outstanding|open) until|obvious next (hardening|step)|must be copied|remains? (open|outstanding|unfixed)|belongs to (another|a different)|for (a )?(later|another) (pass|session|pr)|someone (else|later)|deferred (to|until|for)|is a separate review|left unfixed|left untouched|no workaround .* was built'

strip_fences() {
  awk '
    /^[[:space:]]*```/ { inf = !inf; next }
    !inf { print }
  ' "$1"
}

LEDGER_ENTRIES=0
LEDGER_SAID_NONE=0

check_entry() {
  local label="$1" raw="$2" text reason
  text="$(printf '%s' "$raw" | sed 's/^[[:space:]]*[-*+][[:space:]]*//; s/^[[:space:]]*[0-9]\+\.[[:space:]]*//')"
  text="$(printf '%s' "$text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -n "$text" ] || return 0
  LEDGER_ENTRIES=$((LEDGER_ENTRIES + 1))

  case "$(printf '%s' "$text" | tr 'A-Z' 'a-z')" in
    none|none.|none\ --*|nothing|nothing\ deferred*|none\ deferred*)
      LEDGER_SAID_NONE=1
      return 0 ;;
  esac

  case "$text" in
    *NO-OWNER:*)
      reason="${text#*NO-OWNER:}"
      reason="$(printf '%s' "$reason" | sed 's/^[[:space:]]*//')"
      if [ "${#reason}" -lt "$NO_OWNER_MIN" ]; then
        note_find "$label: NO-DESTINATION -- 'NO-OWNER:' with no reason (>= $NO_OWNER_MIN chars saying why nothing can own it): ${text:0:70}"
      fi
      return 0 ;;
  esac

  if ! has_destination "$text"; then
    note_find "$label: NO-DESTINATION -- a ledger entry naming work and no home for it: ${text:0:80}"
  fi
}

# audit_body <label> <path>
audit_body() {
  local label="$1" path="$2"
  local body scan block line entry nopen nclose
  local -a prose=()

  if [ ! -r "$path" ]; then
    note_blind "$label: the body could not be read at $path -- nothing was examined."
    return
  fi
  body="$(cat "$path")"
  if [ -z "${body//[[:space:]]/}" ]; then
    note_find "$label: UNLEDGERED -- the body is empty. An empty body says nothing about what was deferred."
    return
  fi

  LEDGER_ENTRIES=0
  LEDGER_SAID_NONE=0

  # --- detector 2 first, because its output is evidence for detector 1 ------
  # Fences stripped so an example inside a code block is never a finding, and
  # the ledger block itself removed so its own entries are not re-read here.
  #
  # THE UNIT IS A BLOCK, NOT A LINE, and that correction is measured. The
  # first draft tested each physical line and missed three of the six real
  # deferrals in #95..#104 -- every one of them because the sentence that
  # postponed the work had wrapped onto the bullet's second line:
  #
  #     - **Orphaned shims** on monkey accounts (`ecosystem-survey`,
  #       `steward-survey`) -- named, left.
  #
  # "named, left" is not on a list-item line. A markdown-aware matcher has to
  # reassemble the item first. Headings, tables and blockquotes are excluded
  # from eligibility: a heading announces a section (and #102 proves a
  # deferral-shaped heading can sit over pure scope statements), a table row
  # is a comparison, a quote is somebody else's words.
  scan="$(strip_fences "$path" \
    | sed '/^[[:space:]]*<!--[[:space:]]*DEFERRED[[:space:]]*-->[[:space:]]*$/,/^[[:space:]]*<!--[[:space:]]*\/DEFERRED[[:space:]]*-->[[:space:]]*$/d')"
  local blk=''
  flush_blk() {
    [ -n "$blk" ] || return 0
    local b="$blk"; blk=''
    printf '%s\n' "$b" | grep -qiE "$DEFER_LINE_RE" || return 0
    has_destination "$b" && return 0
    prose+=("$(printf '%s' "$b" | sed 's/[[:space:]]\+/ /g')")
  }
  while IFS= read -r line; do
    case "$line" in
      ''|---*|===*)   flush_blk; continue ;;
      \#*|\>*|\|*)    flush_blk; continue ;;
      [-*+]\ *|[0-9]*.\ *)
                      flush_blk; blk="$line"; continue ;;
    esac
    if [ -n "$blk" ]; then blk="$blk $(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
    else blk="$line"; fi
  done <<< "$scan"
  flush_blk

  # --- detector 1: the declaration ------------------------------------------
  nopen="$(printf '%s\n' "$body" | grep -cE '^[[:space:]]*<!--[[:space:]]*DEFERRED[[:space:]]*-->[[:space:]]*$')"
  nclose="$(printf '%s\n' "$body" | grep -cE '^[[:space:]]*<!--[[:space:]]*/DEFERRED[[:space:]]*-->[[:space:]]*$')"

  if [ "$nopen" -eq 0 ]; then
    note_find "$label: UNLEDGERED -- no <!-- DEFERRED --> block. Silence and nothing-was-deferred are indistinguishable; say which."
    local p
    for p in ${prose+"${prose[@]}"}; do
      note_evid "and it defers, with no destination: $(printf '%s' "${p:0:140}" | sed 's/[[:space:]]\+/ /g')"
    done
    return
  fi
  if [ "$nopen" -gt 1 ]; then
    note_find "$label: $nopen DEFERRED blocks -- a reader cannot tell which is current. Keep one."
    return
  fi
  if [ "$nclose" -eq 0 ]; then
    note_find "$label: the DEFERRED block is never closed (<!-- /DEFERRED --> missing) -- everything after it reads as an entry."
    return
  fi

  block="$(printf '%s\n' "$body" \
    | sed -n '/^[[:space:]]*<!--[[:space:]]*DEFERRED[[:space:]]*-->[[:space:]]*$/,/^[[:space:]]*<!--[[:space:]]*\/DEFERRED[[:space:]]*-->[[:space:]]*$/p' \
    | grep -vE '^[[:space:]]*<!--[[:space:]]*/?DEFERRED[[:space:]]*-->[[:space:]]*$')"

  # Continuation lines fold into their bullet, so a NO-OWNER reason may wrap.
  entry=''
  while IFS= read -r line; do
    case "$line" in
      [-*+]\ *|[0-9]*.\ *)
        [ -n "$entry" ] && check_entry "$label" "$entry"
        entry="$line" ;;
      '') : ;;
      *)  [ -n "$entry" ] && entry="$entry $(printf '%s' "$line" | sed 's/^[[:space:]]*//')" ;;
    esac
  done <<< "$block"
  [ -n "$entry" ] && check_entry "$label" "$entry"

  if [ "$LEDGER_ENTRIES" -eq 0 ]; then
    note_find "$label: the DEFERRED block is empty. Write '- none' and mean it, or list what was left."
    return
  fi

  # THE DODGE: `- none` written above a section that defers six things. The
  # prose is only consulted here, and only when the ledger claims nothing.
  if [ "$LEDGER_SAID_NONE" -eq 1 ] && [ "$LEDGER_ENTRIES" -eq 1 ] && [ "${#prose[@]}" -gt 0 ]; then
    local q
    for q in "${prose[@]}"; do
      note_find "$label: PROSE-DEFERS -- the ledger says 'none' but this line leaves work with no destination: $(printf '%s' "${q:0:140}" | sed 's/[[:space:]]\+/ /g')"
    done
  fi
}

# ---------------------------------------------------------------------------
# THE SOURCES
# ---------------------------------------------------------------------------
printf 'deferral-ledger: %s\n\n' "${BODY_FILE:-${REPO:-(repo from remote)}}"

TMPD=''
cleanup() { [ -n "$TMPD" ] && rm -rf "$TMPD"; }
trap cleanup EXIT

if [ -n "$BODY_FILE" ]; then
  audit_body "$BODY_FILE" "$BODY_FILE"
  [ "$findings" -eq 0 ] && [ "$blind" -eq 0 ] && clean=1
else
  if [ -z "$REPO" ] && have gh; then
    REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || REPO=''
  fi
  if ! have gh || ! have jq; then
    missing=''
    have gh || missing="$missing gh"
    have jq || missing="$missing jq"
    note_blind "cannot read the tracker --$missing not on PATH. This is not 'nothing was deferred'. Nothing was examined."
  else
    if [ "$ALL" -eq 1 ]; then
      list="$(gh pr list --repo "$REPO" --state open --limit 100 --json number 2>/dev/null)" || list=''
      if [ -z "$list" ]; then
        note_blind "could not list open pull requests for ${REPO:-(unknown repo)}."
      else
        while read -r n; do [ -n "$n" ] && PRS+=("$n"); done \
          < <(printf '%s' "$list" | jq -r '.[].number' 2>/dev/null)
      fi
    fi
    if [ "${#PRS[@]}" -gt 0 ]; then
      TMPD="$(mktemp -d)"
      for n in "${PRS[@]}"; do
        if ! gh pr view "$n" --repo "$REPO" --json body -q '.body' > "$TMPD/body.$n" 2>/dev/null; then
          note_blind "#$n: could not read the pull request body."
          continue
        fi
        before=$findings
        audit_body "#$n" "$TMPD/body.$n"
        [ "$findings" -eq "$before" ] && clean=$((clean + 1))
      done
    fi
  fi
fi

# ---------------------------------------------------------------------------
# THE REPORT -- blindness first, always.
# ---------------------------------------------------------------------------
# guard-estate check E2: an admission of not-looking printed BELOW the
# findings is buried, and closeout-lint buried thirteen unexamined worktrees
# one line above twelve false alarms. So both lists are accumulated and the
# blind list is emitted first, unconditionally.
for l in ${BLIND_LINES+"${BLIND_LINES[@]}"}; do printf '%s\n' "$l"; done
[ "${#BLIND_LINES[@]}" -gt 0 ] && printf '\n'
for l in ${FIND_LINES+"${FIND_LINES[@]}"}; do printf '%s\n' "$l"; done

if [ "$findings" -gt 0 ]; then
  printf '\n  Every deferral needs a destination with a clock behind it.\n'
  printf '  `defere "<what>" --project <who>` files it and prints the line; or paste:\n\n'
  print_template | sed 's/^/    /'
fi

printf '\n%d finding(s), %d clean, %d blind.\n' "$findings" "$clean" "$blind"

if [ "$STRICT" -eq 1 ]; then
  [ "$blind" -gt 0 ] && exit 6
  [ "$findings" -gt 0 ] && exit 1
fi
exit 0
