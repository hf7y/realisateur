#!/usr/bin/env bash
# dexter-liveness.test.sh -- does the probe distinguish DOWN from BLIND?
#
# The distinction is the whole point of the script, so it is the thing worth
# testing: "I could not look" reported as healthy is how ten days of a dead
# relay passed unnoticed. Everything here runs offline against a stub `ssh`
# on PATH -- no dexter, no network, no credential.
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
PROBE="$PWD/dexter-liveness.sh"

is()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: expected '$3', got '$2'"; fi; }

STUB="$(mktemp -d)"; trap 'rm -rf "$STUB"' EXIT
# The stub stands in for `ssh <host> <script>`: it ignores its arguments and
# prints whatever the current case has staged in $STUB/reply.
cat > "$STUB/ssh" <<'EOF'
#!/bin/sh
[ -f "$STUB_REPLY" ] || exit 255
cat "$STUB_REPLY"
EOF
chmod +x "$STUB/ssh"
export STUB_REPLY="$STUB/reply"
export PATH="$STUB:$PATH"

# A host where everything declared is present. WINBOOT is left empty so the
# login-drift arm stays out of this case -- it has its own below.
healthy() {
  cat > "$STUB_REPLY" <<EOF
UPTIME_S=100000
DOCKER=active
CONTAINERS=zaxon-gateway,zaxon-relay,zaxon-watcher,zaxon-whisper,
PORTS=22,2223,8643,8090,
MCP_SERVER=hermes
STT=And so my fellow Americans, ask not what your country can do for you, ask what you can do for your country.
DISTROS=Ubuntu,
VMS=monkey,
WINBOOT=
EOF
}

echo "== 1. A HEALTHY HOST IS QUIET ============================================"
healthy
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 0 when everything declared is up" "$rc" "0"
has "and says so" "$out" "OK"

echo
echo "== 2. A MISSING SERVICE IS A FINDING, NOT A CRASH ========================"
healthy
sed -i 's/^PORTS=.*/PORTS=22,2223,/' "$STUB_REPLY"     # zaxon's port gone
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 5 when a declared port is dark" "$rc" "5"
has "names the port" "$out" "8643"
has "and says what it costs, in human terms" "$out" "carry a question to a human"

echo
echo "== 3. A DOWN VM IS NAMED AS SELF-DEV, NOT AS A VM ========================"
healthy
sed -i 's/^VMS=.*/VMS=/' "$STUB_REPLY"
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 5 when monkey is not running" "$rc" "5"
has "spells out the consequence" "$out" "self-dev dispatch is down"

echo
echo "== 3b. ZAXON IS REPORTED APART FROM MONKEY ==============================="
# zaxon must work without monkey; both are exit 5, so OUTPUT tells them apart.
healthy
sed -i 's/^VMS=.*/VMS=/' "$STUB_REPLY"
out="$(bash "$PROBE" 2>&1)"
has "monkey down is named as the VM" "$out" "MONKEY (self-dev VM): DOWN"
has "and the human channel is still called OK" "$out" "ZAXON (human channel): OK"

healthy
sed -i 's/^MCP_SERVER=.*//' "$STUB_REPLY"          # socket open, relay mute
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 5 when the MCP layer does not answer" "$rc" "5"
has "an open socket is not liveness" "$out" "no serverInfo"
has "zaxon is DOWN" "$out" "ZAXON (human channel): DOWN"
has "while the VM is not blamed for it" "$out" "MONKEY (self-dev VM): OK"

healthy
sed -i 's/^CONTAINERS=.*/CONTAINERS=zaxon-gateway,zaxon-watcher,/' "$STUB_REPLY"
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 5 when a declared container is gone" "$rc" "5"
has "names it" "$out" "zaxon-relay"

echo
echo "== 3c. STT IS ASSERTED BY ITS WORDS, NOT BY ITS PORT ====================="
# docker-proxy keeps 8090 LISTEN for the gateway, so a port check would not have
# caught the three weeks. These cases drive the TRANSCRIPT, ports left healthy.
healthy
sed -i 's/^STT=.*/STT=STT command failed (rc=7): no stderr/' "$STUB_REPLY"
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 5 when the sample does not transcribe" "$rc" "5"
has "quotes what came back instead" "$out" "rc=7"
has "STT is DOWN" "$out" "STT   (voice notes):   DOWN"
has "while the human channel is NOT blamed" "$out" "ZAXON (human channel): OK"

healthy
sed -i 's/^STT=.*/STT=and so my fellow americans/' "$STUB_REPLY"
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 5 when the transcript is wrong, not merely absent" "$rc" "5"
has "names the phrase it wanted" "$out" "ask not what your country can do for you"

healthy
sed -i 's/^STT=.*/STT=/' "$STUB_REPLY"
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 5 when the self-test could not be run at all" "$rc" "5"
has "and says it returned nothing" "$out" "returned nothing"

