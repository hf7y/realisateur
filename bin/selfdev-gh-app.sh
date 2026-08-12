#!/usr/bin/env bash
# selfdev-gh-app.sh -- mint a short-lived GitHub App installation token for a
# self-dev account, and prove GitHub answers to it.
#
#   selfdev-gh-app.sh --check              probe the wiring, write nothing (default)
#   selfdev-gh-app.sh --token [--repos a,b]  print an installation token to stdout
#   selfdev-gh-app.sh --identity           print the App actor -- the PUSHER, not
#                                          the author. See "AUTHOR AND PUSHER"
#                                          below: --wire no longer writes this
#                                          into git's author fields.
#   selfdev-gh-app.sh --jwt                print the App JWT only (401 debugging)
#   selfdev-gh-app.sh --adopt --account <name> --key <file.pem> --app-id <id>
#                                          install a freshly downloaded key at
#                                          mode 600, write its conf, and prove it
#   selfdev-gh-app.sh --credential <op>    git credential helper. Git appends the
#                                          operation itself: `get` mints, and
#                                          `store`/`erase` are no-ops that exit 0.
#   selfdev-gh-app.sh --wire               write git config: the credential helper
#                                          (PUSHER = the App) and the git author
#                                          (AUTHOR = this account, from `id -un`).
#                                          Never clobbers an existing identity
#                                          silently -- it preserves and reports it.
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

# GIT APPENDS AN OPERATION TO ITS CREDENTIAL HELPER, AND THIS PARSER USED TO
# DIE ON IT.
#
# `git config credential.helper "!<cmd>"` is invoked by git as
# `<cmd> <operation>`, where operation is `get`, `store` or `erase`. So the
# helper wired by `--wire` actually runs as:
#
#     selfdev-gh-app.sh --credential get
#
# `get` matched no case, fell through to `*)`, printed usage and exited 2.
# THE HELPER HAS THEREFORE NEVER FUNCTIONED, from the day it was written
# (2026-08-06) to the day this was found (2026-08-07). Every fetch and push
# through it fell back to whatever else git could find.
#
# bin/tests/selfdev-gh-app.test.sh exercised `--credential` -- but never with
# the argument git actually appends, so it passed by testing a shape
# production never runs. That is the same bug class as the `$HOME`-fixture
# guards in MEMORY.md and as the `--build-id -` outage in this same PR: a test
# green against a paraphrase of the real invocation.
MODE="--check"; REPOS=""; ADOPT_ACCOUNT=""; ADOPT_KEY=""; ADOPT_ID=""; GIT_OP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check|--token|--identity|--credential|--wire|--jwt|--adopt) MODE="$1" ;;
    get|store|erase)
      # Accepted ONLY after --credential. A bare `get` with no mode is not a
      # git invocation at all, and treating it as one would make a typo mint a
      # token. The refusal below still catches it.
      [ "$MODE" = "--credential" ] || { echo "$0: '$1' is a git credential operation and is only accepted after --credential" >&2; exit 2; }
      GIT_OP="$1" ;;
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

# WHERE THE CREDENTIAL LIVES is answered in ONE place for every reader --
# bin/lib/selfdev-app-key.sh -- and not re-spelled here. Until 2026-08-12 this
# line said `$HOME/.config/selfdev/gh-app.conf`, i.e. one copy of one key per
# account (thirteen on monkey), and three other scripts spelled the same fact
# three other ways; converging an account failed because the writer and the
# reader disagreed (realisateur#209). Now: $SELFDEV_APP_CONF, else
# /etc/selfdev/gh-app.conf, host-wide.
#
# Sourced by PATH when this file is installed as a lone copy under
# ~/.local/libexec/selfdev/ (the release bootstrap copies both), and by
# directory otherwise -- a bootstrap that only works from a full checkout is
# not a bootstrap.
_sd_lib="$(dirname "${BASH_SOURCE[0]}")/lib/selfdev-app-key.sh"
[ -r "$_sd_lib" ] || _sd_lib="$(dirname "${BASH_SOURCE[0]}")/selfdev-app-key.sh"
if [ -r "$_sd_lib" ]; then
  # shellcheck source=lib/selfdev-app-key.sh
  . "$_sd_lib"
  CONF="$(selfdev_app_conf)"
