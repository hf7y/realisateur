#!/usr/bin/env bash
# consigne.test.sh -- the two doors must be one implementation, and the second
# half of a reaping pass must be countable.
#
# HERMETICITY: nothing outside $TMP is read or written. The deposit mechanism
# is never the real one: `bin/consigne` resolves it through CONSIGNE_IMPL,
# which every deposit case points at a RECORDING STUB inside $TMP, so no vault,
# no bibliothecaire checkout and no installed verb build is touched. PATH is
# replaced with a $TMP-only bin for the resolution cases, so a host that
# happens to have `fonde` or `installe` installed cannot change an outcome. The
# `status` cases build their own fixture repo and fixture vault under $TMP and
# hash real files there. No network, no git remote, no AI call.
#
# ===========================================================================
# WHAT THIS SUITE IS FOR
# ===========================================================================
#
# `consigne` claims to be backwards compatible with `fonde consign`. That claim
# is worth exactly as much as what observes it, and the thing being claimed is
# not a behaviour this repository can run: the mechanism lives in another
# project (bibliothecaire's lib/consign-prose.sh) and is not present in CI.
#
# So the claim is pinned WHERE IT IS ACTUALLY MADE -- at the call boundary.
# `bin/fonde`'s do_consign runs, verbatim:
#
#     bash "$impl" "$VAULT" "$@"
#
# Case B asserts that `consigne` produces the same three things: the same
# program, the same vault as its first argument, and the caller's paths after
# it, in order, unmangled. Case C asserts that whatever that program exits
# with is what `consigne` exits with -- every code in fonde's published
# contract, individually. Together those are the whole of "same inputs, same
# vault semantics, same exit codes where they carry meaning", because
# everything downstream of that call IS the same program.
#
# THE END-TO-END RUN AGAINST THE REAL MECHANISM IS NOT HERE, AND SAYING WHY IS
# PART OF THE TEST. It cannot be hermetic: it needs bibliothecaire installed.
# It was run by hand on mandark against the real lib/consign-prose.sh and the
# real `fonde` before this landed, and the verbatim output is in the pull
# request that added this file. Case D is the piece of that which CAN be
# hermetic -- that the resolver finds the mechanism at the place `fonde`
# carries it, from a fixture shaped exactly like an installed verb build.

set -uo pipefail
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
CONSIGNE="$REPO/bin/consigne"

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok    %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL  %s\n' "$1"; [ $# -gt 1 ] && printf '        %s\n' "$2"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "want [$3] got [$2]"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "not in output: $3" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1" "present but must not be: $3" ;; *) ok "$1" ;; esac; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# A PATH with nothing on it but coreutils. Without this, a host that has
# `fonde` or `installe` installed would let the resolver find the REAL
# mechanism, and every case below would be testing mandark instead of this
# tree. Case D puts its own fixture `fonde` back on it, deliberately.
mkdir -p "$TMP/emptybin"
BASE_PATH="$TMP/emptybin:/usr/bin:/bin"

echo "consigne.test.sh"
echo

# ===========================================================================
echo "-- A. THE ARGUMENT CONTRACT --------------------------------------------"
# ===========================================================================
OUT="$(PATH="$BASE_PATH" "$CONSIGNE" --help 2>&1)"; rc=$?
check "--help exits 0" "$rc" "0"
has   "--help names the old door it replaces" "$OUT" "fonde consign"
has   "--help names the status mode"          "$OUT" "consigne status"
has   "--help publishes the exit contract"    "$OUT" "7  refused"
has   "--help says it never pushes"           "$OUT" "NEVER PUSHES"

OUT="$(PATH="$BASE_PATH" "$CONSIGNE" 2>&1)"; rc=$?
check "no arguments is a usage error (2), not a silent no-op" "$rc" "2"

OUT="$(PATH="$BASE_PATH" "$CONSIGNE" --not-a-real-flag 2>&1)"; rc=$?
check "an unknown flag exits 2" "$rc" "2"
has   "...and names what it rejected" "$OUT" "--not-a-real-flag"

OUT="$(PATH="$BASE_PATH" "$CONSIGNE" -s foo 2>&1)"; rc=$?
check "a near-miss on the cost flag exits 2 rather than being ignored" "$rc" "2"
has   "...and says it is a near-miss on --summon" "$OUT" "near-miss"

OUT="$(PATH="$BASE_PATH" "$CONSIGNE" status --summon 2>&1)"; rc=$?
check "--summon on status is a usage error: status never spends" "$rc" "2"

# ===========================================================================
echo
echo '-- B. ONE IMPLEMENTATION: the call shape `fonde consign` makes ---------'
# ===========================================================================
# The recording stub IS the assertion. It writes its own argv to a file and
# exits 0. `bin/fonde` runs `bash "$impl" "$VAULT" "$@"`; if this records
# anything else, the two doors are two behaviours.
cat > "$TMP/rec-impl.sh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGV_LOG"
exit "${STUB_RC:-0}"
STUB
export ARGV_LOG="$TMP/argv.log"

