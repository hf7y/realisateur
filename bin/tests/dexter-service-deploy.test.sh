#!/usr/bin/env bash
# dexter-service-deploy.test.sh -- does the one-owner refusal actually refuse?
#
# This is the safety-critical line in the whole dexter channel. zaxon's data
# holds a WhatsApp linked-device session; if the container starts while the
# `hermes` distro still runs its own bridge against the same files, WhatsApp
# logs the link out and recovery costs a QR scan on Zach's phone. A refusal
# that only exists in a comment is not a refusal, so it is tested here --
# offline, against a stub `ssh`, before it is ever needed for real.
# HERMETICITY: no network and no dexter -- both `ssh` and `rsync` are stubs on
# PATH that record their calls, which is also how the refusal cases assert that
# nothing was pushed or started. The one temp service dir it creates under
# provision/dexter/ is removed in the same case that makes it.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
DEPLOY="$PWD/dexter-service-deploy.sh"

pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: expected '$3', got '$2'"; fi; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1: output lacks '$3'";; esac; }

STUB="$(mktemp -d)"; trap 'rm -rf "$STUB"' EXIT
# Stub ssh prints the staged distro list. Anything that is NOT the read-only
# distro query is recorded, so the test can assert nothing was mutated.
cat > "$STUB/ssh" <<'EOF'
#!/bin/sh
echo "$*" >> "$STUB_CALLS"
cat "$STUB_REPLY" 2>/dev/null
EOF
# rsync must never run on a refused deploy either -- stub it the same way.
cat > "$STUB/rsync" <<'EOF'
#!/bin/sh
echo "rsync $*" >> "$STUB_CALLS"
EOF
chmod +x "$STUB/ssh" "$STUB/rsync"
export STUB_REPLY="$STUB/reply" STUB_CALLS="$STUB/calls"
export PATH="$STUB:$PATH"

echo "== 1. hermes RUNNING => REFUSE, and touch nothing =========================="
: > "$STUB_CALLS"; printf 'Ubuntu\nhermes\n' > "$STUB_REPLY"
out="$(bash "$DEPLOY" zaxon 2>&1)"; rc=$?
is "exits non-zero" "$rc" "1"
has "names the hazard in the terms that matter" "$out" "logs the link out"
has "and tells the operator the exact next command" "$out" "--terminate hermes"
if grep -q '^rsync ' "$STUB_CALLS" 2>/dev/null; then
  bad "it refused but still pushed files"
else
  ok "no rsync ran"
fi
if grep -q 'compose up' "$STUB_CALLS" 2>/dev/null; then
  bad "it refused but still started containers"
else
  ok "no compose up ran"
fi

echo
echo "== 2. hermes STOPPED => the refusal does not fire =========================="
: > "$STUB_CALLS"; printf 'Ubuntu\n' > "$STUB_REPLY"
out="$(bash "$DEPLOY" zaxon --dry-run 2>&1)"; rc=$?
is "dry-run exits 0 when nothing else owns the session" "$rc" "0"
has "and says where it would go" "$out" "/srv/zaxon/"

echo
echo "== 3. AN UNKNOWN SERVICE IS A USAGE ERROR, NOT A SILENT NO-OP ============="
out="$(bash "$DEPLOY" not-a-service 2>&1)"; rc=$?
is "exits non-zero" "$rc" "1"
has "names what it looked for" "$out" "provision/dexter/not-a-service"

echo
echo "== 4. THE REFUSAL IS SCOPED TO THE SERVICE THAT OWNS A SESSION ============"
# A different service must not inherit zaxon's refusal -- a guard that blocks
# unrelated work gets routed around, and then it protects nothing.
: > "$STUB_CALLS"; printf 'Ubuntu\nhermes\n' > "$STUB_REPLY"
mkdir -p "$PWD/../provision/dexter/_testsvc" && printf 'services: {}\n' > "$PWD/../provision/dexter/_testsvc/compose.yaml"
out="$(bash "$DEPLOY" _testsvc --dry-run 2>&1)"; rc=$?
rm -rf "$PWD/../provision/dexter/_testsvc"
is "an unrelated service deploys while hermes runs" "$rc" "0"
case "$out" in *"logs the link out"*) bad "zaxon's refusal leaked onto another service";; *) ok "no zaxon refusal for a service with no session";; esac

echo
echo "dexter-service-deploy.test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
