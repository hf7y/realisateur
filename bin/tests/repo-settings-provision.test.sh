#!/usr/bin/env bash
# HERMETICITY: offline, zero AI, no network. Every invocation sets both
# SCHED_ROOT (to a throwaway schedule/*.conf registry in $T) and GH_BIN (to a
# stub in $T that answers from a fixture table), so no run reads the live
# scheduler registry and none reaches github.com -- the stub resolves no
# hostname and holds no credential. The one case that deliberately points at
# an empty registry points at a fresh mktemp dir, never at $HOME.
#
# repo-settings-provision.test.sh -- witness for bin/repo-settings-provision.sh.
#
# Cases:
#   A both settings already true            -> "ok", 0 drift
#   B both settings false                   -> DRIFT, --strict exits 1
#   C one true one false                    -> DRIFT (either alone is enough)
#   D repo unreadable (stub returns nothing) -> BLIND, not silently "ok"
#   E --apply calls gh repo edit with exactly the missing flag(s)
#   F bare invocation (no --strict) exits 0 even with drift -- signal by
#     default, same stance as hygiene-lint/closeout-lint
#   G BLIND is never 0 and is never gated behind --strict: an unreadable repo
#     exits 2 with or without the flag, and an EMPTY registry -- the shape
#     that reads as "0 drifted, 0 BLIND, out of 0 project(s)" and looks like
#     compliance -- exits 2 and says nothing was measured.
#
# ON F AND G TOGETHER, because the pair is the point. F's original assertion
# ran bare against the whole fixture registry, which contains gone-proj, and
# pinned exit 0 -- so it was pinning "reported a repo it could not read, and
# graded that clean". bin/tests/guard-estate.test.sh case E1 is the authority
# that says that is wrong, and it is what went red. F now runs against the
# three READABLE projects, which is what it was always about (drift alone does
# not gate without --strict); G asserts the half F was accidentally denying.
#
# Usage: bin/tests/repo-settings-provision.test.sh   (exit 0 = all pass)
set -uo pipefail
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/repo-settings-provision.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 (unexpected: $3)" ;; *) ok "$1" ;; esac; }
rc()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }

mkdir -p "$T/schedule"
cat > "$T/schedule/clean-proj.conf" <<'EOF'
PROJECT_REPO_PATH="$HOME/Documents/Projects/clean-proj"
REPO_URL="https://github.com/acme/clean-proj.git"
EOF
cat > "$T/schedule/dirty-proj.conf" <<'EOF'
PROJECT_REPO_PATH="$HOME/Documents/Projects/dirty-proj"
REPO_URL="https://github.com/acme/dirty-proj.git"
EOF
cat > "$T/schedule/mixed-proj.conf" <<'EOF'
PROJECT_REPO_PATH="$HOME/Documents/Projects/mixed-proj"
REPO_URL="git@github.com:acme/mixed-proj.git"
EOF
cat > "$T/schedule/gone-proj.conf" <<'EOF'
PROJECT_REPO_PATH="$HOME/Documents/Projects/gone-proj"
REPO_URL="https://github.com/acme/gone-proj.git"
EOF
cat > "$T/schedule/_ignored.conf" <<'EOF'
PROJECT_REPO_PATH="$HOME/Documents/Projects/should-not-appear"
REPO_URL="https://github.com/acme/should-not-appear.git"
EOF

# --- the gh stub: answers `api repos/OWNER/REPO --jq ...` from a fixture
# table, and records every `repo edit` call it receives so case E can check
# the exact flags applied.
GH_CALLS="$T/gh-edit-calls.log"
: > "$GH_CALLS"
cat > "$T/gh" <<EOF
#!/usr/bin/env bash
CALLS="$GH_CALLS"
case "\$1 \$2" in
  "api repos/acme/clean-proj") echo '{"d":true,"a":true}' ;;
  "api repos/acme/dirty-proj") echo '{"d":false,"a":false}' ;;
  "api repos/acme/mixed-proj") echo '{"d":true,"a":false}' ;;
  "api repos/acme/gone-proj")  exit 1 ;;
  "repo edit")
    echo "\$*" >> "\$CALLS"
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$T/gh"

