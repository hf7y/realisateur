#!/usr/bin/env bash
# path-provenance-audit.sh -- eight probes asking one question: can senechal
# name the owner and the live source of every executable this account can run?
#
# RUNNER: bin/tests/path-provenance-audit.test.sh
# GUARD-TEST: bin/tests/path-provenance-audit.test.sh
# GATE: strict
#
# TRAP: BLIND IS NEVER CLEAN. "I could not census this account" and "this
#   account is clean" are different answers; exit 2 is BLIND, never success.
# TRAP: `installe` maintains a manifest of what IT installed and cannot see
#   anything it did not. This asks who put a thing there, which is a
#   different question -- do not fold the two together.
# TRAP: the ratchet is a ceiling that may fall and may never rise. The
#   estate-wide clean run this once demanded was NEVER ONCE PASSABLE, and a
#   bar that cannot be met does not raise standards -- it retires a check.
#
# usage:  path-provenance-audit.sh [--strict] [--accept] [--quiet] [--json]
# exit:   0 no regression   1 REGRESSION against the ratchet

set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
RATCHET="$ROOT/bin/path-provenance-audit.ratchet"

CLI_NAME='path-provenance-audit.sh'
CLI_SUMMARY='can senechal name the owner and live source of every executable on this PATH?'
CLI_USAGE='  path-provenance-audit.sh            census, report, fail only on regression
  path-provenance-audit.sh --strict   also fail while the vision is unmet
  path-provenance-audit.sh --accept   record the current bars as the new floor
  path-provenance-audit.sh --json     the per-entry census, machine-readable
  path-provenance-audit.sh --prune    LIST the orphans it would remove
  path-provenance-audit.sh --prune --apply
                                      remove them (only entries whose source is gone)'
CLI_FLAGS='--strict --accept --quiet --json --prune --apply'
CLI_EXITS='  0  nothing regressed against the ratchet
  1  REGRESSION -- a check that used to pass no longer does, or a ceiling rose
  2  BLIND -- a probe could not be performed. NEVER "all clear"
  3  --strict, and the vision is not fully met (but nothing regressed)'
CLI_POSITIONAL=none
. "$ROOT/bin/lib/cli-guard.sh"
cli_guard "$@"

STRICT=0; ACCEPT=0; QUIET=0; JSON=0
for a in "$@"; do
  case "$a" in
    --strict) STRICT=1 ;;
    --accept) ACCEPT=1 ;;
    --quiet)  QUIET=1 ;;
    --json)   JSON=1 ;;
    --prune)  PRUNE=1 ;;
    --apply)  APPLY=1 ;;
  esac
done
PRUNE="${PRUNE:-0}"; APPLY="${APPLY:-0}"

HOME_DIR="${HOME:?path-provenance-audit: HOME is unset; there is no account to census}"
PROJECTS="${INSTALLE_PROJECTS:-$HOME_DIR/Documents/Projects}"
MANIFEST="${INSTALLE_MANIFEST:-${XDG_DATA_HOME:-$HOME_DIR/.local/share}/installe/manifest.tsv}"
SENECHAL_CONF="${SENECHAL_CONFIG:-${XDG_CONFIG_HOME:-$HOME_DIR/.config}/senechal/senechal.json}"

# Directories swept FILE BY FILE. Everything else under $HOME that is on PATH
# must match a toolchain shape below or it is itself a finding.
SWEPT_DIRS="$HOME_DIR/.local/bin $HOME_DIR/bin"

# --- host class -------------------------------------------------------------
# uid, not hostname: provisioned accounts are uid 3000-3099.
HOST_CLASS="${PATH_PROVENANCE_CLASS:-}"
if [ -z "$HOST_CLASS" ]; then
  _uid="$(id -u 2>/dev/null || echo 0)"
  if [ "$_uid" -ge 3000 ] && [ "$_uid" -le 3099 ]; then
    HOST_CLASS=provisioned
  else
    HOST_CLASS=daily
  fi
fi

# --- results ----------------------------------------------------------------
# Parallel arrays, not an associative array: one host in the estate still
# runs bash 3.2 (see bin/thermostat-wiring.sh, same constraint).
IDS=(); STATES=(); NOTES=()
record() { IDS+=("$1"); STATES+=("$2"); NOTES+=("$3"); }

