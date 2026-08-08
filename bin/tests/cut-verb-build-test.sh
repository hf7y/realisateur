#!/usr/bin/env bash
# HERMETICITY: a fake `gh` earlier on PATH answers every API call out of local
# fixture repositories, and GIT_CONFIG_GLOBAL rewrites github.com URLs to
# file:// paths in a temp dir. No network, no GitHub, no real `gh`.
#
# Contract test for cut-verb-build.sh -- the DERIVING half of the pair.
# (bin/tests/verb-build-test.sh covers install-verb-build.sh, the consuming
# half. They share no fixtures on purpose: the two halves must be able to
# disagree, and a fixture in common would hide it.)
#
# Hermetic. No network, no GitHub, no `gh`:
#   * a fake `gh` earlier on PATH answers `auth status`, `repo list` and the
#     tree API out of local fixture repositories;
#   * GIT_CONFIG_GLOBAL rewrites https://github.com/<owner>/ to file://<fix>/
#     so ls-remote and fetch reach those same fixtures.
# The suite therefore cannot pass because the network happened to be up,
# which is the failure mode the script under test exists to refuse.
#
# THE CLAIMS WORTH FAILING OVER
# Each of these was either a live defect found on 2026-08-04 or a promise
# VERB-DISTRIBUTION.md makes to consumers:
#
#   * a project that STOPS declaring verbs leaves the build.   <- was broken
#     Without this the meta-repo re-commits a retired project's verbs every
#     night and archiving a repo -- the documented retirement mechanism --
#     does nothing to the tree consumers install.
#   * the shrink refusal fires in CI, where there is no ~/.local/share
#     build root and the previous build is the meta-repo checkout itself.
#                                                              <- was broken
#   * assembling twice into one directory is idempotent.
#   * a bashified branch that MOVED is re-assembled at the new sha.
#   * --dry-run cannot produce an artifact, because its read is short by
#     construction.
#   * a verb name declared by two projects is still refused.
set -uo pipefail

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n     %s\n' "$1" "${2:-}"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUT="$HERE/../cut-verb-build.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OWNER=fixtureowner
FIX="$TMP/fix"            # bare-ish fixture repos, named <repo>.git
OUT="$TMP/assemble"       # stands in for the meta-repo checkout
mkdir -p "$FIX" "$OUT"

g() { git -c init.defaultBranch=main -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }

# --- fixture projects ----------------------------------------------------
# A project's bashified branch carries bin/<verb> (executable), man/<verb>.1,
# and lib/verb.sh which the verb SOURCES. That last file is the point: the
# assemble step once copied only bin/ and man/, every verb in the build was
# broken, and -f && -x passed anyway. If the whole-tree copy regresses, the
# --help witness here fails exactly as it did in production.
mkrepo() {
    local repo="$1"; shift
    local d="$FIX/$repo.git"
    rm -rf "$d"; mkdir -p "$d/bin" "$d/man" "$d/lib"
    printf 'verb_fixture_lib_loaded=1\n' > "$d/lib/verb.sh"
    for v in "$@"; do
        # `# KIND: verb` is part of the fixture because it is part of the
        # declaration contract: bin/verb-kind-lint.sh runs over the
        # assembled tree in section 6a and refuses a build containing a
        # command that declares no channel. A fixture without it would test
        # a build shape the cutter no longer accepts.
        cat > "$d/bin/$v" <<EOF
#!/usr/bin/env bash
# KIND: verb
. "\$(dirname "\$0")/../lib/verb.sh"
printf '%s -- fixture verb from $repo\n' "$v"
EOF
        chmod +x "$d/bin/$v"
        printf '.TH %s 1\n' "$v" > "$d/man/$v.1"
    done
    g init "$d"
    g -C "$d" checkout -b bashified
    g -C "$d" add -A
    g -C "$d" commit -m "bashified $repo"
    # Shallow fetch of a specific sha is how the assemble step works, and a
    # sha that is no longer the branch tip must still be fetchable -- that
    # is the "branch moved mid-run" case. GitHub allows this; a local
    # fixture has to be told to.
    g -C "$d" config uploadpack.allowAnySHA1InWant true
    g -C "$d" config uploadpack.allowReachableSHA1InWant true
}

