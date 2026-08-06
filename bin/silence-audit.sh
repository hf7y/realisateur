#!/usr/bin/env bash
# silence-audit.sh -- the ecosystem's NULL-DISCRIMINATOR.
#
# Offline-first (zero AI), writes nothing, exits 0 unless --strict.
#
# WHAT IS MISSING THAT THIS SUPPLIES
# ----------------------------------
# Every existing survey here answers "what is the state of the projects?".
# None answers "can this sensor tell the difference between nothing-there,
# could-not-look, and did-not-look?". Those are three distinct world-states
# and every mechanism in this ecosystem currently maps all three onto one
# output symbol: silence. Ashby's Law is usually applied to the regulator's
# effectors -- R's variety must match D's. It binds just as hard on the
# SENSOR: a sensor with one output symbol cannot regulate a domain with
# three states, and no quantity of added checks fixes that. You must add
# output symbols. That is the entire thesis of this script, and it is why
# it audits MECHANISMS rather than projects.
#
# The cost of getting this wrong is asymmetric in the expensive direction
# (BUILD-DISCIPLINE pattern 14): these tools fail toward alarm, and alarm is
# routed to the scarcest organ in the system, which is Zach's attention.
#
# CHECKS -- each names the domain it read, and reports BLIND when it could
# not read that domain rather than reporting clean.
#
#   [mute-null]         a script scans a domain and has no branch for the
#                       domain being empty -- so "found nothing" and "the
#                       glob did not match" print identically (nothing).
#   [self-witness]      a scheduled entry sends all output to /dev/null, so
#                       the only evidence it ran is what it writes about
#                       itself. Pattern 9 moved down a level: the actor is
#                       sole source of truth for whether it RAN.
#   [home-scoped]       a sensor resolves job state under $HOME while the
#                       ecosystem dispatches from more than one account, so
#                       it silently reports on half the ecosystem as if it
#                       were the whole. Found live 2026-07-28.
#   [stderr-silenced]   a privileged/probing command with 2>/dev/null --
#                       turns "permission denied" into "clean".
#   [unwired]           an executable mechanism named by no crontab, no
#                       command file, no systemd unit and no other script.
#                       Built, never dispatched.
#   [prose-only-rule]   a doc asserts a checkable rule for which no
#                       executable check exists -- an unretired layer
#                       waiting to happen.
#   [retirement-open]   a change claims a retirement (RETIRES:/Retires:)
#                       whose literal is still live somewhere. "Names what
#                       it retires" is satisfied by the thing being GONE,
#                       not by a commit message saying so.
#
# Usage:
#   silence-audit.sh                  audit the whole ecosystem
#   silence-audit.sh <project>        audit one registered project
#   silence-audit.sh --strict         exit 1 if any FLAG (for hooks/CI)
#   silence-audit.sh --self-test      run the built-in fixtures, exit 1 on fail
#
# Exit codes: 0 clean-or-advisory, 1 --strict with FLAGs or self-test fail,
#             3 BLIND (parsed zero mechanisms -- see below).
#
# BLIND is non-negotiable and is the whole point. A checker that scans an
# empty domain and prints nothing reads exactly like a checker that scanned
# everything and found everything healthy. If this script parses zero
# mechanisms it exits 3 and says so, because that is the same defect it
# exists to find, and a tool that commits its own named failure mode is
# worth nothing.
set -uo pipefail

SCHED_ROOT="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || REPO=""

STRICT=0
ONLY=""
SELFTEST=0   # deliberately NOT read from the environment. It used to be, and
             # the self-test's own child invocations inherited it and recursed
             # until the harness killed them -- a mute hang, found 2026-07-28
             # while building this. An env-readable mode flag is the same
             # class of defect this script audits: a state the caller cannot
             # see from the outside.
case "${1:-}" in
  --strict)    STRICT=1 ;;
  --self-test) SELFTEST=1 ;;
  -h|--help)   sed -n '2,60p' "${BASH_SOURCE[0]}"; exit 0 ;;
  "")          ;;
  --*)         echo "unknown flag: $1" >&2; exit 2 ;;
  # A SHORT flag fell through to the project-name branch. `silence-audit -s`
  # audited a project literally named "-s" and printed a full, confident
  # report (measured 2026-07-30) -- the misparse this script exists to catch,
  # in this script. -s/-S specifically are near-misses on --summon, the only
  # flag in this ecosystem that spends money, and must never be swallowed.
  -*)          echo "unknown flag: $1 (short flags are not accepted; the cost flag --summon is long-form only)" >&2; exit 2 ;;
  *)           ONLY="$1" ;;
