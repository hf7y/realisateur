#!/usr/bin/env bash
# dexter-service-deploy.test.sh -- does the one-owner refusal actually refuse?
#
# This is the safety-critical line in the whole dexter channel. zaxon's data
# holds a WhatsApp linked-device session; if the container starts while the
# `hermes` distro still runs its own bridge against the same files, WhatsApp
# logs the link out and recovery costs a QR scan on Zach's phone. A refusal
# that only exists in a comment is not a refusal, so it is tested here --
# offline, against a stub `ssh`, before it is ever needed for real.
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
DEPLOY="$PWD/dexter-service-deploy.sh"

is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: expected '$3', got '$2'"; fi; }

STUB="$(mktemp -d)"; trap 'rm -rf "$STUB"' EXIT
# Stub ssh answers per-probe: the session-holder query from $STUB_HOLDERS, the
# distro query from $STUB_REPLY. Every call is recorded, so the test can assert
# nothing was mutated. SSH_BLIND=1 makes the holder probe fail to run at all.
cat > "$STUB/ssh" <<'EOF'
#!/bin/sh
echo "$*" >> "$STUB_CALLS"
case "$*" in
  *pgrep*)
    [ -n "${SSH_BLIND:-}" ] && exit 9
    cat "$STUB_HOLDERS" 2>/dev/null
    echo PROBE-OK ;;
  *) cat "$STUB_REPLY" 2>/dev/null ;;
esac
EOF
# rsync must never run on a refused deploy either -- stub it the same way.
cat > "$STUB/rsync" <<'EOF'
#!/bin/sh
echo "rsync $*" >> "$STUB_CALLS"
EOF
# A fake gh, so the clone-free path is exercised offline. It answers the deploy's
# two calls -- a recursive tree, then a blob -- for hf7y/crt, which really owns
# zaxon. GH_BLIND=1 fails every call: unreadable, as opposed to empty.
cat > "$STUB/gh" <<'EOF'
#!/bin/sh
echo "gh $*" >> "$STUB_CALLS"
[ -n "${GH_BLIND:-}" ] && exit 1
case "$*" in
  *"repos/hf7y/crt/git/trees"*)  printf '100644 provision/dexter/zaxon/compose.yaml\n100755 provision/dexter/zaxon/relay.sh\n' ;;
  *git/trees*)                   printf '100644 README.md\n' ;;
  *contents/provision/dexter/zaxon/compose.yaml*) printf 'services: {}\n' | base64 | tr -d '\n' ;;
  *contents/provision/dexter/zaxon/relay.sh*)     printf '#!/bin/sh\n'     | base64 | tr -d '\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$STUB/ssh" "$STUB/rsync" "$STUB/gh"
export STUB_REPLY="$STUB/reply" STUB_CALLS="$STUB/calls" STUB_HOLDERS="$STUB/holders"
: > "$STUB_HOLDERS"
# A fixture service, so this suite needs no project's real files: zaxon's
# container lives in hf7y/crt now (crt owns it), which may not be cloned here.
mkdir -p "$STUB/svc/zaxon" && printf 'services: {}\n' > "$STUB/svc/zaxon/compose.yaml"
export DEXTER_SERVICE_PATH="$STUB/svc"
export PATH="$STUB:$PATH"

echo "== 0. THE SESSION HAS A HOLDER => REFUSE, whatever the distro list says ==="
# The incident this closes: zaxon runs as bare processes in Ubuntu and holds
# the session while `hermes` reads Stopped. The old guard passed and would have
# started a second holder, reporting success.
: > "$STUB_CALLS"; printf 'Ubuntu\n' > "$STUB_REPLY"
printf '4711 node /srv/zaxon/bridge.js --session %s --mode bot\n' \
  /home/zaxon/.hermes/whatsapp/session > "$STUB_HOLDERS"  # hardcoded-home-ok: fixture of a dexter path
