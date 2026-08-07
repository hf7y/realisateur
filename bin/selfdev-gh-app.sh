#!/usr/bin/env bash
# selfdev-gh-app.sh -- mint a short-lived GitHub App installation token for a
# self-dev account, and prove GitHub answers to it.
#
#   selfdev-gh-app.sh --check              probe the wiring, write nothing (default)
#   selfdev-gh-app.sh --token [--repos a,b]  print an installation token to stdout
#   selfdev-gh-app.sh --identity           print the bot's git user.name / user.email
#   selfdev-gh-app.sh --jwt                print the App JWT only (401 debugging)
#   selfdev-gh-app.sh --adopt --account <name> --key <file.pem> --app-id <id>
#                                          install a freshly downloaded key at
#                                          mode 600, write its conf, and prove it
#   selfdev-gh-app.sh --credential         git credential helper (reads git's stdin)
#   selfdev-gh-app.sh --wire               write git config so push/gh use the App
#
# WHY THIS EXISTS. bin/wire-selfdev-git.sh gives a self-dev account per-repo
# deploy keys. Those grant ACCESS and confer no IDENTITY: a deploy-key push is
# attributed to whatever author string the commit carries, so agent work and
# human work are indistinguishable in `git log` and in the GitHub UI. Every
# rule in CLAUDE.md about a dirty tree, an unattributable push, or an
# autocommit adopting an agent's edit "under a human's name" is downstream of
# that one missing distinction. A GitHub App installation has its own actor --
# `<app-slug>[bot]` -- so the attribution is made by GitHub, not asserted by
# the committer, and cannot be spoofed by setting user.email.
#
# WHY A TOKEN AND NOT A PAT. An installation token expires in ONE HOUR and is
# minted from a private key on demand. There is no long-lived secret to leak
# into a tracked file, a crontab line, or a log -- the thing at rest is a key
# that is useless without the App's installation, and the thing in flight is
# dead by the next scheduler tick. A PAT is the opposite on both counts.
#
# WHAT THIS DOES NOT SOLVE. App permissions are per-APP, not per-repo: one App
# cannot be read-write on a project's own repo and read-only on realisateur.
# Deploy keys can express that and this cannot, which is why this is an
# ADDITION to wire-selfdev-git.sh and not a replacement for it. The intended
# shape is TWO Apps -- a writer installed on the account's own repos, and a
# reader/filer installed on the shared ones -- selected by $SELFDEV_APP_ID.
# `--repos` narrows a single mint below the installation's own repo list, which
# is the only least-privilege lever available inside one App.
#
# CONFIG. Read from ONE place, per BUILD-DISCIPLINE: ~/.config/selfdev/gh-app.conf
# (overridable with $SELFDEV_APP_CONF), a plain shell fragment:
#     SELFDEV_APP_ID=4520255
#     SELFDEV_APP_KEY=$HOME/.config/selfdev/monkey-self-dev.pem
#     SELFDEV_GH_OWNER=hf7y
# Environment variables of the same names win over the file, so a scheduler job
# can carry a different App without editing anything.
set -uo pipefail

MODE="--check"; REPOS=""; ADOPT_ACCOUNT=""; ADOPT_KEY=""; ADOPT_ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check|--token|--identity|--credential|--wire|--jwt|--adopt) MODE="$1" ;;
    --repos) REPOS="${2:-}"; shift ;;
    --repos=*) REPOS="${1#--repos=}" ;;
    --account) ADOPT_ACCOUNT="${2:-}"; shift ;;
    --key)     ADOPT_KEY="${2:-}"; shift ;;
    --app-id)  ADOPT_ID="${2:-}"; shift ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    *) echo "usage: $0 [--check|--token|--identity|--credential|--wire|--jwt] [--repos a,b]" >&2
       echo "       $0 --adopt --account <name> --key <file.pem> --app-id <id>" >&2; exit 2 ;;
  esac
  shift
