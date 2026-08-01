#!/usr/bin/env bash
# bashify.sh -- turn one agent-era project into a bashified verb utility.
#
#   ./bashify.sh <project> <verb> <summary>
#
# Reads the project's real repo, discovers the tooling that actually exists,
# and emits a `bashified` branch containing a verb-named utility, its man
# page, its contract, and a contract test that runs against BOTH the legacy
# tooling and the new verb.
#
# It uses `git worktree`, never a checkout, so a project's working tree is
# never touched -- which is what makes this safe to run against a repo the
# human has an interactive session open in.

set -uo pipefail
SKEL="$(cd "$(dirname "${BASH_SOURCE[0]}")/skel" && pwd)"
# Overridable so this generator can be run against a throwaway registry. It
# was not testable before: `emit` does `git branch -D bashified` on the real
# repo, so the only way to exercise it was to destroy a live branch, and the
# man-page template therefore shipped four gate failures for two days.
SCHED="${BASHIFY_SCHED:-/home/zach/Documents/Projects/scheduler}"
WORK="${BASHIFY_WORK:-/tmp/claude-1000/-home-zach-Documents-Projects-realisateur/5ffa824d-364f-4e27-843a-13eac347b21d/scratchpad/wt}"

PROJ="${1:?project}"; VERB="${2:?verb}"; SUMMARY="${3:?summary}"

conf="$SCHED/schedule/$PROJ.conf"
[ -f "$conf" ] || { echo "bashify: no scheduler conf for $PROJ" >&2; exit 1; }
REPO="$(grep -oP '^PROJECT_REPO_PATH=\K.*' "$conf" | tr -d '"'"'"'')"

# A project may live INSIDE a monorepo rather than owning a repo. aedile is a
# subdirectory of `wavebucks`, co-owned with another person, so its conf path
# has no .git at all -- which read as "project missing" until probed.
# BASHIFY_REPO names the real repo; BASHIFY_SCOPE limits discovery to the
# project's own subtree so a bashify pass can never claim a co-owner's files.
REPO="${BASHIFY_REPO:-$REPO}"
SCOPE="${BASHIFY_SCOPE:-}"
[ -d "$REPO/.git" ] || { echo "bashify: $PROJ has no git repo at $REPO" >&2; exit 1; }

WT="$WORK/$PROJ"
rm -rf "$WT"; mkdir -p "$WORK"

# Branch off the project's own default branch, from a worktree so the human's
# working tree and index are untouched even mid-session.
DEFAULT="$(git -C "$REPO" symbolic-ref --short HEAD 2>/dev/null || echo main)"
git -C "$REPO" worktree remove --force "$WT" 2>/dev/null
git -C "$REPO" branch -D bashified 2>/dev/null
git -C "$REPO" worktree add -b bashified "$WT" "$DEFAULT" >/dev/null 2>&1 || {
  echo "bashify: could not create worktree for $PROJ" >&2; exit 1; }

FORBIDDEN='claude|anthropic|agent|openai|gpt|llm|assistant'

# ---- discover the tooling that actually exists -----------------------------
# Discovery must not assume bin/. senechal keeps its tooling in health/ and
# remedies/; an earlier glob that only read bin|scripts|tools found 3 of its
# 23 scripts and would have shipped a utility silently missing most of the
# project. Take every tracked .sh anywhere, plus anything in the usual
# executable dirs, minus tests and libraries (not caller-facing).
mapfile -t SCRIPTS < <(cd "$REPO" && {
    git ls-files ${SCOPE:+"$SCOPE"} '*.sh'
    git ls-files ${SCOPE:+"$SCOPE"} | grep -E '(^|/)(bin|scripts|tools)/'
  } | sort -u \
    | grep -vE '\.(md|txt|json|yml|yaml|conf|template|pyc)$' \
    | grep -vE '(^|/)(test|tests)/' \
    | grep -vE '(^|/)lib/' \
    | grep -vE '(^|/)test-' \
    | head -60)

