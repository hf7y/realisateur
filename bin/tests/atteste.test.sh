#!/usr/bin/env bash
# atteste.test.sh -- offline: --body grades a fixture tree, subject mode a
# fake `gh` in $T. Nothing here touches the network.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/atteste.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp
echo "atteste.test.sh"

mkdir -p "$T/tree/bin/lib" "$T/tree/docs"
: > "$T/tree/bin/real.sh"; : > "$T/tree/bin/lib/real.tsv"; : > "$T/tree/gardien.py"

body() {  # body <delivers-line>... -- a minimal compliant body on stdout
  printf 'NO-DECISION: fixture\n\n<!-- DELIVERS -->\n'
  local l; for l in "$@"; do printf -- '- %s\n' "$l"; done
  printf '<!-- /DELIVERS -->\n'
}
runbody() {  # runbody <delivers-line>... -- OUT/RC
  body "$@" > "$T/b.md"
  OUT="$(ATTESTE_ROOT="$T/tree" "$SCRIPT" --body "$T/b.md" 2>&1)"; RC=$?
}

section "A. the argument contract"
"$SCRIPT" --not-a-real-flag >/dev/null 2>&1;  rc "A1 unknown flag exits 2" 2 $?
"$SCRIPT" >/dev/null 2>&1;                    rc "A2 no subject at all exits 2" 2 $?
"$SCRIPT" --body >/dev/null 2>&1;             rc "A3 --body with no file exits 2" 2 $?
"$SCRIPT" --help >/dev/null 2>&1;             rc "A4 --help exits 0" 0 $?
O="$("$SCRIPT" --help 2>&1)"
has "A5 --help documents the BLIND exit" "$O" "6  BLIND"
has "A6 --help documents the GAP exit" "$O" "4  GAP"
O="$(ATTESTE_ROOT="$T/tree" "$SCRIPT" --body "$T/b.md" extra 2>&1)"; \
  rc "A7 --body plus a subject is a usage error" 2 $?

section "B. a path claim is looked up, not believed"
runbody 'path:bin/real.sh -- the thing'
has "B1 a path that is there is SATISFIED" "$OUT" "SATISFIED path:bin/real.sh"
rc  "B2 and the run exits 0" 0 $RC
has "B3 and it says every checked claim holds" "$OUT" "Every claim that could be checked holds"

runbody 'path:bin/absent.sh -- the thing'
has "B4 a path that is NOT there is a GAP" "$OUT" "GAP       path:bin/absent.sh"
rc  "B5 and the run exits 4" 4 $RC

runbody 'path:docs -- a directory counts'
has "B6 a directory is a delivery too" "$OUT" "SATISFIED path:docs"

runbody 'path:bin/real.sh' 'path:bin/absent.sh'
has "B7 one gap among satisfied claims still reports the gap" "$OUT" "GAP       path:bin/absent.sh"
rc  "B8 and a single gap decides the exit" 4 $RC

section "C. the kinds that cannot be checked from here are BLIND, never OK"
runbody 'repo:hf7y/realisateur -- one ledger answers built/armed/shipped'
has "C1 repo: alone is BLIND" "$OUT" "BLIND     repo:hf7y/realisateur alone"
has "C2 and says why a bare repo proves nothing" "$OUT" "proves no delivery"
rc  "C3 and an unfalsifiable claim never exits 0" 6 $RC

runbody 'unit:bibliothecaire-intake.timer on mandark'
has "C4 unit: is BLIND and says no predicate exists" "$OUT" "no predicate was written for it"
rc  "C5 and exits 6" 6 $RC

runbody 'clock:19 7 * * 1 on monkey'
has "C6 clock: is BLIND too" "$OUT" "BLIND"
runbody 'port:8080 on dexter'
has "C7 port: is BLIND too" "$OUT" "BLIND"

runbody 'path:/usr/local/bin/gh -- no host named'
has "C8 an absolute path naming no host asked no machine" "$OUT" "names an absolute path and no host"
rc  "C9 and is BLIND, not satisfied" 6 $RC

SELFDEV_LOCAL_HOSTNAME=notmonkey runbody 'path:/usr/local/bin/gh on monkey'
OUT="$(SELFDEV_LOCAL_HOSTNAME=notmonkey ATTESTE_ROOT="$T/tree" "$SCRIPT" --body "$T/b.md" 2>&1)"; RC=$?
has "C10 a host path is BLIND when this run is not that host" "$OUT" "this run is not monkey"
rc  "C11 and exits 6" 6 $RC

