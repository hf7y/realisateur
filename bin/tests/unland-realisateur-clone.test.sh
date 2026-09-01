#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/unland-realisateur-clone.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp

echo "unland-realisateur-clone.test.sh"

mkpasswd() {  # two self-dev accounts in the band, the owning account, and two out-of-band names that must never be touched
  cat > "$T/passwd" <<'EOF'
root:x:0:0::/root:/bin/bash
zach:x:1000:1000::/home/zach:/bin/bash
ecosim:x:3011:3011::/home/ecosim:/bin/bash
realisateur:x:3010:3010::/home/realisateur:/bin/bash
wtul:x:3006:3006::/home/wtul:/bin/bash
nobody:x:65534:65534::/nonexistent:/usr/sbin/nologin
EOF
}
mkclone() {  # a committed, pushed clone -- the state a bootstrap copy is in
  local d="$1"
  mkdir -p "$d"
  git -C "$d" init -q
  git -C "$d" -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed
  git -C "$d" branch -q -M main
  git clone -q --bare "$d" "$d.remote" 2>/dev/null
  git -C "$d" remote add origin "$d.remote"
  git -C "$d" push -q origin main 2>/dev/null
  git -C "$d" branch -q --set-upstream-to=origin/main main 2>/dev/null
}
run() { SELFDEV_PASSWD="$T/passwd" SELFDEV_HOME_ROOT="$T/home" "$SCRIPT" "$@" 2>&1; }

section "A. the argument contract"
"$SCRIPT" --not-a-real-flag >/dev/null 2>&1; eq "A1 unknown flag exits 2" "$?" "2"
"$SCRIPT" --help >/dev/null 2>&1;            eq "A2 --help exits 0" "$?" "0"
OUT="$("$SCRIPT" --help 2>&1)"
has "A3 --help documents the BLIND exit" "$OUT" "BLIND"
has "A4 --help documents the refused-without-root exit" "$OUT" "refused"
has "A5 --help says --check is the default and removes nothing" "$OUT" "--check (default)"

section "B. an empty uid band is BLIND, not a silent pass"
: > "$T/empty-passwd"
OUT="$(SELFDEV_PASSWD="$T/empty-passwd" SELFDEV_HOME_ROOT="$T/home" "$SCRIPT" --check 2>&1)"; RC=$?
eq  "B1 no account in the band exits 6" "$RC" "6"
has "B2 and says BLIND" "$OUT" "BLIND"
has "B3 and says nothing was measured" "$OUT" "nothing was measured"

section "C. the default is a dry run that names every clone and removes none"
mkpasswd
mkclone "$T/home/ecosim/Documents/Projects/realisateur"
mkclone "$T/home/wtul/Documents/Projects/realisateur"
mkclone "$T/home/realisateur/Documents/Projects/realisateur"
mkclone "$T/home/zach/Documents/Projects/realisateur"   # uid 1000: a real checkout, out of band
OUT="$(run --check)"; RC=$?
has "C1 ecosim's clone is named" "$OUT" "would remove $T/home/ecosim/Documents/Projects/realisateur"
has "C2 wtul's clone is named"   "$OUT" "would remove $T/home/wtul/Documents/Projects/realisateur"
eq  "C3 findings exit 1" "$RC" "1"
[ -d "$T/home/ecosim/Documents/Projects/realisateur" ] \
  && ok "C4 --check removed nothing" || bad "C4 --check removed nothing"

section "D. the account that OWNS realisateur keeps its checkout"
has  "D1 it is reported KEPT, by name" "$OUT" "realisateur: KEPT -- this account owns realisateur"
hasnt "D2 and is never a removal target" "$OUT" "would remove $T/home/realisateur/"

section "E. out-of-band accounts are not in the roster at all"
hasnt "E1 zach (uid 1000) is untouched" "$OUT" "/home/zach/"
hasnt "E2 root (uid 0) is untouched"    "$OUT" "root:"

section "F. a clone holding work is KEPT, not destroyed"
echo 'an idea nobody pushed' > "$T/home/wtul/Documents/Projects/realisateur/x.idea"
OUT="$(run --check)"
has "F1 untracked residue keeps wtul's clone back" "$OUT" "wtul: KEPT"
has "F2 and says what the residue is" "$OUT" "uncommitted or untracked files"
rm -f "$T/home/wtul/Documents/Projects/realisateur/x.idea"

section "G. --apply is refused without root, and refusing removes nothing"
if [ "$(id -u)" -eq 0 ]; then
  ok "G1 skipped: already root, so the refusal branch cannot be reached"
else
  OUT="$(run --apply)"; RC=$?
  eq  "G1 --apply without root exits 5" "$RC" "5"
  has "G1b and says so" "$OUT" "needs root"
  [ -d "$T/home/ecosim/Documents/Projects/realisateur" ] \
    && ok "G2 a refused --apply removed nothing" || bad "G2 a refused --apply removed nothing"
fi

section "H. --apply really removes them -- the destructive path, exercised"
# fakeroot is enough -- id -u is the only root fact the script reads, and an untested rm -rf is the one path that must not ship on inspection alone.
if command -v fakeroot >/dev/null 2>&1; then
  OUT="$(SELFDEV_PASSWD="$T/passwd" SELFDEV_HOME_ROOT="$T/home" fakeroot "$SCRIPT" --apply 2>&1)"; RC=$?
  eq "H1 a clean sweep exits 0" "$RC" "0"
  [ -d "$T/home/ecosim/Documents/Projects/realisateur" ] \
    && bad "H2 ecosim's clone is gone" || ok "H2 ecosim's clone is gone"
  [ -d "$T/home/wtul/Documents/Projects/realisateur" ] \
    && bad "H3 wtul's clone is gone" || ok "H3 wtul's clone is gone"
  [ -d "$T/home/realisateur/Documents/Projects/realisateur" ] \
    && ok "H4 the OWNING account's checkout survived the sweep" \
    || bad "H4 the OWNING account's checkout survived the sweep"
  [ -d "$T/home/zach/Documents/Projects/realisateur" ] \
    && ok "H5 zach's uid-1000 checkout survived -- the band is the whole roster" \
    || bad "H5 zach's uid-1000 checkout survived"
else
  ok "H1 skipped: no fakeroot, so the removal path cannot be driven here"
fi

section "J. the witness proves BOTH halves"
OUT="$(run --check)"
has "J1 it counts the clones left" "$OUT" "clones left:"
has "J2 and that a verb still resolves" "$OUT" "command -v ausculte"
has "J3 it lists as root, so the 0700 home of the clone that must SURVIVE is not counted as removed" "$OUT" "sudo find"

section "K. it is declared, so it reaches a host by a named channel"
. "$ROOT/lib/propagation-set.sh"
ch="$(prop_channel unland-realisateur-clone.sh 2>/dev/null)" || ch=""
eq "K1 prop_channel says provision -- an operator runs this once, on nobody's clock" "$ch" "provision"
printf '%s\n' "$(prop_host_tools)" | grep -qx unland-realisateur-clone.sh \
  && ok "K2 it rides to the host libexec, the only copy monkey will have once the clones are gone" \
  || bad "K2 it rides to the host libexec" "absent from prop_host_tools"

echo
summary
