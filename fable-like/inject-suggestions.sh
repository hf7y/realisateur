#!/usr/bin/env bash
# inject-suggestions.sh — propagate the fable-review findings into the REAL projects.
#
# Appends one dated "## Fable review (2026-07-25)" section to each project's
# actual FOCUS.md (current real paths — .claude/ or .scheduler/ as each project
# uses TODAY). Honors the ecosystem's own cross-write protocol:
#   * busy-check before touching a repo (check-project-busy.sh); BUSY => skip loudly
#   * idempotent: a project already carrying the marker is skipped
#   * append-only; the heading matches none of extract_next_items()' keywords,
#     so the awk parser ignores the section entirely
#   * --commit makes one small commit per repo, never bundled, never left dirty
#
# Usage:
#   ./inject-suggestions.sh            # dry-run: report what WOULD change
#   ./inject-suggestions.sh --diff     # dry-run + show the text per project
#   ./inject-suggestions.sh --apply    # write the sections
#   ./inject-suggestions.sh --commit   # write AND commit per-repo (implies --apply)
set -euo pipefail

MODE="dry-run"
case "${1:-}" in
  "")         MODE="dry-run" ;;
  --diff)     MODE="diff" ;;
  --apply)    MODE="apply" ;;
  --commit)   MODE="commit" ;;
  *) echo "usage: $0 [--diff|--apply|--commit]" >&2; exit 2 ;;
esac

MARKER="## Fable review (2026-07-25)"
BUSY_CHECK="$HOME/Documents/Projects/realisateur/bin/check-project-busy.sh"
DOCS="$HOME/Documents"

# project|path-to-real-FOCUS.md (as of 2026-07-25; update if normalization lands)
TARGETS=$(cat <<'EOF'
scheduler|Project Archive/scheduler/.scheduler/FOCUS.md
realisateur|Projects/realisateur/.claude/FOCUS.md
crt|Projects/crt/.claude/FOCUS.md
chezz|Project Archive/chezz/.claude/FOCUS.md
home-assistant|Project Archive/home_assistant/.claude/FOCUS.md
wtul|wtul/.claude/FOCUS.md
gardien|Projects/gardien/.claude/FOCUS.md
senechal|Projects/senechal/.claude/FOCUS.md
groc-mangr|Projects/groc-mangr/.claude/FOCUS.md
nine-speakers|Projects/nine-speakers/.claude/FOCUS.md
sequestria|Projects/sequestria/.claude/FOCUS.md
vim-arcade|Projects/vim-arcade/.claude/FOCUS.md
aedile|vkv/wavebucks/aedile/.scheduler/FOCUS.md
vkv-inventory|vkv/inv/inventory-app/.claude/FOCUS.md
EOF
)

suggestions_for() {
  case "$1" in
    scheduler) cat <<'S'
- **2026-07-25 (fable-review):** build + cron-wire a liveness audit: every enabled/externally-dispatched project must have a report younger than 2 days or the morning glance shouts. The aedile/vkv-inventory 4-day silent orphaning is the class this closes. Example: realisateur/fable-like/projects/scheduler/bin/liveness-audit.sh
- **2026-07-25 (fable-review):** finish MIGRATION.md — retire the ~20 legacy `*-loop.sh` wrappers still referenced by `_paced.conf` in favor of `scheduler-run`; layer-not-replace is live in the engine's own backyard
- **2026-07-25 (fable-review):** delete (or regenerate-and-own) `services/` — stale since 2026-07-18, describes the pre-pacing world; healthy-looking stale output is the silent-failure smell
- **2026-07-25 (fable-review):** investigate the rc=1 dispatch at 2026-07-25 00:19 (scheduler batch); an uninvestigated nonzero exit is a timestamped silent failure. Also fix the `[legacy absolute path]` defect on every ROTATION log line
- **2026-07-25 (fable-review):** compaction convention for DIGEST.md (256KB) / DESIGN-NOTES.md (88KB): monthly roll-up into docs/history/YYYY-MM.md + one-page index; append-only stays, unbounded single files go
S
      ;;
    realisateur) cat <<'S'
