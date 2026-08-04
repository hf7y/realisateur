#!/usr/bin/env bash
# closeout-lint.sh -- the deterministic half of the `/cloture` session-closing
# rite (design: realisateur .scheduler/FOCUS.md 2026-07-26). Offline-first,
# zero AI, writes nothing. Bare invocation exits 0 always -- same
# signals-not-verdicts stance as ecosystem-survey.sh / hygiene-lint.sh /
# milestone-audit.sh -- FLAGs printed here are for a human/AI to triage.
# `--strict` gates on them (exit 1) for a caller that wants a hard failure,
# e.g. a pre-close hook. Exit 2 is already used (via lib/cli-guard.sh) for
# usage errors, so --strict uses 1, matching reach-lint.sh/silence-audit.sh.
#
# It answers ONE question a session cannot answer about itself reliably:
# "is the work this session did actually durable, where its consumers read?"
# An overnight run that is not saved anywhere didn't happen -- and the three
# recorded ways that goes wrong are a dirty tree at exit, a commit that never
# left the local clone, and a session record with no commit shas in it.
#
# What it checks (per the queued design's layer 1):
#   A. RECENTLY TOUCHED REPOS -- every registered project whose HEAD is
#      younger than $HOURS: dirty working tree, commits ahead of upstream,
#      or no upstream at all. Complements hygiene-lint.sh's untracked-script-
#      in-bin/ check rather than repeating it; run that one too (this script
#      does not shell out to it, so each stays independently readable).
#      Linked worktrees are reported BLIND, not audited: section A reads the
#      registered path's HEAD only, and saying so is cheaper and more honest
#      than growing it to audit branches it was never scoped to.
#   B. TODAY'S SESSION RECORD -- realisateur's own .scheduler/FOCUS.md has an
#      entry dated today, and that entry cites at least one commit sha in
#      backticks. Mechanizes the standing "confirm every meaningful change
#      has a real commit" rule, which is prose today and so decays.
#   C. BLOCKERS.md TODAY -- whether scheduler's BLOCKERS.md carries a block
#      dated today.
#
# Stated limit (check C): whether a session actually FILED any decision is
# not mechanically detectable from outside the session, so C never FLAGs.
# It reports the fact and leaves the judgment to the closing session, which
# is the only party that knows whether it had decision-shaped residue.
#
# Usage:
#   closeout-lint.sh              scan every registered project
#   closeout-lint.sh <name>...    scan only the named project(s)
#   closeout-lint.sh --strict [<name>...]   exit 1 if any FLAG was printed
#   closeout-lint.sh --repo <path>          audit ONE working tree
#   closeout-lint.sh --allow-blind          downgrade BLIND to a warning
#
# --repo exists because this script's own BLIND message says "run closeout-lint
# against them by hand" -- and until now there was no way to do that. A linked
# worktree is not a registered project, so no positional name reaches it. In
# --repo mode the registry is not consulted, the $HOURS age gate does not
# apply (the caller just worked in that tree; whether HEAD is old is not the
# question), and sections B and C are skipped: they are session-wide concerns,
# not properties of one directory. It is what a SubagentStop hook needs --
# "is THIS tree durable" -- and running the full registry scan from a hook
# would block every subagent because some unrelated project is dirty.
#
# BLIND GATES, and it exits 6 to do it. Decided 2026-08-02 (Zach). A domain
# that existed and was NOT read is not a pass, so under --strict it must stop
# the caller. 6 rather than 1 or 2 because the ecosystem already has a blind
# code and this reuses it instead of inventing a third: `garde --help` states
# "6 blind" in its own exit table, and `ausculte` exits 6 for the same
# condition. 1 stays FLAG-only, and 2 belongs to lib/cli-guard.sh for usage
# errors -- a hook that cannot tell "I called this wrong" from "a domain was
# unreadable" is a hook that will be ignored.
#
# The override is deliberate and two-shaped: --allow-blind for unattended
# callers (explicit, auditable, greppable in a crontab) and an interactive
# y/N prompt when stdin AND stdout are both a TTY. The prompt can never fire
# unattended, which is the property that matters -- a lint that blocks
# forever waiting on an answer nobody is there to give is worse than one that
# does not gate at all.
#
# Env overrides (used by bin/tests/closeout-lint.test.sh, not normally set):
#   HOURS=12        age below which a repo counts as "touched by this session"
#   SCHED_ROOT=...  scheduler repo (project registry lives in schedule/*.conf)
#   FOCUS_MD=...    the FOCUS.md checked by B
#   BLOCKERS_MD=... the BLOCKERS.md checked by C
#   TODAY=YYYY-MM-DD  the date B and C treat as "today"
set -uo pipefail

