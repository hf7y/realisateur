#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/self-merge-audit.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

cat > "$T/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  repo="" prev=""
  for a in "$@"; do case "$prev" in --repo) repo="$a" ;; esac; prev="$a"; done
  case "$repo" in
    acme/realisateur)
      echo '[{"number":10,"author":{"login":"bot"},"mergedBy":{"login":"bot"}},{"number":9,"author":{"login":"bot"},"mergedBy":{"login":"bot"}}]' ;;
    acme/chezz)
      echo '[{"number":3,"author":{"login":"bot"},"mergedBy":{"login":"bot"}}]' ;;
    acme/crt)
      echo '[{"number":7,"author":{"login":"alice"},"mergedBy":{"login":"bot"}}]' ;;
    acme/ecosim)
      echo '[]' ;;
    acme/basheur)
      exit 1 ;;
    *) echo '[]' ;;
  esac
  exit 0
fi

if [ "$1" = "api" ]; then
  url="$2"
  case "$url" in
    repos/acme/gardien) exit 1 ;;
    repos/acme/*/branches/main/protection)
      repo="$(printf '%s' "$url" | cut -d/ -f2-3)"
      case "$repo" in
        acme/realisateur|acme/crt|acme/ecosim|acme/basheur)
          echo '{"required_status_checks":{"contexts":["ci"]}}'; exit 0 ;;
      esac
      echo '{"message":"Branch not protected","status":"404"}'; exit 1 ;;
    repos/acme/*) echo '{"default_branch":"main"}'; exit 0 ;;
  esac
  exit 1
fi
exit 1
EOF
chmod +x "$T/gh"

run() { SMA_OWNER=acme GH_BIN="$T/gh" "$SCRIPT" "$@" 2>&1; }

section "A: protected + self-merged -> gated, never a HAZARD"
out="$(run realisateur)"
has   "A: protected self-merge reports ok"   "$out" "ok    realisateur: 2 self-merge(s), all gated by [ci]"
hasnt "A: and is never a HAZARD"             "$out" "HAZARD realisateur"

section "B: unprotected + self-merged -> HAZARD"
out="$(run chezz)"
has "B: unprotected self-merge reports HAZARD" "$out" "HAZARD chezz#3: bot merged their own PR with no required check to queue behind"
run --strict chezz >/dev/null 2>&1
rc "B: --strict exits 1 on a HAZARD" 1 "$?"

section "C: protected, but merger != author -> no self-merge at all"
out="$(run crt)"
has   "C: no-self-merge repo reports ok"   "$out" "ok    crt: no self-merge among its last"
hasnt "C: and is never gated or HAZARD"    "$out" "HAZARD crt"
hasnt "C: not counted as a gated self-merge either" "$out" "self-merge (gated) crt"

section "F: no merged PRs at all"
out="$(run ecosim)"
has "F: empty merge history reports ok" "$out" "ok    ecosim: no merged pull request"

section "D: repo itself unreadable -> BLIND"
out="$(run gardien)"
has "D: unreadable repo reports BLIND" "$out" "BLIND gardien"
run gardien >/dev/null 2>&1
rc "D: BLIND exits 6 without --strict" 6 "$?"
run --strict gardien >/dev/null 2>&1
rc "D: BLIND exits 6 with --strict too" 6 "$?"

section "E: repo readable, but gh pr list fails -> BLIND"
out="$(run basheur)"
has "E: pr-list failure reports BLIND" "$out" "BLIND basheur: could not list pull requests"
run basheur >/dev/null 2>&1
rc "E: BLIND exits 6" 6 "$?"

section "G: --verbose lists every self-merge; bare invocation does not"
out="$(run realisateur)"
hasnt "G: bare invocation does not list individual gated PRs" "$out" "self-merge (gated) realisateur#10"
out="$(run --verbose realisateur)"
has "G: --verbose lists each gated self-merge" "$out" "self-merge (gated) realisateur#10: bot merged their own PR, but [ci] was required"
has "G: --verbose lists the other one too"     "$out" "self-merge (gated) realisateur#9:"

section "H: bare invocation never gates on a HAZARD; --strict does"
run chezz >/dev/null 2>&1
rc "H: bare invocation exits 0 despite a HAZARD" 0 "$?"
run --strict realisateur >/dev/null 2>&1
rc "H: --strict exits 0 when nothing is a HAZARD" 0 "$?"

section "roster filter: an unknown repo name is a usage error, not a silent skip"
run not-a-real-repo >/dev/null 2>&1
rc "not a registered repo is a usage error (exit 2)" 2 "$?"

echo
summary
