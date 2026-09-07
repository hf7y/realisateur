#!/usr/bin/env bash
# enrole-selfdev.test.sh -- witness for bin/enrole-selfdev.sh.
#
# HERMETICITY: fully offline. Every case builds a throwaway git repo shaped
# like a scheduler clone under a temp dir. Nothing reads the live ecosystem,
# nothing writes a crontab (--sync is never passed), nothing reaches GitHub.
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/enrole-selfdev.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { printf '  PASS: %s\n' "$*"; pass=$((pass+1)); }
bad() { printf '  FAIL: %s\n' "$*"; fail=$((fail+1)); }
rc()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1 (unexpectedly present: $3)" ;; *) ok "$1" ;; esac; }

# A minimal clone: one registered project with a deliberately BLANK batch tier
# and no CRON_* fields -- the exact 2026-08-12 starting state of sequestria.
mkclone() {
  local d="$T/$1"; rm -rf "$d"; mkdir -p "$d/schedule"
  cat > "$d/schedule/widget.conf" <<'EOF'
PROJECT="widget"
PROJECT_KEY="widget"
PROJECT_REPO_PATH="$HOME/Documents/Projects/widget"
REPO_URL="https://github.com/hf7y/widget.git"
SWEEP_JOB_NAME=""
BATCH_JOB_NAME=""
BATCH_PROMPT="/nightly-batch"
BATCH_CRON=""
AUTONOMY_TIER="medium"
EOF
  printf '# rotation\nother|1|1|%s/other/x\n' "$HOMES" > "$d/schedule/_paced.testhost.conf"
  git -C "$d" init -q; git -C "$d" add -A
  git -C "$d" -c user.email=t@t -c user.name=t commit -qm init
  echo "$d"
}
# SELFDEV_HOME_ROOT keeps the fixture rows out of a real /home, which is also
# what stops bin/hardcoded-home-lint.sh flagging this file's expected strings.
HOMES="$T/homes"
run() { SELFDEV_HOME_ROOT="$HOMES" "$SCRIPT" widget --host testhost --repo "$1" "${@:2}"; }

echo "enrole-selfdev.test.sh"

echo "-- A. --check writes nothing and names every missing field"
C="$(mkclone a)"
OUT="$(run "$C" --check 2>&1)"; RC=$?
rc  "A1 exits 0 with only would-changes" 0 "$RC"
has "A2 names BATCH_JOB_NAME"   "$OUT" 'set BATCH_JOB_NAME="widget-nightly-batch"'
has "A3 names CRON_ACCOUNT"     "$OUT" 'set CRON_ACCOUNT="widget"'
has "A4 names SCHEDULER_SUBDIR" "$OUT" 'set SCHEDULER_SUBDIR=".scheduler"'
has "A5 names the row it would add" "$OUT" 'add row: widget|1|1|'
[ -z "$(git -C "$C" status --porcelain)" ] && ok "A6 tree is untouched" || bad "A6 --check wrote to the clone"

echo "-- B. --apply sets every field and adds ONE enabled row"
OUT="$(run "$C" --apply 2>&1)"; RC=$?
rc  "B1 exits 0" 0 "$RC"
has "B2 conf carries the job name" "$(cat "$C/schedule/widget.conf")" 'BATCH_JOB_NAME="widget-nightly-batch"'
has "B3 conf carries CRON_HOST"    "$(cat "$C/schedule/widget.conf")" 'CRON_HOST="testhost"'
ROWS="$(grep -c '^widget|' "$C/schedule/_paced.testhost.conf")"
[ "$ROWS" = 1 ] && ok "B4 exactly one row" || bad "B4 expected 1 row, got $ROWS"
has "B5 the row is enabled" "$(grep '^widget|' "$C/schedule/_paced.testhost.conf")" "widget|1|1|$HOMES/widget/Documents/Projects/scheduler/bin/scheduler-run widget batch"
has "B6 prints the undo command" "$OUT" 'undo: git -C'

