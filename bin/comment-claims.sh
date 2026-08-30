#!/usr/bin/env bash
set -uo pipefail  # comment-claims.sh -- does a code comment assert something this tree contradicts? RUNNER: .github/workflows/tests.yml (comment-claims job). GUARD-TEST: bin/tests/comment-claims.test.sh. GATE: ratchet -- a finding already in bin/comment-claims.ratchet does not fail; a new one does. WHY it exists, WHICH predicates were measured and rejected to get here, and why "unresolvable" can never be reported as "false" all live with the predicate, in bin/lib/comment-claims.jq -- this file is extraction, value resolution and the ratchet, nothing else. BLIND, NEVER CLEAN: every way this can fail to look exits 6, because a zero-finding run over a tree it could not read is the exact defect it exists to prevent.

CLI_NAME='comment-claims.sh'
CLI_SUMMARY='does a code comment assert something this tree contradicts?'
CLI_USAGE='  comment-claims.sh                 check this repository
  comment-claims.sh <repo-root>     check another checkout
  comment-claims.sh --accept        record the current findings as the floor'
CLI_FLAGS='--check --accept'
CLI_POSITIONAL=any
CLI_EXITS='  0  no finding this tree had not already recorded
  1  REGRESSION -- a claim the ratchet does not hold
  6  BLIND -- could not read the tree, the predicate, or any comment'
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
. "$HERE/lib/cli-guard.sh"
cli_guard "$@"

ACCEPT=0
ROOT=''
while [ $# -gt 0 ]; do
  case "$1" in
    --check)  shift ;;   # the default, named because a caller asks for it by name
    --accept) ACCEPT=1; shift ;;
    *) [ -n "$ROOT" ] && cli_die "one repository root at a time: $1"
       ROOT="$1"; shift ;;
  esac
done
ROOT="${ROOT:-$(cd "$HERE/.." && pwd)}"

blind() { printf '%s: BLIND -- %s\n' "$CLI_NAME" "$*" >&2; exit 6; }

command -v jq >/dev/null 2>&1 || blind "jq is not on PATH, so nothing was parsed."
for p in "$HERE/lib/comment-claims.jq" "$HERE/lib/stale-paths.jq"; do
  [ -r "$p" ] || blind "the predicate is not readable at $p."
done

. "$HERE/lib/roster-set.sh"
[ "${ROSTER_SET_LIB:-}" = 1 ] && [ "${#ROSTER[@]}" -gt 0 ] \
  || blind "lib/roster-set.sh did not load, so cross-repo citations would be read as local ones."
ROSTER_PATTERN="$(IFS='|'; echo "${ROSTER[*]}")"
OWNER="${GH_ESTATE_OWNER:-hf7y}"

cd "$ROOT" || blind "cannot cd to $ROOT."
git rev-parse --git-dir >/dev/null 2>&1 || blind "$ROOT is not a git tree; the file list would be a guess."

mapfile -t FILES < <(   # TRACKED ONLY, bin/shellcheck-lint.sh's rule: a scratch file cannot turn this red and a deleted one cannot keep it red. `#` is the comment character in every extension below; .md is absent deliberately, since there `#` is a heading.
  {
    git ls-files '*.sh' '*.bash' '*.conf' '*.yml' '*.yaml' '*.py' '*.jq' \
                 '*.tsv' '*.cfg' '*.ini' '*.toml' 2>/dev/null
    while IFS= read -r f; do   # the verbs are extensionless, so reading the shebang is the only way to know
      [ -f "$f" ] || continue
      head -1 "$f" 2>/dev/null | grep -qE '^#!.*(bash|sh|python)' && printf '%s\n' "$f"
    done < <(git ls-files 'bin/*' 2>/dev/null)
  } | sort -u
)
[ "${#FILES[@]}" -gt 0 ] || blind "matched zero files under $ROOT -- this run read NOTHING."

TREE="$(git ls-files | jq -R -s 'split("\n") | map(select(length > 0))')"

