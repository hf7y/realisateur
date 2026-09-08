#!/usr/bin/env bash
set -uo pipefail  # HERMETICITY: fixture passwd file, fixture crontab shim, SUDO empty
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/selfdev-libexec-probe.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp

echo "selfdev-libexec-probe.test.sh"

mkpasswd() {
  cat > "$T/passwd" <<'EOF'
root:x:0:0::/root:/bin/bash
zach:x:1000:1000::/home/zach:/bin/bash
ecosim:x:3011:3011::/home/ecosim:/bin/bash
dcp-gate-site:x:3015:3015::/home/dcp-gate-site:/bin/bash
wtul:x:3006:3006::/home/wtul:/bin/bash
nobody:x:65534:65534::/nonexistent:/usr/sbin/nologin
EOF
}

mkcrontabbin() {
  mkdir -p "$T/stub"
  cat > "$T/stub/crontab" <<'SHIM'
#!/usr/bin/env bash
u=""
while [ $# -gt 0 ]; do
  case "$1" in
    -l) ;;
    -u) shift; u="$1" ;;
  esac
  shift
done
f="$CRONTAB_FIXTURE_DIR/${u:-_self}"
if [ -f "$f" ]; then cat "$f"; exit 0; fi
echo "no crontab for ${u:-$(id -un)}" >&2
exit 1
SHIM
  chmod +x "$T/stub/crontab"
}
mkpasswd
mkcrontabbin
mkdir -p "$T/cronfix"

run() {  # run [args...] -- uid band + fixture crontab, no real account touched
  SELFDEV_PASSWD="$T/passwd" SELFDEV_HOME_ROOT="$T/home" SUDO='' \
    CRONTAB_FIXTURE_DIR="$T/cronfix" PATH="$T/stub:$PATH" \
    "$SCRIPT" "$@" 2>&1
}

section "A. a private tree is DRIFT, named by account"
mkdir -p "$T/home/ecosim/.local/libexec/selfdev"
mkdir -p "$T/home/wtul"
printf '56 5 * * * /usr/local/libexec/selfdev/selfdev-release-tick.sh --apply # realisateur:selfdev-release:TICK\n' > "$T/cronfix/dcp-gate-site"
out="$(run)"; rc=$?
has "A1 ecosim's private tree is reported DRIFT" "$out" "DRIFT ecosim: $T/home/ecosim/.local/libexec/selfdev"
eq  "A2 without --strict, a finding still exits 0" "$rc" "0"

section "B. an account with no private tree reports ok"
has "B1 wtul, with no tree, reports ok" "$out" "ok    wtul"

section "C. dcp-gate-site's private tick is DRIFT"
printf '56 5 * * * /home/dcp-gate-site/.local/libexec/selfdev/selfdev-release-tick.sh --apply # realisateur:selfdev-release:TICK\n' > "$T/cronfix/dcp-gate-site"
out="$(run)"
has "C1 the private tick is named" "$out" "DRIFT dcp-gate-site: still adopts builds out of its own"

section "D. dcp-gate-site on the shared host tick reads clear"
printf '56 5 * * * /usr/local/libexec/selfdev/selfdev-release-tick.sh --apply # realisateur:selfdev-release:TICK\n' > "$T/cronfix/dcp-gate-site"
out="$(run)"
has "D1 the shared-tick row reads ok, not DRIFT" "$out" "ok    dcp-gate-site: the release tick row points at the shared host tick"
hasnt "D2 and is never reported as DRIFT" "$out" "DRIFT dcp-gate-site"

section "E. dcp-gate-site with no crontab at all reads clear, not BLIND"
rm -f "$T/cronfix/dcp-gate-site"
out="$(run)"; rc=$?
has "E1 no crontab at all is ok" "$out" "ok    dcp-gate-site: no crontab at all"
eq  "E2 and the run is not BLIND for it" "$rc" "0"

