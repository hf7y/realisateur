#!/usr/bin/env bash
# vault-spool-drain.test.sh -- witness for bin/vault-spool-drain.sh (#742).
#
# THE ONE PROPERTY THAT MATTERS: a request is never lost. A drain that removed
# a request it had not deposited would turn `consigne`'s "SPOOLED" into a lie,
# and the caller who then deleted the source would have destroyed the only
# copy -- the exact failure senechal's tools/vault.sh header names as the one
# bug it must not have.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/vault-spool-drain.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp
echo "vault-spool-drain.test.sh"

section "A. the argument contract"
"$SCRIPT" --not-a-real-flag >/dev/null 2>&1; eq "A1 unknown flag exits 2" "$?" "2"
"$SCRIPT" --help >/dev/null 2>&1;            eq "A2 --help exits 0" "$?" "0"
OUT="$("$SCRIPT" --help 2>&1)"
has "A3 --help documents the BLIND exit" "$OUT" "BLIND"

section "B. a missing spool is BLIND, never 'nothing queued'"
OUT="$("$SCRIPT" --check --spool "$T/no-such-spool" 2>&1)"; RC=$?
eq  "B1 exits 6" "$RC" "6"
has "B2 and says BLIND" "$OUT" "BLIND"
has "B3 and says an unmeasured queue is not an empty one" "$OUT" "NOT the same as empty"

section "C. an empty spool is a clean 0"
mkdir -p "$T/spool"
OUT="$("$SCRIPT" --check --spool "$T/spool" 2>&1)"; RC=$?
eq  "C1 exits 0" "$RC" "0"
has "C2 and says so" "$OUT" "nothing queued"

section "D. --check reports the queue and writes nothing"
printf 'account\tacct-a\nrequested\t2026-08-30T00:00:00Z\npath\t%s/DOC.md\n' "$T" > "$T/spool/req-acct-a.aaaaaaaa"
OUT="$("$SCRIPT" --check --spool "$T/spool" 2>&1)"; RC=$?
eq  "D1 a queued request is a finding (exit 1)" "$RC" "1"
has "D2 the account is named" "$OUT" "acct-a"
has "D3 the count is named"   "$OUT" "1 request(s) queued"
eq  "D4 --check removed nothing" "$(find "$T/spool" -type f | wc -l | tr -d ' ')" "1"

section "E. --apply deposits through the real impl and clears the queue"
# A stand-in for lib/consign-prose.sh that records its argv. The deposit
# mechanism is bibliothecaire's and is deliberately NOT reimplemented here --
# what this asserts is the handoff: same vault, same paths, unchanged.
mkdir -p "$T/vault"; git -C "$T/vault" init -q 2>/dev/null
printf 'x\n' > "$T/DOC.md"
cat > "$T/impl.sh" <<'IMPL'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ARGV_LOG"
exit "${IMPL_RC:-0}"
IMPL
chmod +x "$T/impl.sh"
export ARGV_LOG="$T/argv.log"

OUT="$(CONSIGNE_IMPL="$T/impl.sh" "$SCRIPT" --apply --spool "$T/spool" --vault "$T/vault" 2>&1)"; RC=$?
eq  "E1 a deposited queue exits 0" "$RC" "0"
has "E2 the impl was handed the vault and the path" "$(cat "$ARGV_LOG")" "$T/vault $T/DOC.md"
eq  "E3 the request is gone once its deposit landed" "$(find "$T/spool" -maxdepth 1 -name 'req-*' | wc -l | tr -d ' ')" "0"

section "F. a failed deposit KEEPS the request -- the queue is not a leak"
printf 'account\tacct-b\npath\t%s/DOC.md\n' "$T" > "$T/spool/req-acct-b.bbbbbbbb"
OUT="$(CONSIGNE_IMPL="$T/impl.sh" IMPL_RC=7 "$SCRIPT" --apply --spool "$T/spool" --vault "$T/vault" 2>&1)"; RC=$?
eq  "F1 exits 1" "$RC" "1"
eq  "F2 the request is kept, renamed .failed" "$(find "$T/spool" -maxdepth 1 -name 'req-*.failed' | wc -l | tr -d ' ')" "1"
has "F3 the reason is recorded" "$(cat "$T/spool/req-acct-b.bbbbbbbb.failed.why" 2>/dev/null)" "exit 7"
has "F4 and the run says which one failed" "$OUT" "acct-b"

section "G. a request with no paths is not silently dropped"
printf 'account\tacct-c\n' > "$T/spool/req-acct-c.cccccccc"
OUT="$(CONSIGNE_IMPL="$T/impl.sh" "$SCRIPT" --apply --spool "$T/spool" --vault "$T/vault" 2>&1)"; RC=$?
eq  "G1 exits 1" "$RC" "1"
eq  "G2 kept as .failed" "$(find "$T/spool" -maxdepth 1 -name 'req-acct-c*.failed' | wc -l | tr -d ' ')" "1"

section "H. --apply refuses a vault it cannot read, rather than emptying the queue"
if [ "$(id -u)" -eq 0 ]; then
  ok "H1 skipped: running as root"
else
  mkdir -p "$T/spool2" "$T/shut"; chmod 0000 "$T/shut"
  printf 'account\tacct-d\npath\t%s/DOC.md\n' "$T" > "$T/spool2/req-acct-d.dddddddd"
  OUT="$(CONSIGNE_IMPL="$T/impl.sh" "$SCRIPT" --apply --spool "$T/spool2" --vault "$T/shut" 2>&1)"; RC=$?
  eq "H1 exits 5 (refused)" "$RC" "5"
  eq "H2 and the request is still queued" "$(find "$T/spool2" -maxdepth 1 -name 'req-*' | wc -l | tr -d ' ')" "1"
  chmod 0755 "$T/shut"
fi

section "I. it is declared, so it reaches a host by a named channel"
. "$ROOT/lib/propagation-set.sh"
ch="$(prop_channel vault-spool-drain.sh 2>/dev/null)" || ch=""
eq "I1 prop_channel says local -- it runs on a clock, on the host" "$ch" "local"
has "I2 prop_host_tools carries it, or the cron row points at nothing" "$(prop_host_tools)" "vault-spool-drain.sh"
has "I3 carries.tsv rides it into the build, so the 05:53 tick refreshes it" \
    "$(cat "$ROOT/lib/carries.tsv")" "libexec/vault-spool-drain.sh"

section "J. it does not reimplement the deposit"
hasnt "J1 no sha256 read-back gate copied out of consign-prose" "$(cat "$SCRIPT")" "sha256sum"
grep -q 'rm -rf' "$SCRIPT" && bad "J2 the script contains an rm -rf" || ok "J2 no rm -rf anywhere in the script"

echo
summary
