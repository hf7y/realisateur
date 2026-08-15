#!/usr/bin/env bash
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
#   * a HALF-declared name -- an executable bin/<n> with no man/<n>.1, or a
#     man/<n>.1 with no executable bin/<n> -- is NAMED and REFUSES the cut.
#                                                              <- was broken
#     It was omitted from every build in silence, which is how ecosim's
#     `ecosim-sensor` missed every build ever cut and surfaced weeks later,
#     on another host, as a wrapper failing on a path that never existed.
#   * the genuinely-not-a-verb case opts out by NAME in lib/not-a-verb.tsv,
#     and every such decision -- exempted or unresolved -- is written into the
#     MANIFEST, because the build is what travels to the accounts.
#   * every command in the ASSEMBLED tree declares its channel, and a
#     `# KIND: product` is refused a place in the workchain cut. That check
#     is bin/verb-kind-lint.sh and it is asserted here because the failure
#     mode is a correct lint nothing calls.
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

# HALF a declaration, both directions. The rule is a conjunction, so it has a
# difference as well as an intersection, and the difference is what used to be
# computed and thrown away in the same awk statement.
add_half_exec() {   # executable bin/<n>, no man page
    local repo="$1" n="$2" d="$FIX/$1.git"
    printf '#!/usr/bin/env bash\nprintf %%s\\\\n %s\n' "$n" > "$d/bin/$n"
    chmod +x "$d/bin/$n"
    g -C "$d" add -A
    g -C "$d" commit -m "half: bin/$n with no page"
}
add_half_page() {   # man/<n>.1, no executable
    local repo="$1" n="$2" d="$FIX/$1.git"
    printf '.TH %s 1\n' "$n" > "$d/man/$n.1"
    g -C "$d" add -A
    g -C "$d" commit -m "half: man/$n.1 with no executable"
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

# The not-a-verb opt-out is pointed at a FIXTURE file, never the repository's
# own bin/lib/not-a-verb.tsv: a suite that read the shipped exemptions would
# change its own answers whenever a project earned a row, which is the hermetic
# equivalent of testing against production. Empty here means nothing is exempt.
printf '#project\tname\twhy\n' > "$TMP/not-a-verb.tsv"

# And the channel guard's grandfather ratchet, for the same reason. Section
# 6a runs bin/verb-kind-lint.sh over the assembled tree, and that lint reads
# bin/verb-kind-lint.ratchet -- 33 real commands this suite knows nothing
# about. Empty here means nothing is grandfathered, so every fixture verb
# must declare its channel exactly as a real one must.
: > "$TMP/verb-kind.ratchet"

cut() {
    PATH="$TMP/stub:$PATH" \
    FIXTURE_REPOLIST="$TMP/repolist" FIXTURE_DIR="$FIX" \
    VERB_NOT_A_VERB_FILE="$TMP/not-a-verb.tsv" \
    VERB_KIND_RATCHET="$TMP/verb-kind.ratchet" \
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

# --- 10. a HALF-declaration is named, and refuses -----------------------
# The defect this pair of cases exists for: `ecosim-sensor` was an executable
# with no page on a bashified branch, so it fell out of the END loop, then
# `[ -n "$verbs" ] || continue` skipped the project, and no count, name or
# manifest row said anything. It was missing from every build ever cut, and
# what a host saw instead was `WRAPPER_NO_SENSOR` -- a symptom that reads as a
# stale build (realisateur#66) and is nothing of the kind.
mkrepo epsilon ea
add_half_exec epsilon ee
printf 'epsilon\n' > "$TMP/repolist"
cut >"$TMP/m10" 2>"$TMP/e10"
check "an executable with no man page refuses the build" "$?" "1"
case "$(cat "$TMP/e10")" in
    *"HALF-DECLARED  epsilon/ee"*) ok "...and NAMES the project and the executable" ;;
    *) bad "the half-declaration is named" "got: $(cat "$TMP/e10")" ;;