- **2026-07-25 (fable-review):** split doctrine from journal — standing decisions (identity seam, vision-debt math, autonomy bar) into a DOCTRINE.md edited in place; .claude/FOCUS.md (56KB) stays a lean dated log with monthly roll-ups
- **2026-07-25 (fable-review):** create NAMES.md (with senechal) and check it before every scaffold — two unrelated bibliothecaires exist right now (crt's parked catalog split vs the inbox "page 92" idea)
- **2026-07-25 (fable-review):** build the two queued lints (hygiene-lint shared-host-footprint row; milestone-format check that says "join these two lines" instead of UNRECOGNIZED) — own doctrine: guards over reminders
- **2026-07-25 (fable-review):** file-structure normalization is stalling because it's batch-sized; execute one move per /ideate pass, scheduler out of "Project Archive" first
S
      ;;
    crt) cat <<'S'
- **2026-07-25 (fable-review):** mandark's paced-runner log shows crt dispatches 2026-07-24 23:58/23:59 despite `_paced.conf` enabled=0 and dexter ownership — verify (stale log vs real double-dispatch), then make single-host dispatch a runner-enforced invariant, not a two-config-file implication
- **2026-07-25 (fable-review):** resolve the bibliothecaire name collision (your parked Book-Game catalog split vs realisateur's new inbox "page 92" idea) before either scaffolds
S
      ;;
    chezz) cat <<'S'
- **2026-07-25 (fable-review):** declare a stability milestone — the oldest project runs nightly at weight 1 with no bar; proposed: tracker-driven bug sweep re-enabled under the paced governor + one week green
- **2026-07-25 (fable-review):** migrate .claude/ -> .scheduler/ to unblock unattended QUESTIONS.md writes (the sensitive-file gate), and retire chezz-nightly-batch-loop.sh for scheduler-run
- **2026-07-25 (fable-review):** the staleness check silently no-op'd during the 2026-07-25 mega-burn — make it exit nonzero with a reason; sweep tier "PAUSED pending migration" since 07-19 needs an owner or an explicit park
S
      ;;
    home-assistant) cat <<'S'
- **2026-07-25 (fable-review):** the three 2026-07-18 entries are the ecosystem's oldest active debt — drain one or explicitly re-tag (parked)/(waiting) with a note; a week-old active item nobody drains and nobody parks is the ambiguity the three-state vocabulary exists to kill
- **2026-07-25 (fable-review):** make the burst/concurrency exclusion structural (a conf flag like BURST_EXCLUDE=1, reason in comment), not a remembered list
S
      ;;
    wtul) cat <<'S'
- **2026-07-25 (fable-review):** the dexter move's one remaining step is human and unnamed in BLOCKERS — record it precisely: install gh on dexter OR add the deploy key via GitHub web UI; a reverted migration with an unnamed step is a mystery in three weeks
- **2026-07-25 (fable-review):** keep this FOCUS.md thin but add a comment naming ROADMAP.md as source of truth, so the duplication is never "fixed" by deleting the wrong file
S
      ;;
    gardien) cat <<'S'
- **2026-07-25 (fable-review):** record the rejected fork option (why git-remote+partial-clone beat the alternative) in one line so the decision survives its context; TB2 cable stays correctly (waiting) — zero glance anxiety owed
S
      ;;
    senechal) cat <<'S'
- **2026-07-25 (fable-review):** scope-creep watch — three missions now live here (environment journal, keeper of names/places, shared-host footprint registry) at weight 1. Make the footprint ledger a file format (FOOTPRINTS.tsv: host/path/owner/installed/retired) hygiene-lint can diff against reality; move names into a shared NAMES.md with realisateur; keep the journal as the milestone-bearing core
S
      ;;
    groc-mangr) cat <<'S'
- **2026-07-25 (fable-review):** parked without a milestone means parked-by-velocity, not by choice — declare a re-admission bar even while parked. Proposed: one list, add-from-phone in <5s, one real shopping trip run entirely from it
S
      ;;
    nine-speakers) cat <<'S'
- **2026-07-25 (fable-review):** split the dream from the buildable core: keep the physical rig (parked, forming dream), give the belief sim a bar — proposed: 9-node headless sim, scripted PIR events, per-node belief state legible after the fact
S
      ;;
    sequestria) cat <<'S'
