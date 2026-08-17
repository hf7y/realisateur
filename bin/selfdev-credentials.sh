#!/usr/bin/env bash
# selfdev-credentials.sh -- read every self-dev account's credentials SIDE BY
# SIDE against one declared baseline, and converge one account to it.
#
# RUNNER: no -- needs `ssh $CRED_HOST` + passwordless `sudo -n -u <account>`
#
# TRAPS (the rest of this header is in the vault):
# Measured 2026-08-11: ecosim's `gh` credential was a fine-grained PAT missing
# the Pull-requests permission -- 403 on the ENTIRE Pull-requests API, read
# and write. `gh issue list` kept working, so every automated signal an
# operator would normally trust (a green test run, a pushed branch, an
# answered issue) stayed healthy right up to the one step that mattered. It
# took two days and a human to notice, because the OTHER nine accounts were
# never compared against it -- each account's own scripts
# (provision-selfdev-user.sh, wire-selfdev-git.sh, selfdev-gh-app.sh) check
# THAT account in isolation and always have. THE ACTUAL DEFECT WAS THAT
# NOTHING COMPARED THE TEN. This is that comparison, run on a clock.
# --audit (default) is READ-ONLY throughout: it never writes to the fleet, so
# it needs no notify-senechal and is safe to run unattended on a clock. It is
# the mode that would have caught ecosim on day one.
#
# usage:
# exit (audit):  0 clean   1 drift or a per-account BLIND   3 fleet BLIND
# exit (apply):  0 converged / nothing to do   5 a step failed

set -uo pipefail

CLI_NAME='selfdev-credentials.sh'
CLI_SUMMARY='side-by-side self-dev account credential audit against one declared baseline, and single-account converge'
CLI_USAGE='  selfdev-credentials.sh            --audit (default): read all ten accounts, report side by side
  selfdev-credentials.sh --audit    same, explicit
  selfdev-credentials.sh --apply <account>   converge ONE account to the baseline'
CLI_FLAGS='--audit --apply'
CLI_POSITIONAL=any
CLI_EXITS='  audit: 0 clean   1 drift found, or an account could not be read (BLIND)   3 the whole fleet is BLIND
  apply: 0 converged, or nothing to do   5 a converge step failed   2 usage error'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

. "$(dirname "${BASH_SOURCE[0]}")/lib/selfdev-credentials-set.sh"

# --- knobs. Every one exists so bin/tests/selfdev-credentials.test.sh can run
# with no real ssh, no real gh and no live account -- same INSTALLE_*/TICK_*
# override pattern the rest of this family uses (install-verbs.sh,
# selfdev-release-tick.sh), because a suite that cannot redirect these cannot
# tell its own passing from the live estate's health.
CRED_HOST="${CRED_HOST:-monkey}"
CRED_SSH_BIN="${CRED_SSH_BIN:-ssh}"
CRED_GH_BIN="${CRED_GH_BIN:-gh}"
CRED_SSH_TIMEOUT="${CRED_SSH_TIMEOUT:-20}"
CRED_PASSWD_FILE="${CRED_PASSWD_FILE:-/etc/passwd}"       # a REMOTE path
# NO CANONICAL-SOURCE KNOBS. There used to be CRED_APP_PEM_SRC /
# CRED_APP_CONF_SRC pointing at a local copy of the App key to push out per
# account. The credential is host-wide now and bin/selfdev-app-key.sh places
# it; a second script holding its own opinion about where the key lives is
# precisely realisateur#209.

PASS=0; GAPS=0; BAD=0; BLIND_N=0
ok()    { printf '  ok    %s\n' "$*"; PASS=$((PASS+1)); }
gap()   { printf '  gap   %s\n' "$*"; GAPS=$((GAPS+1)); }
bad()   { printf '  FLAG [drift] %s\n' "$*"; BAD=$((BAD+1)); }
blind() { printf '  BLIND %s\n' "$*"; BLIND_N=$((BLIND_N+1)); }
act()   { printf '  DO    %s\n' "$*"; }

