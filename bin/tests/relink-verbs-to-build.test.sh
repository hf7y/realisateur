#!/usr/bin/env bash
# HERMETICITY: it builds a complete fake world under one `mktemp -d` -- a
# build root with a `current` symlink and a manifest, a ~/.local/bin, a fake
# dev-clone tree -- and points the script at all three with BUILD_ROOT, BIN
# and INSTALLE_PROJECTS. It never reads the real ~/.local/bin, the real verb
# builds, or any account. No network, no crontab, no ssh.
#
# ABOUT THE STUB INSTALLE, because it is the one thing here that could test
# itself instead of the script. The build's `installe` is not available in CI
# (it lives in hf7y/verbs, a different repository), so the fixture build
# carries a stub. The stub implements exactly the two behaviours this script
# depends on and NOTHING else: it refuses an unowned name without --force
# (with the real refusal message, copied verbatim from senechal's
# bin/installe:145), and it refuses a REGULAR FILE even with --force. What is
# under test is not the stub -- it is which verbs relink-verbs-to-build.sh
# chooses to hand --force to, and that decision is made entirely in this
# repository before installe is ever invoked. The last section asserts the
# stub was actually exercised, so a stub that silently stopped refusing could
# not make this suite green.
#
# relink-verbs-to-build.test.sh -- the migration must be able to migrate.
#
# ============================================================================
# THE FAILURE, MEASURED ON ecosim@monkey 2026-08-07
# ============================================================================
#
#   19 of 33 verbs relinked. 14 FAILED.
#
#     installe: REFUSED: arpente is already on the path at ~/.local/bin/arpente
#     and installe did not put it there ... --force overwrites it
#
# The 14 were exactly the verbs that already had a clone-backed shim -- which
# is the population the script's own header says it exists to move ("move every
# ~/.local/bin verb off a bashified WORKTREE of a dev clone"). It could only
# link names that had never been installed, so every account provisioned the
# old way was stuck at ~58% consumption, and the script reported that as a
# failure it had no route past.
#
# It had no suite at all, which is why it shipped able to do the opposite of
# its stated job.
#
# THE ASSERTIONS SPLIT IN TWO, and the second half matters more than the first:
#   - it CAN adopt the stale shims (the defect), and
#   - it STILL REFUSES everything the rule does not cover (the guard). A fix
#     that passed --force unconditionally would pass every case in the first
#     half and fail every case in the second, which is the whole reason the
#     second half is here.
#
# Usage: bin/tests/relink-verbs-to-build.test.sh   (exit 0 = all pass)
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
S="$REPO/bin/relink-verbs-to-build.sh"
[ -x "$S" ] || { echo "FAIL: $S not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
has()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1 (unexpectedly present: $3)" ;; *) ok "$1" ;; esac; }
rc()    { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }

BR="$T/verb-builds"; BUILD="$BR/2026-08-07T040739Z"
BIN="$T/bin"; PROJ="$T/Projects"
mkdir -p "$BUILD/senechal/bin" "$BUILD/realisateur/bin" "$BUILD/scheduler/bin" "$BIN" "$PROJ"

# --- the build ---------------------------------------------------------------
for pv in "realisateur arpente" "realisateur epluche" "scheduler arme" \
          "scheduler rapporte" "senechal installe" "senechal debarrasse"; do
  set -- $pv
  printf '#!/bin/sh\necho "%s from the build"\n' "$2" > "$BUILD/$1/bin/$2"
  chmod +x "$BUILD/$1/bin/$2"
done
{
  printf '# project\tverb\tsha\n'
  printf 'realisateur\tarpente\tdeadbee\n'
  printf 'realisateur\tepluche\tdeadbee\n'
  printf 'scheduler\tarme\tcafe123\n'
  printf 'scheduler\trapporte\tcafe123\n'
  printf 'senechal\tinstalle\tf00d999\n'
  printf 'senechal\tdebarrasse\tf00d999\n'
} > "$BUILD/manifest.tsv"
ln -sfn "$BUILD" "$BR/current"

# --- the stub installe -------------------------------------------------------
# The refusal text is senechal bin/installe:145, verbatim. The regular-file
# refusal is bin/installe:165, verbatim. It keeps a manifest so "installe did
# not put it there" means the same thing it means in the real one.
cat > "$BUILD/senechal/bin/installe" <<'STUB'
#!/usr/bin/env bash
# stub installe -- verb-builds aware (relink greps this file for that word).
set -uo pipefail
BIN="${INSTALLE_BIN:?}"; MAN="${INSTALLE_MANIFEST:?}"; ROOT="${STUB_BUILD_ROOT:?}"
FORCE=0; ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -f|--force) FORCE=1 ;;
    --quiet|-q) ;;
    verb) ARGS+=(verb) ;;
    -*) echo "stub installe: unknown flag: $1" >&2; exit 2 ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