out="$(bash "$DEPLOY" zaxon 2>&1)"; rc=$?
is "exits non-zero although hermes is Stopped" "$rc" "1"
has "names the session, not the distro" "$out" "ALREADY HAS A HOLDER"
has "and names the process holding it" "$out" "4711"
if grep -q '^rsync ' "$STUB_CALLS" 2>/dev/null; then bad "it refused but still pushed files"; else ok "no rsync ran"; fi

echo
echo "== 0b. THE PROBE ITSELF MUST NOT MATCH => no self-match, no false holder ==="
# `pgrep -f` sees its own command line. The bracket in [-]-session is what stops
# the probe reporting the state it was testing for, forever.
grep -q '\[-\]-session' "$DEPLOY" && ok "the probe pattern cannot match itself" \
  || bad "the probe pattern would match its own command line"

echo
echo "== 0c. THE PROBE CANNOT RUN => BLIND (6), never 'no holder' ==============="
: > "$STUB_CALLS"; : > "$STUB_HOLDERS"; printf 'Ubuntu\n' > "$STUB_REPLY"
out="$(SSH_BLIND=1 bash "$DEPLOY" zaxon --dry-run 2>&1)"; rc=$?
is "exits BLIND on the estate's ladder" "$rc" "6"
has "and says an unrunnable probe is not an absence" "$out" "not an absence of holders"
if grep -q '^rsync ' "$STUB_CALLS" 2>/dev/null; then bad "it went blind but still pushed files"; else ok "no rsync ran"; fi

echo
echo "== 1. hermes RUNNING => REFUSE, and touch nothing =========================="
: > "$STUB_CALLS"; : > "$STUB_HOLDERS"; printf 'Ubuntu\nhermes\n' > "$STUB_REPLY"
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
has "names where it looked" "$out" "provision/dexter/"

echo
echo "== 4. THE REFUSAL IS SCOPED TO THE SERVICE THAT OWNS A SESSION ============"
# A different service must not inherit zaxon's refusal -- a guard that blocks
# unrelated work gets routed around, and then it protects nothing.
: > "$STUB_CALLS"; printf 'Ubuntu\nhermes\n' > "$STUB_REPLY"
mkdir -p "$STUB/svc/_testsvc" && printf 'services: {}\n' > "$STUB/svc/_testsvc/compose.yaml"
out="$(bash "$DEPLOY" _testsvc --dry-run 2>&1)"; rc=$?
is "an unrelated service deploys while hermes runs" "$rc" "0"
case "$out" in *"logs the link out"*) bad "zaxon's refusal leaked onto another service";; *) ok "no zaxon refusal for a service with no session";; esac

echo
echo "== 5. NO CLONE ANYWHERE => READ THE OWNER'S REPO LIVE ====================="
# dexter holds no checkouts: with the search roots emptied, only GitHub is left.
: > "$STUB_CALLS"; printf 'Ubuntu\n' > "$STUB_REPLY"
mkdir -p "$STUB/home"
out="$(env -u DEXTER_SERVICE_PATH HOME="$STUB/home" bash "$DEPLOY" zaxon --dry-run 2>&1)"; rc=$?
is "a clone-free dry-run succeeds" "$rc" "0"
has "it asked the owning repo for the tree" "$(cat "$STUB_CALLS")" "repos/hf7y/crt/git/trees"
has "and it would still push to /srv" "$out" "/srv/zaxon/"

echo
echo "== 6. GITHUB UNREADABLE => BLIND (6), NEVER 'no such service' ============="
: > "$STUB_CALLS"
out="$(env -u DEXTER_SERVICE_PATH HOME="$STUB/home" GH_BLIND=1 bash "$DEPLOY" zaxon --dry-run 2>&1)"; rc=$?
is "exits BLIND on the estate's ladder" "$rc" "6"
has "and says so in those terms" "$out" "BLIND"
if grep -q '^rsync ' "$STUB_CALLS" 2>/dev/null; then bad "it went blind but still pushed files"; else ok "no rsync ran"; fi

echo
summary
