#!/usr/bin/env bash
# decide.sh -- the options this research pass produced, each runnable on its
# own, each DRY-RUN BY DEFAULT. Nothing here fires unless you pass --commit.
#
# These are deliberately separate, single-purpose, and independently
# revertible. Judgement is yours; the mechanism is mine. Run:
#
#   decide.sh                 list the options with current live state
#   decide.sh <id>            show exactly what that option would do
#   decide.sh <id> --commit   do it
#
# Every option prints its own revert line before acting. Options that touch
# machine-wide config say so and run notify-senechal, per CLAUDE.md.
set -uo pipefail

SVC=svc-vaporwave
SCHED="/home/zach/Documents/Project Archive/scheduler"
STAGING="/home/zach/Documents/Projects/realisateur-staging-silence-audit"

ID="${1:-}"; MODE="${2:---dry-run}"
commit() { [ "$MODE" = "--commit" ]; }
say()    { printf '  %s\n' "$*"; }
head_()  { printf '\n=== %s ===\n' "$*"; }
would()  { if commit; then printf '  RUN : %s\n' "$*"; else printf '  WOULD: %s\n' "$*"; fi; }

# ---------------------------------------------------------------- listing
if [ -z "$ID" ]; then
  cat <<'EOF'
OPTIONS -- each independent, each dry-run by default.

  1  renew-vkv        Renew vkv-inventory's expired dead-man switch so its
                      04:00 batch job runs again. (Expired 2026-07-27 20:51.)
                      REVERSIBLE: it re-expires in 7 days on its own.

  2  retire-orphans   Remove svc-vaporwave's orphaned crt / nine-speakers
                      wrappers + state dirs, referenced by no crontab.
                      Archives them first; nothing is destroyed.

  3  cron-logging     Re-enable cron logging in rsyslog so a job that never
                      starts leaves a trace. MACHINE-WIDE: notifies senechal.
                      This is the single highest-leverage silence fix.

  4  latest-symlinks  Normalise LATEST.md to a symlink everywhere, so a
                      stale report is visibly stale. (nine-speakers' is a
                      byte-copy of a 7-day-old file and looks current.)

  5  silence-audit    Install the staged silence-audit + retire the three
                      prose checklist rows it mechanizes. Net -35 lines.

  6  aedile-deadman   Give aedile the dead-man switch it has never had --
                      the only job that auto-pushes to a repo co-owned with
                      another human, and the only one with no expiry.

  7  status-blind     Make `scheduler status` report BLIND for projects it
                      cannot read, instead of printing another account's
                      state as if it were theirs. (The narrow, safe half of
                      the cross-account fix -- no behaviour change, only an
                      honest symbol. This is the study's own recommendation.)

Run `decide.sh <id>` to see exactly what it would do.
EOF
  head_ "current live state (re-probed, not quoted)"
  if sudo -n -u "$SVC" test -f "/home/$SVC/.local/share/vkv-inventory-nightly-batch/expires_at" 2>/dev/null; then
    say "vkv expires_at : PRESENT -> $(sudo -n -u "$SVC" cat /home/$SVC/.local/share/vkv-inventory-nightly-batch/expires_at 2>/dev/null)"
  else
    say "vkv expires_at : absent (renewed, or never stamped)"
  fi
  say "cron logging   : $(grep -qE '^\s*cron\.\*' /etc/rsyslog.d/50-default.conf 2>/dev/null && echo ENABLED || echo DISABLED)"
  say "silence-audit  : $( [ -e "$HOME/.local/bin/silence-audit" ] && echo installed || echo 'staged only (not live)')"
  exit 0
fi

case "$ID" in
# ------------------------------------------------------------------ 1
1|renew-vkv)
  head_ "renew vkv-inventory dead-man switch"
  say "WHY  : expired 2026-07-27T20:51; the 04:00 job does no work until renewed."
  say "HOW  : remove expires_at; the next run re-stamps now+7d."
  say "REVERT: nothing to revert -- it re-expires in 7 days by itself."
  would "sudo -u $SVC rm /home/$SVC/.local/share/vkv-inventory-nightly-batch/expires_at"
  commit && sudo -u "$SVC" rm -f "/home/$SVC/.local/share/vkv-inventory-nightly-batch/expires_at" \
         && say "done."
  ;;

