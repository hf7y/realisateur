#!/usr/bin/env bash
#
# Contract test for bin/cloture: a close either comes back CLEAN or comes back
# with rows, and a check that could not look is never CLEAN.
#
# HERMETICITY: full. Every input cloture reads is redirected into $T -- a fake
# `installe` on PATH, a fake build tree, a fake home commands dir, a fake
# transcript root and a throwaway git repo. Nothing here touches the real
# host's build, home or repositories, which matters because the thing under
# test is an auditor of exactly those.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/cloture"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
harness_tmp

mkdir -p "$T/bin" "$T/build/realisateur/commands" "$T/home/commands" "$T/projects/p"

# A `gh` that answers every issue OPEN, milestoned, NO-DECISION -- so the
# default fixture is quiet and each case turns on exactly one thing.
cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "${GH_MODE:-quiet}" in
  nomilestone) printf 'NONE\n' ;;
  decision)    printf 'a call that needs a person\n' ;;
  *)           printf '' ;;
esac
exit 0
EOF
chmod +x "$T/bin/gh"

cat > "$T/bin/installe" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = list ] || exit 2
printf 'garde\t%s\n' "$HOME/.local/share/verb-builds/current/gardien/bin/garde"
[ -n "${WITH_CLONE:-}" ] && printf 'vim-arcade\t%s/Documents/Projects/vim-arcade/bin/vim-arcade\n' "$HOME"
exit 0
EOF
chmod +x "$T/bin/installe"

run() { ( cd "$T/repo" 2>/dev/null || cd "$T" || exit 2
          PATH="$T/bin:$PATH" HOME="$T" \
          VERB_BUILD_DIR="$T/build" CLAUDE_COMMANDS_DIR="$T/home/commands" \
          CLAUDE_PROJECTS_ROOT="$T/projects" "$@" ); }

# ---------------------------------------------------------------------------
section 'A. built but not wired'

: > "$T/build/realisateur/commands/ideate.md"
: > "$T/home/commands/ideate.md"
out="$(run "$SCRIPT" 2>&1)"
hasnt 'A1 a matched build and home raises no row' "$out" 'BUILT-NOT-INSTALLED'

: > "$T/build/realisateur/commands/nightly-batch.md"
out="$(run "$SCRIPT" 2>&1)"
has 'A2 a build command with no home is BUILT-NOT-INSTALLED' "$out" 'BUILT-NOT-INSTALLED'
has 'A3 and it names the file'                               "$out" 'nightly-batch.md'

: > "$T/home/commands/retired.md"
out="$(run "$SCRIPT" 2>&1)"
has 'A4 a home command no build produces is INSTALLED-NOT-BUILT' "$out" 'INSTALLED-NOT-BUILT'
rm -f "$T/home/commands/retired.md" "$T/build/realisateur/commands/nightly-batch.md"

# ---------------------------------------------------------------------------
section 'B. the no-clone acceptance test'

out="$(run "$SCRIPT" 2>&1)"
hasnt 'B1 a build-backed name is not a finding' "$out" 'CLONE-BACKED'

out="$(WITH_CLONE=1 run env WITH_CLONE=1 "$SCRIPT" 2>&1)"
has 'B2 a name resolving into a checkout is CLONE-BACKED' "$out" 'CLONE-BACKED'
has 'B3 and it says why that matters'                     "$out" 'stops working'

# ---------------------------------------------------------------------------
section 'C. could not look is never clean'

# A real PATH minus the fixture bin: coreutils present, `installe` absent.
# Not an empty PATH -- that cannot find bash for the shebang, which is a fact
# about the fixture and not about the thing under test.
out="$(run env PATH=/usr/bin:/bin "$SCRIPT" 2>&1)"
has 'C1 no installe on PATH reports BLIND' "$out" 'BLIND'
out="$(run env -u CLAUDE_CODE_SESSION_ID "$SCRIPT" 2>&1)"
has 'C2 no session id reports BLIND rather than passing' "$out" 'BLIND'
run env -u CLAUDE_CODE_SESSION_ID "$SCRIPT" >/dev/null 2>&1; rc 'C3 blind exits nonzero' 0 "$(( $? == 0 ? 1 : 0 ))"

# ---------------------------------------------------------------------------
section 'D. raised but not filed is structural, not lexical'

mkdir -p "$T/projects/p"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"see https://github.com/o/r/issues/7 for it"}]}}' \
  > "$T/projects/p/$$.jsonl"
out="$(run env CLAUDE_CODE_SESSION_ID="$$" GH_MODE=nomilestone "$SCRIPT" 2>&1)"
has 'D1 an unmilestoned open issue is OPEN-NO-MILESTONE' "$out" 'OPEN-NO-MILESTONE'
has 'D2 and it names the issue'                          "$out" 'o/r#7'

out="$(run env CLAUDE_CODE_SESSION_ID="$$" GH_MODE=quiet "$SCRIPT" 2>&1)"
hasnt 'D3 a milestoned issue raises no row' "$out" 'OPEN-NO-MILESTONE'

# The regression this section exists for: the first implementation grepped the
# transcript for defect words and matched 0 of 239 real messages.
hasnt 'D4 no keyword scan is claimed in the output' "$out" 'UNFILED-CANDIDATES'

# ---------------------------------------------------------------------------
section 'E. blocked on a person is scoped to this session'

out="$(run env CLAUDE_CODE_SESSION_ID="$$" GH_MODE=decision "$SCRIPT" blocked 2>&1)"
has 'E1 a DECISION: issue this session touched is surfaced' "$out" 'AWAITING-A-PERSON'
out="$(run env CLAUDE_CODE_SESSION_ID="$$" GH_MODE=quiet "$SCRIPT" blocked 2>&1)"
hasnt 'E2 a NO-DECISION: issue is not' "$out" 'AWAITING-A-PERSON'

# ---------------------------------------------------------------------------
section 'G. untracked junk is dealt with, not narrated'

# The 2026-09-07 case: a 12MB file nobody owned sat in a repo root and the
# close reported it in prose. A row is not enough on its own -- it has to name
# the path, or the next close reports a count and moves on again.
git init -q "$T/repo" 2>/dev/null
( cd "$T/repo" && git config user.email t@t && git config user.name t \
  && : > tracked.txt && git add tracked.txt && git commit -qm init ) 2>/dev/null

out="$(run "$SCRIPT" 2>&1)"
hasnt 'G1 a clean repo raises no UNTRACKED row' "$out" 'UNTRACKED'

: > "$T/repo/json"
out="$(run "$SCRIPT" 2>&1)"
has 'G2 an untracked non-ignored file is UNTRACKED' "$out" 'UNTRACKED'
has 'G3 and the row names the path'                 "$out" 'json'

printf 'json\n' > "$T/repo/.gitignore"
( cd "$T/repo" && git add .gitignore && git commit -qm ignore ) 2>/dev/null
out="$(run "$SCRIPT" 2>&1)"
hasnt 'G4 an ignored file is not a finding' "$out" '    json'

# ---------------------------------------------------------------------------
section 'F. usage'

run "$SCRIPT" --help >/dev/null 2>&1; rc 'F1 --help exits 0' 0 $?
run "$SCRIPT" nonsense >/dev/null 2>&1; rc 'F2 an unknown argument exits 2' 2 $?
out="$(run "$SCRIPT" --help 2>&1)"
has 'F3 --help says the loop is the routine' "$out" 'run it again'

summary