esac
case "$(cat "$TMP/e10")" in
    *"no man/ee.1"*) ok "...and says which half is missing" ;;
    *) bad "the half-declaration says which half" "got: $(cat "$TMP/e10")" ;;
esac
check "...and no manifest was emitted at all" \
      "$([ -s "$TMP/m10" ] && echo "wrote $(wc -l < "$TMP/m10") line(s)" || echo empty)" "empty"

# The inverse is equally a half-declaration and was equally silent.
add_half_page epsilon pp
cut >/dev/null 2>"$TMP/e10b"
check "a man page with no executable also refuses" "$?" "1"
case "$(cat "$TMP/e10b")" in
    *"HALF-DECLARED  epsilon/pp: man/pp.1 with no executable bin/pp"*)
        ok "...naming the missing executable half" ;;
    *) bad "the inverse half-declaration is named" "got: $(cat "$TMP/e10b")" ;;
esac
case "$(cat "$TMP/e10b")" in
    *"2 HALF-declared name(s)"*) ok "...and both halves are counted, not just the first" ;;
    *) bad "every half-declaration is counted" "got: $(cat "$TMP/e10b")" ;;
esac

# --- 11. the opt-out, and the decision travelling in the manifest -------
# An installer is not a verb and must not be nagged about forever; a row in
# lib/not-a-verb.tsv is how a project says so ONCE. The row is not a silence:
# what it buys is a line in the manifest instead of a refusal, because "what
# did this build decide not to include, and why" belongs with the artifact
# every account consumes, not on the terminal of whoever ran the cut.
printf 'epsilon\tee\tfixture installer, not a verb\nepsilon\tpp\tfixture stray page\n' \
    > "$TMP/not-a-verb.tsv"
cut >"$TMP/m11" 2>"$TMP/e11"
check "an exempted name does not refuse the build" "$?" "0"
case "$(grep '^#' "$TMP/m11")" in
    *"NOT-A-VERB	epsilon	ee"*) ok "...and the MANIFEST records what was left out" ;;
    *) bad "the manifest carries the decision" "got: $(grep '^#' "$TMP/m11")" ;;
esac
case "$(grep '^#' "$TMP/m11")" in
    *"fixture installer, not a verb"*) ok "...with the recorded reason, not only the name" ;;
    *) bad "the manifest carries the reason" "got: $(grep '^#' "$TMP/m11")" ;;
esac
check "...and the project's real verb is still derived" "$(body "$TMP/m11")" "1"

# --- 12. --allow-half-declared cuts, and still tells the consumer -------
# The same shape as --allow-shrink: the operator who has already filed the
# defect can cut tonight's build. What it must NOT buy is silence.
printf '#project\tname\twhy\n' > "$TMP/not-a-verb.tsv"
cut --allow-half-declared >"$TMP/m12" 2>"$TMP/e12"
check "--allow-half-declared cuts despite the half-declarations" "$?" "0"
case "$(grep '^#' "$TMP/m12")" in
    *"HALF-DECLARED	epsilon	ee"*) ok "...and the manifest still names the unresolved defect" ;;
    *) bad "an overridden half-declaration still travels" "got: $(grep '^#' "$TMP/m12")" ;;
esac
check "...and the verb rows are unaffected by the comment rows" "$(body "$TMP/m12")" "1"

# --- 13. the SHIPPED opt-out file is data the build reads every night ---
# A row missing its reason column is an exemption nobody can review, and it
# would be read on a live cut, not here.
REAL_NAV="$HERE/../lib/not-a-verb.tsv"
check "the shipped lib/not-a-verb.tsv exists" \
      "$([ -f "$REAL_NAV" ] && echo present || echo absent)" "present"
check "...and every row is <project><TAB><name><TAB><why>" \
      "$(awk -F'\t' '!/^[[:space:]]*#/ && $0 != "" && (NF < 3 || $1 == "" || $2 == "" || $3 == "") {n++} END {print n+0}' "$REAL_NAV")" \
      "0"

