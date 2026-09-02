#!/usr/bin/env bash
#
# Contract test for the verb-build pair.
#
# The claims worth failing over are not "it can install a verb". They are
# the ways this could quietly do the wrong thing, each of which has already
# happened once in this ecosystem:
#
#   * switch to a build that is missing a verb          (2026-07-29 outage)
#   * report "up to date" when it could not look        (the `garde` shape)
#   * install an empty verb set and exit 0              (install-shims, 08-02)
#   * clobber a link another installer owns             (installe's manifest)
#
# Runs against a local fixture meta-repo over file://, so no network -- the
# suite is not itself subject to the blindness it tests for.
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$HERE/../install-verb-build.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

META="$TMP/meta"
ROOT="$TMP/builds"
BIN="$TMP/bin"
mkdir -p "$BIN"

g() { git -c init.defaultBranch=main -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }

# A fixture meta-repo with two builds, exactly as CI would leave it.
mk_build() {
    local id="$1" verbs="$2"
    rm -rf "${META:?}"/*/ 2>/dev/null || true
    : > "$META/manifest.tsv"
    printf '# verb build %s\n' "$id" >> "$META/manifest.tsv"
    for spec in $verbs; do
        local proj="${spec%%:*}" verb="${spec##*:}"
        mkdir -p "$META/$proj/bin" "$META/$proj/man"
        printf '#!/bin/sh\necho %s\n' "$verb" > "$META/$proj/bin/$verb"
        chmod +x "$META/$proj/bin/$verb"
        : > "$META/$proj/man/$verb.1"
        printf '%s\t%s\t%s\thttps://example/%s.git\n' \
               "$proj" "$verb" "0000000000000000000000000000000000000000" "$proj" >> "$META/manifest.tsv"
    done
    printf '%s\n' "$id" > "$META/BUILD_ID"
    g -C "$META" add -A
    g -C "$META" commit -m "build $id"
    g -C "$META" tag "build/$id"
}

# Only `approved/<id>` is adoptable, written by a reviewer-gated dispatch.
approve() { g -C "$META" tag "approved/$1"; }

mkdir -p "$META"; g init "$META"
mk_build "2026-08-04T0130Z" "vim-arcade:entraine senechal:installe"
approve "2026-08-04T0130Z"
mk_build "2026-08-05T0130Z" "vim-arcade:entraine senechal:installe scheduler:arme"
approve "2026-08-05T0130Z"

CMD_DEST="$TMP/claude/commands"
HOOK_DEST="$TMP/claude/hooks"
SELFDEV_LIBEXEC="$TMP/libexec"
run() { VERB_BUILD_ROOT="$ROOT" INSTALLE_BIN="$BIN" \
        CMD_DEST="$CMD_DEST" HOOK_DEST="$HOOK_DEST" \
        SELFDEV_LIBEXEC="$SELFDEV_LIBEXEC" \
        bash "$INSTALL" --remote "file://$META" "$@"; }

echo "verb-build contract"

# --- 1. install and switch ----------------------------------------------
run --build 2026-08-04T0130Z --apply >/dev/null 2>&1
check "installing a build switches current to it" \
      "$(readlink "$ROOT/current")" "2026-08-04T0130Z"
check "...and the verb is reachable through current" \
      "$(sh "$ROOT/current/vim-arcade/bin/entraine" 2>/dev/null)" "entraine"

# --- 2. a build stays put while the remote moves on ---------------------
# This is the whole "stable while agents work on the next version" claim.
run --check >/dev/null 2>&1
check "--check exits 1 when a newer build exists" "$?" "1"
check "...and current has NOT moved on its own" \
      "$(readlink "$ROOT/current")" "2026-08-04T0130Z"

run --latest --apply >/dev/null 2>&1
check "--latest --apply adopts the newest build" \
      "$(readlink "$ROOT/current")" "2026-08-05T0130Z"
run --check >/dev/null 2>&1
check "--check exits 0 once current" "$?" "0"

# --- 3. rollback is local and needs no network --------------------------
VERB_BUILD_ROOT="$ROOT" INSTALLE_BIN="$BIN" \
  bash "$INSTALL" --remote "file:///nonexistent" --rollback 2026-08-04T0130Z >/dev/null 2>&1
check "rollback works with the remote unreachable" "$?" "0"
check "...and current is back on the older build" \
      "$(readlink "$ROOT/current")" "2026-08-04T0130Z"

# --- 4. unreachable is BLIND, never 'up to date' ------------------------
VERB_BUILD_ROOT="$TMP/fresh" INSTALLE_BIN="$BIN" \
  bash "$INSTALL" --remote "file:///nonexistent" --check >/dev/null 2>&1
check "an unreachable meta-repo exits 6 (BLIND), not 0" "$?" "6"

OUT="$(VERB_BUILD_ROOT="$TMP/fresh" INSTALLE_BIN="$BIN" \
       bash "$INSTALL" --remote "file:///nonexistent" --check 2>&1)"
# Match the CURRENCY CLAIM ('verbs: up to date'), not the bare phrase --
# the BLIND message deliberately contains the words "up to date" in order
# to deny them, and a naive substring test would fail the very wording that
# makes the message correct.
case "$OUT" in
    *"verbs: up to date"*) bad "BLIND never claims currency" "it printed the currency line" ;;
    *BLIND*)               ok "BLIND says BLIND, and does not claim currency" ;;
    *)                     bad "BLIND says BLIND" "got: $OUT" ;;
esac

# --- 5. an incomplete build is discarded, not switched to ---------------
run --latest --apply >/dev/null 2>&1          # back on the newest
before="$(readlink "$ROOT/current")"
# CI could not produce this, but a truncated transfer or a hand-edited
# meta-repo could. The consumer must not trust the manifest blindly.
mk_build "2026-08-06T0130Z" "vim-arcade:entraine senechal:installe"
g -C "$META" tag -d build/2026-08-06T0130Z
printf 'scheduler\tarme\t0000000000000000000000000000000000000000\thttps://example/scheduler.git\n' \
    >> "$META/manifest.tsv"   # promises a verb the tree does not carry
g -C "$META" add -A
g -C "$META" commit -m "broken build"
g -C "$META" tag "build/2026-08-06T0130Z"

run --build 2026-08-06T0130Z --apply >/dev/null 2>&1
check "a build missing a promised verb is refused (exit 1)" "$?" "1"
check "...and current did NOT move to it" "$(readlink "$ROOT/current")" "$before"
check "...and the broken build was discarded, not left half-installed" \
      "$([ -d "$ROOT/2026-08-06T0130Z" ] && echo present || echo absent)" "absent"

# --- 6. --link never clobbers another installer's link ------------------
ln -sfn /somewhere/else/installe "$BIN/installe"      # pretend installe owns it
# By name, NOT --latest: test 5 left a deliberately broken build carrying
# the newest tag, and --latest would (correctly) refuse it and never reach
# the linking step.
run --build 2026-08-05T0130Z --apply --link >/dev/null 2>&1
check "a foreign link is left exactly as it was" \
      "$(readlink "$BIN/installe")" "/somewhere/else/installe"
check "...while a verb it does not own IS linked" \
      "$(readlink "$BIN/entraine")" "$ROOT/current/vim-arcade/bin/entraine"

# --- 7. the link points through `current`, not at a build ---------------
# So that adopting the next build moves every verb at once, and the
# ~/.local/bin links are never rewritten again.
case "$(readlink "$BIN/entraine")" in
    */current/*) ok "verb links resolve through current, so one switch moves them all" ;;
    *) bad "verb links resolve through current" "got $(readlink "$BIN/entraine")" ;;
esac
run --rollback 2026-08-04T0130Z >/dev/null 2>&1
check "...and after a rollback the SAME link resolves to the older build" \
      "$(readlink -f "$BIN/entraine")" "$ROOT/2026-08-04T0130Z/vim-arcade/bin/entraine"

# --- 8. THE VERB COUNT PROPAGATES, NOT JUST THE VERB CONTENT ------------
# Test 7 proves an EXISTING verb follows `current` for free. It says nothing
# about a build whose verb SET changed, which is the question an operator
# actually asks of a nightly channel: "a verb was added last night -- do the
mk_build "2026-08-08T0130Z" "vim-arcade:entraine senechal:installe scheduler:arme bibliothecaire:consulte"
run --build 2026-08-08T0130Z --apply --link >/dev/null 2>&1
check "a verb ADDED by the nightly build is linked with no hand step" \
      "$(readlink "$BIN/consulte")" "$ROOT/current/bibliothecaire/bin/consulte"
[ -x "$BIN/consulte" ] && ok "...and the new verb is executable through the link" \
                       || bad "the new verb is executable through the link" "not executable"
check "...while the verbs already there still resolve through current" \
      "$(readlink "$BIN/entraine")" "$ROOT/current/vim-arcade/bin/entraine"

# The other half of a count change: a verb DROPPED from the manifest must
# have its link removed, not left dangling -- PATH search skips a dangling
# link, so leaving it there is a silent failure (realisateur#223).
mk_build "2026-08-09T0130Z" "vim-arcade:entraine senechal:installe scheduler:arme"
run --build 2026-08-09T0130Z --apply --link >/dev/null 2>&1
if [ ! -L "$BIN/consulte" ] && [ ! -e "$BIN/consulte" ]; then
    ok "a verb DROPPED from the build has its link removed, not left dangling"
else
    bad "a dropped verb's link is removed" \
        "$([ -L "$BIN/consulte" ] && echo 'still a dangling symlink' || echo 'still present')"
fi
check "...while a verb still in the manifest keeps resolving through current" \
      "$(readlink "$BIN/entraine")" "$ROOT/current/vim-arcade/bin/entraine"

# The count check: after a drop, links pointing into the build root match
# the manifest exactly -- the comparison an operator would reach for. Not
# 3: `installe` stays foreign for the rest of the suite (test 6 gave it to
# another owner), so only entraine and arme are ours to count.
ours=0
for f in "$BIN"/*; do
    [ -L "$f" ] || continue
    case "$(readlink "$f")" in "$ROOT/current/"*) ours=$((ours + 1)) ;; esac
done
check "count check: links into the build root match the manifest row count" "$ours" "2"

# --- 9. the non-verb payload: slash commands and hooks ------------------
# --link must carry these too, or "clone-free" is true only of the half that
# happens to be executable (#389).
mk_build "2026-08-10T0130Z" "vim-arcade:entraine scheduler:arme"
mkdir -p "$META/realisateur/commands" "$META/realisateur/hooks"
printf 'slash body\n' > "$META/realisateur/commands/cloture.md"
printf '#!/bin/sh\n' > "$META/realisateur/hooks/subagent-closeout.sh"
g -C "$META" add -A; g -C "$META" commit -m "payload"; g -C "$META" tag -f "build/2026-08-10T0130Z"
run --build 2026-08-10T0130Z --apply --link >/dev/null 2>&1
check "a slash command in the build is installed into CMD_DEST" \
      "$(cat "$CMD_DEST/cloture.md" 2>/dev/null)" "slash body"
check "...VERBATIM -- byte-identical to what the build carries, so carry-drift can grade it" \
      "$(cmp -s "$META/realisateur/commands/cloture.md" "$CMD_DEST/cloture.md" && echo same)" "same"
check "a hook in the build is installed executable into HOOK_DEST" \
      "$([ -x "$HOOK_DEST/subagent-closeout.sh" ] && echo yes)" "yes"

# A symlink at the destination is never ours, and cp would write THROUGH it
# and clobber whatever it points at. Same rule as install-shims.sh.
victim="$TMP/victim.md"; printf 'do not clobber\n' > "$victim"
ln -sfn "$victim" "$CMD_DEST/cloture.md"
run --build 2026-08-10T0130Z --apply --link >/dev/null 2>&1
check "a symlink at the destination is skipped, not written through" \
      "$(cat "$victim")" "do not clobber"

# --- 12. libexec: the host tools the clock now delivers (#517) -----------
# Before this, /usr/local/libexec/selfdev refreshed ONLY when a human ran
# wire-release-channel.sh --host --apply, so a fix to one of ausculte's own
# probes sat on main indefinitely. That is how a decision-rot which could not
# load its roster walked zero repositories, exited 0, and rendered as `rot OK`
# over 48 rotting decisions (#512).
mkdir -p "$META/realisateur/libexec"
printf '#!/bin/sh\ntouch "$1"\nwhile [ ! -f "$2" ]; do sleep 0.05; done\necho OLD\n' \
  > "$META/realisateur/libexec/probe.sh"
g -C "$META" add -A; g -C "$META" commit -m "libexec"; g -C "$META" tag -f "build/2026-08-11T0130Z"
run --build 2026-08-11T0130Z --apply --link >/dev/null 2>&1
check "a host tool in the build is installed executable into SELFDEV_LIBEXEC" \
      "$([ -x "$SELFDEV_LIBEXEC/probe.sh" ] && echo yes)" "yes"

# THE HAZARD THIS DIRECTORY HAS AND THE OTHER TWO DO NOT: a destination here
# can be EXECUTING while the next build lands on it -- root's tick runs
# install-verb-build.sh out of this very directory. A shell re-reads its script
# BY OFFSET, so `cp` over a running one truncates it IN PLACE, same inode, and
# the shell then executes whatever now sits at that offset.
#
# The invariant is REPLACEMENT, NOT REWRITING, and the inode is what says so.
# Asserted directly rather than by racing a live script: a small script gets
# buffered whole by the interpreter, so a timing test passes with `cp` too --
# it looks like a witness and is not one.
ino_before="$(stat -c %i "$SELFDEV_LIBEXEC/probe.sh")"
printf '#!/bin/sh\necho NEW\n' > "$META/realisateur/libexec/probe.sh"
g -C "$META" add -A; g -C "$META" commit -m "libexec v2"; g -C "$META" tag -f "build/2026-08-12T0130Z"
run --build 2026-08-12T0130Z --apply --link >/dev/null 2>&1
ino_after="$(stat -c %i "$SELFDEV_LIBEXEC/probe.sh")"
if [ "$ino_before" != "$ino_after" ]; then
  ok "an updated host tool REPLACES the file (new inode), so a running copy is untouched"
else
  bad "an updated host tool replaces the file" "inode unchanged ($ino_after) -- written in place, which corrupts a script executing from here"
fi
check "...and the destination carries the new content" \
      "$(tail -1 "$SELFDEV_LIBEXEC/probe.sh")" "echo NEW"
# No temp files left behind: the install writes .<name>.new.$$ beside the target.
check "...and no .new temp file is left in the directory" \
      "$(find "$SELFDEV_LIBEXEC" -name '.*.new.*' | wc -l)" "0"

# --- N. a cut is not a release. Own fixture: the cases above deliberately
# leave broken builds in the shared one.
echo
GMETA="$TMP/meta-gate"; GROOT="$TMP/builds-gate"; mkdir -p "$GMETA"
g init "$GMETA"
gmk() { META="$GMETA" mk_build "$1" "vim-arcade:entraine senechal:installe"; }
grun() { VERB_BUILD_ROOT="$GROOT" INSTALLE_BIN="$BIN" CMD_DEST="$CMD_DEST" \
         HOOK_DEST="$HOOK_DEST" SELFDEV_LIBEXEC="$SELFDEV_LIBEXEC" \
         bash "$INSTALL" --remote "file://$GMETA" "$@"; }

gmk "2026-09-01T0130Z"; g -C "$GMETA" tag "approved/2026-09-01T0130Z"
grun --latest --apply >/dev/null 2>&1
check "an approved build installs" "$(readlink "$GROOT/current")" "2026-09-01T0130Z"

gmk "2026-09-02T0130Z"          # cut, not approved
grun --check >/dev/null 2>&1
check "an UNAPPROVED cut does not read as a newer build" "$?" "0"
grun --latest --apply >/dev/null 2>&1
check "...and --latest --apply leaves the pin alone" \
      "$(readlink "$GROOT/current")" "2026-09-01T0130Z"

g -C "$GMETA" tag "approved/2026-09-02T0130Z"
grun --check >/dev/null 2>&1
check "approving it makes it available" "$?" "1"
grun --latest --apply >/dev/null 2>&1
check "...and only then is it adopted" \
      "$(readlink "$GROOT/current")" "2026-09-02T0130Z"

for t in $(git -C "$GMETA" tag --list 'approved/*'); do g -C "$GMETA" tag -d "$t"; done
out="$(VERB_BUILD_ROOT="$TMP/b2" INSTALLE_BIN="$BIN" bash "$INSTALL" \
       --remote "file://$GMETA" --latest --apply 2>&1)"; rc=$?
check "builds but no approval is BLIND, not silent" "$rc" "6"
case "$out" in *"NONE is approved"*) ok "...and it names how to approve one" ;;
                *) bad "...and it names how to approve one" "got: $out" ;; esac

echo
summary