CLI_NAME='closeout-lint.sh'
CLI_SUMMARY='the deterministic half of session closeout -- what did today leave behind?'
CLI_USAGE='  closeout-lint.sh              scan every registered project
  closeout-lint.sh <name>...    scan only the named project(s)
  closeout-lint.sh --strict [<name>...]   exit 1 if any FLAG was printed
  closeout-lint.sh --repo <path>          audit ONE working tree (sections
                                          B/C skipped, age gate ignored)
  closeout-lint.sh --allow-blind          BLIND warns instead of gating
    (HOURS=<n> in the environment sets the lookback window)'
CLI_FLAGS='--strict --repo --allow-blind'
CLI_EXITS='  0  scanned; no --strict given, or --strict given and nothing found
  1  --strict was given and at least one FLAG was printed
  6  --strict was given and a domain existed but was NOT read (BLIND), and
     neither --allow-blind nor an interactive override was given. Matches
     `garde` and `ausculte`, which already use 6 for blind'
CLI_POSITIONAL=any
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

SCHED_ROOT="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FOCUS_MD="${FOCUS_MD:-$REPO_ROOT/.scheduler/FOCUS.md}"
BLOCKERS_MD="${BLOCKERS_MD:-$SCHED_ROOT/BLOCKERS.md}"
HOURS="${HOURS:-12}"
TODAY="${TODAY:-$(date +%Y-%m-%d)}"

# Mode flags are not project names -- strip them before building the
# positional project-filter list (cli_guard validated them but never consumes
# args, per its own contract; each script parses its own).
STRICT=0
ALLOW_BLIND=0
REPO_ARG=""
want=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --strict)      STRICT=1 ;;
    --allow-blind) ALLOW_BLIND=1 ;;
    --repo)
      shift
      [ "$#" -gt 0 ] || cli_die "--repo needs a path"
      REPO_ARG="$1"
      ;;
    *) want+=("$1") ;;
  esac
  shift
done

projects=()
paths=()
if [ -n "$REPO_ARG" ]; then
  # --repo: audit exactly this tree. Refuse to also take project names rather
  # than silently honouring one and dropping the other -- two selectors that
  # disagree is a usage error, not something to resolve by precedence.
  [ "${#want[@]}" -eq 0 ] || \
    cli_die "--repo and project names are two different selectors: ${want[*]}"
  [ -d "$REPO_ARG" ] || cli_die "--repo path is not a directory: $REPO_ARG"
  git -C "$REPO_ARG" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
    cli_die "--repo path is not inside a git work tree: $REPO_ARG"
  # Resolve to the tree's own root so a subdirectory argument still names the
  # repo, and so the label matches what a reader would call it.
  REPO_ARG="$(git -C "$REPO_ARG" rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ARG")"
  projects+=("$(basename "$REPO_ARG")"); paths+=("$REPO_ARG")
