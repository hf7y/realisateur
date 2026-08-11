#!/usr/bin/env bash
# stamp-agent.sh -- write (and verify) a project's BOOTSTRAP FOCUS.md.
#
# WHY THIS IS A MECHANISM AND NOT A RULE
# --------------------------------------
# THE PLAY's re-run rests on one premise: a project's FOCUS.md is enough
# to direct the agent that runs it. That premise only holds while the file
# stays a brief. Every FOCUS.md in this ecosystem started as one and
# accreted into a session log -- scheduler's reached 4455 lines,
# realisateur's 2517 -- because no session is ever ABOUT removing a line.
# That is UNIVERSE.md's Law 3 (retirement pressure) applied to the
# signaling tissue rather than to a command surface.
#
# realisateur's standing job is to stamp every agent it brings online. As
# prose, that decays -- which is the failure this play is re-running to
# fix. So it is a command: `stamp-agent.sh <project>` writes the file, and
# `stamp-agent.sh --check <project>` answers whether a project is stamped,
# so registration can REFUSE an unstamped one instead of trusting that
# someone remembered.
#
# The empirical case for mechanising a rule this way is ecosim's, 2026-07-29:
# eight two-states-one-symbol collapses were committed BY the instrument
# built to detect that exact class of fault, in one night. The rule was
# known and believed by its own author, and still lost. Only a mechanism
# that enumerates its own output caught them.
#
# USAGE
#   stamp-agent.sh --check <project>        # exit 0 stamped, 1 unstamped, 2 unknown
#   stamp-agent.sh --list                   # stamped/unstamped for every project
#   stamp-agent.sh <project> --role <one-line> --bar <one-line> \
#                  [--item <focus item>]... [--law <line>]... [--apply]
#
# Default is DRY RUN: prints the file it would write and exits. --apply
# writes it. Never commits -- committing is the caller's, so a stamp lands
# in the same reviewed change as whatever else that agent's arrival needs.
#
# STAMP_DATE (env, YYYY-MM-DD) overrides the date written into the stamp
# comment. Set it and this script becomes a PURE FUNCTION of its arguments:
# same args, byte-identical file, any day. That is what lets
# bin/make-bootstrap-branch.sh rebuild an identical bootstrap branch from a
# future repo state -- without it, "recreate the branch" silently produces a
# one-line diff every day and the reproducibility claim is untestable.
set -uo pipefail

# shellcheck source=lib/conf.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/conf.sh"

SCHED_ROOT="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"
STAMP_MARK="BOOTSTRAP STAMP"
# Bootstrap briefs are briefs. Past this many lines a file has stopped
# being one, and --check calls it out rather than passing it silently.
MAX_BRIEF_LINES="${STAMP_MAX_LINES:-120}"

die() { echo "stamp-agent: $*" >&2; exit 2; }

# Resolve a project's working copy from its scheduler conf -- ONE source,
# not a path retyped here (BUILD-DISCIPLINE: config read from one source),
# and read through lib/conf.sh so $HOME is EXPANDED. The raw grep this
# replaces handed back the literal `$HOME/Documents/Projects/<name>`, and
# every conf on every host writes exactly that -- so line 176's
# `[ -d "$REPO" ] || die` fired for every project, always. Loud, at least,
# unlike #73's other faces: this script could not stamp anything at all.
repo_path() {
  local conf="$SCHED_ROOT/schedule/$1.conf"
  [ -f "$conf" ] || return 1
  conf_repo_path "$conf"
}

# Where a project's FOCUS.md lives. .scheduler/ is canonical since the
# 2026-07-26 migration; .claude/ is legacy and still real for several
# projects, so an existing legacy file wins over a canonical path that
# does not exist yet -- stamping must not silently create a SECOND
# FOCUS.md and leave the agent reading the stale one.
focus_path() {
  local repo="$1"
  if [ -f "$repo/.scheduler/FOCUS.md" ]; then echo "$repo/.scheduler/FOCUS.md"
  elif [ -f "$repo/.claude/FOCUS.md" ]; then echo "$repo/.claude/FOCUS.md"
  else echo "$repo/.scheduler/FOCUS.md"; fi
}

