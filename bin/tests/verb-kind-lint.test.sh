#!/usr/bin/env bash
# verb-kind-lint.test.sh -- the suite for bin/verb-kind-lint.sh.
#
#
# WHY THE FIXTURES ARE BUILD TREES AND NOT MOCK FUNCTIONS
# The lint's whole subject is the relationship between a manifest row and
# the file that row points at. A mock that returns "declared" or
# "undeclared" would test the arithmetic and skip the only part that has
# ever been wrong here: which bytes on disk count as a declaration.
#
# usage: ./bin/tests/verb-kind-lint.test.sh
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="$REPO/bin/verb-kind-lint.sh"


WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- fixture helpers --------------------------------------------------------

# new_build <name> -- an empty build tree; prints its path.
new_build() {
  local d="$WORK/$1"
  rm -rf "$d"; mkdir -p "$d"
  {
    printf '# verb build %s\n' "$1"
    printf '# fixture\n'
    printf '# project\tverb\tsha\trepo_url\n'
  } > "$d/manifest.tsv"
  printf '%s\n' "$d"
}

# add_cmd <build> <project> <verb> <kind-marker-or-empty> [--deep]
# Writes the manifest row AND the executable it names. --deep puts the
# marker far below the header window, which must NOT count.
add_cmd() {
  local d="$1" p="$2" v="$3" marker="${4:-}" deep="${5:-}"
  local sha='0123456789abcdef0123456789abcdef01234567'
  printf '%s\t%s\t%s\thttps://github.com/hf7y/%s.git\n' "$p" "$v" "$sha" "$p" >> "$d/manifest.tsv"
  mkdir -p "$d/$p/bin"
  {
    printf '#!/usr/bin/env bash\n'
    printf '# %s -- a fixture command\n' "$v"
    if [ -n "$marker" ] && [ -z "$deep" ]; then printf '%s\n' "$marker"; fi
    local i
    if [ -n "$deep" ]; then
      for i in $(seq 1 120); do printf '# padding line %s\n' "$i"; done
      printf '%s\n' "$marker"
    fi
    printf 'exit 0\n'
  } > "$d/$p/bin/$v"
  chmod +x "$d/$p/bin/$v"
}

# ratchet <path> <line>... -- write a ratchet file for the lint to read.
write_ratchet() {
  local f="$1"; shift
  { printf '# fixture ratchet\n'; for l in "$@"; do printf '%s\n' "$l"; done; } > "$f"
}

# run_lint <build> [args...] -- sets OUT and RC. Not a subshell: an rc
# assigned inside `$( )` never reaches the caller, which is the bug
# guard-estate.test.sh records having died on.
run_lint() {
  local d="$1"; shift
  OUT="$(VERB_KIND_RATCHET="${RATCHET_FILE:-$WORK/empty.ratchet}" \
         timeout 60 bash "$LINT" --build "$d" "$@" 2>&1)"
  RC=$?
}

: > "$WORK/empty.ratchet"

# expect <label> <want-rc> <build> [args...]
expect() {
  local label="$1" want="$2" d="$3"; shift 3
  run_lint "$d" "$@"
  if [ "$RC" -eq "$want" ]; then ok "$label (rc=$RC)"
  else bad "$label: wanted rc=$want, got rc=$RC"; printf '%s\n' "$OUT" | sed 's/^/       | /'; fi
}

# --- 1. the clean case ------------------------------------------------------
echo "== 1. A BUILD IN WHICH EVERY COMMAND DECLARES ITSELF A VERB =="
b="$(new_build clean)"
add_cmd "$b" scheduler fx-arme  '# KIND: verb'
add_cmd "$b" scheduler fx-dose  '# KIND: verb'
add_cmd "$b" senechal  fx-lance '# KIND: verb'
expect "a fully-declared workchain build passes" 0 "$b"

# --- 2. THE VIOLATION THIS GUARD EXISTS FOR ---------------------------------
echo
echo "== 2. A PRODUCT RIDING THE WORKCHAIN BUILD =="
# This is the shape found on 2026-08-08: vim-arcade declares `fx-entraine` (a
# workchain verb, correctly in the build) and `vim-arcade` (the product,
# distributed as a verb because the verb build was the only channel that
# reached PATH). The product row is the violation; `fx-entraine` is not.
b="$(new_build product)"
add_cmd "$b" scheduler  fx-arme       '# KIND: verb'
add_cmd "$b" vim-arcade fx-entraine   '# KIND: verb'
add_cmd "$b" vim-arcade vim-arcade '# KIND: product'
expect "a command declaring KIND: product is refused a place in the workchain build" 1 "$b"
run_lint "$b"
if printf '%s\n' "$OUT" | grep -q 'vim-arcade/vim-arcade'; then
  ok "the refusal names the offending command"
