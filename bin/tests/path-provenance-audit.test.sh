#!/usr/bin/env bash
# HERMETICITY: every case builds a throwaway $HOME under mktemp, a throwaway
# copy of the script beside a throwaway ratchet file, and a PATH consisting of
# that fake home's bin dirs plus a stub directory holding a FAILING `gh` and a
# FAILING `crontab`. HOME, PATH, INSTALLE_MANIFEST, INSTALLE_PROJECTS and
# SENECHAL_CONFIG are all redirected into the fixture, so the script cannot
# read this machine's ~/.local/bin, this machine's installe manifest, this
# machine's senechal config, or the live issue tracker. It says the same thing
# on every host and in CI. The one thing it reads from outside is the script
# under test, which is the branch's copy, not the shared checkout.
#
# path-provenance-audit.test.sh -- witness for bin/path-provenance-audit.sh.
#
# NOT A SUBSTITUTE FOR RUNNING IT ON A HOST. The guard's whole subject is a
# real account's PATH; this suite proves the CLASSIFIER and the RATCHET are
# right, which is the half a container can honestly assert.
#
# THE LOAD-BEARING CASE IS B. bin/path-provenance-audit.sh exists because
# hf7y/realisateur#101 deleted three scripts, their shims survived as
# permanent exit-127 commands, and nothing noticed. B1 reconstructs exactly
# that shim and asserts the guard names it; B3 asserts that once `noorphan`
# is in the ratchet, reintroducing one FAILS THE BUILD. A ratchet whose
# regression path is untested is a print statement.
#
# Cases:
#   A1 a HOME with no PATH dir under it        -> BLIND, exit 2 (never 0)
#   A2 ...and the BLIND rows print above everything else
#   B1 the #101 shim, target deleted           -> ORPHAN, named
#   B2 a healthy generated shim                -> DECLARED, not orphan
#   B3 an orphan with `noorphan` ratcheted     -> exit 1 REGRESSION
#   B4 a shim naming an owner but no target    -> DECLARED, not ORPHAN
#      (the lid-inhibit-daemon false positive the first draft produced)
#   B5 a regression AND an unreachable tracker -> exit 1, blindness still said
#   B6 an unreachable tracker, nothing else    -> exit 2, never 0
#   B7 a dangling symlink in retired-*/        -> ORPHAN, not skipped (#204)
#   C1 manifest says X, link resolves to Y     -> DRIFT
#   C2 manifest target deleted                 -> ORPHAN
#   D1 provisioned class, one undeclared entry -> coverage UNMET at any ceiling
#   D2 daily class, same fixture under ceiling -> coverage PASS
#   E1 a symlink into a checkout               -> counted undeclared, not owned
#   F1 an unrecognised PATH dir under HOME     -> dirs UNMET, and NOT swept
#   F2 a toolchain dir (rbenv shims)           -> attributed, not a finding
#   G1 --accept refuses while regressed        -> exit 1
#   G2 --accept never raises the ceiling
#   G3 --accept refuses a run that censused nothing
#   H1 --strict with checks unmet              -> exit 3
#   H2 an unknown flag                         -> exit 2

set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }
is()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected [$3], got [$2]"; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "output lacks [$3]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1" "output should not contain [$3]" ;; *) ok "$1" ;; esac; }