body 'path:/atteste-fixture-absent on fixturehost' > "$T/b.md"
OUT="$(SELFDEV_LOCAL_HOSTNAME=fixturehost ATTESTE_ROOT="$T/tree" "$SCRIPT" --body "$T/b.md" 2>&1)"; RC=$?
has "C12 ON the named host an absent path IS a gap" "$OUT" "is absent on fixturehost, and this run IS fixturehost"
rc  "C13 and exits 4" 4 $RC

runbody 'path:bin/real.sh -- this one is checkable' 'repo:hf7y/realisateur -- this one is not'
has "C14 a satisfied claim is still reported beside a blind one" "$OUT" "SATISFIED path:bin/real.sh"
has "C15 and the blind one is still named" "$OUT" "BLIND     repo:hf7y/realisateur"
rc  "C16 A SATISFIED CLAIM NEVER LAUNDERS A BLIND ONE INTO A PASS" 6 $RC
has "C17 and the run refuses to call a partial look clean" "$OUT" 'NOT "the claims hold"'

section "D. the parse the first measurement taught (37 claims read MISSING)"
runbody 'path:bin/real.sh, and the rest of the sentence'
has "D1 a trailing comma is punctuation, not part of the path" "$OUT" "SATISFIED path:bin/real.sh"
runbody 'path:`bin/real.sh` in a code span'
has "D2 a code span is stripped" "$OUT" "SATISFIED path:bin/real.sh"
runbody 'path:gardien.py,test_gardien.py -- two paths in one entry'
has "D3 a comma-joined pair grades the first, not the joined string" "$OUT" "SATISFIED path:gardien.py"
runbody 'path:docs/ -- a trailing slash'
has "D4 a trailing slash is still that directory" "$OUT" "SATISFIED path:docs"
runbody 'path:origin/bashified:lib/sprint-common.sh'
has "D5 a git ref is not a path in one tree" "$OUT" "is a git ref"
runbody 'path:bin/real.sh on this repo default branch'
has "D6 \"on this ...\" is prose, not a hostname" "$OUT" "SATISFIED path:bin/real.sh"
runbody 'repo:hf7y/senechal path:bin/real.sh -- repo: scopes the path'
has "D7 a repo: beside a path: does not make the entry unfalsifiable" "$OUT" "path:bin/real.sh"
runbody 'the propagation row stops grading NO_CHANGE nights DOWN'
has "D8 an entry naming no kind is BLIND, not a pass" "$OUT" "UNTYPED"
rc  "D9 and exits 6" 6 $RC

section "E. none is honest, and honest is not a pass"
runbody 'none'
has "E1 \"- none\" claims nothing" "$OUT" "checked 0 claim(s)"
rc  "E2 and a body claiming nothing was not verified, so 6" 6 $RC

printf 'NO-DECISION: fixture\n\nno ledger at all\n' > "$T/b.md"
OUT="$(ATTESTE_ROOT="$T/tree" "$SCRIPT" --body "$T/b.md" 2>&1)"; RC=$?
has "E3 a body with no DELIVERS block is BLIND" "$OUT" "no DELIVERS block at all"
rc  "E4 and exits 6" 6 $RC

OUT="$(ATTESTE_ROOT="$T/tree" "$SCRIPT" --body "$T/nope.md" 2>&1)"; RC=$?
rc  "E5 an unreadable body exits 6, not 0" 6 $RC
OUT="$(ATTESTE_ROOT="$T/not-a-dir" "$SCRIPT" --body "$T/b.md" 2>&1)"; RC=$?
rc  "E6 no tree to look in exits 6" 6 $RC

