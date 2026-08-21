#!/usr/bin/env bash
#
# TRAPS (the rest of this header is in the vault):
# Cases:
#   A unreadable repo (stub returns nonzero)     -> BLIND, exit 2
#   B a populated repo reports secrets/keys/hooks/rulesets/protection
#   C an empty repo reports "none" for each, not silence
#   D no repo named -> falls back to the scheduler registry's REPO_URLs
#   E no repo named and an empty registry        -> BLIND, exit 2
#   F a scheduler account wired to the same slug is named
#   G hardcoded owner/repo strings: found, absent, and no local clone (BLIND
#     for that one line only -- does not fail the whole audit)
#   H Pages cname=null + a non-github.io html_url is flagged; a real custom
#     domain is not
#   I secrets are named, never valued -- the fixture's secret value never
#     appears in the output
#
# Usage: bin/tests/org-migration-audit.test.sh   (exit 0 = all pass)

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/org-migration-audit.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/schedule" "$T/projects"

# --- the gh stub: answers `api <path>` from a fixture table ----------------
cat > "$T/gh" <<'STUBEOF'
#!/usr/bin/env bash
[ "$1" = "api" ] || exit 1
path="$2"
case "$path" in
  "repos/acme/full")                      echo '{}' ;;
  "repos/acme/full/pages")                echo '{"cname":"play.acme.com","html_url":"https://play.acme.com/"}' ;;
  "repos/acme/full/actions/secrets")      echo '{"total_count":2,"secrets":[{"name":"ANTHROPIC_API_KEY","value":"nope-never"},{"name":"DEPLOY_TOKEN"}]}' ;;
  "repos/acme/full/keys")                 echo '[{"title":"ci-key"},{"title":"human-laptop"}]' ;;
  "repos/acme/full/hooks")                echo '[{"name":"web"}]' ;;
  "repos/acme/full/rulesets")             echo '[{"name":"main protection"}]' ;;
  "repos/acme/full/branches/main/protection") echo '{"required_status_checks":{"contexts":["build","test"],"checks":[{"context":"build","app_id":1},{"context":"test","app_id":1}]}}' ;;

  "repos/acme/empty")                     echo '{}' ;;
  "repos/acme/empty/pages")               echo '{"message":"Not Found"}'; exit 1 ;;
  "repos/acme/empty/actions/secrets")     echo '{"total_count":0,"secrets":[]}' ;;
  "repos/acme/empty/keys")                echo '[]' ;;
  "repos/acme/empty/hooks")               echo '[]' ;;
  "repos/acme/empty/rulesets")            echo '[]' ;;
  "repos/acme/empty/branches/main/protection") echo '{"message":"Not Found"}'; exit 1 ;;

  "repos/acme/proxied")                   echo '{}' ;;
  "repos/acme/proxied/pages")             echo '{"cname":null,"html_url":"http://acme.com/proxied/"}' ;;
  "repos/acme/proxied/actions/secrets")   echo '{"total_count":0,"secrets":[]}' ;;
  "repos/acme/proxied/keys")              echo '[]' ;;
  "repos/acme/proxied/hooks")             echo '[]' ;;
  "repos/acme/proxied/rulesets")          echo '[]' ;;
  "repos/acme/proxied/branches/main/protection") echo '{"message":"Not Found"}'; exit 1 ;;

  "repos/acme/gone")                      echo '{"message":"Not Found"}'; exit 1 ;;

  *) echo '{"message":"Not Found"}'; exit 1 ;;
esac
STUBEOF
chmod +x "$T/gh"

run() { GH_BIN="$T/gh" SCHED_ROOT="$T" PROJECTS_ROOT="$T/projects" "$SCRIPT" "$@" 2>&1; }

# --- A: unreadable repo is BLIND, not silence -------------------------------
out="$(run acme/gone)"; rc_got=$?
has "A1 unreadable repo says BLIND"         "$out" "BLIND -- could not read repos/acme/gone"
rc  "A2 exit 6 (BLIND)"                             6 "$rc_got"