# --- 14. the CHANNEL check is WIRED, not merely present -----------------
# Section 6a runs bin/verb-kind-lint.sh over the tree this script just
# assembled. Asserted here rather than only in that lint's own suite,
# because the failure being guarded against is not a broken lint -- it is a
# correct lint nothing calls. guard-estate.test.sh check B exists for
# exactly that, and six of the guards surveyed on 2026-08-07 were hand-run
# only.
#
# The population is DISJOINT from sections 10-13 above and that is the whole
# relationship between the two files. lib/not-a-verb.tsv exempts a HALF
# declaration -- bin/<n> with no man/<n>.1 -- which by construction never
# reaches the manifest. verb-kind-lint grades manifest rows, i.e. names that
# carried BOTH halves. No name can be in both populations, so the channel
# check reads no exemption file: there is nothing in one for it to find.
#
# 14a. A PRODUCT must not ride the workchain cut.
mkrepo theta tv
printf '#!/usr/bin/env bash\n# KIND: product\n. "$(dirname "$0")/../lib/verb.sh"\nprintf "tv\\n"\n' \
    > "$FIX/theta.git/bin/tv"
chmod +x "$FIX/theta.git/bin/tv"
g -C "$FIX/theta.git" add -A
g -C "$FIX/theta.git" commit -m 'tv declares itself a product'
printf 'theta\n' > "$TMP/repolist"
cut --assemble "$TMP/asm14a" >/dev/null 2>"$TMP/e14a"
check "a command declaring KIND: product is refused a place in the cut" "$?" "1"
case "$(cat "$TMP/e14a")" in
    *PRODUCT*theta/tv*) ok "...and the refusal names the product and its project" ;;
    *) bad "the refusal names the product" "got: $(cat "$TMP/e14a")" ;;
esac

# 14b. A command that declares NOTHING and is not grandfathered is refused
# on its first night. This is the arrival path the whole guard exists for:
# the next product to ship down the workchain will be a NEW name, and the
# ratchet in bin/verb-kind-lint.ratchet names only the ones that predate it.
mkrepo iota iq
printf '#!/usr/bin/env bash\n. "$(dirname "$0")/../lib/verb.sh"\nprintf "iq\\n"\n' \
    > "$FIX/iota.git/bin/iq"
chmod +x "$FIX/iota.git/bin/iq"
g -C "$FIX/iota.git" add -A
g -C "$FIX/iota.git" commit -m 'iq declares no channel at all'
printf 'iota\n' > "$TMP/repolist"
cut --assemble "$TMP/asm14b" >/dev/null 2>"$TMP/e14b"
check "a new command declaring no channel is refused" "$?" "1"
case "$(cat "$TMP/e14b")" in
    *UNDECLARED*iota/iq*) ok "...and the refusal names it" ;;
    *) bad "the refusal names the undeclared command" "got: $(cat "$TMP/e14b")" ;;
esac

# 14c. ...and the grandfather ratchet is honoured THROUGH the wiring, not
# only when the lint is run by hand. Every one of the commands in tonight's
# build predates this rule; if the ratchet did not reach section 6a the
# nightly cut would refuse the whole ecosystem on the first night, which is
# how a check nobody can make green gets deleted instead of satisfied.
printf 'undeclared iota/iq\n' > "$TMP/verb-kind.ratchet"
cut --assemble "$TMP/asm14c" >/dev/null 2>"$TMP/e14c"
check "a grandfathered undeclared command does not refuse the cut" "$?" "0"
case "$(cat "$TMP/e14c")" in
    *OWED*iota/iq*) ok "...and it is still printed as OWED on every cut" ;;
    *) bad "a forgiven entry stays visible" "got: $(cat "$TMP/e14c")" ;;
esac
: > "$TMP/verb-kind.ratchet"

echo
printf 'cut-verb-build: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
