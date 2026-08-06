#!/usr/bin/env bash
# hygiene-lint.test.sh -- witness for bin/hygiene-lint.sh's --strict exit-code
# plumbing. Offline, zero AI, no network.
#
# hygiene-lint.sh always reads the REAL scheduler registry for its per-
# project checks (1-9), which this file redirects via SCHED_ROOT so a
# fixture project is the only one scanned. But three of its OWN checks (10
# install-shims drift, 11 reach-lint, 12 silence-audit) shell out to sibling
# scripts that read real, live machine/ecosystem state regardless of any
# project filter -- so a bare invocation against this machine can never be
# guaranteed clean (this repo's own reach-lint currently reports real
# scope-undeclared FLAGs from OTHER registered projects, for instance). To
# get a deterministic clean case, this file points SHIM_INSTALLER/REACH_LINT/
# SILENCE_AUDIT at throwaway stub scripts that always report clean, isolating
# the thing actually under test: does --strict gate on $total_flags correctly?
#
# Cases:
#   A clean project (one tracked, unremarkable file) -> 0 FLAGs
#       -> --strict exits 0
#   B dirty project (a tracked file literally named id_rsa -> FLAG
#     [secret-file], check 1) -> >=1 FLAG
#       -> --strict exits 1
#       -> bare invocation (no --strict) still exits 0 -- FLAGs are signals
#          by default, never a build failure, unless the caller opted in
#   D check 8c, self-dev branch discipline (Zach's Decision 3, 2026-08-06):
#     D1 off-convention branch name; D2 ON the convention branch and still
#     unpushed (the vim-arcade case -- scheduler#38's read-only deploy key);
#     D3 no upstream at all; D4 SELFDEV_BRANCH retargets the convention
#     ecosystem-wide from one place rather than per project.
#
# Usage: bin/tests/hygiene-lint.test.sh   (exit 0 = all pass)
set -uo pipefail
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/hygiene-lint.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 (unexpected: $3)" ;; *) ok "$1" ;; esac; }
rc()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }

# --- always-clean stubs for the three sibling-tool checks (10, 11, 12) ------
mkdir -p "$T/stubs"
for stub in install-shims.sh reach-lint.sh silence-audit.sh; do
  cat > "$T/stubs/$stub" <<'EOF'
#!/usr/bin/env bash
echo "stub -- clean (audited 0 mechanism(s); 0 FLAG(s))"
exit 0
EOF
  chmod +x "$T/stubs/$stub"
done

# run <project...> -- args after the project name(s) may include --strict;
# sets RUN_OUT / RUN_RC. Always points the three sibling-tool checks at the
# clean stubs above, and the registry at $T/sched (built by the caller).
run() {
  RUN_OUT="$(SCHED_ROOT="$T/sched" \
    SHIM_INSTALLER="$T/stubs/install-shims.sh" \
    REACH_LINT="$T/stubs/reach-lint.sh" \
    SILENCE_AUDIT="$T/stubs/silence-audit.sh" \
    "$SCRIPT" "$@" 2>&1)"
  RUN_RC=$?
}

mkreg() { # mkreg <name> <path>
  mkdir -p "$T/sched/schedule"
  printf 'PROJECT_REPO_PATH="%s"\n' "$2" > "$T/sched/schedule/$1.conf"
}

newgitrepo() { # newgitrepo <path> [branch] -- git repo on `main` with a
  # pushed upstream. Check 8c (self-dev branch discipline) FLAGs a repo that
  # is off-convention, detached, upstream-less, or ahead of its upstream --
  # so "clean" now means a real remote exists and HEAD is level with it. A
  # bare repo beside it is enough; nothing here touches the network.
  local br="${2:-main}"
  mkdir -p "$1"
  git init -q -b "$br" "$1"
  git -C "$1" config user.email t@test
  git -C "$1" config user.name T
  git init -q --bare "$1.origin.git"
  git -C "$1" remote add origin "$1.origin.git"
}

pushupstream() { # pushupstream <path> -- publish the current branch, level
  git -C "$1" push -q -u origin HEAD 2>/dev/null
}

echo "hygiene-lint.test.sh"

echo "-- A. clean project"
newgitrepo "$T/cleanproj"
echo "hello" > "$T/cleanproj/README.md"
git -C "$T/cleanproj" add -A
git -C "$T/cleanproj" commit -qm init
pushupstream "$T/cleanproj"
mkreg cleanproj "$T/cleanproj"

