#!/usr/bin/env bash
# HERMETICITY: fully hermetic, zero live access. Sections A-B source the two
# files under test and call their PURE functions directly with fixture
# strings -- no ssh, no sudo, no gh, no network, no real account. Sections
# C-E exercise the CLI by pointing CRED_SSH_BIN / CRED_GH_BIN at throwaway
# stub executables under a mktemp dir that this suite writes itself: the ssh
# stub prints canned fixture TSV instead of reaching monkey, and the gh stub
# answers `deploy-key list` from a fixture instead of calling GitHub. Section
# F greps the SOURCE TEXT for invariants that must never execute even by
# accident (propagation.test.sh's own style for the same reason: asserting
# "--apply never does X" by running --apply against a live account would be
# the opposite of hermetic). Nothing here reads bin/lib/selfdev-credentials-
# set.sh's CRED_GRANTS as anything but the empty table it ships with; a case
# that needs a grant declares one locally by re-sourcing with CRED_GRANTS
# overridden, never by editing the real file.
#
# NAMING NOTE: this suite's own assertion helpers are prefixed `t_` on
# purpose. The script under test defines global `ok()`/`gap()`/`bad()`
# helpers of its own (the estate-wide idiom -- wire-selfdev-git.sh,
# provision-selfdev-user.sh, selfdev-release-tick.sh all do the same), and
# sourcing it into this suite's shell REDEFINES any same-named function this
# file declared first. A first draft used bare ok()/bad() and passed 11/11 --
# every one of dozens of intentionally-failing assertions had been silently
# swallowed into the SCRIPT's own BAD counter instead of this suite's `fail`,
# because the source line runs after the helpers and simply overwrites them.
# Caught by eye, not by the suite (a suite cannot catch its own silencing);
# the fix is the naming rule stated here so it cannot recur by accident.
#
# selfdev-credentials.test.sh -- witness for bin/selfdev-credentials.sh and
# bin/lib/selfdev-credentials-set.sh.
#
# Usage: bin/tests/selfdev-credentials.test.sh   (exit 0 = all pass)
set -uo pipefail

REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/selfdev-credentials.sh"
LIB="$REPO_BIN/lib/selfdev-credentials-set.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
[ -f "$LIB" ]    || { echo "FAIL: $LIB missing"; exit 1; }