[ "${ARGS[0]:-}" = verb ] || { echo "stub installe: only 'verb' is implemented" >&2; exit 2; }
project="${ARGS[1]:?}"; name="${ARGS[2]:?}"
target="$ROOT/current/$project/bin/$name"
dest="$BIN/$name"
touch "$MAN"
owned="$(awk -F'\t' -v n="$name" '$1==n{print $2}' "$MAN")"
if [ -e "$dest" ] || [ -L "$dest" ]; then
  if [ -z "$owned" ] && [ "$FORCE" != 1 ]; then
    echo "installe: REFUSED: $name is already on the path at $dest and installe did not put it there. \`installe audit\` says what it is; --force overwrites it." >&2
    exit 7
  fi
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "installe: REFUSED: $name at $dest is a regular file, not a symlink. --force re-points a name; it does not delete a file somebody wrote. Move it aside yourself if you mean to." >&2
    exit 7
  fi
  rm -f -- "$dest"
fi
ln -s -- "$target" "$dest"
grep -v -P "^$name\t" "$MAN" > "$MAN.new" 2>/dev/null || : > "$MAN.new"
printf '%s\t%s\n' "$name" "$target" >> "$MAN.new"
mv "$MAN.new" "$MAN"
echo "stub installe: linked $name" >&2
STUB
chmod +x "$BUILD/senechal/bin/installe"

MAN="$T/installe-manifest.tsv"; : > "$MAN"
run() {
  env BUILD_ROOT="$BR" BIN="$BIN" INSTALLE_PROJECTS="$PROJ" \
      INSTALLE_BIN="$BIN" INSTALLE_MANIFEST="$MAN" STUB_BUILD_ROOT="$BR" \
      bash "$S" "$@" 2>&1
}
tgt() { readlink "$BIN/$1" 2>/dev/null || echo '<none>'; }

# --- the starting world, one verb per case the rule has to decide -----------
reset_world() {
  rm -rf "$BIN"; mkdir -p "$BIN"; : > "$MAN"
  # (a) nothing there at all -> `free`, links with no --force
  # (b) a bashified worktree of a dev clone -> ADOPT. THE 14.
  mkdir -p "$PROJ/realisateur/.worktrees/bashified/bin"
  printf '#!/bin/sh\necho stale\n' > "$PROJ/realisateur/.worktrees/bashified/bin/arpente"
  chmod +x "$PROJ/realisateur/.worktrees/bashified/bin/arpente"
  ln -sfn "$PROJ/realisateur/.worktrees/bashified/bin/arpente" "$BIN/arpente"
  # (c) pinned to a SUPERSEDED build -> ADOPT
  mkdir -p "$BR/2026-08-05T040843Z/scheduler/bin"
  printf '#!/bin/sh\necho old\n' > "$BR/2026-08-05T040843Z/scheduler/bin/arme"
  chmod +x "$BR/2026-08-05T040843Z/scheduler/bin/arme"
  ln -sfn "$BR/2026-08-05T040843Z/scheduler/bin/arme" "$BIN/arme"
  # (d) a DANGLING shim -> ADOPT
  ln -sfn "$PROJ/deleted-project/bin/rapporte" "$BIN/rapporte"
  # (e) a symlink to somewhere this script does not retire -> REFUSE
  printf '#!/bin/sh\necho vendored\n' > "$T/vendored-installe"; chmod +x "$T/vendored-installe"
  ln -sfn "$T/vendored-installe" "$BIN/installe"
  # (f) a REGULAR FILE somebody wrote -> REFUSE, never adopted
  printf '#!/bin/sh\necho "hand-written, not a link"\n' > "$BIN/debarrasse"
  chmod +x "$BIN/debarrasse"
}

