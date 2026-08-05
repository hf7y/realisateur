#!/usr/bin/env bash
# verify-closure.sh -- the guard that makes the CLEAN column a move-list.
#
# THE LOAD-BEARING ASSERTIONS ARE A1, A2 AND B1.
#
# A1: a script that itself scores ZERO but sources a library naming a vendor
#     must classify ESSENTIAL, and must be reported as a FALSE NEGATIVE. This
#     is scheduler/bin/scheduler-run, reproduced as a fixture. Without it the
#     migration moves the model dispatcher onto the branch that guarantees it
#     holds none.
#
# A2: `source "$CONF"` -- a path that is runtime state -- must classify
#     UNRESOLVED and must NEVER be CLEAN. Treating an unresolvable source as
#     "no dependency" rebuilds A1 one layer down, which is the failure mode
#     that is easy to write and impossible to see.
#
# B1: a project name matching nothing must EXIT 1. A checker reporting clean
#     about something it never looked at is this ecosystem's most-recorded
#     failure, and a filter is where it hides best. (verify-sync.sh calls the
#     same assertion B4 and treats it the same way.)
#
# Hermetic: builds fixture repos and a fixture schedule dir in a temp dir,
# points BASHIFY_SCHED at it. Never reads the live ecosystem, never writes
# outside its temp dir.
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"   # bashify/
CLOSURE="$ROOT/lib/closure.sh"
. "$ROOT/lib/surface.sh"

