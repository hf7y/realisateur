#!/usr/bin/env bash
#
# conf.test.sh -- the defect that made propagation reach zero projects.
#
# THE LOAD-BEARING ASSERTIONS ARE A1 AND B1. A1: a conf written the way EVERY
# registered project writes it -- PROJECT_REPO_PATH="$HOME/..." -- resolves to
# a real directory. The raw `grep -oP` this replaces returned the literal
# characters `$HOME/...`, so `[ -d "$repo/.git" ]` was false for every project
# on every host and restamp-discipline.sh propagated the baseline to NOBODY
# while printing a tidy summary and exiting 0.
#
# B1: a run that reached nothing exits nonzero. Without it the fix is one bad
# conf away from silently regressing to the same shape, and the shape is the
# point: thirteen SKIP lines and exit 0 is what the defect looked like for as
# long as it lasted.
#
# Hermetic: builds its own scheduler root and its own target repos in a temp
# dir, overrides HOME and SCHED_ROOT, and never touches the live ecosystem.
#
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$REPO/bin/lib/conf.sh"


T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'conf.sh -- test\n\n'

# --- A: expansion -------------------------------------------------------------
printf 'A. the path a real conf carries resolves (A1 is the whole defect)\n'
printf 'PROJECT_REPO_PATH="$HOME/Documents/Projects/demo"\n' > "$T/a.conf"
got="$(HOME=/tmp/fakehome conf_repo_path "$T/a.conf")"
eq "A1  \$HOME is expanded"        "$got" "/tmp/fakehome/Documents/Projects/demo"
printf 'PROJECT_REPO_PATH="${HOME}/x"\n' > "$T/b.conf"
got="$(HOME=/tmp/fakehome conf_repo_path "$T/b.conf")"
eq "A2  \${HOME} is expanded too"  "$got" "/tmp/fakehome/x"
printf 'PROJECT_REPO_PATH="/opt/absolute"\n' > "$T/c.conf"
eq "A3  an absolute path is untouched" "$(conf_repo_path "$T/c.conf")" "/opt/absolute"
# A conf is a file this repo does not own. Expansion is by name, not by eval.
printf 'PROJECT_REPO_PATH="$(touch %s/PWNED)/x"\n' "$T" > "$T/d.conf"
conf_repo_path "$T/d.conf" >/dev/null 2>&1
if [ -e "$T/PWNED" ]; then bad "A4  a conf cannot execute code through this"
else ok "A4  a conf cannot execute code through this"; fi
printf 'OTHER="x"\n' > "$T/e.conf"
conf_repo_path "$T/e.conf" >/dev/null 2>&1
eq "A5  no PROJECT_REPO_PATH returns 1" "$?" "1"

# --- B: RETIRED 2026-08-14 -----------------------------------------------------
# This section exercised restamp-discipline.sh end to end against a fixture
# ecosystem, including its "a pass that reached nothing exits nonzero" guard.
# The script is gone, and so is the checklist it stamped (#684)

# --- C: the population ratchet -----------------------------------------------
# WHY A RATCHET AND NOT A LIST. lib/conf.sh's header used to NAME the four
# scripts still on the raw grep; by 2026-08-11 it was wrong in both directions
printf '\nC. no script in bin/ extracts PROJECT_REPO_PATH without expanding it\n'
c_bad=""
c_scanned=0
while IFS= read -r f; do
  [ -f "$REPO/$f" ] || continue
  c_scanned=$((c_scanned + 1))
  # An EXTRACTION: a non-comment line pulling the value out with a text tool.
  # `grep -q '^PROJECT_REPO_PATH='` (presence) and sourcing the conf
  # (silence-audit.sh, which expands by definition) are not extractions.
  grep -vE '^[[:space:]]*#' "$REPO/$f" \
    | grep -E 'PROJECT_REPO_PATH' \
    | grep -qE 'grep -o|sed -n|cut -d|awk' || continue
  # ...and somewhere in the same file, an expansion.
  grep -q 'conf_repo_path' "$REPO/$f" && continue
  grep -qF "'\$HOME'/*)" "$REPO/$f" && continue
  c_bad="$c_bad $f"
  # `:(glob)` so `*` stops at `/`. bin/tests/ is deliberately out: a suite that
  # QUOTES the raw grep in a fixture (deferral-ledger.test.sh does, verbatim,
  # as its example of a well-formed deferral) documents the defect rather than
  # committing it. The population is the scripts that run against the registry.
done < <(cd "$REPO" && git ls-files \
           ':(glob)bin/*.sh' ':(glob)bin/lib/*.sh' \
           2>/dev/null)

if [ "$c_scanned" -eq 0 ]; then
  bad "C0  the scan found files to scan" "git ls-files matched nothing -- this checked NOTHING"
else
  ok "C0  scanned $c_scanned tracked script(s) under bin/"
fi
if [ -z "$c_bad" ]; then
  ok "C1  every extraction of PROJECT_REPO_PATH is expanded"
else
  bad "C1  every extraction of PROJECT_REPO_PATH is expanded" "unexpanded:$c_bad"
fi

# Section D exercised session-marker.sh; RESTORED at hooks/session-marker.sh
# (hf7y/vim-arcade#207), sourcing this file's conf_repo_path as before -- see
# bin/tests/selfdev-hooks-provision.test.sh section I/J for its wiring coverage.

summary