VAULTDIR="$TMP/vault-b"; mkdir -p "$VAULTDIR"
OUT="$(PATH="$BASE_PATH" CONSIGNE_IMPL="$TMP/rec-impl.sh" BIBLIOTHECAIRE_VAULT="$VAULTDIR" \
       "$CONSIGNE" DOC.md docs/two.md 2>&1)"; rc=$?
check "a plain deposit forwards and succeeds" "$rc" "0"

GOT="$(cat "$ARGV_LOG" 2>/dev/null)"
WANT="$(printf '%s\n%s\n%s' "$VAULTDIR" "DOC.md" "docs/two.md")"
check "the mechanism is invoked as \`<impl> \$VAULT \$@\` -- fonde's own call shape" \
      "$GOT" "$WANT"

# The vault variable, not a new one. A `consigne` that invented CONSIGNE_VAULT
# would deposit somewhere else than `fonde consign` for the same caller.
check "the vault comes from BIBLIOTHECAIRE_VAULT, the variable fonde reads" \
      "$(head -1 "$ARGV_LOG")" "$VAULTDIR"

# Paths with spaces are one argument, not two. The old door passes "$@"; a
# front door that re-split them would corrupt exactly the filenames a prose
# reaping pass produces.
: > "$ARGV_LOG"
PATH="$BASE_PATH" CONSIGNE_IMPL="$TMP/rec-impl.sh" BIBLIOTHECAIRE_VAULT="$VAULTDIR" \
  "$CONSIGNE" "a file with spaces.md" >/dev/null 2>&1
check "a path with spaces stays one argument" \
      "$(sed -n '2p' "$ARGV_LOG")" "a file with spaces.md"

# --summon: accepted, buys nothing, says so, and still deposits. `fauche`
# prints `fonde consign --summon <file>` as its remedy for unconsigned prose.
: > "$ARGV_LOG"
OUT="$(PATH="$BASE_PATH" CONSIGNE_IMPL="$TMP/rec-impl.sh" BIBLIOTHECAIRE_VAULT="$VAULTDIR" \
       "$CONSIGNE" --summon DOC.md 2>&1)"; rc=$?
check "--summon is accepted and still deposits" "$rc" "0"
has   "--summon says plainly that nothing was spent" "$OUT" "nothing was spent"
check "--summon is not forwarded to the mechanism as a path" \
      "$(sed -n '2p' "$ARGV_LOG")" "DOC.md"

# ===========================================================================
echo
echo "-- C. THE EXIT CONTRACT, unwrapped -------------------------------------"
# ===========================================================================
# fonde publishes `0 kept  2 usage  5 broken  6 blind  7 refused`. Each is the
# mechanism's own code and must arrive at the caller unchanged -- a front door
# that collapsed 7 (refused, nothing was destroyed) into 5 (broken) would
# teach a caller to distrust the loudest code the vocabulary has.
for want in 0 2 5 6 7; do
  PATH="$BASE_PATH" CONSIGNE_IMPL="$TMP/rec-impl.sh" BIBLIOTHECAIRE_VAULT="$VAULTDIR" \
    STUB_RC="$want" "$CONSIGNE" DOC.md >/dev/null 2>&1
  check "exit $want reaches the caller unchanged" "$?" "$want"
done

# ===========================================================================
echo
echo "-- D. RESOLUTION: it finds the mechanism where fonde carries it --------"
# ===========================================================================
# A fixture shaped exactly like an installed verb build: bin/fonde on PATH,
# lib/consign-prose.sh one directory up from it. This is the layout
# `installe` produces and the one `bin/fonde` itself resolves against.
BUILD="$TMP/build/bibliothecaire"
mkdir -p "$BUILD/bin" "$BUILD/lib"
printf '#!/usr/bin/env bash\nexit 0\n' > "$BUILD/bin/fonde"; chmod +x "$BUILD/bin/fonde"
cp "$TMP/rec-impl.sh" "$BUILD/lib/consign-prose.sh"
: > "$ARGV_LOG"
OUT="$(PATH="$BUILD/bin:$BASE_PATH" BIBLIOTHECAIRE_VAULT="$VAULTDIR" \
       "$CONSIGNE" DOC.md 2>&1)"; rc=$?
check "with no CONSIGNE_IMPL it resolves through the installed fonde's tree" "$rc" "0"
check "...and reaches the mechanism that tree carries" \
      "$(sed -n '2p' "$ARGV_LOG")" "DOC.md"