- **2026-07-25 (fable-review):** the hard fences are exemplary — keep all of them. Honest milestone within them: a one-page fence-compliant brand brief + static landing mockup; no domain, no deploy, no suppliers, no money
S
      ;;
    vim-arcade) cat <<'S'
- **2026-07-25 (fable-review):** cheapest re-admission in the parked set — one playable level (h/j/k/l + w/b, run-to-win in a real terminal) is weekend-sized and exactly what a nightly batch grinds well; declare it as the milestone even while parked
S
      ;;
    aedile) cat <<'S'
- **2026-07-25 (fable-review):** silently orphaned since 2026-07-20 (svc-vaporwave crontab never installed) — the 15-minute human step is the sole blocker for real email ops; surface its AGE daily until done
- **2026-07-25 (fable-review):** two flagged one-liners still unapplied: SCHEDULER_SUBDIR=".scheduler" missing from schedule/aedile.conf (milestone-audit misreports "no focus" every pass) and scheduler's questions/aedile.md symlink pointing at the wrong file — apply on sight; known-wrong survey output trains everyone to ignore the survey
S
      ;;
    vkv-inventory) cat <<'S'
- **2026-07-25 (fable-review):** same 2026-07-20 orphaning as aedile — restore svc-vaporwave dispatch, then close the class with scheduler's liveness audit
- **2026-07-25 (fable-review):** its nightly-batch never runs collect-feedback.sh --consume against its own QUESTIONS.md, so `> ` answers go unread by the run they steer — the one contractual channel, severed at its endpoint; one-line wiring fix
S
      ;;
    *) echo "no suggestions defined for '$1'" >&2; return 1 ;;
  esac
}

changed=0 skipped=0 busy=0 missing=0

while IFS='|' read -r project relpath; do
  [ -n "$project" ] || continue
  focus="$DOCS/$relpath"

  if [ ! -f "$focus" ]; then
    echo "MISSING  $project  ($focus not found — path moved? update TARGETS)" >&2
    missing=$((missing + 1))
    continue
  fi

  if grep -qF "$MARKER" "$focus"; then
    echo "skip     $project  (already carries the marker)"
    skipped=$((skipped + 1))
    continue
  fi

  if [ -x "$BUSY_CHECK" ] && ! "$BUSY_CHECK" "$project" >/dev/null 2>&1; then
    echo "BUSY     $project  (scheduler job holds its lock — rerun later; nothing touched)"
    busy=$((busy + 1))
    continue
  fi

  block=$(printf '\n%s\n\n<!-- Appended by realisateur/fable-like/inject-suggestions.sh. Full context: fable-like/FABLE_REPORT.md. Triage these like any dated entries; delete freely. -->\n\n%s\n' \
            "$MARKER" "$(suggestions_for "$project")")

  case "$MODE" in
    dry-run)
      echo "would    $project  -> $focus ($(suggestions_for "$project" | grep -c '^-') suggestion(s))"
      ;;
    diff)
      echo "would    $project  -> $focus"
      printf '%s\n' "$block" | sed 's/^/    | /'
      ;;
    apply|commit)
      printf '%s' "$block" >> "$focus"
      echo "wrote    $project  -> $focus"
      changed=$((changed + 1))
      if [ "$MODE" = "commit" ]; then
        repo_dir=$(git -C "$(dirname "$focus")" rev-parse --show-toplevel)
        git -C "$repo_dir" add -- "$focus"
        git -C "$repo_dir" commit -q -m "FOCUS.md: fable-review 2026-07-25 suggestions (via realisateur/fable-like)" -- "$focus"
        echo "commit   $project  ($repo_dir)"
      fi
      ;;
  esac
done <<< "$TARGETS"

echo
echo "mode=$MODE  written=$changed  skipped=$skipped  busy=$busy  missing=$missing"
if [ "$MODE" = "apply" ] && [ "$changed" -gt 0 ]; then
  echo "NOTE: repos now carry uncommitted FOCUS.md changes — commit per-repo soon;"
  echo "      'a dirty tree is a stop, not a thing to edit around'. Or rerun with --commit."
fi
if [ "$busy" -gt 0 ]; then
  echo "NOTE: $busy project(s) were mid-dispatch and untouched — rerun to pick them up."
  exit 1
fi