# ============================================================================
# THE REMOTE PROBE -- the ONLY place this script touches the network.
# ============================================================================
#
# Everything it reads is a FILE or a git config -- never a secret's own bytes
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
fetch_remote() { # fetch_remote [account-filter]
  # "-" IS THE NO-FILTER SENTINEL. NEVER AN EMPTY STRING.
  #
  # `ssh host "bash -s" -- "$a" "$b" ""` does NOT hand the remote process argv
  # elements the way a normal exec() would: ssh joins every argument after
  # the remote command with a single SPACE into one string and has the
  # remote's login shell re-parse THAT STRING. A zero-length argument
  # contributes zero characters to the join and simply DISAPPEARS -- word
  # splitting on the far side collapses the adjacent spaces, so every
  # argument after it silently shifts one position to the left.
  #
  # FOUND LIVE, against the real fleet, not in the hermetic suite -- whose
  # stub `ssh` received a real bash argv array and could not reproduce ssh's
  # own flattening. A plain `--audit` (filter="") measured the WHOLE FLEET
  # BLIND: FILTER arrived on the remote side holding "hf7y" (the OWNER
  # argument, shifted into the empty slot), OWNER arrived holding
  # "realisateur" (the first shared repo), and REPOS arrived one short. The
  # uid-band comparison against that garbage FILTER matched no account, the
  # remote script printed nothing, and this function reported it exactly as
  # it must report a genuinely unreachable host: BLIND. Same failure shape as
  # the $CRED_GH_OWNER closure bug two paragraphs below -- a probe silently
  # measuring less than it claims -- caught the same way: read the live
  # fleet, not just the fixture.
  local filter="${1:--}"
  "$CRED_SSH_BIN" -o BatchMode=yes -o ConnectTimeout="$CRED_SSH_TIMEOUT" "$CRED_HOST" "bash -s" \
      -- "$CRED_UID_MIN" "$CRED_UID_MAX" "$CRED_PASSWD_FILE" "$filter" "$CRED_GH_OWNER" $CRED_SHARED_REPOS \
      <<'REMOTE_PROBE'
set -uo pipefail
UMIN="$1"; UMAX="$2"; PWFILE="$3"; FILTER="$4"; shift 4
OWNER="$1"; shift
REPOS="$*"

probe_one() {
  local owner="$1"; shift
  # THE CREDENTIAL IS HOST-WIDE as of 2026-08-12: /etc/selfdev/{app.pem,gh-app.conf},
  # one file readable by group `selfdev`, not a copy per account. So what this
  # probe asks changed shape: not "does this account have its own key" but
  # "can this account READ the one key". The witness is a read, not a stat --
  # `usermod -aG` before the account's next session stats fine and reads
  # EACCES, which is the entire failure mode of a group-readable secret.
  local pem="${SELFDEV_APP_PEM:-/etc/selfdev/app.pem}"
  local conf="${SELFDEV_APP_CONF:-/etc/selfdev/gh-app.conf}"
  local hosts="$HOME/.config/gh/hosts.yml"
  local d="$HOME/.config/selfdev"
  local pem_state="missing"
  if [ -e "$pem" ]; then
    if head -c 1 -- "$pem" >/dev/null 2>&1; then pem_state="ok:600"; else pem_state="unreadable"; fi
  fi
  local conf_state="missing" keymatch="n/a" appid="-" ownerd="-"
  if [ -r "$conf" ]; then
    conf_state="ok"
    local dkey; dkey="$(sed -n "s/^SELFDEV_APP_KEY=//p" "$conf" | tail -1)"
    local a;    a="$(sed -n "s/^SELFDEV_APP_ID=//p" "$conf" | tail -1)"; [ -n "$a" ] && appid="$a"
    local o;    o="$(sed -n "s/^SELFDEV_GH_OWNER=//p" "$conf" | tail -1)"; [ -n "$o" ] && ownerd="$o"
    if [ -n "$dkey" ]; then
      [ "$dkey" = "$pem" ] && keymatch="match" || keymatch="mismatch:$dkey"
    fi
  fi
  # ANY surviving file under the retired per-account directory is drift now,
  # including app.pem and gh-app.conf themselves: the host-wide file is the
  # credential, and a private copy beside it is a second source that a rotation
  # will miss. Before 2026-08-12 those two names were the baseline here and
  # only OTHER files were flagged.
  local extra="-"
  if [ -d "$d" ]; then
    local ex; ex="$(ls -A "$d" 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
    [ -n "$ex" ] && extra="$ex"
  fi
  local token="missing"
  if [ -r "$hosts" ]; then
    local line; line="$(grep oauth_token "$hosts" 2>/dev/null | head -1)"
    case "$line" in
      *gho_*)        token="gho" ;;
      *github_pat_*) token="pat" ;;
      *)             [ -n "$line" ] && token="other" ;;
    esac
  fi
  local ownrepo; ownrepo="$(id -un)"
  local wo; wo="$(git config --global --get-all "url.git@github-$ownrepo:$owner/$ownrepo.git.insteadof" 2>/dev/null | wc -l | tr -d ' ')"
  printf '%s\t%s\t%s\t%s\t%s\t%s' "$pem_state" "$conf_state" "$keymatch" "$token" "$extra" "$wo"
  local r wr
  for r in "$@"; do
    wr="$(git config --global --get-all "url.git@github-$r:$owner/$r.git.insteadof" 2>/dev/null | wc -l | tr -d ' ')"
    printf '\t%s' "$wr"
  done
  printf '\t%s\t%s\n' "$appid" "$ownerd"
}

