#!/usr/bin/env bash
# bin/shellcheck-lint.sh -- run shellcheck over this repository's own shell,
# and fail when a NEW class of finding appears in a file that did not have it.
#
# RUNNER: bin/tests/shellcheck-lint.test.sh
# GUARD-TEST: bin/tests/shellcheck-lint.test.sh
# GATE: default
#
# TRAPS (the rest of this header is in the vault):
# The first run found 423 findings. It also found that one of the tree's own
# suppressions was malformed and had therefore never suppressed anything --
# see .shellcheckrc's header. That is the argument for running the tool, made
# by the tool, on the first run.
# It never reports "I could not look" as "nothing is wrong". shellcheck
# missing from PATH is BLIND (exit 2), never success -- the recorded pathology
# is a propagation pass that reached zero projects and exited 0. Matching zero
# files is BLIND for the same reason: `bin/tests/*.sh matched nothing` was a
# real CI defect in this repository, and a lint that lints nothing is its twin.
# It never lowers the ratchet. `--accept` writes the CURRENT set, which is how
# a baseline is supposed to move, but a run that would REMOVE nothing and ADD
# entries still reports what it added, so accepting is a visible act rather
# than a quiet one.
#
# exit-0 no-op, the unguarded `cd`, the check that cannot see and says fine.
# usage:  shellcheck-lint.sh [--strict] [--accept] [--quiet]
# exit:   0 no new findings   1 REGRESSION (a new file/code pair)

set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
RATCHET="$ROOT/bin/shellcheck-lint.ratchet"

STRICT=0; ACCEPT=0; QUIET=0
for a in "$@"; do
  case "$a" in
    --strict) STRICT=1 ;;
    --accept) ACCEPT=1 ;;
    --quiet|-q) QUIET=1 ;;
    -h|--help)
      sed -n '/^# usage:/,/^set -uo/p' "$0" | sed 's/^# \{0,1\}//; $d'
      exit 0 ;;
    *) echo "shellcheck-lint.sh: unknown flag '$a'" >&2; exit 2 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

command -v shellcheck >/dev/null 2>&1 || {
  echo "BLIND: shellcheck is not on PATH -- this guard could not look." >&2
  echo "  install: apt-get install shellcheck, or drop the static binary from" >&2
  echo "  https://github.com/koalaman/shellcheck/releases onto PATH." >&2
  echo "  A guard that cannot probe does not get to report success." >&2
  exit 2
}

# WHICH FILES. Tracked-only, so an untracked scratch script in the working
# tree cannot turn the guard red, and a deleted one cannot keep it red.
# `*.sh` misses the extensionless executables in bin/ (the verbs), so those are
# selected by SHEBANG rather than by name -- reading the file is the only
# honest way to ask "is this shell".
#
# archive/ is excluded: it is retired code kept as evidence, and a guard that
# demands retired code be maintained is a guard that gets disabled.
cd "$ROOT" || { echo "BLIND: cannot cd to $ROOT" >&2; exit 2; }

mapfile -t FILES < <(
  {
    git ls-files '*.sh' 2>/dev/null
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      case "$(head -c 2 "$f" 2>/dev/null)" in
        '#!') head -1 "$f" | grep -qE '^#!.*(bash|sh)\b' && printf '%s\n' "$f" ;;
      esac
    done < <(git ls-files 'bin/*' 2>/dev/null | grep -v '\.ratchet$')
  } | grep -v '^archive/' | sort -u
)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "BLIND: matched zero shell files under $ROOT -- this run linted NOTHING." >&2
  echo "  A lint that lints nothing is not a clean tree; it is a broken glob." >&2
  exit 2
fi

# CURRENT set: "path<TAB>SCNNNN", one per distinct pair, sorted.
# The tool's own exit status is deliberately ignored here (it is non-zero
# whenever there is any finding at all, which is the normal state of a
# ratcheted tree); the FINDINGS are the signal, and an empty output with
# the linter present is a genuinely clean tree.
current="$(
  shellcheck -f gcc -S warning "${FILES[@]}" 2>/dev/null \
  | sed -nE 's|^([^:]+):[0-9]+:[0-9]+: [a-z]+: .* \[(SC[0-9]+)\]$|\1\t\2|p' \
  | sort -u
)"

baseline=""
[ -f "$RATCHET" ] && baseline="$(grep -v '^#' "$RATCHET" | grep -v '^[[:space:]]*$' | sort -u)"