# --- the census -------------------------------------------------------------
home_path_dirs() {
  local IFS=: d
  for d in $PATH; do
    [ -n "$d" ] || continue
    case "$d" in "$HOME_DIR"|"$HOME_DIR"/*) printf '%s\n' "$d" ;; esac
  done
}

# A directory whose whole contents one named manager owns and regenerates.
# Prints the manager's name, or nothing.
toolchain_owner() {
  case "$1" in
    */.nvm/versions/node/*/bin)   printf 'nvm' ;;
    */.rbenv/shims|*/.rbenv/bin)  printf 'rbenv' ;;
    */.pyenv/shims|*/.pyenv/bin)  printf 'pyenv' ;;
    */.rye/shims)                 printf 'rye' ;;
    */.cargo/bin)                 printf 'cargo' ;;
    */go/bin)                     printf 'go' ;;
    */.bun/bin)                   printf 'bun' ;;
    */.deno/bin)                  printf 'deno' ;;
    */.npm-global/bin)            printf 'npm' ;;
    */.local/share/pnpm)          printf 'pnpm' ;;
    */.local/share/uv/*)          printf 'uv' ;;
    */.local/share/verb-builds/*) printf 'verb-build' ;;
  esac
}

is_swept() {
  local d
  for d in $SWEPT_DIRS; do [ "$1" = "$d" ] && return 0; done
  return 1
}

manifest_target() {
  [ -f "$MANIFEST" ] || return 0
  awk -F'\t' -v n="$1" '$1 == n {print $2; exit}' "$MANIFEST"
}

# The generated-by declaration a shim writes about itself. install-shims.sh
# emits `# >>> realisateur-owned shim -- generated by bin/install-shims.sh.`
# and a `real="<abs path>"` line. Prints "<owner>\t<declared target>".
self_declaration() {
  local f="$1" hd owner tgt
  # Text only. Reading 4KB of an ELF binary through a command substitution
  # produced six "ignored null byte" warnings on the first live run, and a
  # binary cannot carry a generated-by header anyway.
  [ "$(head -c 2 -- "$f" 2>/dev/null)" = '#!' ] || return 0
  hd="$(head -c 4096 -- "$f" 2>/dev/null | tr -d '\000')" || return 0
  case "$hd" in
    *'GENERATED by'*|*'generated by'*|*'Generated by'*) : ;;
    *) return 0 ;;
  esac
  owner="$(printf '%s\n' "$hd" | sed -n 's/.*>>> \([a-z0-9_-]*\)-owned.*/\1/p' | head -1)"
  [ -n "$owner" ] || owner="$(printf '%s\n' "$hd" | sed -n 's/.*[Gg]enerated by \([a-z0-9_-]*\)[ /].*/\1/p' | head -1)"
  [ -n "$owner" ] || owner=unnamed
  tgt="$(sed -n 's/^real="\(\/.*\)"$/\1/p' "$f" 2>/dev/null | head -1)"
  printf '%s\t%s' "$owner" "$tgt"
}

# The project a path inside a checkout belongs to.
project_of() {
  case "$1" in
    "$PROJECTS"/*) local rest="${1#"$PROJECTS"/}"; printf '%s' "${rest%%/*}" ;;
    */verb-builds/*/*) local rest="${1#*/verb-builds/}"; rest="${rest#*/}"; printf '%s' "${rest%%/*}" ;;
  esac
}