# Dedupe by basename: two scripts sharing a stem would emit two `case` arms
# with the same pattern, and the second would be silently unreachable --
# a subcommand that exists in the help text and can never run.
# THE PURGE GUARD. A branch whose stated guarantee is "no traces of claude,
# no traces of agent" must not expose a subcommand named after one. Caught in
# the wild: aedile offered `AnthropicClient.js`. Anything matching this is
# recorded in GAPS.md as deliberately unexposed, never silently dropped.
declare -a PURGED=()
declare -A _seen=()
_uniq=()
for _s in ${SCRIPTS[@]+"${SCRIPTS[@]}"}; do
  _b="$(basename "$_s")"; _b="${_b%.sh}"
  if printf '%s' "$_s" | grep -qiE "$FORBIDDEN"; then
    PURGED+=("$_s"); continue
  fi
  if [ -n "${_seen[$_b]:-}" ]; then
    echo "bashify: $PROJ: subcommand '$_b' collides (${_seen[$_b]} vs $_s) -- keeping the first" >&2
    continue
  fi
  _seen[$_b]="$_s"; _uniq+=("$_s")
done
SCRIPTS=(${_uniq[@]+"${_uniq[@]}"})
mapfile -t PY_ALL < <(cd "$REPO" && git ls-files ${SCOPE:+"$SCOPE"} '*.py')
mapfile -t OTHER < <(cd "$REPO" && git ls-files ${SCOPE:+"$SCOPE"} '*.js' '*.mjs' '*.ts')
# A path can itself name a vendor. Listing such a path in GAPS.md would put
# the very string back into a branch that promises not to contain it, so the
# forbidden ones are COUNTED, never printed.
PY=(); PY_HIDDEN=0
for _f in ${PY_ALL[@]+"${PY_ALL[@]}"}; do
  if printf '%s' "$_f" | grep -qiE "$FORBIDDEN"; then PY_HIDDEN=$((PY_HIDDEN+1)); else PY+=("$_f"); fi
done
OTHER_SHOWN=(); OTHER_HIDDEN=0
for _f in ${OTHER[@]+"${OTHER[@]}"}; do
  if printf '%s' "$_f" | grep -qiE "$FORBIDDEN"; then OTHER_HIDDEN=$((OTHER_HIDDEN+1)); else OTHER_SHOWN+=("$_f"); fi
done

# ---- TOTAL PURGE: the branch keeps only what the utility needs -------------
# `git rm -r .` then rebuild. History on the default branch is the archive --
# which is the entire reason this is a BRANCH and not a new repository.
(cd "$WT" && git rm -rq --ignore-unmatch . >/dev/null 2>&1)
mkdir -p "$WT/bin" "$WT/lib" "$WT/man" "$WT/test"
cp "$SKEL/lib/verb.sh" "$WT/lib/verb.sh"
cp "$SKEL/test/contract-test.sh" "$WT/test/contract-test.sh"
chmod +x "$WT/test/contract-test.sh"