section "F. subject mode: WHICH ref a claim is graded at"
cat > "$T/gh" <<'EOF'
#!/usr/bin/env bash
case "$2" in
  */issues/*)     cat "$FIX/issue" ;;
  */pulls/*/files*) cat "$FIX/files" 2>/dev/null || : ;;
  */pulls/*)      cat "$FIX/pull" ;;
  repos/*/*)
    case "$2" in */contents/*) ;; *)
      case " ${UNREADABLE_REPOS:-} " in *" ${2#repos/} "*) exit 1 ;; esac
      exit 0 ;;
    esac ;;&
  */contents/*)
    p="${2#*/contents/}"; ref="${p#*\?ref=}"; p="${p%%\?*}"
    case "$2" in *'?ref='*) ;; *) ref=default ;; esac
    if [ -e "$FIX/at-$ref/$p" ]; then
      # The contents API returns an ARRAY for a directory: a caller reading
      # `--jq .name` loses every one, so the fake must lose it too.
      for a in "$@"; do [ "$a" = --jq ] && [ -d "$FIX/at-$ref/$p" ] && exit 1; done
      exit 0
    fi
    if [ -n "${GH_OUTAGE:-}" ]; then echo "connection refused" >&2; exit 1; fi
    echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
esac
EOF
chmod +x "$T/gh"
mkdir -p "$T/fix/at-mergesha1" "$T/fix/at-headsha2" "$T/fix/at-default"
: > "$T/fix/at-mergesha1/BUILD-DISCIPLINE.md"     # true at the merge commit
: > "$T/fix/at-headsha2/onbranch.md"              # only on an open PR's head
: > "$T/fix/at-default/onmain.md"                 # only on the default branch
printf 'https://api/pulls/1\n' > "$T/fix/issue"
body 'path:BUILD-DISCIPLINE.md' >> "$T/fix/issue"
printf 'merged\nmergesha1\nheadsha2\n' > "$T/fix/pull"
OUT="$(ATTESTE_GH="$T/gh" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#675 2>&1)"; RC=$?
has "F1 a MERGED PR is graded at its merge commit" "$OUT" "merged PR, graded at merge commit mergesha"
has "F2 so a claim true at merge and deleted later still holds" "$OUT" "SATISFIED path:BUILD-DISCIPLINE.md"
rc  "F3 and exits 0" 0 $RC

printf 'open\n-\nheadsha2\n' > "$T/fix/pull"
printf 'https://api/pulls/1\n' > "$T/fix/issue"; body 'path:onbranch.md' >> "$T/fix/issue"
OUT="$(ATTESTE_GH="$T/gh" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#777 2>&1)"; RC=$?
has "F4 an UNMERGED PR is graded at its head, not at main" "$OUT" "unmerged PR, graded at its head headsha"
has "F5 so an open branch's own file is not called a lie" "$OUT" "SATISFIED path:onbranch.md"

printf -- '-\n' > "$T/fix/issue"; body 'path:onmain.md' >> "$T/fix/issue"
OUT="$(ATTESTE_GH="$T/gh" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#790 2>&1)"; RC=$?
has "F6 an ISSUE is graded at the default branch" "$OUT" "issue, graded at the default branch"
has "F7 and its claim is looked up there" "$OUT" "SATISFIED path:onmain.md"

section "G. cannot tell is BLIND, and an outage is never a false claim"
printf -- '-\n' > "$T/fix/issue"; body 'path:absent.md' >> "$T/fix/issue"
OUT="$(ATTESTE_GH="$T/gh" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#1 2>&1)"; RC=$?
has "G1 a 404 from the contents API IS a gap" "$OUT" "GAP       path:absent.md"
rc  "G2 and exits 4" 4 $RC

OUT="$(GH_OUTAGE=1 ATTESTE_GH="$T/gh" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#1 2>&1)"; RC=$?
has "G3 an unreachable API is BLIND, NOT a gap" "$OUT" "could not be read, so this is not a miss"
hasnt "G4 and it never reports a gap it did not see" "$OUT" "GAP  "
rc  "G5 and exits 6" 6 $RC

cat > "$T/gh-dead" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$T/gh-dead"
OUT="$(ATTESTE_GH="$T/gh-dead" "$SCRIPT" hf7y/realisateur#1 2>&1)"; RC=$?
has "G6 a subject that cannot be fetched is BLIND" "$OUT" "could not be read from GitHub"
rc  "G7 and exits 6, never 0" 6 $RC

OUT="$(ATTESTE_GH="$T/gh" "$SCRIPT" not-a-subject 2>&1)"; RC=$?
has "G8 an unparseable subject is BLIND, not skipped silently" "$OUT" "is not owner/repo#n"
rc  "G9 and exits 6" 6 $RC

mkdir -p "$T/fix/at-default/adir"
printf -- '-\n' > "$T/fix/issue"; body 'path:adir -- a directory is a delivery' >> "$T/fix/issue"
OUT="$(ATTESTE_GH="$T/gh" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#2 2>&1)"; RC=$?
has "G10 a DIRECTORY is a delivery over the API too, not only on disk" "$OUT" "SATISFIED path:adir"
rc  "G11 and exits 0" 0 $RC

