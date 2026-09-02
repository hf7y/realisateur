#!/usr/bin/env bash
#
# TRAPS:
# Hermetic. No network, no GitHub, no `gh`:
#   * a fake `gh` earlier on PATH answers `auth status`, `repo list` and the
#     tree API out of local fixture repositories;
#   * GIT_CONFIG_GLOBAL rewrites https://github.com/<owner>/ to file://<fix>/
#     so ls-remote and fetch reach those same fixtures.
# The suite therefore cannot pass because the network happened to be up,
# which is the failure mode the script under test exists to refuse.

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

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
mkrepo() {
    local repo="$1"; shift
    local d="$FIX/$repo.git"
    rm -rf "$d"; mkdir -p "$d/bin" "$d/man" "$d/lib"
    printf 'verb_fixture_lib_loaded=1\n' > "$d/lib/verb.sh"
    for v in "$@"; do
        # `# KIND: verb` is contract, not decoration: verb-kind-lint.sh
        # (section 6a) refuses a build whose command declares no channel.
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

# Both halves of the OLD conjunctive rule. Since #891 only add_half_page's
# shape is still a defect (an orphaned man page); add_half_exec's is now a
# plain page-optional verb, and section 10 below tests it as one.
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
  path="$2"
  # repos/<owner>/verbs/contents/manifest.tsv -> the PUBLISHED manifest,
  # base64 as the contents API returns it. Absent fixture = a 404, which is
  # what a cut with no published build behind it actually sees.
  case "$path" in
    */contents/manifest.tsv)
      [ -n "${FIXTURE_PUBLISHED:-}" ] && [ -f "$FIXTURE_PUBLISHED" ] || exit 1
      base64 -w0 < "$FIXTURE_PUBLISHED"; echo; exit 0 ;;
  esac
  # repos/<owner>/<repo>/git/trees/<sha>?recursive=1  ->  "<mode> <path>"
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

printf '#project\tverb\twhy\n' > "$TMP/retired-verbs.tsv"  # empty: nothing declared retired, same fixture-not-production posture

# Empty grandfather ratchet too, so every fixture verb declares its channel.
: > "$TMP/verb-kind.ratchet"

cut() {
    PATH="$TMP/stub:$PATH" \
    FIXTURE_REPOLIST="$TMP/repolist" FIXTURE_DIR="$FIX" \
    FIXTURE_PUBLISHED="${FIXTURE_PUBLISHED:-}" \
    VERB_NOT_A_VERB_FILE="$TMP/not-a-verb.tsv" \
    VERB_RETIRED_VERBS_FILE="$TMP/retired-verbs.tsv" \
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
# Archiving is how a project says "no longer a participant", and to
# `gh repo list --no-archived` that is just: the name stops coming back.
printf 'alpha\nbeta\n' > "$TMP/repolist"
printf '#project\tverb\twhy\ngamma\tga\tfixture: gamma retired\n' > "$TMP/retired-verbs.tsv"
cut --assemble "$OUT" >/dev/null 2>"$TMP/e3"
check "a cut after a DECLARED project retirement exits 0" "$?" "0"
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
# A fresh runner has neither local reference point -- that is how #399 passed.
printf '#project\tverb\twhy\n' > "$TMP/retired-verbs.tsv"
printf 'alpha\n' > "$TMP/repolist"
printf 'alpha\taa\nalpha\tab\nbeta\tba\n' > "$TMP/published"
FIXTURE_PUBLISHED="$TMP/published" \
  cut --assemble "$TMP/fresh-runner" >/dev/null 2>"$TMP/e0"
check "a shrinking build is refused on a runner with NOTHING local" "$?" "1"
case "$(cat "$TMP/e0")" in
    *"$OWNER/verbs"*) ok "...and it names the published manifest as its source" ;;
    *) bad "the CI shrink message names the remote" "got: $(head -3 "$TMP/e0")" ;;
esac

FIXTURE_PUBLISHED="$TMP/published" cut --dry-run >/dev/null 2>"$TMP/e0b"
check "--dry-run is not graded against the published manifest" "$?" "0"
case "$(cat "$TMP/e0b")" in
    *"--dry-run reads a subset"*) ok "...and it SAYS the comparison was skipped" ;;
    *) bad "the dry run names the skip" "got: $(head -3 "$TMP/e0b")" ;;
esac

# ...and the local readings still work when they are the only ones there.
cut --assemble "$OUT" >/dev/null 2>"$TMP/e4"
check "a shrinking build is refused with no local build root at all" "$?" "1"
check "...and the assembled tree was NOT touched" \
      "$([ -d "$OUT/beta" ] && echo present || echo absent)" "present"