else
  bad "the refusal does not name vim-arcade/vim-arcade"; printf '%s\n' "$OUT" | sed 's/^/       | /'
fi
# Not "fx-entraine is absent from the output" -- it is present, as an `ok` line,
# and it should be. The assertion is that it never appears on a FINDING line.
if printf '%s\n' "$OUT" | grep -E '^  (FLAG|PRODUCT|UNDECLARED|OWED)' | grep -q 'fx-entraine'; then
  bad "it flagged fx-entraine, which is a legitimate workchain verb"
else
  ok "the sibling workchain verb fx-entraine is NOT flagged"
fi
n="$(printf '%s\n' "$OUT" | grep -cE '^  (FLAG|PRODUCT|UNDECLARED)')"
if [ "$n" -eq 1 ]; then ok "exactly one violation, not a project-wide sweep"
else bad "expected exactly 1 violation line, got $n"; printf '%s\n' "$OUT" | sed 's/^/       | /'; fi

# --- 2b. the third kind (#552) ----------------------------------------------
echo
echo "== 2b. A PERSONAL TOOL RIDING THE VERB BUILD =="
# Before this there were two states -- distributed to all 13 accounts, or
# undeclared litter -- and `canon` sat in the second from 2026-08-05.
b="$(new_build personal)"
add_cmd "$b" scheduler   fx-arme    '# KIND: verb'
add_cmd "$b" vim-arcade  vim-arcade '# KIND: personal'
expect "a command declaring KIND: personal is refused a place in the verb build" 1 "$b"
run_lint "$b"
if printf '%s\n' "$OUT" | grep -q '^  PERSONAL vim-arcade/vim-arcade'; then
  ok "it is NAMED and not silently dropped -- a quiet removal reads as a short build"
else
  bad "the refusal does not name vim-arcade/vim-arcade as PERSONAL"; printf '%s\n' "$OUT" | sed 's/^/       | /'
fi
if printf '%s\n' "$OUT" | grep -E '^  (FLAG|PRODUCT|PERSONAL|UNDECLARED|OWED)' | grep -q 'fx-arme'; then
  bad "it flagged fx-arme, which is a legitimate verb"
else
  ok "the sibling verb is NOT flagged -- one violation, not a sweep"
fi

# THE MAN PAGE IS THE VERB CONTRACT, and this is not a verb.
b="$(new_build personal-no-man)"
add_cmd "$b" scheduler  fx-arme '# KIND: verb'
add_cmd "$b" space-canon canon   '# KIND: personal'
rm -f "$b/space-canon/man/canon.1" 2>/dev/null || true
run_lint "$b"
if printf '%s\n' "$OUT" | grep -qi 'man page.*canon\|canon.*man page'; then
  bad "a personal tool was asked for a man page"
else
  ok "a personal tool owes no man/<name>.1"
fi

# NOT RATCHETABLE, for the same reason a product is not: the ratchet forgives
# SILENCE, never a declaration that says outright it is on the wrong channel.
b="$(new_build personal-not-ratchetable)"
add_cmd "$b" scheduler  fx-arme    '# KIND: verb'
add_cmd "$b" vim-arcade vim-arcade '# KIND: personal'
RATCHET_FILE="$WORK/r3"; write_ratchet "$RATCHET_FILE" 'undeclared vim-arcade/vim-arcade'
expect "the ratchet cannot forgive a declared personal tool in the verb build" 1 "$b"
RATCHET_FILE=""

# The "not a channel" branch must stop claiming there are two.
b="$(new_build bogus-kind)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
add_cmd "$b" scheduler fx-dose '# KIND: LOCAL'
run_lint "$b"
if printf '%s\n' "$OUT" | grep -q "Say 'verb', 'product' or 'personal'"; then
  ok "a marker that is not a kind names all three, so the fix is in the message"
else
  bad "the not-a-kind message does not offer the third kind"; printf '%s\n' "$OUT" | sed 's/^/       | /'
