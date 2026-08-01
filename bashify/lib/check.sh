#!/usr/bin/env bash
# check.sh -- score a man page against the nine-row page test.
#
#   check.sh <page.1> <command-under-test>
#
# The page is the contract; this is the thing that reads it back. It was
# built from inside `bashify check`'s own exit-4 call site, and its first
# subject is the page that describes it -- which is the only self-application
# available to a page test and therefore the only real witness that it works.
#
# Design rule throughout: a row is either MECHANISED or it is reported as
# UNCHECKED. There is no third state where a row is asserted by this script
# without having measured anything -- that is the exit-0 no-op the whole
# ecosystem is built against.
#
# Where a row cannot cover its whole domain (forms that must not be executed,
# exit codes that cannot be provoked from outside), it says so and COUNTS
# what it skipped. A silent cap reads as full coverage and is worse than an
# admitted one.

set -uo pipefail

PAGE="${1:?usage: check.sh <page.1> <command-under-test>}"
CUT="${2:?usage: check.sh <page.1> <command-under-test>}"
TIMEOUT="${BASHIFY_CHECK_TIMEOUT:-20}"

[ -r "$PAGE" ] || { printf 'check: BLIND: cannot read page: %s\n' "$PAGE" >&2; exit 6; }
command -v "$CUT" >/dev/null 2>&1 || [ -x "$CUT" ] || {
  printf 'check: BLIND: command under test is not executable: %s\n' "$CUT" >&2; exit 6; }

CUT_ABS="$(readlink -f "$CUT" 2>/dev/null || printf '%s' "$CUT")"
# Examples are written as a reader would type them, so they name the tool by
# its own name. Run them against the command under test instead -- the same
# indirection the contract test uses, and what lets one page be scored
# against a legacy implementation and its replacement.
ROOT="$(cd "$(dirname "$PAGE")/.." && pwd)"

ROWS_PASS=0; ROWS_FAIL=0
declare -a FAILED=() NOTES=()

row_pass() { ROWS_PASS=$((ROWS_PASS+1)); printf 'PASS  %-10s %s\n' "$1" "$2"; }
row_fail() { ROWS_FAIL=$((ROWS_FAIL+1)); FAILED+=("$1: $2")
             printf 'FAIL  %-10s %s\n' "$1" "$2"; }
note()     { NOTES+=("$1"); printf '      %s\n' "$1"; }