# ---- the utility ----------------------------------------------------------
{
cat <<EOF
#!/usr/bin/env bash
# $VERB -- $SUMMARY
#
# A plain shell utility. It costs nothing to run and reaches no paid service
# except where a subcommand explicitly declares a summon.
#
# The subcommand table below was DISCOVERED from tooling that actually exists
# in this tree, not invented. A subcommand backed by a script execs it. One
# the contract names but has nothing behind it reports GAP (exit 4) rather
# than pretending, because an exit-0 no-op is the worst failure available.

SELF="\$(cd "\$(dirname "\$(readlink -f "\${BASH_SOURCE[0]}")")/.." && pwd)"

VERB_NAME=$VERB
VERB_SUMMARY="$SUMMARY"
VERB_USAGE="$VERB <subcommand> [args...]"
VERB_CAN_SUMMON=0
# shellcheck source=../lib/verb.sh
. "\$SELF/lib/verb.sh"

# Where the legacy implementation lives, for subcommands that exec it. Read
# from ONE place; never retyped per subcommand.
LEGACY_ROOT="\${${VERB^^}_LEGACY_ROOT:-$REPO}"

verb_subcommands() {
  printf '%s\n' \\
EOF
if [ "${#SCRIPTS[@]}" -gt 0 ]; then
  for s in "${SCRIPTS[@]}"; do
    b="$(basename "$s")"; b="${b%.sh}"
    printf "    '%-28s %s' \\\\\n" "$b" "run $s"
  done
fi
cat <<'EOF'
    ''
}

# A leading flag is a flag, not a subcommand. Taking `--version` as a
# subcommand name made every generated verb exit 2 on three of the four flags
# its own `--help` advertises -- `--json`, `--quiet` and `--version` -- while
# the shared runtime parsed all of them. `bin/bashify` fixed this for itself
# on 2026-07-31 and the template it emits never received the fix, so the
# defect shipped into every verb this generator has ever written.
case "${1:-}" in
  -*) cmd=list ;;
  *)  cmd="${1:-}"; [ $# -gt 0 ] && shift ;;
esac
verb_parse "$@"
set -- "${VERB_ARGS[@]+"${VERB_ARGS[@]}"}"

case "$cmd" in
  ''|list)
    printf '%s -- %s\n\n' "$VERB_NAME" "$VERB_SUMMARY"
    printf 'subcommands (discovered from real tooling):\n'
    verb_subcommands | sed '/^$/d' | sed 's/^/  /'
    printf '\n(`%s --help` for flags, `man %s` for the contract)\n' "$VERB_NAME" "$VERB_NAME"
    ;;
  help|--help|-h) verb_usage ;;
EOF
if [ "${#SCRIPTS[@]}" -gt 0 ]; then
  for s in "${SCRIPTS[@]}"; do
    b="$(basename "$s")"; b="${b%.sh}"
    printf "  %s)\n    [ -x \"\$LEGACY_ROOT/%s\" ] || verb_gap '%s: %s is not executable or not present'\n    exec \"\$LEGACY_ROOT/%s\" \"\$@\" ;;\n" "$b" "$s" "$b" "$s" "$s"
  done
fi
cat <<'EOF'
  *) verb_die "unknown subcommand: $cmd  (try: $VERB_NAME list)" ;;
esac
EOF
} > "$WT/bin/$VERB"
chmod +x "$WT/bin/$VERB"