# classify <path> -> "<state>\t<owner>\t<detail>"
classify() {
  local f="$1" name="${1##*/}" mtgt rtgt decl owner dtgt
  mtgt="$(manifest_target "$name")"
  rtgt=""
  if [ -L "$f" ]; then
    rtgt="$(readlink -f -- "$f" 2>/dev/null || true)"
    if [ -z "$rtgt" ] || [ ! -e "$rtgt" ]; then
      printf 'ORPHAN\t%s\tdangling symlink -> %s' "${mtgt:+installe}" "$(readlink -- "$f" 2>/dev/null)"
      return
    fi
  elif [ ! -e "$f" ]; then
    printf 'ORPHAN\t\tentry does not exist'; return
  fi

  if [ -n "$mtgt" ]; then
    if [ ! -e "$mtgt" ]; then
      printf 'ORPHAN\t%s\tinstalle manifest names a target that is gone: %s' "$(project_of "$mtgt")" "$mtgt"; return
    fi
    if [ -n "$rtgt" ] && [ "$rtgt" != "$(readlink -f -- "$mtgt" 2>/dev/null)" ]; then
      printf 'DRIFT\t%s\tmanifest says %s, resolves to %s' "$(project_of "$mtgt")" "$mtgt" "$rtgt"; return
    fi
    printf 'OWNED\t%s\tinstalle manifest' "$(project_of "$mtgt")"; return
  fi

  if [ -f "$f" ] && [ ! -L "$f" ]; then
    decl="$(self_declaration "$f")"
    if [ -n "$decl" ]; then
      owner="${decl%%	*}"; dtgt="${decl#*	}"
      if [ -n "$dtgt" ] && [ ! -e "$dtgt" ]; then
        printf 'ORPHAN\t%s\tgenerated shim delegates to a deleted source: %s' "$owner" "$dtgt"; return
      fi
      printf 'DECLARED\t%s\tself-declaring generated shim' "$owner"; return
    fi
  fi

  if [ -n "$rtgt" ]; then
    owner="$(project_of "$rtgt")"
    if [ -n "$owner" ]; then
      printf 'REPO-LINK\t%s\thand-made link into a checkout: %s' "$owner" "$rtgt"; return
    fi
    printf 'UNKNOWN\t\tsymlink -> %s, declared by nothing' "$rtgt"; return
  fi
  printf 'UNKNOWN\t\tno declaration anywhere'
}

# --- run the census ---------------------------------------------------------
DIRS_TOTAL=0; DIRS_UNATTRIBUTED=0; UNATTRIBUTED_LIST=""; UNATTRIBUTED_EXECS=0
ORPHAN_PATHS=""
N_TOTAL=0; N_OWNED=0; N_DECLARED=0; N_ORPHAN=0; N_DRIFT=0; N_REPOLINK=0; N_UNKNOWN=0
FINDING_LINES=""; CENSUS_JSON=""

# classify one swept entry and fold it into the running totals. Shared by the
# top-level sweep and the one-level descent into retired-*/ below.
sweep_entry() {
  local f="$1" disp="$2" st ow de
  N_TOTAL=$((N_TOTAL + 1))
  IFS=$'\t' read -r st ow de <<< "$(classify "$f")"
  case "$st" in
    OWNED)     N_OWNED=$((N_OWNED + 1)) ;;
    DECLARED)  N_DECLARED=$((N_DECLARED + 1)) ;;
    ORPHAN)    N_ORPHAN=$((N_ORPHAN + 1));   FINDING_LINES="$FINDING_LINES  ORPHAN    $disp  ($de)"$'\n'
               ORPHAN_PATHS="$ORPHAN_PATHS$f"$'\n' ;;
    DRIFT)     N_DRIFT=$((N_DRIFT + 1));     FINDING_LINES="$FINDING_LINES  DRIFT     $disp  ($de)"$'\n' ;;
    REPO-LINK) N_REPOLINK=$((N_REPOLINK + 1)) ;;
    UNKNOWN)   N_UNKNOWN=$((N_UNKNOWN + 1)) ;;
  esac
  CENSUS_JSON="$CENSUS_JSON{\"name\":\"$disp\",\"state\":\"$st\",\"owner\":\"$ow\"}
"
}