healthy
sed -i 's/^CONTAINERS=.*/CONTAINERS=zaxon-gateway,zaxon-relay,zaxon-watcher,/' "$STUB_REPLY"
out="$(bash "$PROBE" 2>&1)"
has "a missing whisper container is STT's finding" "$out" "zaxon-whisper"
has "and lands on the STT verdict, not zaxon's" "$out" "ZAXON (human channel): OK"

echo
echo "== 4. BLIND IS NOT 'HEALTHY', AND NOT 'DOWN' ============================="
rm -f "$STUB_REPLY"                                     # stub ssh exits 255
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 6 when the host cannot be reached" "$rc" "6"
has "says BLIND out loud" "$out" "BLIND"
has "and refuses to be read as healthy" "$out" "not 'healthy'"

echo
echo "== 5. THE LOGIN-SCOPED AUTOSTART TRAP ===================================="
# The check that would have caught the ten days: Windows booted long before the
# distro came up, i.e. the machine rebooted and nobody logged in.
healthy
# REPLACE the WINBOOT line rather than appending one: the probe reads the
# FIRST match per key, so an appended duplicate is silently ignored -- which is
# what this test caught about itself on first run.
{ sed -i 's/^UPTIME_S=.*/UPTIME_S=60/' "$STUB_REPLY"
  sed -i "s|^WINBOOT=.*|WINBOOT=$(date -u -d '10 days ago' +%Y-%m-%dT%H:%M:%SZ)|" "$STUB_REPLY"; }
out="$(bash "$PROBE" 2>&1)"
has "notices the distro started long after Windows booted" "$out" "autostart is login-scoped"

echo
echo "== 5b. A DECLARED PAUSE IS NOT THE OUTAGE THIS PROBE EXISTS FOR (#704) ===="
healthy
sed -i 's/^VMS=.*/VMS=/' "$STUB_REPLY"
{ printf 'PAUSE_MONKEY=until=2999-01-01T00:00:00Z;declared_at=2026-08-29T00:00:00Z;\n'; } >> "$STUB_REPLY"
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 0 inside a declared pause window -- not the failure exit 5" "$rc" "0"
has "the VM line says PAUSED, not DOWN" "$out" "MONKEY (self-dev VM): PAUSED"
has "the finding names the declared resume time" "$out" "resumes 2999-01-01T00:00:00Z"

healthy
sed -i 's/^VMS=.*/VMS=/' "$STUB_REPLY"
{ printf 'PAUSE_MONKEY=until=2020-01-01T00:00:00Z;declared_at=2019-01-01T00:00:00Z;\n'; } >> "$STUB_REPLY"
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 5 once the pause is EXPIRED with no resume yet triggered" "$rc" "5"
has "still named as the VM being down" "$out" "MONKEY (self-dev VM): DOWN"

healthy
sed -i 's/^VMS=.*/VMS=/' "$STUB_REPLY"
{ printf 'PAUSE_MONKEY=until=2020-01-01T00:00:00Z;resumed_at=%s;\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"; } >> "$STUB_REPLY"
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 0 while inside the post-expiry boot grace window" "$rc" "0"
has "reads as PAUSED, waiting for boot -- not a fresh outage" "$out" "waiting for boot"

healthy
sed -i 's/^VMS=.*/VMS=/' "$STUB_REPLY"
{ printf 'PAUSE_MONKEY=until=2020-01-01T00:00:00Z;resumed_at=2020-01-01T01:00:00Z;\n'; } >> "$STUB_REPLY"
out="$(bash "$PROBE" 2>&1)"; rc=$?
is "exit 5 once the boot grace window itself is exhausted -- the loud case" "$rc" "5"
has "the resume actuator failing is still named as the VM down" "$out" "MONKEY (self-dev VM): DOWN"

echo
echo "== 6. --json IS PARSEABLE ================================================"
healthy
out="$(bash "$PROBE" --json 2>&1)"
if printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["status"]=="OK" else 1)' 2>/dev/null; then
  ok "--json emits one valid object with a status"
else
  bad "--json did not parse as JSON with a status: $out"
fi
healthy
out="$(bash "$PROBE" --json 2>&1)"
if printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["zaxon"]=="OK" and d["stt"]=="OK" and d["selfdev_vm"]=="OK" and d["mcp_server"]=="hermes" else 1)' 2>/dev/null; then
  ok "--json carries the three verdicts separately"
else
  bad "--json lacks independent zaxon/stt/selfdev_vm verdicts: $out"
fi
healthy
out="$(bash "$PROBE" --json 2>&1)"
if printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if "ask not what your country" in d["transcript"] else 1)' 2>/dev/null; then
  ok "--json carries the transcript itself, so a reader can judge it too"
else
  bad "--json lacks the transcript: $out"
fi
rm -f "$STUB_REPLY"
out="$(bash "$PROBE" --json 2>&1)"
if printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["status"]=="BLIND" else 1)' 2>/dev/null; then
  ok "and BLIND is a status in the document, not an empty one"
else
  bad "--json BLIND did not parse: $out"
fi

echo
summary
