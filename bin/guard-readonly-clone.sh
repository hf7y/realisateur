#!/usr/bin/env bash
set -uo pipefail

CLI_NAME='guard-readonly-clone.sh'
CLI_SUMMARY="refuse a local commit into a self-dev account's read-only clone of scheduler/realisateur/senechal -- wire-selfdev-git.sh's read-only credentials stop a push but nothing stopped a commit, and wtul's scheduler dispatch clone diverged and dispatched stale code for 3 ticks before a human reset it by hand (hf7y/scheduler#321). Path-based, evaluated live at commit time: only a clone directly under \$PROJECTS/<name> where <name> != this account is refused; a scratch clone, a worktree, or anywhere else (CLAUDE.md rule 6's cross-repo draft-PR workflow) is untouched. Shares stamp-verb-build.sh's HOOK_DIR: one core.hooksPath slot, two independently-generated files (prepare-commit-msg, pre-commit)."
CLI_USAGE='  guard-readonly-clone.sh              --check (default): is this account guarded?
  guard-readonly-clone.sh --apply      install the commit hook for THIS account
  guard-readonly-clone.sh --retire     remove it (with --apply; --check alone prints what would go)'
CLI_FLAGS='--check --apply --retire'
CLI_POSITIONAL=none
CLI_EXITS='  0  this account is guarded, witnessed by running the hook
  1  findings: not wired, wired but unverified, or hooksPath owned elsewhere
  2  usage error'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

HOOK_DIR="${STAMP_HOOK_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/verb-stamp/hooks}"  # fixture-overridable, mirrors stamp-verb-build.sh
HOOK="$HOOK_DIR/pre-commit"
PROJECTS="${INSTALLE_PROJECTS:-$HOME/Documents/Projects}"

MODE=check; RETIRE=0
for a in "$@"; do
  case "$a" in
    --check)  MODE=check ;;
    --apply)  MODE=apply ;;
    --retire) RETIRE=1 ;;
  esac
done

PASS=0; GAPS=0; BAD=0
ok()  { printf '  ok    %s\n' "$*"; PASS=$((PASS+1)); }
gap() { printf '  gap   %s\n' "$*"; GAPS=$((GAPS+1)); }
bad() { printf '  bad   %s\n' "$*"; BAD=$((BAD+1)); }
act() { printf '  ..    %s\n' "$*"; }

write_hook() {  # generated, not shipped: a second copy in the bootstrap set rots; $PROJECTS is baked in at install time
  mkdir -p "$HOOK_DIR" || return 1
  cat > "$HOOK" <<EOF
#!/bin/sh
top="\$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
case "\$top" in
  "$PROJECTS"/*) ;;
  *) exit 0 ;;
esac
rel="\${top#"$PROJECTS"/}"
name="\${rel%%/*}"
[ "\$name" = "\$(id -un)" ] && exit 0
echo "REFUSED: \$top is read-only infrastructure, not \$(id -un)'s own project -- commit through a pull request against origin instead (hf7y/scheduler#321)" >&2
exit 1
EOF
  chmod 755 "$HOOK"
}

echo "== guard-readonly-clone ($MODE) -- $(id -un)@$(hostname -s 2>/dev/null || echo '?') =="
echo

cur="$(git config --global core.hooksPath 2>/dev/null)"; cfg_rc=$?  # same three-way read as stamp-verb-build.sh
if [ "$cfg_rc" -gt 1 ]; then
  bad "cannot read this account's global git config (git config exited $cfg_rc). Nothing was changed -- an unreadable config is not an empty one."
  echo; printf '%d ok, %d gap, %d bad\n' "$PASS" "$GAPS" "$BAD"
  exit 1
fi

if [ "$RETIRE" = 1 ]; then
  if [ ! -e "$HOOK" ]; then
    ok "nothing to retire: no $HOOK"
  elif [ "$MODE" != apply ]; then
    act "would remove $HOOK"
    act "not removed (--check). Re-run with --apply."
  else
    rm -f "$HOOK"
    [ -e "$HOOK" ] && bad "removed $HOOK but it is STILL present" || ok "guard retired: $HOOK removed"  # core.hooksPath itself is left alone; a sibling hook may still need it
  fi
  echo; printf '%d ok, %d gap, %d bad\n' "$PASS" "$GAPS" "$BAD"
  [ "$BAD" -eq 0 ] || exit 1
  exit 0
fi

case "$cur" in
  "$HOOK_DIR") ;;
  '') if [ "$MODE" != apply ]; then
        gap "core.hooksPath is unset -- this account is not guarded"
        act "would write $HOOK and point core.hooksPath at $HOOK_DIR"
        act "not installed (--check). Re-run with --apply."
        echo; printf '%d ok, %d gap, %d bad\n' "$PASS" "$GAPS" "$BAD"
        exit 1
      fi ;;
  *)  bad "core.hooksPath is already $cur, which this command does not own. Reconcile deliberately; nothing was changed."  # taking it over would silently disable whatever else it holds, same refusal stamp-verb-build.sh makes
      echo; printf '%d ok, %d gap, %d bad\n' "$PASS" "$GAPS" "$BAD"
      exit 1 ;;
esac

if [ "$MODE" = apply ]; then
  write_hook || { bad "could not write $HOOK"; echo; exit 1; }
  git config --global core.hooksPath "$HOOK_DIR"
fi

if [ -x "$HOOK" ] && [ "$(git config --global core.hooksPath 2>/dev/null || true)" = "$HOOK_DIR" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT  # only the outside-$PROJECTS case is safe to probe on a real host; the refusal case is bin/tests/guard-readonly-clone.test.sh's job, $PROJECTS sandboxed
  git init -q "$W/scratch-clone"
  git -C "$W/scratch-clone" config user.email test@example.com
  git -C "$W/scratch-clone" config user.name test
  if ( cd "$W/scratch-clone" && "$HOOK" ) >/dev/null 2>&1; then
    ok "the hook does not touch a clone outside \$PROJECTS (cross-repo draft-PR work stays possible)"
  else
    bad "the hook refused inside a clone OUTSIDE \$PROJECTS -- it would block sanctioned cross-repo work"
  fi
else
  gap "not wired: core.hooksPath is ${cur:-unset} and $HOOK is $([ -x "$HOOK" ] && echo present || echo absent)"
fi

echo
printf '%d ok, %d gap, %d bad\n' "$PASS" "$GAPS" "$BAD"
[ "$GAPS" -eq 0 ] && [ "$BAD" -eq 0 ] || exit 1
exit 0