_seen_dirs=" "
while IFS= read -r d; do
  [ -n "$d" ] || continue
  case "$_seen_dirs" in *" $d "*) continue ;; esac   # a duplicate PATH entry
  _seen_dirs="$_seen_dirs$d "                        #   provides nothing new
  [ -d "$d" ] || continue
  DIRS_TOTAL=$((DIRS_TOTAL + 1))
  if [ -n "$(toolchain_owner "$d")" ]; then
    continue
  fi
  if ! is_swept "$d"; then
    DIRS_UNATTRIBUTED=$((DIRS_UNATTRIBUTED + 1))
    _n=0
    for f in "$d"/*; do [ -f "$f" ] && [ -x "$f" ] && _n=$((_n + 1)); done
    UNATTRIBUTED_EXECS=$((UNATTRIBUTED_EXECS + _n))
    UNATTRIBUTED_LIST="$UNATTRIBUTED_LIST ${d#"$HOME_DIR"/}($_n)"
    continue
  fi
  for f in "$d"/*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    if [ -d "$f" ] && [ ! -L "$f" ]; then
      # A plain subdirectory of a swept dir is not itself a PATH entry, so it
      # is skipped -- except retired-*/, a hand-made holding pen for shims
      #   [rest: vault:realisateur/guard-archaeology-20260817.md]
      case "${f##*/}" in
        retired-*)
          for rf in "$f"/*; do
            [ -e "$rf" ] || [ -L "$rf" ] || continue
            [ -d "$rf" ] && [ ! -L "$rf" ] && continue
            sweep_entry "$rf" "${f##*/}/${rf##*/}"
          done
          ;;
      esac
      continue
    fi
    sweep_entry "$f" "${f##*/}"
  done
done < <(home_path_dirs)

N_ACCOUNTED=$((N_OWNED + N_DECLARED))
N_UNDECLARED=$((N_REPOLINK + N_UNKNOWN))
CENSUSED=1
[ "$DIRS_TOTAL" -eq 0 ] && CENSUSED=0

# --- the ratchet ------------------------------------------------------------
RATCHETED=""; BOUND_UNDECLARED=""; BOUND_UNATTRIB=""
if [ -f "$RATCHET" ]; then
  while IFS= read -r line; do
    case "$line" in
      \#*|'') continue ;;
      "bound undeclared "*) BOUND_UNDECLARED="${line##* }" ;;
      "bound unattributed-dirs "*) BOUND_UNATTRIB="${line##* }" ;;
      *) RATCHETED="$RATCHETED ${line} " ;;
    esac
  done < "$RATCHET"