fi

# --- 3. undeclared is a failure, never a default ----------------------------
echo
echo "== 3. A COMMAND THAT DECLARES NOTHING FAILS; IT DOES NOT DEFAULT =="
b="$(new_build undeclared)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
add_cmd "$b" mystery   thing ''
expect "an undeclared command is refused" 1 "$b"
run_lint "$b"
printf '%s\n' "$OUT" | grep -q 'mystery/thing' \
  && ok "the refusal names the undeclared command" \
  || bad "the refusal does not name mystery/thing"

# The dodge: a marker that exists but is not a kind.
b="$(new_build badkind)"
add_cmd "$b" scheduler fx-arme  '# KIND: verb'
add_cmd "$b" scheduler fx-dose  '# KIND: yes'
expect "'# KIND: yes' is not a declaration -- refused, not accepted" 1 "$b"

# The other dodge: a bare marker with nothing after it.
b="$(new_build emptykind)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
add_cmd "$b" scheduler fx-dose '# KIND:'
expect "a bare '# KIND:' with no value is refused" 1 "$b"

# And a marker buried below the header window is not a header declaration.
b="$(new_build deepkind)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
add_cmd "$b" scheduler fx-dose '# KIND: verb' --deep
expect "a KIND marker below the header window does not count" 1 "$b"

# --- 4. the ratchet ---------------------------------------------------------
echo
echo "== 4. THE GRANDFATHER RATCHET SHRINKS AND NEVER GROWS =="
# The 32 commands already in the build predate the declaration rule. A
# count-based bound would let a new undeclared command in whenever an old
# one was declared in the same pass; the ratchet therefore names the exact
# pairs it forgives, so a NEW undeclared name is refused on its first night
# regardless of how the count moved.
b="$(new_build grandfathered)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
add_cmd "$b" legacy    old  ''
RATCHET_FILE="$WORK/r1"; write_ratchet "$RATCHET_FILE" 'undeclared legacy/old'
expect "an undeclared command NAMED in the ratchet is tolerated" 0 "$b"
run_lint "$b"
printf '%s\n' "$OUT" | grep -q 'legacy/old' \
  && ok "it is still printed every run, not silently forgiven" \
  || bad "the grandfathered command is not reported at all"

add_cmd "$b" newcomer fresh ''
expect "a NEW undeclared command is refused even though an old one is forgiven" 1 "$b"
run_lint "$b"
printf '%s\n' "$OUT" | grep -q 'newcomer/fresh' \
  && ok "the refusal names the new arrival" \
  || bad "the refusal does not name newcomer/fresh"

# A ratchet entry for a command that now declares itself is stale, and
# leaving it there would silently re-forgive the name if it regressed.
b="$(new_build ratchet-stale)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
add_cmd "$b" legacy    old  '# KIND: verb'
RATCHET_FILE="$WORK/r1"
expect "a ratchet entry whose command now declares itself does not fail the build" 0 "$b"
run_lint "$b"
printf '%s\n' "$OUT" | grep -qi 'stale\|no longer' \
  && ok "the now-declared entry is reported as retirable" \
  || bad "nothing said the ratchet entry can be dropped"
RATCHET_FILE=""

# A product is NOT ratchetable: the ratchet forgives silence, never a
# declared product sitting in the workchain channel.
b="$(new_build product-not-ratchetable)"
add_cmd "$b" scheduler  fx-arme       '# KIND: verb'
add_cmd "$b" vim-arcade vim-arcade '# KIND: product'
RATCHET_FILE="$WORK/r2"; write_ratchet "$RATCHET_FILE" 'undeclared vim-arcade/vim-arcade'
expect "the ratchet cannot forgive a declared product in the workchain build" 1 "$b"
RATCHET_FILE=""

# --- 5. BLIND never grades clean --------------------------------------------
echo
echo "== 5. BLIND IS NOT CLEAN =="
expect "a build directory that does not exist is BLIND, not clean" 6 "$WORK/nope"

b="$(new_build nomanifest)"
rm -f "$b/manifest.tsv"
expect "a build tree with no manifest is BLIND, not clean" 6 "$b"