# The FOCUS-FORMAT.md contract, checked rather than assumed: a heading the
# scheduler's extract_next_items() recognises, and at least one top-level
# item under it that is NOT inside an HTML comment. A stamp that does not
# parse is a stamp that directs nobody.
parses_as_focus() {
  awk '
    /<!--/ { inc=1 } inc { if (/-->/) inc=0; next }
    /^#+/ { h = tolower($0); insec = (h ~ /current focus|priority queue|priority|backlog/) }
    insec && /^ ?(- |[0-9]+\. )/ { found=1 }
    END { exit(found ? 0 : 1) }
  ' "$1"
}

check_one() {
  local p="$1" repo focus
  repo="$(repo_path "$p")" || { echo "UNKNOWN   $p (no schedule/$p.conf)"; return 2; }
  [ -n "$repo" ] && [ -d "$repo" ] || { echo "UNKNOWN   $p (repo path unresolvable: ${repo:-<empty>})"; return 2; }
  focus="$(focus_path "$repo")"
  [ -f "$focus" ] || { echo "UNSTAMPED $p (no FOCUS.md at ${focus#"$repo"/})"; return 1; }
  local lines; lines="$(wc -l < "$focus")"
  if ! grep -q "$STAMP_MARK" "$focus"; then
    echo "UNSTAMPED $p ($lines lines, no $STAMP_MARK marker)"; return 1
  fi
  if ! parses_as_focus "$focus"; then
    echo "UNSTAMPED $p (stamped but UNPARSEABLE -- no top-level item under a focus heading)"; return 1
  fi
  if [ "$lines" -gt "$MAX_BRIEF_LINES" ]; then
    echo "BLOATED   $p ($lines lines > $MAX_BRIEF_LINES -- stamped, but no longer a brief)"; return 1
  fi
  echo "STAMPED   $p ($lines lines)"; return 0
}