# --- B: a populated repo reports each channel -------------------------------
out="$(run acme/full)"
has "B1 secrets are named"                  "$out" "ANTHROPIC_API_KEY"
has "B2 second secret named too"            "$out" "DEPLOY_TOKEN"
has "B3 deploy keys named"                  "$out" "ci-key"
has "B4 rulesets named"                     "$out" "main protection"
has "B5 branch protection contexts named"   "$out" "build, test"
has "B6 webhook count reported"             "$out" "1 hook(s)"
has "B7 secrets are marked HUMAN"           "$out" "do not travel with a transferred repo"

# --- I: a secret VALUE in the fixture never reaches the output -------------
hasnt "I1 secret value never printed"       "$out" "nope-never"

# --- C: an empty repo reports 'none', not silence ---------------------------
out="$(run acme/empty)"
has "C1 no secrets -> 'none'"               "$out" "Secrets          none"
has "C2 no deploy keys -> 'none'"           "$out" "Deploy keys      none"
has "C3 no rulesets -> 'none'"              "$out" "Rulesets         none"
has "C4 no pages -> 'not configured'"       "$out" "not configured"
has "C5 no branch protection -> says so"    "$out" "none, or main unprotected"

# --- H: the Pages proxy note fires only when it should ----------------------
out="$(run acme/proxied)"
has "H1 proxied domain flagged"             "$out" "org/user-level Pages proxy"
out="$(run acme/full)"
hasnt "H2 a real custom domain is not flagged" "$out" "org/user-level Pages proxy"

# --- D/E: no repo named falls back to the scheduler registry ---------------
cat > "$T/schedule/full-proj.conf" <<'EOF'
PROJECT_REPO_PATH="$HOME/Documents/Projects/full-proj"
REPO_URL="https://github.com/acme/full.git"
EOF
cat > "$T/schedule/_ignored.conf" <<'EOF'
REPO_URL="https://github.com/acme/should-not-appear.git"
EOF
out="$(run)"; rc_got=$?
has  "D1 registry fallback audits the registered repo" "$out" "org-migration-audit: acme/full"
hasnt "D2 an _-prefixed conf is not scanned"            "$out" "should-not-appear"
rc   "D3 exit 0 when the fallback found something"      0 "$rc_got"

rm -f "$T/schedule/full-proj.conf" "$T/schedule/_ignored.conf"
out="$(run)"; rc_got=$?
has "E1 empty registry and no repo named is BLIND" "$out" "no repo named"
rc  "E2 exit 6 (BLIND)"                                    6 "$rc_got"

# --- F: a scheduler account wired to this slug is surfaced ------------------
cat > "$T/schedule/full-proj.conf" <<'EOF'
REPO_URL="https://github.com/acme/full.git"
EOF
out="$(run acme/full)"
has "F1 the account name is surfaced"          "$out" "account(s): full-proj"
has "F2 it is marked HUMAN"                    "$out" "re-run the wiring for the new owner"
out="$(run acme/empty)"
has "F3 an unwired slug says so"               "$out" "no scheduler-registered account references this slug"
rm -f "$T/schedule/full-proj.conf"

# --- G: hardcoded owner/repo strings -- found, absent, and no clone at all --
mkdir -p "$T/projects/full" && (
  cd "$T/projects/full" && git init -q && git config user.email t@t && git config user.name t
  printf 'const REPO = "acme/full";\n' > config.js
  git add config.js && git commit -qm init
)
out="$(run acme/full)"
has "G1 a hardcoded ref is found and named"    "$out" "config.js"
has "G2 marked SCRIPTABLE"                     "$out" "a literal owner/repo string does not update itself"

mkdir -p "$T/projects/empty" && (
  cd "$T/projects/empty" && git init -q && git config user.email t@t && git config user.name t
  printf 'nothing here\n' > readme.txt
  git add readme.txt && git commit -qm init
)
out="$(run acme/empty)"
has "G3 a clean clone says none found"         "$out" "none found in tracked files"

out="$(run acme/proxied)"
has "G4 no local clone is BLIND for that line only" "$out" "Hardcoded refs   BLIND"
rc_got=$?
rc "G5 the whole audit still exits 0"          0 "$rc_got"

summary