b="$(new_build emptymanifest)"
expect "a manifest with no rows is BLIND, not clean" 6 "$b"
# ...and it reaches that verdict by its OWN logic. `grep -c` prints 0 and
# exits 1 on no match, so a `|| echo 0` fallback made rows "0\n0" and the
# guard arrived at BLIND through a bash integer-expression error printed
# above its own admission. run_lint folds stderr in, so this sees it.
printf '%s\n' "$OUT" | grep -qE 'integer expression|line [0-9]+:' \
  && bad "BLIND on an empty manifest is reached via a shell error, not the check: $(printf '%s\n' "$OUT" | grep -E 'integer expression|line [0-9]+:' | head -1)" \
  || ok "the empty-manifest BLIND carries no shell error of its own"

# The row points at a file that is not there. That is not "declared
# nothing" -- it is a build this lint could not read, and it must not be
# graded either way.
b="$(new_build missingfile)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
add_cmd "$b" scheduler fx-dose '# KIND: verb'
rm -f "$b/scheduler/bin/fx-dose"
expect "a manifest row whose executable is absent is BLIND, not undeclared" 6 "$b"
run_lint "$b"
printf '%s\n' "$OUT" | grep -q 'BLIND' \
  && ok "it says BLIND out loud" \
  || bad "exit 6 with no BLIND in the output"

# E from guard-estate: the admission must come BEFORE the findings.
b="$(new_build blindfirst)"
add_cmd "$b" mystery   thing ''
add_cmd "$b" scheduler fx-dose  '# KIND: verb'
rm -f "$b/scheduler/bin/fx-dose"
run_lint "$b"
fb="$(printf '%s\n' "$OUT" | grep -nE '^[[:space:]]*BLIND[[:space:]:[]' | head -1 | cut -d: -f1)"
ff="$(printf '%s\n' "$OUT" | grep -nE '^[[:space:]]*(FLAG|UNDECLARED|PRODUCT)[[:space:]:[]' | head -1 | cut -d: -f1)"
if [ -z "$fb" ]; then
  bad "no BLIND line at all when a row could not be read"
elif [ -n "$ff" ] && [ "$fb" -gt "$ff" ]; then
  bad "the BLIND admission (line $fb) is buried under the first finding (line $ff)"
else
  ok "the BLIND admission is printed above the findings"
fi

# --- 6. exit code tracks findings -------------------------------------------
echo
echo "== 6. THE EXIT CODE TRACKS THE FINDINGS IT PRINTED =="
# The property guard-estate calls D, asserted here directly rather than only
# through the sandbox, because this is the guard's own suite and it can
# arrange both sides of the implication.
b="$(new_build tracks-clean)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
run_lint "$b"
c="$(printf '%s\n' "$OUT" | grep -oE '[0-9]+ violation' | grep -oE '^[0-9]+' | head -1)"; c="${c:-0}"
if [ "$RC" -eq 0 ] && [ "$c" -eq 0 ]; then ok "rc=0 with zero violations reported"
else bad "rc=$RC with $c violation(s) reported -- inconsistent"; fi

b="$(new_build tracks-dirty)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
add_cmd "$b" a b ''
add_cmd "$b" c d ''
run_lint "$b"
c="$(printf '%s\n' "$OUT" | grep -oE '[0-9]+ violation' | grep -oE '^[0-9]+' | head -1)"; c="${c:-0}"
if [ "$RC" -ne 0 ] && [ "$c" -eq 2 ]; then ok "rc=$RC and it reported exactly the 2 violations it found"
else bad "rc=$RC, reported $c violation(s), expected 2 and a non-zero rc"; printf '%s\n' "$OUT" | sed 's/^/       | /'; fi

# A PASSING RUN MAY NOT CLAIM MORE THAN IT CHECKED. The summary line used to
# say "N command(s), each declaring its channel" unconditionally -- including
# the live case where every row was grandfathered and NONE declared anything,
# printing that one line above "N command(s) still owed a declaration".
b="$(new_build honest-summary)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
add_cmd "$b" legacy    old  ''
RATCHET_FILE="$WORK/honest.ratchet"
write_ratchet "$RATCHET_FILE" 'undeclared legacy/old'
run_lint "$b"
unset RATCHET_FILE
if [ "$RC" -ne 0 ]; then
  bad "the grandfathered build did not exit 0 (rc=$RC)"
elif printf '%s\n' "$OUT" | grep -q 'each declaring its channel'; then
  bad "rc=0 with an entry still OWED, but the summary claims each command declares its channel"
else
  ok "with an entry still OWED, the summary does not claim every command declared"
