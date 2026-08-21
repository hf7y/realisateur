#!/usr/bin/env bash
# org-migration-audit.sh -- what would moving a repo from a personal account
# to a GitHub organization actually cost, in credentials and manual tedium?
#
# RUNNER: operator -- decision support, not migration; run before deciding
# GUARD-TEST: bin/tests/org-migration-audit.test.sh
# GATE: none -- every path calls `gh` against a live repo
#
# TRAPS (the rest of this header is in the vault):
# so painful. make an issue so a self-dev gives me a script that walks me
# through exactly the credentials I'll need to provision and other manual
# tedium ... so I can decide if it's worth it." The deliverable is the
# walkthrough, so the cost is knowable before committing -- not a transfer
# tool. There is no --apply: nothing here writes to GitHub or to disk.
#
# WHAT IS ASSERTED VS WHAT IS A QUESTION. GitHub's own docs say issues, PRs,
# commits, releases, wikis, webhooks, deploy keys, branch protection and
# rulesets all move with a transferred repo. This script does not re-assert
# that as fact for items it has not itself watched survive a real transfer --
# a repo has never actually been transferred by anyone in this estate. So
# probed state is reported as CURRENT STATE (what exists today, to be
# recreated if it does not survive) rather than as a verified transfer
# outcome, and the one item with a live, checked discrepancy (chezz's Pages
# domain: `pages.cname` is null even though it serves from hf7y.com) is
# flagged rather than assumed either way.
#
# usage: `--help`, from CLI_USAGE below. One source.
# exit codes: `--help`, from CLI_EXITS below. One source.

set -uo pipefail

CLI_NAME='org-migration-audit.sh'
CLI_SUMMARY='enumerate the credentials and manual steps an org migration would cost, per repo'
CLI_USAGE='  org-migration-audit.sh <owner/repo>...   audit the named repo(s)
  org-migration-audit.sh                   audit every scheduler-registered
                                            repo with a public GitHub REPO_URL'
CLI_FLAGS='none'
CLI_EXITS='  0  audited at least one repo (findings are the point, not a failure)
  2  BLIND -- a named repo could not be read, or no repo was named and the
     scheduler registry named none either. NEVER 0: could-not-look is not an
     audit.'
CLI_POSITIONAL=any
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"

GH_BIN="${GH_BIN:-gh}"
SCHED_ROOT="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"
PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/Documents/Projects}"

command -v "$GH_BIN" >/dev/null 2>&1 || { echo "$CLI_NAME: $GH_BIN not on PATH" >&2; exit 2; }

# api <path> -- prints the body ONLY on success, empty otherwise. `gh api`
# writes an error JSON body to stdout even on a 404/403, so a plain capture
# cannot tell "empty list" from "endpoint refused" without this.
api() {
  local out
  out="$("$GH_BIN" api "$1" 2>/dev/null)" || return 0
  printf '%s' "$out"
}

slugs=("$@")

