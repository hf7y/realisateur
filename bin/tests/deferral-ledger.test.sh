#!/usr/bin/env bash
# HERMETICITY: offline, zero AI, no network, no live tracker. Every case
# writes a pull-request body to a file under one `mktemp -d` and runs
# bin/deferral-ledger.sh in its `--body-file` mode, which reads nothing but
# that file. The bin/defere.sh cases build a throwaway git repo and put a fake
# `gh` at the front of PATH; case R4 removes `gh` entirely to pin the BLIND
# path rather than inheriting whatever the runner happens to have installed.
# Nothing here reads hf7y/realisateur, this checkout, or $HOME.
#
# deferral-ledger.test.sh -- witness for bin/deferral-ledger.sh and its filing
# sibling bin/defere.sh.
#
# THE TWO LOAD-BEARING CASES, and they pull in opposite directions.
#
#   P1 is the SENSITIVITY case. It is a real body from hf7y/realisateur#104,
#      trimmed: a bullet whose deferring sentence has wrapped onto its second
#      physical line ("...`steward-survey`) -- named, left."). The first draft
#      of the matcher tested each physical line and missed THREE of the six
#      real deferrals in #95..#104 for exactly this reason. A matcher that
#      passes P1 only by accident of a wide regex is not what is wanted; a
#      matcher that reassembles the markdown block is.
#
#   P4 is the SPECIFICITY case, and it is the trap this estate has already
#      fallen into. guard-estate check E's first draft matched the word `FLAG`
#      anywhere in a guard's output and fired on its own preamble sentence --
#      a guard about false alarms producing a false alarm about false alarms,
#      within ten minutes of being written. P4 is a PR body that DISCUSSES
#      this mechanism at length, quoting every phrase in the matcher inside
#      code fences, headings and a table. It must come out clean. Any future
#      widening of DEFER_LINE_RE has to keep it clean.
#
# Between them they pin the only interesting property: the guard reads
# markdown, not text.
#
# Cases:
#   L1  a `- none` ledger                         -> clean, exit 0 under --strict
#   L2  no ledger at all                          -> UNLEDGERED, exit 1
#   L3  entry with owner/repo#N                   -> clean
#   L4  entry with a bare #N                      -> clean
#   L5  entry naming work and no home             -> NO-DESTINATION
#   L6  NO-OWNER: with a real reason              -> clean (a PASSING answer)
#   L7  NO-OWNER: with no reason                  -> NO-DESTINATION
#   L8  ledger says none, prose defers            -> PROSE-DEFERS (the dodge)
#   L9  two DEFERRED blocks                       -> finding (which is current?)
#   L10 block never closed                        -> finding
#   L11 empty body                                -> UNLEDGERED
#   P1  deferral wrapped onto a continuation line -> caught (SENSITIVITY)
#   P2  a scope statement, not a deferral         -> clean (#102's shape)
#   P3  a deferral that DOES cite an issue        -> clean (#97's coin.sh line)
#   P4  a body discussing this guard              -> clean (SPECIFICITY)
#   P5  a deferral-shaped HEADING alone           -> clean, headings are not items
#   B1  --body-file pointing at nothing           -> BLIND, exit 6 under --strict
#   B2  ...and it says it could not look
#   B3  BLIND is printed above any finding        -> guard-estate check E2
#   H1  unknown flag                              -> 2
#   H2  no argument at all                        -> 2
#   H3  --body-file combined with a PR number     -> 2
#   I1  a workflow invokes it on its own
#   I2  ...on `edited`, because a body changes with no commit
#   R1  `defere --ledger` emits a block this guard accepts (the round trip)
#   R2  ...and with entries filed, still accepts
#   R3  defere with no route                      -> 2, no default owner
#   R4  defere with gh absent                     -> 6, and still prints the
#       line you owe; a filing tool that fails silently re-creates the bug
#   R5  defere --dry-run files nothing
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
SUT="$ROOT/bin/deferral-ledger.sh"
DEF="$ROOT/bin/defere.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }
is()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected [$3], got [$2]"; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "output lacks [$3]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1" "output should not contain [$3]" ;; *) ok "$1" ;; esac; }