RECORDS="$(   # Two record kinds in one pass: a WHOLE-LINE comment tagged with the index of the contiguous run it belongs to (the unit a KEY=VALUE claim states its subject in), and a structured header field wherever on the line it sits -- several are crammed into a trailing comment to keep the prose ratchet down -- cut at ` -- `, where the field's value stops and prose starts.
  awk '
    FNR == 1 { prev = -2; blk = 0 }
    {
      h = index($0, "#")
      if (h > 0) {
        tail = substr($0, h)
        if (match(tail, /(RUNNER|GUARD-TEST|SUBJECTS?):?[ \t]/)) {
          f = substr(tail, RSTART, RLENGTH); sub(/:?[ \t]$/, "", f)
          v = substr(tail, RSTART + RLENGTH); sub(/ -- .*$/, "", v)
          printf "%s\t%d\t0\t%s\t%s\n", FILENAME, FNR, f, v
        }
      }
      if ($0 ~ /^[ \t]*#/) {
        if (FNR != prev + 1) blk++
        prev = FNR
        printf "%s\t%d\t%d\t\t%s\n", FILENAME, FNR, blk, $0
      }
    }
  ' "${FILES[@]}" \
  | jq -R -s 'split("\n") | map(select(length > 0))
      | map(capture("^(?<file>[^\t]*)\t(?<line>[^\t]*)\t(?<block>[^\t]*)\t(?<field>[^\t]*)\t(?<text>.*)$"))
      | map(.line |= tonumber | .block |= tonumber
            | .field |= (if . == "" then null else . end))'
)" || blind "the comment extractor failed."
N_LINES="$(printf '%s' "$RECORDS" | jq 'length' 2>/dev/null)" || N_LINES=0
[ "${N_LINES:-0}" -gt 0 ] || blind "extracted zero comments from ${#FILES[@]} file(s) -- the extractor read nothing."

FOUND="$(
  printf '%s' "$RECORDS" \
  | jq -r -L "$HERE/lib" --arg owner "$OWNER" --arg roster_pattern "$ROSTER_PATTERN" \
        --argjson tree "$TREE" '
      include "comment-claims";
      annotate
      | (header_findings($tree) | [.file, .line, .kind, .missing, .subject]),
        (kv_pairs($tree)        | [.file, .line, .kind, (.key + "=" + .value),
                                   (.targets | join(","))])
      | @tsv'
)" || blind "the predicate did not run."

values() {   # <file> <KEY> -> every value that file gives KEY, INCLUDING the built-in default in a ${KEY:-X} expansion, which IS the value when nothing overrides it -- reading the literal RHS alone would call an accurate claim false. A value still holding `$` after that (KEY="$RUSH_MIN") states no value at all and is dropped, or every claim about that key would be resolvable and none satisfiable.
  sed -nE "s/^[[:space:]]*(export[[:space:]]+)?$2=(.*)$/\2/p" "$1" 2>/dev/null \
  | sed -E 's/[[:space:]]+#.*$//' \
  | while IFS= read -r v; do
      printf '%s\n' "$v"
      printf '%s\n' "$v" | grep -oE ':-[^}]*\}' | sed -E 's/^:-//; s/\}$//'
    done \
  | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/' | grep -v '^$' | grep -v '[$]'
}
norm() { awk -v s="$1" 'BEGIN { if (s ~ /^-?[0-9]+([.][0-9]+)?$/) printf "%.10g", s+0; else printf "%s", s }'; }   # 0.90 and 0.9 are the same ceiling; a string compare would report a file's own wording as a contradiction of itself