run cleanproj
hasnt "A default run has no FLAG"            "$RUN_OUT" "FLAG ["
has   "A default run reports 0 total FLAGs"  "$RUN_OUT" "== 0 total FLAG(s)"
run cleanproj --strict
rc    "A --strict exits 0 on a clean scan"   0 "$RUN_RC"

echo "-- B. dirty project (tracked id_rsa -> FLAG [secret-file])"
newgitrepo "$T/dirtyproj"
echo "hello" > "$T/dirtyproj/README.md"
printf 'not a real key, just a fixture\n' > "$T/dirtyproj/id_rsa"
git -C "$T/dirtyproj" add -A
git -C "$T/dirtyproj" commit -qm init
pushupstream "$T/dirtyproj"
mkreg dirtyproj "$T/dirtyproj"

run dirtyproj
has "B default run FLAGs the tracked id_rsa"    "$RUN_OUT" "FLAG [secret-file] tracked: id_rsa"
run dirtyproj --strict
rc  "B --strict exits nonzero when a FLAG was printed" 1 "$RUN_RC"
run dirtyproj
rc  "B bare invocation (no --strict) still exits 0"    0 "$RUN_RC"
has "B the FLAG is still printed (signal, not silence)" "$RUN_OUT" "FLAG [secret-file]"

echo "-- C. --strict combined with a project-name filter (arg order)"
run --strict cleanproj
rc  "C --strict before the project name still parses" 0 "$RUN_RC"
run --strict dirtyproj
rc  "C --strict before a dirty project name exits 1"   1 "$RUN_RC"

echo "-- D. self-dev branch discipline (check 8c)"
# D1 off-convention branch name. Zach's Decision 3: one consistently named
# branch for all self-dev, `main` today.
newgitrepo "$T/branchproj" feature/side-quest
echo hi > "$T/branchproj/README.md"
git -C "$T/branchproj" add -A
git -C "$T/branchproj" commit -qm init
pushupstream "$T/branchproj"
mkreg branchproj "$T/branchproj"
run branchproj
has "D1 FLAGs a project not on the convention branch" "$RUN_OUT" \
    "FLAG [branch] checked out on 'feature/side-quest'"

# D2 the vim-arcade case: ON main, and still not converging. A read-only
# deploy key (scheduler#38) makes every local commit permanently unpushed,
# which the branch NAME check cannot see.
newgitrepo "$T/aheadproj"
echo hi > "$T/aheadproj/README.md"
git -C "$T/aheadproj" add -A
git -C "$T/aheadproj" commit -qm init
pushupstream "$T/aheadproj"
echo more >> "$T/aheadproj/README.md"
git -C "$T/aheadproj" commit -qam second
mkreg aheadproj "$T/aheadproj"
run aheadproj
hasnt "D2 does NOT flag the branch name (it is on main)" "$RUN_OUT" "FLAG [branch] checked out"
has   "D2 FLAGs the unpushed commit instead"             "$RUN_OUT" "FLAG [branch-unpushed] 1 commit(s) ahead"

# D3 no remote at all -- Zach 2026-08-06: projects "often with no git
# remotes", which he calls malformed. Commits have nowhere to land.
newgitrepo "$T/noremoteproj"
git -C "$T/noremoteproj" remote remove origin
echo hi > "$T/noremoteproj/README.md"
git -C "$T/noremoteproj" add -A
git -C "$T/noremoteproj" commit -qm init
mkreg noremoteproj "$T/noremoteproj"
run noremoteproj
has "D3 FLAGs a self-dev checkout with no upstream" "$RUN_OUT" "FLAG [branch-noremote]"

# D4 SELFDEV_BRANCH retargets the convention ecosystem-wide, from one place.
RUN_OUT="$(SELFDEV_BRANCH=feature/side-quest SCHED_ROOT="$T/sched" \
  SHIM_INSTALLER="$T/stubs/install-shims.sh" REACH_LINT="$T/stubs/reach-lint.sh" \
  SILENCE_AUDIT="$T/stubs/silence-audit.sh" "$SCRIPT" branchproj 2>&1)"
hasnt "D4 SELFDEV_BRANCH=feature/side-quest clears D1's flag" "$RUN_OUT" "FLAG [branch] checked out"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
