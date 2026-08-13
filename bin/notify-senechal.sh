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

command -v gh >/dev/null 2>&1 || die "gh is not on PATH -- cannot file, and could not confirm a filing either"
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
# SHALLOW FIX, 2026-08-12, Zach-directed: file with `gh` directly instead of
# shelling out to `scheduler -i`.
#
# WHY. `scheduler -i` is bin/scheduler, the 3,522-line monolith hf7y/scheduler#34
# is sunsetting -- and it lives in a CHECKOUT. This command is the one every
# project protocol requires, so that single call was pinning a scheduler clone
# onto every host that must be able to notify. Filing the issue is the part
# `scheduler -i` does last and least; the labels below are the part that
# matters, and `gh` can stamp those directly.
#
# THE LABEL IS A SENSOR, NOT METADATA, and it is the reason this is not just
# `gh issue create`. From realisateur/bin/thermostat-wiring.sh:147 -- "the
# provenance label is the thermostat's actual sensor. Every actor in this
# estate is `hf7y` (realisateur#40, #86), so authorship cannot answer 'did a
# human ask for this, or did an agent find it' ... An unlabelled issue reads as
# a Zach directive, i.e. it errors toward dispatching MORE." Git authorship
# cannot carry provenance here because every actor is the same account, so
# `from:<project>` is the only channel that can. Dropping it would not be
# untidy; it would make every machine note read as a human instruction.
#
# THIS IS NOT THE PRINCIPLED SHAPE -- see hf7y/realisateur#196. One door, as a
# French verb, taking a destination, with notify-senechal and `consulte` as
# thin callers. Both already implement "file a machine-authored note, labelled
# with its origin, and prove it landed", twice.
DEST_REPO="${NOTIFY_SENECHAL_REPO:-hf7y/senechal}"
FROM_PROJECT="${NOTIFY_FROM_PROJECT:-realisateur}"

# The title is the first line, bounded; the body carries the whole note. A
# title that is the entire paragraph is unreadable in a list, and the list is
# where a human meets this.
title="$(printf '%s' "$text" | head -1 | cut -c1-72)"
[ -n "$title" ] || die "the note has no first line to title it with"

# THE FOOTER IS A GATE, NOT DECORATION (restored 2026-08-13; senechal#221 ->
# realisateur#220). `scheduler -i` stamped every issue it filed with
#
#   ---
#   filed <YYYY-MM-DD HH:MM> via `<tool>` on <host>
#
# and senechal's tools/issue-janitor.py keys on it as gate 2 of seven. That
# footer is the ONLY thing distinguishing a machine receipt from a
# human-written issue: every actor in this estate is the same `hf7y` account,
# so authorship cannot answer it and the label cannot either (senechal#75 is
# `idea`-labelled, machine-filed, and real work).
#
# Filing with `gh` directly dropped it. Nothing errored -- a missing footer
# means "not machine-filed", so the janitor did not fail, it went BLIND:
# 0 of 28 swept, exit 0, reading as a clean inbox rather than a broken broom.
# Thirteen receipts were closed by hand on 2026-08-13 before it was noticed.
#
# Emitted byte-identically to `scheduler -i`'s version and pinned against
# senechal's own FOOTER_RE by bin/tests/notify-senechal-footer.test.sh.
# Changing this shape silently disables a tool in another repo -- if it must
# change, change FOOTER_RE in the same breath.
#
# The triage paragraph sits AFTER the footer on purpose: the janitor strips
# from the footer onward, so text below can never be read as part of the
# receipt body that gate 4 anchors against.
body="$(printf '%s\n\n---\nfiled %s via `notify-senechal` on %s\n\nTriage this on senechal'\''s next run: fold it into FOCUS.md if it is work,\nanswer and close it if it is a note. Closing IS the acknowledgement --\nthere is no separate label to add.\n' \
  "$text" "$(date '+%Y-%m-%d %H:%M')" "$(hostname -s 2>/dev/null || hostname)")"

echo "notify-senechal: filing to $DEST_REPO as from:$FROM_PROJECT ..."
out="$(gh issue create --repo "$DEST_REPO" \
        --title "$title" \
        --body "$body" \
        --label idea --label "from:$FROM_PROJECT" 2>&1)" || {
  printf '%s\n' "$out" >&2
  die "gh issue create rejected the note on $DEST_REPO"
}
printf '%s\n' "$out"

# The URL is the receipt. Parsed rather than assumed: a create that prints
# success without a URL recorded nothing anybody can find, and exit 0 is not
# evidence that an issue exists. Same reason the body below reads it back.
issue_url="$(printf '%s\n' "$out" | grep -oE 'https://github\.com/[^[:space:]]+/issues/[0-9]+' | head -1)"
[ -n "$issue_url" ] \
  || die "gh reported success but printed no issue URL -- nothing verifiable was recorded"

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