# VERSION SKEW. A ratchet is a comparison, and comparing findings across two
# linter versions compares two different questions: releases add checks,
# retire them, and change wording. A baseline accepted under one version can
# therefore show phantom regressions under another, and the reader's first
# guess will be that their branch broke something.
#
# This was live on the day the guard was written. The baseline was accepted
# locally with 0.10.0 while .github/workflows/tests.yml's ubuntu-latest runner
# had 0.9.0 -- the run passed, but only because the two happened to agree on
# these 11 pairs. That is luck, and luck that reports green is the kind this
# repository keeps paying for.
#
# It WARNS rather than fails. Failing would break CI the moment GitHub bumps
# the runner image, which is a change nobody here made and cannot fix from this
# repo -- a guard that goes red for that is a guard that gets disabled. A
# genuine skew still surfaces, loudly, as the first thing said on the
# regression path.
SC_VERSION="$(shellcheck --version 2>/dev/null | awk '/^version:/{print $2}')"
SC_ACCEPTED=""
[ -f "$RATCHET" ] && SC_ACCEPTED="$(awk '/^# shellcheck-version /{print $3}' "$RATCHET")"
SC_SKEW=0
if [ -n "$SC_ACCEPTED" ] && [ -n "$SC_VERSION" ] && [ "$SC_ACCEPTED" != "$SC_VERSION" ]; then
  SC_SKEW=1
fi

new="$(comm -23 <(printf '%s\n' "$current" | grep -v '^$' | sort -u) \
                <(printf '%s\n' "$baseline" | grep -v '^$' | sort -u))"
gone="$(comm -13 <(printf '%s\n' "$current" | grep -v '^$' | sort -u) \
                 <(printf '%s\n' "$baseline" | grep -v '^$' | sort -u))"

n_cur=$(printf '%s\n' "$current" | grep -c . || true)
n_new=$(printf '%s\n' "$new" | grep -c . || true)
n_gone=$(printf '%s\n' "$gone" | grep -c . || true)

say "shellcheck-lint: ${#FILES[@]} tracked shell files, $n_cur baselined finding(s)."
if [ "$SC_SKEW" -eq 1 ]; then
  say "  note: running shellcheck $SC_VERSION; ratchet was accepted with $SC_ACCEPTED."
fi

if [ "$n_gone" -gt 0 ]; then
  say ""
  say "FIXED since the ratchet was accepted ($n_gone) -- run --accept to lock these in:"
  printf '%s\n' "$gone" | grep . | sed 's/^/  - /' | { [ "$QUIET" -eq 1 ] && cat >/dev/null || cat; }
fi

if [ "$ACCEPT" -eq 1 ]; then
  {
    echo "# shellcheck-lint.ratchet -- (file, code) pairs present when accepted."
    echo "# Raised or lowered ONLY by --accept, and --accept always reports what it"
    echo "# changed. See bin/shellcheck-lint.sh for why the pair, not a count."
    echo "# accepted $(date -Is)"
    echo "# shellcheck-version ${SC_VERSION:-unknown}"
    printf '%s\n' "$current" | grep . || true
  } > "$RATCHET"
  say ""
  say "ACCEPTED: $RATCHET now records $n_cur pair(s) (+$n_new new, -$n_gone fixed)."
  exit 0
fi

if [ "$n_new" -gt 0 ]; then
  echo ""
  if [ "$SC_SKEW" -eq 1 ]; then
    echo "READ THIS FIRST: shellcheck $SC_VERSION is running, but the ratchet was" >&2
    echo "accepted with $SC_ACCEPTED. Findings below may be that difference rather" >&2
    echo "than anything your branch did. Check against $SC_ACCEPTED before fixing." >&2
    echo "" >&2
  fi
  echo "REGRESSION: $n_new shellcheck finding(s) in files that did not have them." >&2
  printf '%s\n' "$new" | grep . | sed 's/^/  + /' >&2
  echo "" >&2
  # The advice below deliberately does NOT spell the directive literally.
  # Writing `# shell<no space>check disable=SCNNNN` in this file would BE a
  # directive as far as shellcheck is concerned, with an invalid code -- which
  # is SC1072/SC1073, the exact defect this guard exists to catch. It was
  # written that way in the first draft and caught by this guard's own test
  # suite (case A), which is the most useful thing that happened all evening.
  echo "Fix them, or -- if the finding is deliberate and you can say why in the" >&2
  echo "code -- add an inline shellcheck disable directive naming the code, with" >&2
  echo "the reason beside it, and re-run. '--accept' is for a baseline move you" >&2
  echo "intend, not for a red run." >&2
  exit 1
fi

say "no new findings."

if [ "$STRICT" -eq 1 ] && [ "$n_cur" -gt 0 ]; then
  say ""
  say "--strict: $n_cur finding(s) still baselined. The tree is not clean, it is"
  say "held. bin/shellcheck-lint.ratchet lists every one."
  exit 3
fi
exit 0