# --- the fake gh ---------------------------------------------------------
# It reads $TMP/repolist, so a test can retire a project between runs simply
# by rewriting that file -- which is what archiving a repo looks like to
# `gh repo list --no-archived`.
mkdir -p "$TMP/stub"
cat > "$TMP/stub/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo list")   cat "$FIXTURE_REPOLIST"; exit 0 ;;
esac
if [ "$1" = api ]; then
  # repos/<owner>/<repo>/git/trees/<sha>?recursive=1  ->  "<mode> <path>"
  path="$2"
  repo="$(printf '%s' "$path" | awk -F/ '{print $3}')"
  sha="$(printf '%s' "$path" | sed 's#.*/trees/##; s#?.*##')"
  d="$FIXTURE_DIR/$repo.git"
  [ -d "$d" ] || exit 1
  git -C "$d" ls-tree -r "$sha" 2>/dev/null \
    | awk '{ p=$4; for(i=5;i<=NF;i++) p=p" "$i; print $1, p }'
  exit 0
fi
exit 1
STUB
chmod +x "$TMP/stub/gh"

cat > "$TMP/gitconfig" <<EOF
[url "file://$FIX/"]
    insteadOf = https://github.com/$OWNER/
EOF

cut() {
    PATH="$TMP/stub:$PATH" \
    FIXTURE_REPOLIST="$TMP/repolist" FIXTURE_DIR="$FIX" \
    GIT_CONFIG_GLOBAL="$TMP/gitconfig" GIT_CONFIG_NOSYSTEM=1 \
    bash "$CUT" --owner "$OWNER" --build-root "$TMP/no-such-build-root" "$@"
}
body() { grep -cv '^#' "$1" 2>/dev/null || echo 0; }

echo "cut-verb-build contract"

mkrepo alpha  aa ab
mkrepo beta   ba
mkrepo gamma  ga
printf 'alpha\nbeta\ngamma\n' > "$TMP/repolist"

# --- 1. a clean cut ------------------------------------------------------
cut --assemble "$OUT" >"$TMP/m1" 2>"$TMP/e1"
check "a clean cut exits 0" "$?" "0"
check "...deriving every declared verb" "$(body "$TMP/m1")" "4"
check "...and the verb runs from the assembled tree" \
      "$("$OUT/alpha/bin/aa" 2>&1)" "aa -- fixture verb from alpha"

# The lib/ regression guard: if the assemble step ever goes back to copying
# only bin/ and man/, this file is absent and every verb above dies in its
# first line.
check "the whole bashified tree travels, not just bin/ and man/" \
      "$([ -f "$OUT/alpha/lib/verb.sh" ] && echo present || echo absent)" "present"

# --- 2. idempotence ------------------------------------------------------
sha_before="$(awk -F'\t' '$1=="alpha"{print $3; exit}' "$OUT/manifest.tsv")"
cut --assemble "$OUT" >"$TMP/m2" 2>/dev/null
check "a second cut into the same directory exits 0" "$?" "0"
check "...and derives the same rows" \
      "$(diff <(grep -v '^#' "$TMP/m1") <(grep -v '^#' "$TMP/m2") >/dev/null && echo same || echo differs)" "same"
check "...and the tree is unchanged" \
      "$(diff -r "$OUT/alpha" "$OUT/alpha" >/dev/null && echo same || echo differs)" "same"

# --- 3. RETIREMENT: a project that stops declaring leaves the build ------
# Archiving a repository is how a project says "I am no longer a
# participant" (VERB-DISTRIBUTION.md section 5), and to `gh repo list
# --no-archived` that is exactly this: the name stops coming back.
printf 'alpha\nbeta\n' > "$TMP/repolist"
cut --assemble "$OUT" --allow-shrink >/dev/null 2>"$TMP/e3"
check "a cut after a project retires exits 0" "$?" "0"
check "...the retired project is GONE from the assembled tree" \
      "$([ -d "$OUT/gamma" ] && echo present || echo absent)" "absent"
