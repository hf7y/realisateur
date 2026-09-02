#!/usr/bin/env bash
# HERMETICITY: HOME, STAMP_HOOK_DIR and INSTALLE_PROJECTS are all a throwaway
# tree under $T -- no case touches this account's real ~/.gitconfig or real
# $HOME/Documents/Projects. Witness for bin/guard-readonly-clone.sh
# (hf7y/scheduler#321): A --check on a fresh account -> gap, exit 1. B
# --apply installs the hook and claims core.hooksPath. C a commit inside
# $PROJECTS/<not this account> is refused. D a commit inside
# $PROJECTS/<this account> succeeds. E a commit OUTSIDE $PROJECTS entirely
# (the cross-repo draft-PR path, CLAUDE.md rule 6) succeeds. F re-running
# --apply is idempotent. G --retire removes the hook but leaves
# core.hooksPath (a sibling hook may still need it). H a hooksPath already
# owned by something else is refused, untouched.
set -uo pipefail
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/guard-readonly-clone.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
rc()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }

mkfixture() {  # <root-tag> -> sets HOME/HOOKS/PROJECTS for that fixture
  local tag="$1"
  mkdir -p "$T/$tag/home" "$T/$tag/hooks" "$T/$tag/projects"
}
# `id -un` is an external command, not fakeable with a shell function, so
# every case here drives account identity as the REAL account this suite
# runs under -- "this account's own project" is $REAL_ME, and "not this
# account" is a name that can never match it.
REAL_ME="$(id -un)"
NOTME="not-$REAL_ME-$$"

run2() {  # <tag> <args...> -- runs as the REAL account (id -un unfaked)
  local tag="$1"; shift
  HOME="$T/$tag/home" STAMP_HOOK_DIR="$T/$tag/hooks" INSTALLE_PROJECTS="$T/$tag/projects" \
    "$SCRIPT" "$@" 2>&1
}

mkgit() {  # <dir>
  git init -q "$1"
  git -C "$1" config user.email t@example.com
  git -C "$1" config user.name t
}
try_commit() {  # <dir> <hooks-dir> -> exit code of the commit
  printf 'x\n' > "$1/f"
  git -C "$1" add f
  ( cd "$1" && git -c core.hooksPath="$2" commit -q -m x ) >/dev/null 2>&1
}

# --- A. --check on a fresh account -> gap, exit 1 ---------------------------
mkfixture a
out="$(run2 a --check)"; got=$?
rc "A: --check on an unguarded account exits 1" 1 "$got"
case "$out" in *"not guarded"*) ok "A: reports not guarded" ;; *) bad "A: does not say 'not guarded': $out" ;; esac

# --- B. --apply installs the hook and claims core.hooksPath -----------------
mkfixture b
out="$(run2 b --apply)"; got=$?
rc "B: --apply exits 0" 0 "$got"
[ -x "$T/b/hooks/pre-commit" ] && ok "B: pre-commit hook installed and executable" \
                                || bad "B: no executable hook at $T/b/hooks/pre-commit"
cur="$(HOME="$T/b/home" git config --global core.hooksPath 2>/dev/null)"
[ "$cur" = "$T/b/hooks" ] && ok "B: core.hooksPath points at the hook dir" \
                            || bad "B: core.hooksPath is '$cur', not $T/b/hooks"

# --- C. a commit inside \$PROJECTS/<not this account> is refused ------------
mkfixture c
run2 c --apply >/dev/null
mkgit "$T/c/projects/$NOTME"
if try_commit "$T/c/projects/$NOTME" "$T/c/hooks"; then
  bad "C: commit SUCCEEDED inside \$PROJECTS/<not this account>"
else
  ok "C: commit refused inside \$PROJECTS/<not this account>"
fi
[ "$(git -C "$T/c/projects/$NOTME" log --oneline 2>/dev/null | wc -l)" -eq 0 ] \
  && ok "C: no commit landed" || bad "C: a commit landed despite the refusal"

# --- D. a commit inside \$PROJECTS/<this account> succeeds ------------------
mkfixture d
run2 d --apply >/dev/null
mkgit "$T/d/projects/$REAL_ME"
if try_commit "$T/d/projects/$REAL_ME" "$T/d/hooks"; then
  ok "D: commit succeeded inside \$PROJECTS/<this account's own project>"
else
  bad "D: commit was refused inside this account's OWN project"
fi

# --- E. a commit OUTSIDE \$PROJECTS entirely succeeds (cross-repo draft-PR) -
mkfixture e
run2 e --apply >/dev/null
mkgit "$T/e/scratch-clone"
if try_commit "$T/e/scratch-clone" "$T/e/hooks"; then
  ok "E: commit succeeded outside \$PROJECTS (sanctioned cross-repo work stays possible)"
else
  bad "E: commit was refused OUTSIDE \$PROJECTS -- this would block CLAUDE.md rule 6 work"
fi

# --- F. re-running --apply is idempotent ------------------------------------
out="$(run2 e --apply)"; got=$?
rc "F: a second --apply exits 0" 0 "$got"
cur2="$(HOME="$T/e/home" git config --global core.hooksPath 2>/dev/null)"
[ "$cur2" = "$T/e/hooks" ] && ok "F: core.hooksPath unchanged on re-apply" \
                             || bad "F: core.hooksPath drifted to '$cur2'"

# --- G. --retire removes the hook, leaves core.hooksPath --------------------
run2 e --retire --apply >/dev/null
[ ! -e "$T/e/hooks/pre-commit" ] && ok "G: --retire removed the hook file" \
                                   || bad "G: hook file survived --retire"
cur3="$(HOME="$T/e/home" git config --global core.hooksPath 2>/dev/null)"
[ "$cur3" = "$T/e/hooks" ] && ok "G: --retire left core.hooksPath alone (a sibling hook may need it)" \
                             || bad "G: --retire touched core.hooksPath ('$cur3')"

# --- H. hooksPath already owned by something else is refused, untouched ----
mkfixture h
HOME="$T/h/home" git config --global core.hooksPath "$T/h/someone-elses-dir" 2>/dev/null
out="$(run2 h --apply)"; got=$?
rc "H: refuses when core.hooksPath is owned elsewhere" 1 "$got"
case "$out" in *"does not own"*) ok "H: names the conflict" ;; *) bad "H: no ownership-conflict message: $out" ;; esac
cur4="$(HOME="$T/h/home" git config --global core.hooksPath 2>/dev/null)"
[ "$cur4" = "$T/h/someone-elses-dir" ] && ok "H: core.hooksPath left untouched" \
                                         || bad "H: core.hooksPath was overwritten to '$cur4'"

echo "guard-readonly-clone: $pass ok, $fail failed"
[ "$fail" -eq 0 ]