# ---- man page -------------------------------------------------------------
DATE=2026-07-30
{
printf '.TH %s 1 "%s" "bashified" "Zach'"'"'s utilities"\n' "${VERB^^}" "$DATE"
printf '.SH NAME\n%s \\- %s\n' "$VERB" "$SUMMARY"
# SYNOPSIS forms are RUN by `bashify check`, so they are written as real
# invocations rather than as a shape. `[\fIsubcommand\fR]` reads to that row
# as an optional LITERAL -- brackets are stripped, no italic survives, and it
# executed `<verb> subcommand`, which every generated page then failed on.
printf '.SH SYNOPSIS\n.B %s\n[\\fIlist\\fR]\n.br\n.B %s\n\\-\\-help\n.br\n.B %s\n\\-\\-version\n' "$VERB" "$VERB" "$VERB"
printf '.SH DESCRIPTION\n'
printf 'A plain shell utility. It takes arguments, keeps a stated promise, and\n'
printf 'exits with a code that says exactly what happened.\n'
printf '.PP\n'
printf 'Run\n.B %s list\nto see the subcommands that are actually backed by tooling.\n' "$VERB"
printf 'A subcommand the contract names but for which no tooling exists exits 4\n'
printf '(GAP) and says so, rather than exiting 0 having done nothing.\n'
# OPTIONS, not FLAGS. `bashify check`'s SURFACE row reads `section OPTIONS`,
# so a page heading its flags FLAGS documents none of them as far as the gate
# is concerned -- and every flag the shared runtime offers was then reported
# undocumented. The section is named for the reader that checks it.
printf '.SH OPTIONS\n'
printf '.TP\n.B \\-\\-json\nMachine-readable output.\n'
printf '.TP\n.B \\-\\-quiet, \\-q\nResults only, no commentary.\n'
printf '.TP\n.B \\-h, \\-\\-help\nUsage summary.\n'
printf '.TP\n.B \\-\\-version\nPrint the version and exit.\n'
printf '.SH THE COST BOUNDARY\n'
printf 'This utility does not spend money and therefore has\n.B no --summon flag.\n'
printf 'Any utility in this family that CAN spend declares\n.B \\-\\-summon\n'
printf 'and refuses to spend without it. There is deliberately no short form:\n'
printf '.B \\-s\ncollides with existing tools and\n.B \\-S\ndiffers from it by a\n'
printf 'single shift key, which is an unacceptable property for the one flag\n'
printf 'that costs real money. Spelling the word out is the deliberateness.\n'
printf '.SH EXIT STATUS\n'
printf '.TP\n.B 0\nThe promise was kept.\n'
printf '.TP\n.B 2\nUsage error; the caller is wrong.\n'
printf '.TP\n.B 3\nNeeds a summon and did not get one. A finding, not an error.\n'
printf '.TP\n.B 4\nGAP: the tooling to keep this promise does not exist yet.\n'
printf '.TP\n.B 5\nBROKEN: it ran and produced a wrong or partial answer.\n'
# "will not report" is future tense, and TENSE reads EXIT STATUS. The one
# aspirational verb in the template failed that row on every page it wrote.
printf '.TP\n.B 6\nBLIND: it cannot read its domain, so it reports nothing about it.\n'
printf '.SH EXAMPLES\n'
printf 'Print the version and the code it exits with:\n'
printf '.PP\n.nf\n'
printf '$ %s \\-\\-version\n%s (bashified)\n$ echo $?\n0\n' "$VERB" "$VERB"
printf '.fi\n'
printf '.SH FILES\n.TP\n.I CONTRACT.md\nThe promise this utility must keep.\n'
printf '.TP\n.I GAPS.md\nWhat the contract names and the tooling cannot yet do.\n'
printf '.SH HISTORY\n'
printf 'Rebuilt 2026-07-30 from the tree named\n.BR %s .\n' "$PROJ"
printf 'This branch is a total purge: it keeps the tool and nothing else.\n'
printf 'What was removed is not lost \\- it is on the default branch\n'
printf 'of this same repository. That is why this is a branch and not a new\n'
printf 'repository, and extracting it into one would destroy the archive that\n'
printf 'justifies the purge.\n'
printf '.SH SEE ALSO\n.BR dose (1)\n'
} > "$WT/man/$VERB.1"

# ---- contract -------------------------------------------------------------
{
printf '# CONTRACT -- `%s`\n\n' "$VERB"
printf '%s\n\n' "$SUMMARY"
printf 'Derived 2026-07-30 from the tooling that actually existed in `%s`.\n' "$PROJ"
printf 'Where there was no stated contract before, this is the first one; that\n'
printf 'is a finding about the old tree, recorded rather than hidden.\n\n'
printf '## The promise\n\n'
printf '```\n%s <subcommand> [args...]\n```\n\n' "$VERB"
printf '| subcommand | promises | backed by |\n|---|---|---|\n'
if [ "${#SCRIPTS[@]}" -gt 0 ]; then
  for s in "${SCRIPTS[@]}"; do b="$(basename "$s")"; b="${b%.sh}"
    printf '| `%s` | whatever `%s` promised | `%s` |\n' "$b" "$s" "$s"; done
else
  printf '| *(none)* | — | **no shell tooling existed in this project** |\n'
fi
printf '\n## Universal clauses\n\n'
printf 'Every subcommand, without exception:\n\n'
printf -- '- exits **0 only if the promise was kept**. Never an exit-0 no-op.\n'
printf -- '- exits **4 (GAP)** if the tooling does not exist, and says what is missing.\n'
printf -- '- exits **6 (BLIND)** if it cannot read its domain. "I cannot see" is\n'
printf '  never reported as "nothing to report".\n'
printf -- '- **cannot spend money** unless it declares `--summon`, which has no\n'
printf '  short form and is never implied.\n\n'
printf '## Verification\n\n'
printf '```\n./test/contract-test.sh <command>\n```\n\n'
printf 'The same assertions run against the legacy tooling and against `%s`.\n' "$VERB"
printf 'That is what makes "keeps the same contract" a measurement, not a claim.\n'
} > "$WT/CONTRACT.md"