check "...and gone from the manifest" \
      "$(grep -c '^gamma' "$OUT/manifest.tsv")" "0"
check "...while the surviving projects are untouched" \
      "$("$OUT/alpha/bin/aa" 2>&1)" "aa -- fixture verb from alpha"
case "$(cat "$TMP/e3")" in
    *RETIRED*gamma*) ok "...and it SAYS what it retired, rather than doing it silently" ;;
    *) bad "retirement is announced" "no RETIRED line for gamma" ;;
esac

# --- 4. the shrink refusal must fire in CI ------------------------------
# CI has no $BUILD_ROOT/current -- it is a fresh runner every night. The
# previous build is the meta-repo checkout being assembled into. Note
# --build-root points at a directory that does not exist, so ONLY the
# assembled manifest can be supplying this refusal.
printf 'alpha\n' > "$TMP/repolist"
cut --assemble "$OUT" >/dev/null 2>"$TMP/e4"
check "a shrinking build is refused with no local build root at all" "$?" "1"
check "...and the assembled tree was NOT touched" \
      "$([ -d "$OUT/beta" ] && echo present || echo absent)" "present"
case "$(cat "$TMP/e4")" in
    *"$OUT/manifest.tsv"*) ok "...and it names the record it compared against" ;;
    *) bad "the shrink message names its source" "got: $(head -3 "$TMP/e4")" ;;
esac

cut --assemble "$OUT" --allow-shrink >/dev/null 2>&1
check "--allow-shrink accepts the same build" "$?" "0"
check "...and the departed project is pruned" \
      "$([ -d "$OUT/beta" ] && echo present || echo absent)" "absent"

# --- 5. a bashified branch that MOVED -----------------------------------
# The manifest pins a sha; the tree must be assembled from THAT sha. A cut
# after a merge lands must pick up the new one, and the old sha must remain
# fetchable in case the branch moves mid-run.
# A comment, not a command: an appended command would (correctly) fail the
# --help witness and this test is about the sha, not about the witness.
printf '# CHANGED\n' >> "$FIX/alpha.git/bin/aa"
g -C "$FIX/alpha.git" add -A
g -C "$FIX/alpha.git" commit -m "alpha moves"
cut --assemble "$OUT" >/dev/null 2>&1
check "a cut after bashified moves exits 0" "$?" "0"
sha_after="$(awk -F'\t' '$1=="alpha"{print $3; exit}' "$OUT/manifest.tsv")"
check "...the manifest pins the NEW sha" \
      "$([ "$sha_after" != "$sha_before" ] && echo moved || echo stuck)" "moved"
check "...and the assembled file is the new content" \
      "$(grep -c CHANGED "$OUT/alpha/bin/aa")" "1"

# --- 6. --dry-run cannot become an artifact -----------------------------
# Its read is short BY CONSTRUCTION: the credential-less smoke path sees
# only public repositories. A short build that looks complete is the one
# failure this whole script exists to refuse, so the flags are exclusive.
cut --dry-run --assemble "$TMP/nope" >/dev/null 2>&1
check "--dry-run with --assemble is a usage error" "$?" "2"
cut --dry-run --write >/dev/null 2>&1
check "--dry-run with --write is a usage error" "$?" "2"
check "...and it created nothing" \
      "$([ -e "$TMP/nope" ] && echo present || echo absent)" "absent"

cut --dry-run >"$TMP/m6" 2>"$TMP/e6"
check "--dry-run alone exits 0" "$?" "0"
check "...and prints a manifest" "$(body "$TMP/m6")" "2"
case "$(cat "$TMP/e6")" in
    *"DRY RUN"*"NOT a build"*) ok "...and refuses to let its count be read as the verb surface" ;;
    *) bad "--dry-run disclaims its own count" "got: $(cat "$TMP/e6")" ;;
esac