# A missing mechanism is BLIND (6) and LOUD. This is the row that matters most
# in an estate whose recurring defect is the exit-0 no-op: a front door that
# could not find its own implementation must not report success.
OUT="$(PATH="$BASE_PATH" INSTALLE_PROJECTS="$TMP/no-such-projects" \
       BIBLIOTHECAIRE_VAULT="$VAULTDIR" "$CONSIGNE" DOC.md 2>&1)"; rc=$?
check "no mechanism anywhere is BLIND (6), not a silent success" "$rc" "6"
has   "...and names what it looked for" "$OUT" "consign-prose.sh"
has   "...and says nothing was deposited" "$OUT" "Nothing was deposited"

OUT="$(PATH="$BASE_PATH" CONSIGNE_IMPL="$TMP/does-not-exist.sh" \
       BIBLIOTHECAIRE_VAULT="$VAULTDIR" "$CONSIGNE" DOC.md 2>&1)"; rc=$?
check "an unreadable CONSIGNE_IMPL is BLIND (6), not ignored" "$rc" "6"

# ===========================================================================
echo
echo "-- E. STATUS: the half nothing consumed (hf7y/scheduler#86) ------------"
# ===========================================================================
# A fixture repo and a fixture vault, with one file in each of the three
# states the report distinguishes. The notes carry the same frontmatter the
# real mechanism writes, because that frontmatter is what `status` reads.
SRC="$TMP/src/scheduler"; mkdir -p "$SRC/docs"
VS="$TMP/vault-e/scheduler"; mkdir -p "$VS/docs"

note() { # <notefile> <repo> <relpath> <sha>
  { printf -- '---\n'
    printf 'source_repo: %s\n'   "$2"
    printf 'source_path: %s\n'   "$3"
    printf 'source_commit: %s\n' "0000000000000000000000000000000000000000"
    printf 'source_sha256: %s\n' "$4"
    printf 'consigned: 2026-08-01\n'
    printf 'project: scheduler\n'
    printf -- '---\n'
  } > "$1"
}

printf 'still here\nand unchanged\nthird line\n' > "$SRC/DESIGN-NOTES.md"
note "$VS/DESIGN-NOTES.md" "$SRC" "DESIGN-NOTES.md" \
     "$(sha256sum "$SRC/DESIGN-NOTES.md" | cut -d' ' -f1)"

printf 'edited since the deposit\n' > "$SRC/BLOCKERS.md"
note "$VS/BLOCKERS.md" "$SRC" "BLOCKERS.md" \
     "0000000000000000000000000000000000000000000000000000000000000000"

note "$VS/docs/gone.md" "$SRC" "docs/gone.md" \
     "1111111111111111111111111111111111111111111111111111111111111111"

printf 'not a note\n' > "$VS/no-frontmatter.md"

OUT="$(PATH="$BASE_PATH" BIBLIOTHECAIRE_VAULT="$TMP/vault-e" "$CONSIGNE" status 2>&1)"; rc=$?
check "status exits 0 when it could read everything" "$rc" "0"
has   "a file present and byte-identical is DUPLICATED" "$OUT" "DUPLICATED  scheduler/DESIGN-NOTES.md"
has   "...counted in lines, so the queue has a size"    "$OUT" "(3 lines)"
has   "a file present and changed is DIVERGED"          "$OUT" "DIVERGED    scheduler/BLOCKERS.md"
has   "...and says the vault copy is a stale fork"      "$OUT" "stale fork"
has   "a note with no usable provenance is UNREADABLE"  "$OUT" "UNREADABLE  scheduler/no-frontmatter.md"
has   "the counts are printed"                          "$OUT" "1 DUPLICATED (3 lines in both places), 1 DIVERGED, 1 REAPED, 1 UNREADABLE"
has   "...and prompted, not just counted"               "$OUT" "STILL IN THE REPO"
has   "the prompt names the judgement rather than making it" "$OUT" "PROSE-REAPING.md"

# THE ROW THAT KEEPS THIS FROM BECOMING A DELETER. scheduler#86 asks for the
# queue to be visible, not drained. Nothing may vanish.
if [ -f "$SRC/DESIGN-NOTES.md" ] && [ -f "$VS/DESIGN-NOTES.md" ] && [ -f "$SRC/BLOCKERS.md" ]; then
  ok "status removed nothing -- both copies of every row are still on disk"
else
  bad "status removed nothing" "a file is missing after a status run"
fi
hasnt "status offers no flag that would remove anything" \
      "$(PATH="$BASE_PATH" "$CONSIGNE" --help 2>&1)" "--remove"

# Scoping to one project, and a project that is not there.
OUT="$(PATH="$BASE_PATH" BIBLIOTHECAIRE_VAULT="$TMP/vault-e" "$CONSIGNE" status scheduler 2>&1)"; rc=$?
check "status takes a project name" "$rc" "0"
has   "...and reports it"           "$OUT" "DUPLICATED  scheduler/DESIGN-NOTES.md"

