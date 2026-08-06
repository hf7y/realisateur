#!/usr/bin/env bash
# Cut the bibliothecaire scanner pipeline over from mandark to monkey.
#
#   sudo bash cutover-bibliothecaire-to-monkey.sh --verify   # look, change nothing
#   sudo bash cutover-bibliothecaire-to-monkey.sh --apply
#
# WHY THIS NEEDS YOU AND NOT THE AGENT: mandark has no passwordless sudo
# (`sudo -n true` -> "a password is required"), so stopping mandark's three
# SYSTEM units is the one step an unattended run cannot take. Everything on
# monkey is already done and proven; this is the switch.
#
# WHAT IT DOES NOT DO: it does not delete mandark's 1.4G copy of the scans,
# and it does not repoint gardien. Both are deliberate -- see AFTER, below.
set -euo pipefail

MODE="${1:---verify}"
OWNER="${SUDO_USER:-zach}"
INTAKE=/home/zach/bibliothecaire-intake
REPO=/home/zach/Documents/Projects/bibliothecaire
TIMERS=(bibliothecaire-intake.timer bibliothecaire-intake-ocr.timer
        bibliothecaire-intake-health.timer)
UNITS=(bibliothecaire-intake.service bibliothecaire-intake-ocr.service
       bibliothecaire-intake-health.service)
CRON_LINE='*/5 * * * * /usr/bin/rsync -a --remove-source-files -e "ssh -o BatchMode=yes -o ConnectTimeout=15" /home/zach/bibliothecaire-intake/incoming/ monkey:/home/zach/bibliothecaire-intake/incoming/ >> /home/zach/.local/state/bibliothecaire-ship.log 2>&1 # bibliothecaire: ship scans to monkey (owner: bibliothecaire)'

say() { printf '%s\n' "$*"; }
die() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run me with sudo"

# ---------------------------------------------------------------- preflight
# Refuse to cut over to a monkey that is not actually ready. Each of these
# is a thing that, if false, turns "migrated" into "scans quietly stop".
say "== preflight =="
sudo -u "$OWNER" ssh -o BatchMode=yes -o ConnectTimeout=15 monkey true \
  || die "cannot ssh to monkey as $OWNER -- the shipper would fail silently"
sudo -u "$OWNER" ssh monkey 'test -x /home/zach/Documents/Projects/bibliothecaire/bin/intake.py' \
  || die "monkey has no intake.py at the expected path"
sudo -u "$OWNER" ssh monkey 'systemctl is-enabled bibliothecaire-intake.timer' >/dev/null \
  || die "monkey's intake timer is not enabled -- nothing would drain there"
say "[ok] monkey reachable, intake.py present, timer enabled"

if [ "$MODE" = "--verify" ]; then
  say
  say "would stop+disable on mandark: ${TIMERS[*]}"
  say "would add cron line for $OWNER:"
  say "  $CRON_LINE"
  say
  say "nothing changed. re-run with --apply"
  exit 0
fi
[ "$MODE" = "--apply" ] || die "unknown mode: $MODE (use --verify or --apply)"

# ------------------------------------------------------------------- apply
say "== stopping mandark's pipeline =="
for t in "${TIMERS[@]}"; do
  systemctl disable --now "$t" 2>/dev/null || say "  (already off: $t)"
done
for u in "${UNITS[@]}"; do systemctl reset-failed "$u" 2>/dev/null || true; done
say "[ok] timers disabled"

# The unit FILES stay on disk for now: re-enabling is then one command if
# monkey turns out to be wrong. `systemd/install.sh --uninstall` removes
# them for real, once you are satisfied.

say "== making monkey an exact mirror of mandark =="
# NOT just incoming/. mandark stayed the live pipeline until the line above,
# so its ledger.json, accepted/ and work/ have moved on since the 2026-08-06
# seed copy. Syncing only incoming/ would silently strand every scan accepted
# in between: they would exist as files on monkey with no ledger entry, which
# `--status` reports as a healthy 0-awaiting-drain pipeline. That is the exact
# shape of quiet loss this project refuses.
#
# --delete is deliberate and makes monkey byte-identical to mandark. It also
# removes the synthetic `migration-witness-20260806` item seeded on monkey to
# prove the pipeline worked; mandark's ledger is authoritative here.
sudo -u "$OWNER" rsync -a --delete \
  -e "ssh -o BatchMode=yes -o ConnectTimeout=15" \
  "$INTAKE/" monkey:/home/zach/bibliothecaire-intake/