while IFS=: read -r acct _ uid _ _ home _; do
  [ "$uid" -ge "$UMIN" ] 2>/dev/null || continue
  [ "$uid" -le "$UMAX" ] || continue
  [ "$FILTER" = "-" ] || [ "$acct" = "$FILTER" ] || continue
  # shellcheck disable=SC2086
  out="$(sudo -n -u "$acct" bash -c "$(declare -f probe_one); probe_one \"\$@\"" _ "$OWNER" $REPOS 2>/dev/null)"
  rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
    printf '%s\tBLIND\n' "$acct"
  else
    printf '%s\t%s\n' "$acct" "$out"
  fi
done < "$PWFILE"
REMOTE_PROBE
}

# ============================================================================
# GRADING -- pure given a row; no network. This is the half
# bin/tests/selfdev-credentials.test.sh exercises directly.
# ============================================================================

# cred_grade_account <account> <tab-separated-row-or-BLIND>
# Prints the account's line(s) and returns 0 (clean), 1 (drift) or 2 (blind).
cred_grade_account() {
  local acct="$1" row="$2"
  if [ -z "$row" ] || [ "$row" = "BLIND" ]; then
    blind "$acct: could not be read at all (sudo -n failed, or it does not exist in the uid band)"
    return 2
  fi

  local pem conf keymatch token extra wire_own wire_r1 wire_r2 wire_r3 appid ownerd
  IFS=$'\t' read -r pem conf keymatch token extra wire_own wire_r1 wire_r2 wire_r3 appid ownerd <<<"$row"

  printf '  %-16s pem=%-8s conf=%-4s token=%-4s extra=%-16s wire own=%s/3 shared=%s,%s,%s\n' \
    "$acct" "$pem" "$conf" "$token" "$extra" "$wire_own" "$wire_r1" "$wire_r2" "$wire_r3"

  local drift=0

  case "$pem" in
    ok:600) : ;;
    unreadable) bad "$acct: the host-wide App key exists but this account CANNOT READ IT -- check group '${CRED_APP_GROUP:-selfdev}' membership has taken effect (sudo bin/selfdev-app-key.sh --check)"; drift=1 ;;
    missing|*) bad "$acct: no host-wide App key at /etc/selfdev/app.pem -- no account on this host can mint an App token (sudo bin/selfdev-app-key.sh --apply)"; drift=1 ;;
  esac

  case "$conf" in
    ok) : ;;
    *) bad "$acct: no host-wide /etc/selfdev/gh-app.conf -- selfdev-gh-app.sh has nothing to read (sudo bin/selfdev-app-key.sh --apply)"; drift=1 ;;
  esac

  case "$keymatch" in
    match|n/a) : ;;
    mismatch:*) bad "$acct: gh-app.conf's SELFDEV_APP_KEY points at ${keymatch#mismatch:}, not the app.pem actually present"; drift=1 ;;
  esac

  if [ "$conf" = ok ]; then
    [ "$appid" = "$CRED_APP_ID" ]  || { bad "$acct: gh-app.conf declares App id '$appid', fleet baseline is $CRED_APP_ID"; drift=1; }
    [ "$ownerd" = "$CRED_GH_OWNER" ] || { bad "$acct: gh-app.conf declares owner '$ownerd', fleet baseline is $CRED_GH_OWNER"; drift=1; }
  fi

  case "$token" in
    gho) : ;;
    missing) bad "$acct: no gh-token at all (~/.config/gh/hosts.yml unreadable or absent) -- gh CLI cannot authenticate: no issue filing, no deploy-key registration"; drift=1 ;;
    pat|other)
      if cred_grant_covers "$acct" token-type "$token"; then
        gap "$acct: gh-token is '$token' -- DECLARED in CRED_GRANTS, not baseline but on record"
      else
        bad "$acct: gh-token is '$token', not the fleet's 'gho_' baseline, and UNDECLARED in CRED_GRANTS -- this exact shape is what left ecosim 403ing on Pull requests for two days"
        drift=1
      fi
      ;;
  esac

  if [ "$extra" != "-" ]; then
    local old_ifs="$IFS" f
    local -a files=()
    IFS=','; read -ra files <<<"$extra"; IFS="$old_ifs"
    for f in "${files[@]}"; do
      [ -n "$f" ] || continue
      if cred_grant_covers "$acct" extra-file "$f"; then
        gap "$acct: extra file '$f' under ~/.config/selfdev/ -- DECLARED in CRED_GRANTS"
      else
        bad "$acct: leftover private file '$f' under ~/.config/selfdev/ -- the credential is host-wide now, so a private copy is a second source a rotation will miss; retire with \`sudo bin/selfdev-app-key.sh --retire-copies\`, or declare it in CRED_GRANTS with a dated reason"
        drift=1
      fi
    done
  fi

  [ "$wire_own" = 3 ] || { bad "$acct: own-repo git wiring is $wire_own/3 url.insteadOf spellings -- cannot push via the deploy-key channel"; drift=1; }
  local r i=0
  for r in $CRED_SHARED_REPOS; do
    i=$((i + 1))
    local w=""
    case "$i" in 1) w="$wire_r1" ;; 2) w="$wire_r2" ;; 3) w="$wire_r3" ;; esac
    [ "$w" = 3 ] || { bad "$acct: $r git wiring is ${w:-0}/3 url.insteadOf spellings"; drift=1; }
  done

  [ "$drift" -eq 0 ] && ok "$acct: matches baseline"
  return "$drift"
}