else
  # No lib beside us: fall back to the same host-wide default it declares,
  # rather than to a per-account path that no longer exists. Stated, not silent.
  CONF="${SELFDEV_APP_CONF:-/etc/selfdev/gh-app.conf}"
  SELFDEV_APP_PEM_DEFAULT=/etc/selfdev/app.pem
fi
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
APP_KEY="${_env_app_key:-${SELFDEV_APP_KEY:-${SELFDEV_APP_PEM_DEFAULT:-/etc/selfdev/app.pem}}}"
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

# ============================================================================
# AUTHOR AND PUSHER ARE TWO LAYERS, AND --wire USED TO CONFLATE THEM
# ============================================================================
#
# Found live 2026-08-07: `--wire` had set ecosim@monkey's GLOBAL git identity
# to `unattended-monkey[bot] <314444911+unattended-monkey[bot]@users.noreply.
# github.com>`. Under the ORIGINAL design -- one App per account -- that was
# correct, because the bot WAS the account. Under the fleet model chosen the
# same day -- ONE App across all ten accounts -- it makes every account author
# identically, and `git log` can no longer answer which agent did anything.
#
# That is not cosmetic. The argument for one App over ten was: a per-App
# identity buys CRYPTOGRAPHIC attribution, we only need BOOKKEEPING
# attribution, and a per-agent commit author gives that for free. Setting the
# author to the bot deletes the free half and leaves the fleet with neither.
#
# THE MODEL, stated once so neither layer gets rebuilt out of the other:
#
#   AUTHOR   who wrote the commit. PURELY LOCAL GIT CONFIG. GitHub has no say
#            in it and only displays it. Must be the ACCOUNT -- ecosim, chezz,
#            crt -- because that is the fact nothing else records.
#   PUSHER   what credential delivered it. The App installation token. GitHub
#            attributes the push event to `<app-slug>[bot]` REGARDLESS OF
#            AUTHOR, automatically, with no configuration at all.
#
# Both are available at once, and that is the whole point: `git log` answers
# "which agent did this", GitHub's push event answers "did this come from the
# fleet". Setting the author to the bot threw away the first in order to
# duplicate the second.
#
# --- the ACCOUNT identity: the AUTHOR half ----------------------------------
#
# NAME: `id -un`, deliberately, and NOT `$USER`. $USER is an ordinary
# environment variable inherited across `sudo -u` and `su` without `-`, which
# is exactly how these uid-3000 accounts are stood up -- so it can name the
# provisioning operator while running as the account, and the failure is
# silent and permanent (it lands in every commit). `id -un` asks the kernel
# about the effective uid and cannot be inherited from anywhere.
#
# EMAIL: `<account>@selfdev.invalid`. `.invalid` is reserved by RFC 2606
# precisely so it can never resolve, which makes the address HONEST -- it does
# not pretend to be a mailbox, and nothing will ever try to deliver to it. It
# is greppable, it sorts, and it says what the identity is.
#
# THE TRADEOFF, stated rather than buried: this address does NOT link to a
# GitHub profile. A `<id>+<name>@users.noreply.github.com` address would, and
# is the reason bot_identity() below uses one. But the only such address
# available here is the BOT's, and using it would make every commit claim to
# be authored by an identity that did not act -- buying a clickable avatar at
# the cost of a true record. These are machine identities; the record is worth
# more than the avatar. Overridable for anyone who weighs it the other way.
SELFDEV_EMAIL_DOMAIN="${SELFDEV_EMAIL_DOMAIN:-selfdev.invalid}"

