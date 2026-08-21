#!/usr/bin/env bash
# silence-audit.sh -- the ecosystem's NULL-DISCRIMINATOR.
#
# KIND: verb
#
# RUNNER: operator -- surveys every registered project's working checkout
# GUARD-TEST: none -- it carries its own --self-test with fixtures, which is not a suite CI globs; closing this is the next repaint due
# GATE: strict --target $TREE
#
# TRAPS (the rest of this header is in the vault):
# Other surveys ask "what is the state of the projects?". This asks whether a
# sensor can tell nothing-there from could-not-look from did-not-look: three
# world-states every mechanism here maps onto one symbol, silence.
# Ashby binds on the SENSOR too: one output symbol cannot regulate three
# states, and no added checks fix that. Hence it audits MECHANISMS.
#

set -uo pipefail

PROJECTS_ROOT="${PROJECTS_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}}"
REGISTRY_MARKER="${REGISTRY_MARKER:-.agent-project}"
UNDECLARED_SEEN="$(mktemp)"; trap 'rm -f "$UNDECLARED_SEEN"' EXIT
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." 2>/dev/null && pwd)" || REPO=""

STRICT=0
ONLY=""
TARGET=""       # resolved absolute path of --target, "" if it did not resolve
TARGET_GIVEN="" # what the caller actually typed. Kept SEPARATELY so that a
                # --target that does not resolve is reported as the thing the
                # caller asked for, and so "no --target" and "a --target that
                # names nothing" stay distinguishable -- collapsing those two
                # onto one empty string is how a pointed run would silently
                # fall back to surveying the estate, which is #107 again.
SELFTEST=0   # NOT read from the environment: child invocations inherited it
             # and recursed. An env-readable mode flag is a state the caller
             # cannot see, the class of defect this script audits.
while [ $# -gt 0 ]; do
  case "$1" in
    --strict)    STRICT=1 ;;
    --self-test) SELFTEST=1 ;;
    --target)    shift
                 [ $# -gt 0 ] || { echo "--target needs a directory" >&2; exit 2; }
                 TARGET_GIVEN="$1" ;;
    --target=*)  TARGET_GIVEN="${1#--target=}"
                 [ -n "$TARGET_GIVEN" ] || { echo "--target needs a directory" >&2; exit 2; } ;;
    # The thesis, THEN the usage block. Both halves anchored on the text, not
    # on line numbers -- `2,60p` used to stop short of `# Usage:` once the
    # header grew past 60 lines, silently dropping the tail of the thesis.
    # A line number is what rotted in the first place; don't reintroduce one.
    -h|--help)   sed -n '2,/^# Usage:/p' "${BASH_SOURCE[0]}" | sed '$d'
                 sed -n '/^# Usage:/,/^#             3 BLIND/p' "${BASH_SOURCE[0]}"
                 exit 0 ;;
    "")          ;;
    --*)         echo "unknown flag: $1" >&2; exit 2 ;;
    # A SHORT flag fell through to the project-name branch. `silence-audit -s`
    # audited a project literally named "-s" and printed a full, confident
    # report -- the misparse this script exists to catch,
    # in this script. -s/-S specifically are near-misses on --summon, the only
    # flag in this ecosystem that spends money, and must never be swallowed.
    -*)          echo "unknown flag: $1 (short flags are not accepted; the cost flag --summon is long-form only)" >&2; exit 2 ;;
    *)           ONLY="$1" ;;
  esac
  shift
done

# Two scope knobs is a question with two subjects: a registry name and a
# directory are different domains, and picking one is the silent misparse.
if [ -n "$TARGET_GIVEN" ] && [ -n "$ONLY" ]; then
  echo "--target <dir> and <project> name different domains (a tree vs a registry entry); pass one" >&2
  exit 2
fi

# Resolve to an absolute path ONCE so every message names the same thing; a
# failure leaves TARGET empty and is BLIND, never a clean audit.
if [ -n "$TARGET_GIVEN" ]; then
  TARGET="$(cd "$TARGET_GIVEN" 2>/dev/null && pwd)" || TARGET=""
