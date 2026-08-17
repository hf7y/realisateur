#!/usr/bin/env bash
# coin.sh -- add ONE verb to a bashified branch that already carries verbs.
#
# RUNNER: bin/tests/bashify-coin.test.sh
#   It lives under bin/tests/ and not bashify/test/ because .github/workflows/
#   tests.yml globs bin/tests/*.sh only -- bashify/test/verify-*.sh is run by
#   no workflow at all (hf7y/realisateur#157). A suite for the estate's only
#   new-verb door, filed where nothing executes it, would be the same failure
#   tests/run-all.sh was written to end.
#
# Written 2026-08-01 at its own call site. The doctrine is now ONE NOUN, MANY
# VERBS (vault:realisateur/RESEARCH-VERB-ECOSYSTEM-20260730.md): a project is a noun, a noun does
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

SELF="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"   # bashify/
ROOT="$(cd "$SELF/.." && pwd)"                                            # realisateur/
# Resolved, not hardcoded. This was `/home/zach/Documents/Projects/scheduler`
# with no override, so `coin` could not see the registry from ANY other
# account -- including the uid 3000-3099 accounts the monkey dispatch runs
# under, where $HOME is /home/<project>. It failed as `gap` (exit 4, "not
# registered") rather than as blind, so the account looked like it had no
# projects instead of no path. Same resolution order as milestone-audit.sh,
# steward-survey.sh, precipitation-scan.sh and notify-senechal.sh; caught by
# bin/tests/verb-set.test.sh once it ran in CI rather than only on zach's box.
SCHED="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"
# ONE NAME FOR THE REGISTRY DIRECTORY, not one per file. bin/install-verbs.sh
# reads `SCHEDULE_DIR` (defaulting to the same place), and coin did not, so a
# caller who moved the registry got the two disagreeing about where projects
# are declared -- silently, each insisting the other's projects do not exist.
# Same override, same precedence, same default: SCHEDULE_DIR is the specific
# answer and wins; SCHED_ROOT/INSTALLE_PROJECTS still derive it when unset.
SCHEDULE_DIR="${SCHEDULE_DIR:-$SCHED/schedule}"

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
conf="$SCHEDULE_DIR/$PROJ.conf"
# BLIND, not GAP, when the registry itself is unreadable. "no registered
# project named X" is an answer about the project; if the directory that holds
# the answers is not there, the honest report is that nothing was read. This
# is the exact confusion #89 named: an account with no registry looked like an
# account with no projects.
[ -d "$SCHEDULE_DIR" ] \
  || blind "no registry directory at $SCHEDULE_DIR -- I read nothing, which is not the same as '$PROJ is unregistered'. Set SCHEDULE_DIR or SCHED_ROOT."
[ -f "$conf" ] || die "no registered project named '$PROJ'"
# THE PATH IS EXPANDED, and that is not a detail. Until 2026-08-11 this read
# `grep -oP '^PROJECT_REPO_PATH=\K.*' | tr -d '"'`, which returns the LITERAL
# characters `$HOME/Documents/...`: grep does not expand shell variables and
# nothing downstream did either. So the very next check, `[ -d "$REPO/.git" ]`,
# was false for every project on every host, and coin answered
#
#     coin: BLIND: scheduler has no git repository at $HOME/Documents/Projects/scheduler
#
# A path with a literal `$HOME` in it is not a path anyone typed. `bashify
# coin` is the ONLY door for a new verb here, so for as long as this line stood
# no new verb could be cut, from any host, by anyone -- which is why bin/consigne
# merged in #121 and reached no host's PATH (#162 asks for exactly this command).
# ONE reader, shared with bin/'s scripts: bin/lib/conf.sh. hf7y/realisateur#143.
. "$ROOT/bin/lib/conf.sh"
REPO="${BASHIFY_REPO:-$(conf_repo_path "$conf" || true)}"
[ -n "$REPO" ] || blind "$PROJ names no PROJECT_REPO_PATH and BASHIFY_REPO is unset"
[ -d "$REPO/.git" ] || blind "$PROJ has no git repository at $REPO"