account_identity() {
  local acct; acct="$(id -un)" || return 1
  [ -n "$acct" ] || return 1
  printf '%s\n%s@%s\n' "$acct" "$acct" "$SELFDEV_EMAIL_DOMAIN"
}

# --- the BOT identity: the PUSHER half, printed by --identity ----------------
# Still resolved and still correct for what it IS -- the actor GitHub will
# attribute the PUSH to. It is no longer written into git's author fields.
# The email here is the only address GitHub links back to the bot actor, which
# is why it has that shape and why it is not the shape used above.
bot_identity() {
  local jwt slug uid
  jwt="$(app_jwt)" || return 1
  slug="$(api GET /app "$jwt" | jq -r '.slug // empty')" || return 1
  [ -n "$slug" ] || return 1
  uid="$(curl -sS -H "Accept: application/vnd.github+json" "$API/users/$slug%5Bbot%5D" | jq -r '.id // empty')"
  [ -n "$uid" ] || { echo "could not resolve the bot user id for ${slug}[bot]" >&2; return 1; }
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

    # ADOPT NO LONGER INVENTS A PATH. It used to write
    # ~/.config/selfdev/<account>/<account>.pem plus a conf naming it -- which
    # is how one App key came to sit on disk under four different names, and
    # why `selfdev-credentials.sh --apply` could not find it (realisateur#209).
    # The host-wide placement, the group, and the per-account read witness are
    # bin/selfdev-app-key.sh's job; this hands the key to it rather than
    # keeping a second placement implementation alive.
    if [ "$(id -u)" -eq 0 ] && [ -x "$(dirname "${BASH_SOURCE[0]}")/selfdev-app-key.sh" ]; then
      "$(dirname "${BASH_SOURCE[0]}")/selfdev-app-key.sh" --apply --from "$ADOPT_KEY" --app-id "$ADOPT_ID" --owner "$OWNER" \
        || die "selfdev-app-key.sh --apply refused; the key was NOT installed"
      dir="$SELFDEV_APP_DIR"
    else
      die "adopting a key places it host-wide in ${SELFDEV_APP_DIR:-/etc/selfdev} and needs root:
    sudo bin/selfdev-app-key.sh --apply --from $ADOPT_KEY --app-id $ADOPT_ID"
    fi
    echo
    # Re-exec rather than duplicate the witness. A second copy of this logic
    # is a second thing to keep true.
    exec env SELFDEV_APP_CONF="${SELFDEV_APP_CONF_DEFAULT:-/etc/selfdev/gh-app.conf}" \
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
    # Git's request is drained and ignored on purpose: the helper is configured
    # per-host in --wire, so there is nothing left to decide from the input, and
    # a helper that does not read its stdin leaves git writing into a closed pipe.
    while IFS= read -r line; do [ -z "$line" ] && break; done
    case "$GIT_OP" in
      store|erase)
        # NO-OPS BY DESIGN, and they must exit 0. There is nothing to store --
        # that is the point of a one-hour token minted on demand -- and
        # nothing to erase. Git ignores a helper's output for these two
        # operations but DOES notice a non-zero exit, so answering them
        # loudly would put a spurious failure in front of every push.
        exit 0 ;;
      get|'')
        # `''` is the hand-run form (`selfdev-gh-app.sh --credential`), kept
        # so an operator can still exercise the helper from a terminal exactly
        # as it was documented before git's operation argument was honoured.
        # `exit 5`, matching --token and --identity two branches down.
        # mint_token flattens die()'s 5 to `return 1` internally, so every
        # caller restates the FATAL code; this one said 1 and was the only
        # caller in the file that did. Git treats any non-zero as "no
        # credential" so nothing downstream cares -- but the operator
        # hand-running the helper does, and one script with two answers for
        # its own FATAL code is how a missing key gets debugged as a revoked
        # one.
        tok="$(mint_token)" || exit 5
        printf 'username=x-access-token\npassword=%s\n' "$tok"
        ;;
      *)
        # Unreachable through the parser above, and left loud anyway: a future
        # git operation this helper does not understand must not be answered
        # with a token.
        echo "$0: unknown git credential operation: $GIT_OP" >&2; exit 2 ;;
    esac
    ;;

  --wire)
    self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    git config --global credential."https://github.com".helper "!'$self' --credential"
    git config --global credential."https://github.com".useHttpPath false
    ok "git credential helper -> $self --credential"

    # THE AUTHOR HALF. The account, not the bot -- see the model above.
    if ident="$(account_identity)"; then
      want_name="$(printf '%s' "$ident" | sed -n 1p)"
      want_mail="$(printf '%s' "$ident" | sed -n 2p)"
      have_name="$(git config --global --get user.name  || true)"
      have_mail="$(git config --global --get user.email || true)"

      # DO NOT CLOBBER SILENTLY. This already cost real information: the
      # value --wire overwrote on ecosim@monkey was never captured and cannot
      # be restored, because the previous version read nothing before writing.
      # So the old value is READ, REPORTED, and PRESERVED in git's own config
      # under a selfdev.* key before anything is written -- and the backup is
      # written only ONCE, so re-running --wire can never overwrite the
      # original with a value --wire itself set.
      if [ -n "$have_name$have_mail" ] && \
         { [ "$have_name" != "$want_name" ] || [ "$have_mail" != "$want_mail" ]; }; then
        if [ -z "$(git config --global --get selfdev.previousUserName || true)" ] && \
           [ -z "$(git config --global --get selfdev.previousUserEmail || true)" ]; then
          git config --global selfdev.previousUserName  "$have_name"
          git config --global selfdev.previousUserEmail "$have_mail"
          git config --global selfdev.previousUserSavedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          ok "preserved the previous identity: git config --global selfdev.previousUserName/Email"
        else
          ok "a previous identity was already preserved; not overwriting the backup"
        fi
        # Loud, and it names both values. A replacement an operator cannot see
        # in the output is a replacement they will find out about from a
        # `git log` six weeks later.
        gap "REPLACING the global git identity on $(id -un)@$(hostname -s 2>/dev/null || echo '?'):"
        gap "  was:  ${have_name:-<unset>} <${have_mail:-<unset>}>"
        gap "  now:  $want_name <$want_mail>"
        case "$have_name" in
          *'[bot]') gap "  the previous value was an App bot slug -- this is the fleet-identity"
                    gap "  bug being corrected: one App across ten accounts made every account"
                    gap "  author identically, so 'which agent did this' had no answer." ;;
        esac
        gap "  restore with: git config --global user.name \"\$(git config --global selfdev.previousUserName)\""
      fi

      git config --global user.name  "$want_name"
      git config --global user.email "$want_mail"
      # WITNESS: read it back out of git, not out of the variable just written.
      got_name="$(git config --global --get user.name  || true)"
      got_mail="$(git config --global --get user.email || true)"
      if [ "$got_name" = "$want_name" ] && [ "$got_mail" = "$want_mail" ]; then
        ok "git AUTHOR -> $got_name <$got_mail>   (the account: git log answers 'which agent')"
      else
        bad "git config accepted the write but re-reading gives '$got_name <$got_mail>'"
      fi
    else
      bad "could not resolve the account identity from \`id -un\` -- credential helper is wired, git author is NOT"
    fi

    # THE PUSHER HALF. Nothing to configure: GitHub attributes the push to the
    # App actor because of the CREDENTIAL, not because of any git setting.
    # Resolved here only so the operator can see both layers in one output and
    # confirm they are different on purpose.
    if bident="$(bot_identity 2>/dev/null)"; then
      ok "git PUSHER -> $(printf '%s' "$bident" | sed -n 1p)   (the App: GitHub attributes the push, no config needed)"
    else
      gap "git PUSHER -> could not resolve the App actor for display. This does NOT affect pushes: GitHub attributes them from the CREDENTIAL, not from any git setting, so the pusher layer is wired whether or not this line can name it."
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