else
  # --- discover registered projects (same loop as hygiene-lint.sh) ----------
  for conf in "$SCHED_ROOT"/schedule/*.conf; do
    [ -f "$conf" ] || continue
    name="$(basename "$conf" .conf)"
    case "$name" in _*) continue ;; esac
    p="$(sed -n 's/^PROJECT_REPO_PATH=["'\'']\?\([^"'\'']*\)["'\'']\?[[:space:]]*$/\1/p' "$conf" | head -1)"
    [ -n "$p" ] || continue
    if [ "${#want[@]}" -gt 0 ]; then
      skip=1; for w in "${want[@]}"; do [ "$w" = "$name" ] && skip=0; done
      [ "$skip" -eq 1 ] && continue
    fi
    projects+=("$name"); paths+=("$p")
  done
  cli_require_matched want projects
fi

if [ -n "$REPO_ARG" ]; then
  echo "closeout-lint -- $TODAY (single tree: $REPO_ARG)"
else
  echo "closeout-lint -- $TODAY (repos touched in the last ${HOURS}h)"
fi
if [ "$STRICT" = 1 ]; then
  echo "(offline-first: no claude calls, writes nothing. --strict: FLAG=1, BLIND=6."
else
  echo "(offline-first: no claude calls, writes nothing, exits 0 -- --strict to gate."
fi
echo " FLAGs are SIGNALS a closing session should look at, not verdicts."
echo " Run alongside hygiene-lint.sh; see realisateur/BUILD-DISCIPLINE.md.)"
echo
if [ -n "$REPO_ARG" ]; then
  echo "== A. THIS WORKING TREE =="
else
  echo "== A. RECENTLY TOUCHED REPOS =="
fi

flags=0
blind=0
touched=0
now="$(date +%s)"
cutoff=$(( HOURS * 3600 ))

i=0
while [ "$i" -lt "${#projects[@]}" ]; do
  name="${projects[$i]}"; repo="${paths[$i]}"; i=$((i+1))
  [ -d "$repo" ] || { echo "  FLAG [missing-repo] $name: $repo does not exist"; flags=$((flags+1)); continue; }
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || continue

  # Linked worktrees are checked BEFORE the age gate, deliberately. This
  # section reads the registered path's own HEAD only, so a branch checked
  # out in a linked worktree is invisible to every check below -- and the
  # registered repo's HEAD can be old while that branch is minutes fresh,
  # which would let the gate hide exactly the case this exists to surface.
  # Decided 2026-07-28 (Zach, option b, scheduler/BLOCKERS.md "realisateur"):
  # emit a symbol saying the domain was not read, rather than grow section A
  # to audit each worktree. A sensor that cannot represent "did not look"
  # reports it as "nothing there" -- see bin/silence-audit.sh.
  wt="$(git -C "$repo" worktree list --porcelain 2>/dev/null \
        | awk -v m="$repo" '/^worktree /{p=substr($0,10); if (p != m) print p}')"
  if [ -n "$wt" ]; then
    n_wt="$(printf '%s\n' "$wt" | grep -c .)"
    blind=$((blind+1))
    echo "  BLIND [worktrees] $name: $n_wt linked worktree(s) NOT examined below"
    printf '%s\n' "$wt" | while IFS= read -r w; do
      printf '      %s [%s]\n' "$w" "$(git -C "$w" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
    done
    echo "      (their dirty/unpushed state is outside this check's domain --"
    echo "       run closeout-lint against them by hand, or push them)"
  fi

  ct="$(git -C "$repo" log -1 --format=%ct 2>/dev/null)"
  [ -n "$ct" ] || continue
  age=$(( now - ct ))
  # The age gate answers "did THIS SESSION touch it", which is the right
  # question for a registry sweep and the wrong one for --repo: the caller
  # names the tree explicitly, so skipping it as "too old" would silently
  # audit nothing and report clean -- the exact shape of a false all-clear.
  if [ -z "$REPO_ARG" ] && [ "$age" -gt "$cutoff" ]; then continue; fi
  touched=$((touched+1))
  printf '  %-18s HEAD %sh ago\n' "$name" "$(( age / 3600 ))"

  # dirty tree: an uncommitted change to a live script is indistinguishable
  # from an abandoned one (CLAUDE.md subagent rule, 2026-07-25 incident).
  dirty="$(git -C "$repo" status --porcelain 2>/dev/null | head -8)"
  if [ -n "$dirty" ]; then
    echo "    FLAG [dirty-tree] $name: uncommitted changes at session close"
    echo "$dirty" | sed 's/^/      /'
    flags=$((flags+1))
  fi

  # unpushed: "verified where the consumer reads it" -- the nightly clones
  # the REF, not this working tree.
  # EVERY BRANCH, not just the checked-out one. This read HEAD alone until
  # 2026-08-01, so a branch that exists only on this host was invisible unless
  # it happened to be checked out -- scheduler carried three such `paced/*`
  # branches through an entire session and no lint mentioned them. `fauche`
  # caught them, because it enumerates refs/heads/ rather than HEAD. Same
  # defect shape as BUILD-DISCIPLINE pattern 20: the census read one branch
  # and the report named the repository.
  #
  # A HOST-ONLY BRANCH IS A BLOCKER (Zach, 2026-08-01). The test is the remote
  # REF, never the tracking config: a branch pushed by explicit refspec has no
  # upstream configured and is still safely on origin.
  while IFS= read -r br; do
    [ -n "$br" ] || continue
    if git -C "$repo" rev-parse --verify -q "origin/$br" >/dev/null 2>&1; then
      ahead="$(git -C "$repo" rev-list --count "origin/$br..$br" 2>/dev/null)"
      if [ "${ahead:-0}" -gt 0 ]; then
        echo "    FLAG [unpushed] $name: $ahead commit(s) on $br not on origin/$br"
        git -C "$repo" log --oneline "origin/$br..$br" 2>/dev/null | head -5 | sed 's/^/      /'
        flags=$((flags+1))
      fi
    else
      echo "    FLAG [host-only-branch] $name: branch '$br' has no origin/$br -- it exists only on this host"
      flags=$((flags+1))
    fi
  done <<EOF
$(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)
EOF
  i=$i
done
[ -n "$REPO_ARG" ] || [ "$touched" -ne 0 ] || \
  echo "  (no registered repo has a commit younger than ${HOURS}h)"

# B and C ask about the SESSION -- did it leave a dated record, did it file a
# decision -- not about a directory. --repo skips them: a hook auditing one
# worktree must not block on realisateur's FOCUS.md lacking today's entry.
# Wrapped in a function purely so the body stays unindented and diffs cleanly
# against the version before this flag existed; bash functions share scope, so
# `flags` still accumulates.
session_wide_sections() {
echo
echo "== B. TODAY'S SESSION RECORD ($FOCUS_MD) =="
if [ ! -f "$FOCUS_MD" ]; then
  echo "  FLAG [no-focus] $FOCUS_MD does not exist"; flags=$((flags+1))
else
  # An entry opens with a dated line and runs to the next `---` rule. BOTH
  # `**2026-07-31 ...` and `## 2026-07-31 ...` count: the file's older entries
  # use the bold form and its recent ones use the heading form, and matching
  # only the bold form made this check report "no durable record" over records
  # that were sitting in the file. It fired that way against two real entries
  # dated 2026-07-31 before anyone noticed, which is the failure mode this
  # whole script exists to catch in other people's work.
  entry="$(awk -v d="$TODAY" '
    $0 ~ "^(\\*\\*|##+[[:space:]]*)" d {f=1}
    f && /^---[[:space:]]*$/ {exit}
    f {print}
  ' "$FOCUS_MD")"
  if [ -z "$entry" ]; then
    echo "  FLAG [no-record] no FOCUS.md entry dated $TODAY -- this session left no durable record"
    flags=$((flags+1))
  else
    shas="$(printf '%s\n' "$entry" | grep -oE '`[0-9a-f]{7,40}`' | sort -u | tr '\n' ' ')"
    if [ -z "$shas" ]; then
      echo "  FLAG [record-no-sha] today's entry cites no commit sha in backticks"
      echo "    (a record that names no commit cannot be checked against the repo)"
      flags=$((flags+1))
    else
      echo "  ok -- entry dated $TODAY cites: $shas"
      # Cheap corroboration: do those shas actually exist here?
      for s in $shas; do
        s="${s//\`/}"
        git -C "$REPO_ROOT" cat-file -e "${s}^{commit}" 2>/dev/null && continue
        echo "    NOTE [foreign-sha] $s is not a commit in this repo (fine if it names another project's)"
      done
    fi
  fi
fi

echo
echo "== C. DECISION RESIDUE ($BLOCKERS_MD) =="
if [ ! -f "$BLOCKERS_MD" ]; then
  echo "  NOTE $BLOCKERS_MD not found -- cannot check"
elif grep -q "$TODAY" "$BLOCKERS_MD" 2>/dev/null; then
  echo "  ok -- BLOCKERS.md carries at least one line dated $TODAY"
else
  echo "  NOTE BLOCKERS.md has nothing dated $TODAY."
  echo "    Not a FLAG: only the closing session knows whether it had any"
  echo "    decision-shaped residue to file. If it did, it belongs there as a"
  echo "    '> '-answerable one-liner under the filing project's ## section."
fi
}
[ -n "$REPO_ARG" ] || session_wide_sections

echo
if [ -n "$REPO_ARG" ]; then
  echo "== $flags FLAG(s) in $REPO_ARG; $blind BLIND =="
else
  echo "== $flags FLAG(s) across $touched recently-touched repo(s); $blind BLIND =="
fi
[ "$blind" -gt 0 ] && echo "BLIND means a domain existed and was NOT read -- not a clean result."
echo "FLAGs are candidates for the closing session to resolve before it ends;"
echo "this script never edits, commits, or pushes anything."

# --- the gate --------------------------------------------------------------
# Order matters: a FLAG is something we DID see and is the stronger claim, so
# it wins over BLIND when both are present.
[ "$STRICT" = 1 ] && [ "$flags" -gt 0 ] && exit 1

if [ "$STRICT" = 1 ] && [ "$blind" -gt 0 ] && [ "$ALLOW_BLIND" != 1 ]; then
  # Interactive override. Both stdin AND stdout must be a TTY: a hook gets
  # neither, cron gets neither, and a lint that blocks forever waiting for an
  # answer nobody is there to give is worse than one that never gated.
  if [ -t 0 ] && [ -t 1 ]; then
    printf '\n%s BLIND domain(s) were not read. Proceed anyway? [y/N] ' "$blind" >&2
    read -r _reply </dev/tty 2>/dev/null || _reply=""
    case "$_reply" in
      [yY]|[yY][eE][sS])
        echo "closeout-lint: proceeding past $blind BLIND on an interactive override." >&2
        exit 0
        ;;
    esac
  fi
  echo "closeout-lint: refusing -- $blind BLIND domain(s) unread." >&2
  echo "  Audit them: closeout-lint.sh --strict --repo <path>   (one per worktree)" >&2
  echo "  Or accept:  re-run with --allow-blind (states, in the command, that" >&2
  echo "              you chose to proceed without reading them)." >&2
  exit 6
fi
exit 0