fi

flags=0
mechanisms=0
projects_seen=0
flag() { echo "  FLAG [$1] $2"; flags=$((flags+1)); }
note() { echo "  NOTE [$1] $2"; }

# ---------------------------------------------------------------- domains
# Everything below reports the domain it read: a negative is asserted over
# that domain, never over "the ecosystem".

read_crontabs() {
  # "account<TAB>line" per readable crontab. Unreadable is BLIND, not clean.
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
  # --target: the tree POINTED AT is the entire domain; the registry is not
  # consulted. Returning early rather than filtering it down is the point --
  # a filter matching nothing falls through to surveying everything (#107).
  if [ -n "$TARGET_GIVEN" ]; then
    [ -n "$TARGET" ] || return 0            # unresolvable -> zero -> BLIND
    [ -d "$TARGET/bin" ] || return 0        # not a project tree -> BLIND
    printf '%s\t%s\n' "$(basename "$TARGET")" "$TARGET"
    return 0
  fi
  # A PROJECT IS A TREE THAT SAYS SO: `.agent-project` is the registry.
  for tree in "$PROJECTS_ROOT"/*; do
    [ -d "$tree" ] || continue
    name="$(basename "$tree")"
    [ -n "$ONLY" ] && [ "$name" != "$ONLY" ] && continue
    if [ ! -f "$tree/$REGISTRY_MARKER" ]; then
      # A CHECKOUT MISSING THE MARKER IS NOT THE SAME AS A NON-PROJECT, and
      # silently treating it as one is how this guard would narrow its own
      # domain without saying so. wtul carries .agent-project on its default
      # branch and a local clone here did not -- a stale clone, not a
      if [ -d "$tree/.git" ] && ! grep -qxF "$name" "$UNDECLARED_SEEN" 2>/dev/null; then
        echo "$name" >>"$UNDECLARED_SEEN"
        printf 'undeclared: %s (no %s -- stale clone, or not a project)\n' \
          "$name" "$REGISTRY_MARKER" >&2
      fi
      continue
    fi
    [ -d "$tree/bin" ] || continue
    printf '%s\t%s\n' "$name" "$tree"
  done
}

project_repos_and_worktrees() {
  local name repo wt
  while IFS=$'\t' read -r name repo; do
    [ -z "${repo:-}" ] && continue
    printf '%s\t%s\n' "$name" "$repo"
    while IFS= read -r wt; do
      [ -n "$wt" ] || continue
      [ "$wt" = "$repo" ] && continue
      [ -d "$wt/bin" ] || continue
      printf '%s\t%s\n' "$name(worktree)" "$wt"
    done < <(git -C "$repo" worktree list --porcelain 2>/dev/null \
               | awk '/^worktree /{print $2}')
  done < <(project_repos)
}

# Counted ONCE up front, so BLIND is keyed on the domain this script is
# actually about (registered projects) rather than on a total that other
# checks can quietly inflate. The first cut of this script keyed BLIND on a
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
      # HERESTRINGS, NOT `echo "$body" | grep -q`. With `set -o pipefail` (top
      # of this file) that pipeline returns 141, not 0, whenever grep -q finds
      # its match and exits while echo is still writing -- so the WRITER's
      grep -qE 'mapfile -t [A-Za-z_]+ < <\(|for [A-Za-z_]+ in .*\*|for [A-Za-z_]+ in \$\(' <<<"$body" || continue
      # does it have any empty-domain signal at all?
      grep -qiE 'BLIND|NOT[- ]PROBEABLE|no .* found|nothing to |none found|-eq 0 \]|\[ -z "\$' <<<"$body" && continue
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
    if grep -qE '>[[:space:]]*/dev/null[[:space:]]*2>&1|>/dev/null 2>&1' <<<"$line"; then
      flag self-witness "$acct: cron entry discards all output -- only self-written logs witness it: ${cmd:0:70}"
    fi
  done < <(read_crontabs)
}