# ---------------------------------------------------------------- page parts
# Section body: everything between `.SH <name>` and the next `.SH`.
# `.SH "EXIT STATUS"` and `.SH EXIT STATUS` are the same heading to every roff
# on earth, and an exact string match saw only the second. Every page written
# with the quoted form -- which is most of senechal's -- scored "no EXIT STATUS
# codes documented" and "SEE ALSO names no standard tool", two rows failing on
# a pair of quote characters. The check has to read what a reader reads.
section() { awk -v want="$1" '
    { h = $0
      if (h ~ /^\.SH /) {
        sub(/^\.SH[ \t]+/, "", h); gsub(/^"|"$/, "", h)
        inb = (h == want); next
      } }
    inb {print}' "$PAGE"; }

# Strip troff markup down to readable text.
detroff() { sed -e 's/\\f[IBRP]//g' -e 's/^\.[A-Za-z][A-Za-z]*[ ]*//' \
                -e 's/\\-/-/g' -e 's/\\ / /g' -e 's/\\&//g'; }

PAGE_NAME="$(section NAME | detroff | grep -m1 . | sed 's/ *-.*//' | tr -d ' ')"
[ -n "$PAGE_NAME" ] || { printf 'check: BLIND: page has no NAME section\n' >&2; exit 6; }

printf '=== page test: %s\n' "$PAGE"
printf '    under test: %s\n' "$CUT_ABS"
printf '    page names: %s\n\n' "$PAGE_NAME"

# run_cut <args...> -- run the command under test, capture output and rc.
run_cut() {
  LAST_OUT="$(cd "$ROOT" && timeout "$TIMEOUT" "$CUT_ABS" "$@" 2>&1)"
  LAST_RC=$?
  [ "$LAST_RC" = 124 ] && LAST_OUT="(timed out after ${TIMEOUT}s)"
  return 0
}

# ------------------------------------------------------------------- row 1
# NAME is one clause. An "and" joining two predicates means two utilities.
r1() {
  local line summary
  line="$(section NAME | detroff | grep -m1 .)"
  summary="${line#*- }"
  if [ "$summary" = "$line" ]; then
    row_fail 'NAME' "no ' - <summary>' on the NAME line: $line"; return
  fi
  if printf '%s' "$summary" | grep -qiE '(^| )and( |$)'; then
    row_fail 'NAME' "summary joins two clauses with 'and': $summary"; return
  fi
  if [ "$PAGE_NAME" != "$(basename "$CUT_ABS")" ]; then
    row_fail 'NAME' "page names '$PAGE_NAME', command under test is '$(basename "$CUT_ABS")'"; return
  fi
  row_pass 'NAME' "one clause: $summary"
}

# ------------------------------------------------------------------- row 2
# Every SYNOPSIS form runs as written. A form carrying placeholder arguments
# cannot be run without inventing them, and some forms MUTATE things a test
# must not mutate -- so the page marks those `.\" bashify: norun`, and this
# row runs everything else and counts what it did not run. The escape hatch
# is bounded by row 3, which still requires every such form's subcommand to
# exist in the tool's own surface.
r2() {
  local ran=0 bad=0 norun=0
  local -a norun_forms=()
  local buf='' skip=0 line
  local -a forms=() skips=()

  while IFS= read -r line; do
    case "$line" in
      '.\"'*bashify:*norun*) skip=1; continue ;;
      .br) [ -n "$buf" ] && { forms+=("$buf"); skips+=("$skip"); }; buf=''; skip=0; continue ;;
      *) buf+="${buf:+ }$line" ;;
    esac
  done < <(section SYNOPSIS)
  [ -n "$buf" ] && { forms+=("$buf"); skips+=("$skip"); }

  local i form text
  for i in "${!forms[@]}"; do
    text="$(printf '%s' "${forms[$i]}" | detroff | sed 's/  */ /g; s/^ //; s/ $//')"
    [ -n "$text" ] || continue
    if [ "${skips[$i]}" = 1 ]; then
      norun=$((norun+1)); norun_forms+=("$text"); continue
    fi
    # Brackets mean "optional literal"; bare italics mean "placeholder the
    # caller supplies". `[\fIlist\fR]` is runnable both ways; `emit \fIproject\fR`
    # is not runnable without inventing a project, so it must declare norun.
    # Distinguishing them by brackets is what stopped this row failing every
    # page ever written, including its own.
    if printf '%s' "${forms[$i]}" | sed 's/\[[^]]*\]//g' | grep -q '\\fI'; then
      row_fail 'SYNOPSIS' "form has placeholder arguments but is not marked norun: $text"
      bad=$((bad+1)); continue
    fi
    # Expand one form into concrete invocations: `[x]` is optional, `a|b`
    # alternatives are each run on their own.
    local -a invocations=()
    if printf '%s' "$text" | grep -q '\['; then
      local tok
      invocations=("")
      for tok in $(printf '%s' "$text" | grep -oP '\[\K[^]]+'); do
        local alt
        for alt in ${tok//|/ }; do invocations+=("$alt"); done
      done
    else
      invocations=("${text#"$PAGE_NAME"}")
    fi
    local inv
    for inv in "${invocations[@]}"; do
      # shellcheck disable=SC2086
      run_cut $inv
      ran=$((ran+1))
      if printf '%s' "$LAST_OUT" | grep -qE 'unknown (flag|subcommand)'; then
        row_fail 'SYNOPSIS' "form not accepted: '$PAGE_NAME $inv' -> $LAST_OUT"
        bad=$((bad+1))
      fi
      DOC_CODES+=("$LAST_RC")
    done
  done

  if [ "$bad" = 0 ]; then
    row_pass 'SYNOPSIS' "$ran invocation(s) from the SYNOPSIS ran and were accepted"
  fi
  if [ "$norun" -gt 0 ]; then
    note "SYNOPSIS: $norun form(s) declared norun and NOT executed:"
    local f; for f in "${norun_forms[@]}"; do note "  - $f"; done
  fi
}