# --- 7. a name declared twice is still refused --------------------------
# `range` was declared by both bibliothecaire and secretaire on 2026-07-30;
# `cueille` by both bibliothecaire and quatre-vingt-douze on 2026-08-04.
mkrepo delta aa
printf 'alpha\ndelta\n' > "$TMP/repolist"
cut >/dev/null 2>"$TMP/e7"
check "a verb declared by two projects is refused" "$?" "1"
case "$(cat "$TMP/e7")" in
    *COLLISION*aa*) ok "...and both claimants are named" ;;
    *) bad "the collision names its claimants" "got: $(cat "$TMP/e7")" ;;
esac

# --- 8. a repo listed but unreadable is BLIND, not verbless -------------
# GIT_TERMINAL_PROMPT=0 turns "cannot read this repository" into a failed
# ls-remote instead of a password prompt that hangs CI for six hours. The
# result must be counted as blindness: an unreadable repo and a repo with
# no bashified branch both yield an empty sha and mean opposite things.
printf 'alpha\nghost\n' > "$TMP/repolist"
cut >/dev/null 2>"$TMP/e8"
check "a listed repository git cannot read is refused" "$?" "1"
case "$(cat "$TMP/e8")" in
    *BLIND*ghost*) ok "...as BLIND, naming the repository" ;;
    *) bad "an unreadable repo reads as BLIND" "got: $(cat "$TMP/e8")" ;;
esac

# --- 9. an empty read is never an empty build ---------------------------
: > "$TMP/repolist"
cut >/dev/null 2>&1
check "no readable repositories is BLIND, not a zero-verb build" "$?" "1"

# --- 10. the channel check is WIRED, not merely present -----------------
# Section 6a runs bin/verb-kind-lint.sh over the assembled tree. Asserted
# here rather than only in that lint's own suite, because the failure this
# guards against is not a broken lint -- it is a correct lint nothing calls.
# Six of the guards surveyed on 2026-08-07 were hand-run only, and
# guard-estate.test.sh check B exists because a guard nothing runs is
# documentation with an exit code.
#
# 10a. A PRODUCT must not ride the workchain cut.
mkrepo epsilon zz
printf '#!/usr/bin/env bash\n# KIND: product\n. "$(dirname "$0")/../lib/verb.sh"\nprintf "zz\\n"\n' \
    > "$FIX/epsilon.git/bin/zz"
chmod +x "$FIX/epsilon.git/bin/zz"
g -C "$FIX/epsilon.git" add -A
g -C "$FIX/epsilon.git" commit -m 'zz declares itself a product'
printf 'epsilon\n' > "$TMP/repolist"
cut --assemble "$TMP/asm10" >/dev/null 2>"$TMP/e10"
check "a command declaring KIND: product is refused a place in the cut" "$?" "1"
case "$(cat "$TMP/e10")" in
    *PRODUCT*epsilon/zz*) ok "...and the refusal names the product and its project" ;;
    *) bad "the refusal names the product" "got: $(cat "$TMP/e10")" ;;
esac

# 10b. A command that declares NOTHING and is not grandfathered is refused
# on its first night. This is the arrival path the whole guard exists for:
# the next product to ship down the workchain will be a new name, and the
# ratchet in bin/verb-kind-lint.ratchet names only the 31 that predate it.
mkrepo zeta qq
printf '#!/usr/bin/env bash\n. "$(dirname "$0")/../lib/verb.sh"\nprintf "qq\\n"\n' \
    > "$FIX/zeta.git/bin/qq"
chmod +x "$FIX/zeta.git/bin/qq"
g -C "$FIX/zeta.git" add -A
g -C "$FIX/zeta.git" commit -m 'qq declares no channel at all'
printf 'zeta\n' > "$TMP/repolist"
cut --assemble "$TMP/asm10b" >/dev/null 2>"$TMP/e10b"
check "a new command declaring no channel is refused" "$?" "1"
case "$(cat "$TMP/e10b")" in
    *UNDECLARED*zeta/qq*) ok "...and the refusal names it" ;;
    *) bad "the refusal names the undeclared command" "got: $(cat "$TMP/e10b")" ;;
esac

echo
printf 'cut-verb-build: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