# ============================================================================
# THE SYMMETRY CHECK -- deploy-key READ/WRITE level, from GitHub itself.
# ============================================================================
#
# Everything above reads local CONFIG (is a url.insteadOf rewrite present).
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
cred_check_deploy_keys() { # cred_check_deploy_keys <account>...
  if ! command -v "$CRED_GH_BIN" >/dev/null 2>&1; then
    blind "deploy-key symmetry: '$CRED_GH_BIN' not on PATH -- could not check GitHub-side read/write permissions"
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    blind "deploy-key symmetry: jq not on PATH -- could not parse deploy-key listings"
    return
  fi
  if ! "$CRED_GH_BIN" auth status >/dev/null 2>&1; then
    blind "deploy-key symmetry: '$CRED_GH_BIN' is not authenticated here -- could not check GitHub-side read/write permissions"
    return
  fi
  # AN ACCOUNT'S OWN REPO IS ALWAYS ITS OWN, even when that repo also appears
  # on the shared list. `realisateur@monkey` and `scheduler@monkey` exist
  # because one unix user per project is the whole monkey design, and their
  # own repo IS a shared repo -- so the two halves of the symmetry rule gave
  # opposite answers for exactly those accounts and the audit reported a
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
  local repo acct others
  for repo in $CRED_SHARED_REPOS; do
    others=""
    for acct in "$@"; do
      [ "$(cred_own_repo "$acct")" = "$repo" ] && continue
      others="$others $acct"
    done
    # shellcheck disable=SC2086
    [ -n "$others" ] && cred_check_repo_keys "$repo" ro $others
  done
  for acct in "$@"; do
    cred_check_repo_keys "$(cred_own_repo "$acct")" rw "$acct"
  done
}