# ------------------------------------------------------------------- row 3
# Bidirectional surface. Flags: what the page documents versus what --help
# advertises. Subcommands: what the SYNOPSIS names versus what the tool
# itself reports. A documented ghost and an undocumented surface fail alike.
r3() {
  local bad=0
  local page_flags help_flags f
  # Unescape BEFORE matching, not after. `\-\-dry\-run` matched only as far as
  # the third `\`, yielding `--dry`, so the row reported a flag the page does
  # not document and a flag the tool does not offer -- two failures, one
  # hyphen, on a page that was correct. Any flag with a hyphen in its name was
  # unscoreable.
  page_flags="$(section OPTIONS | detroff | grep -oE '\-\-[a-z][a-z-]*' | sort -u)"
  run_cut --help
  help_flags="$(printf '%s' "$LAST_OUT" | grep -oE '\-\-[a-z-]+' | sort -u)"
  # A utility that cannot spend names --summon in order to DENY it. Counting
  # that mention as an offered flag would force every non-spending page to
  # document a flag it does not have -- the opposite of the cost boundary.
  if printf '%s' "$LAST_OUT" | grep -q 'no --summon flag'; then
    help_flags="$(printf '%s\n' "$help_flags" | grep -vx -- '--summon')"
  fi

  for f in $page_flags; do
    printf '%s\n' "$help_flags" | grep -qx -- "$f" || {
      row_fail 'SURFACE' "page documents $f but --help does not offer it"; bad=1; }
  done
  for f in $help_flags; do
    printf '%s\n' "$page_flags" | grep -qx -- "$f" || {
      row_fail 'SURFACE' "--help offers $f but the page does not document it"; bad=1; }
  done

  # Subcommands, both directions, when the tool can enumerate its own.
  local page_subs tool_subs s
  # Subcommand names may be hyphenated -- five of senechal's seven are. A
  # bare [a-z]+ truncated `dead-config` to `dead` on the page side and
  # dropped it entirely on the tool side, so the two could never agree and
  # every hyphenated verb in the ecosystem was unpassable.
  page_subs="$(section SYNOPSIS | grep -oP "^\.B $PAGE_NAME \K[a-z][a-z-]*" | sort -u)"
  run_cut list
  if [ "$LAST_RC" = 0 ] && [ -n "$page_subs" ]; then
    tool_subs="$(printf '%s' "$LAST_OUT" | awk '{print $NF}' | grep -E '^[a-z][a-z-]*$' | sort -u)"
    for s in $page_subs; do
      printf '%s\n' "$tool_subs" | grep -qx -- "$s" || {
        row_fail 'SURFACE' "SYNOPSIS names subcommand '$s' which the tool does not list"; bad=1; }
    done
    for s in $tool_subs; do
      grep -q "^\.B $PAGE_NAME $s\$" "$PAGE" || printf '%s\n' "$page_subs" | grep -qx -- "$s" || {
        row_fail 'SURFACE' "tool lists subcommand '$s' which the SYNOPSIS does not name"; bad=1; }
    done
  else
    note "SURFACE: tool does not enumerate subcommands; flags checked both ways, subcommands UNCHECKED"
  fi
  [ "$bad" = 0 ] && row_pass 'SURFACE' 'every documented flag exists; every offered flag is documented'
}