section "K. a retirement is a delivery, and only the diff can say which"
printf 'https://api/pulls/1\n' > "$T/fix/issue"
body 'path:retired.md -- this change retires it' >> "$T/fix/issue"
printf 'merged\nmergesha1\nheadsha2\n' > "$T/fix/pull"
printf 'removed\tretired.md\n' > "$T/fix/files"
OUT="$(ATTESTE_GH="$T/gh" FIX="$T/fix" "$SCRIPT" hf7y/scheduler#372 2>&1)"; RC=$?
has "K1 a path the PR DELETED is satisfied by being gone" "$OUT" "was RETIRED by this change and is gone"
rc  "K2 and retiring a file is not a false claim" 0 $RC

printf 'modified\tsomething-else.md\n' > "$T/fix/files"
OUT="$(ATTESTE_GH="$T/gh" FIX="$T/fix" "$SCRIPT" hf7y/scheduler#372 2>&1)"; RC=$?
has "K3 an absent path the PR never removed is still a GAP" "$OUT" "GAP       path:retired.md"
rc  "K4 and exits 4" 4 $RC

printf 'added\tretired.md\n' > "$T/fix/files"
OUT="$(ATTESTE_GH="$T/gh" FIX="$T/fix" "$SCRIPT" hf7y/scheduler#372 2>&1)"; RC=$?
has "K5 a path the PR ADDED and that is absent is a GAP, not a retirement" "$OUT" "GAP       path:retired.md"
rm -f "$T/fix/files"

section "H. a domain in the first segment is another namespace, not a lie"
printf -- '-\n' > "$T/fix/issue"; body 'path:hf7y.com/monkey/status.json' >> "$T/fix/issue"
OUT="$(ATTESTE_GH="$T/gh" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#611 2>&1)"; RC=$?
has "H1 an absent domain-shaped path is BLIND, not a GAP" "$OUT" "reads as a domain or another namespace"
rc  "H2 and exits 6" 6 $RC
printf -- '-\n' > "$T/fix/issue"; body 'path:.github/workflows/prose.yml' >> "$T/fix/issue"
OUT="$(ATTESTE_GH="$T/gh" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#611 2>&1)"; RC=$?
has "H3 a dotfile directory is NOT a domain -- still a GAP" "$OUT" "GAP       path:.github/workflows/prose.yml"

section "J. a ref belongs to ONE repo, and an unreadable repo is not an absent file"
mkdir -p "$T/fix/other-default"
: > "$T/fix/other-default/deposited.md"
cat > "$T/gh2" <<'EOF'
#!/usr/bin/env bash
case "$2" in
  */issues/*) cat "$FIX/issue" ;;
  */pulls/*)  cat "$FIX/pull" ;;
  repos/hf7y/other/contents/*)
    p="${2#*/contents/}"
    case "$2" in *'?ref='*) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;; esac
    [ -e "$FIX/other-default/$p" ] && exit 0
    echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
  repos/hf7y/locked/contents/*) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
  repos/hf7y/locked) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
  repos/*/*) exit 0 ;;
esac
EOF
chmod +x "$T/gh2"
printf 'https://api/pulls/1
' > "$T/fix/issue"
body 'repo:hf7y/other path:deposited.md -- a deposit into another repo' >> "$T/fix/issue"
printf 'merged
mergesha1
headsha2
' > "$T/fix/pull"
OUT="$(ATTESTE_GH="$T/gh2" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#636 2>&1)"; RC=$?
has "J1 a CROSS-REPO claim is graded at that repo, not at this PR's merge sha" "$OUT" "SATISFIED path:deposited.md"
rc  "J2 and a real deposit is not called a lie" 0 $RC

printf 'https://api/pulls/1
' > "$T/fix/issue"
body 'repo:hf7y/other path:never-deposited.md' >> "$T/fix/issue"
OUT="$(ATTESTE_GH="$T/gh2" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#636 2>&1)"; RC=$?
has "J3 a cross-repo claim that is really absent is still a GAP" "$OUT" "GAP       path:never-deposited.md"
rc  "J4 and exits 4" 4 $RC

