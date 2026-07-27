#!/usr/bin/env bash
# hygiene-lint.sh -- offline-first (zero AI) build-hygiene scan across every
# scheduler-registered project, realisateur's third mechanical survey
# alongside bin/ecosystem-survey.sh (ecosystem health) and
# bin/incubation-audit.sh (graduation signals). Same discipline as both and
# as scheduler's docs/offline-first-checks.md: gather real signals with plain
# git/grep, surface them, and leave the JUDGMENT to a human or an AI reading
# the output -- this script never fixes anything and never decides a finding
# is real; a secret-looking string or a tracked binary might be intentional.
#
# It checks for the recurring build/deploy failure patterns distilled in
# realisateur's BUILD-DISCIPLINE.md (itself generalized from
# crt/DEV-DISCIPLINE-RETROSPECTIVE-2026-07-23.md): secrets in tracked files,
# build debris tracked as source, finished-but-uncommitted work, missing exec
# bits, silent-pipeline smells, single-value config duplication, stamped-
# checklist drift, stale `verified <date>` claims, and (once, ecosystem-wide)
# task-shaped entries rotting in scheduler's BLOCKERS.md.
#
# Usage:
#   hygiene-lint.sh            scan every registered project, print findings
#   hygiene-lint.sh <name>...  scan only the named project(s)
#                              (skips the ecosystem-wide BLOCKERS.md check)
#
# Env overrides (used by the tests/fixtures, not normally set):
#   STALE_DAYS=7    age at which a `verified <date>` stamp is flagged
#   BLOCKERS_MD=... path to the BLOCKERS.md to scan
#
# Known false-positive class, left in deliberately: BUILD-DISCIPLINE.md's own
# prose DEFINES the `# verified <date> via <cmd>` format, so its example line
# ages like a real claim. Same stance as senechal's base64 test fixture --
# a documented recurring FLAG beats a special case that could hide a real one.
#
# Exit status is always 0 -- findings are signals, not build failures (same
# stance as ecosystem-survey.sh). Grep for "FLAG" in the output to gate on it.
set -uo pipefail

SCHED_ROOT="/home/zach/Documents/Project Archive/scheduler"