echo "relink-verbs-to-build.test.sh"

# ===========================================================================
echo
echo "-- THE DEFECT: IT COULD NOT MOVE THE VERBS IT EXISTS TO MOVE -----------"
# ===========================================================================
# Without --adopt-existing (the behaviour as it shipped) the three stale shims
# cannot be moved. That is correct now only because it is SAID OUT LOUD and
# routed somewhere: before this change it was 14 bare FAILs with no next step.
reset_world
O="$(run --apply)"; R=$?
rc  "a run that cannot adopt still exits non-zero" 1 "$R"
has "the dev-clone shim is named as needing adoption"  "$O" "NEEDS-ADOPT arpente"
has "the superseded-build shim too"                    "$O" "NEEDS-ADOPT arme"
has "the dangling shim too"                            "$O" "NEEDS-ADOPT rapporte"
has "it names the flag that would move them"           "$O" "--adopt-existing"
has "it summarises how many are stuck"                 "$O" "verb(s) need --adopt-existing"
hasnt "it does not report them as an opaque installe refusal" "$O" "installe did not put it there"
# The free name still links with no force at all, as it always did.
has "a name nothing owns is still linked normally" "$O" "MOVED  epluche"
[ "$(tgt epluche)" = "$BR/current/realisateur/bin/epluche" ] \
  && ok "...and it resolves into the build" || bad "...and it resolves into the build"
# Nothing was overwritten.
[ "$(tgt arpente)" = "$PROJ/realisateur/.worktrees/bashified/bin/arpente" ] \
  && ok "the stale shim is UNTOUCHED without the opt-in" \
  || bad "the stale shim was overwritten without --adopt-existing"

# ===========================================================================
echo
echo "-- THE FIX: --adopt-existing MOVES EXACTLY THE THREE STALE CHANNELS ----"
# ===========================================================================
reset_world
O="$(run --apply --adopt-existing)"; R=$?
has "a dev clone / bashified worktree is adopted"      "$O" "ADOPT  arpente"
has "...and the reason names the dev-clone root"       "$O" "dev clone or bashified worktree"
has "a shim pinned to a superseded build is adopted"   "$O" "ADOPT  arme"
has "...and the reason says so"                        "$O" "superseded build"
has "a dangling shim is adopted"                       "$O" "ADOPT  rapporte"
has "...and the reason says its target is gone"        "$O" "DANGLING"
has "the run announces that it will re-point"          "$O" "will be RE-POINTED"
has "adoptions are counted separately from plain links" "$O" "by adoption"

# The witness: the link itself, re-read, not the exit code. A build where
# `-f && -x` passed and nothing could run is why this script re-reads at all.
for v in arpente:realisateur arme:scheduler rapporte:scheduler epluche:realisateur; do
  n="${v%%:*}"; p="${v##*:}"
  # Through `current`, not through the dated directory: that is what the real
  # installe writes, and it is what makes the next build switch atomic.
  [ "$(tgt "$n")" = "$BR/current/$p/bin/$n" ] \
    && ok "$n now resolves into the build (re-read from the link)" \
    || bad "$n resolves to $(tgt "$n"), not $BR/current/$p/bin/$n"
done

# ===========================================================================
echo
echo "-- THE GUARD: --adopt-existing IS NOT A BLANKET --force ----------------"
# ===========================================================================
# Every assertion here FAILS if the fix were `always pass --force`. That is
# the point of this section: installe's refusal protects files it did not
# install, and adopting a name is not permission to delete one.
rc  "a run with unadoptable names still exits non-zero" 1 "$R"

has "a REGULAR FILE is refused, not adopted"        "$O" "REFUSE debarrasse"
has "...and the refusal says why a file is different from a link" "$O" "regular file, not a symlink"
hasnt "a regular file is never handed to --force"   "$O" "ADOPT  debarrasse"
if [ -f "$BIN/debarrasse" ] && [ ! -L "$BIN/debarrasse" ]; then
  ok "the hand-written file is still there, byte for byte"
  has "...with its contents intact" "$(cat "$BIN/debarrasse")" "hand-written, not a link"