OUT="$(PATH="$BASE_PATH" BIBLIOTHECAIRE_VAULT="$TMP/vault-e" "$CONSIGNE" status nosuchproj 2>&1)"
has "a project absent from the vault is named, not silently skipped" "$OUT" "UNREADABLE  nosuchproj"

OUT="$(PATH="$BASE_PATH" BIBLIOTHECAIRE_VAULT="$TMP/no-such-vault" "$CONSIGNE" status 2>&1)"; rc=$?
check "status with no vault is BLIND (6), never 'nothing to report'" "$rc" "6"

# A vault whose projects are all clean must SAY so, not print an empty report
# that reads as "checked, nothing found" the same way a broken read does.
mkdir -p "$TMP/vault-clean/wtul"
note "$TMP/vault-clean/wtul/OLD.md" "$SRC" "docs/gone.md" \
     "2222222222222222222222222222222222222222222222222222222222222222"
OUT="$(PATH="$BASE_PATH" BIBLIOTHECAIRE_VAULT="$TMP/vault-clean" "$CONSIGNE" status 2>&1)"
has "a clean vault says so in words" "$OUT" "Nothing is sitting in both places"

# ===========================================================================
echo
echo "-- F. IT IS NOT A SECOND IMPLEMENTATION --------------------------------"
# ===========================================================================
# The defect this verb was rewritten to avoid, asserted against its own source.
# The first draft (#121, b81de52) copied files with `cp` and committed them,
# which produced vault notes with no provenance -- notes `status` above cannot
# classify at all. If any of these ever appear here, there are two deposits.
# COMMENTS ARE STRIPPED FIRST, and that is not a convenience. This very file,
# and the header of bin/consigne, both have to NAME the things being forbidden
# in order to explain why they are forbidden. Scanning the raw text makes the
# explanation trip the guard -- which is exactly what guard-estate check E's
# first draft did, firing on its own preamble within ten minutes of being
# written (bin/deferral-ledger.sh's header records it). So this reads CODE.
SRC_TEXT="$(grep -v '^[[:space:]]*#' "$CONSIGNE")"
hasnt "it does not run git push"   "$SRC_TEXT" "git push"
hasnt "it does not run git commit" "$SRC_TEXT" "git commit"
hasnt "it does not copy files into the vault itself" "$SRC_TEXT" 'cp -- "$src"'
has   "it forwards to the mechanism instead"         "$SRC_TEXT" 'bash "$IMPL" "$VAULT"'
# One vault variable across both doors, and no second name for the same fact.
hasnt "it invents no second name for the vault" "$SRC_TEXT" "CONSIGNE_VAULT"
# propagation-set.sh reserves resolving the pin path to two layout-owning
# scripts; this asks `fonde` and `installe` where they are instead.
hasnt "it does not re-derive the verb-build layout" "$SRC_TEXT" "verb-builds/current"

# --- the vault knob: flag beats env beats default ---------------------------
# Three sources for one fact, so the ORDER is the thing to assert. It was one
# hardcoded home until 2026-08-12; a knob whose precedence nobody checked would
# be the same defect wearing a flag.
: > "$ARGV_LOG"
VAULT_F="$TMP/vault-flag"; mkdir -p "$VAULT_F"
PATH="$BASE_PATH" CONSIGNE_IMPL="$TMP/rec-impl.sh" BIBLIOTHECAIRE_VAULT="$VAULTDIR" \
  "$CONSIGNE" --vault "$VAULT_F" DOC.md >/dev/null 2>&1
check "--vault beats BIBLIOTHECAIRE_VAULT" "$(head -1 "$ARGV_LOG")" "$VAULT_F"

: > "$ARGV_LOG"
PATH="$BASE_PATH" CONSIGNE_IMPL="$TMP/rec-impl.sh" BIBLIOTHECAIRE_VAULT="$VAULTDIR" \
  "$CONSIGNE" --vault="$VAULT_F" DOC.md >/dev/null 2>&1
check "--vault=PATH is the same knob" "$(head -1 "$ARGV_LOG")" "$VAULT_F"

OUT="$(PATH="$BASE_PATH" CONSIGNE_IMPL="$TMP/rec-impl.sh" "$CONSIGNE" --vault DOC.md 2>&1)"; rc=$?
check "--vault with no path is a usage error, not a silent deposit" "$rc" "2"

# The default is the FHS location, not a home directory. Asserted against the
# source rather than by running with a clean env, because running it would
# depend on whether this machine happens to have /srv/ecosystem1-vault.
has   "the default vault is /srv/ecosystem1-vault" "$SRC_TEXT" "VAULT_DEFAULT=/srv/ecosystem1-vault"
hasnt "no vault path under a home directory remains" "$SRC_TEXT" 'ecosystem1/ecosystem1'

echo
printf -- '--- consigne: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