TMP="$(mktemp -d)" || { echo "cannot mktemp" >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT

# body <name> -- reads a heredoc from stdin, returns the path.
body() { local p="$TMP/$1.md"; cat > "$p"; printf '%s' "$p"; }
run()  { OUT="$(bash "$SUT" --strict --body-file "$1" 2>&1)"; RC=$?; }

echo "L. the declaration"

p="$(body L1 <<'MD'
Some ordinary pull request prose.

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->
MD
)"; run "$p"; is L1a "$RC" 0; has L1b "$OUT" "0 finding(s)"

p="$(body L2 <<'MD'
A perfectly nice pull request that says nothing about what it left behind.
MD
)"; run "$p"; is L2a "$RC" 1; has L2b "$OUT" "UNLEDGERED"

p="$(body L3 <<'MD'
<!-- DEFERRED -->
- hf7y/chezz#12 -- orphaned ecosystem-survey shim on chezz@monkey
<!-- /DEFERRED -->
MD
)"; run "$p"; is L3 "$RC" 0

p="$(body L4 <<'MD'
<!-- DEFERRED -->
- #42 -- the fourth bootstrap slot review
<!-- /DEFERRED -->
MD
)"; run "$p"; is L4 "$RC" 0

p="$(body L5 <<'MD'
<!-- DEFERRED -->
- the orphaned shims on the nine unarmed accounts, left for later
<!-- /DEFERRED -->
MD
)"; run "$p"; is L5a "$RC" 1; has L5b "$OUT" "NO-DESTINATION"

p="$(body L6 <<'MD'
<!-- DEFERRED -->
- NO-OWNER: free the fourth bootstrap slot -- it changes what four live
  accounts must hold before they can fetch anything, and needs a human
<!-- /DEFERRED -->
MD
)"; run "$p"; is L6 "$RC" 0

p="$(body L7 <<'MD'
<!-- DEFERRED -->
- NO-OWNER: dunno
<!-- /DEFERRED -->
MD
)"; run "$p"; is L7a "$RC" 1; has L7b "$OUT" "NO-DESTINATION"

p="$(body L8 <<'MD'
## Deliberately left alone

- **Orphaned shims** on the nine accounts -- named, left.

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->
MD
)"; run "$p"; is L8a "$RC" 1; has L8b "$OUT" "PROSE-DEFERS"

p="$(body L9 <<'MD'
<!-- DEFERRED -->
- none
<!-- /DEFERRED -->
<!-- DEFERRED -->
- hf7y/chezz#12 -- something
<!-- /DEFERRED -->
MD
)"; run "$p"; is L9a "$RC" 1; has L9b "$OUT" "2 DEFERRED blocks"

p="$(body L10 <<'MD'
<!-- DEFERRED -->
- none
MD
)"; run "$p"; is L10a "$RC" 1; has L10b "$OUT" "never closed"

: > "$TMP/L11.md"; run "$TMP/L11.md"; is L11a "$RC" 1; has L11b "$OUT" "UNLEDGERED"

# L12 -- FOUND BY DOGFOODING, and it is the most embarrassing possible bug for
# this particular guard. The pull request that INTRODUCED it explains the
# mechanism in prose, and that prose says the words `<!-- DEFERRED -->` inline
# in a sentence. The first cut counted markers anywhere on a line, so it read
# that sentence as a second block and reported "2 DEFERRED blocks -- a reader
# cannot tell which is current" about a body with exactly one. A guard whose
# own PR body trips it is a guard that gets deleted in a week. Markers are now
# anchored to a whole line; a marker mentioned inside a sentence is prose.
p="$(body L12 <<'MD'
A body must carry a `<!-- DEFERRED -->` block, and the closing
`<!-- /DEFERRED -->` marker must be there too, or nothing is bounded.