# ------------------------------------------------------------------ 2
2|retire-orphans)
  head_ "retire orphaned svc-vaporwave job footprint"
  say "WHY  : crt- and nine-speakers- wrappers + state dirs exist under $SVC"
  say "       but are referenced by NO crontab on either account. Pattern 6,"
  say "       on a shared ACCOUNT rather than a shared host."
  ARCH="/home/$SVC/archive-$(date +%F)"
  say "REVERT: everything is moved to $ARCH, not deleted."
  for f in crt-nightly-batch-loop.sh nine-speakers-nightly-batch-loop.sh; do
    would "mv /home/$SVC/bin/$f -> $ARCH/"
  done
  for d in crt-nightly-batch nine-speakers-nightly-batch; do
    would "mv /home/$SVC/.local/share/$d -> $ARCH/"
  done
  if commit; then
    sudo -u "$SVC" mkdir -p "$ARCH"
    for f in crt-nightly-batch-loop.sh nine-speakers-nightly-batch-loop.sh; do
      sudo -u "$SVC" mv -n "/home/$SVC/bin/$f" "$ARCH/" 2>/dev/null
    done
    for d in crt-nightly-batch nine-speakers-nightly-batch; do
      sudo -u "$SVC" mv -n "/home/$SVC/.local/share/$d" "$ARCH/" 2>/dev/null
    done
    say "archived to $ARCH"
    command -v notify-senechal >/dev/null && \
      notify-senechal "retired orphaned crt/nine-speakers job footprint under $SVC; archived to $ARCH (realisateur, /ideate 2026-07-28)"
  fi
  ;;

# ------------------------------------------------------------------ 3
3|cron-logging)
  head_ "re-enable cron logging (MACHINE-WIDE)"
  say "WHY  : '#cron.*' is commented in /etc/rsyslog.d/50-default.conf and"
  say "       journalctl -t CRON is empty, so NOTHING independently witnesses"
  say "       that a job ran. Every 'last run' figure is self-reported by the"
  say "       actor. This is the deepest silence in the ecosystem."
  say "REVERT: sudo sed -i 's|^cron\\.\\*|#cron.*|' /etc/rsyslog.d/50-default.conf"
  say "        && sudo systemctl restart rsyslog"
  would "sudo sed -i 's|^#cron\\.\\*|cron.*|' /etc/rsyslog.d/50-default.conf"
  would "sudo systemctl restart rsyslog"
  would "notify-senechal '<cron logging re-enabled on mandark>'"
  if commit; then
    sudo sed -i 's|^#cron\.\*|cron.*|' /etc/rsyslog.d/50-default.conf && \
    sudo systemctl restart rsyslog && say "rsyslog restarted; cron now logs to /var/log/cron.log"
    command -v notify-senechal >/dev/null && \
      notify-senechal "cron logging re-enabled on mandark (/etc/rsyslog.d/50-default.conf, cron.* -> /var/log/cron.log). Owner: realisateur /ideate 2026-07-28. Reason: no independent witness existed that any scheduled job ran."
  fi
  ;;