# ---- argument handling ----
[ $# -gt 0 ] || die "no arguments. See the usage block at the top of this script."

case "${1:-}" in
  -h|--help)
    printf 'stamp-agent.sh -- stamp a project with its agent role, bar and laws\n\n'
    printf 'usage:\n'
    printf '  stamp-agent.sh <project> --role R [--bar B] [--item I]... [--law L]... [--apply]\n'
    printf '  stamp-agent.sh --check <project>    verify one project'"'"'s stamp\n'
    printf '  stamp-agent.sh --list               check every registered project\n\n'
    printf 'flags: --role --bar --item --law --apply --check --list --selftest\n\n'
    printf 'exit codes:\n'
    printf '  0  stamped, or the checked stamp is present and current\n'
    printf '  1  a stated failure, or a --check/--list stamp is missing or drifted\n'
    printf '  2  usage error\n\n'
    printf 'this tool makes no AI calls and cannot spend: --summon is rejected.\n'
    exit 0 ;;
  --summon) die "--summon rejected: this tool makes no AI calls and cannot spend." ;;
  -s|-S)    die "'$1' rejected as a near-miss on --summon (the cost flag is long-form only)." ;;
  --check)
    [ $# -ge 2 ] || die "--check needs a project name"
    check_one "$2"; exit $?
    ;;
  --list)
    rc=0
    for c in "$SCHED_ROOT"/schedule/*.conf; do
      b="$(basename "$c" .conf)"
      case "$b" in _*) continue ;; esac
      check_one "$b" || rc=1
    done
    exit "$rc"
    ;;
  --selftest)
    # §4 proof: the checker must FIRE, not merely pass. A checker never
    # observed rejecting anything is indistinguishable from one that
    # cannot -- the exact defect ecosim found eight times in one night.
    t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT; fails=0
    printf '# F\n\n## Current focus\n\n- a real item\n' > "$t/ok.md"
    parses_as_focus "$t/ok.md" || { echo "FAIL: valid file rejected"; fails=1; }
    printf '# F\n\n## Current focus\n\n<!--\n- commented item\n-->\n' > "$t/commented.md"
    parses_as_focus "$t/commented.md" && { echo "FAIL: comment-only list accepted"; fails=1; }
    printf '# F\n\n## History\n\n- item under wrong heading\n' > "$t/wrongheading.md"
    parses_as_focus "$t/wrongheading.md" && { echo "FAIL: item outside a focus heading accepted"; fails=1; }
    printf '# F\n\n## Current focus\n\nprose only, no list\n' > "$t/nolist.md"
    parses_as_focus "$t/nolist.md" && { echo "FAIL: listless file accepted"; fails=1; }
    printf '# F\n\n## Backlog\n\n   - deeply indented\n' > "$t/indent.md"
    parses_as_focus "$t/indent.md" && { echo "FAIL: over-indented sub-bullet accepted as top-level"; fails=1; }
    [ "$fails" -eq 0 ] && echo "selftest OK (5 cases: 1 accept, 4 reject -- every reject path observed firing)"
    exit "$fails"
    ;;
esac

PROJECT="$1"; shift
ROLE=""; BAR=""; APPLY=0
declare -a ITEMS=() LAWS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --role) ROLE="${2:-}"; shift 2 ;;
    --bar)  BAR="${2:-}";  shift 2 ;;
    --item) ITEMS+=("${2:-}"); shift 2 ;;
    --law)  LAWS+=("${2:-}");  shift 2 ;;
    --apply) APPLY=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$ROLE" ] || die "--role is required. An agent without a stated role invents one."
[ -n "$BAR" ]  || die "--bar is required. A bootstrap with no bar has no done."
[ "${#ITEMS[@]}" -gt 0 ] || die "at least one --item is required, or the file will not parse as a focus list."

REPO="$(repo_path "$PROJECT")" || die "no $SCHED_ROOT/schedule/$PROJECT.conf -- register the project first."
[ -n "$REPO" ] && [ -d "$REPO" ] || die "PROJECT_REPO_PATH unresolvable for $PROJECT: ${REPO:-<empty>}"
FOCUS="$(focus_path "$REPO")"

OUT="$(mktemp)"
{
  echo "# FOCUS — $PROJECT"
  echo
  echo "<!-- $STAMP_MARK. Written by realisateur bin/stamp-agent.sh on ${STAMP_DATE:-$(date +%Y-%m-%d)}."
  echo "     This file is this agent's WHOLE brief. Anything that was here before"
  echo "     is recoverable from git (\`git log -p -- ${FOCUS#"$REPO"/}\`) and was"
  echo "     stripped deliberately, not lost. Do not restore it. Do not append"
  echo "     session history here -- that is how the last one reached four"
  echo "     thousand lines and stopped directing anybody. -->"
  echo
  echo "## What this project is"
  echo
  echo "$ROLE"
  echo
  echo "## The bar for this bootstrap"
  echo
  echo "$BAR"
  echo
  echo "Done means a WITNESS, not code existing: a command that ran, a log line,"
  echo "a commit on the ref the consumer reads. Not \"it is written.\""
  echo
  echo "## Current focus"
  echo
  for i in "${ITEMS[@]}"; do echo "- $i"; done
  if [ "${#LAWS[@]}" -gt 0 ]; then
    echo
    echo "## Standing constraints"
    echo
    for l in "${LAWS[@]}"; do echo "- $l"; done
  fi
  echo
  echo "## Standing constraints (ecosystem-wide)"
  echo
  echo "- A claim about system state is **re-probed, not quoted**."
  echo "- **A dirty tree at exit is a failed run**, not a handoff."
  echo "- Fail **loud**. An exit-0 no-op is worse than a crash."
  echo "- File work you did not ask for through the front door; do not just do it."
} > "$OUT"

if ! parses_as_focus "$OUT"; then
  rm -f "$OUT"
  die "generated file does not satisfy FOCUS-FORMAT.md -- refusing to write it."
fi

if [ "$APPLY" -eq 0 ]; then
  echo "=== DRY RUN -- would write $FOCUS ($(wc -l < "$OUT") lines) ==="
  cat "$OUT"
  [ -f "$FOCUS" ] && echo "=== (replacing an existing $(wc -l < "$FOCUS")-line file) ==="
  rm -f "$OUT"
  echo "=== re-run with --apply to write ==="
  exit 0
fi

mkdir -p "$(dirname "$FOCUS")" || die "cannot create $(dirname "$FOCUS")"
prev_lines=0; [ -f "$FOCUS" ] && prev_lines="$(wc -l < "$FOCUS")"
cp "$OUT" "$FOCUS" || die "write failed: $FOCUS"
rm -f "$OUT"
echo "stamped $PROJECT: $FOCUS ($prev_lines -> $(wc -l < "$FOCUS") lines)"
echo "NOT committed -- commit this with whatever else $PROJECT's arrival needs."