done

CONF="${SELFDEV_APP_CONF:-$HOME/.config/selfdev/gh-app.conf}"
# The environment is captured BEFORE the config file is sourced, because
# sourcing it would otherwise clobber the very variables it is supposed to
# default. Sourced-file-wins is the opposite of the documented contract and is
# invisible until a scheduler job carrying a different App silently runs as the
# one in the file -- with the right permissions on the wrong repos.
_env_app_id="${SELFDEV_APP_ID:-}"
_env_app_key="${SELFDEV_APP_KEY:-}"
_env_owner="${SELFDEV_GH_OWNER:-}"
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"
APP_ID="${_env_app_id:-${SELFDEV_APP_ID:-}}"
APP_KEY="${_env_app_key:-${SELFDEV_APP_KEY:-$HOME/.config/selfdev/selfdev-app.pem}}"
OWNER="${_env_owner:-${SELFDEV_GH_OWNER:-hf7y}}"
API="${SELFDEV_GH_API:-https://api.github.com}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/selfdev-gh-app"

PASS=0; GAPS=0; BAD=0
ok()  { printf '  OK      %s\n' "$*"; PASS=$((PASS+1)); }
gap() { printf '  MISSING %s\n' "$*"; GAPS=$((GAPS+1)); }
bad() { printf '  BAD     %s\n' "$*"; BAD=$((BAD+1)); }
die() { printf '%s: FATAL: %s\n' "${0##*/}" "$*" >&2; exit 5; }

# --- the JWT -----------------------------------------------------------------
# RS256 by hand rather than a library, because the whole point of this script is
# that a self-dev account can mint its own credential with nothing but openssl,
# curl and jq -- all three of which every host in this ecosystem already has,
# and none of which needs a package install on a fresh uid-3000 account.
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

app_jwt() {
  [ -n "$APP_ID" ] || die "SELFDEV_APP_ID is unset (looked in \$SELFDEV_APP_ID and $CONF)"
  [ -r "$APP_KEY" ] || die "private key not readable at $APP_KEY -- generate one on the App's settings page and save it there, chmod 600"
  local now hdr pay signing sig
  now="$(date +%s)"
  # iat backdated 60s: GitHub rejects a JWT whose iat is in ITS future, and
  # host clocks in this estate have drifted before.
  hdr='{"alg":"RS256","typ":"JWT"}'
  pay="{\"iat\":$((now - 60)),\"exp\":$((now + 540)),\"iss\":\"$APP_ID\"}"
  signing="$(printf '%s' "$hdr" | b64url).$(printf '%s' "$pay" | b64url)"
  sig="$(printf '%s' "$signing" | openssl dgst -sha256 -sign "$APP_KEY" -binary | b64url)" \
    || die "openssl could not sign with $APP_KEY -- is it the App's PKCS#1 .pem?"
  [ -n "$sig" ] || die "empty signature from openssl -- $APP_KEY is not a usable private key"
  printf '%s.%s' "$signing" "$sig"
}

# api <method> <path> <bearer> [body]  -- prints the response body, exits
# non-zero on HTTP >= 400 and says WHICH call failed with WHAT GitHub said. A
# silent 401 here is the defect this ecosystem keeps rediscovering:
# configuration is not capability.
api() {
  local method="$1" path="$2" auth="$3" body="${4:-}" out code
  out="$(curl -sS -w '\n%{http_code}' -X "$method" \
      -H "Authorization: Bearer $auth" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      ${body:+-d "$body"} \
      "$API$path")" || { echo "curl failed: $method $path" >&2; return 1; }
  code="${out##*$'\n'}"; out="${out%$'\n'*}"
  if [ "$code" -ge 400 ]; then
    printf 'github %s %s -> HTTP %s: %s\n' "$method" "$path" "$code" \
      "$(printf '%s' "$out" | jq -r '.message // .' 2>/dev/null || printf '%s' "$out")" >&2
    return 1
  fi
  printf '%s' "$out"
}