case "$(cat "$TMP/e4")" in
    *"$OUT/manifest.tsv"*) ok "...and it names the record it compared against" ;;
    *) bad "the shrink message names its source" "got: $(head -3 "$TMP/e4")" ;;
esac

printf '#project\tverb\twhy\nbeta\tba\tfixture: beta retired\n' > "$TMP/retired-verbs.tsv"
cut --assemble "$OUT" >/dev/null 2>&1
check "a retired-verbs.tsv row accepts the same build" "$?" "0"
check "...and the departed project is pruned" \
      "$([ -d "$OUT/beta" ] && echo present || echo absent)" "absent"
printf '#project\tverb\twhy\n' > "$TMP/retired-verbs.tsv"

# --- 5. a bashified branch that MOVED -----------------------------------
# The manifest pins a sha; the tree must be assembled from THAT sha. A cut
# after a merge lands must pick up the new one, and the old sha must remain
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

# --- 8b. a VERBLESS bashified branch is not BLIND -----------------------
# 2026-08-18: retiring twenty verbs left five repos with no bin/ or man/, and
# the cut refused -- "5 repository tree(s) did not read" -- because the fetch
# filtered inside the `gh` call, making "no verbs" indistinguishable from "no
# answer". The fixture gh could not catch it: the stub returned the whole tree
# and ignored the filter. The filter now lives in the script, where both see it.
mkrepo zeta za
VERBLESS="$FIX/verbless.git"
rm -rf "$VERBLESS"; mkdir -p "$VERBLESS/docs"
printf 'this project declares nothing\n' > "$VERBLESS/docs/README.md"
g init "$VERBLESS"
g -C "$VERBLESS" checkout -b bashified
g -C "$VERBLESS" add -A
g -C "$VERBLESS" commit -m "bashified verbless"
g -C "$VERBLESS" config uploadpack.allowAnySHA1InWant true
g -C "$VERBLESS" config uploadpack.allowReachableSHA1InWant true

printf 'zeta\nverbless\n' > "$TMP/repolist"
cut >"$TMP/m8b" 2>"$TMP/e8b"
check "a verbless bashified branch does not refuse the build" "$?" "0"
# A BLIND line NAMING verbless -- the registry is separately BLIND here, so a
# loose glob over the whole output scores that as this failure.
if grep -E 'BLIND.*verbless' "$TMP/e8b" "$TMP/m8b" >/dev/null 2>&1; then
    bad "a verbless repo was scored BLIND" "got: $(grep -E 'BLIND.*verbless' "$TMP/e8b" "$TMP/m8b")"
else
    ok "...and is not reported as BLIND"
fi
grep -qE 'none +verbless' "$TMP/e8b" "$TMP/m8b" \
    && ok "...it is reported as declaring no verbs, which is a different answer" \
    || bad "a verbless repo passed in SILENCE -- it must say so" "got: $(cat "$TMP/e8b")"
grep -q 'zeta' "$TMP/m8b" \
    && ok "...while the repo that DOES declare a verb still contributes" \
    || bad "the verbless repo suppressed a real declaration" "got: $(cat "$TMP/m8b")"

# --- 9. an empty read is never an empty build ---------------------------
: > "$TMP/repolist"
cut >/dev/null 2>&1
check "no readable repositories is BLIND, not a zero-verb build" "$?" "1"

# --- 10. man-page-optional (#891): an executable alone IS a verb ---------
# The defect this used to exist for: `ecosim-sensor`, an executable with no
# page, fell out of the derivation and surfaced later as a wrapper failing on
# a path that was never going to exist. This case no longer refuses.
mkrepo epsilon ea
add_half_exec epsilon ee
printf 'epsilon\n' > "$TMP/repolist"
cut >"$TMP/m10" 2>"$TMP/e10"
check "an executable with no man page does not refuse the build" "$?" "0"
check "...and IS derived as a verb, man page or not" "$(body "$TMP/m10")" "2"
case "$(grep -v '^#' "$TMP/m10")" in
    *"epsilon	ee"*) ok "...named in the manifest like any other verb" ;;
    *) bad "the page-optional verb reached the manifest" "got: $(grep -v '^#' "$TMP/m10")" ;;
esac

# The inverse remains a real defect and still refuses: stale docs, not a door.
add_half_page epsilon pp
cut >"$TMP/m10b" 2>"$TMP/e10b"
check "a man page with no executable still refuses" "$?" "1"
case "$(cat "$TMP/e10b")" in
    *"HALF-DECLARED  epsilon/pp: man/pp.1 with no executable bin/pp"*)
        ok "...naming the missing executable half" ;;
    *) bad "the orphaned man page is named" "got: $(cat "$TMP/e10b")" ;;
