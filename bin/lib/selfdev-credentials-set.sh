#!/usr/bin/env bash
# selfdev-credentials-set.sh -- THE SELF-DEV CREDENTIAL BASELINE, in one place.
#
# ============================================================================
# WHY THIS EXISTS
# ============================================================================
#
# Measured 2026-08-11: ten self-dev accounts (uid 3000-3099 on `monkey`) each
# got their credentials wired by hand-ish, one-account-at-a-time runs of
# provision-selfdev-user.sh / wire-selfdev-git.sh / selfdev-gh-app.sh over the
# course of a week. Nothing ever read the ten side by side.
#
# ecosim's `github_pat` (a fine-grained PAT missing the Pull-requests
# permission) sat unnoticed for two days, returning 403 on the entire
# Pull-requests API, because every other signal an operator would check
# (`gh issue list`, a green test run, a pushed branch) kept working. The
# defect was never "the PAT was wrong" -- a wrong credential is a normal,
# expected failure mode and every script in this family already reports one
# loudly. THE DEFECT WAS THAT NOTHING COMPARED THE TEN, so the one account
# that diverged from its nine siblings had no sensor pointed at the
# divergence itself, only at each account in isolation.
#
# So this file is not a provisioning script. It is the DECLARATION that
# bin/selfdev-credentials.sh measures every account against -- one baseline,
# read from here and nowhere else, per BUILD-DISCIPLINE.md's "config read
# from one source, not retyped per file".
#
# ============================================================================
# THE BASELINE SHAPE (verified live 2026-08-11, all ten accounts)
# ============================================================================
#
#   ~/.config/selfdev/app.pem        the ONE fleet-wide GitHub App's private
#                                     key (MONKEY.md 11.1: one App, id 4521586,
#                                     shared across every account on purpose).
#                                     Mode 600. No other file in that
#                                     directory is baseline.
#   ~/.config/selfdev/gh-app.conf    SELFDEV_APP_ID / SELFDEV_APP_KEY (must
#                                     resolve to the app.pem actually present)
#                                     / SELFDEV_GH_OWNER. Mode 600.
#   ~/.config/gh/hosts.yml           the gh CLI's own OAuth token, COPIED
#                                     (provision-selfdev-user.sh), not minted
#                                     per account -- see THE REDUNDANCY NOTE.
#   git url.insteadOf                three rewrite spellings per repo
#                                     (wire-selfdev-git.sh), for the account's
#                                     own repo AND for each of
#                                     CRED_SHARED_REPOS. This is where
#                                     Zach's symmetry rule actually lives:
#
# ============================================================================
# THE SYMMETRY RULE (Zach, 2026-08-11, stated plainly)
# ============================================================================
#
#   "why does vim-arcade need to write to scheduler repo instead of filing
#    issues? this keeps coming up but it makes no sense. [make them]
#    symmetrical with the option to add extra permissions using the script
#    utility"
#
# An account has WRITE on its own project repo, READ on the shared repos it
# must pull (realisateur, scheduler, senechal, ...), and anything it needs to
# SAY about a shared repo goes through a front door that files an issue
# (`scheduler -i`, `notify-senechal`, `consulte`) -- never a cross-repo push.
# That rule already existed in prose (wire-selfdev-git.sh's own header, this
# file's neighbours) and nowhere compared what GitHub actually granted against
# it. `bin/selfdev-credentials.sh`'s deploy-key section is the mechanization:
# it reads `gh repo deploy-key list` for every repo in scope and asserts
# read_only=false on the account's own repo, read_only=true everywhere else.
#
# ============================================================================
# THE REDUNDANCY NOTE (not enforced here, not silently acted on)
# ============================================================================
#
# `bin/selfdev-gh-app.sh`'s own header ("WHY A TOKEN AND NOT A PAT") argues
# that a long-lived secret at rest is exactly what the GitHub App exists to
# eliminate: an installation token expires in one hour and is minted from a
# key on demand, so there is nothing to leak. hf7y/scheduler#103 (merged
# 2026-08-11) now mints an App token at DISPATCH time, which makes the shared
# `gho_` token copied into every account's `~/.config/gh/hosts.yml` redundant
# on that path -- two credential systems layered, one of which was supposed
# to replace the other.
#
# bin/selfdev-credentials.sh --audit REPORTS this every run (see its
# "redundant on the dispatch path" line). It does not remove the token, ever,
# under --apply or otherwise: "do not silently strip a working credential" --
# BUILD-DISCIPLINE.md pattern 1, and stated directly for this PR. Deciding
# whether and when to retire the copied token is a separate, filed question.
#
# ============================================================================
# EXTRA PERMISSIONS -- DECLARED, DATED, READ FROM HERE
# ============================================================================
#
# The baseline above is symmetric on purpose: every account gets the same
# shape. Zach asked for "the option to add extra permissions using the script
# utility" -- explicitly NOT an ad-hoc flag that leaves no trace, because an
# undeclared exception is exactly how ecosim's PAT survived two days: nobody
# could read, in one place, "this account is different, and here is why".
#
# CRED_GRANTS is that place. Each row is a permanent, reviewed exception, not
# a convenience -- adding one is a decision, the same way raising a bound in
# propagation-set.sh or ownership-set.sh is a decision there. Empty today: no
# account has a reviewed reason to differ from the baseline, and ecosim's
# `ecosim.pem` / `github_pat` are NOT such a reason -- they are exactly the
# undeclared drift this file exists to make visible instead of silently
# tolerated.
#
# FORMAT (newline-separated, consumed by `while read`, NOT shell code -- see
# ownership-set.sh's own warning: a bare `"` inside a row here would silently
# truncate this file the same way it truncated that one):
#
#   <account>  <kind>  <what>              <YYYY-MM-DD>  <reason...>
#
#   kind = extra-file    what = a filename under ~/.config/selfdev/ beyond
#                                app.pem and gh-app.conf
#   kind = repo-access   what = <repo>:<ro|rw>, permitting a deploy key whose
#                                access level differs from the WRITE-own /
#                                READ-shared default
#   kind = token-type     what = gho|pat|other, permitting a gh-token shape
#                                other than the fleet default (gho_)
#
# Example (commented out -- there are no live grants):
#   # ecosim  extra-file  ecosim.pem  2026-08-11  legacy key kept during the
#   #                                              App-conf migration; remove
#   #                                              once selfdev-credentials
#   #                                              --audit reports it gone
CRED_GRANTS="
"