pass=0; fail=0
t_ok()  { echo "  ok   $1"; pass=$((pass+1)); }
t_bad() { echo "  FAIL $1"; fail=$((fail+1)); }
t_eq()    { if [ "$2" = "$3" ]; then t_ok "$1"; else t_bad "$1 (expected '$3', got '$2')"; fi; }
t_has()   { case "$2" in *"$3"*) t_ok "$1" ;; *) t_bad "$1 (missing: $3)" ;; esac; }
t_hasnt() { case "$2" in *"$3"*) t_bad "$1 (unexpectedly present: $3)" ;; *) t_ok "$1" ;; esac; }
t_rc()    { if [ "$2" = "$3" ]; then t_ok "$1"; else t_bad "$1 (expected exit $2, got $3)"; fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# ============================================================================
echo "-- A. bin/lib/selfdev-credentials-set.sh: the pure baseline functions --"
# ============================================================================
# shellcheck source=/dev/null
. "$LIB"

t_eq "classify: gho_ token"          "$(cred_classify_token 'oauth_token: gho_wkxBabc123')" gho
t_eq "classify: github_pat_ token"   "$(cred_classify_token 'oauth_token: github_pat_11ABC')" pat
t_eq "classify: classic ghp_ token"  "$(cred_classify_token 'oauth_token: ghp_abc123')" other
t_eq "classify: no line at all"      "$(cred_classify_token '')" missing

t_eq "own_repo: identity mapping"    "$(cred_own_repo ecosim)" ecosim
t_eq "own_repo: hyphenated account"  "$(cred_own_repo groc-mangr)" groc-mangr

# The shipped table is EMPTY -- no account has a reviewed exception today.
[ -z "$(cred_list_grants ecosim)" ] && t_ok "grants: shipped CRED_GRANTS has no rows for ecosim" \
                                     || t_bad "grants: shipped CRED_GRANTS unexpectedly has rows"
if cred_grant_covers ecosim extra-file ecosim.pem; then
  t_bad "grants: ecosim.pem is covered, but no such grant is declared -- CRED_GRANTS drifted"
else
  t_ok "grants: an undeclared exception (ecosim.pem) is correctly NOT covered"
fi

# A locally-scoped grant, declared the same way the real file documents,
# proves the LOOKUP works without ever editing the shipped table.
CRED_GRANTS='
ecosim  extra-file  ecosim.pem  2026-08-11  fixture-only test grant
'
if cred_grant_covers ecosim extra-file ecosim.pem; then
  t_ok "grants: a declared exception IS covered"
else
  t_bad "grants: a declared exception was not recognized"
fi
if cred_grant_covers vim-arcade extra-file ecosim.pem; then
  t_bad "grants: a grant leaked to an account it was not declared for"
else
  t_ok "grants: a grant does not apply to a different account"
fi
t_has "grants: cred_list_grants prints the declared row" "$(cred_list_grants ecosim)" "2026-08-11"
# Restore the real, empty table for every section below.
# shellcheck source=/dev/null
. "$LIB"

# ============================================================================
echo
echo "-- B. cred_grade_account: pure grading, no network --------------------"
# ============================================================================
# shellcheck source=/dev/null
. "$SCRIPT"   # BASH_SOURCE guard keeps main()/cmd_audit's ssh call from firing

# grade <account> <row> -- sets GLOBALS GRADE_OUT/GRADE_RC/GRADE_FLAGS/GRADE_GAPS.
# NOT `res="$(grade ...)"`: a first draft packed everything into one
# \x1f-delimited string and unpacked it with `read`, which stops at the
# FIRST NEWLINE regardless of IFS -- cred_grade_account's own output is
# multi-line (a table row, then zero or more FLAG lines), so `read` silently
# truncated the captured text to just the first line and every content
# assertion below failed against text that had already been cut off before
# the assertion ever ran. Globals set by a DIRECTLY CALLED function (not
# `$(...)`, which forks a subshell whose assignments never reach the caller
# -- see the sibling note this replaced) sidestep both problems at once.
grade() {
  GRADE_OUT="$(cred_grade_account "$1" "$2" 2>&1)"; GRADE_RC=$?
  GRADE_FLAGS="$(grep -c '^  FLAG \[drift\]' <<<"$GRADE_OUT" || true)"
  GRADE_GAPS="$(grep -c '^  gap   '          <<<"$GRADE_OUT" || true)"
}

CLEAN_ROW=$'ok:600\tok\tmatch\tgho\t-\t3\t3\t3\t3\t'"$CRED_APP_ID"$'\t'"$CRED_GH_OWNER"
grade clean-acct "$CLEAN_ROW"
t_eq "clean row: 0 FLAG"   "$GRADE_FLAGS" 0
t_eq "clean row: exit 0"   "$GRADE_RC" 0
t_has "clean row: reports matches baseline" "$GRADE_OUT" "matches baseline"

grade ghost "BLIND"
t_eq "BLIND row: exit 2"          "$GRADE_RC" 2
t_has "BLIND row: reported as BLIND, not ok" "$GRADE_OUT" "BLIND"

grade nobody ""
t_eq "empty row: treated the same as BLIND (exit 2)" "$GRADE_RC" 2

BAD_PEM_ROW=$'mode:644\tok\tmatch\tgho\t-\t3\t3\t3\t3\t'"$CRED_APP_ID"$'\t'"$CRED_GH_OWNER"
grade x "$BAD_PEM_ROW"
t_has "wrong pem mode: flagged" "$GRADE_OUT" "app.pem is mode 644"
[ "$GRADE_FLAGS" -ge 1 ] && t_ok "wrong pem mode: at least one FLAG" || t_bad "wrong pem mode: no FLAG counted"

MISSING_PEM_ROW=$'missing\tok\tn/a\tgho\t-\t3\t3\t3\t3\t'"$CRED_APP_ID"$'\t'"$CRED_GH_OWNER"
grade x "$MISSING_PEM_ROW"
t_has "missing pem: flagged, names the consequence" "$GRADE_OUT" "cannot mint an App token at all"

MISSING_CONF_ROW=$'ok:600\tmissing\tn/a\tgho\t-\t3\t3\t3\t3\t-\t-'
grade x "$MISSING_CONF_ROW"
t_has "missing conf: flagged" "$GRADE_OUT" "gh-app.conf is MISSING"
t_hasnt "missing conf: does NOT also flag appid/owner (nothing to compare)" "$GRADE_OUT" "declares App id"

# A fixture path, not a real filesystem location -- deliberately NOT shaped
# like /home/<name>/..., which bin/hardcoded-home-lint.sh's own suite scans
# this repository's TRACKED files for and flags on sight, fixture or not.
MISMATCH_ROW=$'ok:600\tok\tmismatch:/var/tmp/selfdev-fixture/OTHER.pem\tgho\t-\t3\t3\t3\t3\t'"$CRED_APP_ID"$'\t'"$CRED_GH_OWNER"
grade x "$MISMATCH_ROW"
t_has "SELFDEV_APP_KEY mismatch: flagged" "$GRADE_OUT" "points at /var/tmp/selfdev-fixture/OTHER.pem"

WRONG_APPID_ROW=$'ok:600\tok\tmatch\tgho\t-\t3\t3\t3\t3\t9999999\t'"$CRED_GH_OWNER"
grade x "$WRONG_APPID_ROW"
t_has "divergent App id: flagged against the fleet baseline" "$GRADE_OUT" "fleet baseline is $CRED_APP_ID"

# The exact live shape found 2026-08-11: a fine-grained PAT, undeclared.
PAT_ROW=$'ok:600\tok\tmatch\tpat\t-\t3\t3\t3\t3\t'"$CRED_APP_ID"$'\t'"$CRED_GH_OWNER"
grade ecosim "$PAT_ROW"
t_has "undeclared PAT: flagged, names the ecosim incident" "$GRADE_OUT" "403ing on Pull requests"
[ "$GRADE_FLAGS" -ge 1 ] && t_ok "undeclared PAT: counted as FLAG, not gap" || t_bad "undeclared PAT: not counted as a FLAG"

# Same PAT, but declared: gap, not a FLAG.
CRED_GRANTS='
ecosim  token-type  pat  2026-08-11  fixture grant
'
grade ecosim "$PAT_ROW"
[ "$GRADE_FLAGS" -eq 0 ] && t_ok "declared PAT grant: no FLAG raised" || t_bad "declared PAT grant: still flagged ($GRADE_FLAGS FLAG)"
[ "$GRADE_GAPS" -ge 1 ] && t_ok "declared PAT grant: recorded as a gap (visible, not silent)" || t_bad "declared PAT grant: not recorded at all"
# shellcheck source=/dev/null
. "$LIB"   # restore the empty table

MISSING_TOKEN_ROW=$'ok:600\tok\tmatch\tmissing\t-\t3\t3\t3\t3\t'"$CRED_APP_ID"$'\t'"$CRED_GH_OWNER"
grade x "$MISSING_TOKEN_ROW"
t_has "no gh-token at all: flagged" "$GRADE_OUT" "gh CLI cannot authenticate"

EXTRA_ROW=$'ok:600\tok\tmatch\tgho\tecosim.pem\t3\t3\t3\t3\t'"$CRED_APP_ID"$'\t'"$CRED_GH_OWNER"
grade ecosim "$EXTRA_ROW"
t_has "undeclared extra file: flagged, names the ecosim shape" "$GRADE_OUT" "UNDECLARED extra file 'ecosim.pem'"

EXTRA_TWO_ROW=$'ok:600\tok\tmatch\tgho\ta.pem,b.pem\t3\t3\t3\t3\t'"$CRED_APP_ID"$'\t'"$CRED_GH_OWNER"
grade x "$EXTRA_TWO_ROW"
t_has "two extra files: both named" "$GRADE_OUT" "'a.pem'"
t_has "two extra files: both named (second)" "$GRADE_OUT" "'b.pem'"
[ "$GRADE_FLAGS" -ge 2 ] && t_ok "two extra files: two separate FLAGs" || t_bad "two extra files: expected >=2 FLAGs, got $GRADE_FLAGS"

WIRE_OWN_ROW=$'ok:600\tok\tmatch\tgho\t-\t0\t3\t3\t3\t'"$CRED_APP_ID"$'\t'"$CRED_GH_OWNER"
grade ecosim "$WIRE_OWN_ROW"
t_has "own-repo wiring 0/3: flagged, names the consequence" "$GRADE_OUT" "cannot push via the deploy-key channel"

WIRE_SHARED_ROW=$'ok:600\tok\tmatch\tgho\t-\t3\t3\t3\t0\t'"$CRED_APP_ID"$'\t'"$CRED_GH_OWNER"
grade x "$WIRE_SHARED_ROW"
t_has "shared-repo (senechal, 3rd) wiring 0/3: flagged by name" "$GRADE_OUT" "senechal git wiring is 0/3"

# ============================================================================
echo
echo "-- C. the CLI contract (cli-guard, --help, unknown flags) -------------"
# ============================================================================
"$SCRIPT" --not-a-real-flag >/dev/null 2>&1; t_rc "unknown flag exits 2" 2 $?
"$SCRIPT" --help >/dev/null 2>&1;            t_rc "--help exits 0" 0 $?
HELP_OUT="$("$SCRIPT" --help 2>&1)"
t_has "--help documents --audit as default" "$HELP_OUT" "--audit (default)"
t_has "--help documents --apply" "$HELP_OUT" "--apply <account>"
t_has "--help documents the BLIND exit" "$HELP_OUT" "BLIND"

"$SCRIPT" --apply >/dev/null 2>&1; t_rc "--apply with no account exits 2" 2 $?
STRAY_OUT="$("$SCRIPT" strayword 2>&1)"; STRAY_RC=$?
t_rc "a bare positional with no flag exits 2" 2 "$STRAY_RC"
t_has "the bare-positional error names the offending word" "$STRAY_OUT" "strayword"

# ============================================================================
echo
echo "-- D. --audit over a stubbed transport (no live ssh, no live gh) ------"
# ============================================================================
STUB="$T/stub"; mkdir -p "$STUB"

# A stub `ssh` that answers fetch_remote's `bash -s -- <args...>` shape (the
# FILTER positional is the 4th token after "--") from $STUB_ROWS, and treats
# any OTHER invocation (cmd_apply's one-shot commands) as "log it, succeed" --
# see section E, which points CRED_APP_PEM_SRC/CONF_SRC at real fixture files
# and inspects this log rather than trusting a bare exit code.
#
# `flat="$*"` DELIBERATELY THROWS AWAY the argv boundaries this stub was
# actually invoked with, then re-derives them by joining with one space and
# re-splitting -- reproducing the ONE property of REAL ssh that broke this
# script against the live fleet: ssh joins every argument after the remote
# command into ONE STRING and the remote shell re-parses THAT STRING, so a
# caller's argv boundaries do not survive the trip. An empty-string argument
# contributes zero characters to the join and VANISHES, shifting every later
# argument one position left. A first draft of this stub used "$@" directly
# (real, boundary-preserving argv), which cannot fail this way no matter what
# the script under test does -- it would have stayed green through the exact
# regression found live while building this suite. Every fetch_remote-shaped
# case below is therefore also a regression test for that bug: if
# fetch_remote's "-" sentinel default is ever reverted to plain "${1:-}",
# these fixtures (named for accounts, never for "hf7y" or a repo) go BLIND.
cat > "$STUB/ssh" <<'STUBSH'
#!/usr/bin/env bash
LOG="${STUB_LOG:-/dev/null}"
flat="$*"
case "$flat" in
  *" -- "*)
    after="${flat#*-- }"
    # shellcheck disable=SC2206
    args=($after)
    filter="${args[3]:-}"
    cat < /dev/null
    if [ -n "$filter" ] && [ "$filter" != "-" ]; then
      printf '%s\n' "${STUB_ROWS:-}" | grep "^$filter"$'\t' || true
    else
      printf '%s\n' "${STUB_ROWS:-}"
    fi
    exit "${STUB_SSH_RC:-0}"
    ;;