installation_id() {
  local jwt="$1" json
  json="$(api GET /app/installations "$jwt")" || return 1
  printf '%s' "$json" | jq -r --arg o "$OWNER" \
    '[.[] | select(.account.login | ascii_downcase == ($o | ascii_downcase))] | .[0].id // empty'
}

# --- the token, with a cache -------------------------------------------------
# Cached because git invokes a credential helper on EVERY remote operation, and
# minting per operation would turn one push into three round trips and three
# audit-log entries. Keyed by App and repo scope so a narrowed mint never gets
# served a broader cached token. Expiry is treated as 5 minutes early: a token
# that dies mid-push fails in the least legible way GitHub offers.
mint_token() {
  local jwt inst body cache now exp
  cache="$CACHE_DIR/$(printf '%s|%s|%s' "$APP_ID" "$OWNER" "$REPOS" | openssl dgst -sha256 -hex | awk '{print $NF}').tok"
  if [ -r "$cache" ]; then
    now="$(date +%s)"; exp="$(head -1 "$cache")"
    case "$exp" in
      ''|*[!0-9]*) : ;;
      *) [ "$now" -lt $((exp - 300)) ] && { tail -n +2 "$cache"; return 0; } ;;
    esac
  fi
  jwt="$(app_jwt)" || return 1
  inst="$(installation_id "$jwt")" || return 1
  [ -n "$inst" ] || die "the App is not installed on '$OWNER' -- open the App's Install App tab and install it, then re-run --check"
  if [ -n "$REPOS" ]; then
    body="$(printf '%s' "$REPOS" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";"")) | {repositories: .}')"
  else
    body=""
  fi
  local json tok
  json="$(api POST "/app/installations/$inst/access_tokens" "$jwt" "$body")" || return 1
  tok="$(printf '%s' "$json" | jq -r '.token // empty')"
  [ -n "$tok" ] || die "GitHub returned no token for installation $inst"
  exp="$(printf '%s' "$json" | jq -r '.expires_at // empty')"
  mkdir -p "$CACHE_DIR" && chmod 700 "$CACHE_DIR"
  # Written 600 BEFORE the secret goes in, not after: a world-readable instant
  # is still a leak, and this file is a bearer credential.
  ( umask 077; printf '%s\n%s' "$(date -d "$exp" +%s 2>/dev/null || echo 0)" "$tok" > "$cache" )
  printf '%s' "$tok"
}

# --- the bot identity --------------------------------------------------------
# The email is not a convention this script invents -- it is the only address
# GitHub links back to the bot actor, so a commit made with anything else shows
# as an unlinked author even though the PUSH was the App's.
bot_identity() {
  local jwt slug uid
  jwt="$(app_jwt)" || return 1
  slug="$(api GET /app "$jwt" | jq -r '.slug // empty')" || return 1
  [ -n "$slug" ] || return 1
  uid="$(curl -sS -H "Accept: application/vnd.github+json" "$API/users/$slug%5Bbot%5D" | jq -r '.id // empty')"
  [ -n "$uid" ] || { echo "could not resolve the bot user id for $slug[bot]" >&2; return 1; }
  printf '%s[bot]\n%s+%s[bot]@users.noreply.github.com\n' "$slug" "$uid" "$slug"
}

