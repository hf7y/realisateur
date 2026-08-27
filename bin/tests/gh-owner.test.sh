#!/usr/bin/env bash
# gh-owner.test.sh -- one home for the estate's GitHub owner (#673).

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
LIB="$HERE/bin/lib/gh-owner.sh"

section "A. the one home"
if [ -r "$LIB" ]; then ok "A1 bin/lib/gh-owner.sh exists"; else bad "A1 bin/lib/gh-owner.sh is missing"; fi
eq "A2 defaults to hf7y today" "$(bash -c ". '$LIB'; printf '%s' \"\$GH_ESTATE_OWNER\"")" "hf7y"
eq "A3 GH_ESTATE_OWNER overrides it" \
   "$(bash -c "export GH_ESTATE_OWNER=neworg; . '$LIB'; printf '%s' \"\$GH_ESTATE_OWNER\"")" "neworg"
eq "A4 sourcing twice is a no-op" \
   "$(bash -c ". '$LIB'; . '$LIB'; printf '%s' \"\$GH_ESTATE_OWNER\"")" "hf7y"

section "B. no script re-spells the owner"
ADDRESSES='(:-|:=|=)"?hf7y([/"]|$)|github\.com/hf7y'
offenders=""
while IFS= read -r f; do
  case "$f" in
    */lib/gh-owner.sh|*/tests/*) continue ;;
  esac
  hits="$(grep -nE "$ADDRESSES" "$f" || true)"
  if [ -n "$hits" ]; then offenders="$offenders
$f:
$hits"; fi
done <<<"$(find "$HERE/bin" "$HERE/hooks" -name '*.sh' -type f | sort)"

if [ -z "$offenders" ]; then
  ok "B1 no owner literal addresses GitHub outside lib/gh-owner.sh"
else
  bad "B1 read the owner from lib/gh-owner.sh (\$GH_ESTATE_OWNER), do not re-spell it" "$offenders"
fi

section "C. the callers resolve through it"
eq "C1 answered.sh"        "$(bash -c ". '$HERE/bin/lib/answered.sh' >/dev/null 2>&1; printf '%s' \"\$ANSWERED_OWNER\"")" "hf7y"
eq "C2 roster-set.sh"      "$(bash -c ". '$HERE/bin/lib/roster-set.sh' >/dev/null 2>&1; printf '%s' \"\$ROSTER_OWNER\"")" "hf7y"
eq "C3 arming.sh"          "$(bash -c ". '$HERE/bin/lib/arming.sh' >/dev/null 2>&1; printf '%s' \"\$ARMING_ROSTER_REPO\"")" "hf7y/scheduler"
eq "C4 propagation-set.sh" "$(bash -c ". '$HERE/bin/lib/propagation-set.sh' >/dev/null 2>&1; printf '%s' \"\$PROP_RELEASE_REPO\"")" "hf7y/verbs"
eq "C5 a new owner reaches a caller" \
   "$(bash -c "export GH_ESTATE_OWNER=neworg; . '$HERE/bin/lib/arming.sh' >/dev/null 2>&1; printf '%s' \"\$ARMING_ROSTER_REPO\"")" "neworg/scheduler"
eq "C6 a new owner reaches the release channel" \
   "$(bash -c "export GH_ESTATE_OWNER=neworg; . '$HERE/bin/lib/propagation-set.sh' >/dev/null 2>&1; printf '%s' \"\$PROP_RELEASE_REMOTE\"")" \
   "https://github.com/neworg/verbs.git"

section "D. the lib stays POSIX-sourceable"
# stamp-verb-build.sh generates a /bin/sh commit-msg hook that sources
# propagation-set.sh and FAILS OPEN, so a bash-only line there ends the
# Verb-Build trailer estate-wide with nothing to report it.
SH="$(command -v dash || command -v busybox || echo sh)"
case "$SH" in */busybox) SH="busybox sh" ;; esac
OUT="$($SH -c ". '$LIB'; . '$HERE/bin/lib/propagation-set.sh'; printf '%s' \"\$PROP_RELEASE_REPO\"" 2>&1)"
eq "D1 propagation-set.sh sources under $SH" "$OUT" "hf7y/verbs"
HOOKSRC="$(cat "$HERE/bin/stamp-verb-build.sh")"
has "D2 the generated hook pre-sources gh-owner.sh" "$HOOKSRC" '. "$GH_OWNER_SH" || exit 0'

summary