fi
printf '%s\n' "$OUT" | grep -qE '1 (still )?OWED|1 command\(s\) still owed' \
  && ok "...and it still says how many are owed" \
  || bad "the summary dropped the owed count entirely: $(printf '%s\n' "$OUT" | tail -1)"

# The true form is still spoken when it IS true.
b="$(new_build honest-summary-clean)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
add_cmd "$b" scheduler fx-dose '# KIND: verb'
run_lint "$b"
printf '%s\n' "$OUT" | grep -q 'each declaring its channel' \
  && ok "when every command really does declare, the summary says so" \
  || bad "a genuinely clean build lost its summary line: $(printf '%s\n' "$OUT" | tail -1)"

# --- 7. the tree it is pointed at -------------------------------------------
echo
echo "== 7. IT HONOURS THE BUILD IT IS POINTED AT =="
b="$(new_build honours)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
run_lint "$b"
if printf '%s\n' "$OUT" | grep -qE '/home/[a-z][a-z0-9_-]*/\.local/share/verb-builds'; then
  bad "pointed at a temp build, it reported on the host's real build root"
  printf '%s\n' "$OUT" | sed 's/^/       | /'
else
  ok "no path under the host's real build root appears in the output"
fi

# --- 8. --accept may only shrink the ratchet --------------------------------
echo
echo "== 8. --accept LOWERS THE RATCHET OR REFUSES =="
b="$(new_build accept)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
add_cmd "$b" legacy    old  ''
RATCHET_FILE="$WORK/r3"; write_ratchet "$RATCHET_FILE" 'undeclared legacy/old' 'undeclared gone/away'
run_lint "$b" --accept
if [ "$RC" -eq 0 ] && ! grep -q 'gone/away' "$RATCHET_FILE"; then
  ok "--accept dropped the entry whose command left the build"
else
  bad "--accept did not drop the stale entry (rc=$RC)"; cat "$RATCHET_FILE" | sed 's/^/       | /'
fi
grep -q 'legacy/old' "$RATCHET_FILE" \
  && ok "--accept kept the entry that is still needed" \
  || bad "--accept dropped an entry that is still undeclared -- that is a raise in disguise"

# The move a ratchet exists to refuse.
b="$(new_build accept-grow)"
add_cmd "$b" scheduler fx-arme '# KIND: verb'
add_cmd "$b" brandnew  cmd  ''
RATCHET_FILE="$WORK/r4"; write_ratchet "$RATCHET_FILE" 'undeclared legacy/old'
run_lint "$b" --accept
if [ "$RC" -eq 0 ] && grep -q 'brandnew/cmd' "$RATCHET_FILE"; then
  bad "--accept ADDED a new undeclared command to the ratchet -- the ratchet can be grown by running the tool"
else
  ok "--accept refuses to enrol a newly-undeclared command (rc=$RC)"
fi
RATCHET_FILE=""

# --- 9. a whole manifest's shape, with one product declared -----------------
echo
echo "== 9. A 32-ROW MANIFEST, WITH ITS ONE PRODUCT DECLARED =="
# Verb names carry the fx- prefix so no fixture name is ever a real verb:
# a grep for a verb's callers must not count this file (#186). All 32 are
# given `# KIND: verb` except vim-arcade/vim-arcade -- `# KIND: product`, the
b="$(new_build real)"
while read -r p v; do
  [ -n "$p" ] || continue
  if [ "$p/$v" = "vim-arcade/vim-arcade" ]; then
    add_cmd "$b" "$p" "$v" '# KIND: product'
  else
    add_cmd "$b" "$p" "$v" '# KIND: verb'
  fi
