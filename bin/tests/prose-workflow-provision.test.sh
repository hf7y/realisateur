#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/prose-workflow-provision.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp
echo "prose-workflow-provision.test.sh"

FIX="$T/fix"; mkdir -p "$FIX"
GH="$T/gh"
cat > "$GH" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
if [ "${1:-}" = api ]; then
  shift
  if [ "${1:-}" = -X ]; then
    path="$3"; shift 3
    key="$(printf '%s' "$path" | tr -c 'A-Za-z0-9' '_')"
    if [ -n "${PUT_BODY_DIR:-}" ]; then printf '%s\n' "$*" > "$PUT_BODY_DIR/$key"; fi
    case "$path" in
      */git/refs)     [ -f "$FIX/refuse-branch" ]   && exit 1 ;;
      */contents/*)   [ -f "$FIX/refuse-write" ]     && exit 1 ;;
    esac
    exit 0
  fi
  path="$1"
  key="$(printf '%s' "$path" | tr -c 'A-Za-z0-9' '_')"
  [ -f "$FIX/$key" ] || exit 1
  cat "$FIX/$key"
  exit 0
fi
if [ "${1:-}" = pr ] && [ "${2:-}" = create ]; then
  [ -f "$FIX/refuse-pr" ] && exit 1
  echo "https://github.com/hf7y/fake/pull/1"
  exit 0
fi
exit 0
STUB
chmod +x "$GH"

APPTOK="$T/apptok"
cat > "$APPTOK" <<'STUB'
#!/usr/bin/env bash
[ -f "$FIX/refuse-token" ] && exit 1
echo "ghs_faketoken0000000000000000000000"
STUB
chmod +x "$APPTOK"

put() { local k; k="$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '_')"; shift; cat > "$FIX/$k"; }

written_body() {
  [ -f "$1" ] || return 0
  grep -oE 'content=[A-Za-z0-9+/=]+' "$1" | head -1 | cut -d= -f2- | base64 -d 2>/dev/null
}

repo() {   # <name> <private: true|false> -- default_branch always main
  put "repos/hf7y/$1" <<<"{\"private\":$2,\"default_branch\":\"main\"}"
}
present() { put "repos/hf7y/$1/contents/.github/workflows/prose.yml?ref=main" <<<'{"sha":"deadbeef"}'; }
head_sha() { put "repos/hf7y/$1/git/ref/heads/main" <<<'{"object":{"sha":"cafebabe"}}'; }
no_open_prs() { put "repos/hf7y/$1/pulls?state=open&per_page=100" <<<'[]'; }
one_open_pr() { put "repos/hf7y/$1/pulls?state=open&per_page=100" <<<'[{"head":{"ref":"prose-workflow-20260101000000"}}]'; }

repo tidy false;    present tidy
repo gappy true;    head_sha gappy;  no_open_prs gappy
repo pubgap false;  head_sha pubgap; no_open_prs pubgap
repo reopened true; head_sha reopened; one_open_pr reopened
repo ghost false   # no contents fixture (missing), no head/pulls fixtures either -- for BLIND cases

run() { GH_LOG="$T/log" GH_BIN="$GH" FIX="$FIX" PROSE_APP_TOKEN_CMD="$APPTOK" \
        PUT_BODY_DIR="${PUT_BODY_DIR:-}" bash "$SCRIPT" "$@" 2>&1; }

section "A. the argument contract"
run --not-a-real-flag >/dev/null 2>&1; eq "A1 unknown flag exits 2" "$?" "2"
run >/dev/null 2>&1; eq "A2 no repo named exits 2" "$?" "2"
OUT="$(run --help)"; eq "A3 --help exits 0" "$?" "0"
has "A4 --help documents BLIND" "$OUT" "BLIND"

section "B. a repo that already carries prose.yml is clean"
: > "$T/log"; OUT="$(run tidy)"; RC=$?
eq  "B1 exits 0" "$RC" "0"
has "B2 says ok, naming the file" "$OUT" "ok      tidy: .github/workflows/prose.yml already present"
hasnt "B3 nothing was written -- a repo that already complies is never touched" "$(cat "$T/log")" "-X"

section "C. --check on a repo with no workflow is a finding, not a write"
: > "$T/log"; OUT="$(run gappy)"; RC=$?
eq  "C1 exits 1" "$RC" "1"
has "C2 names it MISSING and its visibility" "$OUT" "MISSING gappy (private): no .github/workflows/prose.yml on main"
has "C3 names the remedy" "$OUT" "prose-workflow-provision.sh --apply gappy"
hasnt "C4 wrote nothing" "$(cat "$T/log")" "-X"

section "D. --apply opens a PR for a PRIVATE gap, runs_on self-hosted"
PUT_BODY_DIR="$T/put"; mkdir -p "$PUT_BODY_DIR"
: > "$T/log"; OUT="$(run --apply gappy)"; RC=$?
eq  "D1 exits 0 once the PR is opened" "$RC" "0"
has "D2 says applied" "$OUT" "applied gappy: PR opened"
has "D3 a branch was created" "$(cat "$T/log")" "-X POST repos/hf7y/gappy/git/refs"
BODY="$T/put/$(printf '%s' 'repos/hf7y/gappy/contents/.github/workflows/prose.yml' | tr -c 'A-Za-z0-9' '_')"
[ -f "$BODY" ] || bad "D4 the write body was captured" "no file at $BODY"
has "D5 the written content requests a self-hosted runner"  "$(written_body "$BODY")" 'self-hosted'
has "D6 a PR was opened against main" "$(cat "$T/log")" "pr create --repo hf7y/gappy --base main"
unset PUT_BODY_DIR

section "E. --apply opens a PR for a PUBLIC gap, no runs_on line"
PUT_BODY_DIR="$T/put2"; mkdir -p "$PUT_BODY_DIR"
: > "$T/log"; OUT="$(run --apply pubgap)"; RC=$?
eq  "E1 exits 0" "$RC" "0"
BODY="$T/put2/$(printf '%s' 'repos/hf7y/pubgap/contents/.github/workflows/prose.yml' | tr -c 'A-Za-z0-9' '_')"
hasnt "E2 the written content carries no self-hosted runs_on" "$(written_body "$BODY")" 'self-hosted'
unset PUT_BODY_DIR

section "F. an open PR from a prior run stops a second one (idempotent re-run)"
: > "$T/log"; OUT="$(run --apply reopened)"; RC=$?
eq  "F1 exits 0" "$RC" "0"
has "F2 recognises the earlier PR" "$OUT" "reopened: a PR already open from a prior run"
hasnt "F3 no second branch was created" "$(cat "$T/log")" "git/refs"
hasnt "F4 no second file write" "$(cat "$T/log")" "-X PUT"

section "G. could-not-look is BLIND, never clean, and never partial"
: > "$T/log"; OUT="$(run ghost)"; RC=$?
eq  "G1 a repo whose contents call 404s with no fixture at all reads as missing, not BLIND" "$RC" "1"
has "G2 reported MISSING" "$OUT" "MISSING ghost"

rm -f "$FIX/$(printf '%s' 'repos/hf7y/ghost' | tr -c 'A-Za-z0-9' '_')"
: > "$T/log"; OUT="$(run ghost)"; RC=$?
eq  "G3 a repo that will not answer at all exits 6" "$RC" "6"
has "G4 named BLIND" "$OUT" "BLIND   ghost: the repo would not answer"
has "G5 the counts are called untrustworthy" "$OUT" "NOT trustworthy"

section "H. a token that cannot be minted is BLIND under --apply, and writes nothing"
: > "$FIX/refuse-token"
: > "$T/log"; OUT="$(run --apply gappy)"; RC=$?
rm -f "$FIX/refuse-token"
eq  "H1 exits 6" "$RC" "6"
has "H2 names the failure" "$OUT" "could not mint an App token"
hasnt "H3 wrote nothing" "$(cat "$T/log")" "-X"

section "I. it is declared, so it reaches a host by a named channel"
. "$ROOT/lib/propagation-set.sh"
ch="$(prop_channel prose-workflow-provision.sh 2>/dev/null)" || ch=""
eq "I1 prop_channel says local -- its subject is ANOTHER repo, reached by a minted App token, not this host's own deploy key" "$ch" "local"

echo
summary