# prop_is_local <repo> <script> -- true when that repo's own propagation-set
# classifies it LOCAL. An absent classification is not an exemption.
prop_is_local() {
  local repo="$1" name="$2" set="$1/bin/lib/propagation-set.sh" locals
  [ -r "$set" ] || return 1
  locals="$(sed -n '/^PROP_LOCAL_SCRIPTS="/,/^"/p' "$set" 2>/dev/null)"
  case " $(printf '%s' "$locals" | tr '\n' ' ') " in *" $name "*) return 0 ;; esac
  return 1
}

check_home_scoped() {
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
      # A LOCAL-CLASS SCRIPT NEVER LEAVES THIS HOST, so $HOME is its scope.
      if prop_is_local "$repo" "$(basename "$sh")"; then continue; fi
      # reads per-job run state under $HOME, but never mentions another account
      if grep -qE '\$HOME/\.local/share|~/\.local/share' "$sh" 2>/dev/null \
         && ! grep -qE 'CRON_ACCOUNT|sudo -n -u|-u "\$acct"' "$sh" 2>/dev/null; then
        # #347: a script that names an established host-wide root
        # (/usr/local, /etc -- the two this ecosystem actually installs to,
        # per propagation-set.sh and selfdev-app-key.sh) BEFORE the $HOME
        local hm_line prefix any_home_scoped=0
        while IFS= read -r hm_line; do
          # A $HOME path that is the DEFAULT OF AN ENV OVERRIDE is not
          # $HOME-scoped: the host-wide installs set it -- dexter's crontab
          # passes VERB_BUILD_ROOT=/usr/local/share/verb-builds. The one TRUE
          # finding here (#487) was a BARE $HOME path with no escape.
          case "$hm_line" in *'${'*':-'*) continue ;; esac
          prefix="${hm_line%%\$HOME*}"
          [ "$prefix" = "$hm_line" ] && prefix="${hm_line%%~*}"
          if ! printf '%s' "$prefix" | grep -qE '/(usr/local|etc)/'; then
            any_home_scoped=1
          fi
        done < <(grep -E '\$HOME/\.local/share|~/\.local/share' "$sh" 2>/dev/null)
        if [ "$any_home_scoped" -eq 1 ]; then
          flag home-scoped "$name: $(basename "$sh") reads job state under \$HOME only, but $n_acct accounts dispatch"
        fi
      fi
    done < <(find "$repo/bin" -maxdepth 1 -name '*.sh' -type f 2>/dev/null)
  done < <(project_repos)
}

check_stderr_silenced() {
  # SAY WHAT WAS DROPPED: this showed five per repo and reported that as the
  # count -- realisateur has 44. "5 findings" vs "5 of 44" is this script's
  # own thesis, in this script.
  local name repo hit all n shown=5
  while IFS=$'\t' read -r name repo; do
    [ -z "${repo:-}" ] && continue
    all="$(grep -rnE '(sudo|systemctl|crontab|ssh|journalctl)[^|;]*2>[[:space:]]*/dev/null' \
      "$repo/bin" 2>/dev/null | grep -vE '^\s*#' | cut -c1-160)"
    n="$(printf '%s' "$all" | grep -c . || true)"
    [ "${n:-0}" -eq 0 ] && continue
    while IFS= read -r hit; do
      [ -n "$hit" ] && flag stderr-silenced "$name: $hit"
    done < <(printf '%s\n' "$all" | head -"$shown")
    if [ "$n" -gt "$shown" ]; then
      flag stderr-silenced "$name: and $((n - shown)) more silenced privileged call(s) not shown -- $n in total"
    fi
  done < <(project_repos)
}