# cred_check_repo_keys <repo> <ro|rw> <accounts...> -- list a repo's deploy
# keys ONCE and grade every named account's key against the expected level,
# so a shared repo (checked for all ten accounts at once) costs one call.
cred_check_repo_keys() {
  local repo="$1" want="$2"; shift 2
  # `--json title,readOnly` is REQUESTED but not, in practice, HONOURED: gh
  # 2.45.0 validates "readOnly" as a real field name (an unknown one is
  # refused with a list that names it) and then ignores the filter anyway,
  # returning the endpoint's raw default shape -- id, key, title, created_at,
  # read_only (snake_case). Measured live, not assumed. `--json` is still
  # passed because a future gh that actually honours it should not need this
  # comment rewritten; the parsing below tolerates either key name.
  local json; json="$("$CRED_GH_BIN" repo deploy-key list --repo "$CRED_GH_OWNER/$repo" --json title,readOnly 2>/dev/null)"
  if [ -z "$json" ]; then
    blind "deploy-key symmetry: could not list keys on $CRED_GH_OWNER/$repo (no admin access here, or the repo/call failed)"
    return
  fi
  local acct want_word; [ "$want" = rw ] && want_word="WRITE" || want_word="READ-ONLY"
  for acct in "$@"; do
    # TWO jq calls, deliberately, not one with `// empty`. jq's `//` falls
    # through on `false` as well as `null` -- `.readOnly // empty` silently
    # turned every legitimate `"readOnly": false` (a WRITE key -- exactly the
    # own-repo case this check exists to confirm) into "not found", which
    # would have made this check unable to ever confirm a WRITE grant.
    # Measured live against a fixture while building this file. `length`
    # distinguishes "no matching title" from "matching title, value false".
    local suf="-$acct-$repo" found
    found="$(printf '%s' "$json" | jq -r --arg suf "$suf" '[.[] | select(.title | endswith($suf))] | length')"
    if [ "${found:-0}" -eq 0 ] 2>/dev/null; then
      bad "$acct: no deploy key registered on $repo (title ending '$suf') -- expected $want_word"
      continue
    fi
    # readOnly-OR-read_only, resolved by KEY PRESENCE rather than `//`, which
    # would repeat the exact false-swallowing mistake one paragraph up the
    # moment the field legitimately holds `false` under either name.
    local ro; ro="$(printf '%s' "$json" | jq -r --arg suf "$suf" '
      [.[] | select(.title | endswith($suf))][0] as $m
      | if ($m | has("readOnly")) then ($m.readOnly | tostring) else ($m.read_only | tostring) end
    ')"
    case "$want:$ro" in
      rw:false|ro:true) ok "$acct: $repo deploy key is $want_word, matching the symmetry rule" ;;
      rw:true)  bad "$acct: $repo (OWN repo) deploy key is READ-ONLY -- cannot push its own work" ;;
      ro:false) bad "$acct: $repo (SHARED repo) deploy key is WRITE -- the symmetry rule says shared repos are read-only; a stray write key here is exactly the cross-repo-push shape Zach flagged" ;;
      *)
        # FAIL LOUD ON AN UNRECOGNIZED SHAPE. A silent `case` with no default
        # arm is exactly how this bug hid the first time: `$ro` read the
        # literal string "null" (the field name gh's own error message calls
        # correct, absent from gh's own actual output) and matched NONE of
        # the three arms above, so the whole symmetry section printed nothing
        # at all for a live 13-repo run -- not ok, not FLAG, not BLIND.
        # Found live against the real fleet while building this file.
        blind "deploy-key symmetry: $acct on $repo returned an unreadable readOnly value ('$ro') -- gh's JSON shape may have changed" ;;
    esac
  done
}