esac

flags=0
mechanisms=0
projects_seen=0
flag() { echo "  FLAG [$1] $2"; flags=$((flags+1)); }
note() { echo "  NOTE [$1] $2"; }

# ---------------------------------------------------------------- domains
# Everything below reports the domain it actually read. A negative is only
# ever asserted over that domain, never over "the ecosystem".

read_crontabs() {
  # Returns "account<TAB>line" for every crontab we can actually read.
  # Domain is reported by the caller; an account we cannot read is BLIND,
  # NOT clean -- that distinction is the reason this function exists.
  local acct
  crontab -l 2>/dev/null | sed "s/^/$(id -un)\t/"
  for acct in $(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1}'); do
    [ "$acct" = "$(id -un)" ] && continue
    if sudo -n -u "$acct" crontab -l >/dev/null 2>&1; then
      sudo -n -u "$acct" crontab -l 2>/dev/null | sed "s/^/$acct\t/"
    else
      echo -e "$acct\t#BLIND# cannot read crontab for $acct (no NOPASSWD sudo)"
    fi
  done
}

project_repos() {
  local conf name repo
  for conf in "$SCHED_ROOT"/schedule/*.conf; do
    [ -f "$conf" ] || continue
    name="$(basename "$conf" .conf)"
    case "$name" in _*) continue ;; esac
    [ -n "$ONLY" ] && [ "$name" != "$ONLY" ] && continue
    # SOURCE the conf; do not scrape it. scheduler's schedule/*.conf are shell
    # and correctly write PROJECT_REPO_PATH="$HOME/Documents/Projects/<name>".
    # A `grep -oP` hands back the LITERAL five characters `$HOME`, so [ -d ]
    # was false for every registered project and this script reported
    # "BLIND -- parsed ZERO registered projects", exit 3, on every host, always.
    # That made `silence-audit --strict` -- a BUILD-DISCIPLINE close-out row in
    # ~19 projects' CLAUDE.md -- a gate that could never be passed: the exact
    # null-discrimination defect this script exists to detect, committed by the
    # detector. Diagnosed by senechal 2026-08-05 and fixed here 2026-08-06.
    # Subshell + unset so one conf's value cannot leak into the next iteration.
    repo="$(unset PROJECT_REPO_PATH; . "$conf" >/dev/null 2>&1; echo "${PROJECT_REPO_PATH:-}")"
    [ -n "$repo" ] && [ -d "$repo" ] && echo -e "$name\t$repo"
  done
}

# Counted ONCE, up front, so BLIND is keyed on the domain this script is
# actually about (registered projects) rather than on a total that other
# checks can quietly inflate. The first cut of this script keyed BLIND on a
# global mechanism counter, and real crontab lines kept the count above zero
# even when zero projects were parsed -- so an unreadable schedule/ dir
# reported "clean". That is the defect, committed by the detector.
projects_seen="$(project_repos | grep -c . || true)"

# ---------------------------------------------------------------- checks

check_mute_null() {
  # A script that iterates a discovered domain must have SOME branch for
  # that domain being empty. Low-false-positive form: we only look at
  # scripts that clearly scan (mapfile from a process substitution, or a
  # for-loop over a glob/command substitution), and we accept any of the
  # recognised empty-signals as satisfying the check.
  local name repo sh body
  while IFS=$'\t' read -r name repo; do
    [ -z "${repo:-}" ] && continue
    while IFS= read -r sh; do
      [ -f "$sh" ] || continue
      mechanisms=$((mechanisms+1))
      body="$(cat "$sh" 2>/dev/null)" || continue
      # does it scan a domain?
      echo "$body" | grep -qE 'mapfile -t [A-Za-z_]+ < <\(|for [A-Za-z_]+ in .*\*|for [A-Za-z_]+ in \$\(' || continue
      # does it have any empty-domain signal at all?
      echo "$body" | grep -qiE 'BLIND|NOT[- ]PROBEABLE|no .* found|nothing to |none found|-eq 0 \]|\[ -z "\$' && continue
      flag mute-null "$name: $(basename "$sh") scans a domain with no empty-domain branch"
    done < <(find "$repo/bin" -maxdepth 1 -name '*.sh' -type f 2>/dev/null)
  done < <(project_repos)
}

check_self_witness() {
  # A cron line that discards all output has no witness but itself.
  local acct line cmd
  while IFS=$'\t' read -r acct line; do
    case "$line" in \#BLIND#*) note blind "crontab: $line"; continue ;; esac
    case "$line" in ''|\#*) continue ;; esac
    mechanisms=$((mechanisms+1))
    cmd="${line#*[0-9] }"
    if echo "$line" | grep -qE '>[[:space:]]*/dev/null[[:space:]]*2>&1|>/dev/null 2>&1'; then
      flag self-witness "$acct: cron entry discards all output -- only self-written logs witness it: ${cmd:0:70}"
    fi
  done < <(read_crontabs)
}