# --- default population: every scheduler-registered repo, if none named ----
if [ "${#slugs[@]}" -eq 0 ]; then
  for conf in "$SCHED_ROOT"/schedule/*.conf; do
    [ -f "$conf" ] || continue
    case "$(basename "$conf")" in _*) continue ;; esac
    url="$(sed -n 's/^REPO_URL=["'\'']\?\([^"'\'']*\)["'\'']\?[[:space:]]*$/\1/p' "$conf" | head -1)"
    [ -n "$url" ] || continue
    slug="$(printf '%s\n' "$url" \
      | sed -e 's#^git@github\.com:##' -e 's#^https://github\.com/##' -e 's#\.git$##')"
    [ -n "$slug" ] || continue
    slugs+=("$slug")
  done
fi
if [ "${#slugs[@]}" -eq 0 ]; then
  echo "$CLI_NAME: BLIND -- no repo named and $SCHED_ROOT/schedule has no REPO_URL to fall back to" >&2
  exit 6
fi

blind=0

# --- self-dev accounts wired against a given slug, from the same registry --
selfdev_accounts_for() {
  local slug="$1" conf name url csslug
  for conf in "$SCHED_ROOT"/schedule/*.conf; do
    [ -f "$conf" ] || continue
    name="$(basename "$conf" .conf)"
    case "$name" in _*) continue ;; esac
    url="$(sed -n 's/^REPO_URL=["'\'']\?\([^"'\'']*\)["'\'']\?[[:space:]]*$/\1/p' "$conf" | head -1)"
    [ -n "$url" ] || continue
    csslug="$(printf '%s\n' "$url" \
      | sed -e 's#^git@github\.com:##' -e 's#^https://github\.com/##' -e 's#\.git$##')"
    [ "$csslug" = "$slug" ] || continue
    printf '%s\n' "$name"
  done
}

for slug in "${slugs[@]}"; do
  printf '\n== org-migration-audit: %s ==\n' "$slug"

  if ! "$GH_BIN" api "repos/$slug" >/dev/null 2>&1; then
    printf '  BLIND -- could not read repos/%s (no access, or it does not exist)\n' "$slug"
    blind=1
    continue
  fi

  printf '\nPROBED LIVE\n'

  # --- Pages / custom domain -------------------------------------------------
  pages="$(api "repos/$slug/pages")"
  if [ -n "$pages" ]; then
    cname="$(printf '%s' "$pages" | grep -o '"cname":"[^"]*"\|"cname":null' | head -1 | sed 's/"cname"://')"
    html_url="$(printf '%s' "$pages" | grep -o '"html_url":"[^"]*"' | head -1 | sed 's/.*:"//;s/"$//')"
    printf '  Pages            cname=%s html_url=%s\n' "${cname:-?}" "${html_url:-?}"
    case "$cname $html_url" in
      "null "*"github.io"*) : ;;
      "null "?*)
        printf '                   NOTE: cname is null but html_url is not *.github.io -- this repo is served under an org/user-level Pages proxy, not a per-repo custom domain. Verify which mechanism is live before assuming per-repo custom-domain transfer semantics apply at all.\n' ;;
    esac
    printf '                   UNVERIFIED: whether Pages settings and any custom domain survive a real transfer has not been tested against a real transfer in this estate. HUMAN: re-check the live URL immediately after transfer.\n'
  else
    printf '  Pages            not configured (or unreadable)\n'
  fi

  # --- Actions secrets (names only, never values) -----------------------------
  secrets="$(api "repos/$slug/actions/secrets")"
  names="$(printf '%s' "$secrets" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"$//')"
  count="$(printf '%s' "$names" | grep -c . || true)"
  if [ "$count" -gt 0 ]; then
    printf '  Secrets          %s secret(s): %s\n' "$count" "$(printf '%s' "$names" | tr '\n' ' ')"
    printf '                   HUMAN: Actions secrets do not travel with a transferred repo and must be re-entered by hand in the new location.\n'
  else
    printf '  Secrets          none\n'
  fi

  # --- Deploy keys -------------------------------------------------------------
  keys="$(api "repos/$slug/keys")"
  ktitles="$(printf '%s' "$keys" | grep -o '"title":"[^"]*"' | sed 's/"title":"//;s/"$//')"
  kcount="$(printf '%s' "$ktitles" | grep -c . || true)"
  if [ "$kcount" -gt 0 ]; then
    printf '  Deploy keys      %s key(s): %s\n' "$kcount" "$(printf '%s' "$ktitles" | tr '\n' ',' | sed 's/,$//;s/,/, /g')"
    printf '                   SCRIPTABLE, once repointed: re-addable via `gh repo deploy-key add`, but only the account holding each private half can generate a fresh keypair for the new slug.\n'
  else
    printf '  Deploy keys      none\n'
  fi

  # --- Webhooks ------------------------------------------------------------
  hooks="$(api "repos/$slug/hooks")"
  hnames="$(printf '%s' "$hooks" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"$//')"
  hcount="$(printf '%s' "$hnames" | grep -c . || true)"
  printf '  Webhooks         %s hook(s)\n' "${hcount:-0}"

  # --- Rulesets --------------------------------------------------------------
  rulesets="$(api "repos/$slug/rulesets")"
  rnames="$(printf '%s' "$rulesets" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"$//')"
  rcount="$(printf '%s' "$rnames" | grep -c . || true)"
  if [ "$rcount" -gt 0 ]; then
    printf '  Rulesets         %s: %s\n' "$rcount" "$(printf '%s' "$rnames" | tr '\n' ';' | sed 's/;$//;s/;/; /g')"
  else
    printf '  Rulesets         none\n'
  fi

  # --- Branch protection ------------------------------------------------------
  prot="$(api "repos/$slug/branches/main/protection")"
  if [ -n "$prot" ]; then
    contexts="$(printf '%s' "$prot" | grep -o '"context":"[^"]*"' | sed 's/"context":"//;s/"$//' | tr '\n' ',' | sed 's/,$//;s/,/, /g')"
    printf '  Branch protection required checks: %s\n' "${contexts:-(none named)}"
  else
    printf '  Branch protection none, or main unprotected\n'
  fi

  # --- Hardcoded owner/repo strings, if a local clone exists ------------------
  local_path="$PROJECTS_ROOT/${slug#*/}"
  if [ -d "$local_path/.git" ]; then
    hits="$(cd "$local_path" && git grep -l -F "$slug" -- . 2>/dev/null | grep -v '^\.git/' || true)"
    hcount2="$(printf '%s' "$hits" | grep -c . || true)"
    if [ "$hcount2" -gt 0 ]; then
      printf '  Hardcoded refs   %s tracked file(s) name %s literally: %s\n' "$hcount2" "$slug" "$(printf '%s' "$hits" | tr '\n' ' ')"
      printf '                   SCRIPTABLE: grep+review each one; a literal owner/repo string does not update itself when the repo moves.\n'
    else
      printf '  Hardcoded refs   none found in tracked files at %s\n' "$local_path"
    fi
  else
    printf '  Hardcoded refs   BLIND -- no local clone at %s; clone it and re-run to grep source\n' "$local_path"
  fi

  # --- Self-dev accounts wired to this exact slug -----------------------------
  accounts="$(selfdev_accounts_for "$slug")"
  if [ -n "$accounts" ]; then
    printf '  Self-dev wiring  account(s): %s\n' "$(printf '%s' "$accounts" | tr '\n' ' ')"
    printf '                   HUMAN: each holds a deploy key and a git remote wired to this exact slug (bin/wire-selfdev-git.sh); re-run the wiring for the new owner after transfer.\n'
  else
    printf '  Self-dev wiring  no scheduler-registered account references this slug\n'
  fi