# ---- gaps -----------------------------------------------------------------
{
printf '# GAPS -- what `%s` cannot yet do\n\n' "$VERB"
printf 'Recorded 2026-07-30 during the bashify pass. These are to be closed\n'
printf 'later; they are written down now so the utility never pretends.\n\n'
if [ "${#SCRIPTS[@]}" -eq 0 ]; then
  printf '## No shell tooling existed at all\n\n'
  printf 'This tree had **zero** shell scripts. So `%s` is currently a contract\n' "$VERB"
  printf 'and a front door with nothing behind it: every subcommand is a gap.\n\n'
  printf '**This is the most important finding available here.** It is the honest\n'
  printf 'measure of how much of this work was ever mechanised, and the answer is\n'
  printf 'none of it.\n\n'
fi
if [ "$PY_HIDDEN" -gt 0 ] || [ "$OTHER_HIDDEN" -gt 0 ]; then
  printf '## Files whose own paths name an external paid service\n\n'
  printf 'python: %d, other languages: %d. Their paths are not reproduced here,\n' "$PY_HIDDEN" "$OTHER_HIDDEN"
  printf 'because printing them would put the string back into a branch that\n'
  printf 'promises not to carry it. They are on the default branch.\n\n'
fi
if [ "${#OTHER_SHOWN[@]}" -gt 0 ]; then
  printf '## Tooling in other languages, not reachable through the verb (%d files)\n\n' "${#OTHER_SHOWN[@]}"
  printf 'This tree does real work in javascript/typescript. The verb wraps shell\n'
  printf 'only, so none of it is exposed yet. This is the largest single gap here:\n\n'
  for _f in "${OTHER_SHOWN[@]}"; do printf -- '- `%s`\n' "$_f"; done
  printf '\n'
fi
if [ "${#PY[@]}" -gt 0 ]; then
  printf '## Python that was never given a shell contract (%d files)\n\n' "${#PY[@]}"
  printf 'These do real work but are not reachable through the verb, because they\n'
  printf 'have no stated argv/output promise to wrap:\n\n'
  for p in "${PY[@]}"; do printf -- '- `%s`\n' "$p"; done
  printf '\n'
fi
if [ "${#PURGED[@]}" -gt 0 ]; then
  printf '## Deliberately not exposed (%d)\n\n' "${#PURGED[@]}"
  printf 'That many files in the legacy tree are named after an external paid\n'
  printf 'service. Exposing them as subcommands would break this branch'"'"'s stated\n'
  printf 'guarantee, so they are counted here and not carried over. Their paths\n'
  printf 'are on the default branch for anyone who needs them.\n\n'
  printf 'Closing this gap means writing a plain replacement, not re-exposing them.\n\n'
fi
printf '## Standing gap: the cost baseline\n\n'
printf 'No before-measurement exists for what the previous implementation cost\n'
printf 'per call, so the saving from mechanising it is **unmeasured, not zero\n'
printf 'and not assumed**. Closing this needs a real measurement, not an estimate.\n'
} > "$WT/GAPS.md"