echo "-- D. IDEMPOTENT: a second --apply changes nothing"
BEFORE="$(git -C "$C" diff)"
OUT="$(run "$C" --apply 2>&1)"; RC=$?
rc  "D1 exits 0" 0 "$RC"
has "D2 says it was already enrolled" "$OUT" "already enrolled (idempotent)"
[ "$BEFORE" = "$(git -C "$C" diff)" ] && ok "D3 the diff is byte-identical after a second run" || bad "D3 the second run changed the tree"
ROWS="$(grep -c '^widget|' "$C/schedule/_paced.testhost.conf")"
[ "$ROWS" = 1 ] && ok "D4 still exactly one row (no append-on-rerun)" || bad "D4 rows multiplied: $ROWS"

echo "-- E. REVERSIBLE: --retire disables the row and KEEPS it"
OUT="$(run "$C" --retire 2>&1)"; RC=$?
rc  "E1 exits 0" 0 "$RC"
has "E2 the row is now disabled" "$(grep '^widget|' "$C/schedule/_paced.testhost.conf")" 'widget|0|1|'
ROWS="$(grep -c '^widget|' "$C/schedule/_paced.testhost.conf")"
[ "$ROWS" = 1 ] && ok "E3 the row was kept, not deleted (deleting un-suppresses the fixed nightly line)" || bad "E3 the row was removed"
has "E4 the conf fields survive retirement" "$(cat "$C/schedule/widget.conf")" 'BATCH_JOB_NAME="widget-nightly-batch"'
OUT="$(run "$C" --apply 2>&1)"
has "E5 --apply re-arms the same row" "$(grep '^widget|' "$C/schedule/_paced.testhost.conf")" 'widget|1|1|'

echo "-- F. it refuses rather than half-writing"
OUT="$(run "$C" --apply --repo "$T/nope" 2>&1)"; RC=$?
rc  "F1 a missing clone exits 5" 5 "$RC"
C2="$(mkclone f)"
OUT="$("$SCRIPT" ghost --host testhost --repo "$C2" --check 2>&1)"; RC=$?
rc  "F2 an unregistered project exits 3" 3 "$RC"
has "F3 says registration is the missing act" "$OUT" "is not registered"
OUT="$(run "$C2" --check --host nosuchhost 2>&1)"; RC=$?
rc  "F4 a host with no _paced.<host>.conf exits 5" 5 "$RC"
has "F5 says why that matters" "$OUT" "another machine's rotation"
echo 'BATCH_MAX_TURNS="9"' >> "$C2/schedule/widget.conf"
OUT="$(run "$C2" --apply 2>&1)"; RC=$?
rc  "F6 an uncommitted edit to the conf it would rewrite exits 5" 5 "$RC"
has "F7 names the in-flight file" "$OUT" "schedule/widget.conf"

printf 'another-project|1|1|%s/another-project/x\n' "$HOMES" >> "$C2/schedule/_paced.testhost.conf"
git -C "$C2" checkout -q -- schedule/widget.conf
OUT="$(run "$C2" --apply 2>&1)"; RC=$?
rc  "F8 a foreign row added to the rotation exits 5" 5 "$RC"
has "F9 quotes the foreign line, not ours" "$OUT" "another-project|1|1|"

echo "-- G. the brief-location finding (the defect that hid behind a 404)"
C3="$(mkclone g)"
mkdir -p "$T/home/Documents/Projects/widget/.claude"
: > "$T/home/Documents/Projects/widget/.claude/FOCUS.md"
OUT="$(HOME="$T/home" run "$C3" --check 2>&1)"; RC=$?
has "G1 flags a brief under .claude/" "$OUT" "an unattended run can read it and CANNOT write it"
rc  "G2 a BAD row makes --check exit 1" 1 "$RC"
mkdir -p "$T/home/Documents/Projects/widget/.scheduler"
mv "$T/home/Documents/Projects/widget/.claude/FOCUS.md" "$T/home/Documents/Projects/widget/.scheduler/FOCUS.md"
OUT="$(HOME="$T/home" run "$C3" --check 2>&1)"; RC=$?
has "G3 accepts a brief under .scheduler/" "$OUT" "brief at .scheduler/FOCUS.md"
rc  "G4 and exits 0 again" 0 "$RC"