case "$MODE" in
  --adopt)
    # Take a freshly downloaded .pem plus an App ID and produce a wired,
    # PROVEN account config. Exists because this runs once per self-dev
    # account and the hand version is four commands with two chances to leave
    # a bearer credential world-readable -- which the very first real key
    # already did (mode 664 out of the browser, 2026-08-07).
    [ -n "$ADOPT_ACCOUNT" ] || die "--adopt needs --account <name>"
    [ -n "$ADOPT_KEY" ]     || die "--adopt needs --key <file.pem>"
    [ -r "$ADOPT_KEY" ]     || die "cannot read key file: $ADOPT_KEY"
    [ -n "$ADOPT_ID" ]      || die "--adopt needs --app-id <id> (App ID or Client ID; both work as the JWT issuer)"

    # Prove it is a private key BEFORE moving it anywhere. A truncated or
    # HTML-error download is still a file, and every later failure would
    # present as a GitHub 401.
    openssl rsa -in "$ADOPT_KEY" -noout -check >/dev/null 2>&1 \
      || die "$ADOPT_KEY is not a valid RSA private key -- re-download it"
    fp="$(openssl rsa -in "$ADOPT_KEY" -pubout -outform DER 2>/dev/null | openssl sha256 -binary | openssl base64)"
    ok "key is a valid RSA private key"
    ok "fingerprint: $fp"
    echo "          ^ must equal the SHA256: shown on the App's settings page"

    dir="$HOME/.config/selfdev/$ADOPT_ACCOUNT"
    mkdir -p "$dir" && chmod 700 "$HOME/.config/selfdev" "$dir"
    install -m 600 "$ADOPT_KEY" "$dir/$ADOPT_ACCOUNT.pem" \
      || die "could not install the key into $dir"
    ok "key installed at $dir/$ADOPT_ACCOUNT.pem (mode 600)"
    ( umask 077; { printf '# written by selfdev-gh-app.sh --adopt for %s\n' "$ADOPT_ACCOUNT"
      printf 'SELFDEV_APP_ID=%s\n' "$ADOPT_ID"
      printf 'SELFDEV_APP_KEY=%s/%s.pem\n' "$dir" "$ADOPT_ACCOUNT"
      printf 'SELFDEV_GH_OWNER=%s\n' "$OWNER"; } > "$dir/gh-app.conf" )
    ok "config written at $dir/gh-app.conf (mode 600)"
    echo
    # Re-exec rather than duplicate the witness. A second copy of this logic
    # is a second thing to keep true.
    exec env SELFDEV_APP_CONF="$dir/gh-app.conf" \
         SELFDEV_APP_ID= SELFDEV_APP_KEY= SELFDEV_GH_OWNER= "$0" --check
    ;;

  --jwt)
    # The App JWT, unexchanged. Exists because GitHub answers a malformed one
    # with a bare 401 that is indistinguishable from a revoked key -- with this
    # you can decode the payload and see which it is. Lives ~9 minutes and
    # grants nothing but the App-level endpoints; the test suite verifies its
    # signature against a throwaway public key through this mode.
    app_jwt || exit 5
    echo
    ;;

  --token)
    mint_token || exit 5
    echo
    ;;

  --identity)
    bot_identity || exit 5
    ;;

  --credential)
    # git credential protocol: read key=value lines on stdin, answer in kind.
    # Only `get` is answered; `store`/`erase` are no-ops BY DESIGN -- there is
    # nothing to store, which is the point of a one-hour token.
    # Git's request is drained and ignored on purpose: the helper is configured
    # per-host in --wire, so there is nothing left to decide from the input, and
    # a helper that does not read its stdin leaves git writing into a closed pipe.
    while IFS= read -r line; do [ -z "$line" ] && break; done
    tok="$(mint_token)" || exit 1
    printf 'username=x-access-token\npassword=%s\n' "$tok"
    ;;

  --wire)
    self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    git config --global credential."https://github.com".helper "!'$self' --credential"
    git config --global credential."https://github.com".useHttpPath false
    ok "git credential helper -> $self --credential"
    if ident="$(bot_identity)"; then
      git config --global user.name  "$(printf '%s' "$ident" | sed -n 1p)"
      git config --global user.email "$(printf '%s' "$ident" | sed -n 2p)"
      ok "git identity -> $(printf '%s' "$ident" | sed -n 1p) <$(printf '%s' "$ident" | sed -n 2p)>"
    else
      bad "could not resolve the bot identity -- credential helper is wired, git author is NOT"
    fi
    # url.insteadOf from wire-selfdev-git.sh rewrites github.com onto per-repo
    # ssh aliases. Where both are wired, ssh WINS and this helper is never
    # consulted -- silently. Say so rather than let it look wired.
    if git config --global --get-regexp '^url\..*github-.*\.insteadof$' >/dev/null; then
      gap "deploy-key url.insteadOf rewrites are also configured -- those repos will keep using ssh and the App identity, remove them per repo to switch"
    fi
    printf '\nwired: %d ok, %d missing, %d bad\n' "$PASS" "$GAPS" "$BAD"
    [ "$BAD" -eq 0 ] || exit 5
    ;;

  --check)
    echo "== selfdev-gh-app --check -- $(id -un)@$(hostname -s 2>/dev/null || echo unknown) =="
    [ -r "$CONF" ] && ok "config $CONF" || gap "no config at $CONF (env vars may still supply it)"
    [ -n "$APP_ID" ] && ok "app id $APP_ID" || gap "SELFDEV_APP_ID unset -- the App ID is on the App's settings page"
    if [ -r "$APP_KEY" ]; then
      perm="$(stat -c %a "$APP_KEY" 2>/dev/null || echo '?')"
      case "$perm" in
        600|400) ok "private key $APP_KEY (mode $perm)" ;;
        *)       bad "private key $APP_KEY is mode $perm -- a bearer key must be 600" ;;
      esac
    else
      gap "no private key at $APP_KEY -- generate one on the App's settings page (Private keys -> Generate a private key) and save it there"
    fi
    for c in openssl curl jq; do
      command -v "$c" >/dev/null && ok "$c present" || bad "$c missing -- this script cannot mint without it"
    done

    # The witness. Everything above is a file on disk; this is GitHub answering.
    if [ -n "$APP_ID" ] && [ -r "$APP_KEY" ]; then
      if jwt="$(app_jwt 2>/dev/null)" && slug="$(api GET /app "$jwt" 2>/dev/null | jq -r '.slug // empty')" && [ -n "$slug" ]; then
        ok "WITNESS: GitHub authenticated the App as '$slug'"
        inst="$(installation_id "$jwt" 2>/dev/null)"
        if [ -n "$inst" ]; then
          ok "installed on $OWNER (installation $inst)"
          if tok="$(mint_token 2>/dev/null)" && [ -n "$tok" ]; then
            n="$(curl -sS -H "Authorization: Bearer $tok" -H "Accept: application/vnd.github+json" \
                 "$API/installation/repositories?per_page=100" | jq -r '.total_count // 0')"
            ok "WITNESS: installation token minted, $n repo(s) in scope"
            if ident="$(bot_identity 2>/dev/null)"; then
              ok "bot identity: $(printf '%s' "$ident" | sed -n 1p) <$(printf '%s' "$ident" | sed -n 2p)>"
            else
              gap "bot user not resolvable yet -- normal until the App has been installed for a moment"
            fi
          else
            bad "WITNESS FAILED: App authenticates but no installation token could be minted"
          fi
        else
          gap "the App is not installed on '$OWNER' -- Install App tab, pick the repos, then re-run"
        fi
      else
        bad "WITNESS FAILED: GitHub did not accept the App JWT -- wrong App ID, wrong key, or a revoked key"
      fi
    fi

    printf '\ncheck only, nothing changed: %d ok, %d missing, %d bad\n' "$PASS" "$GAPS" "$BAD"
    [ "$GAPS" -eq 0 ] && [ "$BAD" -eq 0 ] && echo "wired. Next: $0 --wire (on the self-dev account)" \
      || echo "not wired yet -- clear the MISSING/BAD lines above."
    [ "$BAD" -eq 0 ] || exit 5
    ;;
esac
exit 0