check_unwired() {
  # A mechanism nothing names. Domain read: every readable crontab, this
  # project's command files, EVERY .sh ANYWHERE IN THE REPO, and the registry.
  #
  local name repo sh base crontab_blob verb found
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
      grep -rqF "$base" "$repo" --include='*.sh' --exclude="$base" \
        --exclude-dir=.git --exclude-dir=worktrees 2>/dev/null && continue
      found=0
      while IFS= read -r verb; do
        [ -f "$verb" ] && [ -r "$verb" ] || continue
        grep -qF "$base" "$verb" 2>/dev/null && { found=1; break; }
      done < <(find "$repo/bin" -maxdepth 1 -type f ! -name '*.sh' 2>/dev/null)
      [ "$found" = 1 ] && continue
      # scheduler's confs were one place a script could be named. They are not
      # readable without a scheduler checkout, and requiring one is the coupling
      # this guard just shed -- so it is consulted only if it happens to exist.
      [ -n "${SCHED_ROOT:-}" ] && grep -rqF "$base" "$SCHED_ROOT/schedule" 2>/dev/null && continue
      flag unwired "$name: bin/$base is named by no crontab, doc, conf, unit, registry entry, verb binary, or any other .sh in the repo (tests/ included)"
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

check_worktree_backed() {  # ported from ecosim's fork, #421
  local bindir="${LOCAL_BIN:-$HOME/.local/bin}" entry target dir gitdir
  if [ ! -d "$bindir" ]; then
    note blind "worktree-backed: $bindir does not exist or is unreadable -- NOT audited"
    return
  fi
  while IFS= read -r entry; do
    [ -L "$entry" ] || continue
    target="$(readlink -f "$entry" 2>/dev/null)" || continue
    [ -n "$target" ] && [ -e "$target" ] || {
      flag worktree-backed "$(basename "$entry") -> DANGLING ($(readlink "$entry"))"
      continue
    }
    dir="$(dirname "$target")"
    gitdir="$(git -C "$dir" rev-parse --git-dir 2>/dev/null)" || continue
    if [ -f "$dir/.git" ] || [ -f "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)/.git" ]; then
      flag worktree-backed "$(basename "$entry") -> $target lives in a git WORKTREE, not a permanent checkout -- pruning the worktree deletes this command silently"
    fi
  done < <(find "$bindir" -maxdepth 1 -type l 2>/dev/null)
}

check_twin() {  # ported from ecosim's fork, #421
  local name repo sh sum base
  local -a sums=() paths=() owners=()
  while IFS=$'\t' read -r name repo; do
    [ -z "${repo:-}" ] && continue
    while IFS= read -r sh; do
      [ -f "$sh" ] || continue
      sum="$(md5sum "$sh" 2>/dev/null | cut -d' ' -f1)"
      [ -n "$sum" ] || continue
      local i found="" found_owner="" owner
      owner="${name%(worktree)}"
      for i in "${!sums[@]}"; do
        if [ "${sums[$i]}" = "$sum" ] && [ "${owners[$i]}" != "$owner" ]; then
          found="${paths[$i]}"; found_owner="${owners[$i]}"; break
        fi
      done
      if [ -n "$found" ]; then
        base="$(basename "$sh")"
        flag twin "$owner: bin/$base is byte-identical to $found_owner's copy at $found -- two projects, one file, and only one of them will get the next edit"
      fi
      sums+=("$sum"); paths+=("$sh"); owners+=("$owner")
    done < <(find "$repo/bin" -maxdepth 1 -name '*.sh' -type f 2>/dev/null)
  done < <(project_repos_and_worktrees)
}

check_subrepo_invisible() {  # ported from ecosim's fork, #421
  local name repo top
  while IFS=$'\t' read -r name repo; do
    [ -z "${repo:-}" ] && continue
    top="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || continue
    [ -n "$top" ] || continue
    if [ "$top" != "$repo" ]; then
      flag subrepo-invisible "$name: registered at $repo, which is not a repo root (root is $top) -- every [ -d \$repo/.git ] check in the ecosystem skips it while it still reads as registered"
    fi
  done < <(project_repos)
}

# check_dirty_writer (#421) NOT ported: adapted, it false-positives on bin/cut-verb-build.sh (writes to a build staging dir, not a repo it read).


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
  # The registry is the marker in the tree, so the fixture declares itself the
  # same way a real project does. It used to write a scheduler conf here, which
  # is what coupled this guard to a scheduler checkout.
  mkdir -p "$tmp/projects" && ln -sfn "$tmp/proj" "$tmp/projects/proj"
  : > "$tmp/proj/.agent-project"
  out="$(PROJECTS_ROOT="$tmp/projects" ONLY="" bash "${BASH_SOURCE[0]}" 2>&1)"
  t  "mute-null fires on unguarded scanner"  'mute-null.*bad\.sh'  "$out"
  tn "mute-null quiet on guarded scanner"    'mute-null.*good\.sh' "$out"

  # --- [retirement-open] is RETIRED; assert it stays retired.
  # The old pair of cases here passed on this fixture -- one declaration in an
  # otherwise empty repo -- while the check was emitting 52 false FLAGs on the
  # live estate. This replaces them with the only assertion that would have
  # caught that: the scraper must not resurrect.
  printf '# RETIRES: LEGACY_TOKEN_XYZ\n' >"$tmp/proj/bin/new.sh"
  printf 'we still use LEGACY_TOKEN_XYZ here\n' >"$tmp/proj/OLD.md"
  out="$(PROJECTS_ROOT="$tmp/projects" bash "${BASH_SOURCE[0]}" 2>&1)"
  tn "retirement-open stays retired" 'retirement-open' "$out"
  rm -f "$tmp/proj/OLD.md"

  # --- stderr-silenced fires on a privileged probe
  printf '#!/usr/bin/env bash\nsudo -n crontab -l 2>/dev/null\n[ -z "$x" ] && echo none found\n' \
    >"$tmp/proj/bin/probe.sh"
  out="$(PROJECTS_ROOT="$tmp/projects" bash "${BASH_SOURCE[0]}" 2>&1)"
  t "stderr-silenced fires on silenced privileged probe" 'stderr-silenced.*probe\.sh' "$out"

  for i in 1 2 3 4 5 6 7; do
    printf '#!/usr/bin/env bash\nsudo -n crontab -l 2>/dev/null\n' >"$tmp/proj/bin/many$i.sh"
  done
  out="$(PROJECTS_ROOT="$tmp/projects" bash "${BASH_SOURCE[0]}" 2>&1)"
  t "a truncated list says how many more there are" 'more silenced privileged call' "$out"
  t "...and states the true total"                  'in total'                      "$out"
  rm -f "$tmp/proj/bin/many"*.sh

  # --- The registry is a MARKER; no path is interpolated.
  # This case replaces the old "conf with a literal $HOME" regression: that
  # bug existed because a conf was SCRAPED for PROJECT_REPO_PATH and handed
  # back the five characters `$HOME`, so every project resolved to a directory
  mkdir -p "$tmp/reg2/declared/bin" "$tmp/reg2/undeclared/bin"
  : > "$tmp/reg2/declared/.agent-project"
  printf '#!/usr/bin/env bash\nls /etc >/dev/null\n' >"$tmp/reg2/undeclared/bin/x.sh"
  out="$(PROJECTS_ROOT="$tmp/reg2" bash "${BASH_SOURCE[0]}" 2>&1; echo "rc=$?")"
  tn "a declared tree is not reported BLIND"        'BLIND'       "$out"
  tn "a declared tree does not exit 3"              'rc=3'        "$out"
  tn "an undeclared sibling is not audited"         'undeclared'  "$out"

  # --- #138: a script whose ONLY caller is its own witness is WIRED.
  # tests/ was outside the reference domain, so the witness-backed pattern the
  # estate asks for graded as the broken one. The negative case is the half
  # that matters: widening the domain must not make [unwired] unfireable.
  mkdir -p "$tmp/proj/tests"
  printf '#!/usr/bin/env bash\necho hi\n'                     >"$tmp/proj/bin/witnessed.sh"
  printf '#!/usr/bin/env bash\nTARGET=bin/witnessed.sh\n'     >"$tmp/proj/tests/witnessed-witness.sh"
  printf '#!/usr/bin/env bash\necho nobody calls me\n'        >"$tmp/proj/bin/orphaned.sh"
  out="$(PROJECTS_ROOT="$tmp/projects" bash "${BASH_SOURCE[0]}" 2>&1)"
  tn "unwired quiet on a script named only by its own witness" 'unwired.*witnessed\.sh' "$out"
  t  "unwired still fires on a script nothing names"           'unwired.*orphaned\.sh'  "$out"
  rm -f "$tmp/proj/bin/witnessed.sh" "$tmp/proj/tests/witnessed-witness.sh" "$tmp/proj/bin/orphaned.sh"

  printf '#!/usr/bin/env bash\necho hi\n'                            >"$tmp/proj/bin/helper.sh"
  printf '#!/usr/bin/env bash\nexec bin/helper.sh "$@"\n'            >"$tmp/proj/bin/garde"
  chmod +x "$tmp/proj/bin/garde"
  out="$(PROJECTS_ROOT="$tmp/projects" bash "${BASH_SOURCE[0]}" 2>&1)"
  tn "unwired quiet on a script named only by an extensionless verb binary" 'unwired.*helper\.sh' "$out"
  rm -f "$tmp/proj/bin/helper.sh" "$tmp/proj/bin/garde"

  # --- #107: --target must audit the tree it was POINTED AT and must not read
  # the registry. The registry here is deliberately non-empty and points at a
  # DECOY holding its own known-bad script: if the audit consults it, the
  mkdir -p "$tmp/decoy/bin" "$tmp/reg/schedule" "$tmp/pointed/bin"
  printf 'PROJECT_REPO_PATH="%s/decoy"\n' "$tmp" >"$tmp/reg/schedule/decoy.conf"
  printf '#!/usr/bin/env bash\nfor f in /etc/*.conf; do echo "$f"; done\n' >"$tmp/decoy/bin/decoy-scan.sh"
  printf '#!/usr/bin/env bash\nfor f in /etc/*.conf; do echo "$f"; done\n' >"$tmp/pointed/bin/pointed-scan.sh"
  out="$(PROJECTS_ROOT="$tmp/reg" bash "${BASH_SOURCE[0]}" --target "$tmp/pointed" 2>&1)"
  t  "--target reports on the tree it was pointed at" 'mute-null.*pointed-scan\.sh' "$out"
  tn "--target does not read the registry"            'decoy-scan\.sh'              "$out"

  # --strict and --target together. The old single-argument parser read
  # argument one and dropped the rest in silence, so the gating mode and the
  # scope knob could not be combined -- which is the exact invocation
  # CLAUDE.md's checklist row needs.
  out="$(PROJECTS_ROOT="$tmp/reg" bash "${BASH_SOURCE[0]}" --strict --target "$tmp/pointed" 2>&1; echo "rc=$?")"
  # BOTH halves. `rc=1` alone is a vacuous pass: the old parser dropped
  # --target, audited the registry, found the decoy's FLAG and exited 1 -- the
  # right exit code for the wrong tree, which is #107 in one line.
  t "--strict --target parses both and gates"          'rc=1'             "$out"
  t "--strict --target gated on the TARGET's findings" 'pointed-scan\.sh' "$out"

  # A --target that is not a project tree must fail LOUD. Falling back to the
  # registry, or reporting clean, is how #107 survived a year of green runs.
  out="$(PROJECTS_ROOT="$tmp/reg" bash "${BASH_SOURCE[0]}" --target "$tmp/no-such-tree" 2>&1; echo "rc=$?")"
  t  "--target on a non-tree exits BLIND(3)"      'rc=3'          "$out"
  t  "--target on a non-tree names what it wanted" 'no-such-tree' "$out"
  tn "--target on a non-tree does not fall back to the registry" 'decoy-scan\.sh' "$out"

  mkdir -p "$tmp/reg3/proj1/bin" "$tmp/reg3/proj2/bin"
  : > "$tmp/reg3/proj1/.agent-project"; : > "$tmp/reg3/proj2/.agent-project"
  printf '#!/usr/bin/env bash\necho identical\n' >"$tmp/reg3/proj1/bin/dup.sh"
  cp "$tmp/reg3/proj1/bin/dup.sh" "$tmp/reg3/proj2/bin/dup.sh"
  out="$(PROJECTS_ROOT="$tmp/reg3" bash "${BASH_SOURCE[0]}" 2>&1)"
  t "twin fires on byte-identical executables in two declared projects" 'twin.*dup\.sh' "$out"
  printf '\n# now different\n' >>"$tmp/reg3/proj2/bin/dup.sh"
  out="$(PROJECTS_ROOT="$tmp/reg3" bash "${BASH_SOURCE[0]}" 2>&1)"
  tn "twin clears once the copies diverge" 'twin.*dup\.sh' "$out"

  out="$(PROJECTS_ROOT="$tmp/reg3" LOCAL_BIN="$tmp/nonexistent-bin" bash "${BASH_SOURCE[0]}" 2>&1)"
  t "worktree-backed reports BLIND on an unreadable bin dir" 'blind.*worktree-backed' "$out"
  mkdir -p "$tmp/lbin"; ln -sfn "$tmp/gone-forever" "$tmp/lbin/ghost"
  out="$(PROJECTS_ROOT="$tmp/reg3" LOCAL_BIN="$tmp/lbin" bash "${BASH_SOURCE[0]}" 2>&1)"
  t "worktree-backed fires on a dangling install" 'worktree-backed.*ghost.*DANGLING' "$out"

  mkdir -p "$tmp/mono/sub/bin"
  git -C "$tmp/mono" init -q 2>/dev/null
  : > "$tmp/mono/sub/.agent-project"
  out="$(PROJECTS_ROOT="$tmp/mono" bash "${BASH_SOURCE[0]}" 2>&1)"
  t "subrepo-invisible fires on a monorepo subdirectory" 'subrepo-invisible.*not a repo root' "$out"

  mkdir -p "$tmp/reg4/repo-root/bin"
  : > "$tmp/reg4/repo-root/.agent-project"
  git -C "$tmp/reg4/repo-root" init -q 2>/dev/null
  out="$(PROJECTS_ROOT="$tmp/reg4" bash "${BASH_SOURCE[0]}" 2>&1)"
  tn "subrepo-invisible clears when the declared tree is the repo root" 'subrepo-invisible' "$out"

  # --- BLIND: zero mechanisms must exit 3, not 0
  mkdir -p "$tmp/empty/schedule"
  out="$(PROJECTS_ROOT="$tmp/empty" bash "${BASH_SOURCE[0]}" 2>&1; echo "rc=$?")"
  t "empty domain exits BLIND(3) not clean" 'rc=3' "$out"
  t "empty domain says BLIND"               'BLIND'  "$out"

  mkdir -p "$tmp/cls/bin/lib"
  cat > "$tmp/cls/bin/lib/propagation-set.sh" <<'PS'
PROP_LOCAL_SCRIPTS="
verbs-refresh.sh
floor-check.sh
"
PS
  mkdir -p "$tmp/ovr/bin"
  printf '#!/usr/bin/env bash\nB="${VERB_BUILD_ROOT:-$HOME/.local/share/x}"\n' > "$tmp/ovr/bin/overridable.sh"
  printf '#!/usr/bin/env bash\nB="$HOME/.local/share/x"\n' > "$tmp/ovr/bin/bare.sh"
  if grep -E '\$HOME/\.local/share' "$tmp/ovr/bin/overridable.sh" | grep -qE '\$\{[A-Z_]+:-'; then
    echo "  ok   an overridable \$HOME default is recognised as configurable"
  else echo "  FAIL overridable \$HOME default not recognised"; rc=1; fi
  if grep -E '\$HOME/\.local/share' "$tmp/ovr/bin/bare.sh" | grep -qE '\$\{[A-Z_]+:-'; then
    echo "  FAIL a BARE \$HOME path was treated as configurable"; rc=1
  else echo "  ok   a bare \$HOME path is still \$HOME-scoped"; fi

  if prop_is_local "$tmp/cls" verbs-refresh.sh; then echo "  ok   a LOCAL-classified script is exempt"
  else echo "  FAIL a LOCAL-classified script was not recognised"; rc=1; fi
  if prop_is_local "$tmp/cls" check-project-busy.sh; then
    echo "  FAIL a script absent from PROP_LOCAL_SCRIPTS was treated as LOCAL"; rc=1
  else echo "  ok   a script the classification does not list is still checked"; fi
  if prop_is_local "$tmp/proj" verbs-refresh.sh; then
    echo "  FAIL a repo with NO propagation-set exempted a script"; rc=1
  else echo "  ok   a repo with no classification exempts nothing"; fi

  echo
  [ "$rc" -eq 0 ] && echo "self-test: PASS" || echo "self-test: FAIL"
  return "$rc"
}