# --- the uid band -------------------------------------------------------
# Same band provision-selfdev-user.sh creates accounts in, same knob names
# selfdev-agent-survey.sh already uses -- one more reader of the same fact,
# not a second definition of it.
CRED_UID_MIN="${CRED_UID_MIN:-3000}"
CRED_UID_MAX="${CRED_UID_MAX:-3099}"

# --- the shared repos, read-only by baseline -----------------------------
CRED_SHARED_REPOS="realisateur scheduler senechal"

# --- the fleet-wide App, per MONKEY.md 11.1 -------------------------------
# One App across all ten accounts, decided 2026-08-07. An account whose
# gh-app.conf declares a DIFFERENT id or owner is not obviously wrong (the
# decision has a stated revisit trigger) but it IS a divergence from every
# sibling, and this baseline is what "divergence" is measured against.
CRED_APP_ID="${CRED_APP_ID:-4521586}"
CRED_GH_OWNER="${CRED_GH_OWNER:-hf7y}"

# --- the baseline file set, under ~/.config/selfdev/ ----------------------
CRED_BASELINE_FILES="app.pem gh-app.conf"

# cred_classify_token <line> -- given the raw `oauth_token:` line from
# hosts.yml (or empty), classify its SHAPE without ever handling the secret
# itself beyond a substring test. Pure, offline-testable.
#
#   gho      a `gho_` OAuth token -- the shared, copied credential every
#            account but ecosim carries today. Flagged redundant (see above),
#            never stripped.
#   pat      a `github_pat_` fine-grained PAT -- ecosim's shape, live
#            2026-08-11. Not baseline; a real divergence unless CRED_GRANTS
#            names it.
#   other    present, and neither of the above -- a classic PAT
#            (`ghp_`) or something this baseline has never seen.
#   missing  no oauth_token line at all.
cred_classify_token() {
  local line="$1"
  case "$line" in
    *gho_*)         echo gho ;;
    *github_pat_*)  echo pat ;;
    "")             echo missing ;;
    *)              echo other ;;
  esac
}

# cred_own_repo <account> -- the repo this account should hold WRITE on.
# Today every account's own repo is named identically to the account
# (MONKEY.md 11.1: "every account had a matching hf7y/<name> repo; none was
# missing, and none was invented") -- but a future account could reasonably
# want a different repo name, so this is a single function or an override
# in CRED_GRANTS's own vocabulary, not eleven hardcoded assumptions.
cred_own_repo() {
  printf '%s' "$1"
}

# cred_grant_covers <account> <kind> <what> -- is this exact exception
# declared? rc 0 = yes (and the caller must still REPORT it, never go quiet),
# rc 1 = no, this is undeclared drift.
cred_grant_covers() {
  local acct="$1" kind="$2" what="$3" g_acct g_kind g_what g_date
  while read -r g_acct g_kind g_what g_date _; do
    [ -n "$g_acct" ] || continue
    if [ "$g_acct" = "$acct" ] && [ "$g_kind" = "$kind" ] && [ "$g_what" = "$what" ]; then
      return 0
    fi
  done <<EOF
$CRED_GRANTS
EOF
  return 1
}

# cred_list_grants <account> -- print every declared grant for one account,
# one per line, for the audit's report section. Empty output means no grants.
cred_list_grants() {
  local acct="$1" g_acct g_kind g_what g_date g_rest
  while read -r g_acct g_kind g_what g_date g_rest; do
    [ -n "$g_acct" ] || continue
    [ "$g_acct" = "$acct" ] || continue
    printf '%s %s %s %s\n' "$g_kind" "$g_what" "$g_date" "$g_rest"
  done <<EOF
$CRED_GRANTS
EOF
}
