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
# bits, silent-pipeline smells, and single-value config duplication.
#
# Usage:
#   hygiene-lint.sh            scan every registered project, print findings
#   hygiene-lint.sh <name>...  scan only the named project(s)
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

  # 7. BUILD-DISCIPLINE checklist present in CLAUDE.md? ------------------------
  if echo "$tracked" | grep -qx 'CLAUDE.md'; then
    if ! git -C "$repo" grep -qi 'Build discipline' -- CLAUDE.md 2>/dev/null; then
      echo "  NOTE [no-checklist] CLAUDE.md exists but lacks the build-discipline checklist"
    fi
  else
    echo "  NOTE [no-claude-md] no root CLAUDE.md tracked"
  fi

  if [ "$n" -eq 0 ]; then
    echo "  clean -- no mechanical flags (NOTEs above, if any, are advisory)"
  else
    echo "  -> $n FLAG(s) for this project"
  fi
  total_flags=$((total_flags+n))
done

echo
echo "############################################################"
echo "== $total_flags total FLAG(s) across ${#projects[@]} project(s) =="
echo "FLAGs are candidates, not confirmed problems -- a human/AI confirms"
echo "each before acting. NOTEs are advisory. See BUILD-DISCIPLINE.md."