# ---- the verb name -------------------------------------------------------
case "$VERB" in
  *[!a-z]*) die "verb '$VERB' must be lowercase ASCII letters only" ;;
esac
if command -v "$VERB" >/dev/null 2>&1; then
  die "'$VERB' is already claimed on PATH; coin another"
fi
# PATH is not the claim register. `command -v` above answers "is this name
# reachable on THIS HOST RIGHT NOW", and the declarations live in the repos --
# so on a host where nothing is installed it finds nothing and every name looks
# free. That is not hypothetical: the 2026-07-30 pass installed nothing on
# PATH, `command -v range` came back empty twice, and `range` was assigned to
# both bibliothecaire and secretaire with unrelated meanings. Only one can own
# the name; secretaire's won, and bibliothecaire's verb is unreachable. The
# report for that pass says "all verbs confirmed unclaimed on PATH before
# assignment" -- true, and still a collision, because PATH was the wrong
# register to confirm against.
# shellcheck source=../../bin/lib/verb-set.sh
if [ -r "$SELF/../bin/lib/verb-set.sh" ]; then
  . "$SELF/../bin/lib/verb-set.sh"
  _claimants="$(verb_set_claimants "$VERB" | grep -vx "$PROJ" || true)"
  [ -z "$_claimants" ] \
    || die "'$VERB' is already declared by:$(printf ' %s' $_claimants) -- coin another. (Declared means that project's bashified branch carries bin/$VERB and man/$VERB.1, whether or not it is installed here.)"
else
  # A missing guard is a finding, not an inconvenience: say so rather than
  # silently falling back to the check that produced the collision.
  printf 'coin: WARNING: bin/lib/verb-set.sh is unreadable, so the only claim check\n' >&2
  printf 'coin: that ran is `command -v`, which is host state and misses any verb\n' >&2
  printf 'coin: declared but not installed here. This is how `range` collided.\n' >&2
fi

# ---- REFUSAL 1: there must already be a branch to add to -------------------
# This is the whole distinction between coin and emit, so it is enforced
# rather than documented. Refusing names its escalation, which is emit.
git -C "$REPO" rev-parse --verify -q bashified >/dev/null 2>&1 \
  || refuse "$PROJ has no 'bashified' branch to add to. Bootstrap it first: bashify emit $PROJ <verb> <summary>"

# ---- a working copy of the branch, in a THROWAWAY CLONE --------------------
# This was `git worktree list ... | awk` for the worktree holding
# refs/heads/bashified, and it is the second reason coin was dead estate-wide
# on 2026-08-11: PR #156 removed all 30 worktrees that morning and added
# bin/no-worktree-lint.sh so a thirty-first cannot appear. Nothing recreates
# them, so the awk returned empty and coin exited BLIND for every project on
# every host -- with a message that was true, permanent and unactionable.
#
# A CLONE, exactly as `bashify emit` was converted on the same day (see
# bashify.sh's "WHY A CLONE AND NOT A WORKTREE"). It keeps the property the
# worktree was chosen for -- the human's working tree and index untouched even
# mid-session -- and drops the one that caused the growth: it registers nothing
# in $REPO.
#
# THE PUBLISH BELOW IS NOT NEW BEHAVIOUR, it is the same behaviour ported.
# Under a worktree the coin landed in a working copy sharing $REPO's ref store,
# so it was already reachable from $REPO. A clone has its own ref store, so the
# same reachability must be an explicit push -- to $REPO, the LOCAL repository,
# never to a remote. `git show bashified:bin/<verb>` reads it and
# `git update-ref` undoes it, so "read it before it becomes history" survives
# the change. Leaving it uncommitted in a temp clone instead would be strictly
# worse than the worktree it replaces: a change nobody can find is not a change
# anyone can review.
WORK="${BASHIFY_WORK:-${TMPDIR:-/tmp}/bashify-coin}"
WT="$WORK/$PROJ"
rm -rf "$WT"; mkdir -p "$WORK"
git clone -q --branch bashified --single-branch "$REPO" "$WT" 2>/dev/null \
  || broke "could not clone $PROJ's bashified branch from $REPO into $WT"