# ------------------------------------------------------------------ 4
4|latest-symlinks)
  head_ "normalise LATEST.md to symlinks"
  say "WHY  : three conventions across four projects. A COPY cannot look"
  say "       stale: nine-speakers' LATEST.md is a byte-identical copy of"
  say "       2026-07-21 and reads as current."
  say "REVERT: cp the dated file back over the symlink."
  for d in /srv/vaporwave-reports/*/; do
    p="$(basename "$d")"; L="$d/LATEST.md"
    [ -e "$L" ] || continue
    if [ -L "$L" ]; then say "$p: already a symlink -- skip"; continue; fi
    newest="$(ls -1 "$d" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}.*\.md$' | sort | tail -1)"
    [ -n "$newest" ] || { say "$p: no dated report -- SKIP (would be BLIND)"; continue; }
    would "$p: LATEST.md -> $newest"
    commit && ln -sfn "$newest" "$L" && say "  linked."
  done
  ;;

# ------------------------------------------------------------------ 5
5|silence-audit)
  head_ "install staged silence-audit + retire three prose rows"
  say "WHY  : mechanizes 'silencing stderr', 'Wired to a real path', and"
  say "       'names what it retires'. Dry run: -53 rows, +18 pointers."
  say "REVERT: git -C <each repo> checkout CLAUDE.md; rm ~/.local/bin/silence-audit"
  say "        git -C $STAGING checkout . "
  if [ ! -d "$STAGING" ]; then say "STAGING WORKTREE MISSING at $STAGING -- BLIND, refusing."; exit 3; fi
  would "bash $STAGING/bin/install-silence-audit.sh --commit"
  commit && SILENCE_AUDIT_REPO="$STAGING" bash "$STAGING/bin/install-silence-audit.sh" --commit
  ;;

# ------------------------------------------------------------------ 6
6|aedile-deadman)
  head_ "give aedile a dead-man switch"
  say "WHY  : aedile is the ONLY job that auto-pushes to a repo co-owned with"
  say "       another human, and the ONLY one with no expires_at, because it"
  say "       is bespoke rather than sourcing lib/sweep-loop-common.sh."
  say "NOTE : this is a real code change to $SVC's wrapper, not a toggle."
  say "       It is printed, NOT applied, because editing a service account's"
  say "       live job from an audit is exactly the class of write this"
  say "       ecosystem keeps getting burned by. Apply it deliberately."
  cat <<'PATCH'

  Add near the top of ~svc-vaporwave/bin/aedile-nightly-batch-loop.sh,
  after STATE_DIR is defined:

    EXPIRES_AT_FILE="$STATE_DIR/expires_at"
    EXPIRY_DAYS="${EXPIRY_DAYS:-7}"
    if [ -f "$EXPIRES_AT_FILE" ]; then
      if [ "$(date +%s)" -ge "$(date -d "$(cat "$EXPIRES_AT_FILE")" +%s)" ]; then
        echo "expired -- dead-man switch tripped; no work attempted."
        echo "=== skipped (expired $(cat "$EXPIRES_AT_FILE")) $(date -Is) ==="
        exit 3
      fi
    else
      date -d "+${EXPIRY_DAYS} days" -Is > "$EXPIRES_AT_FILE"
    fi
PATCH
  ;;

# ------------------------------------------------------------------ 7
7|status-blind)
  head_ "make scheduler status report BLIND instead of another account's state"
  say "WHY  : bin/scheduler resolves run state against \$HOME, so it reports"
  say "       aedile as never-run and vkv-inventory as FAILED 2026-07-20,"
  say "       while both have succeeded nightly under $SVC through 07-27."
  say "       This is the study's own recommendation: the safe half is not"
  say "       'read the other account' but 'stop claiming to have read it'."
  say "NOTE : scheduler owns its own engine. This option does NOT patch it."
  say "       It files the proposal through scheduler's front door, which is"
  say "       the sanctioned path (already filed once tonight as 523ee65)."
  would "scheduler -i scheduler '<BLIND-symbol proposal + sim evidence>'"
  if commit; then
    "$SCHED/bin/scheduler" -i scheduler "SIM EVIDENCE for the cross-account status bug already filed as 523ee65. A toy cybernetic model of this ecosystem (realisateur branch research/ecosystem-cybernetics) was run across 11 arms, 60 seeds and 10 disturbance regimes. Result: adding a BLIND output symbol to a single sensor cut unregulated-disturbance ticks by ~88 percent versus the current two-symbol baseline, and the effect survived a hostile parameterisation where a BLIND report only leads to a structural fix 20 percent of the time. Adding MORE sensors while they share the same \$HOME-scoped blind spot produced a byte-identical result to the baseline -- literally zero improvement -- which is the modelled form of why sensor reconciliation cannot fix a correlated blind spot. The minimal, behaviour-preserving change is therefore NOT to make status read the other account, but to stop it asserting a negative over a domain it never read: when a project's conf sets CRON_ACCOUNT to another user and that account's state is unreadable, print BLIND naming the domain, never the local \$HOME path's state."
  fi
  ;;

*) echo "unknown option: $ID  (run with no args to list)"; exit 2 ;;
esac

commit || printf '\n(dry run -- nothing changed. add --commit to apply.)\n'