# ------------------------------------------------------------------- row 4
# Every code the page lists is in the shared vocabulary or declared above it;
# every code OBSERVED during this run is listed. Reachability of a code no
# invocation here provoked is reported UNPROVOKED, never claimed.
r4() {
  local bad=0 codes c
  codes="$(section 'EXIT STATUS' | grep -oP '^\.B \K[0-9]+' | sort -un)"
  [ -n "$codes" ] || { row_fail 'EXIT' 'no EXIT STATUS codes documented'; return; }

  for c in $codes; do
    case "$c" in
      0|2|3|4|5|6) ;;
      *) [ "$c" -gt 6 ] || { row_fail 'EXIT' "code $c redefines a reserved code"; bad=1; } ;;
    esac
  done

  local observed unlisted='' unprovoked=''
  observed="$(printf '%s\n' "${DOC_CODES[@]}" | sort -un)"
  for c in $observed; do
    printf '%s\n' "$codes" | grep -qx -- "$c" || unlisted+=" $c"
  done
  for c in $codes; do
    printf '%s\n' "$observed" | grep -qx -- "$c" || unprovoked+=" $c"
  done

  if [ -n "$unlisted" ]; then
    row_fail 'EXIT' "codes returned but not documented:$unlisted"; bad=1
  fi
  [ "$bad" = 0 ] && row_pass 'EXIT' "documented:$(printf ' %s' $codes)  provoked here:$(printf ' %s' $observed)"
  [ -n "$unprovoked" ] && note "EXIT: documented but NOT provoked by this run:$unprovoked (reachability UNCHECKED)"
}

# ------------------------------------------------------------------- row 5
# EXAMPLES are doctests. Each `$ ` line is executed and the lines beneath it
# must match exactly. `$ echo $?` is answered from the previous command's
# real exit code, which is how a page states a code without narrating it.
r5() {
  local bad=0 n=0
  local cmd='' expected='' inblock=0 line
  local prev_rc=''

  _settle() {
    [ -n "$cmd" ] || return 0
    n=$((n+1))
    local got
    if [ "$cmd" = 'echo $?' ]; then
      got="$prev_rc"
    else
      # shellcheck disable=SC2086
      set -- $cmd
      if [ "$1" = "$PAGE_NAME" ]; then shift; run_cut "$@"; else
        LAST_OUT="$(cd "$ROOT" && timeout "$TIMEOUT" "$@" 2>&1)"; LAST_RC=$?
      fi
      got="$LAST_OUT"; prev_rc="$LAST_RC"; DOC_CODES+=("$LAST_RC")
    fi
    expected="${expected%$'\n'}"
    if [ "$got" != "$expected" ]; then
      row_fail 'EXAMPLES' "example '$cmd' did not reproduce"
      printf '        expected: %s\n' "$(printf '%s' "$expected" | head -3 | tr '\n' '|')"
      printf '        got:      %s\n' "$(printf '%s' "$got" | head -3 | tr '\n' '|')"
      bad=1
    fi
    cmd=''; expected=''
  }

  while IFS= read -r line; do
    case "$line" in
      .nf) inblock=1; continue ;;
      .fi) _settle; inblock=0; continue ;;
    esac
    [ "$inblock" = 1 ] || continue
    case "$line" in
      # Detroff the command too, not just the prose. An example that shows a
      # flag is written `\-n` in the source, and handing that to the shell
      # verbatim invoked the tool with a literal backslash -- so every example
      # containing a flag "did not reproduce", for a reason that had nothing to
      # do with the tool.
      '$ '*) _settle; cmd="$(printf '%s' "${line#\$ }" | sed -e 's/\\-/-/g' -e 's/\\&//g')" ;;
      # Expected output is detroffed for the same reason the command is: the
      # page writes a hyphen `\-`, the tool prints a hyphen, and comparing the
      # two verbatim failed every example whose output contained one.
      *) [ -n "$cmd" ] && expected+="$(printf '%s' "$line" | sed -e 's/\\-/-/g' -e 's/\\&//g')"$'\n' ;;
    esac
  done < <(section EXAMPLES)
  _settle

  if [ "$n" = 0 ]; then
    row_fail 'EXAMPLES' 'the page contains no executable examples'
  elif [ "$bad" = 0 ]; then
    row_pass 'EXAMPLES' "$n example line(s) executed; every output reproduced"
  fi
}