else
  bad "the hand-written file was destroyed"
  bad "...with its contents intact"
fi

has "a symlink to an unrelated target is refused"   "$O" "REFUSE installe"
has "...and the refusal names the target it will not touch" "$O" "$T/vendored-installe"
has "...and says it is none of the retired channels" "$O" "none of the stale channels"
[ "$(tgt installe)" = "$T/vendored-installe" ] \
  && ok "the vendored binary's link is untouched" \
  || bad "the vendored binary's link was re-pointed to $(tgt installe)"

# ===========================================================================
echo
echo "-- THE DRY RUN SAYS WHAT THE APPLY RUN WOULD DO ------------------------"
# ===========================================================================
# A dry run that reports a different set from the apply run is worse than no
# dry run: the classification is computed in ONE function precisely so these
# cannot diverge.
reset_world
O="$(run --adopt-existing)"; R=$?
has "the dry run says it is one"                    "$O" "DRY RUN"
has "it shows the state it classified each verb as" "$O" "[adopt]"
has "it still refuses the regular file"             "$O" "REFUSE debarrasse"
has "it still refuses the unrelated symlink"        "$O" "REFUSE installe"
hasnt "it does not claim to have adopted anything"  "$O" "ADOPT  arpente"
[ "$(tgt arpente)" = "$PROJ/realisateur/.worktrees/bashified/bin/arpente" ] \
  && ok "a dry run changed nothing on disk" || bad "a dry run changed a link"

# ===========================================================================
echo
echo "-- SECOND RUN IS A NO-OP, AND THE REFUSALS DO NOT DECAY ----------------"
# ===========================================================================
reset_world
run --apply --adopt-existing >/dev/null
O="$(run --apply --adopt-existing)"; R=$?
rc  "the refusals still fail the run on a second pass" 1 "$R"
has "everything adopted last run is now 'already on the build'" "$O" "4 already on the build"
hasnt "nothing is adopted twice" "$O" "ADOPT  arpente"

# ===========================================================================
echo
echo "-- THE STUB WAS ACTUALLY EXERCISED ------------------------------------"
# ===========================================================================
# A stub that quietly stopped refusing would make every assertion above pass
# for the wrong reason. So: the unowned-name refusal must still fire when the
# script is NOT allowed to adopt.
reset_world
O="$(env BUILD_ROOT="$BR" BIN="$BIN" INSTALLE_BIN="$BIN" INSTALLE_MANIFEST="$MAN" \
      STUB_BUILD_ROOT="$BR" "$BUILD/senechal/bin/installe" --quiet verb realisateur arpente 2>&1)"; R=$?
rc  "the stub still refuses an unowned name without --force" 7 "$R"
has "...with the message the real installe prints" "$O" "installe did not put it there"
O="$(env BUILD_ROOT="$BR" BIN="$BIN" INSTALLE_BIN="$BIN" INSTALLE_MANIFEST="$MAN" \
      STUB_BUILD_ROOT="$BR" "$BUILD/senechal/bin/installe" --quiet --force verb senechal debarrasse 2>&1)"; R=$?
rc  "the stub still refuses a regular file even WITH --force" 7 "$R"

# ===========================================================================
echo
echo "-- THE ARGUMENT CONTRACT ----------------------------------------------"
# ===========================================================================
run --not-a-real-flag >/dev/null 2>&1; rc "an unknown flag exits 2" 2 $?
O="$(run --not-a-real-flag)"
has "the usage line documents the new flag" "$O" "--adopt-existing"

# It refuses to guess when there is no build, rather than relinking to nothing.
O="$(env BUILD_ROOT="$T/absent" BIN="$BIN" bash "$S" --apply --adopt-existing 2>&1)"; R=$?
rc  "no installed build is a refusal, not an empty success" 1 "$R"
has "...and it names what to run"  "$O" "install-verb-build.sh"

echo
echo "relink-verbs-to-build.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