fi
in_ratchet() { case " $RATCHETED " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# --- the eight checks -------------------------------------------------------

# 1. dirs -- every PATH directory under $HOME is attributable.
if [ "$CENSUSED" = 0 ]; then
  record dirs BLIND 'no PATH entry lies under this HOME -- nothing to census'
elif [ "$DIRS_UNATTRIBUTED" -eq 0 ]; then
  record dirs PASS "all $DIRS_TOTAL PATH dir(s) under HOME are a known toolchain or a swept estate dir"
else
  record dirs UNMET "$DIRS_UNATTRIBUTED of $DIRS_TOTAL PATH dir(s) belong to no known toolchain and are swept by nothing:$UNATTRIBUTED_LIST"
fi

# 2. noorphan -- ABSOLUTE on every host class. This is the #101 defect.
if [ "$CENSUSED" = 0 ]; then
  record noorphan BLIND 'nothing censused'
elif [ "$N_ORPHAN" -eq 0 ]; then
  record noorphan PASS "no PATH entry delegates to a deleted source ($N_TOTAL swept)"
else
  record noorphan UNMET "$N_ORPHAN entr(ies) delegate to a source that no longer exists"
fi

# 3. nodrift -- ABSOLUTE on every host class.
if [ "$CENSUSED" = 0 ]; then
  record nodrift BLIND 'nothing censused'
elif [ ! -f "$MANIFEST" ]; then
  record nodrift UNMET 'no installe manifest on this account -- nothing declares what it installed'
elif [ "$N_DRIFT" -eq 0 ]; then
  record nodrift PASS 'every installe-owned entry resolves where the manifest says'
else
  record nodrift UNMET "$N_DRIFT entr(ies) resolve somewhere other than the manifest target"
fi

# 4. coverage -- THE ASYMMETRIC CHECK. Different predicate per host class, and
#    the reason this file is not one bar applied everywhere.
if [ "$CENSUSED" = 0 ]; then
  record coverage BLIND 'nothing censused'
elif [ "$HOST_CLASS" = provisioned ]; then
  if [ "$N_UNDECLARED" -eq 0 ] && [ "$N_TOTAL" -gt 0 ]; then
    record coverage PASS "provisioned account: $N_ACCOUNTED/$N_TOTAL declared (bar is 100%)"
  else
    record coverage UNMET "provisioned account: $N_ACCOUNTED/$N_TOTAL declared, $N_UNDECLARED undeclared. The bar here is 100% -- this account was created from nothing, so every name on it arrived through a provisioner."
  fi
else
  if [ -z "$BOUND_UNDECLARED" ]; then
    record coverage UNMET "daily-driver account: $N_ACCOUNTED/$N_TOTAL declared, $N_UNDECLARED undeclared ($N_REPOLINK repo-link, $N_UNKNOWN unknown). No ceiling recorded yet -- run --accept to set the floor this debt may only fall from."
  elif [ "$N_UNDECLARED" -le "$BOUND_UNDECLARED" ]; then
    record coverage PASS "daily-driver account: $N_UNDECLARED undeclared <= ceiling $BOUND_UNDECLARED ($N_ACCOUNTED/$N_TOTAL declared)"
  else
    record coverage UNMET "daily-driver account: $N_UNDECLARED undeclared, ceiling is $BOUND_UNDECLARED -- something new arrived on PATH that nothing declared"
  fi
fi

# 5. registry -- is the provenance record something SENECHAL can read?
#    installe's manifest is per-account, untracked, and named in no registry,
#    so it answers the question for whoever is logged in and for nobody else.
if [ ! -f "$SENECHAL_CONF" ]; then
  record registry UNMET "no senechal config at ${SENECHAL_CONF#"$HOME_DIR"/} -- this account's PATH provenance is recorded nowhere senechal reads"
elif grep -q 'path-provenance\|installe/manifest' "$SENECHAL_CONF" 2>/dev/null; then
  record registry PASS "senechal's config names a PATH provenance record"
else
  record registry UNMET "senechal.json's estate.footprint names no PATH provenance record; installe's manifest.tsv is per-account and untracked, so senechal cannot read it for any account but this one"
fi

# 6. fleetview -- can the provisioned class be measured AT ALL from a host
#    that has senechal on it? Deliberately NOT modelled as BLIND: the probe
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
_self="$(cd "$HOME_DIR" 2>/dev/null && pwd -P)"
_fleet_readable=0; _fleet_total=0
for _h in "$HOME_DIR/../"*; do
  [ -d "$_h" ] || continue
  [ "$(cd "$_h" 2>/dev/null && pwd -P)" = "$_self" ] && continue
  _fleet_total=$((_fleet_total + 1))
  [ -r "$_h/.local/bin" ] && [ -x "$_h/.local/bin" ] && _fleet_readable=$((_fleet_readable + 1))
done
if [ "$_fleet_total" -eq 0 ]; then
  record fleetview UNMET "no other account on this host exposes a PATH directory to census, and senechal holds no remote census of the provisioned accounts (hf7y/senechal#111: remote_hosts contains only dexter; monkey carries all ten uid 3000-3009 accounts)"
elif [ "$_fleet_readable" -eq "$_fleet_total" ]; then
  record fleetview PASS "$_fleet_readable/$_fleet_total sibling account PATH dirs are censusable from here"
else
  record fleetview UNMET "$_fleet_readable of $_fleet_total sibling account PATH dirs are readable from here -- the provisioned class, where the bar is 100%, is the class senechal can least see"
fi

# 7. sweepwired -- does anything RUN this, or is it another hand-run guard?
#    A guard nothing runs is documentation with an exit code (the phrasing is
#    bin/tests/guard-estate.test.sh's, and its check B is the same assertion).
_wired=""
for _c in "$HOME_DIR/.config/systemd/user" "$HOME_DIR/.config/autostart"; do
  [ -d "$_c" ] || continue
  grep -rl 'path-provenance' "$_c" >/dev/null 2>&1 && _wired="$_wired $_c"
done
if command -v crontab >/dev/null 2>&1 && crontab -l 2>/dev/null | grep -q 'path-provenance'; then
  _wired="$_wired crontab"
fi
if [ -n "$_wired" ]; then
  record sweepwired PASS "run automatically by:$_wired"
else
  record sweepwired UNMET 'nothing on this host runs this sweep on a clock -- no timer, no autostart, no crontab line. senechal/health/estate-health.sh is the natural home.'
fi

# 8. noticesabsorbed -- installe files a tracker notice per install (senechal
#    #118..#136 today, nineteen of them in one minute). A notice is a message,
#    not a registry: nothing absorbs them, which is hf7y/senechal#29 exactly.
if ! command -v gh >/dev/null 2>&1; then
  record noticesabsorbed BLIND 'gh is not on PATH -- cannot read senechal'\''s tracker'
elif ! _raw="$(gh issue list --repo hf7y/senechal --state open --limit 200 --json title 2>/dev/null)"; then
  record noticesabsorbed BLIND 'gh could not read hf7y/senechal'
else
  _n="$(printf '%s' "$_raw" | grep -o '"title":"installe: ' | wc -l | tr -d ' ')"
  if [ "$_n" -eq 0 ]; then
    record noticesabsorbed PASS 'no installe notice is sitting unabsorbed on the tracker'
  else
    record noticesabsorbed UNMET "$_n open installe notice(s) on hf7y/senechal have been filed and absorbed into no registry (hf7y/senechal#29)"
  fi
fi

# --- verdict ----------------------------------------------------------------
pass=0; unmet=0; blind=0; regressed=""; blindlist=""
for i in "${!IDS[@]}"; do
  case "${STATES[$i]}" in
    PASS)  pass=$((pass + 1)) ;;
    UNMET) unmet=$((unmet + 1)); in_ratchet "${IDS[$i]}" && regressed="$regressed ${IDS[$i]}" ;;
    BLIND) blind=$((blind + 1)); blindlist="$blindlist ${IDS[$i]}" ;;
  esac
