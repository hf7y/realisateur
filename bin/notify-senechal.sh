#!/usr/bin/env bash
# notify-senechal.sh <text> -- file a machine-config change through senechal's
# own front door, and make sure it actually LANDED where senechal reads it.
#
# THE STANDING RULE THIS MECHANIZES (Zach-directed, reaffirmed 2026-07-26):
# realisateur GENERATES machine-wide config (crontab entries, ~/.claude
# settings hooks, systemd units, autostart, WM config, marker files under
# ~/.local/share); senechal OWNS KNOWING IT EXISTS. Ownership of the thing
# itself stays with realisateur -- precedent is the `# >>> realisateur-owned`
# block inside Zach's crontab: one project owning its own entry inside a
# shared machine-config surface.
#
# WHAT IT RETIRES: the prose promise. Until now this rule lived only as a
# remembered policy ("cross-write a dated note to senechal's FOCUS.md"), and
# prose decays -- UNIVERSE.md's own doctrine. On 2026-07-26 the cross-write
# for the SessionStart/SessionEnd hook was deferred (senechal was mid-run),
# recorded as owed in QUESTIONS.md, and only paid a session later by hand.
# That is exactly the failure mode a script removes.
#
# WHY THE FRONT DOOR AND NOT A DIRECT WRITE:
# `scheduler -i senechal` is the one interface senechal publishes for inbound
# notes. Going around it means guessing where senechal keeps its inbox, which
# is precisely the coupling the split below exists to prevent.
#
# WHAT CHANGED, 2026-08-05 (scheduler#22), and what it retires:
# `scheduler -i` used to append to a LOCAL .scheduler/FOCUS.md in a senechal
# clone and push it. It now files a GitHub ISSUE. So everything this script
# did after the call -- fetch, merge-base containment, a SIGPIPE-safe blob
# read of FOCUS.md, and a rebase-with-content-verification path for the
# behind case -- had no subject any more and is DELETED, not switched off.
#
# Two things that bought:
#   * this script no longer needs a senechal CLONE on the host it runs from.
#     That clone was the last thing pinning senechal to every machine, and it
#     was pinned by the one command the protocol requires everyone to call.
#   * it fixes MONKEY.md 8.1(2) from the other side. A self-dev account holds
#     a READ-ONLY deploy key on senechal, so the old push could never work:
#     `installe` exited 8 on all 25 verbs while the change itself had landed.
#     An issue needs no write access to any default branch.
#
# The old header argued this script must not stop at `scheduler -i` because
# that command skips the push when the repo is behind, leaving a note the
# consumer never reads. That reasoning is retired with the mechanism -- there
# is no push to skip. The PRINCIPLE it came from is not: verify where the
# consumer reads it. So `--- 2.` still re-reads the issue from GitHub rather
# than trusting exit 0 and a URL we printed ourselves.
#
# WHO OWNS WHAT IN THIS FILE (Zach's call, 2026-07-27) -- read before editing:
#
#   realisateur owns the PROTOCOL. That this guard exists at all, that it is
#   one of a family of three (with check-project-busy, focus-commit), that
#   the family is propagated as a baseline and shimmed onto PATH, and that
#   calling it is mandatory when machine-wide config changes. Structure,
#   existence, distribution.
#
#   senechal owns the CONTRACT -- everything below the `--- 2.` line: what
#   "landed" means and which surface the consumer actually reads. That is now
#   its issue queue rather than a file in its tree, which is a smaller and
#   more stable contract than the one it replaces: an issue URL cannot be
#   moved by senechal reorganising its own repository.
#
# Why split it rather than leave it all here: this script encoded senechal's
# read-path in realisateur's repo, so if senechal moved its inbox its own
# front door would break and it would be structurally unable to fix it. Not
# hypothetical -- realisateur made exactly that .claude/ -> .scheduler/ move
# on 2026-07-26. The 2026-07-27 SIGPIPE bug was the same seam: a defect in
# senechal's verification logic that only senechal noticed, requiring an edit
# to another project's repo to fix.
#
# Practical rule: a change to step 2 is senechal's to make, unannounced. A
# change to step 1, to the guard family, or to how this is installed is
# realisateur's. Cross-write to the other when you touch its half.
#
# Usage:
#   bin/notify-senechal.sh 'realisateur added <what> at <where>; ownership: ...'
#
# Exit 0 ONLY if the note is on senechal's remote. Every other path exits
# non-zero with a stated reason -- no exit-0 no-op.
set -uo pipefail

# WHERE PROJECTS LIVE IS A PROPERTY OF THE HOST, NOT OF ZACH'S LAPTOP.
# These were absolute paths under /home/zach, which is correct on mandark and
# wrong everywhere else. On `monkey` -- the self-dev host stood up 2026-08-03,
# one unix user per project -- this guard died with
#
#   notify-senechal: FAIL: scheduler front door not found/executable at
#   /home/zach/Documents/Projects/scheduler/bin/scheduler
#
# so a machine-scoped change made on monkey could not be filed AT ALL. That is
# the guard whose entire job is filing, structurally unable to do it on the
# host the ecosystem is moving to. It failed loud, which is the only reason
# this is a fix and not an incident.
#
# INSTALLE_PROJECTS is the name install-verbs.sh, verb-set.sh, installe and
# land-selfdev.sh already share for this, so there are not two answers.
PROJECTS_ROOT="${INSTALLE_PROJECTS:-$HOME/Documents/Projects}"
SCHED_ROOT="${SCHED_ROOT:-$PROJECTS_ROOT/scheduler}"