if [ "$SELFTEST" = 1 ]; then self_test; exit $?; fi

# ------------------------------------------------- am I wired to anything?
# The noisy self-trigger. BUILD-DISCIPLINE pattern 2 (build-but-don't-wire)
# is the failure this project regenerates most often, and an auditor that
# sits unwired while reporting on everyone else's wiring is the joke writing
self_wiring_banner() {
  local me hits=0
  me="$(basename "${BASH_SOURCE[0]}")"
  # Herestring for the same pipefail/SIGPIPE reason as check_mute_null, and it
  # bites harder here: a 141 from a MATCHING grep would leave hits at 0 and
  # print the NOT WIRED banner over a script that is, in fact, wired.
  grep -qF "$me" <<<"$(read_crontabs)" && hits=$((hits+1))
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
    echo "## Wire it to a runner or delete it. Do not leave it standing.        ##"
    echo "## here looking like coverage.                                        ##"
    echo "########################################################################"
    echo
  fi
}

# ---------------------------------------------------------------- run
echo "silence-audit -- $(date -Is)"
echo "purpose: null-discriminator lint -- flags mechanisms that collapse"
echo "  nothing-there, could-not-look and did-not-look onto one output"
echo "  symbol (silence). Offline, writes nothing, exits 0 unless --strict."
if [ -n "$TARGET_GIVEN" ]; then
  echo "domain: the tree this run was pointed at -- ${TARGET:-$TARGET_GIVEN} (registry NOT read)"