done

printf '\nKNOWN MANUAL TEDIUM, CARRIED FROM THE ISSUE (not re-probed here -- verify still true before relying on it)\n'
printf '  GH_DISPATCH_TOKEN (chezz)  Apps Script Script Property PAT scoped to one slug; rescoping needs the Apps Script editor plus a manual clasp/API redeploy, currently blocked by a Workspace domain restriction on the deploy step (chezz#28). HUMAN, browser-only, ~15-30 min.\n'
printf '  Copilot (chezz)            code review is unavailable on a personal-account repo; may become available under an org (chezz#30). Informational, not a blocker.\n'
printf '  GitHub App installations   every App installed against the personal account (this estate ships one for dispatch tokens) needs re-authorizing against the new org. HUMAN, browser-only, ~5 min per App.\n'

printf '\nCHECKLIST SHAPE (per repo above)\n'
printf '  AUTOMATIC     git history, issues, PRs, releases, wiki -- move with the repo, no action.\n'
printf '  SCRIPTABLE    deploy keys, rulesets, branch protection, hardcoded owner/repo strings -- a script can read the old state (above) and replay it once the new slug is known.\n'
printf '  HUMAN-ONLY    secrets, Pages custom domain re-verification, Apps Script token + redeploy, GitHub App re-auth, self-dev account rewiring -- each needs a person in a browser or at a keyboard the automation cannot reach.\n'

if [ "$blind" -eq 1 ]; then
  exit 6
fi
exit 0