CURRENT=''   # the ratchet key: file<TAB>kind<TAB>subject, with NO line number -- one would churn the floor on every edit above a finding, which is why bin/shellcheck-lint.ratchet keys on (file, code) too
DETAIL=''    # the same key plus the line, grouped by that key at print time, so the row count can never disagree with the reported count
while IFS=$'\t' read -r file line kind subject extra; do
  [ -n "${file:-}" ] || continue
  case "$kind" in
    header)
      CURRENT+="$file"$'\t'"header"$'\t'"$subject"$'\n'
      DETAIL+="$file"$'\t'"header"$'\t'"$subject"$'\t'"$line"$'\t'"not in this tree"$'\n'
      ;;
    kv)
      key="${subject%%=*}"; claim="${subject#*=}"
      actual=''; assigners=''
      IFS=',' read -ra TARGETS <<< "$extra"
      for t in "${TARGETS[@]}"; do
        [ -f "$t" ] || continue
        v="$(values "$t" "$key")"
        [ -n "$v" ] || continue
        assigners="$assigners $t"
        actual+="$v"$'\n'
      done
      [ -n "$assigners" ] || continue   # no named file assigns the key: UNRESOLVABLE, and unresolvable is not false. A claim about another host, another repo, or a variable this tree never sets is reported as nothing at all.
      cn="$(norm "$claim")"
      match=0
      while IFS= read -r a; do
        [ -n "$a" ] && [ "$(norm "$a")" = "$cn" ] && match=1
      done <<< "$actual"
      [ "$match" -eq 1 ] && continue
      CURRENT+="$file"$'\t'"kv"$'\t'"$subject"$'\n'
      DETAIL+="$file"$'\t'"kv"$'\t'"$subject"$'\t'"$line"$'\t'"$(printf '%s' "$actual" | sort -u | paste -sd'|' -) in${assigners}"$'\n'
      ;;
  esac
done <<< "$FOUND"

RATCHET="$ROOT/bin/comment-claims.ratchet"
CURRENT="$(printf '%s' "$CURRENT" | grep . | sort -u)"
BASELINE=''
[ -f "$RATCHET" ] && BASELINE="$(grep -v '^#' "$RATCHET" | grep . | sort -u)"

NEW="$(comm -23 <(printf '%s\n' "$CURRENT" | grep . | sort -u) \
                <(printf '%s\n' "$BASELINE" | grep . | sort -u))"
GONE="$(comm -13 <(printf '%s\n' "$CURRENT" | grep . | sort -u) \
                 <(printf '%s\n' "$BASELINE" | grep . | sort -u))"
n_cur=$(printf '%s\n' "$CURRENT" | grep -c . || true)
n_new=$(printf '%s\n' "$NEW" | grep -c . || true)
n_gone=$(printf '%s\n' "$GONE" | grep -c . || true)

printf '%s: %d file(s), %d comment(s), %d finding(s).\n' \
  "$CLI_NAME" "${#FILES[@]}" "$N_LINES" "$n_cur"
if [ "$n_cur" -gt 0 ]; then
  printf '%s' "$DETAIL" | sort -t$'\t' -k1,1 -k2,2 -k3,3 -k4,4n | awk -F'\t' '
    function emit() { printf "  %-8s %-44s %s\n  %-8s %-44s   -> %s\n", K, F ":" L, S, "", "", D }
    { key = $1 FS $2 FS $3
      if (key == prev) { L = L "," $4; next }
      if (prev != "") emit()
      prev = key; F = $1; K = $2; S = $3; L = $4; D = $5 }
    END { if (prev != "") emit() }'
fi

if [ "$ACCEPT" -eq 1 ]; then
  {
    echo "# comment-claims.ratchet -- findings present when accepted. A run may"
    echo "# not add one; --accept is a visible act, and it reports what moved."
    echo "# See bin/lib/comment-claims.jq for the predicate table."
    echo "# accepted $(date -Is)"
    printf '%s\n' "$CURRENT" | grep . || true
  } > "$RATCHET"
  printf 'ACCEPTED: %s records %d finding(s) (+%d new, -%d fixed).\n' \
    "$RATCHET" "$n_cur" "$n_new" "$n_gone"
  exit 0
fi

[ "$n_gone" -gt 0 ] && {
  printf '\nFIXED since the floor was accepted (%d) -- run --accept to lock in:\n' "$n_gone"
  printf '%s\n' "$GONE" | grep . | sed 's/^/  - /'
}
if [ "$n_new" -gt 0 ]; then
  printf '\nREGRESSION: %d claim(s) the ratchet does not hold.\n' "$n_new" >&2
  printf '%s\n' "$NEW" | grep . | sed 's/^/  + /' >&2
  printf 'Fix the comment, or -- if it is right and this tree is wrong -- fix the\n' >&2
  printf 'tree. `--accept` is for a floor move you intend, not for a red run.\n' >&2
  exit 1
fi
printf 'no claim outside the floor (%d held).\n' "$n_cur"
exit 0