done
total=${#IDS[@]}

# A ceiling that ROSE is a regression even when every check still passes:
# it is how the undeclared set would otherwise grow one entry at a time.
if [ -n "$BOUND_UNDECLARED" ] && [ "$CENSUSED" = 1 ] && [ "$N_UNDECLARED" -gt "$BOUND_UNDECLARED" ]; then
  regressed="$regressed undeclared-ceiling"
fi

# --prune: remove entries whose SOURCE is gone. The predicate is re-evaluated
# here, entry by entry, rather than trusting the list the sweep built -- and it
# only ever removes what classify() still calls ORPHAN.
if [ "$PRUNE" = 1 ]; then
  n_gone=0; n_kept=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    st="$(classify "$f" | cut -f1)"
    if [ "$st" != ORPHAN ]; then
      printf '  kept    %s (no longer an orphan: %s)\n' "$f" "$st"; n_kept=$((n_kept + 1)); continue
    fi
    case "$f" in
      "$HOME_DIR"/*) ;;
      *) printf '  kept    %s (outside HOME -- this prunes only the account it runs as)\n' "$f"; n_kept=$((n_kept + 1)); continue ;;
    esac
    if [ "$APPLY" = 1 ]; then
      if rm -f -- "$f"; then printf '  removed %s\n' "$f"; n_gone=$((n_gone + 1))
      else printf '  BAD     could not remove %s\n' "$f"; n_kept=$((n_kept + 1)); fi
    else
      printf '  would   remove %s\n' "$f"; n_gone=$((n_gone + 1))
    fi
  done <<< "$ORPHAN_PATHS"
  if [ "$APPLY" = 1 ]; then printf 'path-provenance-audit --prune: %s removed, %s kept\n' "$n_gone" "$n_kept"
  else printf 'path-provenance-audit --prune: %s would go, %s kept. Re-run with --apply.\n' "$n_gone" "$n_kept"; fi
  exit 0
fi

if [ "$JSON" = 1 ]; then
  printf '%s' "$CENSUS_JSON" | sed '/^$/d'
fi

if [ "$QUIET" = 0 ] && [ "$JSON" = 0 ]; then
  printf 'path-provenance-audit -- %s\n' "$(date '+%Y-%m-%d %H:%M')"
  printf '  account class: %s\n\n' "$HOST_CLASS"
  # BLIND rows print FIRST, above everything. guard-estate.test.sh check E2
  # exists because closeout-lint put "13 worktrees NOT examined" one line
  # above twelve false alarms; an admission under the noise is not an
  # admission.
  for i in "${!IDS[@]}"; do
    [ "${STATES[$i]}" = BLIND ] && printf '  BLIND  %-16s %s\n' "${IDS[$i]}" "${NOTES[$i]}"
  done
  [ "$blind" -gt 0 ] && printf '\n'
  for i in "${!IDS[@]}"; do
    [ "${STATES[$i]}" = BLIND ] && continue
    mark=' '; in_ratchet "${IDS[$i]}" && mark='*'
    printf '  %s%-6s %-16s %s\n' "$mark" "${STATES[$i]}" "${IDS[$i]}" "${NOTES[$i]}"
  done
  printf '\n  (* = held by the ratchet; regressing one of these fails the build)\n'
  if [ "$CENSUSED" = 1 ]; then
    printf '\n  CENSUS of %s swept entr(ies) across %s PATH dir(s) under HOME:\n' "$N_TOTAL" "$DIRS_TOTAL"
    printf '    accounted  %3s  (owned %s, self-declaring %s)\n' "$N_ACCOUNTED" "$N_OWNED" "$N_DECLARED"
    printf '    undeclared %3s  (repo-link %s, unknown %s)\n' "$N_UNDECLARED" "$N_REPOLINK" "$N_UNKNOWN"
    printf '    broken     %3s  (orphan %s, drift %s)\n' "$((N_ORPHAN + N_DRIFT))" "$N_ORPHAN" "$N_DRIFT"
    if [ "$DIRS_UNATTRIBUTED" -gt 0 ]; then
      printf '    plus %s executable(s) in %s PATH dir(s) nothing sweeps at all\n' \
        "$UNATTRIBUTED_EXECS" "$DIRS_UNATTRIBUTED"
    fi
    if [ "$N_TOTAL" -gt 0 ]; then
      printf '\n  ACCOUNTED FOR: %s%% (%s of %s) -- target on a %s account: %s\n' \
        "$((N_ACCOUNTED * 100 / N_TOTAL))" "$N_ACCOUNTED" "$N_TOTAL" "$HOST_CLASS" \
        "$([ "$HOST_CLASS" = provisioned ] && echo '100%' || echo "undeclared <= ${BOUND_UNDECLARED:-(unset)} and falling")"
    fi
  fi
  [ -n "$FINDING_LINES" ] && printf '\n%s' "$FINDING_LINES"
  printf '\n'
fi

# --accept: raise, or refuse. There is no flag that lowers a ratchet -- edit
# the file by hand and defend it in the diff.
if [ "$ACCEPT" = 1 ]; then
  if [ "$CENSUSED" = 0 ]; then
    echo "path-provenance-audit: REFUSED: cannot accept a floor from a run that censused nothing" >&2
    exit 2
  fi
  if [ -n "$regressed" ]; then
    echo "path-provenance-audit: REFUSED: cannot accept while$regressed is regressed" >&2
    exit 1
  fi
  _newbound="$N_UNDECLARED"
  if [ -n "$BOUND_UNDECLARED" ] && [ "$BOUND_UNDECLARED" -lt "$_newbound" ]; then
    _newbound="$BOUND_UNDECLARED"
  fi
  {
    echo "# path-provenance-audit.ratchet -- the bars that were met when accepted."
    echo "# Raised by --accept, never lowered by any flag. See bin/path-provenance-audit.sh."
    echo "# accepted $(date -Is) on a $HOST_CLASS account"
    echo "bound undeclared $_newbound"
    for i in "${!IDS[@]}"; do
      [ "${STATES[$i]}" = PASS ] && echo "${IDS[$i]}"
      in_ratchet "${IDS[$i]}" && [ "${STATES[$i]}" != PASS ] && echo "${IDS[$i]}"
    done | sort -u
  } > "$RATCHET"
  echo "path-provenance-audit: ratchet now holds $pass of $total checks, undeclared ceiling $_newbound"
  exit 0
fi

# ORDER: A POSITIVE FINDING OUTRANKS AN INABILITY TO SEE SOMETHING ELSE.
# Both are non-zero, so neither grades as clean either way -- but if BLIND
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
if [ -n "$regressed" ]; then
  echo "path-provenance-audit: REGRESSION:$regressed held when the ratchet was accepted." >&2
  [ "$blind" -gt 0 ] && echo "path-provenance-audit: (also BLIND on:$blindlist)" >&2
  exit 1
fi

# ANY BLIND, not merely a blind on a ratcheted check. bin/thermostat-wiring.sh
# tolerates the unratcheted case on the argument that it costs nothing to be
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
if [ "$blind" -gt 0 ]; then
  echo "path-provenance-audit: BLIND on:$blindlist" >&2
  echo "path-provenance-audit: this is 'I could not look', NOT 'nothing is wrong'." >&2
  exit 2
fi

echo "path-provenance-audit: $pass/$total met, $((total - pass)) to go -- no regression"
if [ "$STRICT" = 1 ] && [ "$unmet" != 0 ]; then
  echo "path-provenance-audit: --strict: senechal does not yet own everything on this PATH" >&2
  exit 3
fi
exit 0