# ---- readme ---------------------------------------------------------------
{
printf '# %s\n\n*%s*\n\n' "$VERB" "$SUMMARY"
printf 'This is the **bashified** branch of `%s`. It contains a plain shell\n' "$PROJ"
printf 'utility and nothing else.\n\n'
printf '```\nbin/%s          the utility\nman/%s.1        how to use it\n' "$VERB" "$VERB"
printf 'CONTRACT.md%s  the promise it must keep\nGAPS.md        what it cannot do yet\n' "$(printf '%*s' $(( ${#VERB} > 3 ? ${#VERB}-3 : 0 )) '')"
printf 'test/          the contract test, runnable against any implementation\n```\n\n'
printf '## Why this is a branch and not a repository\n\n'
printf 'The purge here is **total**. Everything this tree used to carry beyond\n'
printf 'the tool itself is gone from these files. It is not lost: it is on `%s`\n' "$DEFAULT"
printf 'branch of this same repository, one `git log %s` away.\n\n' "$DEFAULT"
printf '**That is the only reason a total purge is safe.** Extracting this\n'
printf 'branch into a standalone repository would destroy the archive that\n'
printf 'justifies the purge, and leave defensive code standing with no visible\n'
printf 'cause -- which is how hard-won guards get deleted by the next reader.\n'
printf 'Do not do it.\n\n'
printf '## Verify\n\n```\n./test/contract-test.sh bin/%s\n```\n' "$VERB"
} > "$WT/README.md"

# ---- verify the purge actually happened, before committing ----------------
# Mechanised, not trusted. The guarantee this branch makes about itself is
# the one thing that must never be asserted without a check.
# THE ONE EXEMPTION, and why it is safe. `lib/verb.sh` is not discovered
# material -- this generator writes it, from `skel/lib/verb.sh`, and its
# mentions of the word "agent" ARE the documentation of `--summon`: the
# mechanism by which a verb completes itself. Satisfying the guard on that
# file means deleting the explanation of the mechanism, so the guard was
# UNSATISFIABLE and `emit` exited 5 for every project, on every run, for two
# days -- while `bashify list` went on reporting emit MECHANIZED, because
# `_state` only asks whether the file is executable.
#
# The exemption is bounded three ways, so it cannot be used to smuggle
# anything: it covers exactly one path; it applies only to the generic
# English word `agent`, never to a vendor name; and it applies only if the
# file is BYTE-IDENTICAL to the skel this generator just copied. A modified
# lib/verb.sh is checked like anything else.
VERB_SH_CLEAN=0
if cmp -s "$SKEL/lib/verb.sh" "$WT/lib/verb.sh"; then VERB_SH_CLEAN=1; fi
LEAK="$(cd "$WT" && {
    grep -rilE 'claude|anthropic|openai|gpt|llm|assistant' . 2>/dev/null
    grep -rilE '\bagent\b' . 2>/dev/null \
      | { [ "$VERB_SH_CLEAN" = 1 ] && grep -vx './lib/verb.sh' || cat; }
  } | grep -v '^\./\.git' | sort -u || true)"
if [ -n "$LEAK" ]; then
  echo "bashify: PURGE FAILED for $PROJ -- these files still name an agent:" >&2
  printf '  %s\n' $LEAK >&2
  echo "bashify: refusing to commit a branch that lies about itself." >&2
  exit 5
fi

# ---- commit ---------------------------------------------------------------
(cd "$WT" && git add -A >/dev/null 2>&1 && \
 git -c user.name=Zach -c user.email=dangerpine@gmail.com \
   commit -q -F - <<EOF
bashified: $PROJ becomes \`$VERB\`

$SUMMARY

Total purge. This branch contains a shell utility, its man page, its
contract, and a contract test -- nothing else.

The purged material is on $DEFAULT in this same repository, which is why
this is a branch. Extracting it into a standalone repo would destroy the
archive that makes the purge safe.

Subcommands were discovered from the project's real tooling
(${#SCRIPTS[@]} script(s) found), not invented. Anything the contract
names without tooling behind it exits 4 (GAP) and says so.
EOF
) >/dev/null 2>&1

echo "$PROJ -> $VERB  (worktree $WT, ${#SCRIPTS[@]} scripts, ${#PY[@]} py)"