section "F. an empty uid band is BLIND, not a silent pass"
: > "$T/empty-passwd"
out="$(SELFDEV_PASSWD="$T/empty-passwd" SELFDEV_HOME_ROOT="$T/home" SUDO='' PATH="$T/stub:$PATH" "$SCRIPT" 2>&1)"; rc=$?
eq  "F1 no account in the band exits 6" "$rc" "6"
has "F2 and says BLIND" "$out" "BLIND"
has "F3 and says nothing was measured" "$out" "nothing was measured"

section "G. dcp-gate-site missing from the band is BLIND"
cat > "$T/passwd-noticket" <<'EOF'
ecosim:x:3011:3011::/home/ecosim:/bin/bash
EOF
out="$(SELFDEV_PASSWD="$T/passwd-noticket" SELFDEV_HOME_ROOT="$T/home" SUDO='' \
       CRONTAB_FIXTURE_DIR="$T/cronfix" PATH="$T/stub:$PATH" "$SCRIPT" 2>&1)"; rc=$?
eq  "G1 exits 6 when dcp-gate-site is not in the band on this host" "$rc" "6"
has "G2 and names it BLIND" "$out" "BLIND dcp-gate-site is not in uid band"

section "H. a crontab that cannot be read is BLIND, never graded ok or DRIFT"
mkpasswd
mkdir -p "$T/stub-h"
cat > "$T/stub-h/crontab" <<'SHIM'
#!/usr/bin/env bash
echo "crontab: permission denied" >&2
exit 1
SHIM
chmod +x "$T/stub-h/crontab"
out="$(SELFDEV_PASSWD="$T/passwd" SELFDEV_HOME_ROOT="$T/home" SUDO='' PATH="$T/stub-h:$PATH" "$SCRIPT" 2>&1)"; rc=$?
eq  "H1 an unreadable crontab exits 6" "$rc" "6"
has "H2 and says BLIND, naming the account" "$out" "BLIND dcp-gate-site: crontab -l -u dcp-gate-site could not be read"
hasnt "H3 its tick is never reported ok" "$out" "ok    dcp-gate-site:"
hasnt "H4 its tick is never reported DRIFT" "$out" "DRIFT dcp-gate-site:"

section "I. --strict tracks findings"
printf '56 5 * * * /home/dcp-gate-site/.local/libexec/selfdev/selfdev-release-tick.sh --apply # realisateur:selfdev-release:TICK\n' > "$T/cronfix/dcp-gate-site"
out="$(run --strict)"; rc=$?
eq  "I1 --strict exits 1 while a private tree or the private tick exists" "$rc" "1"
out="$(run)"; rc=$?
eq  "I2 without --strict, the same finding still exits 0" "$rc" "0"

section "J. a fully clear estate is --strict-green"
rm -rf "$T/home/ecosim/.local/libexec/selfdev"
printf '56 5 * * * /usr/local/libexec/selfdev/selfdev-release-tick.sh --apply # realisateur:selfdev-release:TICK\n' > "$T/cronfix/dcp-gate-site"
out="$(run --strict)"; rc=$?
eq  "J1 --strict exits 0 once every tree is gone and the tick is repointed" "$rc" "0"
has "J2 the summary reports zero findings" "$out" "0 drift finding(s)"

section "K. it is declared, so it reaches a host by a named channel"
. "$REPO_BIN/lib/propagation-set.sh"
ch="$(prop_channel selfdev-libexec-probe.sh 2>/dev/null)" || ch=""
eq "K1 prop_channel says provision -- a probe an operator runs, not a verb" "$ch" "provision"
printf '%s\n' "$(prop_host_tools)" | grep -qx selfdev-libexec-probe.sh \
  && ok "K2 it rides to the host libexec, alongside the steps it probes" \
  || bad "K2 it rides to the host libexec" "absent from prop_host_tools"

section "L. it is wired into dresse.sh's standing plan, --check only"
DRESSE="$REPO_BIN/dresse.sh"
has "L1 named in HOST_STEPS" "$(cat "$DRESSE")" "selfdev-libexec-probe.sh|--strict|--strict|"
hasnt "L2 no --apply half is wired for it" "$(sed -n '/^HOST_STEPS=/,/^"/p' "$DRESSE")" "selfdev-libexec-probe.sh|--strict|--apply|"

echo
summary
