#!/usr/bin/env bash
#
# Contract test for lib/api-restamp.sh (hf7y/realisateur#256): the fallback
# restamp-discipline.sh falls back to when `git push` fails because this
# account's SSH deploy key is read-only on a foreign repo. Exercises
# gh_slug()'s URL parsing and api_restamp_push()'s full call sequence
# (base sha -> branch -> commit -> PR -> merge), including each step's
# failure mode and the one step (auto-merge) that is allowed to fail without
# failing the whole restamp.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }
contains(){ case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected to contain [$3], got [$2]" ;; esac; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASH_BIN="$(command -v bash)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- the fake gh -------------------------------------------------------------
mkdir -p "$TMP/stub"
cat > "$TMP/stub/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"

prev=''
for a in "$@"; do
  case "$prev" in
    -f) case "$a" in content=*) printf '%s' "${a#content=}" > "$GH_CONTENT_CAPTURE" ;; esac ;;
  esac
  prev="$a"
done

case "$*" in
  *"git/refs/heads/"*"--jq .object.sha"*)
    [ "${GH_FAIL_STEP:-}" = "base-sha" ] && exit 1
    printf '%s\n' "$FIXTURE_BASE_SHA"; exit 0 ;;
  "api repos/"*"/git/refs -f ref="*)
    [ "${GH_FAIL_STEP:-}" = "create-ref" ] && exit 1
    exit 0 ;;
  *"contents/CLAUDE.md?ref="*"--jq .sha"*)
    [ "${GH_FAIL_STEP:-}" = "file-sha" ] && exit 1
    printf '%s\n' "$FIXTURE_FILE_SHA"; exit 0 ;;
  "api -X PUT repos/"*"/contents/CLAUDE.md"*)
    [ "${GH_FAIL_STEP:-}" = "put-content" ] && exit 1
    exit 0 ;;
  "pr create --repo "*)
    [ "${GH_FAIL_STEP:-}" = "pr-create" ] && exit 1
    printf '%s\n' "$FIXTURE_PR_URL"; exit 0 ;;
  "pr merge --repo "*)
    [ "${GH_FAIL_STEP:-}" = "pr-merge" ] && exit 1
    exit 0 ;;
  *)
    echo "gh: fixture stub got unrecognized args: $*" >&2
    exit 9 ;;
esac
STUB
chmod +x "$TMP/stub/gh"

export PATH="$TMP/stub:$PATH"
export GH_LOG="$TMP/gh.log"
export GH_CONTENT_CAPTURE="$TMP/gh.content"
export FIXTURE_BASE_SHA="base1234"
export FIXTURE_FILE_SHA="file5678"
export FIXTURE_PR_URL="https://github.com/hf7y/widget/pull/99"

# shellcheck source=../lib/api-restamp.sh
. "$HERE/../lib/api-restamp.sh"

echo "api-restamp contract"

# --- 1. gh_slug parses every origin form realisateur's own conf.sh-registered
#        projects actually use -------------------------------------------------
mkrepo() { # mkrepo <dir> <origin-url>
  git init -q "$1"
  git -C "$1" remote add origin "$2"
}

mkrepo "$TMP/r-ssh" "git@github.com:hf7y/widget.git"
check "gh_slug: ssh form with .git" "$(gh_slug "$TMP/r-ssh")" "hf7y/widget"

mkrepo "$TMP/r-https" "https://github.com/hf7y/widget.git"
check "gh_slug: https form with .git" "$(gh_slug "$TMP/r-https")" "hf7y/widget"

mkrepo "$TMP/r-https-nogit" "https://github.com/hf7y/widget"
check "gh_slug: https form without .git" "$(gh_slug "$TMP/r-https-nogit")" "hf7y/widget"

mkrepo "$TMP/r-nongh" "git@gitlab.com:hf7y/widget.git"
check "gh_slug: non-GitHub origin returns 1, prints nothing" \
      "$(gh_slug "$TMP/r-nongh" 2>/dev/null; echo "rc=$?")" "rc=1"

# --- 2. full success path ---------------------------------------------------
repo="$TMP/r-full"
mkrepo "$repo" "git@github.com:hf7y/widget.git"
printf 'stub content\n' > "$repo/CLAUDE.md"
git -C "$repo" add CLAUDE.md
git -C "$repo" -c user.email=t@t -c user.name=t commit -q -m "restamp"

content="$TMP/content.md"
printf 'CLAUDE.md: restamp the realisateur baseline (replace)\n\nbody line\n' > "$TMP/msg.txt"
printf 'restamped content\nsecond line\n' > "$content"

: > "$GH_LOG"; rm -f "$GH_CONTENT_CAPTURE"
out="$(api_restamp_push "$repo" "hf7y/widget" "main" "$content" "$TMP/msg.txt")"
rc=$?
check "success path: exit 0" "$rc" "0"
check "success path: prints the PR url" "$out" "$FIXTURE_PR_URL"
check "...reads the base sha off the right branch" \
      "$(grep -c "git/refs/heads/main --jq .object.sha" "$GH_LOG")" "1"
contains "...creates the new ref off that base sha" "$(cat "$GH_LOG")" "-f sha=$FIXTURE_BASE_SHA"
contains "...opens the PR against the base branch, not the new one" \
         "$(grep '^pr create' "$GH_LOG")" "--base main"
contains "...PR title is the message file's first line" \
         "$(grep '^pr create' "$GH_LOG")" "--title CLAUDE.md: restamp the realisateur baseline (replace)"
contains "...merges with auto+squash+delete-branch, no manual step" \
         "$(grep '^pr merge' "$GH_LOG")" "--auto --squash --delete-branch"
check "...content shipped to the Contents API is base64 of the file, not raw text" \
      "$(printf '%s' "$(cat "$GH_CONTENT_CAPTURE")" | base64 -d 2>/dev/null || openssl base64 -d -A < "$GH_CONTENT_CAPTURE")" \
      "$(cat "$content")"

# --- 3. each required step's failure fails the whole call, prints nothing --
for step in base-sha create-ref file-sha put-content pr-create; do
  : > "$GH_LOG"
  out="$(GH_FAIL_STEP="$step" api_restamp_push "$repo" "hf7y/widget" "main" "$content" "$TMP/msg.txt" 2>/dev/null)"
  rc=$?
  check "GH_FAIL_STEP=$step -> exit 1" "$rc" "1"
  check "GH_FAIL_STEP=$step -> prints nothing (no half-landed PR url)" "$out" ""
done

# --- 4. auto-merge failing does NOT fail the call: the content already
#        landed on the PR branch, a human can still merge it by hand --------
: > "$GH_LOG"
out="$(GH_FAIL_STEP=pr-merge api_restamp_push "$repo" "hf7y/widget" "main" "$content" "$TMP/msg.txt" 2>/dev/null)"
rc=$?
check "GH_FAIL_STEP=pr-merge -> still exit 0" "$rc" "0"
check "GH_FAIL_STEP=pr-merge -> still prints the PR url" "$out" "$FIXTURE_PR_URL"

echo
summary