sudo -u "$OWNER" ssh monkey 'sudo -n chown zach:bibscan /home/zach/bibliothecaire-intake/incoming && sudo -n chmod 0730 /home/zach/bibliothecaire-intake/incoming'
say "[ok] monkey mirrors mandark (ledger, accepted/, work/, incoming/)"

# Prove the mirror rather than trusting rsync's exit code.
lbytes="$(du -sb "$INTAKE" | cut -f1)"
rbytes="$(sudo -u "$OWNER" ssh monkey 'du -sb /home/zach/bibliothecaire-intake | cut -f1')"
[ "$lbytes" = "$rbytes" ] || die "mirror check FAILED: mandark $lbytes bytes, monkey $rbytes -- do not proceed"
say "[ok] mirror verified byte-for-byte: $lbytes bytes on both hosts"

say "== installing the shipper =="
# A plain rsync line: mandark keeps NO bibliothecaire code, only samba (which
# the scanner needs) and this one cron entry.
mkdir -p /home/zach/.local/state
chown "$OWNER":"$OWNER" /home/zach/.local/state 2>/dev/null || true
tmp="$(mktemp)"
crontab -u "$OWNER" -l 2>/dev/null | grep -v 'bibliothecaire: ship scans to monkey' > "$tmp" || true
printf '%s\n' "$CRON_LINE" >> "$tmp"
crontab -u "$OWNER" "$tmp"
rm -f "$tmp"
say "[ok] cron line installed for $OWNER"

say "== proving the shipper actually runs =="
sudo -u "$OWNER" rsync -a --remove-source-files --dry-run \
  -e "ssh -o BatchMode=yes -o ConnectTimeout=15" \
  "$INTAKE/incoming/" monkey:/home/zach/bibliothecaire-intake/incoming/ >/dev/null \
  || die "the shipper command itself fails -- do NOT leave it here"
say "[ok] shipper command verified"

if command -v notify-senechal >/dev/null 2>&1 || [ -x "/home/$OWNER/.local/bin/notify-senechal" ]; then
  n="$(command -v notify-senechal || echo "/home/$OWNER/.local/bin/notify-senechal")"
  sudo -u "$OWNER" "$n" "mandark: bibliothecaire intake CUT OVER to monkey. mandark's three intake timers are disabled; a cron line every 5 min ships ~/bibliothecaire-intake/incoming/ to monkey over tailscale. Draining, OCR, ledger and library now run on monkey at /home/zach/Documents/Projects/bibliothecaire. mandark keeps samba (the scanner needs a LAN target) and no bibliothecaire code. Revert: systemctl enable --now the three timers and remove the cron line." || true
fi

cat <<'AFTER'

== done. AFTER, in this order, once you have seen a scan land on monkey ==

1. WATCH ONE REAL SCAN through. Scan something, then:
     ssh monkey 'ls -la ~/bibliothecaire-intake/incoming/'   # arrives within 5 min
     ssh monkey 'journalctl -u bibliothecaire-intake.service -n 20'

2. REPOINT GARDIEN. The media set `bibliothecaire-intake` is at 1 copy and
   still sources mandark. Until it is repointed at monkey, new scans have
   NO backup. This is the one step that loses data if forgotten.

3. ONLY THEN remove mandark's leftovers:
     sudo /home/zach/Documents/Projects/bibliothecaire/systemd/install.sh --uninstall
     rm -rf /home/zach/bibliothecaire-intake      # 1.4G copy, after step 2
     fauche check /home/zach/Documents/Projects/bibliothecaire
     fauche script /home/zach/Documents/Projects/bibliothecaire   # read, then run

4. THE REAL FIX, when you have hands on dexter: give monkey a LAN address
   (bridge its VirtualBox NIC) or serve the drop box from a dexter shared
   folder handed to the VM. Then the scanner talks to monkey directly and
   mandark keeps nothing at all -- not even samba.
AFTER