pass=0; fail=0
ok()   { printf '  ok   %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export BASHIFY_SCHED="$WORK/sched"
mkdir -p "$BASHIFY_SCHED/schedule"
G() { git -c user.email=t@t -c user.name=t -C "$1" "${@:2}"; }

# mkrepo <name> -- a git repo with a bashified branch and a scheduler conf.
mkrepo() {
  local d="$WORK/repos/$1"
  mkdir -p "$d"; G "$d" init -q -b main
  echo x > "$d/README.md"; G "$d" add -A; G "$d" commit -qm init
  G "$d" branch bashified
  printf 'PROJECT_REPO_PATH=%s\n' "$d" > "$BASHIFY_SCHED/schedule/$1.conf"
  printf '%s' "$d"
}
commit() { G "$1" add -A; G "$1" commit -qm f >/dev/null 2>&1; }

# cls <project> <script> -- the class closure.sh assigns, from the TSV
cls() { "$CLOSURE" --tsv "$1" 2>/dev/null | awk -F'\t' -v s="$2" '$2==s{print $3}'; }
col() { "$CLOSURE" --tsv "$1" 2>/dev/null | awk -F'\t' -v s="$2" -v c="$3" '$2==s{print $c}'; }

echo "== A. the false negative that blocks the migration =="

# A1 -- scheduler-run, reproduced. bin/dispatch scores 0; the lib it sources
# names a vendor in CODE, not a comment.
r="$(mkrepo fixdispatch)"
mkdir -p "$r/bin" "$r/lib"
printf '#!/usr/bin/env bash\nSELF="$(dirname "$0")"\nsource "$SELF/../lib/engine.sh"\nrun_it\n' > "$r/bin/dispatch"
printf '#!/usr/bin/env bash\nrun_it() { claude -p "$PROMPT" --model "$MODEL"; }\n' > "$r/lib/engine.sh"
chmod +x "$r/bin/dispatch"; commit "$r"

check "A1 self-score of the wrapper is 0 (the old guard clears it)" \
  "$(surface_score "$r/bin/dispatch")" "0"
check "A1 the library it sources scores nonzero" \
  "$([ "$(surface_score "$r/lib/engine.sh")" -gt 0 ] && echo yes)" "yes"
check "A1 closure classifies the wrapper ESSENTIAL" "$(cls fixdispatch bin/dispatch)" "ESSENTIAL"
check "A1 the closure carries the library's score, not the wrapper's" \
  "$(col fixdispatch bin/dispatch 5)" "$(surface_score "$r/lib/engine.sh")"
check "A1 via names the library that condemned it" \
  "$(col fixdispatch bin/dispatch 7)" "lib/engine.sh"
"$CLOSURE" fixdispatch >/dev/null 2>&1
check "A1 exit 1 -- a false negative is a finding, not a note" "$?" "1"
check "A1 it is REPORTED as a false negative, by name" \
  "$("$CLOSURE" fixdispatch 2>/dev/null | grep -c 'FALSE NEGATIVE')" "1"

# A4 -- the truncation regression. `$(dirname "$0")/../lib/x.sh` must RESOLVE.
# A first cut cut the argument at the first `)` and called this UNRESOLVED,
# which would have hidden A1 behind the weaker finding.
check "A4 \$(dirname \"\$0\")/../lib resolves (closure has 2 members)" \
  "$(col fixdispatch bin/dispatch 6)" "2"

echo
echo "== B. the honest failure mode =="

# A2 -- a source whose whole path is runtime state.
r="$(mkrepo fixdynamic)"
mkdir -p "$r/bin"
printf '#!/usr/bin/env bash\nCONF="$1"\nsource "$CONF"\n' > "$r/bin/loader"
chmod +x "$r/bin/loader"; commit "$r"
check "A2 a wholly-variable source path is UNRESOLVED" "$(cls fixdynamic bin/loader)" "UNRESOLVED"
check "A2 and it is NOT CLEAN" \
  "$([ "$(cls fixdynamic bin/loader)" != CLEAN ] && echo yes)" "yes"
check "A2 the unresolved directive is printed, not counted away" \
  "$("$CLOSURE" fixdynamic 2>/dev/null | grep -c 'UNRESOLVED source directive')" "1"

# B1 -- a name matching nothing.
"$CLOSURE" no-such-project-anywhere >/dev/null 2>&1
check "B1 a name matching nothing exits 1, never 0" "$?" "1"

echo
echo "== C. the classes it must NOT over-condemn =="

# C1 -- genuinely clean, including through a clean library.
r="$(mkrepo fixclean)"
mkdir -p "$r/bin" "$r/lib"
printf '#!/usr/bin/env bash\nsource "$(dirname "$0")/../lib/util.sh"\ntidy\n' > "$r/bin/tidy"
printf '#!/usr/bin/env bash\ntidy() { echo tidy; }\n' > "$r/lib/util.sh"
chmod +x "$r/bin/tidy"; commit "$r"
check "C1 clean wrapper + clean library is CLEAN" "$(cls fixclean bin/tidy)" "CLEAN"
"$CLOSURE" fixclean >/dev/null 2>&1
check "C1 and exits 0" "$?" "0"

# C2 -- vendor named only in a comment is COMMENT-ONLY, not ESSENTIAL. The
# distinction is what keeps the guard from crying wolf.
r="$(mkrepo fixcomment)"
mkdir -p "$r/bin"
printf '#!/usr/bin/env bash\n# this used to call claude -p; it no longer does\necho hi\n' > "$r/bin/former"
chmod +x "$r/bin/former"; commit "$r"
check "C2 a comment-only mention is COMMENT-ONLY" "$(cls fixcomment bin/former)" "COMMENT-ONLY"

# C3 -- REWRITTEN 2026-08-05 when the criterion changed from NAMING a model to
# INVOKING one (Zach's call; see lib/surface.sh "NAMING vs INVOKING").
# Previously this asserted ESSENTIAL, on the conservative reading that a
# trailing comment sits on a line of code and code that names a vendor might
# run one. Under the new rule the question is whether the line RUNS a model,
# and `run_thing` does not -- the mention is in the comment, and a comment
# cannot dispatch. So COMMENT-ONLY is now the correct answer, and asserting
# ESSENTIAL here would be asserting the superseded criterion.
r="$(mkrepo fixtrailing)"
mkdir -p "$r/bin"
printf '#!/usr/bin/env bash\nrun_thing   # dispatches via claude\n' > "$r/bin/mixed"
chmod +x "$r/bin/mixed"; commit "$r"
check "C3 a code line whose COMMENT names a model is COMMENT-ONLY" "$(cls fixtrailing bin/mixed)" "COMMENT-ONLY"

# C3b -- the half that must NOT relax with it: an actual invocation is still
# ESSENTIAL even when a trailing comment is what draws the eye. Without this,
# C3's change would read as "trailing comments are ignored" rather than
# "naming is not invoking".
r="$(mkrepo fixtrailingreal)"
mkdir -p "$r/bin"
printf '#!/usr/bin/env bash\nclaude -p "$PROMPT"   # the real thing\n' > "$r/bin/mixed"
chmod +x "$r/bin/mixed"; commit "$r"
check "C3b a real invocation with a trailing comment is ESSENTIAL" "$(cls fixtrailingreal bin/mixed)" "ESSENTIAL"

# C3c -- the refusal case that cost four false positives in cli-guard.sh: a
# script REJECTING --summon must not be read as spending it.
r="$(mkrepo fixrefusal)"
mkdir -p "$r/bin"
printf '#!/usr/bin/env bash\ncase "$1" in\n  --summon) die "--summon rejected: this tool cannot spend." ;;\nesac\n' > "$r/bin/guarded"
chmod +x "$r/bin/guarded"; commit "$r"
check "C3c refusing --summon is not invoking it" "$(cls fixrefusal bin/guarded)" "CLEAN"

echo
echo "== D. termination and arithmetic =="

# D1 -- mutual recursion must terminate.
r="$(mkrepo fixcycle)"
mkdir -p "$r/bin" "$r/lib"
printf '#!/usr/bin/env bash\nsource "$(dirname "$0")/../lib/a.sh"\n' > "$r/bin/cyc"
printf 'source "$(dirname "${BASH_SOURCE[0]}")/b.sh"\n' > "$r/lib/a.sh"
printf 'source "$(dirname "${BASH_SOURCE[0]}")/a.sh"\n' > "$r/lib/b.sh"
chmod +x "$r/bin/cyc"; commit "$r"
out="$(timeout 30 "$CLOSURE" --tsv fixcycle 2>/dev/null | awk -F'\t' '$2=="bin/cyc"{print $6}')"
check "D1 a source cycle terminates, with each file counted once" "$out" "3"

# D2 -- `grep -c` prints 0 AND exits 1. The obvious `|| printf 0` fallback
# yields "0\n0", which is not `0`, and every integer test downstream then
# misfires. That bug made the first run of this tool report "no false
# negatives" about a script it had already condemned.
check "D2 surface_score of a clean file is exactly one token" \
  "$(surface_score "$r/lib/a.sh" | wc -w)" "1"
check "D2 and that token is 0" "$(surface_score "$r/lib/a.sh")" "0"

echo
echo "== E. the anchor reaches the PATH guard, not just the content guard =="
# The 2026-08-02 fix anchored the content guard in bashify.sh and left the
# path guard eleven lines above it unanchored, because they were two copies.
# These assert the single definition in lib/surface.sh covers both.
for n in fullmatch.sh killmode.sh; do
  check "E1 '$n' names no vendor" \
    "$(surface_names_vendor "bin/$n" && echo VENDOR || echo clean)" "clean"
done
for n in AnthropicClient.js agent-runner.sh my-llm-helper.sh; do
  check "E2 '$n' does name one" \
    "$(surface_names_vendor "bin/$n" && echo VENDOR || echo clean)" "VENDOR"
done
# E3 -- the compounds. `agent` is deliberately UNANCHORED: anchoring it either
# side is an evasion, because every compound of it names an agent. This is the
# live file that flips to EXPOSED under `\bagent\b`, which is why the vendor
# half is anchored and this half is not.
for n in subagent-closeout.sh agents.sh agentic-loop.sh; do
  check "E3 compound '$n' still names an agent" \
    "$(surface_names_vendor "hooks/$n" && echo VENDOR || echo clean)" "VENDOR"
done

echo
printf 'passed %d, failed %d\n' "$pass" "$fail"
exit $(( fail > 0 ? 1 : 0 ))
