#!/usr/bin/env bash
# port-markdown-cost.sh -- give another repo the same markdown ratchet.
#
# Not a guard: it emits no findings and gates nothing in this repo's own CI.
# It is a one-shot installer, run by hand once per target repo (or again to
# pick up an update to bin/markdown-cost.sh itself).
#
#
# WHY THIS EXISTS. bin/markdown-cost.sh (realisateur#176) prices prose against
# mechanism on every PR here, and nothing else in the estate has it. It was
# built generic on purpose -- its only repo-specific state is the MD_ALLOW
# allowlist inside it, and it locates its own library via
# `dirname "${BASH_SOURCE[0]}"`, so it works unmodified wherever it lands, as
# long as its lib/ sits next to it. This script is the one place that copies
# it, so "port it to project X" is a command instead of a hand-carry that
# drifts the moment someone retypes it (BUILD-DISCIPLINE.md: "config read
# from one source, not retyped per file" applies to a rollout as much as to a
# hostname).
#
# WHAT IT DOES. Copies three files into <target-repo>/<dest>/, preserving the
# relative layout markdown-cost.sh and its test already assume:
#   <dest>/markdown-cost.sh
#   <dest>/lib/cli-guard.sh
#   <dest>/tests/markdown-cost.test.sh   (default) or <dest>/test-markdown-cost.sh
#                                         with --test-style flat
# Then, if the target has no .github/workflows/markdown-cost.yml yet, writes
# one that fetches origin/main and runs the guard on every pull request. If
# one already exists, it is left alone and this script says so -- CI wiring
# varies too much per repo to overwrite blindly.
#
# IT NEVER OVERWRITES A FILE THAT HAS DIVERGED. A target file that already
# exists and is byte-identical is a silent no-op (re-running this is safe).
# One that exists and DIFFERS is left untouched and reported -- pass --force
# to take the incoming version anyway. Silently clobbering a repo's local
# fork of the guard is worse than doing nothing.
#
# Usage:
#   port-markdown-cost.sh <target-repo-path> [--dest <dir>] [--test-style nested|flat] [--force]
#
#   port-markdown-cost.sh ../senechal --dest tools --test-style flat
set -uo pipefail

CLI_NAME='port-markdown-cost.sh'
CLI_SUMMARY='copy the markdown-cost ratchet (script + lib + test) into another repo'
CLI_USAGE='  port-markdown-cost.sh <target-repo> [--dest <dir>] [--test-style nested|flat] [--force]'
CLI_FLAGS='--dest --test-style --force'
CLI_EXITS='  0  every file was written or already matched -- and the CI note, if any, was printed
  1  a target file exists and differs, and --force was not given
  2  the source files could not be read, the target is not a directory, or an argument is invalid'
CLI_POSITIONAL=any
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

die2() { printf '%s: %s\n' "$CLI_NAME" "$*" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPT="$HERE/markdown-cost.sh"
SRC_LIB="$HERE/lib/cli-guard.sh"
SRC_TEST="$HERE/tests/markdown-cost.test.sh"
for f in "$SRC_SCRIPT" "$SRC_LIB" "$SRC_TEST"; do
  [ -r "$f" ] || die2 "source file missing or unreadable: $f"
done

TARGET=''
DEST='bin'
TEST_STYLE='nested'
FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) [ $# -ge 2 ] || die2 "--dest needs a value"; DEST="$2"; shift 2 ;;
    --test-style)
      [ $# -ge 2 ] || die2 "--test-style needs a value"
      case "$2" in nested|flat) ;; *) die2 "--test-style must be 'nested' or 'flat', got '$2'" ;; esac
      TEST_STYLE="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -*) die2 "unknown flag: $1" ;;
    *)
      [ -z "$TARGET" ] || die2 "takes one target-repo argument, got a second: $1"
      TARGET="$1"; shift ;;
  esac
done
[ -n "$TARGET" ] || die2 "missing target-repo argument"
[ -d "$TARGET" ] || die2 "not a directory: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"
[ -d "$TARGET/.git" ] || die2 "not a git repository (no .git): $TARGET"

DEST_SCRIPT="$TARGET/$DEST/markdown-cost.sh"
DEST_LIB="$TARGET/$DEST/lib/cli-guard.sh"
if [ "$TEST_STYLE" = flat ]; then
  DEST_TEST="$TARGET/$DEST/test-markdown-cost.sh"
else
  DEST_TEST="$TARGET/$DEST/tests/markdown-cost.test.sh"
fi

rc=0

# install <src> <dst> -- copy, refusing to clobber a diverged file without --force
install() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ]; then
    if cmp -s "$src" "$dst"; then
      printf '  ok      %s (already matches)\n' "$dst"
      return 0
    fi
    if [ "$FORCE" -ne 1 ]; then
      printf '  DIFFERS %s -- exists and differs from the source; rerun with --force to overwrite\n' "$dst"
      rc=1
      return 0
    fi
    printf '  FORCED  %s (overwriting a diverged copy)\n' "$dst"
  else
    printf '  wrote   %s\n' "$dst"
  fi
  cp "$src" "$dst"
  chmod --reference="$src" "$dst" 2>/dev/null || chmod +x "$dst"
}

# The flat test style expects markdown-cost.sh in the SAME directory as the
# test, not one level up (the nested style's `dirname "$0"/..`). Rewriting
# that one line here -- rather than shipping two near-duplicate test files in
# this repo -- keeps the test's assertions in exactly one place.
install_test() {
  if [ "$TEST_STYLE" = flat ]; then
    local tmp; tmp="$(mktemp)"
    sed 's#SCRIPT="\$(cd "\$(dirname "\$0")/\.\." && pwd)/markdown-cost\.sh"#SCRIPT="$(cd "$(dirname "$0")" \&\& pwd)/markdown-cost.sh"#' \
      "$SRC_TEST" > "$tmp"
    install "$tmp" "$DEST_TEST"
    rm -f "$tmp"
  else
    install "$SRC_TEST" "$DEST_TEST"
  fi
}

printf 'porting markdown-cost to %s (dest=%s, test-style=%s)\n' "$TARGET" "$DEST" "$TEST_STYLE"
install "$SRC_SCRIPT" "$DEST_SCRIPT"
install "$SRC_LIB" "$DEST_LIB"
install_test

WORKFLOW="$TARGET/.github/workflows/markdown-cost.yml"
if [ -e "$WORKFLOW" ]; then
  printf '  note    %s already exists -- left alone; wire the guard into it by hand:\n' "$WORKFLOW"
  printf '            bash %s/markdown-cost.sh\n' "$DEST"
else
  mkdir -p "$(dirname "$WORKFLOW")"
  cat > "$WORKFLOW" <<EOF
# markdown-cost.yml -- price the prose in every PR diff (ported from
# hf7y/realisateur bin/markdown-cost.sh via bin/port-markdown-cost.sh).
name: markdown-cost

on:
  pull_request:

jobs:
  markdown-cost:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # The default range is \$(git merge-base HEAD origin/main)..HEAD, so
      # origin/main has to actually exist as a remote-tracking ref. On a PR,
      # actions/checkout fetches the PR refs; main is not guaranteed among
      # them even at depth 0.
      - name: Make origin/main resolvable
        run: git fetch --no-tags origin +refs/heads/main:refs/remotes/origin/main

      - name: Price the prose in this diff
        run: bash $DEST/markdown-cost.sh
EOF
  printf '  wrote   %s\n' "$WORKFLOW"
fi

[ "$rc" -eq 0 ] && printf 'ok -- ported.\n'
exit "$rc"