# --- discover registered projects (same loop as ecosystem-survey.sh) --------
want=("$@")
projects=()
for conf in "$SCHED_ROOT"/schedule/*.conf; do
  name="$(basename "$conf" .conf)"
  case "$name" in _*) continue ;; esac
  grep -q '^PROJECT_REPO_PATH=' "$conf" || continue
  if [ "${#want[@]}" -gt 0 ]; then
    skip=1; for w in "${want[@]}"; do [ "$w" = "$name" ] && skip=0; done
    [ "$skip" -eq 1 ] && continue
  fi
  projects+=("$name")
done

echo "hygiene-lint -- $(date '+%Y-%m-%d %H:%M')"
echo "(offline-first: no claude calls -- findings are SIGNALS, not verdicts;"
echo " an intentional binary or a test fixture will show up here. A human/AI"
echo " decides what's real. See realisateur/BUILD-DISCIPLINE.md for the rules."
echo " Grep 'FLAG' to count; this script never edits or fixes anything.)"
echo
echo "== scanning ${#projects[@]} project(s): $(printf '%s,' "${projects[@]}" | sed 's/,$//') =="

total_flags=0

# Baseline checklist row count, read from the ONE source (BUILD-DISCIPLINE.md's
# own "## Build discipline (realisateur baseline" block) rather than retyped
# here -- check 7b compares each project's stamped copy against it.
BD_MD="$(cd "$(dirname "$0")/.." && pwd)/BUILD-DISCIPLINE.md"
BASELINE_ROWS=0
if [ -f "$BD_MD" ]; then
  BASELINE_ROWS="$(awk '/^## Build discipline \(realisateur baseline/{f=1} f&&/^- \[ \]/{c++} END{print c+0}' "$BD_MD")"
fi

for name in "${projects[@]}"; do
  conf="$SCHED_ROOT/schedule/$name.conf"
  repo="$(grep -oP '(?<=PROJECT_REPO_PATH=")[^"]*' "$conf")"
  echo
  echo "############################################################"
  echo "# $name  ($repo)"
  if [ ! -d "$repo/.git" ]; then
    echo "  (no git repo at that path -- skipped)"
    continue
  fi

  n=0  # per-project flag count
  flag() { echo "  FLAG [$1] $2"; n=$((n+1)); }

  # -- tracked files list, reused across checks --
  tracked="$(git -C "$repo" ls-files 2>/dev/null)"

  # 1. SECRETS: tracked files whose NAME looks like a credential/key -----------
  # "secret(s)" must be followed by a non-letter so it can't match "secretary".
  secre='(^|/)([^/]*(secrets?([^a-z]|$)|credential|creds|passwd|apikey|api[_-]key)[^/]*|id_rsa|.*\.(pem|key|p12|pfx|keystore))$'
  # Drop obvious templates -- an *.example/*.sample/*.template secret file is
  # the CORRECT way to ship a config shape without the real value.
  tracked_sec="$(echo "$tracked" | grep -vE '\.(example|sample|template|dist)$')"
  echo "$tracked_sec" | grep -iE "$secre" \
    | while read -r f; do [ -n "$f" ] && echo "  FLAG [secret-file] tracked: $f"; done
  sfiles="$(echo "$tracked_sec" | grep -icE "$secre")"
  [ "${sfiles:-0}" -gt 0 ] && n=$((n+sfiles))

  # 1b. SECRETS: high-signal password/token assignments inside tracked TEXT ----
  # Limit to text files git knows, cap matches so a fixture file can't flood.
  sec_hits="$(git -C "$repo" grep -InE \
      '(password|passwd|secret|api[_-]?key|access[_-]?token|bearer)[[:space:]]*[:=][[:space:]]*.?[A-Za-z0-9/+_-]{12,}' \
      -- . ':(exclude)*.md' ':(exclude)tests/*' ':(exclude)test/*' 2>/dev/null | head -8)"
  if [ -n "$sec_hits" ]; then
    echo "$sec_hits" | while IFS= read -r line; do echo "  FLAG [secret-value] $line"; done
    n=$((n + $(echo "$sec_hits" | grep -c .) ))
  fi

  # 2. BUILD DEBRIS tracked as source (disk images, firmware, archives) --------
  echo "$tracked" | grep -iE '\.(img|img\.xz|img\.gz|iso|efi|dmg|deb|rpm|apk|exe|msi|zip|tar|tar\.gz|tgz|bin)$' \
    | while read -r f; do [ -n "$f" ] && echo "  FLAG [debris] tracked binary/artifact: $f"; done
  dcount="$(echo "$tracked" | grep -icE '\.(img|img\.xz|img\.gz|iso|efi|dmg|deb|rpm|apk|exe|msi|zip|tar|tar\.gz|tgz|bin)$')"
  [ "${dcount:-0}" -gt 0 ] && n=$((n+dcount))

  # 3. FINISHED-BUT-UNCOMMITTED: untracked scripts sitting in bin/ -------------
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in bin/*|*/bin/*) echo "  FLAG [uncommitted] untracked script in bin/: $f"; n=$((n+1)) ;; esac
  done < <(git -C "$repo" ls-files --others --exclude-standard 2>/dev/null | grep -iE '\.(sh|py|pl|rb|js|ts)$')

  # 4. MISSING EXEC BIT: tracked script with a shebang stored non-executable ---
  # git tracks mode: 100644 = non-exec, 100755 = exec. A shebang'd script that
  # is 100644 silently fails to launch (crt hit this twice).
  # Scoped to bin/ -- scripts meant to be *launched* directly (the crt bug
  # class). Test files usually run via a runner, so a non-exec test isn't this.
  while read -r mode _ _ path; do
    case "$mode" in
      100644)
        case "$path" in
          bin/*.sh|bin/*.py|bin/*.pl|bin/*.rb)
            first="$(git -C "$repo" show ":$path" 2>/dev/null | head -c 2)"
            [ "$first" = "#!" ] && { echo "  FLAG [exec-bit] tracked non-executable but has shebang: $path"; n=$((n+1)); }
            ;;
        esac
        ;;
    esac
  done < <(git -C "$repo" ls-files -s 2>/dev/null)

  # 5. SILENT-PIPELINE SMELL: pipefail + an audio/stream tool that SIGPIPEs -----
  # (the exact crt stt-feed.sh bug: pipefail made every arecord|sox pipeline
  # register as failed and silently drop output). Heuristic -- flags for review.
  for sh in $(echo "$tracked" | grep -E '\.sh$' | grep -vE '(^|/)tests?/'); do
    body="$(git -C "$repo" show ":$sh" 2>/dev/null)"
    # Skip this linter itself: it names the audio tools inside its own
    # detection regex, which would otherwise self-flag. Any script that
    # emits the FLAG marker is a silent-pipe *detector*, not a target.
    if echo "$body" | grep -q 'pipefail' \
       && echo "$body" | grep -qE '\b(arecord|aplay|sox|ffmpeg|parec|pacat)\b' \
       && ! echo "$body" | grep -qF 'FLAG [silent-pipe]'; then
      echo "  FLAG [silent-pipe] pipefail + audio/stream pipe (SIGPIPE guard?): $sh"
      n=$((n+1))
    fi
  done

  # 6. CONFIG DUPLICATION: a 4-digit port hardcoded across >=3 tracked files ---
  # Light heuristic for the "same value retyped everywhere" pattern.
  git -C "$repo" grep -hoE ':[0-9]{4}\b|\bport[[:space:]]*[=:][[:space:]]*[0-9]{4}\b' -- . 2>/dev/null \
    | grep -oE '[0-9]{4}' | sort | uniq -c | sort -rn | \
    while read -r cnt port; do
      [ -z "$port" ] && continue
      files="$(git -C "$repo" grep -lE "[:= ]$port\b" -- . 2>/dev/null | wc -l)"
      [ "${files:-0}" -ge 3 ] && echo "  NOTE [config-dup] port $port appears in $files tracked files (single-source it?)"
    done

  # 9. DISPATCH PARITY: a mechanism wired into SOME command files, not all ----
  # BUILD-DISCIPLINE pattern 13's partial-wiring case. Pattern 13 proper is a
  # decision recorded where NOTHING dispatches from; this is the sibling that
  # looks done and isn't -- recorded on the dispatch path you happened to be
  # editing, missing from the one that actually runs unattended.
  #
  # Live case 2026-07-26: precipitation-scan.sh was wired into
  # ecosystem-survey.sh and documented in .claude/commands/ideate.md, but NOT
  # in nightly-batch.md -- so every unattended pass printed promotion-signal
  # reports with no doctrine attached, which is exactly the run with no human
  # present to catch a false positive. Same shape as the .claude/->.scheduler/
  # trace two days earlier.
  #
  # Rule: a script under the project's own bin/ that some command file names
  # should be named by ALL of them. Advisory (NOTE) -- asymmetry is sometimes
  # deliberate (an interactive-only tool), and this script never decides.
  cmd_dir="$repo/.claude/commands"
  if [ -d "$cmd_dir" ]; then
    cmd_files=(); while IFS= read -r c; do cmd_files+=("$c"); done < <(find "$cmd_dir" -maxdepth 1 -name '*.md' | sort)
    if [ "${#cmd_files[@]}" -ge 2 ]; then
      while IFS= read -r script; do
        [ -n "$script" ] || continue
        base="$(basename "$script")"
        naming=(); missing=()
        for c in "${cmd_files[@]}"; do
          if grep -q -- "$base" "$c"; then naming+=("$(basename "$c")"); else missing+=("$(basename "$c")"); fi
        done
        # only interesting if SOME name it and SOME don't
        if [ "${#naming[@]}" -gt 0 ] && [ "${#missing[@]}" -gt 0 ]; then
          echo "  NOTE [dispatch-parity] $base named in $(printf '%s,' "${naming[@]}" | sed 's/,$//') but NOT in $(printf '%s,' "${missing[@]}" | sed 's/,$//')"
        fi
      done < <(git -C "$repo" ls-files 'bin/*.sh' 2>/dev/null)
    fi
  fi

  # 7. BUILD-DISCIPLINE checklist present in CLAUDE.md? ------------------------
  if echo "$tracked" | grep -qx 'CLAUDE.md'; then
    if ! git -C "$repo" grep -qi 'Build discipline' -- CLAUDE.md 2>/dev/null; then
      echo "  NOTE [no-checklist] CLAUDE.md exists but lacks the build-discipline checklist"
    fi
  else
    echo "  NOTE [no-claude-md] no root CLAUDE.md tracked"
  fi

  # 7b. STAMPED-CHECKLIST DRIFT ------------------------------------------------
  # BUILD-DISCIPLINE.md's baseline checklist is COPIED into each project's
  # CLAUDE.md at scaffold time; when the baseline gains a row, every stamped
  # copy silently lags and nothing detects it (incident: three rows added
  # 2026-07-25, nothing noticed). Compare row counts, not text -- a project
  # may legitimately append its OWN rows, so only a SHORTFALL is reported.
  if [ "${BASELINE_ROWS:-0}" -gt 0 ] && echo "$tracked" | grep -qx 'CLAUDE.md'; then
    have="$(git -C "$repo" show ":CLAUDE.md" 2>/dev/null \
            | awk '/^## Build discipline/{f=1} f&&/^- \[ \]/{c++} END{print c+0}')"
    if [ "$have" -gt 0 ] && [ "$have" -lt "$BASELINE_ROWS" ]; then
      echo "  NOTE [checklist-drift] CLAUDE.md checklist has $have row(s), baseline has $BASELINE_ROWS -- restamp from BUILD-DISCIPLINE.md"
    fi
  fi

  # 7c. UNWIRED DEPLOY KEY ------------------------------------------------------
  # A repo whose origin is a bare `git@github.com:` URL while a matching
  # deploy key + ssh alias ALREADY EXIST for it. The key was built and never
  # wired, so every push falls through to the passphrase-protected default
  # identity: interactive sessions get prompted, and an UNATTENDED run blocks
  # on a passphrase prompt nobody is there to answer -- a hang that reads
  # like a network error.
  #
  # Incident (2026-07-26): restamp-discipline.sh --apply pushed to 17 repos
  # and spammed Zach with password prompts. Four of the five SSH repos had a
  # deploy-key alias sitting unused in ~/.ssh/config; `scheduler`, the one
  # that DID use its alias, was silent. This is the build-but-don't-wire
  # pattern applied to credentials.
  #
  # Deliberately checks only for an alias that exists -- it never proposes
  # creating a key, which is a credential decision, not a lint's call.
  origin_url="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
  case "$origin_url" in
    git@github.com:*)
      alias_hit=""
      while read -r h; do
        case "$h" in
          *"$name"*) alias_hit="$h" ;;
        esac
      done < <(grep -oP '(?<=^Host )github-\S+' "$HOME/.ssh/config" 2>/dev/null || true)
      if [ -n "$alias_hit" ]; then
        echo "  FLAG [ssh-remote] origin is bare github.com but alias '$alias_hit' exists -- unused deploy key, pushes will prompt for a passphrase (unattended runs BLOCK)"
        echo "                    fix: git -C \"$repo\" remote set-url origin git@$alias_hit:<path>"
        n=$((n+1))
      else
        echo "  NOTE [ssh-remote] origin is bare github.com with no deploy-key alias -- pushes use the default identity and will prompt"
      fi
      ;;
  esac

  # 8. STALE VERIFIED-CLAIMS ---------------------------------------------------
  # BUILD-DISCIPLINE requires a written claim about system state to carry a
  # `# verified <date> via <command>` stamp. A stamp doesn't expire on its own:
  # the incident was an assertion about another host's crontab that outlived
  # its truth by a day and became an audit's #1 finding. Flag stamps older
  # than STALE_DAYS so the claim gets re-probed rather than re-quoted.
  # Excludes this linter (it names the stamp format in its own prose).
  STALE_DAYS="${STALE_DAYS:-7}"
  now_s=$(date +%s)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    d="$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
    [ -z "$d" ] && continue
    then_s="$(date -d "$d" +%s 2>/dev/null)" || continue
    age=$(( (now_s - then_s) / 86400 ))
    [ "$age" -le "$STALE_DAYS" ] && continue
    flag "stale-claim" "$age days old, re-probe: $(echo "$line" | cut -c1-140)"
  done < <(git -C "$repo" grep -InE 'verified[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}' \
             -- . ':(exclude)bin/hygiene-lint.sh' 2>/dev/null | head -8)

  # 8b. UNSTAMPED STATE ASSERTIONS in config comments (advisory) ---------------
  # Heuristic half of the same rule: a .conf comment asserting a fact about
  # the live system with NO stamp at all. Noisier than 8 (prose varies), so
  # NOTE not FLAG -- it points at a line to stamp, it doesn't claim it's wrong.
  git -C "$repo" grep -InE '^[[:space:]]*#.*\b(confirmed|no crontab|does not exist|already (exists|installed|running)|is (running|enabled|empty))\b' \
      -- '*.conf' 2>/dev/null | grep -viE 'verified[[:space:]]+[0-9]{4}' | head -4 \
    | while IFS= read -r l; do [ -n "$l" ] && echo "  NOTE [unstamped-claim] $(echo "$l" | cut -c1-140)"; done

  if [ "$n" -eq 0 ]; then
    echo "  clean -- no mechanical flags (NOTEs above, if any, are advisory)"
  else
    echo "  -> $n FLAG(s) for this project"
  fi
  total_flags=$((total_flags+n))
done

# 9. TASK-SHAPED ENTRIES IN scheduler's BLOCKERS.md --------------------------
# Mechanical half of BUILD-DISCIPLINE failure pattern 13 ("a decision without
# a dispatch path"). BLOCKERS.md is by standing rule NOT a work queue -- it is
# where things blocked ON THE HUMAN are surfaced. A task-shaped entry parked
# there is rot by definition: nothing dispatches from that file, so the work
# is invisible to every project's own runs. Incident: the 2026-07-24
# `.scheduler/` migration decision sat there 2 days while three projects
# independently re-derived it.
#
# Ecosystem-scoped (one shared file), so it runs ONCE after the per-project
# loop rather than per project. An entry is exempt if it carries a `> ` answer
# (the human replied) or names a dispatch path (OBLIGATION / dispatch / queued
# / routed / filed in <project>'s FOCUS) -- that's the difference between rot
# and a deliberate pointer.
BLOCKERS_MD="${BLOCKERS_MD:-$SCHED_ROOT/BLOCKERS.md}"
if [ "${#want[@]}" -eq 0 ] && [ -f "$BLOCKERS_MD" ]; then
  echo
  echo "############################################################"
  echo "# scheduler BLOCKERS.md  ($BLOCKERS_MD)"
  bl_out="$(awk '
    function emit(   i) {
      if (!inentry) return
      if (body ~ /(filed for an async pass|NOT DONE|not done|not completed|TODO|next step:)/ &&
          body !~ /(^|\n)[[:space:]]*> / &&
          body !~ /(OBLIGATION|dispatch|queued|routed)/)
        printf "  FLAG [blockers-task] %s:%d (## %s) %s\n", "BLOCKERS.md", start, sect, first
      inentry = 0; body = ""
    }
    /^## /   { emit(); sect = substr($0, 4) }
    /^- /    { emit(); inentry = 1; start = NR; first = substr($0, 1, 100); body = $0; next }
    inentry  { body = body "\n" $0 }
    END      { emit() }
  ' "$BLOCKERS_MD")"
  if [ -n "$bl_out" ]; then
    echo "$bl_out"
    bl_n="$(echo "$bl_out" | grep -c .)"
    total_flags=$((total_flags + bl_n))
  else
    echo "  clean -- no task-shaped entries without a dispatch path"
  fi
fi

echo
echo "############################################################"
echo "== $total_flags total FLAG(s) across ${#projects[@]} project(s) =="
echo "FLAGs are candidates, not confirmed problems -- a human/AI confirms"
echo "each before acting. NOTEs are advisory. See BUILD-DISCIPLINE.md."