esac
cmd="$flat"
stdin_hash="-"; [ -t 0 ] || stdin_hash="$(cat 2>/dev/null | sha256sum | cut -d' ' -f1)"
printf 'CMD: %s | STDIN: %s\n' "$cmd" "$stdin_hash" >> "$LOG"
[ -n "${STUB_FAIL_MATCH:-}" ] && [[ "$cmd" == *"$STUB_FAIL_MATCH"* ]] && exit 1
exit 0
STUBSH
chmod +x "$STUB/ssh"

# A stub `gh` for the deploy-key symmetry section. `readOnly` per repo is read
# from $STUB_JSON_<repo> so different scenarios can be expressed without
# touching this file.
cat > "$STUB/gh" <<'STUBGH'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") [ "${STUB_GH_AUTH_FAIL:-0}" = 1 ] && exit 1; exit 0 ;;
  "repo deploy-key")
    repo=""
    for ((i=1; i<=$#; i++)); do [ "${!i}" = "--repo" ] && { j=$((i+1)); repo="${!j}"; }; done
    var="STUB_JSON_${repo#hf7y/}"; var="${var//-/_}"
    printf '%s' "${!var:-[]}"
    ;;
  *) exit 1 ;;
esac
STUBGH
chmod +x "$STUB/gh"

FULL_CLEAN_ROWS='fleet-clean	ok:600	ok	match	gho	-	3	3	3	3	4521586	hf7y'
# A GENUINELY clean run needs the deploy-key symmetry section clean too, not
# merely absent -- gh being unreachable is its own BLIND (asserted separately
# below) and correctly keeps the overall exit non-zero, matching this
# script's "BLIND is never ok" contract. So THIS case supplies a gh stub that
# reports the exact fixture account correctly wired on all four repos.
O="$(STUB_ROWS="$FULL_CLEAN_ROWS" CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN="$STUB/gh" \
     STUB_JSON_realisateur='[{"title":"monkey-fleet-clean-realisateur","readOnly":true}]' \
     STUB_JSON_scheduler='[{"title":"monkey-fleet-clean-scheduler","readOnly":true}]' \
     STUB_JSON_senechal='[{"title":"monkey-fleet-clean-senechal","readOnly":true}]' \
     STUB_JSON_fleet_clean='[{"title":"monkey-fleet-clean-fleet-clean","readOnly":false}]' \
     "$SCRIPT" --audit 2>&1)"; R=$?
t_rc "a genuinely clean fleet (files AND deploy keys) exits 0" 0 "$R"
t_has "clean fleet: reports matches baseline" "$O" "fleet-clean: matches baseline"

# The SAME file-level-clean fixture, with gh unreachable, must NOT read as
# clean -- BLIND on one section still makes the overall run non-zero.
O="$(STUB_ROWS="$FULL_CLEAN_ROWS" CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN=/nonexistent-gh "$SCRIPT" --audit 2>&1)"; R=$?
t_rc "file-clean but gh unreachable still exits non-zero (BLIND is never ok)" 1 "$R"

FULL_DRIFT_ROWS='fleet-drift	missing	missing	n/a	pat	x.pem	0	3	3	3	-	-'
O="$(STUB_ROWS="$FULL_DRIFT_ROWS" CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN=/nonexistent-gh "$SCRIPT" --audit 2>&1)"; R=$?
t_rc "a drifted fleet exits 1" 1 "$R"
t_has "drifted fleet: FLAG on missing pem" "$O" "app.pem is MISSING"
t_has "drifted fleet: prints the redundancy note" "$O" "redundant on that path"
t_has "drifted fleet: names hf7y/scheduler#103" "$O" "scheduler#103"

MIXED_ROWS=$'fleet-clean\tok:600\tok\tmatch\tgho\t-\t3\t3\t3\t3\t4521586\thf7y\nfleet-blind\tBLIND'
O="$(STUB_ROWS="$MIXED_ROWS" CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN=/nonexistent-gh "$SCRIPT" --audit 2>&1)"; R=$?
t_rc "one BLIND account among clean ones still exits 1 (never silently ok)" 1 "$R"
t_has "mixed fleet: BLIND account reported, not skipped" "$O" "fleet-blind"
t_has "mixed fleet: BLIND account marked BLIND, not ok" "$O" "BLIND fleet-blind"

O="$(STUB_SSH_RC=255 CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN=/nonexistent-gh "$SCRIPT" --audit 2>&1)"; R=$?
t_rc "an unreachable host exits 3, not 0 and not 1" 3 "$R"
t_has "unreachable host: says BLIND and names nothing was verified" "$O" "Nothing was verified"

O="$(STUB_ROWS="" CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN=/nonexistent-gh "$SCRIPT" --audit 2>&1)"; R=$?
t_rc "zero accounts found exits 3 (BLIND, not a clean empty fleet)" 3 "$R"

# --- gh missing/unauthenticated degrades to BLIND, not a crash -------------
O="$(STUB_ROWS="$FULL_CLEAN_ROWS" CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN=/nonexistent-gh "$SCRIPT" --audit 2>&1)"
t_has "gh absent: deploy-key section reports BLIND by name" "$O" "not on PATH -- could not check GitHub-side"

O="$(STUB_ROWS="$FULL_CLEAN_ROWS" CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN="$STUB/gh" STUB_GH_AUTH_FAIL=1 "$SCRIPT" --audit 2>&1)"
t_has "gh unauthenticated: deploy-key section reports BLIND by name" "$O" "not authenticated here"

# ============================================================================
echo
echo "-- D2. deploy-key symmetry grading -- the false/null jq regression ----"
# ============================================================================
# THE REGRESSION THIS PINS: jq's `//` treats `false` as falsy, same as
# `null`. A first draft used `.readOnly // empty`, which turned every
# legitimate "readOnly": false (a WRITE key -- an account's OWN repo, the
# case this whole section exists to confirm) into empty output, which the
# caller read as "no key registered at all". Found live while building this
# suite, against a real fixture, before this test existed to pin it.
STUB_JSON_solo="$(printf '[{"title":"monkey-solo-solo","readOnly":false}]')"
O="$(STUB_ROWS='solo	ok:600	ok	match	gho	-	3	3	3	3	4521586	hf7y' \
     CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN="$STUB/gh" \
     STUB_JSON_realisateur='[]' STUB_JSON_scheduler='[]' STUB_JSON_senechal='[]' \
     STUB_JSON_solo="$STUB_JSON_solo" \
     "$SCRIPT" --audit 2>&1)"
t_has "own-repo readOnly:false is recognized as WRITE, not 'no key'" "$O" "solo: solo deploy key is WRITE, matching the symmetry rule"
t_hasnt "own-repo readOnly:false is NOT reported as missing" "$O" "no deploy key registered on solo"

STUB_JSON_realisateur='[{"title":"monkey-writer-realisateur","readOnly":false}]'
O="$(STUB_ROWS='writer	ok:600	ok	match	gho	-	3	3	3	3	4521586	hf7y' \
     CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN="$STUB/gh" \
     STUB_JSON_realisateur="$STUB_JSON_realisateur" STUB_JSON_scheduler='[]' STUB_JSON_senechal='[]' \
     STUB_JSON_writer='[]' \
     "$SCRIPT" --audit 2>&1)"
t_has "a WRITE key on a SHARED repo is flagged (the cross-repo-push shape)" "$O" "realisateur (SHARED repo) deploy key is WRITE"

# ============================================================================
echo
echo "-- D3. deploy-key symmetry grading -- the read_only field-name regression"
# ============================================================================
# THE REGRESSION THIS PINS, FOUND LIVE AGAINST THE REAL FLEET (not a fixture):
# `gh repo deploy-key list --json title,readOnly` on gh 2.45.0 VALIDATES
# "readOnly" as a real field name (an unknown one is refused, and the
# refusal's own error text names "readOnly" as correct) and then does not
# actually filter by it -- the call returns the endpoint's raw default shape,
# where the key is `read_only` (snake_case). `.readOnly` on that object is
# always `null`. The `case "$want:$ro"` statement had THREE arms and no
# default, so `ro=null` matched NONE of them and the entire symmetry section
# printed nothing at all for a live 13-repo run: not ok, not FLAG, not BLIND
# -- exactly the silent-negative shape BUILD-DISCIPLINE.md's pattern 14
# names, and worse than a wrong answer because nothing said a check had even
# run. These fixtures use the REAL shape (read_only, no readOnly key at all)
# on purpose, rather than the readOnly shape D2 already covers, so a future
# edit cannot silently go back to trusting the field gh's validator claims
# rather than the field gh's endpoint actually sends.
STUB_JSON_realword='[{"title":"monkey-realword-realword","read_only":false}]'
O="$(STUB_ROWS='realword	ok:600	ok	match	gho	-	3	3	3	3	4521586	hf7y' \
     CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN="$STUB/gh" \
     STUB_JSON_realisateur='[{"title":"monkey-realword-realisateur","read_only":true}]' \
     STUB_JSON_scheduler='[{"title":"monkey-realword-scheduler","read_only":true}]' \
     STUB_JSON_senechal='[{"title":"monkey-realword-senechal","read_only":true}]' \
     STUB_JSON_realword="$STUB_JSON_realword" \
     "$SCRIPT" --audit 2>&1)"
R_RC=$?
t_has "real gh shape (read_only, own repo, false=WRITE): recognized" "$O" "realword: realword deploy key is WRITE, matching the symmetry rule"
t_has "real gh shape (read_only, shared repo, true=READ-ONLY): recognized" "$O" "realword: realisateur deploy key is READ-ONLY, matching the symmetry rule"
t_rc "a fully correct real-shape fleet exits 0" 0 "$R_RC"

# A WRITE key on a shared repo, expressed in the REAL field name, must still
# be caught -- not just the camelCase fixture D2 already exercises.
O="$(STUB_ROWS='badword	ok:600	ok	match	gho	-	3	3	3	3	4521586	hf7y' \
     CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN="$STUB/gh" \
     STUB_JSON_realisateur='[{"title":"monkey-badword-realisateur","read_only":false}]' \
     STUB_JSON_scheduler='[]' STUB_JSON_senechal='[]' STUB_JSON_badword='[]' \
     "$SCRIPT" --audit 2>&1)"
t_has "real gh shape: a WRITE key on a shared repo is still flagged" "$O" "realisateur (SHARED repo) deploy key is WRITE"

# The fail-loud default arm itself: an unrecognized readOnly-shaped value
# must read as BLIND, never as silence. Exercised directly, not by trying to
# reproduce a gh version skew: `has()` on the fixture object true either way,
# so the only path left to the default arm is a value that is a matching
# title but neither `true` nor `false` under either key name -- constructed
# here as a broken fixture, the same way a genuinely different future gh
# response shape would arrive.
O="$(STUB_ROWS='oddshape	ok:600	ok	match	gho	-	3	3	3	3	4521586	hf7y' \
     CRED_SSH_BIN="$STUB/ssh" CRED_GH_BIN="$STUB/gh" \
     STUB_JSON_realisateur='[{"title":"monkey-oddshape-realisateur","readOnly":"maybe"}]' \
     STUB_JSON_scheduler='[]' STUB_JSON_senechal='[]' STUB_JSON_oddshape='[]' \
     "$SCRIPT" --audit 2>&1)"
t_has "an unrecognized readOnly value is reported BLIND, never silent" "$O" "returned an unreadable readOnly value"

# ============================================================================
echo
echo "-- E. --apply: idempotency, converge actions, and refusals ------------"
# ============================================================================
SRC="$T/src"; mkdir -p "$SRC"
printf 'FIXTURE-PEM-BYTES\n' > "$SRC/app.pem"
printf 'SELFDEV_APP_ID=4521586\nSELFDEV_APP_KEY=/x\nSELFDEV_GH_OWNER=hf7y\n' > "$SRC/gh-app.conf"

LOG="$T/apply.log"; : > "$LOG"
CLEAN_SINGLE='conv-clean	ok:600	ok	match	gho	-	3	3	3	3	4521586	hf7y'
O="$(STUB_ROWS="$CLEAN_SINGLE" CRED_SSH_BIN="$STUB/ssh" STUB_LOG="$LOG" \
     CRED_APP_PEM_SRC="$SRC/app.pem" CRED_APP_CONF_SRC="$SRC/gh-app.conf" \
     "$SCRIPT" --apply conv-clean 2>&1)"; R=$?
t_rc "apply on an already-compliant account exits 0" 0 "$R"
t_has "apply on a compliant account reports nothing to do" "$O" "nothing to do"
[ -s "$LOG" ] && t_bad "apply on a compliant account issued a remote command (log not empty)" \
              || t_ok "apply on a compliant account issued NO remote command"

: > "$LOG"
NEEDS_CREDS='conv-fix	missing	missing	n/a	gho	-	0	3	3	0	-	-'
O="$(STUB_ROWS="$NEEDS_CREDS" CRED_SSH_BIN="$STUB/ssh" STUB_LOG="$LOG" \
     CRED_APP_PEM_SRC="$SRC/app.pem" CRED_APP_CONF_SRC="$SRC/gh-app.conf" \
     "$SCRIPT" --apply conv-fix 2>&1)"; R=$?
t_rc "apply that converges pem+conf+wiring exits 0" 0 "$R"
t_has "apply reports the pem/conf install" "$O" "app.pem + gh-app.conf installed"
t_has "apply reminds the operator to notify-senechal" "$O" "notify-senechal 'selfdev-credentials --apply"
PEM_HASH="$(sha256sum "$SRC/app.pem" | cut -d' ' -f1)"
CONF_HASH="$(sha256sum "$SRC/gh-app.conf" | cut -d' ' -f1)"
t_has "apply piped the REAL app.pem bytes over stdin (hash matches)" "$(cat "$LOG")" "$PEM_HASH"
t_has "apply piped the REAL gh-app.conf bytes over stdin (hash matches)" "$(cat "$LOG")" "$CONF_HASH"
t_has "apply delegates own-repo wiring to wire-selfdev-git.sh --apply --rw" "$(cat "$LOG")" "wire-selfdev-git.sh' 'conv-fix' --apply --rw"
t_has "apply delegates senechal wiring to wire-selfdev-git.sh --apply (read-only)" "$(cat "$LOG")" "wire-selfdev-git.sh' 'senechal' --apply\""
t_hasnt "apply never touches realisateur wiring when it is already 3/3" "$(cat "$LOG")" "'realisateur' --apply"
t_hasnt "apply never touches scheduler wiring when it is already 3/3" "$(cat "$LOG")" "'scheduler' --apply"

: > "$LOG"
O="$(STUB_ROWS='conv-nosrc	missing	missing	n/a	gho	-	3	3	3	3	-	-' \
     CRED_SSH_BIN="$STUB/ssh" STUB_LOG="$LOG" \
     CRED_APP_PEM_SRC="$T/does-not-exist.pem" CRED_APP_CONF_SRC="$T/does-not-exist.conf" \
     "$SCRIPT" --apply conv-nosrc 2>&1)"; R=$?
t_rc "apply with no canonical local source to copy from exits 5" 5 "$R"
t_has "apply names why it refused (no source, needs a human)" "$O" "cannot converge this without a human"
[ -s "$LOG" ] && t_bad "apply with no source still issued a remote command" \
              || t_ok "apply with no source issued NO remote command (nothing destructive attempted)"

: > "$LOG"
O="$(STUB_ROWS='conv-blind	BLIND' CRED_SSH_BIN="$STUB/ssh" STUB_LOG="$LOG" "$SCRIPT" --apply conv-blind 2>&1)"; R=$?
t_rc "apply against a BLIND account exits 5" 5 "$R"
t_has "apply on a BLIND account refuses by name" "$O" "read as BLIND"
[ -s "$LOG" ] && t_bad "apply on a BLIND account still issued a remote command" \
              || t_ok "apply on a BLIND account issued NO remote command"

: > "$LOG"
O="$(STUB_ROWS='conv-fail	ok:600	ok	match	gho	-	0	3	3	3	4521586	hf7y' \
     STUB_FAIL_MATCH="wire-selfdev-git.sh' 'conv-fail'" \
     CRED_SSH_BIN="$STUB/ssh" STUB_LOG="$LOG" \
     CRED_APP_PEM_SRC="$SRC/app.pem" CRED_APP_CONF_SRC="$SRC/gh-app.conf" \
     "$SCRIPT" --apply conv-fail 2>&1)"; R=$?
t_rc "apply propagates a failed delegate step as exit 5" 5 "$R"
t_has "apply reports the failed step and does not claim success" "$O" "FAILED"

O="$(STUB_ROWS="" CRED_SSH_BIN="$STUB/ssh" "$SCRIPT" --apply unknown-account 2>&1)"; R=$?
t_rc "apply against an account outside the uid band exits 5" 5 "$R"

# ============================================================================
echo
echo "-- F. source invariants -- what --apply must never even attempt -------"
# ============================================================================
SRC_TXT="$(cat "$SCRIPT")"
t_hasnt "never deletes anything (no rm -f/-r on a credential path)" "$SRC_TXT" 'rm -'
t_hasnt "never truncates or writes ~/.config/gh/hosts.yml" "$SRC_TXT" 'hosts.yml"'$'\n''>'
t_hasnt "never opens hosts.yml for writing (> or >>)" "$SRC_TXT" '> "$hosts'
t_hasnt "never mints a NEW key (no ssh-keygen)" "$SRC_TXT" "ssh-keygen"
t_hasnt "never mints a NEW key (no openssl genrsa/req)" "$SRC_TXT" "openssl genrsa"
t_has "does delegate git wiring to wire-selfdev-git.sh (reuse, not reimplement)" "$SRC_TXT" "wire-selfdev-git.sh"
t_has "declares its GUARD:no opt-out with a reason" "$SRC_TXT" "# GUARD: no --"
t_has "reads the token's oauth_token line but never echoes the token value" "$SRC_TXT" "grep oauth_token"
t_hasnt "the token classifier never captures anything past the shape prefix" "$SRC_TXT" 'printf.*oauth_token.*\$token'

echo
echo "selfdev-credentials.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
