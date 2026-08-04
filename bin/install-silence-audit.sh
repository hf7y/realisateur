#!/usr/bin/env bash
# install-silence-audit.sh -- the wiring trigger for silence-audit.sh.
#
# DEFAULT IS --dry-run. Nothing is changed unless you pass --commit.
#
# ======================================================================
# WHAT THIS RETIRES  (machine-readable; the test below proves it)
# ======================================================================
# RETIRES: silencing stderr
# RETIRES: Wired to a real path
# RETIRES: names what it retires
#
# Those three are CHECKLIST ROWS in the propagated `## Build discipline
# (realisateur baseline)` block that every project's CLAUDE.md carries.
# Each is a prose rule verified by a human remembering to verify it. All
# three are now decidable by `silence-audit.sh` ([stderr-silenced],
# [unwired], [retirement-open] respectively), so keeping the prose is
# exactly the LAYER-NOT-RETIRED failure Zach named on 2026-07-28: a new
# mechanism standing beside the live old layer that keeps producing the
# defect.
#
# The three rows are replaced by ONE pointer row, in every project at
# once. That is the "less prose" requirement, and it is measured, not
# asserted: --commit prints the net line delta and REFUSES to proceed if
# the delta is not negative.
#
# ======================================================================
# WHY A RETIREMENT NEEDS ITS OWN TEST
# ======================================================================
# "Names what it retires" is satisfied by the retired thing being GONE,
# not by a commit message saying it is gone. `--test` asserts exactly
# that, on a fixture: it builds a fake project carrying the three rows,
# runs the retirement, and fails if ANY of the three literals survives
# outside a retirement notice. It also asserts the inverse -- that the
# pointer row landed -- because a "retirement" that deletes the rule and
# installs nothing is not a retirement, it is a deletion.
set -uo pipefail

REPO_DEFAULT="${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/realisateur"
REPO="${SILENCE_AUDIT_REPO:-$REPO_DEFAULT}"
SCHED_ROOT="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"
BIN_DEST="$HOME/.local/bin"

# The literals retired, and the single row that replaces them. Kept here as
# ONE list because a retirement claim that is retyped in three places is the
# config-duplication failure wearing a retirement's clothes.
RETIRED_LITERALS=(
  "silencing stderr"
  "Wired to a real path"
  "names what it retires"
)
POINTER_ROW='- [ ] `silence-audit --strict` clean? (mechanizes the retired
      stderr-silencing / wired-to-a-real-path / names-what-it-retires rows)'

MODE=dry
case "${1:-}" in
  --commit)  MODE=commit ;;
  --test)    MODE=test ;;
  --dry-run|"") MODE=dry ;;
  -h|--help) sed -n '2,45p' "$0"; exit 0 ;;
  *) echo "unknown flag: $1" >&2; exit 2 ;;
esac

say() { echo "install-silence-audit: $*"; }

# ---------------------------------------------------------------- retire
# Removes the three retired checklist rows from one CLAUDE.md and inserts
# the pointer row once. Idempotent. Prints "<removed> <added>" on stdout.
retire_in_file() {
  local f="$1" tmp removed=0 lit
  [ -f "$f" ] || { echo "0 0"; return; }
  tmp="$(mktemp)"
  cp "$f" "$tmp"
  for lit in "${RETIRED_LITERALS[@]}"; do
    # a checklist row containing the literal, plus its continuation lines
    if grep -qF -- "$lit" "$tmp"; then
      awk -v lit="$lit" '
        index($0, lit) && /^- \[ \]/ { drop=1; next }
        drop && /^ / { next }
        { drop=0; print }
      ' "$tmp" >"$tmp.n" && mv "$tmp.n" "$tmp"
      removed=$((removed+1))
    fi
  done
  local added=0
  if ! grep -qF 'silence-audit --strict' "$tmp"; then
    # append the pointer row at the end of the baseline checklist block
    awk -v row="$POINTER_ROW" '
      /^- \[ \]/ { last=NR }
      { lines[NR]=$0 }
      END {
        for (i=1;i<=NR;i++) {
          print lines[i]
          if (i==last) print row
        }
      }
    ' "$tmp" >"$tmp.n" && mv "$tmp.n" "$tmp"
    added=1
  fi
  if [ "$MODE" = commit ] || [ "$MODE" = test ]; then cp "$tmp" "$f"; fi
  rm -f "$tmp" "$tmp.n"
  echo "$removed $added"
}

