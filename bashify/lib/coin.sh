#!/usr/bin/env bash
# coin.sh -- add ONE verb to a bashified branch that already carries verbs.
#
# Written 2026-08-01 at its own call site. The doctrine is now ONE NOUN, MANY
# VERBS (RESEARCH-VERB-ECOSYSTEM-20260730.md): a project is a noun, a noun does
# several things, and forcing each noun to expose exactly one verb was the
# bashify pass's shortcut rather than a decision.
#
# `emit` never learned that. It opens with `git rm -r .` and rebuilds the whole
# branch from the default branch's tooling, so running it against a branch that
# has since grown verbs by hand DESTROYS them. That is not a bug in emit -- it
# is emit doing exactly what a bootstrap does. What was missing is the second
# act: adding one verb without touching the ones already there.
#
# The division of labour:
#   emit  -- bootstrap a bashified branch that does not exist yet
#   coin  -- add one verb to a bashified branch that does
#
# It deliberately does NOT write a man page. `bashify page` does that, against
# a live command, which is the page-first method this family documents: the
# verb is coined, the page is written against it, the page is checked. `fauche`
# was made in exactly that order (gardien e15ce01, then 544b83a).
#
# usage: coin.sh <project> <verb> <summary>
# exit:  0 coined   2 usage   4 gap   5 broken   6 blind
#        7 refused -- the branch is not in a state where coining is the act

set -uo pipefail

SELF="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
SCHED="/home/zach/Documents/Project Archive/scheduler"

die()    { printf 'coin: %s\n' "$*" >&2; exit 2; }
gap()    { printf 'coin: GAP: %s\n' "$*" >&2; exit 4; }
broke()  { printf 'coin: BROKEN: %s\n' "$*" >&2; exit 5; }
blind()  { printf 'coin: BLIND: %s\n' "$*" >&2
           printf 'coin: this is "I cannot see", NOT "nothing to report".\n' >&2
           exit 6; }
refuse() { printf 'coin: REFUSED: %s\n' "$*" >&2; exit 7; }

PROJ="${1:-}"; VERB="${2:-}"; SUMMARY="${3:-}"
[ $# -eq 3 ] || die "usage: coin <project> <verb> <summary> (got $#)"

# ---- the project must be registered and have a repository ------------------
conf="$SCHED/schedule/$PROJ.conf"
[ -f "$conf" ] || die "no registered project named '$PROJ'"
REPO="$(grep -oP '^PROJECT_REPO_PATH=\K.*' "$conf" | tr -d '"'"'"'')"
REPO="${BASHIFY_REPO:-$REPO}"
[ -n "$REPO" ] || blind "$PROJ names no PROJECT_REPO_PATH and BASHIFY_REPO is unset"
[ -d "$REPO/.git" ] || blind "$PROJ has no git repository at $REPO"

# ---- the verb name -------------------------------------------------------
case "$VERB" in
  *[!a-z]*) die "verb '$VERB' must be lowercase ASCII letters only" ;;
esac
if command -v "$VERB" >/dev/null 2>&1; then
  die "'$VERB' is already claimed on PATH; coin another"
fi

# ---- REFUSAL 1: there must already be a branch to add to -------------------
# This is the whole distinction between coin and emit, so it is enforced
# rather than documented. Refusing names its escalation, which is emit.
git -C "$REPO" rev-parse --verify -q bashified >/dev/null 2>&1 \
  || refuse "$PROJ has no 'bashified' branch to add to. Bootstrap it first: bashify emit $PROJ <verb> <summary>"

# ---- locate the branch's working copy --------------------------------------
# The branch is normally checked out as a worktree (that is how emit leaves
# it). Writing into the existing checkout is correct: it is where the verbs
# that already exist live, and where their runtime lives.
WT="$(git -C "$REPO" worktree list --porcelain \
      | awk '/^worktree /{p=$2} /^branch refs\/heads\/bashified$/{print p; exit}')"
[ -n "$WT" ] \
  || blind "the 'bashified' branch exists but is not checked out in any worktree; coin writes into a working copy, and none was found"
[ -d "$WT" ] || blind "the recorded worktree for 'bashified' is not a directory: $WT"

# ---- REFUSAL 2: never overwrite a verb that already exists ------------------
[ -e "$WT/bin/$VERB" ] \
  && refuse "$WT/bin/$VERB already exists. Coining is adding, never replacing; amend the verb in place, or coin a different name."