# ============================================================================
# --audit
# ============================================================================
cmd_audit() {
  echo "== selfdev-credentials --audit -- $CRED_HOST, uid $CRED_UID_MIN-$CRED_UID_MAX (read-only) =="
  echo "   baseline: bin/lib/selfdev-credentials-set.sh (App $CRED_APP_ID @ $CRED_GH_OWNER, shared repos: $CRED_SHARED_REPOS)"
  echo

  local out; out="$(fetch_remote "")"; local rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
    echo "BLIND: could not reach $CRED_HOST at all (ssh rc=$rc). Nothing was verified." >&2
    return 3
  fi

  # `read -r acct row` with IFS=tab and MORE than two tab-separated fields on
  # the line: bash assigns the first field to `acct` and everything else,
  # delimiters included, to the last-named variable `row` -- which is exactly
  # the whole-row string cred_grade_account wants. A plain here-string, not a
  # pipe: this loop must run in the CURRENT shell so `accounts+=` survives it.
  local accounts=() acct row
  while IFS=$'\t' read -r acct row; do
    [ -n "$acct" ] || continue
    accounts+=("$acct")
    cred_grade_account "$acct" "$row"
  done <<<"$out"

  if [ "${#accounts[@]}" -eq 0 ]; then
    echo "BLIND: $CRED_HOST answered, but no account in uid $CRED_UID_MIN-$CRED_UID_MAX was found." >&2
    return 3
  fi

  echo
  echo "-- deploy-key symmetry (GitHub-side read/write, own repo vs shared) --"
  cred_check_deploy_keys "${accounts[@]}"

  echo
  echo "-- the redundancy note (informational; nothing acted on) --"
  echo "  every 'gho'/'pat' token above lives in ~/.config/gh/hosts.yml and is"
  echo "  used by the gh CLI (issue/PR listing, deploy-key registration)."
  echo "  hf7y/scheduler#103 (merged 2026-08-11) now mints a GitHub App"
  echo "  installation token at DISPATCH time, which makes this stored,"
  echo "  long-lived token redundant on that path. Not removed here -- see"
  echo "  this script's header. Filing the removal is a separate decision."

  echo
  printf 'selfdev-credentials: %d ok, %d gap, %d FLAG, %d BLIND, %d account(s)\n' \
    "$PASS" "$GAPS" "$BAD" "$BLIND_N" "${#accounts[@]}"
  if [ "$BAD" -gt 0 ] || [ "$BLIND_N" -gt 0 ]; then
    return 1
  fi
  return 0
}