die() { printf 'notify-senechal: FAIL: %s\n' "$*" >&2; exit 1; }

text="${1:-}"
[ -n "$text" ] || die "no text given. Usage: notify-senechal.sh '<what changed, where, who owns it>'"

# A LEADING DASH IS A MISPARSE, NOT A MESSAGE. This script's argument is free
# text, so it has no flags to get wrong -- which meant a mistyped or
# programmatically-passed flag became the note's BODY and was pushed to
# senechal's repo. That is not hypothetical: on 2026-07-30 a probe sweep ran
# `notify-senechal.sh --not-a-real-flag` across bin/ to find exit-0 no-ops, and
# this script filed "--not-a-real-flag" into senechal's FOCUS.md and pushed it
# (senechal 6f9f6f7, retracted in place same day). No human writes a note that
# starts with a dash; a caller that does has lost track of its own arguments.
case "$text" in
  --help|-h)
    printf "notify-senechal.sh -- announce a machine-wide config change to senechal\n\n"
    printf "usage:\n  notify-senechal.sh '<what changed, where, who owns it>'\n\n"
    printf "flags: none -- the single argument is free text\n\n"
    printf "exit codes:\n"
    printf "  0  the note is confirmed present on senechal's remote\n"
    printf "  1  any failure, with a stated reason (no exit-0 no-op)\n"
    printf "  2  usage error: the message looks like a misparsed flag\n\n"
    printf "this tool makes no AI calls and cannot spend: --summon is rejected.\n"
    exit 0 ;;
  -*)
    printf "notify-senechal: refusing to file a note that begins with '-': %s\n" "$text" >&2
    printf "  This is almost always a misparsed flag rather than a message. If you\n" >&2
    printf "  really mean it, lead with a word: 'note: %s'\n" "$text" >&2
    exit 2 ;;
esac

[ -x "$SCHED_ROOT/bin/scheduler" ] || die "scheduler front door not found/executable at $SCHED_ROOT/bin/scheduler"
# NOTE: no senechal clone is required any more -- the note goes to GitHub.
# The check that used to be here (`[ -d "$SENECHAL/.git" ]`) is removed
# deliberately: keeping it would have made this script keep DEMANDING the very
# checkout the change exists to make unnecessary, on every host, forever.

# --- 1. file it through the front door, and capture the issue it created ----
#
# THE FRONT DOOR IS GITHUB (Zach, 2026-08-05; scheduler#22). `scheduler -i`
# no longer appends to a local .scheduler/FOCUS.md and pushes -- it files a
# GitHub issue labelled `idea`. Everything this script used to do after the
# call was verification of a COMMIT: fetch, merge-base containment, a
# SIGPIPE-safe blob read of FOCUS.md, and a rebase-with-content-verification
# path for the behind case. None of that has a subject any more, so it is
# deleted rather than left switched off.
#
# What it buys, beyond simplicity: this script no longer needs a senechal
# CLONE on the host it runs from. That clone was the last thing pinning
# senechal to every machine, and it was pinned by the one command the estate
# protocol requires every project to call.
#
# It also fixes MONKEY.md 8.1(2) from the other side: a self-dev account
# holds a READ-ONLY deploy key on senechal, so the old push could never work
# and `installe` exited 8 on all 25 verbs while the change itself had landed.
# Filing an issue needs no write access to any default branch.
echo "notify-senechal: filing via 'scheduler -i senechal'..."
out="$("$SCHED_ROOT/bin/scheduler" -i senechal "$text" 2>&1)" || {
  printf '%s\n' "$out" >&2
  die "scheduler -i senechal rejected the note"
}
printf '%s\n' "$out"

# The URL is the receipt. Parsed rather than assumed, because a `scheduler -i`
# that silently changed its output shape must fail here, not be reported as a
# success nobody can find. This is the same reason the old body verified the
# commit instead of trusting exit 0.
issue_url="$(printf '%s\n' "$out" | grep -oE 'https://github\.com/[^[:space:]]+/issues/[0-9]+' | head -1)"
[ -n "$issue_url" ] \
  || die "scheduler -i reported success but printed no issue URL -- nothing verifiable was recorded"

# --- 2. prove the issue exists on the remote --------------------------------
#
# Re-read it from GitHub rather than trusting the URL we were handed. The
# discipline rule is "verified where the consumer reads it", and the consumer
# here is whoever opens senechal's issue list.
command -v gh >/dev/null 2>&1 \
  || die "gh is not on PATH -- the note may have been filed, but nothing here can confirm it"

if ! state="$(gh issue view "$issue_url" --json state,title -q '.state' 2>&1)"; then
  printf '%s\n' "$state" >&2
  die "filed $issue_url but could not read it back -- treat as UNVERIFIED"
fi
case "$state" in
  OPEN|CLOSED) ;;
  *) die "filed $issue_url but its state reads as '$state' -- treat as UNVERIFIED" ;;
esac

echo "notify-senechal: OK -- filed and verified on senechal's issue queue ($state)"
echo "  $issue_url"
exit 0