done <<'ROWS'
baudin fx-loge
bibliothecaire fx-accroche
bibliothecaire fx-cueille
bibliothecaire fx-fonde
bibliothecaire fx-glane
bibliothecaire fx-range
bibliothecaire fx-trie
bibliothecaire fx-verse
crt fx-sonne
ecosim fx-sonde
gardien fx-fauche
gardien fx-garde
gardien fx-transplante
groc-mangr fx-mange
nine-speakers fx-chante
realisateur fx-arpente
realisateur fx-epluche
realisateur fx-juge
scheduler fx-arme
scheduler fx-dose
scheduler fx-jauge
scheduler fx-rapporte
scheduler fx-relis
senechal fx-ausculte
senechal fx-debarrasse
senechal fx-installe
senechal fx-lance
senechal fx-recense
senechal fx-veille
sequestria fx-capte
vim-arcade fx-entraine
vim-arcade vim-arcade
ROWS
rows="$(grep -cv '^#' "$b/manifest.tsv")"
[ "$rows" -eq 32 ] && ok "the fixture carries all 32 rows" || bad "fixture has $rows rows, expected 32"
run_lint "$b"
if [ "$RC" -eq 1 ]; then ok "the real manifest FAILS (rc=1)"
else bad "the real manifest did not fail: rc=$RC"; printf '%s\n' "$OUT" | sed 's/^/       | /'; fi
c="$(printf '%s\n' "$OUT" | grep -oE '[0-9]+ violation' | grep -oE '^[0-9]+' | head -1)"; c="${c:-0}"
if [ "$c" -eq 1 ]; then ok "exactly 1 violation over 32 commands in 12 projects"
else bad "expected exactly 1 violation, got $c"; printf '%s\n' "$OUT" | sed 's/^/       | /'; fi
printf '%s\n' "$OUT" | grep -q 'vim-arcade/vim-arcade' \
  && ok "the violation is vim-arcade/vim-arcade" \
  || bad "the single violation is not the product row"

# --- 10. the two opt-outs do not overlap ------------------------------------
echo
echo "== 10. THIS GUARD AND lib/not-a-verb.tsv GRADE DISJOINT POPULATIONS =="
# #145 landed bin/lib/not-a-verb.tsv the night before this guard: a curated
# list of executables that are deliberately not verbs. The reasonable review
# question is whether this guard should honour it instead of holding a second
# opinion about the same command. It cannot: not-a-verb.tsv exempts HALF
NAV="$REPO/bin/lib/not-a-verb.tsv"
if [ ! -f "$NAV" ]; then
  bad "bin/lib/not-a-verb.tsv is missing -- the file this guard's header reasons about"
else
  # A row is <project>\t<name>\t<why>; a ratchet entry is `undeclared
  # <project>/<verb>`. An intersection means one of the two files is wrong:
  # either an exemption is inert (the name is fully declared and IS in the
  # build) or a grandfather entry names something no build can contain.
  navkeys="$(awk -F'\t' '!/^[[:space:]]*#/ && NF>=2 && $1 != "" && $2 != "" {print $1 "/" $2}' "$NAV" | sort -u)"
  ratkeys="$(sed -n 's/^[[:space:]]*undeclared[[:space:]]\+//p' "$REPO/bin/verb-kind-lint.ratchet" | sort -u)"
  both="$(comm -12 <(printf '%s\n' "$navkeys") <(printf '%s\n' "$ratkeys") | tr '\n' ' ')"
  both="$(printf '%s' "$both" | sed 's/[[:space:]]*$//')"
  [ -z "$both" ] \
    && ok "no name is both a not-a-verb exemption and a grandfathered command" \
    || bad "these names are in BOTH lists, so one of the two files is wrong: $both"
fi

# And the shipped ratchet must still be a ratchet: every entry names a
# <project>/<verb> pair, never a bare count and never a project.
strays="$(sed -n 's/^[[:space:]]*undeclared[[:space:]]\+//p' "$REPO/bin/verb-kind-lint.ratchet" \
          | grep -vE '^[^/]+/[^/]+$' | tr '\n' ' ')"
[ -z "$strays" ] \
  && ok "every ratchet entry names a <project>/<verb> pair" \
  || bad "ratchet entries that are not <project>/<verb>: $strays"

# --- 11. the guard declares itself ------------------------------------------
echo
echo "== 11. THE GUARD SATISFIES THE ESTATE'S OWN CONTRACT =="
# guard-estate.test.sh derives its population by name shape and would pick
# `verb-kind-lint.sh` up on its own. Asserted here as well so a broken
# header fails the guard's OWN suite first, where the message is specific,
# rather than only in the estate sweep where it is one line among many.
for k in RUNNER GUARD-TEST GATE; do
  if head -n 90 "$LINT" | grep -qE "^#[[:space:]]*$k:[[:space:]]*[^[:space:]]"; then
    ok "declares '# $k:'"
  else
    bad "no '# $k:' line in the first 90 lines"
  fi
done

echo
echo "verb-kind-lint.test: $pass ok, $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
exit 0