else
  echo "domain: trees carrying $REGISTRY_MARKER under $PROJECTS_ROOT${ONLY:+ (project: $ONLY)}"
fi
echo
self_wiring_banner

check_mute_null
check_self_witness
check_home_scoped
check_stderr_silenced
check_unwired
check_prose_only_rule
check_worktree_backed
check_twin
check_subrepo_invisible

echo
if [ "${projects_seen:-0}" -eq 0 ]; then
  if [ -n "$TARGET_GIVEN" ]; then
    # A pointed run that reached zero trees is the failure shape that let #107
    # survive: it must be as loud as an unreadable registry, or "you pointed me
    # at something I could not read" renders as "your tree is clean".
    echo "BLIND -- --target $TARGET_GIVEN is not a readable project tree (no bin/ under it)."
  else
    echo "BLIND -- no tree under $PROJECTS_ROOT carries $REGISTRY_MARKER."
  fi
  echo "This is not a clean result. Nothing was audited; the domain was"
  echo "unreadable or empty. Reporting clean here would be the exact defect"
  echo "this script exists to detect."
  exit 3
fi
echo "audited $mechanisms mechanism(s); $flags FLAG(s)"
[ "$STRICT" = 1 ] && [ "$flags" -gt 0 ] && exit 1
exit 0