check_home_scoped() {
  # Count dispatch accounts first. With one account, $HOME-scoping is
  # correct and this check must stay quiet -- it is only a defect when the
  # ecosystem actually spans accounts.
  local accts name repo sh
  accts="$(read_crontabs | grep -cE $'\t[0-9*]' || true)"
  local n_acct
  n_acct="$(read_crontabs | grep -E $'\t[0-9*]' | cut -f1 | sort -u | wc -l)"
  if [ "${n_acct:-0}" -lt 2 ]; then
    note home-scoped "single dispatch account -- \$HOME-scoped sensors are correct here, check skipped"
    return
  fi
  while IFS=$'\t' read -r name repo; do
    [ -z "${repo:-}" ] && continue
    while IFS= read -r sh; do
      [ -f "$sh" ] || continue
      # reads per-job run state under $HOME, but never mentions another account
      if grep -qE '\$HOME/\.local/share|~/\.local/share' "$sh" 2>/dev/null \
         && ! grep -qE 'CRON_ACCOUNT|sudo -n -u|-u "\$acct"' "$sh" 2>/dev/null; then
        flag home-scoped "$name: $(basename "$sh") reads job state under \$HOME only, but $n_acct accounts dispatch"
      fi
    done < <(find "$repo/bin" -maxdepth 1 -name '*.sh' -type f 2>/dev/null)
  done < <(project_repos)
}

check_stderr_silenced() {
  local name repo hit
  while IFS=$'\t' read -r name repo; do
    [ -z "${repo:-}" ] && continue
    while IFS= read -r hit; do
      [ -n "$hit" ] && flag stderr-silenced "$name: $hit"
    done < <(
      grep -rnE '(sudo|systemctl|crontab|ssh|journalctl)[^|;]*2>[[:space:]]*/dev/null' \
        "$repo/bin" 2>/dev/null | grep -vE '^\s*#' | cut -c1-160 | head -5
    )
  done < <(project_repos)
}

check_unwired() {
  # A mechanism nothing names. Domain read: this project's own bin/, every
  # readable crontab, this project's command files, and every other script
  # in the same repo.
  local name repo sh base crontab_blob
  crontab_blob="$(read_crontabs)"
  while IFS=$'\t' read -r name repo; do
    [ -z "${repo:-}" ] && continue
    while IFS= read -r sh; do
      [ -f "$sh" ] || continue
      base="$(basename "$sh")"
      # named anywhere?
      grep -qF "$base" <<<"$crontab_blob" && continue
      grep -rqF "$base" "$repo" --include='*.md' --include='*.conf' \
        --include='*.service' --include='*.timer' 2>/dev/null && continue
      grep -rqF "$base" "$repo/bin" --include='*.sh' \
        --exclude="$base" 2>/dev/null && continue
      grep -rqF "$base" "$SCHED_ROOT/schedule" 2>/dev/null && continue
      flag unwired "$name: bin/$base is named by no crontab, doc, conf, unit or sibling script"
    done < <(find "$repo/bin" -maxdepth 1 -name '*.sh' -type f 2>/dev/null)
  done < <(project_repos)
}

check_prose_only_rule() {
  # A checklist line asserting a rule, in a repo that has a bin/, where no
  # script mentions the rule's distinctive literal. Deliberately narrow:
  # only checklist rows ("- [ ] ...") in discipline docs, only when the row
  # carries a backticked literal we can actually search for.
  local name repo doc lit row
  while IFS=$'\t' read -r name repo; do
    [ -z "${repo:-}" ] && continue
    [ -d "$repo/bin" ] || continue
    for doc in "$repo/BUILD-DISCIPLINE.md" "$repo/CLAUDE.md"; do
      [ -f "$doc" ] || continue
      mechanisms=$((mechanisms+1))
      while IFS= read -r row; do
        lit="$(grep -oP '(?<=`)[^`]{4,40}(?=`)' <<<"$row" | head -1)"
        [ -z "${lit:-}" ] && continue
        grep -rqF -- "$lit" "$repo/bin" 2>/dev/null && continue
        flag prose-only-rule "$name: $(basename "$doc") asserts \`$lit\` but no script in bin/ checks it"
      done < <(grep -E '^- \[ \]' "$doc" 2>/dev/null)
    done
  done < <(project_repos)
}