<!-- DEFERRED -->
- hf7y/chezz#12 -- a real entry
<!-- /DEFERRED -->
MD
)"; run "$p"; is L12a "$RC" 0
hasnt L12b "$OUT" "DEFERRED blocks"

echo
echo "P. reading markdown, not text"

# P1 -- SENSITIVITY. Verbatim shape from hf7y/realisateur#104.
p="$(body P1 <<'MD'
## Deliberately left alone

- **Orphaned shims** on monkey accounts (`ecosystem-survey`, `milestone-audit`,
  `steward-survey`) -- named, left.

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->
MD
)"; run "$p"; is P1a "$RC" 1; has P1b "$OUT" "PROSE-DEFERS"
has P1c "$OUT" "named, left"

# P2 -- a SCOPE STATEMENT under an identically-shaped heading. #102's shape.
# Nothing is being postponed; a boundary is being drawn. Demanding an issue
# for it is the false alarm that gets a guard ignored.
p="$(body P2 <<'MD'
## Deliberately excluded

- **The toolchain** -- `realisateur`, `scheduler`, `senechal`. Agents do not
  need to build the toolchain, and read access there is already solved
  per-repo by the read-only deploy keys.
- **`hf7y/verbs`** -- public, so its payload needs no credential, and the cut
  runs as Actions inside that repo.

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->
MD
)"; run "$p"; is P2 "$RC" 0

# P3 -- #97's real line: a deferral that DID name where it went. The whole
# point of the mechanism is that this shape passes.
p="$(body P3 <<'MD'
### Left alone, deliberately

- `coin.sh:55` still reads `PROJECT_REPO_PATH` with `grep -oP` without
  expanding `$HOME`; that belongs to #73, as #89 already recorded.

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->
MD
)"; run "$p"; is P3 "$RC" 0

# P4 -- SPECIFICITY. A body that talks about this guard, quoting the matcher.
p="$(body P4 <<'MD'
# deferral-ledger: a paragraph is not a queue

## What the matcher looks for

It reads a list item or paragraph that says of itself that it is postponing
work. The phrase list is taken from real pull requests:

```
left alone | named, left | not attempted | out of scope | must be copied
deliberately left out | the obvious next hardening | left for a human
```

| phrase | seen in |
|---|---|
| out of scope | #97 |
| named, left | #104 |
| not attempted | #104 |

### Deliberately left alone

Nothing. Everything this branch touched, it finished.

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->
MD
)"; run "$p"; is P4a "$RC" 0
hasnt P4b "$OUT" "PROSE-DEFERS"

# P5 -- a heading alone is an announcement, not an item.
p="$(body P5 <<'MD'
## Deliberately left alone

Nothing was.

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->
MD
)"; run "$p"; is P5 "$RC" 0

echo
echo "B. blindness is not cleanliness"
OUT="$(bash "$SUT" --strict --body-file "$TMP/definitely-not-here.md" 2>&1)"; RC=$?
is B1 "$RC" 6
has B2a "$OUT" "BLIND"
has B2b "$OUT" "nothing was examined"
hasnt B2c "$OUT" "0 finding(s), 1 clean"
# E2: the admission must be printed ABOVE any finding, not buried under it.
first_blind="$(printf '%s\n' "$OUT" | grep -n 'BLIND' | head -1 | cut -d: -f1)"
first_flag="$(printf '%s\n' "$OUT" | grep -nE '^[[:space:]]*FLAG' | head -1 | cut -d: -f1)"
if [ -z "$first_flag" ] || { [ -n "$first_blind" ] && [ "$first_blind" -lt "$first_flag" ]; }; then
  ok B3
else
  bad B3 "the BLIND line is below the first finding"
fi

