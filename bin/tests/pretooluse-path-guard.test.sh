#!/usr/bin/env bash
set -uo pipefail  # bin/tests/pretooluse-path-guard.test.sh: witness for hooks/pretooluse-path-guard.sh (#707)
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/../hooks/pretooluse-path-guard.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp

TABLE="$T/path-guard.tsv"
cat > "$TABLE" <<'EOF'
/usr/local/bin/gh	edit bin/gh-sign.sh on main instead
/usr/local/bin/*	edit the source on main instead
*/verb-builds/current/*	edit the source on main instead
*/schedule/ROSTER	propose it to schedule/_paced.*.conf instead, by PR
EOF

payload() { printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2"; }
run() { payload "$1" "$2" | PATH_GUARD_TABLE="$TABLE" "$SCRIPT" 2>&1; }
rcof() { payload "$1" "$2" | PATH_GUARD_TABLE="$TABLE" "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?"; }

section "A. tool filter"

RC="$(rcof Read /usr/local/bin/gh)"
rc "A1 a Read of a denied path is not this guard's business -- exit 0" 0 "$RC"

RC="$(rcof Bash /usr/local/bin/gh)"
rc "A2 same for Bash" 0 "$RC"

section "B. table-driven rows, first match wins"

RC="$(rcof Write /usr/local/bin/gh)"
rc "B1 the exact installed gh shim is BLOCKED" 2 "$RC"
OUT="$(run Write /usr/local/bin/gh)"
has "B1 names the front door" "$OUT" "gh-sign.sh"

RC="$(rcof Edit /usr/local/bin/some-other-verb)"
rc "B2 any other installed verb falls to the generic /usr/local/bin/* row" 2 "$RC"

RC="$(rcof Write "/home/acct/.local/share/verb-builds/current/x/bin/foo")"
rc "B3 an installed verb-build copy is BLOCKED" 2 "$RC"

RC="$(rcof Edit "/home/acct/Documents/Projects/scheduler/schedule/ROSTER")"
rc "B4 schedule/ROSTER is BLOCKED" 2 "$RC"
OUT="$(run Edit "/home/acct/Documents/Projects/scheduler/schedule/ROSTER")"
has "B4 names the front door" "$OUT" "_paced"

RC="$(rcof Write "/home/acct/Documents/Projects/realisateur/bin/gh-sign.sh")"
rc "B5 the SOURCE (bin/gh-sign.sh in a checkout) is never blocked" 0 "$RC"

RC="$(rcof Write "/home/acct/scratch.txt")"
rc "B6 an unrelated path is not blocked" 0 "$RC"

section "C. the labels.tsv copy check (not table-driven -- asks the containing repo's remote)"

newrepo() {
  local d="$1" remote="$2"
  mkdir -p "$d/bin/lib"
  git init -q "$d"
  git -C "$d" remote add origin "$remote"
  printf 'stub\n' > "$d/bin/lib/labels.tsv"
}

newrepo "$T/realisateur" "https://github.com/hf7y/realisateur.git"
RC="$(rcof Edit "$T/realisateur/bin/lib/labels.tsv")"
rc "C1 the source copy, in hf7y/realisateur, is never blocked" 0 "$RC"

newrepo "$T/other" "https://github.com/hf7y/senechal.git"
RC="$(rcof Edit "$T/other/bin/lib/labels.tsv")"
rc "C2 a copy in a different repo's remote is BLOCKED" 2 "$RC"
OUT="$(run Edit "$T/other/bin/lib/labels.tsv")"
has "C2 names the one home" "$OUT" "ONE home"

RC="$(rcof Write "$T/no-such-repo/bin/lib/labels.tsv")"
rc "C3 a labels.tsv with no git remote at all is BLOCKED (cannot prove it is the source)" 2 "$RC"

section "D. another project's tree (dynamic: \$SELFDEV_PROJECTS_ROOT/\$(whoami) is home)"

run_d() { payload "$1" "$2" | PATH_GUARD_TABLE="$TABLE" SELFDEV_PROJECTS_ROOT="$T/Projects" "$SCRIPT" 2>&1; }
rcof_d() { payload "$1" "$2" | PATH_GUARD_TABLE="$TABLE" SELFDEV_PROJECTS_ROOT="$T/Projects" "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?"; }
ME="$(id -un)"

RC="$(rcof_d Write "$T/Projects/$ME/foo.sh")"
rc "D1 a write to this account's own project tree is fine" 0 "$RC"

RC="$(rcof_d Edit "$T/Projects/some-other-project/bin/foo.sh")"
rc "D2 a write into a DIFFERENT project's tree is BLOCKED" 2 "$RC"
OUT="$(run_d Edit "$T/Projects/some-other-project/bin/foo.sh")"
has "D2 names the project and a front door" "$OUT" "some-other-project"
has "D2 names notify-senechal as an alternative" "$OUT" "notify-senechal"

RC="$(rcof_d Write "$T/Projects/other/deep/nested/path.sh")"
rc "D3 blocks regardless of how deep under the other project the path is" 2 "$RC"

RC="$(rcof_d Write "/somewhere/else/entirely.sh")"
rc "D4 a path outside SELFDEV_PROJECTS_ROOT entirely is not this check's business" 0 "$RC"

section "E. no payload / no path"

RC="$(printf '' | "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?")"
rc "E1 empty stdin -- reads as empty payload, no tool_name match, exit 0" 0 "$RC"

RC="$(printf '{"tool_name":"Write","tool_input":{}}' | "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?")"
rc "E2 a Write with no file_path is not this guard's business" 0 "$RC"

summary