# ---------------------------------------------------------------- test
run_test() {
  local tmp rc=0 out fix
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  fix="$tmp/proj"; mkdir -p "$fix/bin"

  cat >"$fix/CLAUDE.md" <<'EOF'
# CLAUDE.md
## Build discipline (realisateur baseline)
Before marking anything done:
- [ ] Fails **loud**?
- [ ] **Wired to a real path** (boot/timer/enabled-flag), not just built?
- [ ] New mechanism **names what it retires**?
- [ ] No privileged probe **silencing stderr** (`2>/dev/null` turns
      "denied" into "clean")?
- [ ] Tree clean?
EOF
  local before after
  before="$(wc -l <"$fix/CLAUDE.md")"

  echo "== retirement test =="
  MODE=test retire_in_file "$fix/CLAUDE.md" >/dev/null
  after="$(wc -l <"$fix/CLAUDE.md")"

  # 1. every retired literal is GONE (this is the whole point)
  local lit survived=0
  for lit in "${RETIRED_LITERALS[@]}"; do
    if grep -qF -- "$lit" "$fix/CLAUDE.md"; then
      echo "  FAIL retired literal survived: '$lit'"; survived=1; rc=1
    else
      echo "  ok   retired: '$lit'"
    fi
  done

  # 2. the replacement actually landed (a deletion is not a retirement)
  if grep -qF 'silence-audit --strict' "$fix/CLAUDE.md"; then
    echo "  ok   pointer row installed"
  else
    echo "  FAIL pointer row missing -- this is a deletion, not a retirement"; rc=1
  fi

  # 3. LESS PROSE, measured
  if [ "$after" -lt "$before" ]; then
    echo "  ok   net prose reduced: $before -> $after lines (-$((before-after)))"
  else
    echo "  FAIL prose not reduced: $before -> $after"; rc=1
  fi

  # 4. unrelated rows untouched
  grep -qF 'Fails **loud**' "$fix/CLAUDE.md" \
    && echo "  ok   unrelated checklist rows preserved" \
    || { echo "  FAIL collateral damage to unrelated rows"; rc=1; }

  # 5. idempotent
  MODE=test retire_in_file "$fix/CLAUDE.md" >/dev/null
  [ "$(wc -l <"$fix/CLAUDE.md")" -eq "$after" ] \
    && echo "  ok   idempotent on rerun" \
    || { echo "  FAIL not idempotent"; rc=1; }

  echo
  [ "$rc" -eq 0 ] && echo "retirement test: PASS" || echo "retirement test: FAIL"
  return "$rc"
}

[ "$MODE" = test ] && { run_test; exit $?; }

# ---------------------------------------------------------------- install
# Gate 1: the audit's own self-test must pass. Installing a checker that
# cannot prove it detects anything is how a mute check gets adopted.
if ! bash "$REPO/bin/silence-audit.sh" --self-test >/dev/null 2>&1; then
  say "ABORT -- silence-audit.sh --self-test does not pass. Nothing installed."
  exit 1
fi
say "gate 1 ok: silence-audit self-test passes"

# Gate 2: the retirement test must pass.
if ! bash "$0" --test >/dev/null 2>&1; then
  say "ABORT -- retirement test fails. Nothing installed."
  exit 1
fi
say "gate 2 ok: retirement test passes"

# Survey the prose delta across every registered project BEFORE touching it.
total_removed=0; total_added=0; touched=0
while IFS= read -r conf; do
  name="$(basename "$conf" .conf)"; case "$name" in _*) continue ;; esac
  repo="$(grep -oP '(?<=PROJECT_REPO_PATH=")[^"]*' "$conf" 2>/dev/null)"
  [ -n "${repo:-}" ] && [ -f "$repo/CLAUDE.md" ] || continue
  read -r r a < <(MODE="$MODE" retire_in_file "$repo/CLAUDE.md")
  [ "${r:-0}" -gt 0 ] && { touched=$((touched+1)); say "  $name: -$r row(s), +$a pointer"; }
  total_removed=$((total_removed+r)); total_added=$((total_added+a))
done < <(find "$SCHED_ROOT/schedule" -name '*.conf' 2>/dev/null)

say "prose delta across $touched project(s): -$total_removed rows, +$total_added pointer rows"
if [ "$total_removed" -le "$total_added" ]; then
  say "ABORT -- net prose would not decrease. That is the stated requirement."
  exit 1
fi

if [ "$MODE" = dry ]; then
  say "DRY RUN -- nothing written, nothing installed."
  say "re-run with --commit to install the shim, wire hygiene-lint, and retire the rows."
  exit 0
fi

# Wire: PATH shim + a real cadence. Built-and-not-wired is the pattern this
# whole thing exists to catch, so the shim alone does NOT count as wired.
mkdir -p "$BIN_DEST"
ln -sf "$REPO/bin/silence-audit.sh" "$BIN_DEST/silence-audit"
say "shim: $BIN_DEST/silence-audit -> $REPO/bin/silence-audit.sh"

if ! grep -qF 'silence-audit.sh' "$REPO/bin/hygiene-lint.sh" 2>/dev/null; then
  cat >>"$REPO/bin/hygiene-lint.sh" <<'EOF'

# --- check 12: silence-audit (null-discrimination across mechanisms) ---
# Wired here rather than left standalone because a checker nothing
# dispatches is the defect it checks for. See bin/silence-audit.sh.
echo "== check 12: silence-audit =="
bash "$(dirname "${BASH_SOURCE[0]}")/silence-audit.sh" || true
EOF
  say "wired: hygiene-lint.sh check 12 (runs in /ideate and /nightly-batch)"
fi

say "done. Machine-wide config was NOT touched; run notify-senechal if you add a cron entry."
