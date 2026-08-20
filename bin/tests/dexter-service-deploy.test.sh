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
# Stub ssh: the distro-list query gets $STUB_REPLY; a holder probe succeeds
# only for the distro named in $STUB_HOLDER.
cat > "$STUB/ssh" <<'EOF'
#!/bin/sh
echo "$*" >> "$STUB_CALLS"
case "$*" in
  *"wsl.exe -l -q --running"*) cat "$STUB_REPLY" 2>/dev/null; exit 0 ;;
  *"wsl.exe -d "*)
    holder="$(cat "$STUB_HOLDER" 2>/dev/null)"
    case "$*" in *"-d \"$holder\""*) [ -n "$holder" ] && exit 0; exit 1 ;; *) exit 1 ;; esac ;;
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
export STUB_REPLY="$STUB/reply" STUB_CALLS="$STUB/calls" STUB_HOLDER="$STUB/holder"
# A fixture service, so this suite needs no project's real files: zaxon's
# container lives in hf7y/crt now (crt owns it), which may not be cloned here.
mkdir -p "$STUB/svc/zaxon" && printf 'services: {}\n' > "$STUB/svc/zaxon/compose.yaml"
export DEXTER_SERVICE_PATH="$STUB/svc"
export PATH="$STUB:$PATH"

echo "== 1. hermes HOLDS THE SESSION => REFUSE, and touch nothing ================"
: > "$STUB_CALLS"; printf 'Ubuntu\nhermes\n' > "$STUB_REPLY"; printf 'hermes' > "$STUB_HOLDER"
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
echo "== 1b. UBUNTU HOLDS THE SESSION, HERMES STOPPED => STILL REFUSE ============"
: > "$STUB_CALLS"; printf 'Ubuntu\n' > "$STUB_REPLY"; printf 'Ubuntu' > "$STUB_HOLDER"
out="$(bash "$DEPLOY" zaxon 2>&1)"; rc=$?
is "exits non-zero even though hermes never ran" "$rc" "1"
has "names the distro that actually holds it" "$out" "'Ubuntu' distro"

echo
echo "== 2. NOTHING HOLDS THE SESSION => the refusal does not fire ==============="
: > "$STUB_CALLS"; printf 'Ubuntu\n' > "$STUB_REPLY"; : > "$STUB_HOLDER"
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