# ============================================================================
# --apply <account>
# ============================================================================
#
# Idempotent, fails loud, NEVER touches ~/.config/gh/hosts.yml and NEVER
# deletes an "extra" file -- see the header. Every step is DELEGATED to a
# script that already exists and is already tested (wire-selfdev-git.sh), or
# is the same shared-credential COPY provision-selfdev-user.sh already does
# for the claude/gh tokens -- no new way to mint or register a credential is
# invented here.
cmd_apply() {
  local acct="$1"
  echo "== selfdev-credentials --apply $acct -- $CRED_HOST =="
  local fetched; fetched="$(fetch_remote "$acct")"; local rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$fetched" ]; then
    echo "selfdev-credentials --apply: could not reach $CRED_HOST, or '$acct' is not in the uid $CRED_UID_MIN-$CRED_UID_MAX band there (ssh rc=$rc) -- refusing to guess" >&2
    return 5
  fi
  local seen_acct data
  IFS=$'\t' read -r seen_acct data <<<"$fetched"
  if [ "$seen_acct" != "$acct" ] || [ -z "$data" ]; then
    echo "selfdev-credentials --apply: unexpected response reading $acct from $CRED_HOST -- refusing to guess" >&2
    return 5
  fi
  if [ "$data" = BLIND ]; then
    echo "selfdev-credentials --apply: $acct read as BLIND (sudo -n failed) -- fix sudo access before converging anything" >&2
    return 5
  fi

  local pem conf keymatch token extra wire_own wire_r1 wire_r2 wire_r3 appid ownerd
  IFS=$'\t' read -r pem conf keymatch token extra wire_own wire_r1 wire_r2 wire_r3 appid ownerd <<<"$data"

  local failed=0 changed=0

  # --- 1. the App credential: HOST-WIDE, placed by the script that owns it --
  #
  # This block used to copy a private app.pem + gh-app.conf into the account,
  # from `$CRED_APP_PEM_SRC` (default ~/.config/selfdev/app.pem on THIS host).
  # That default path never existed here -- selfdev-gh-app.sh --adopt writes
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
  if [ "$pem" != "ok:600" ] || [ "$conf" = missing ]; then
    act "placing the host-wide App credential and adding $acct to group $CRED_APP_GROUP (selfdev-app-key.sh --apply)"
    if "$CRED_SSH_BIN" -o BatchMode=yes "$CRED_HOST" \
         "sudo -n /home/${CRED_APPKEY_RUNNER:-zach}/Documents/Projects/realisateur/bin/selfdev-app-key.sh --apply --owner '$CRED_GH_OWNER'" 2>&1 | sed 's/^/    /'; then
      echo "  OK    host-wide App credential in place and readable by $acct"
      changed=1
    else
      echo "  FLAG  selfdev-app-key.sh --apply did not complete on $CRED_HOST -- run it there and read its rows: sudo bin/selfdev-app-key.sh --check" >&2
      failed=1
    fi
  else
    echo "  --    $acct already reads the host-wide App credential; left alone"
  fi

  # --- 2. git wiring: DELEGATED to the account's own wire-selfdev-git.sh ----
  cred_apply_wiring() { # cred_apply_wiring <repo> <rw-or-empty> <have>
    local repo="$1" rw="$2" have="$3"
    if [ "$have" = 3 ]; then
      echo "  --    $repo git wiring already 3/3 for $acct; left alone"
      return 0
    fi
    act "wire-selfdev-git.sh $repo --apply${rw:+ --rw} as $acct"
    local remote_script="\$HOME/Documents/Projects/realisateur/bin/wire-selfdev-git.sh"
    if "$CRED_SSH_BIN" -o BatchMode=yes "$CRED_HOST" \
         "sudo -n -u '$acct' bash -lc \"[ -x $remote_script ] && '$remote_script' '$repo' --apply${rw:+ --rw}\""; then
      echo "  OK    $repo wired for $acct"
      changed=1
      return 0
    fi
    echo "  FLAG  wiring $repo for $acct FAILED -- see wire-selfdev-git.sh's own output above" >&2
    failed=1
    return 1
  }
  cred_apply_wiring "$(cred_own_repo "$acct")" --rw "$wire_own"
  local r i=0
  for r in $CRED_SHARED_REPOS; do
    i=$((i + 1))
    local w=""
    case "$i" in 1) w="$wire_r1" ;; 2) w="$wire_r2" ;; 3) w="$wire_r3" ;; esac
    cred_apply_wiring "$r" "" "$w"
  done

  # --- 3. what this NEVER does, said out loud in the run itself -------------
  echo "  --    ~/.config/gh/hosts.yml (the gh-token) was not touched -- removing a working credential is a decision, not a converge step"
  if [ "$extra" != "-" ]; then
    echo "  --    extra file(s) under ~/.config/selfdev/ ($extra) were not touched -- declare them in CRED_GRANTS or remove them by hand"
  fi

  echo
  if [ "$changed" -eq 0 ] && [ "$failed" -eq 0 ]; then
    echo "selfdev-credentials --apply $acct: nothing to do -- already at baseline."
    return 0
  fi
  if [ "$failed" -gt 0 ]; then
    echo "selfdev-credentials --apply $acct: FAILED -- see FLAG rows above. This IS machine-wide config; run notify-senechal once the remaining rows are clear." >&2
    return 5
  fi
  echo "selfdev-credentials --apply $acct: converged. This changed machine-wide config on $CRED_HOST -- run:"
  echo "    notify-senechal 'selfdev-credentials --apply converged $acct@$CRED_HOST to the credential baseline, owned by realisateur'"
  return 0
}

# ============================================================================
# main
# ============================================================================
main() {
  local mode=audit account=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --audit) mode=audit ;;
      --apply) mode=apply; account="${2:-}"; shift ;;
      *) echo "$CLI_NAME: unexpected argument: $1" >&2; exit 2 ;;
    esac
    shift
  done

  if [ "$mode" = apply ]; then
    [ -n "$account" ] || { echo "$CLI_NAME: --apply needs an account name" >&2; exit 2; }
    cmd_apply "$account"; exit $?
  fi
  cmd_audit; exit $?
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