printf 'https://api/pulls/1
' > "$T/fix/issue"
body 'repo:hf7y/locked path:secret.md' >> "$T/fix/issue"
OUT="$(ATTESTE_GH="$T/gh2" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#636 2>&1)"; RC=$?
has "J5 a repo this token cannot READ is BLIND, not an absent file" "$OUT" "could not be read, so this is not a miss"
hasnt "J6 and never reports a gap inside a repo it cannot see" "$OUT" "GAP  "
rc  "J7 and exits 6" 6 $RC

section "I. one parser, and a named channel to a host"
. "$ROOT/lib/body-grammar.sh"
grep -q 'grammar_delivers' "$SCRIPT" \
  && ok "I1 atteste reads the DELIVERS block through body-grammar.sh, not a second parser" \
  || bad "I1 atteste parses DELIVERS itself -- that is a second grammar"
declare -F grammar_delivers >/dev/null \
  && ok "I2 grammar_delivers is defined in lib/body-grammar.sh" \
  || bad "I2 grammar_delivers is missing from lib/body-grammar.sh"
G="$(grammar_delivers "$(body 'path:a' 'path:b')")"
eq "I3 it emits one entry per bullet, marker stripped" "$G" "$(printf 'path:a\npath:b')"
grammar_delivers 'NO-DECISION: nothing here' >/dev/null \
  && bad "I4 a body with no block must return nonzero" \
  || ok "I4 a body with no DELIVERS block returns nonzero"

. "$ROOT/lib/propagation-set.sh"
ch="$(prop_channel atteste.sh 2>/dev/null)" || ch=""
eq "I5 prop_channel classifies atteste.sh" "$ch" "local"

echo

section "K. a retirement is a delivery, and the absence is the proof"
runbody 'path:bin/gone.sh -- DELETED'
has "K1 a path claimed GONE and absent is SATISFIED" "$OUT" "SATISFIED path:bin/gone.sh"
rc  "K2 and the run exits 0" 0 $RC

runbody 'path:bin/real.sh -- RETIRED'
has "K3 a path claimed GONE that is still there is a GAP" "$OUT" "GAP       path:bin/real.sh"
rc  "K4 and exits 4" 4 $RC

runbody 'path:bin/real.sh -- the thing'
has "K5 an unmarked entry still grades the ordinary way" "$OUT" "SATISFIED path:bin/real.sh"

runbody 'path:bin/undeleted.sh -- the deleted-events handler'
has "K6 DELETED inside a longer word does not flip the sense" "$OUT" "GAP       path:bin/undeleted.sh"

cat > "$T/gh3" <<'GHEOF'
#!/usr/bin/env bash
case "$2" in
  */issues/*) cat "$FIX/issue" ;;
  */pulls/*)  cat "$FIX/pull" ;;
  repos/hf7y/still-here) exit 0 ;;
  repos/hf7y/really-gone) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
  repos/*/*) exit 0 ;;
esac
GHEOF
chmod +x "$T/gh3"
printf 'https://api/pulls/1\n' > "$T/fix/issue"
body 'repo:hf7y/really-gone -- DELETED' >> "$T/fix/issue"
printf 'merged\nmergesha1\nheadsha2\n' > "$T/fix/pull"
OUT="$(ATTESTE_GH="$T/gh3" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#900 2>&1)"; RC=$?
has "K7 repo: alone is checkable once the claim is that it is GONE" "$OUT" "SATISFIED repo:hf7y/really-gone"
rc  "K8 and exits 0" 0 $RC

printf 'https://api/pulls/1\n' > "$T/fix/issue"
body 'repo:hf7y/still-here -- DELETED' >> "$T/fix/issue"
OUT="$(ATTESTE_GH="$T/gh3" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#900 2>&1)"; RC=$?
has "K9 a repo claimed DELETED that still answers is a GAP" "$OUT" "GAP       repo:hf7y/still-here"
rc  "K10 and exits 4" 4 $RC

printf 'https://api/pulls/1\n' > "$T/fix/issue"
body 'repo:hf7y/still-here -- the wing lives here now' >> "$T/fix/issue"
OUT="$(ATTESTE_GH="$T/gh3" FIX="$T/fix" "$SCRIPT" hf7y/realisateur#900 2>&1)"; RC=$?
has "K11 an unmarked repo: is still BLIND -- existing proves no delivery" "$OUT" "BLIND     repo:hf7y/still-here alone"

summary