echo
echo "H. the argument contract"
bash "$SUT" --not-a-real-flag >/dev/null 2>&1; is H1 "$?" 2
bash "$SUT" >/dev/null 2>&1; is H2 "$?" 2
bash "$SUT" --body-file "$TMP/L1.md" 95 >/dev/null 2>&1; is H3 "$?" 2

echo
echo "I. wired to fire on its own"
wf="$(grep -rl 'deferral-ledger.sh' "$ROOT/.github/workflows/" 2>/dev/null | head -1)"
if [ -n "$wf" ]; then
  ok I1
  wfb="$(cat "$wf")"
  # `edited` is the load-bearing event and is NOT in the default set: a PR
  # body changes with no commit and no `synchronize`, so without it the one
  # act that changes this answer would never re-run the check.
  has I2 "$wfb" "edited"
else
  bad I1 "no workflow in .github/workflows/ invokes deferral-ledger.sh"
  bad I2 "(no workflow)"
fi

echo
echo "R. the round trip -- defere files it, deferral-ledger accepts it"
mkdir -p "$TMP/shim" "$TMP/repo"
cat > "$TMP/shim/gh" <<'SHIM'
#!/usr/bin/env bash
case "$1 $2" in
  "repo view")  echo '{"name":"realisateur","nameWithOwner":"hf7y/realisateur"}'
                [ "${3:-}" = "hf7y/nosuchproj" ] && exit 1 || exit 0 ;;
  "label create") exit 0 ;;
  "issue create") echo "https://github.com/hf7y/chezz/issues/7"; exit 0 ;;
esac
echo "stub gh: unexpected: $*" >&2; exit 1
SHIM
chmod +x "$TMP/shim/gh"
(
  cd "$TMP/repo" || exit 1
  git init -q -b main .; git config user.email t@t; git config user.name t
  echo x > f; git add f; git commit -qm init
) >/dev/null 2>&1

# R1 -- an empty branch ledger still emits a block, and it is a VALID one.
( cd "$TMP/repo" && bash "$DEF" --ledger ) > "$TMP/rt1.md" 2>&1
run "$TMP/rt1.md"; is R1 "$RC" 0

# R2 -- with a filed entry accumulated, the emitted block is still accepted.
printf -- '- hf7y/chezz#7 -- orphaned ecosystem-survey shim on chezz@monkey\n' \
  >> "$TMP/repo/.git/defere-ledger.main"
( cd "$TMP/repo" && bash "$DEF" --ledger ) > "$TMP/rt2.md" 2>&1
run "$TMP/rt2.md"; is R2a "$RC" 0
has R2b "$(cat "$TMP/rt2.md")" "hf7y/chezz#7"

# R3 -- there is no default owner. Refusing to choose is an error, not a
# silent assignment to whoever reads the tracker.
o="$( cd "$TMP/repo" && bash "$DEF" 'something left behind' 2>&1 )"; rc=$?
is R3a "$rc" 2
has R3b "$o" "no default owner"

# R4 -- gh absent. A filing tool that fails quietly re-creates the bug it
# exists to fix, so it must be loud AND hand back the line still owed.
o="$( cd "$TMP/repo" && env PATH="/nonexistent-for-this-case" \
      /bin/bash "$DEF" 'a thing' --project chezz 2>&1 )"; rc=$?
is R4a "$rc" 6
has R4b "$o" "BLIND"
has R4c "$o" "NO-OWNER:"

# R5 -- dry run files nothing: the stub would have to be asked to create an
# issue, and it is not.
o="$( cd "$TMP/repo" && env PATH="$TMP/shim:$PATH" \
      bash "$DEF" 'a thing' --project chezz --dry-run 2>&1 )"; rc=$?
is R5a "$rc" 0
has R5b "$o" "DRY RUN"
hasnt R5c "$o" "filed https"

echo
printf 'deferral-ledger.test.sh: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