# ---- REFUSAL 3: a dirty branch is not a branch to add to -------------------
# A coin that lands on top of uncommitted work makes the two indistinguishable
# in the commit, which is the reported failure signature this ecosystem keeps
# recording. Checked before anything is written.
if [ -n "$(git -C "$WT" status --porcelain 2>/dev/null)" ]; then
  refuse "$WT has uncommitted changes. Commit or clear them first -- a coin on a dirty tree cannot be told apart from the work already there."
fi

# ---- the runtime the coined verb will source -------------------------------
# It sources the BRANCH'S OWN lib/verb.sh, not the skeleton's. The runtimes
# have forked across the ecosystem (four distinct copies over seven repos as
# of 2026-08-01) and a branch's own copy is the one its existing verbs are
# written against. Copying the skeleton in would give one verb a different
# exit vocabulary from its neighbours in the same bin/ -- the dialect drift
# the shared runtime exists to prevent.
[ -f "$WT/lib/verb.sh" ] \
  || gap "$WT has no lib/verb.sh; there is no runtime for a coined verb to source"

# What the branch's runtime actually offers, reported rather than assumed, so
# the coined verb's own help does not advertise an exit code its runtime
# cannot produce.
HAS_REFUSE=0
grep -qE '^verb_refuse\(\)' "$WT/lib/verb.sh" && HAS_REFUSE=1

# ---- write the verb --------------------------------------------------------
{
cat <<EOF
#!/usr/bin/env bash
# $VERB -- $SUMMARY
#
# Coined 2026-08-01 by \`bashify coin\` onto a branch that already carried
# verbs. It costs nothing to run and reaches no paid service.
#
# This is a COINED verb, not a discovered one: it wraps no legacy script,
# because it was named before an implementation existed. Every subcommand
# below therefore reports GAP (exit 4) until it is built at its own call
# site. That is the point -- a subcommand that exits 0 having done nothing is
# the worst failure available, and a GAP names what is missing on stderr.

SELF="\$(cd "\$(dirname "\$(readlink -f "\${BASH_SOURCE[0]}")")/.." && pwd)"

VERB_NAME=$VERB
VERB_SUMMARY="$SUMMARY"
VERB_USAGE="$VERB <subcommand> [args...]"
VERB_CAN_SUMMON=0
# shellcheck source=../lib/verb.sh
. "\$SELF/lib/verb.sh"

verb_subcommands() {
  printf '%s\n' \\
    ''
}

# A leading flag is a flag, not a subcommand.
case "\${1:-}" in
  -*) cmd=list ;;
  *)  cmd="\${1:-}"; [ \$# -gt 0 ] && shift ;;
esac
verb_parse "\$@"
set -- "\${VERB_ARGS[@]+"\${VERB_ARGS[@]}"}"

case "\$cmd" in
  ''|list)
    printf '%s -- %s\n\n' "\$VERB_NAME" "\$VERB_SUMMARY"
    printf 'subcommands: none built yet.\n'
    printf '\n(\`%s --help\` for flags, \`man %s\` for the contract)\n' "\$VERB_NAME" "\$VERB_NAME"
    ;;
  help|--help|-h) verb_usage ;;
  *) verb_die "unknown subcommand: \$cmd  (try: \$VERB_NAME list)" ;;
esac
EOF
} > "$WT/bin/$VERB"
chmod +x "$WT/bin/$VERB"

[ -x "$WT/bin/$VERB" ] || broke "wrote $WT/bin/$VERB but it is not executable"

# ---- report ----------------------------------------------------------------
printf 'coin: %s coined onto %s (branch bashified)\n' "$VERB" "$PROJ"
printf 'coin:   file    %s\n' "$WT/bin/$VERB"
printf 'coin:   runtime %s (verb_refuse: %s)\n' "$WT/lib/verb.sh" \
  "$( [ "$HAS_REFUSE" = 1 ] && echo present || echo ABSENT )"
printf 'coin:   verbs now on this branch: %s\n' \
  "$(cd "$WT/bin" && printf '%s ' * 2>/dev/null)"
printf 'coin: NO man page was written. That is `bashify page %s <command>`,\n' "$VERB"
printf 'coin: against the live command, which is the page-first order.\n'
printf 'coin: NOTHING WAS COMMITTED. The coin is in the working tree so it can\n'
printf 'coin: be read before it becomes history.\n'
exit 0