TMP="$(mktemp -d)" || { echo "cannot mktemp" >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT

# --- stubs: no tracker, no crontab -------------------------------------------
mkdir -p "$TMP/stub" "$TMP/stub-noget"
# A gh that answers, deterministically, "the tracker has no open issues". The
# tracker probe is not what these cases are about, and a gh that FAILS would
# make every case BLIND -- which the guard correctly refuses to grade as
# clean, so every assertion below would have been graded against exit 2. The
# stub in stub-noget/ is the failing one, used only by the case that is about
# blindness.
printf '#!/bin/sh\nprintf "[]"\n' > "$TMP/stub/gh"
printf '#!/bin/sh\nexit 1\n'      > "$TMP/stub/crontab"
printf '#!/bin/sh\nexit 1\n'      > "$TMP/stub-noget/gh"
printf '#!/bin/sh\nexit 1\n'      > "$TMP/stub-noget/crontab"
chmod +x "$TMP/stub/gh" "$TMP/stub/crontab" "$TMP/stub-noget/gh" "$TMP/stub-noget/crontab"

# --- a throwaway realisateur holding the script under test -------------------
FAKE="$TMP/realisateur"
mkdir -p "$FAKE/bin/lib"
cp "$ROOT/bin/path-provenance-audit.sh" "$FAKE/bin/"
cp "$ROOT/bin/lib/cli-guard.sh"         "$FAKE/bin/lib/"

CASE=0
# newhome -- a fresh fake account. Sets FH (its home) and clears the ratchet.
newhome() {
  CASE=$((CASE + 1))
  FH="$TMP/h$CASE"
  mkdir -p "$FH/.local/bin" "$FH/.local/share/installe" "$FH/.config/senechal" \
           "$FH/Documents/Projects/someproj/bin"
  : > "$FH/.local/share/installe/manifest.tsv"
  rm -f "$FAKE/bin/path-provenance-audit.ratchet"
}

# run <args...> -- sets OUT and RC. Not `OUT=$(run ...)`: command substitution
# runs the function in a subshell and the rc assigned there never reaches the
# caller, which is how bin/tests/guard-estate.test.sh graded a guard against
# another guard's exit code in its first draft.
run() {
  OUT="$(env \
      HOME="$FH" \
      PATH="$FH/.local/bin:$TMP/stub:/usr/bin:/bin" \
      INSTALLE_MANIFEST="$FH/.local/share/installe/manifest.tsv" \
      INSTALLE_PROJECTS="$FH/Documents/Projects" \
      SENECHAL_CONFIG="$FH/.config/senechal/senechal.json" \
      PATH_PROVENANCE_CLASS="${CLASS:-daily}" \
      timeout 60 bash "$FAKE/bin/path-provenance-audit.sh" "$@" 2>&1)"
  RC=$?
}

# A shim shaped exactly like the ones bin/install-shims.sh writes.
mkshim() { # <path> <owner> <real target>
  cat > "$1" <<EOF
#!/usr/bin/env bash
# >>> $2-owned shim -- generated by bin/install-shims.sh.
# DO NOT EDIT HERE.
# <<< $2-owned
set -uo pipefail
real="$3"
[ -x "\$real" ] || { echo "\$(basename "\$0"): FAIL: not found at \$real" >&2; exit 127; }
exec "\$real" "\$@"
EOF
  chmod +x "$1"
}

echo "== A. A HOME WITH NOTHING ON PATH IS BLIND, NOT CLEAN =="
newhome
# PATH deliberately excludes the fake home's bin dir for this one case.
OUT="$(env HOME="$FH" PATH="$TMP/stub:/usr/bin:/bin" \
    INSTALLE_MANIFEST="$FH/.local/share/installe/manifest.tsv" \
    SENECHAL_CONFIG="$FH/.config/senechal/senechal.json" \
    timeout 60 bash "$FAKE/bin/path-provenance-audit.sh" 2>&1)"; RC=$?
is  "A1 exit 2, not 0"           "$RC" 2
has "A1 says BLIND"              "$OUT" "BLIND"
has "A1 refuses to call it clean" "$OUT" "NOT 'nothing is wrong'"
# The BLIND rows must sit above any UNMET row: closeout-lint printed its
# "13 worktrees NOT examined" one line above twelve false alarms and exited 0.
first_blind="$(printf '%s\n' "$OUT" | grep -n 'BLIND' | head -1 | cut -d: -f1)"
first_unmet="$(printf '%s\n' "$OUT" | grep -n 'UNMET' | head -1 | cut -d: -f1)"
if [ -z "$first_unmet" ] || [ "$first_blind" -lt "$first_unmet" ]; then
  ok "A2 the admission of blindness prints above the findings"
else
  bad "A2 the admission of blindness prints above the findings" "BLIND at $first_blind, UNMET at $first_unmet"
fi

echo
echo "== B. THE ORPHANED SHIM -- THE DEFECT THIS GUARD EXISTS FOR =="
newhome
mkdir -p "$FH/Documents/Projects/realisateur/bin"
echo '#!/bin/sh' > "$FH/Documents/Projects/realisateur/bin/hygiene-lint.sh"
chmod +x "$FH/Documents/Projects/realisateur/bin/hygiene-lint.sh"
# alive: the source is there.
mkshim "$FH/.local/bin/hygiene-lint" realisateur "$FH/Documents/Projects/realisateur/bin/hygiene-lint.sh"
# dead: this is bin/ecosystem-survey.sh after #101 deleted it.
mkshim "$FH/.local/bin/ecosystem-survey" realisateur "$FH/Documents/Projects/realisateur/bin/ecosystem-survey.sh"
run
has "B1 names the orphan"                "$OUT" "ecosystem-survey"
has "B1 calls it an orphan"              "$OUT" "ORPHAN"
has "B1 says the source is deleted"      "$OUT" "delegates to a deleted source"
has "B1 counts exactly one"              "$OUT" "1 entr(ies) delegate to a source that no longer exists"
has "B2 the healthy shim is accounted"   "$OUT" "self-declaring 1"
hasnt "B2 the healthy shim is not flagged" "${OUT#*ORPHAN}" "hygiene-lint"

# B3 -- the ratchet's whole purpose.
cat > "$FAKE/bin/path-provenance-audit.ratchet" <<'EOF'
# fixture ratchet
bound undeclared 99
noorphan
EOF
run
is  "B3 a ratcheted noorphan that now fails is a REGRESSION" "$RC" 1
has "B3 names the regressed check"       "$OUT" "REGRESSION: noorphan"

# B5 -- ordering. An unreachable tracker must not swallow a named regression:
# a headless account with no `gh` would otherwise report "I could not look"
# about a build that has a name for what broke.
OUT="$(env HOME="$FH" PATH="$FH/.local/bin:$TMP/stub-noget:/usr/bin:/bin" \
    INSTALLE_MANIFEST="$FH/.local/share/installe/manifest.tsv" \
    INSTALLE_PROJECTS="$FH/Documents/Projects" \
    SENECHAL_CONFIG="$FH/.config/senechal/senechal.json" \
    timeout 60 bash "$FAKE/bin/path-provenance-audit.sh" 2>&1)"; RC=$?
is  "B5 a REGRESSION outranks an unrelated BLIND" "$RC" 1
has "B5 and the blindness is still reported"      "$OUT" "also BLIND on"
rm -f "$FAKE/bin/path-provenance-audit.ratchet"

# B6 -- and with nothing regressed, an unreachable tracker is exit 2, never 0.
OUT="$(env HOME="$FH" PATH="$TMP/stub-noget:/usr/bin:/bin" \
    HOME="$FH" \
    INSTALLE_MANIFEST="$FH/.local/share/installe/manifest.tsv" \
    SENECHAL_CONFIG="$FH/.config/senechal/senechal.json" \
    timeout 60 bash "$FAKE/bin/path-provenance-audit.sh" 2>&1)"; RC=$?
is "B6 an unreachable tracker is BLIND, not clean" "$RC" 2

# B4 -- the false positive the first draft produced against a real shim.
newhome
cat > "$FH/.local/bin/lid-inhibit-daemon" <<'EOF'
#!/usr/bin/env bash
# GENERATED by senechal remedies/lid-inhibit-honoured.sh -- edit there.
set -uo pipefail
EOF
chmod +x "$FH/.local/bin/lid-inhibit-daemon"
run
hasnt "B4 an owner-only declaration is not an orphan" "$OUT" "ORPHAN"
has   "B4 it is counted as declared"                  "$OUT" "self-declaring 1"

# B7 -- hf7y/realisateur#204: a symlink hand-retired into retired-*/ (pulled
# off PATH rather than deleted) whose target later vanishes must still be
# caught, not silently skipped for being one level down.
newhome
mkdir -p "$FH/.local/bin/retired-2026-08-12"
ln -s "$FH/Documents/Projects/someproj/bin/gone" "$FH/.local/bin/retired-2026-08-12/old-verb"
run
has "B7 a dangling symlink in retired-*/ is still censused" "$OUT" "ORPHAN"
has "B7 it is named with its retired- prefix"                "$OUT" "retired-2026-08-12/old-verb"

echo
echo "== C. DRIFT AND A DEAD MANIFEST ENTRY =="
newhome
echo '#!/bin/sh' > "$FH/Documents/Projects/someproj/bin/thing"
echo '#!/bin/sh' > "$FH/Documents/Projects/someproj/bin/other"
chmod +x "$FH/Documents/Projects/someproj/bin/thing" "$FH/Documents/Projects/someproj/bin/other"
ln -s "$FH/Documents/Projects/someproj/bin/other" "$FH/.local/bin/thing"
printf 'thing\t%s\t2026-08-07\n' "$FH/Documents/Projects/someproj/bin/thing" \
  > "$FH/.local/share/installe/manifest.tsv"
run
has "C1 drift is named"           "$OUT" "DRIFT"
has "C1 drift is counted"         "$OUT" "1 entr(ies) resolve somewhere other than the manifest target"

newhome
ln -s "$FH/Documents/Projects/someproj/bin/gone" "$FH/.local/bin/gone"
printf 'gone\t%s\t2026-08-07\n' "$FH/Documents/Projects/someproj/bin/gone" \
  > "$FH/.local/share/installe/manifest.tsv"
run
has "C2 a manifest entry whose target is gone is an ORPHAN" "$OUT" "ORPHAN"

echo
echo "== D. THE HOST-CLASS ASYMMETRY -- THE DESIGN DECISION UNDER TEST =="
# One fixture, two classes, two verdicts. If these ever agree, the split has
# been flattened back to a single bar and the mandark/monkey distinction Zach
# asked for is gone.
newhome
printf '#!/bin/sh\n' > "$FH/.local/bin/handmade"; chmod +x "$FH/.local/bin/handmade"
cat > "$FAKE/bin/path-provenance-audit.ratchet" <<'EOF'
bound undeclared 5
EOF
CLASS=provisioned run
has "D1 provisioned: an undeclared entry is UNMET even under the ceiling" "$OUT" "The bar here is 100%"
CLASS=provisioned run --strict
is  "D1 provisioned: --strict fails" "$RC" 3
CLASS=daily run
has "D2 daily: the same entry passes under the ceiling" "$OUT" "1 undeclared <= ceiling 5"
rm -f "$FAKE/bin/path-provenance-audit.ratchet"

echo
echo "== E. A HAND-MADE LINK INTO A CHECKOUT IS TRACEABLE, NOT DECLARED =="
newhome
echo '#!/bin/sh' > "$FH/Documents/Projects/someproj/bin/tool"
chmod +x "$FH/Documents/Projects/someproj/bin/tool"
ln -s "$FH/Documents/Projects/someproj/bin/tool" "$FH/.local/bin/tool"
run
has "E1 counted as a repo-link, not as owned" "$OUT" "repo-link 1"
has "E1 and therefore as undeclared"          "$OUT" "undeclared   1"

echo
echo "== F. DIRECTORY-LEVEL PROVENANCE =="
newhome
mkdir -p "$FH/oddbin"
printf '#!/bin/sh\n' > "$FH/oddbin/a"; printf '#!/bin/sh\n' > "$FH/oddbin/b"
chmod +x "$FH/oddbin/a" "$FH/oddbin/b"
OUT="$(env HOME="$FH" PATH="$FH/oddbin:$FH/.local/bin:$TMP/stub:/usr/bin:/bin" \
    INSTALLE_MANIFEST="$FH/.local/share/installe/manifest.tsv" \
    SENECHAL_CONFIG="$FH/.config/senechal/senechal.json" \
    timeout 60 bash "$FAKE/bin/path-provenance-audit.sh" 2>&1)"; RC=$?
has "F1 an unrecognised PATH dir is a finding"   "$OUT" "belong to no known toolchain"
has "F1 its executables are counted once, as a dir" "$OUT" "oddbin(2)"
hasnt "F1 and its contents are NOT swept per-file" "$OUT" "UNKNOWN    a"

newhome
mkdir -p "$FH/.rbenv/shims"
printf '#!/bin/sh\n' > "$FH/.rbenv/shims/gem"; chmod +x "$FH/.rbenv/shims/gem"
OUT="$(env HOME="$FH" PATH="$FH/.rbenv/shims:$FH/.local/bin:$TMP/stub:/usr/bin:/bin" \
    INSTALLE_MANIFEST="$FH/.local/share/installe/manifest.tsv" \
    SENECHAL_CONFIG="$FH/.config/senechal/senechal.json" \
    timeout 60 bash "$FAKE/bin/path-provenance-audit.sh" 2>&1)"; RC=$?
hasnt "F2 a toolchain shim dir is attributed to its manager" "$OUT" "belong to no known toolchain"

echo
echo "== G. THE RATCHET ONLY MOVES ONE WAY =="
newhome
mkdir -p "$FH/Documents/Projects/realisateur/bin"
mkshim "$FH/.local/bin/ecosystem-survey" realisateur "$FH/Documents/Projects/realisateur/bin/ecosystem-survey.sh"
cat > "$FAKE/bin/path-provenance-audit.ratchet" <<'EOF'
bound undeclared 99
noorphan
EOF
run --accept
is  "G1 --accept refuses while a ratcheted check is regressed" "$RC" 1
has "G1 says so"                                               "$OUT" "REFUSED"
has "G1 the ratchet file is untouched"  "$(cat "$FAKE/bin/path-provenance-audit.ratchet")" "bound undeclared 99"

newhome
printf '#!/bin/sh\n' > "$FH/.local/bin/handmade"; chmod +x "$FH/.local/bin/handmade"
cat > "$FAKE/bin/path-provenance-audit.ratchet" <<'EOF'
bound undeclared 0
EOF
run --accept
has "G2 --accept never raises the ceiling" "$(cat "$FAKE/bin/path-provenance-audit.ratchet")" "bound undeclared 0"
rm -f "$FAKE/bin/path-provenance-audit.ratchet"

newhome
OUT="$(env HOME="$FH" PATH="$TMP/stub:/usr/bin:/bin" \
    INSTALLE_MANIFEST="$FH/.local/share/installe/manifest.tsv" \
    SENECHAL_CONFIG="$FH/.config/senechal/senechal.json" \
    timeout 60 bash "$FAKE/bin/path-provenance-audit.sh" --accept 2>&1)"; RC=$?
is  "G3 --accept refuses a floor from a run that censused nothing" "$RC" 2
if [ -f "$FAKE/bin/path-provenance-audit.ratchet" ]; then
  bad "G3 no ratchet was written" "a ratchet file appeared"
else
  ok "G3 no ratchet was written"
fi

echo
echo "== H. THE ARGUMENT CONTRACT =="
newhome
printf '#!/bin/sh\n' > "$FH/.local/bin/handmade"; chmod +x "$FH/.local/bin/handmade"
run --strict
is "H1 --strict fails while the vision is unmet" "$RC" 3
run --not-a-real-flag
is "H2 an unknown flag is a usage error" "$RC" 2

echo
echo "path-provenance-audit.test: $pass ok, $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
