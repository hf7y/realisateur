#!/usr/bin/env bash
#
# TRAPS (the rest of this header is in the vault):
# Cases:
#   A already protected with a context      -> "ok", counted protected
#   B unprotected, has PR checks            -> UNPROT, and --apply writes them
#   C unprotected, no check ever ran on a PR -> NOCI, never protected
#   D repo unreadable                       -> BLIND, exit 2, never "ok"
#   E the 404-BODY TRAP (regression)        -> an unprotected branch is not
#     read as protected just because `gh api` printed the 404 JSON to stdout
#   F matrix legs are dropped when a stable sibling context exists
#   G pages-build-deployment is never required
#   H bare invocation writes nothing; --strict gates
#
# Usage: bin/tests/branch-protection-provision.test.sh   (exit 0 = all pass)

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/branch-protection-provision.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# The stub speaks the four API shapes the script uses. Fixture repos are named
# after real roster entries so the positional filter matches them.
#   chezz     -- unprotected, PR checks incl. matrix legs + a Pages context
#   crt       -- unprotected, no checks ever ran on its PR      (NOCI)
#   basheur   -- unprotected, no PR has ever been opened        (NOCI)
#   realisateur -- already protected with [markdown-cost]
#   gardien   -- unreadable                                     (BLIND)
PUTS="$T/put-calls.log"; : > "$PUTS"
cat > "$T/gh" <<EOF
#!/usr/bin/env bash
PUTS="$PUTS"
STATE="$T/protected"
url=""
for a in "\$@"; do case "\$a" in repos/*) url="\$a"; break ;; esac; done

# -X PUT <protection>: record the payload, then mark the repo protected so a
# re-read reflects the write -- the script verifies by re-reading, and a stub
# that ignored the write would let a broken verify pass.
for a in "\$@"; do
  if [ "\$a" = "PUT" ]; then
    body="\$(cat)"
    echo "\$url \$body" >> "\$PUTS"
    repo="\$(printf '%s' "\$url" | cut -d/ -f2-3)"
    mkdir -p "\$STATE"
    printf '%s' "\$body" | jq -r '.required_status_checks.contexts|join(",")' \
      > "\$STATE/\$(printf '%s' "\$repo" | tr / _)"
    exit 0
  fi
done

case "\$url" in
  repos/acme/gardien) exit 1 ;;                       # unreadable at all
  repos/acme/*/branches/main/protection)
    repo="\$(printf '%s' "\$url" | cut -d/ -f2-3)"
    f="\$STATE/\$(printf '%s' "\$repo" | tr / _)"
    if [ -f "\$f" ]; then
      jq -cn --arg c "\$(cat "\$f")" '{required_status_checks:{contexts:(\$c|split(","))}}'
      exit 0
    fi
    case "\$repo" in
      acme/realisateur)
        echo '{"required_status_checks":{"contexts":["markdown-cost"]}}'; exit 0 ;;
    esac
    # THE TRAP: a 404 prints its body to stdout AND exits non-zero.
    echo '{"message":"Branch not protected","status":"404"}'
    exit 1 ;;
  repos/acme/*/pulls*)
    case "\$url" in
      repos/acme/basheur/*) echo '[]' ;;              # no PR has ever existed
      *) echo '[{"head":{"sha":"deadbeef"}}]' ;;
    esac
    exit 0 ;;
  repos/acme/*/commits/*/check-runs)
    case "\$url" in
      repos/acme/chezz/*)
        echo '{"check_runs":[{"name":"gate"},{"name":"playwright (1/3)"},{"name":"playwright (2/3)"},{"name":"preflight"},{"name":"pages-build-deployment"}]}' ;;
      repos/acme/crt/*) echo '{"check_runs":[]}' ;;
      *) echo '{"check_runs":[]}' ;;
    esac
    exit 0 ;;
  repos/acme/*) echo '{"default_branch":"main"}'; exit 0 ;;
esac
exit 1
EOF
chmod +x "$T/gh"

run() { BPP_OWNER=acme GH_BIN="$T/gh" "$SCRIPT" "$@" 2>&1; }

# --- A/B/C: the three verdicts, read-only -----------------------------------
out="$(run realisateur chezz crt basheur)"
has "A: already-protected repo reports ok"      "$out" "ok    realisateur"
has "A: and names its existing context"         "$out" "required [markdown-cost]"
has "B: unprotected-with-checks reports UNPROT" "$out" "UNPROT chezz"
has "C: no check on its PR head reports NOCI"   "$out" "NOCI  crt"
has "C: and says why"                           "$out" "no check ran on the head"
has "C: a repo with no PR at all is also NOCI"  "$out" "NOCI  basheur"
has "C: and says that is why"                   "$out" "no pull request has ever been opened"
has "C: NOCI is pointed at the CI rollout"      "$out" "#285"

# --- E: THE REGRESSION. The 404 body must never read as a required check.
hasnt "E: 404 body is not reported as a context" "$out" "Branch not protected"
has   "E: and the summary counts them unprotected" "$out" "3 unprotected"

# --- F/G: context hygiene ---------------------------------------------------
has   "F: matrix legs are dropped"           "$out" "dropping 2 matrix leg(s)"
hasnt "F: and no matrix leg is listed"       "$out" "playwright (1/3)"
has   "F: the stable siblings survive"       "$out" "[gate,preflight]"
hasnt "G: pages-build-deployment is never required" "$out" "pages-build-deployment"

# --- H: bare invocation writes NOTHING --------------------------------------
[ ! -s "$PUTS" ] && ok "H: bare invocation wrote no protection" \
                 || bad "H: bare invocation called PUT"

run --strict realisateur >/dev/null 2>&1
rc "H: --strict exits 0 when the filtered repo is protected" 0 "$?"
run --strict chezz >/dev/null 2>&1
rc "H: --strict exits 1 when a repo is unprotected" 1 "$?"
run chezz >/dev/null 2>&1
rc "H: bare invocation exits 0 despite unprotected repos" 0 "$?"

# --- D: BLIND is never 0, and is not gated behind --strict ------------------
out="$(run gardien)"
has "D: unreadable repo reports BLIND" "$out" "BLIND gardien"
hasnt "D: and is never reported ok"    "$out" "ok    gardien"
run gardien >/dev/null 2>&1
rc "D: BLIND exits 2 without --strict" 2 "$?"
run --strict gardien >/dev/null 2>&1
rc "D: BLIND exits 2 with --strict too" 2 "$?"

# --- B/apply: --apply writes the repo's OWN contexts, and verifies by re-read
out="$(run --apply chezz)"
has "B: --apply reports the protection it wrote" "$out" "-> protected, required [gate,preflight]"
[ -s "$PUTS" ] && ok "B: --apply called PUT" || bad "B: --apply wrote nothing"
put="$(cat "$PUTS")"
has "B: PUT targets the protection endpoint" "$put" "repos/acme/chezz/branches/main/protection"
has "B: PUT requires the discovered contexts" "$put" '"gate"'
has "B: PUT sets no required reviewer"        "$put" '"required_pull_request_reviews":null'
has "B: PUT leaves admins able to unstick it" "$put" '"enforce_admins":false'
hasnt "B: PUT never requires a matrix leg"    "$put" 'playwright'

echo
summary