run() { SCHED_ROOT="$T" GH_BIN="$T/gh" "$SCRIPT" "$@" 2>&1; }

# --- A/B/C/D: bare invocation reports every case correctly ------------------
out="$(run)"; rc_got=$?
has "A: clean-proj reports ok"    "$out" "ok    clean-proj"
has "B: dirty-proj reports DRIFT" "$out" "DRIFT dirty-proj"
has "C: mixed-proj reports DRIFT" "$out" "DRIFT mixed-proj"
has "D: gone-proj reports BLIND"  "$out" "BLIND gone-proj"
hasnt "_ignored.conf never scanned" "$out" "should-not-appear"
has "summary counts 2 drifted, 1 BLIND, 4 total" "$out" "2 drifted, 1 BLIND, out of 4"

# --- F: drift alone does not gate without --strict --------------------------
# Scoped to the three readable projects on purpose: the claim is about DRIFT,
# and mixing gone-proj in would make a green here mean "blindness is fine too".
run clean-proj dirty-proj mixed-proj >/dev/null 2>&1
rc "bare invocation exits 0 despite drift" 0 "$?"

# --- F/strict: --strict gates on drift --------------------------------------
run --strict >/dev/null 2>&1; rc "--strict exits 1 when drift found" 1 "$?"
run --strict clean-proj >/dev/null 2>&1; rc "--strict exits 0 on a clean-only filter" 0 "$?"

# --- G: BLIND is never 0, with or without --strict --------------------------
rc "bare invocation exits 2 when a repo could not be read" 2 "$rc_got"
run clean-proj gone-proj >/dev/null 2>&1
rc "an unreadable repo alone is BLIND, exit 2, no --strict needed" 2 "$?"
run --strict clean-proj gone-proj >/dev/null 2>&1
rc "...and --strict does not turn that blindness into clean either" 2 "$?"

# An EMPTY registry is the shape guard-estate E1 actually caught: the loop
# never runs, the summary reads "out of 0 project(s)", and exit 0 would say
# the estate is compliant on the strength of having looked at nothing.
EMPTY="$(mktemp -d)"; mkdir -p "$EMPTY/schedule"
out="$(SCHED_ROOT="$EMPTY" GH_BIN="$T/gh" "$SCRIPT" --strict 2>&1)"; rc_empty=$?
rc "an empty registry is BLIND, exit 2 -- not 'nothing drifted'" 2 "$rc_empty"
has "...and says so in words" "$out" "BLIND: no registered project with a REPO_URL"
has "...and says nothing was measured is not clean" "$out" "This is NOT a clean result"
rm -rf "$EMPTY"

# --- read-only by default: no gh repo edit call without --apply ------------
: > "$GH_CALLS"
run >/dev/null
[ ! -s "$GH_CALLS" ] && ok "bare invocation never calls 'gh repo edit'" \
  || bad "bare invocation called gh repo edit (should be read-only)"

# --- E: --apply calls gh repo edit with exactly the missing flag(s) --------
: > "$GH_CALLS"
run --apply dirty-proj >/dev/null
calls="$(cat "$GH_CALLS")"
has "E: dirty-proj --apply sets both flags" "$calls" "acme/dirty-proj --delete-branch-on-merge --enable-auto-merge"

: > "$GH_CALLS"
run --apply mixed-proj >/dev/null
calls="$(cat "$GH_CALLS")"
has "E: mixed-proj --apply sets only the missing flag" "$calls" "acme/mixed-proj --enable-auto-merge"
hasnt "E: mixed-proj --apply does not re-set the already-true flag" "$calls" "--delete-branch-on-merge"

: > "$GH_CALLS"
run --apply clean-proj >/dev/null
calls="$(cat "$GH_CALLS")"
[ -z "$calls" ] && ok "E: clean-proj --apply calls gh repo edit for nobody" \
  || bad "E: clean-proj --apply unexpectedly called: $calls"

echo
echo "== $pass ok, $fail FAIL =="
[ "$fail" -eq 0 ]
