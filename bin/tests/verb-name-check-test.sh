#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../verb-name-check.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OWNER=fixtureowner
FIX="$TMP/fix"
mkdir -p "$FIX"

g() { git -c init.defaultBranch=main -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }

mkrepo() {   # mkrepo <repo> <verb>...  -- each verb an executable bin/<v>
  local repo="$1"; shift
  local d="$FIX/$repo.git"
  rm -rf "$d"; mkdir -p "$d/bin"
  for v in "$@"; do
    printf '#!/usr/bin/env bash\nprintf %%s\\\\n %s\n' "$v" > "$d/bin/$v"
    chmod +x "$d/bin/$v"
  done
  g init "$d"
  g -C "$d" checkout -b bashified
  g -C "$d" add -A
  g -C "$d" commit -m "bashified $repo"
  g -C "$d" config uploadpack.allowAnySHA1InWant true
  g -C "$d" config uploadpack.allowReachableSHA1InWant true
}

mkdir -p "$TMP/stub"
cat > "$TMP/stub/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo list")   cat "$FIXTURE_REPOLIST"; exit 0 ;;
esac
if [ "$1" = api ]; then
  path="$2"
  repo="$(printf '%s' "$path" | awk -F/ '{print $3}')"
  sha="$(printf '%s' "$path" | sed 's#.*/trees/##; s#?.*##')"
  [ "$repo" = "${FIXTURE_BLIND_REPO:-}" ] && exit 1   # reachable over git, unreadable over the API: BLIND
  d="$FIXTURE_DIR/$repo.git"
  [ -d "$d" ] || exit 1
  git -C "$d" ls-tree -r "$sha" 2>/dev/null \
    | awk '{ p=$4; for(i=5;i<=NF;i++) p=p" "$i; print $1, p }'
  exit 0
fi
exit 1
STUB
chmod +x "$TMP/stub/gh"

cat > "$TMP/gitconfig" <<EOF
[url "file://$FIX/"]
    insteadOf = https://github.com/$OWNER/
EOF

printf '#project\tname\twhy\n' > "$TMP/not-a-verb.tsv"

check_call() {
  PATH="$TMP/stub:$PATH" \
  FIXTURE_REPOLIST="$TMP/repolist" FIXTURE_DIR="$FIX" \
  FIXTURE_BLIND_REPO="${FIXTURE_BLIND_REPO:-}" \
  VERB_NOT_A_VERB_FILE="$TMP/not-a-verb.tsv" \
  GIT_CONFIG_GLOBAL="$TMP/gitconfig" GIT_CONFIG_NOSYSTEM=1 \
  bash "$CHECK" --owner "$OWNER" "$@"
}

echo "verb-name-check contract"

mkrepo alpha aa
mkrepo beta  ba
printf 'alpha\nbeta\n' > "$TMP/repolist"

out="$(check_call zzz 2>&1)"; rc=$?
rc "1a free name exits 0" 0 "$rc"
has "1b says free" "$out" "free"

out="$(check_call aa 2>&1)"; rc=$?
rc "2a a declared name exits 1" 1 "$rc"
has "2b names the claimant" "$out" "alpha"
has "2c says TAKEN" "$out" "TAKEN"

d="$FIX/beta.git"
printf 'echo not-executable\n' > "$d/bin/noexec"
g -C "$d" add -A; g -C "$d" commit -m "non-executable bin/noexec"
out="$(check_call noexec 2>&1)"; rc=$?
rc "3a a non-executable path exits 0 (free)" 0 "$rc"

printf '#project\tname\twhy\nalpha\taa\tfixture: opted out\n' > "$TMP/not-a-verb.tsv"
out="$(check_call aa 2>&1)"; rc=$?
rc "4a an exempted name reads as free" 0 "$rc"
printf '#project\tname\twhy\n' > "$TMP/not-a-verb.tsv"

out="$(check_call 2>&1)"; rc=$?
rc "5a no name given exits 2" 2 "$rc"
out="$(check_call 'has/slash' 2>&1)"; rc=$?
rc "5b a name with a slash exits 2" 2 "$rc"

FIXTURE_BLIND_REPO=beta
out="$(check_call bogus 2>&1)"; rc=$?
rc "6a an unreadable repo exits 3, not 0" 3 "$rc"
has "6b says BLIND" "$out" "BLIND"
unset FIXTURE_BLIND_REPO

summary