echo "-- H. the argument contract (cli-guard)"
"$SCRIPT" widget --not-a-real-flag >/dev/null 2>&1; rc "H1 unknown flag exits 2" 2 "$?"
"$SCRIPT" --help >/dev/null 2>&1;                   rc "H2 --help exits 0" 0 "$?"
"$SCRIPT" >/dev/null 2>&1;                          rc "H3 no project named exits 2" 2 "$?"

echo "-- I. --sync --on <h>: the host half is driven from here over ssh (realisateur#895)"
STUB="$T/stub"; mkdir -p "$STUB"
cat > "$STUB/ssh" <<'FAKE'
#!/usr/bin/env bash
a=(); while [ $# -gt 0 ]; do case "$1" in -o) shift 2 ;; *) a+=("$1"); shift ;; esac; done
echo "FAKESSH host=${a[0]}"
echo "FAKESSH cmd=${a[1]:-}"
case "${a[1]:-}" in
  *"dose 'widget' --apply"*)
    case "${a[0]}" in
      brokenhost) echo "BROKEN: crontab drifted"; exit 0 ;;
      failhost)   exit 3 ;;
      *)          echo "dose: converged"; exit 0 ;;
    esac
    ;;
  *) exit 1 ;;
esac
FAKE
chmod +x "$STUB/ssh"

Ci="$(mkclone i)"
OUT="$(SELFDEV_HOME_ROOT="$HOMES" SELFDEV_SSH_BIN="$STUB/ssh" \
        "$SCRIPT" widget --host testhost --apply --sync --on goodhost --repo "$Ci" 2>&1)"; RC=$?
rc  "I1 exits 0 on a converged remote dose"                0 "$RC"
has "I2 says which host it drove, and that it went over ssh" "$OUT" "on goodhost, driven over ssh"
has "I3 the ssh transport really fired"                       "$OUT" "FAKESSH host=goodhost"
has "I4 the remote call is dose, as the project's own account" "$OUT" "sudo -n -u 'widget' -H bash -lc \"dose 'widget' --apply\""
has "I5 reports convergence, naming the host"                  "$OUT" "crontab converged for widget on goodhost"

OUT="$(SELFDEV_HOME_ROOT="$HOMES" SELFDEV_SSH_BIN="$STUB/ssh" \
        "$SCRIPT" widget --host testhost --apply --sync --on brokenhost --repo "$Ci" 2>&1)"; RC=$?
rc  "I6 a BROKEN line from dose is a finding, not a silent OK" 1 "$RC"
has "I7 says to read the rows above"                            "$OUT" "printed BROKEN/BLIND/GAP lines"

OUT="$(SELFDEV_HOME_ROOT="$HOMES" SELFDEV_SSH_BIN="$STUB/ssh" \
        "$SCRIPT" widget --host testhost --apply --sync --on failhost --repo "$Ci" 2>&1)"; RC=$?
rc  "I8 a nonzero dose exit is a finding" 1 "$RC"
has "I9 names the exit code and the host" "$OUT" "dose widget --apply on failhost exited 3"

cat > "$STUB/ssh-dead" <<'FAKE'
#!/usr/bin/env bash
exit 255
FAKE
chmod +x "$STUB/ssh-dead"
OUT="$(SELFDEV_HOME_ROOT="$HOMES" SELFDEV_SSH_BIN="$STUB/ssh-dead" \
        "$SCRIPT" widget --host testhost --apply --sync --on ghost --repo "$Ci" 2>&1)"; RC=$?
rc  "I10 an unreachable target is a finding, not a crash" 1 "$RC"
has "I11 names the ssh rc"                                  "$OUT" "could not reach ghost over ssh (rc=255)"

echo "-- J. --host and --on never collide: --host still names the paced conf, --on the ssh target"
Cj="$(mkclone j)"
OUT="$(SELFDEV_SSH_BIN="$STUB/ssh" run "$Cj" --apply --sync --on goodhost 2>&1)"; RC=$?
rc  "J1 exits 0" 0 "$RC"
has "J2 the repo half wrote _paced.testhost.conf -- --host's job, untouched by --on" \
    "$(cat "$Cj/schedule/_paced.testhost.conf")" "widget|1|1|"
has "J3 the host half drove goodhost -- --on's job, untouched by --host" "$OUT" "FAKESSH host=goodhost"

echo
printf 'enrole-selfdev: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