check_retirement_open() {
  # A retirement claim whose literal is still live. This is the mechanical
  # form of "names what it retires": satisfaction means GONE, not stated.
  local name repo claim lit live
  while IFS=$'\t' read -r name repo; do
    [ -z "${repo:-}" ] && continue
    while IFS= read -r claim; do
      lit="$(sed -E 's/.*RETIRES:[[:space:]]*//; s/[[:space:]]*$//' <<<"$claim")"
      [ -z "${lit:-}" ] && continue
      mechanisms=$((mechanisms+1))
      # count live occurrences OUTSIDE any line that is itself a retirement notice
      live="$(grep -rF -- "$lit" "$repo" \
                --include='*.md' --include='*.sh' --include='*.conf' 2>/dev/null \
              | grep -vF 'RETIRES:' | wc -l)"
      if [ "${live:-0}" -gt 0 ]; then
        flag retirement-open "$name: claims to retire \`$lit\` -- $live live occurrence(s) remain"
      fi
    done < <(grep -rhE 'RETIRES:' "$repo" --include='*.sh' --include='*.md' 2>/dev/null)
  done < <(project_repos)
}

# ---------------------------------------------------------------- self-test
# Fixtures, not exit codes. Each asserts the check FIRES on a known-bad
# input and STAYS QUIET on a known-good one -- a lint that only ever passes
# is the mute-null defect wearing a lint's clothes.
self_test() {
  local tmp rc=0 out
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/proj/bin"

  t() { # name expected_regex actual
    if grep -qE "$2" <<<"$3"; then echo "  ok   $1"; else
      echo "  FAIL $1 (expected /$2/)"; rc=1; fi
  }
  tn() { # name unexpected_regex actual
    if grep -qE "$2" <<<"$3"; then echo "  FAIL $1 (should not have matched /$2/)"; rc=1
    else echo "  ok   $1"; fi
  }

  echo "== self-test =="

  # --- mute-null fires on a scanner with no empty branch
  cat >"$tmp/proj/bin/bad.sh" <<'EOF'
#!/usr/bin/env bash
for f in /etc/*.conf; do echo "$f"; done
EOF
  cat >"$tmp/proj/bin/good.sh" <<'EOF'
#!/usr/bin/env bash
n=0
for f in /etc/*.conf; do echo "$f"; n=$((n+1)); done
[ "$n" -eq 0 ] && echo "BLIND: no conf files read"
EOF
  SCHED_ROOT="$tmp/sched" ; mkdir -p "$tmp/sched/schedule"
  printf 'PROJECT_REPO_PATH="%s/proj"\n' "$tmp" >"$tmp/sched/schedule/proj.conf"
  out="$(SCHED_ROOT="$tmp/sched" ONLY="" bash "${BASH_SOURCE[0]}" 2>&1)"
  t  "mute-null fires on unguarded scanner"  'mute-null.*bad\.sh'  "$out"
  tn "mute-null quiet on guarded scanner"    'mute-null.*good\.sh' "$out"

  # --- retirement-open fires while the retired literal is still live
  printf '# RETIRES: LEGACY_TOKEN_XYZ\n' >"$tmp/proj/bin/new.sh"
  printf 'we still use LEGACY_TOKEN_XYZ here\n' >"$tmp/proj/OLD.md"
  out="$(SCHED_ROOT="$tmp/sched" bash "${BASH_SOURCE[0]}" 2>&1)"
  t "retirement-open fires while literal is live" 'retirement-open.*LEGACY_TOKEN_XYZ' "$out"
  rm -f "$tmp/proj/OLD.md"
  out="$(SCHED_ROOT="$tmp/sched" bash "${BASH_SOURCE[0]}" 2>&1)"
  tn "retirement-open clears once literal is gone" 'retirement-open' "$out"

  # --- stderr-silenced fires on a privileged probe
  printf '#!/usr/bin/env bash\nsudo -n crontab -l 2>/dev/null\n[ -z "$x" ] && echo none found\n' \
    >"$tmp/proj/bin/probe.sh"
  out="$(SCHED_ROOT="$tmp/sched" bash "${BASH_SOURCE[0]}" 2>&1)"
  t "stderr-silenced fires on silenced privileged probe" 'stderr-silenced.*probe\.sh' "$out"

  # --- A conf whose PROJECT_REPO_PATH is an UNEXPANDED shell variable must
  # still resolve. This is the shape production actually writes, and the ONLY
  # shape it writes; the fixtures above all bake an absolute path, so they
  # exercised an input the real registry never produces and passed while the
  # real thing parsed zero projects. Assert the production shape directly.
  mkdir -p "$tmp/varhome/schedule"
  printf 'PROJECT_REPO_PATH="$HOME/proj"\n' >"$tmp/varhome/schedule/proj.conf"
  out="$(HOME="$tmp" SCHED_ROOT="$tmp/varhome" bash "${BASH_SOURCE[0]}" 2>&1; echo "rc=$?")"
  tn "conf with literal \$HOME is not reported BLIND" 'BLIND' "$out"
  tn "conf with literal \$HOME does not exit 3"       'rc=3'  "$out"

  # --- BLIND: zero mechanisms must exit 3, not 0
  mkdir -p "$tmp/empty/schedule"
  out="$(SCHED_ROOT="$tmp/empty" bash "${BASH_SOURCE[0]}" 2>&1; echo "rc=$?")"
  t "empty domain exits BLIND(3) not clean" 'rc=3' "$out"
  t "empty domain says BLIND"               'BLIND'  "$out"

  echo
  [ "$rc" -eq 0 ] && echo "self-test: PASS" || echo "self-test: FAIL"
  return "$rc"
}

if [ "$SELFTEST" = 1 ]; then self_test; exit $?; fi

# ------------------------------------------------- am I wired to anything?
# The noisy self-trigger. BUILD-DISCIPLINE pattern 2 (build-but-don't-wire)
# is the failure this project regenerates most often, and an auditor that
# sits unwired while reporting on everyone else's wiring is the joke writing
# itself. So this script asks the [unwired] question about ITSELF first, on
# every single run, and refuses to be quiet about the answer.
#
# It cannot be satisfied by a doc mentioning it: the test is whether some
# DISPATCHER names it -- a crontab line, a systemd unit, or hygiene-lint.
self_wiring_banner() {
  local me hits=0
  me="$(basename "${BASH_SOURCE[0]}")"
  read_crontabs | grep -qF "$me" && hits=$((hits+1))
  grep -rqF "$me" /etc/systemd/system ~/.config/systemd 2>/dev/null && hits=$((hits+1))
  [ -n "$REPO" ] && grep -rqF "$me" "$REPO/bin/hygiene-lint.sh" 2>/dev/null && hits=$((hits+1))
  if [ "$hits" -eq 0 ]; then
    echo "########################################################################"
    echo "## NOT WIRED -- this audit is running by hand and by hand only.       ##"
    echo "## No crontab, no systemd unit and no hygiene-lint check names        ##"
    echo "##   $me"
    echo "## Everything below is therefore a ONE-OFF READING, not surveillance. ##"
    echo "## It will not run again unless a human remembers to run it, which is ##"
    echo "## BUILD-DISCIPLINE pattern 2 -- the pattern this script audits for.  ##"
    echo "## Wire it (install-silence-audit.sh) or delete it. Do not leave it   ##"
    echo "## here looking like coverage.                                        ##"
    echo "########################################################################"
    echo
  fi
}

# ---------------------------------------------------------------- run
echo "silence-audit -- $(date -Is)"
echo "domain: schedule/*.conf under $SCHED_ROOT${ONLY:+ (project: $ONLY)}"
echo
self_wiring_banner

check_mute_null
check_self_witness
check_home_scoped
check_stderr_silenced
check_unwired
check_prose_only_rule
check_retirement_open

echo
if [ "${projects_seen:-0}" -eq 0 ]; then
  echo "BLIND -- parsed ZERO registered projects from $SCHED_ROOT/schedule."
  echo "This is not a clean result. Nothing was audited; the domain was"
  echo "unreadable or empty. Reporting clean here would be the exact defect"
  echo "this script exists to detect."
  exit 3
fi
echo "audited $mechanisms mechanism(s); $flags FLAG(s)"
[ "$STRICT" = 1 ] && [ "$flags" -gt 0 ] && exit 1
exit 0
