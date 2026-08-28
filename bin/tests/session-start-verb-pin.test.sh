#!/usr/bin/env bash
set -uo pipefail  # bin/tests/session-start-verb-pin.test.sh: witness for hooks/session-start-verb-pin.sh (#708)
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/../hooks/session-start-verb-pin.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp

payload() { printf '{"cwd":"%s"}' "$1"; }
run() { payload "$1" | VERB_BUILD_ROOT="$2" "$SCRIPT" 2>&1; }

newbare() { # newbare <path> -- bare git-dir nested at <path>/.git, same layout install-verb-build.sh's REPO uses (clone --bare into $REPO/.git, core.bare=false)
  git init -q --bare "$1/.git"
}
tagbuild() { # tagbuild <build-root>/repo <build-id> -- pushes one empty-commit tag, via a throwaway clone
  local repo="$1" id="$2" c
  c="$(mktemp -d)"
  git clone -q "$repo/.git" "$c" 2>/dev/null
  git -C "$c" config user.email t@test
  git -C "$c" config user.name T
  git -C "$c" checkout -q -B main
  git -C "$c" commit -q --allow-empty -m "$id"
  git -C "$c" tag "build/$id"
  git -C "$c" push -q origin "build/$id"
  rm -rf "$c"
}

mkbuildroot() { # mkbuildroot <root> <pinned-id> -- current -> pinned-id, bare repo/ with no tags yet
  local root="$1" id="$2"
  mkdir -p "$root/$id/realisateur/bin"
  ln -sfn "$id" "$root/current"
  newbare "$root/repo"
}

section "A. no build root at all"
A_OUT="$(run "$T/proj-a" "$T/no-such-root")"; A_RC=$?
rc  "A1 no build root -> exit 0" 0 "$A_RC"
eq  "A2 no build root -> no output" "$A_OUT" ""

section "B. build root exists but current is not pinned"
mkdir -p "$T/broot-b"
newbare "$T/broot-b/repo"
B_OUT="$(run "$T/proj-b" "$T/broot-b")"; B_RC=$?
rc "B1 unpinned build root -> exit 0" 0 "$B_RC"
eq "B2 unpinned build root -> no output" "$B_OUT" ""

section "C. pinned, nothing newer, no carried checkout -- boring, silent"
mkbuildroot "$T/broot-c" "2026-08-27T114014Z"
C_OUT="$(run "$T/nope" "$T/broot-c")"; C_RC=$?
rc "C1 boring pin -> exit 0" 0 "$C_RC"
eq "C2 boring pin -> no output (silent when boring)" "$C_OUT" ""

section "D. a newer build is cached (already fetched, never fetched by this hook)"
mkbuildroot "$T/broot-d" "2026-08-27T114014Z"
tagbuild "$T/broot-d/repo" "2026-08-27T114014Z"
tagbuild "$T/broot-d/repo" "2026-08-28T090000Z"
D_OUT="$(run "$T/nope" "$T/broot-d")"; D_RC=$?
rc  "D1 newer cached build -> exit 0 (context, not a gate)" 0 "$D_RC"
has "D2 names the pinned build" "$D_OUT" "2026-08-27T114014Z"
has "D3 flags NEWER with the cached id" "$D_OUT" "NEWER"
has "D3 and names it" "$D_OUT" "2026-08-28T090000Z"

section "E. a build matching the latest cached tag is NOT reported as newer"
mkbuildroot "$T/broot-e" "2026-08-28T090000Z"
tagbuild "$T/broot-e/repo" "2026-08-28T090000Z"
E_OUT="$(run "$T/nope" "$T/broot-e")"
hasnt "E1 on the latest tag already -> no NEWER finding" "$E_OUT" "NEWER"

section "F. checkout diverges from the pinned build (the #653 shape)"
mkbuildroot "$T/broot-f" "2026-08-27T114014Z"
mkdir -p "$T/proj-f/bin/lib"
printf 'bin/gh\tbin/gh-sign.sh\n' > "$T/proj-f/bin/lib/carries.tsv"
echo 'old' > "$T/proj-f/bin/gh-sign.sh"
echo 'old' > "$T/broot-f/2026-08-27T114014Z/realisateur/bin/gh"
F1_OUT="$(run "$T/proj-f" "$T/broot-f")"
hasnt "F1 identical carried content -> no DIVERGES" "$F1_OUT" "DIVERGES"

echo 'new, ahead of the pinned build' > "$T/proj-f/bin/gh-sign.sh"
F2_OUT="$(run "$T/proj-f" "$T/broot-f")"; F2_RC=$?
rc  "F2 diverging checkout -> still exit 0 (context, not a gate)" 0 "$F2_RC"
has "F2 names the pinned build" "$F2_OUT" "2026-08-27T114014Z"
has "F2 flags DIVERGES" "$F2_OUT" "DIVERGES"

section "G. a carried source missing from the pinned build side is also a divergence"
mkbuildroot "$T/broot-g" "2026-08-27T114014Z"
mkdir -p "$T/proj-g/bin/lib"
printf 'bin/gh\tbin/gh-sign.sh\n' > "$T/proj-g/bin/lib/carries.tsv"
echo 'anything' > "$T/proj-g/bin/gh-sign.sh"
G_OUT="$(run "$T/proj-g" "$T/broot-g")"   # deliberately no bin/gh written under the pinned build side
has "G1 pinned build missing the carried file -> DIVERGES" "$G_OUT" "DIVERGES"

section "H. a non-realisateur checkout (no carries.tsv) is never graded for divergence"
mkbuildroot "$T/broot-h" "2026-08-27T114014Z"
mkdir -p "$T/proj-h/bin"
H_OUT="$(run "$T/proj-h" "$T/broot-h")"
hasnt "H1 no carries.tsv -> never claims DIVERGES" "$H_OUT" "DIVERGES"
eq    "H2 and stays silent (nothing else to report)" "$H_OUT" ""

summary