# ------------------------------------------------------------------- row 6
# Cost is answerable from the page alone -- and the page's answer is checked
# against the tool, so a page cannot claim a boundary the tool does not keep.
r6() {
  local declares_summon=0 declares_cannot=0
  grep -q '^\.B \\-\\-summon' "$PAGE" && declares_summon=1
  detroff < "$PAGE" | grep -qiE 'does not spend money|cannot spend money' && declares_cannot=1

  if [ "$declares_summon" = 0 ] && [ "$declares_cannot" = 0 ]; then
    row_fail 'COST' 'the page is silent on whether this can spend money'; return
  fi
  run_cut --summon
  DOC_CODES+=("$LAST_RC")
  if [ "$declares_cannot" = 1 ] && [ "$declares_summon" = 0 ]; then
    if [ "$LAST_RC" = 0 ]; then
      row_fail 'COST' 'page says it cannot spend, but --summon was accepted (exit 0)'
    else
      row_pass 'COST' "page states it cannot spend; tool rejects --summon (exit $LAST_RC)"
    fi
  else
    if [ "$LAST_RC" = 0 ]; then
      row_fail 'COST' '--summon with no work requested exited 0 -- implicit spend'
    else
      row_pass 'COST' "page documents --summon; tool does not spend implicitly (exit $LAST_RC)"
    fi
  fi
}

# ------------------------------------------------------------------- row 7
r7() {
  local refs
  refs="$(section 'SEE ALSO' | grep -oP '^\.BR \K[a-z0-9-]+' | sort -u)"
  if [ -z "$refs" ]; then
    row_fail 'LINEAGE' 'SEE ALSO names no standard tool this one behaves like'
  else
    row_pass 'LINEAGE' "expectations transferable from:$(printf ' %s' $refs)"
  fi
}

# ------------------------------------------------------------------- row 8
r8() {
  local hits
  hits="$(grep -oiE 'claude|anthropic|\bagent\b|openai|gpt|llm|assistant' "$PAGE" | sort -u | tr '\n' ' ')"
  if [ -n "$hits" ]; then
    row_fail 'PURGE' "the page names: $hits"
  else
    row_pass 'PURGE' 'no vendor or external paid service named on the page'
  fi
}

# ------------------------------------------------------------------- row 9
# Present tense. The marker of an aspirational sentence is a modal, and a
# modal in a contract is a promise nobody has to keep. Reported with the
# offending line so the judgment is the reader's, not this script's.
r9() {
  local hits
  hits="$(section DESCRIPTION; section 'EXIT STATUS'; section OPTIONS)"
  hits="$(printf '%s\n' "$hits" | detroff \
        | grep -inE '\b(will|shall|would|eventually|soon|planned|TODO|intends?|going to|in future|not yet|for now)\b' \
        | head -5)"
  if [ -n "$hits" ]; then
    row_fail 'TENSE' 'aspirational or future-tense sentences in a contract:'
    printf '        %s\n' "$hits"
  else
    row_pass 'TENSE' 'present tense throughout the contract sections'
  fi
}

declare -a DOC_CODES=()

r1; r2; r3; r4; r5; r6; r7; r8; r9

printf '\n--- %s: %d of 9 rows passed\n' "$(basename "$PAGE")" "$ROWS_PASS"
if [ "${#FAILED[@]}" -gt 0 ]; then
  printf 'failing rows:\n'; printf '  - %s\n' "${FAILED[@]}"
fi
if [ "${#NOTES[@]}" -gt 0 ]; then
  printf 'declared limits of this run:\n'; printf '  - %s\n' "${NOTES[@]}"
fi

# The page under test failing is not this script failing. It ran, it scored,
# it reported -- so 5 (BROKEN) would be a lie. Exit 7 is this utility's own
# code, declared above the shared vocabulary: THE SUBJECT FAILED.
[ "$ROWS_FAIL" = 0 ] || exit 7
exit 0