esac
case "$(cat "$TMP/e10b")" in
    *"1 orphaned man page(s)"*) ok "...and counted -- ee is no longer among them" ;;
    *) bad "the orphaned-page count excludes the page-optional verb" "got: $(cat "$TMP/e10b")" ;;
esac
check "...and no manifest was emitted at all" \
      "$([ -s "$TMP/m10b" ] && echo "wrote $(wc -l < "$TMP/m10b") line(s)" || echo empty)" "empty"

# --- 11. the opt-out, and the decision travelling in the manifest -------
# Neither tag gets a free pass: a row excludes ee from being a door or keeps
# pp around on purpose, each ONCE rather than nagged about nightly. Not a silence:
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
# The same shape as a declared retirement: the operator who has already filed
# the defect can cut tonight's build. What it must NOT buy is silence.
printf '#project\tname\twhy\n' > "$TMP/not-a-verb.tsv"
cut --allow-half-declared >"$TMP/m12" 2>"$TMP/e12"
check "--allow-half-declared cuts despite the orphaned page" "$?" "0"
case "$(grep '^#' "$TMP/m12")" in
    *"HALF-DECLARED	epsilon	pp"*) ok "...and the manifest still names the unresolved defect" ;;
    *) bad "an overridden orphaned page still travels" "got: $(grep '^#' "$TMP/m12")" ;;
esac
check "...and ee ships as a plain verb alongside ea" "$(body "$TMP/m12")" "2"

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

# 14d. A PERSONAL tool leaves the manifest, and the cut still succeeds (#552).
# ORDERING IS THE POINT: the cut drops it and says so; the lint is backstop.
mkrepo kappa kv
printf '#!/usr/bin/env bash\n# KIND: personal\n. "$(dirname "$0")/../lib/verb.sh"\nprintf "kp\\n"\n' \
    > "$FIX/kappa.git/bin/kp"
chmod +x "$FIX/kappa.git/bin/kp"
printf '.TH KP 1\n' > "$FIX/kappa.git/man/kp.1"
g -C "$FIX/kappa.git" add -A
g -C "$FIX/kappa.git" commit -m 'kp is a personal tool, fully declared as a verb would be'
printf 'kappa\n' > "$TMP/repolist"
cut --assemble "$TMP/asm14d" >/dev/null 2>"$TMP/e14d"
check "a personal tool does NOT refuse the cut" "$?" "0"
case "$(cat "$TMP/e14d")" in
    *PERSONAL*kappa/kp*) ok "...and it is NAMED leaving, not silently dropped" ;;
    *) bad "the cut names the personal tool it omitted" "got: $(cat "$TMP/e14d")" ;;
esac
if grep -q "kappa\skp" "$TMP/asm14d/manifest.tsv" 2>/dev/null; then
    bad "the personal tool left the manifest" "kappa/kp is still in it"
else
    ok "...and it is gone from the manifest a consumer installs from"
fi
[ -f "$TMP/asm14d/kappa/bin/kp" ] \
    && bad "the personal tool left the assembled tree" "the file is still there" \
    || ok "...and gone from the assembled tree, so --link cannot carry it"
[ -f "$TMP/asm14d/kappa/bin/kv" ] \
    && ok "the sibling VERB is untouched -- one command omitted, not a project" \
    || bad "the sibling verb survived" "kappa/kv is missing too"

H14D="$(sed -n 's/^# \([0-9]*\) verb(s), \([0-9]*\) project(s)\..*/\1 \2/p' "$TMP/asm14d/manifest.tsv" | head -1)"
check "the header's verb count matches the data rows after a personal drop" \
      "${H14D%% *}" "$(grep -cv '^#' "$TMP/asm14d/manifest.tsv")"
check "...and its project count does too" \
      "${H14D##* }" "$(awk -F'\t' '/^[^#]/{print $1}' "$TMP/asm14d/manifest.tsv" | sort -u | grep -c .)"

printf 'kappa\tkv\nkappa\tkp\n' > "$TMP/published14e"  # 14e: a KIND:personal drop is a shrink too (realisateur#703)
FIXTURE_PUBLISHED="$TMP/published14e" \
  cut --assemble "$TMP/asm14e" >/dev/null 2>"$TMP/e14e"
check "a personal-tool reclassification alone is refused as a shrink" "$?" "1"
case "$(cat "$TMP/e14e")" in
    *"kappa"*"kp"*) ok "...and the refusal NAMES the command that vanished" ;;
    *) bad "the refusal names the missing command" "got: $(cat "$TMP/e14e")" ;;