[ -d "$WT/.git" ] || broke "cloned $REPO into $WT but it has no .git"

# ---- REFUSAL 2: never overwrite a verb that already exists ------------------
[ -e "$WT/bin/$VERB" ] \
  && refuse "$WT/bin/$VERB already exists. Coining is adding, never replacing; amend the verb in place, or coin a different name."

# ---- REFUSAL 3 is RETIRED, because the clone made it unrepresentable -------
# It read: refuse if `git -C "$WT" status --porcelain` is non-empty, because a
# coin landing on top of uncommitted work makes the two indistinguishable in
# the commit. That was a real hazard when $WT was a long-lived worktree
# somebody might have been editing. $WT is now a clone made twenty lines ago
# and discarded at the end, so it is pristine by construction and the check
# could never fire again.
#
# Deleted rather than kept: "a check nobody expects to be green is a document
# with an exit code" (bin/thermostat-wiring.sh), and the inverse is as true --
# a check nobody expects to be RED is a comment pretending to be a guard, and
# the next reader has to disprove it before trusting anything near it. The
# hazard is gone because the shape changed. That is worth a paragraph, not a
# branch.

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
# KIND: verb
# A coined name is a thing you tell the machine to do, which is this estate's
# own criterion (bin/verb-kind-lint.sh: "a VERB is a thing you tell the machine
# to do, a PRODUCT is a thing with a name of its own"). If what gets built here
# turns out to be a product -- its own name, its own cadence, like vim-arcade --
# change this to \`# KIND: product\` and keep it out of the workchain manifest.
#
# THIS LINE IS LOAD-BEARING, not decoration. bin/cut-verb-build.sh runs
# verb-kind-lint against the assembled build and dies the whole cut on any
# undeclared command, and bin/verb-kind-lint.ratchet grandfathers exactly the
# 33 commands present on 2026-08-11 under "THIS IS THE LAST FREE RE-SEED". So a
# verb coined without it does not fail its own project -- it fails that night's
# build for all twelve. The template emits it so nobody has to remember.
#
# Coined $(date +%Y-%m-%d) by \`bashify coin\` onto a branch that already carried
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

# ---- publish the branch back into $REPO ------------------------------------
# See "THE PUBLISH IS NOT NEW BEHAVIOUR" above. A fast-forward push, never
# --force: coin ADDS to a branch that already carries verbs, and emit is the
# one that regenerates. If this is not a fast-forward, the branch moved under
# us between the clone and now, and the honest answer is to say so and leave
# both sides alone rather than to pick a winner unattended.
git -C "$WT" add "bin/$VERB" >/dev/null 2>&1 \
  || broke "could not stage bin/$VERB in $WT"
git -C "$WT" -c user.name='bashify coin' -c user.email='coin@localhost' \
    commit -q -m "coin $VERB onto $PROJ: $SUMMARY" >/dev/null 2>&1 \
  || broke "could not commit bin/$VERB in $WT"
COINED_SHA="$(git -C "$WT" rev-parse --short HEAD 2>/dev/null)"
git -C "$WT" push -q origin "bashified:refs/heads/bashified" 2>/dev/null \
  || broke "coined $VERB and committed it in $WT, but could not fast-forward $REPO's bashified branch. The branch moved since the clone; nothing in $REPO was changed. Re-run coin, or push $WT by hand once you have looked at both."

printf 'coin:   committed %s onto %s bashified in %s\n' "$COINED_SHA" "$PROJ" "$REPO"
printf 'coin: READ IT BEFORE IT GOES ANYWHERE. It is on the LOCAL branch only --\n'
printf 'coin: no remote has seen it:\n'
printf 'coin:     git -C %s show bashified:bin/%s\n' "$REPO" "$VERB"
printf 'coin: To undo:\n'
printf 'coin:     git -C %s update-ref refs/heads/bashified %s^\n' "$REPO" "$COINED_SHA"
printf 'coin: To ship it, push bashified and let tonight'"'"'s verb build cut it.\n'
rm -rf "$WT"
exit 0