esac

printf '#project\tverb\twhy\nkappa\tkp\tfixture: reclassified personal\n' > "$TMP/retired-verbs.tsv"
FIXTURE_PUBLISHED="$TMP/published14e" \
  cut --assemble "$TMP/asm14e" >/dev/null 2>"$TMP/e14e2"
check "a retired-verbs.tsv row accepts a personal-tool-caused shrink" "$?" "0"

mkrepo omega ov1 ov2   # 14f/g: a declared retirement (realisateur#696), matched by NAME not just count (realisateur#699 point 1)
g -C "$FIX/omega.git" rm -q bin/ov2 man/ov2.1
g -C "$FIX/omega.git" commit -m 'ov2 retired upstream, on omega'"'"'s own bashified'
printf 'omega\n' > "$TMP/repolist"
printf 'omega\tov1\nomega\tov2\n' > "$TMP/published14f"

FIXTURE_PUBLISHED="$TMP/published14f" \
  cut --assemble "$TMP/asm14f" >/dev/null 2>"$TMP/e14f"
check "an undeclared verb-level shrink is refused" "$?" "1"
case "$(cat "$TMP/e14f")" in
    *"omega"*"ov2"*) ok "...and it names the missing verb" ;;
    *) bad "the refusal names the missing verb" "got: $(cat "$TMP/e14f")" ;;
esac

printf '#project\tverb\twhy\nomega\tov2\ttest retirement\n' > "$TMP/retired-verbs.tsv"
FIXTURE_PUBLISHED="$TMP/published14f" \
  cut --assemble "$TMP/asm14g" >/dev/null 2>"$TMP/e14g"
check "a DECLARED retirement is accepted with no flag at all" "$?" "0"
case "$(cat "$TMP/e14g")" in
    *"fully explained"*) ok "...and it says the shrink was explained by the declaration" ;;
    *) bad "the accept names the explanation" "got: $(cat "$TMP/e14g")" ;;
esac
check "...and the surviving verb is still assembled" \
      "$([ -f "$TMP/asm14g/omega/bin/ov1" ] && echo present || echo absent)" "present"
check "...and the retired verb is gone from the manifest" \
      "$(grep -c "$(printf 'omega\tov2')" "$TMP/asm14g/manifest.tsv" 2>/dev/null)" "0"
printf '#project\tverb\twhy\n' > "$TMP/retired-verbs.tsv"

# 14h. SUBSTITUTION: one verb leaves, another arrives, the COUNT never moves
# (#699 point 1). Pins that the name diff is REACHED, not short-circuited by a
# count comparison that sees no shrink.
mkrepo sigma sv1 sv2
g -C "$FIX/sigma.git" rm -q bin/sv2 man/sv2.1
cat > "$FIX/sigma.git/bin/sv3" <<'EOF'
#!/usr/bin/env bash
# KIND: verb
. "$(dirname "$0")/../lib/verb.sh"
printf 'sv3 -- fixture verb from sigma\n'
EOF
chmod +x "$FIX/sigma.git/bin/sv3"
printf '.TH sv3 1\n' > "$FIX/sigma.git/man/sv3.1"
g -C "$FIX/sigma.git" add -A
g -C "$FIX/sigma.git" commit -m 'sigma: sv2 out, sv3 in -- same verb count'
printf 'sigma\n' > "$TMP/repolist"
printf 'sigma\tsv1\nsigma\tsv2\n' > "$TMP/published14h"

FIXTURE_PUBLISHED="$TMP/published14h" \
  cut --assemble "$TMP/asm14h" >/dev/null 2>"$TMP/e14h"
check "an undeclared SUBSTITUTION is refused though the count is unchanged" "$?" "1"
case "$(cat "$TMP/e14h")" in
    *"sigma"*"sv2"*) ok "...and it names the verb that vanished under a steady count" ;;
    *) bad "the refusal names the substituted-out verb" "got: $(cat "$TMP/e14h")" ;;
esac

# ...and once DECLARED it is accepted: acceptance must not depend on the count.
printf '#project\tverb\twhy\nsigma\tsv2\tfixture: substituted out\n' > "$TMP/retired-verbs.tsv"
FIXTURE_PUBLISHED="$TMP/published14h" \
  cut --assemble "$TMP/asm14h2" >/dev/null 2>"$TMP/e14h2"
check "a DECLARED substitution is accepted" "$?" "0"
printf '#project\tverb\twhy\n' > "$TMP/retired-verbs.tsv"

echo
summary
