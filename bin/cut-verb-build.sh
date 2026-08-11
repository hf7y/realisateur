#!/usr/bin/env bash
# cut-verb-build.sh -- pin the ecosystem's whole verb surface to one
# immutable, dated BUILD, derived live from GitHub with no clone on this
# host at all.
#
# WHY THIS EXISTS
# ---------------
# Today a verb on this host is a symlink into a `bashified` WORKTREE of a
# full development clone (`installe`, senechal bin/installe:194-213). Three
# consequences follow from that one fact, and this script exists to break
# all three:
#
#   1. You cannot delete a dev clone without breaking its verb. Removing
#      ~/Documents/Projects/vim-arcade breaks `entraine`, because
#      vim-arcade-verbs/.git is a POINTER into vim-arcade/.git/worktrees/.
#      Measured 2026-08-04: 807M of dev clones on mandark to serve 26 verbs
#      whose bashified branches total ~2.3M.
#   2. Your verbs move under you while agents work. A worktree tracks a
#      BRANCH, so the moment monkey merges to `bashified`, the next `git
#      pull` anywhere changes what `arme` means mid-sitting. There is no
#      version of the verb set to name, hold, or roll back to.
#   3. Different user paths get different verbs. zach@mandark, ecosim@monkey
#      and bibliothecaire@monkey each pull at their own moment, so "the verb
#      set" is whatever each account last happened to fetch.
#
# A BUILD answers all three: a dated manifest naming an exact sha per
# project, so every user path can install *the same named thing*, hold it
# while agents merge past it, and step back to yesterday's by name.
#
# WHAT IT READS
# -------------
# GitHub, and nothing else. The declaration rule is realisateur
# bin/lib/verb-set.sh's, unchanged:
#
#     a project declares a verb  <=>  its `bashified` branch carries an
#     executable bin/<name> AND a matching man/<name>.1
#
# but read via `gh api .../git/trees/bashified?recursive=1` instead of
# `git ls-tree` against a local checkout. verb-set.sh's header already says
# the declaration "lives in the repository, not in ~/.local" -- that was
# true of the REF and false of the PROJECT LIST, which was a scan of
# ~/Documents/Projects/*/ as directories. This reads both from the source.
#
# THE FAILURE MODE THIS REFUSES TO HAVE
# -------------------------------------
# An empty build is not a small build -- it is an instruction to uninstall
# every verb on every host. So unreachable GitHub, an unauthenticated `gh`,
# and a zero-verb result are all HARD failures that write nothing, never an
# empty manifest exiting 0. This is the `garde` shape (realisateur/
# MONKEY.md §5): `pending_sets()` skipped unreachable destinations, so
# nothing reachable read as "everything is already proven". Absent must not
# read as proven, and here it must not read as "declared nothing".
#
# For the same reason a build that SHRINKS against the previous one is a
# refusal unless --allow-shrink: losing a project's verbs because one API
# call flaked is indistinguishable, in the manifest, from a project that
# genuinely retired its verbs.
#
# AND FOR THE SAME REASON, A HALF-DECLARATION IS A REFUSAL.
# ---------------------------------------------------------
# The declaration rule is a conjunction, so it has a difference as well as an
# intersection: an executable bin/<n> with no man/<n>.1, or a man/<n>.1 with
# no executable bin/<n>. This script printed the intersection and DISCARDED
# the difference -- no count, no name, no line in the manifest -- and then
# `[ -n "$verbs" ] || continue` skipped the project entirely.
#
# What that cost, exactly: ecosim's `bin/ecosim-sensor` has been half-declared
# for its whole existence, so it was excluded from EVERY BUILD EVER CUT. What
# was visible instead was `ecosim-sensor-tick` reporting WRAPPER_NO_SENSOR on
# a host, which reads as a stale build, and cost a diagnosis that concluded
# "cut a new build" -- realisateur#66. A new build would have changed nothing.
#
# So a half-declaration is named, written into the manifest, and REFUSED. Not
# warned about: this script already refuses on two weaker conditions (a tree
# that did not read, a name declared twice), and a build that warns and
# proceeds is a build whose warnings get skimmed.
#
# The genuinely-not-a-verb case -- an installer, a cron wrapper, a scraper --
# opts out ONCE, by name, in bin/lib/not-a-verb.tsv, and every applied
# exemption is written into the manifest so the decision travels with the
# artifact every account consumes rather than living on the terminal of
# whoever ran the cut. --allow-half-declared is the per-run escape, and it is
# the same shape as --allow-shrink: the operator who has already filed the
# defect can still cut tonight's build, loudly, with the finding recorded in
# the manifest.
set -uo pipefail

CLI_NAME='cut-verb-build.sh'
CLI_SUMMARY='pin every declared verb to one dated build manifest, read live from GitHub'
CLI_USAGE='  cut-verb-build.sh                    derive and print the manifest to stdout
  cut-verb-build.sh --write            also store it under the build root
  cut-verb-build.sh --assemble <dir>   lay every verb out under <dir> (what CI commits)
  cut-verb-build.sh --allow-shrink     accept a build with fewer verbs than the last
  cut-verb-build.sh --allow-half-declared
                                       accept a project that declares half a verb
  cut-verb-build.sh --dry-run          derive and check the manifest SHAPE only; never a build'
CLI_FLAGS='--write --assemble --allow-shrink --allow-half-declared --dry-run --owner --build-root'
CLI_POSITIONAL=any   # flag VALUES (--build <id>) read as positionals to cli-guard;
                     # the arg loop below rejects anything genuinely unknown.
CLI_EXITS='  0  a complete manifest was derived
  1  refused: BLIND (cannot read GitHub), empty, shrinking, a name declared
     twice, or a HALF-declared verb (bin/<n> with no man/<n>.1, or the inverse)
  2  usage error'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

OWNER="${VERB_BUILD_OWNER:-hf7y}"
BUILD_ROOT="${VERB_BUILD_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/verb-builds}"
WRITE=0
ALLOW_SHRINK=0
ALLOW_HALF=0
ASSEMBLE=''
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --write)        WRITE=1 ;;
    --assemble)     ASSEMBLE="${2:?--assemble needs a directory}"; shift ;;
    --allow-shrink) ALLOW_SHRINK=1 ;;
    --allow-half-declared) ALLOW_HALF=1 ;;
    --dry-run)      DRY_RUN=1 ;;
    --owner)        OWNER="${2:?--owner needs a value}"; shift ;;
    --build-root)   BUILD_ROOT="${2:?--build-root needs a value}"; shift ;;
    *) printf '%s: unknown argument: %s\n' "$CLI_NAME" "$1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*" >&2; }
die() { printf '%s: %s\n' "$CLI_NAME" "$*" >&2; exit 1; }

# --- the not-a-verb opt-out, loaded from ONE file -----------------------
# Rows are <project>\t<name>\t<why>. Read from a file rather than a case
# statement in here so the judgement is reviewable next to the rule it bends
# (lib/verb-set.sh states the rule; lib/not-a-verb.tsv states its exceptions),
# and so adding one is a diff a reader can see rather than a line in a 470-line
# script.
#
# ABSENT MEANS NOTHING IS EXEMPT, which fails toward the refusal rather than
# away from it -- a broken checkout produces a loud build, never a quiet one.
# It still says so, because "no exemptions apply" and "the file was not there"
# are the two states this ecosystem keeps conflating.
NOT_A_VERB="${VERB_NOT_A_VERB_FILE:-$(dirname "${BASH_SOURCE[0]}")/lib/not-a-verb.tsv}"
exempt=''
if [ -f "$NOT_A_VERB" ]; then
  exempt="$(grep -v '^[[:space:]]*#' "$NOT_A_VERB" \
            | awk -F'\t' 'NF>=2 && $1 != "" && $2 != "" {
                            printf "%s\t%s\t%s\n", $1, $2, ($3 == "" ? "(no reason recorded)" : $3) }')"
else
  say "  note: $NOT_A_VERB not found -- no not-a-verb exemptions will apply"
fi

# exempt_reason <project> <name> -- prints the recorded reason, rc 0 if exempt.
exempt_reason() {
  printf '%s\n' "$exempt" \
    | awk -F'\t' -v p="$1" -v n="$2" '$1 == p && $2 == n { print $3; f = 1; exit } END { exit !f }'
}

# --dry-run is for CI that has NO org credential -- see the smoke workflow.
# It must therefore be incapable of producing anything a host could install,
# because a dry run's read is short BY CONSTRUCTION (a token that can only
# see public repositories derives a build missing every private project),
# and a short build that looks complete is the exact failure this whole
# script is built to refuse. So the two flags are mutually exclusive at the
# argument level rather than "handled" later.
if [ "$DRY_RUN" -eq 1 ] && { [ -n "$ASSEMBLE" ] || [ "$WRITE" -eq 1 ]; }; then
  printf '%s: --dry-run cannot be combined with --assemble or --write: a dry run reads with whatever credential it has, so its build is short by an unknown amount and must never become an artifact.\n' \
    "$CLI_NAME" >&2
  exit 2
fi

# An unreadable repository must FAIL LOUDLY, never sit waiting for a
# password. git ls-remote against a repo the credential cannot read will ask
# a terminal for one; in CI there is no terminal and the job hangs to the
# six-hour limit, and on a host it stops a nightly cut dead. Refused here,
# so the call returns non-zero -- which section 2 counts as BLIND rather
# than as "this project has no bashified branch". Those two look identical
# in an empty sha and mean opposite things.
export GIT_TERMINAL_PROMPT=0

command -v gh >/dev/null 2>&1 || die 'gh is not on PATH -- cannot read the declarations. Refusing to cut an empty build.'
gh auth status >/dev/null 2>&1 \
  || die 'gh is not authenticated. Refusing: an unauthenticated read sees no private repo and would cut a SHORT build that looks complete.'

# --- 1. which repositories carry a bashified branch ---------------------
# `gh repo list` rather than a typed list: a project that bashifies itself
# tomorrow joins the build with nobody editing a file. The private repos
# are why authentication is checked above and not merely hoped for.
#
# --no-archived is not tidiness; it is the RETIREMENT MECHANISM. Deriving
# live from the account means a repository nobody has opened in a year still
# declares its verbs forever, and a host-local scan never had to think about
# that because a dormant project simply was not cloned. Archiving is how a
# project says "I am no longer a participant" -- reversibly, in one place,
# visible to everyone.
#
# Found the hard way 2026-08-04: `cueille` was declared by BOTH
# bibliothecaire and quatre-vingt-douze. quatre-vingt-douze had already been
# folded into bibliothecaire by decision, but nothing mechanical recorded
# that, so it kept declaring a verb it no longer owned.
say "reading $OWNER's repositories ..."
repos="$(gh repo list "$OWNER" --limit 200 --no-archived --json name -q '.[].name' 2>/dev/null)" \
  || die "cannot list $OWNER's repositories -- BLIND, not empty."
[ -n "$repos" ] || die "$OWNER has no readable repositories -- BLIND, not empty."

# --- 2. per repo: the bashified sha, then the verbs in that exact tree ---
# ls-remote gives the sha, and the tree is then read AT THAT SHA rather
# than at the branch name. Reading at the name would race a merge landing
# between the two calls and pin a sha whose contents were never inspected.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
rows="$tmp/rows"; : > "$rows"
halves="$tmp/halves"; : > "$halves"
blind=0
half_bad=0
projects=0

for repo in $repos; do
  # rc is read BEFORE the pipe, because "ls-remote succeeded and this repo
  # has no bashified branch" and "ls-remote could not read this repo at all"
  # both come out as an empty sha and mean opposite things: the first is the
  # normal answer for most repos, the second is blindness.
  # git's stderr is CAPTURED, not discarded. It was `2>/dev/null`, and on
  # 2026-08-05 the first real CI build refused with seventeen lines of
  # "listed by the API but git could not read it" and no way to tell an
  # auth denial from a missing repo from a network fault -- three causes,
  # one message, three completely different fixes. A diagnostic that
  # filters the evidence it exists to report is a blind spot, not tidiness.
  giterr="$tmp/giterr"
  refs="$(git ls-remote "https://github.com/$OWNER/$repo.git" refs/heads/bashified 2>"$giterr")"
  if [ $? -ne 0 ]; then
    # One line, and the credential is never echoed: the insteadOf rewrite
    # puts a token in the URL, so git's own message can contain it.
    reason="$(sed -e 's|https://[^@]*@|https://<redacted>@|g' "$giterr" 2>/dev/null | grep -v '^$' | head -1)"
    case "$reason" in
      *"Authentication failed"*|*"could not read Username"*|*"403"*|*"Permission"*)
        hint=" -- the credential cannot READ this repository's contents. A fine-grained PAT needs Contents: Read, not only Metadata: Read; listing succeeded, so Metadata is already granted." ;;
      *"not found"*|*"404"*|*"Repository not found"*)
        # Reaching this line means `gh repo list` ALREADY returned this repo,
        # so the credential can see it. git then 404ing is not ambiguity --
        # GitHub masks a contents-403 as a 404 for private repos, and a
        # fine-grained PAT that has Metadata but not Contents produces
        # exactly this pair. Said definitely, because a hedge here sends the
        # reader to re-pick repositories in a token that already lists them.
        hint=" -- but the API LISTED this repo, so the credential sees it and only its CONTENTS are refused. GitHub reports a contents-403 as 404 on a private repo. Fix: grant the fine-grained PAT 'Contents: Read' (Repository permissions), then re-run. Re-selecting repositories will not help; they are already selected." ;;
      *) hint="" ;;
    esac
    say "  BLIND  $repo: git could not read it: ${reason:-<no stderr>}$hint"
    blind=$((blind + 1))
    continue
  fi
  sha="$(printf '%s\n' "$refs" | awk 'NR==1{print $1}')"
  # No bashified branch is a normal answer: most repos are not bashified.
  [ -n "$sha" ] || continue

  tree="$(gh api "repos/$OWNER/$repo/git/trees/$sha?recursive=1" \
            -q '.tree[] | select(.path|test("^(bin|man)/")) | "\(.mode) \(.path)"' 2>/dev/null)"
  if [ -z "$tree" ]; then
    # A repo WITH a bashified branch whose tree will not read is the
    # ambiguous case: it is either genuinely verbless or a failed call.
    # Counted as blindness rather than silently contributing zero verbs.
    say "  BLIND  $repo: bashified is $sha but its tree did not read"
    blind=$((blind + 1))
    continue
  fi

  # The declaration rule, applied to the fetched tree. Same two conditions
  # as verb-set.sh: executable bin/<n> AND man/<n>.1. bibliothecaire's
  # bin/page92.py is executable, has no page, and correctly is not a verb --
  # which is why it has a row in lib/not-a-verb.tsv and not a man page.
  #
  # BOTH HALVES COME OUT OF THE SAME PASS. The END block used to be one loop
  # over the intersection; the difference was computed and thrown away in the
  # same breath. Emitting it costs two more loops over data awk already has.
  decl="$(printf '%s\n' "$tree" | awk '
      $1 == "100755" && $2 ~ /^bin\/[^\/]+$/ { n = substr($2, 5); exec_[n] = 1 }
      $2 ~ /^man\/[^\/]+\.1$/ { n = $2; sub(/^man\//, "", n); sub(/\.1$/, "", n); page[n] = 1 }
      END {
        for (n in exec_) if (n in page)     print "VERB\t" n
        for (n in exec_) if (!(n in page))  print "HALF\t" n "\texecutable bin/" n " with no man/" n ".1"
        for (n in page)  if (!(n in exec_)) print "HALF\t" n "\tman/" n ".1 with no executable bin/" n
      }
    ' | sort)"
  verbs="$(printf '%s\n' "$decl" | awk -F'\t' '$1 == "VERB" { print $2 }')"

  # Recorded BEFORE the `continue` below. A project whose every executable is
  # half-declared derives no verbs at all, and skipping it here for that reason
  # is precisely how ecosim's whole bin/ went unmentioned for weeks.
  # A here-string, not a pipe: half_bad has to survive the loop.
  while IFS=$'\t' read -r tag name why; do
    [ "$tag" = HALF ] || continue
    if reason="$(exempt_reason "$repo" "$name")"; then
      printf 'NOT-A-VERB\t%s\t%s\t%s\n' "$repo" "$name" "$reason" >> "$halves"
    else
      say "  HALF-DECLARED  $repo/$name: $why -- NOT declared, omitted from this build"
      printf 'HALF-DECLARED\t%s\t%s\t%s\n' "$repo" "$name" "$why" >> "$halves"
      half_bad=$((half_bad + 1))
    fi
  done <<< "$decl"

  [ -n "$verbs" ] || continue

  projects=$((projects + 1))
  while read -r v; do
    [ -n "$v" ] || continue
    printf '%s\t%s\t%s\t%s\n' "$repo" "$v" "$sha" "https://github.com/$OWNER/$repo.git" >> "$rows"
  done <<< "$verbs"
done

[ "$blind" -eq 0 ] || die "$blind repository tree(s) did not read. Refusing to cut a build that is short by an unknown amount."

# --- 2a. half-declarations ----------------------------------------------
# Same posture as the two refusals on either side of this line: a build that
# is short by an unknown amount is refused, and so is one that is short by a
# KNOWN amount it never mentioned. The names are already on stderr, one line
# each, from the loop above.
exempt_count="$(grep -c '^NOT-A-VERB' "$halves" || true)"
[ "$exempt_count" -eq 0 ] || \
  say "  $exempt_count executable(s) recorded as not-a-verb in $NOT_A_VERB -- each is named in the manifest"
if [ "$half_bad" -gt 0 ]; then
  if [ "$ALLOW_HALF" -eq 0 ]; then
    die "$half_bad HALF-declared name(s), listed above. A project declares a verb only with BOTH an executable bin/<name> and a matching man/<name>.1; half of that is silently omitted, and the symptom surfaces later and somewhere else as a wrapper failing on a path that was never going to exist (realisateur#66). Fix the declaration in the project, or -- if it is genuinely not a verb -- give it a row in $NOT_A_VERB. --allow-half-declared cuts anyway and records the finding in the manifest."
  fi
  say "  --allow-half-declared: cutting with $half_bad half-declaration(s) UNFIXED. They are omitted from this build and named in its manifest."
fi

verb_count="$(wc -l < "$rows" | tr -d ' ')"
[ "$verb_count" -gt 0 ] || die 'derived zero verbs. That is a BLIND read, not an ecosystem with no verbs.'

# --- 3. a name may be declared by exactly one project -------------------
# verb-set.sh exists because `range` was assigned to both bibliothecaire
# and secretaire on 2026-07-30. Two claimants is a build that cannot be
# installed unambiguously, so it is refused here rather than resolved by
# whichever `ln -s` runs last.
dupes="$(awk -F'\t' '{print $2}' "$rows" | sort | uniq -d)"
if [ -n "$dupes" ]; then
  while read -r d; do
    [ -n "$d" ] || continue
    say "  COLLISION  $d declared by: $(awk -F'\t' -v w="$d" '$2==w{printf "%s ", $1}' "$rows")"
  done <<< "$dupes"
  die 'a verb name is declared by more than one project. Refusing.'
fi

# --- 4. compare against the previous build ------------------------------
# WHERE "the previous build" LIVES DEPENDS ENTIRELY ON WHO IS RUNNING.
#
# A human at a terminal has one under $BUILD_ROOT/current. CI DOES NOT: a
# GitHub Actions runner is a fresh machine every night, $BUILD_ROOT never
# exists, prev_count stayed 0 -- and so the shrink refusal, the check whose
# whole purpose is to catch a NIGHTLY build that lost a project to a flaked
# API call, was a no-op in the one place it was ever going to matter. Found
# 2026-08-04 while hardening the workflow, before the meta-repo had cut a
# single build.
#
# The previous build is not missing in CI, it is merely somewhere else: the
# meta-repo checkout being assembled INTO carries the last build's own
# manifest.tsv. So --assemble supplies the comparison, and the LARGER of the
# two records wins -- a shrink is a shrink whichever one noticed it.
prev_count=0
prev_where='(no previous build)'
if [ -L "$BUILD_ROOT/current" ] && [ -f "$BUILD_ROOT/current/manifest.tsv" ]; then
  prev_count="$(grep -cv '^#' "$BUILD_ROOT/current/manifest.tsv" 2>/dev/null || echo 0)"
  prev_where="$BUILD_ROOT/current/manifest.tsv"
fi
if [ -n "$ASSEMBLE" ] && [ -f "$ASSEMBLE/manifest.tsv" ]; then
  assembled_prev="$(grep -cv '^#' "$ASSEMBLE/manifest.tsv" 2>/dev/null || echo 0)"
  if [ "$assembled_prev" -gt "$prev_count" ]; then
    prev_count="$assembled_prev"
    prev_where="$ASSEMBLE/manifest.tsv"
  fi
fi
if [ "$prev_count" -gt "$verb_count" ] && [ "$ALLOW_SHRINK" -eq 0 ]; then
  say "  previous build: $prev_count verb(s)  <- $prev_where"
  say "  this build:     $verb_count verb(s)"
  die 'this build is SMALLER than the current one. A verb that vanished because an API call flaked looks exactly like one that was retired. Re-run, or pass --allow-shrink if the loss is real.'
fi

# --- 5. emit ------------------------------------------------------------
# The build id is a UTC date-time so builds sort lexically and a nightly
# job never collides with a hand-cut one in the same day.
build_id="$(date -u +%Y-%m-%dT%H%M%SZ)"
manifest="$tmp/manifest.tsv"
{
  printf '# verb build %s\n' "$build_id"
  printf '# cut by %s from github.com/%s on %s\n' "$CLI_NAME" "$OWNER" "$(hostname -s)"
  printf '# %d verb(s), %d project(s). Immutable: install this by id, never by branch.\n' \
         "$verb_count" "$projects"
  # WHAT THIS BUILD DECIDED NOT TO INCLUDE, AND WHY -- in the artifact every
  # account consumes, not only on the terminal of whoever ran the cut. A
  # half-declaration's whole failure mode is that its consequence lands on a
  # different host, weeks later, as a missing path; the manifest is the one
  # thing that travels with it. Comment rows, so every consumer's
  # `grep -v '^#'` and this script's own shape check are unaffected.
  if [ -s "$halves" ]; then
    printf '# %d name(s) on a bashified branch are NOT in this build. NOT-A-VERB rows\n' \
           "$(wc -l < "$halves" | tr -d ' ')"
    printf '# are recorded judgements (%s); HALF-DECLARED rows are unresolved defects.\n' \
           "$(basename "$NOT_A_VERB")"
    sed 's/^/# /' "$halves" | sort
  fi
  printf '# project\tverb\tsha\trepo_url\n'
  sort "$rows"
} > "$manifest"

# --- 5a. the manifest's SHAPE -------------------------------------------
# Four tab-separated fields, a 40-hex sha, and a repo_url that names the
# project it claims to come from. This is cheap and it is the only part of
# the pipeline a credential-less CI can exercise (see --dry-run), so it is
# checked on EVERY run rather than only on dry ones: a malformed row reaches
# install-verb-build.sh as a verb it will look for and not find, and that
# consumer is required to discard the whole build over it. Better to refuse
# to emit than to make a downstream host prove the build wrong.
shape_bad=0
while IFS= read -r line; do
  case "$line" in '#'*|'') continue ;; esac
  n_fields="$(printf '%s' "$line" | awk -F'\t' '{print NF}')"
  IFS=$'\t' read -r s_project s_verb s_sha s_url <<< "$line"
  if [ "$n_fields" -ne 4 ]; then
    say "  MALFORMED  not 4 tab-separated fields: $line"; shape_bad=$((shape_bad+1)); continue
  fi
  case "$s_sha" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) : ;;
    *) say "  MALFORMED  sha is not 40 hex for $s_project/$s_verb: '$s_sha'"; shape_bad=$((shape_bad+1)) ;;
  esac
  case "$s_url" in
    *"/$s_project.git") : ;;
    *) say "  MALFORMED  repo_url does not name $s_project: '$s_url'"; shape_bad=$((shape_bad+1)) ;;
  esac
  case "$s_verb" in
    ''|*/*|.|..) say "  MALFORMED  unusable verb name: '$s_verb'"; shape_bad=$((shape_bad+1)) ;;
  esac
done < "$manifest"
[ "$shape_bad" -eq 0 ] || die "$shape_bad malformed manifest row(s). Refusing to emit a manifest a consumer would have to discard."

if [ "$DRY_RUN" -eq 1 ]; then
  cat "$manifest"
  say ""
  say "DRY RUN. $verb_count verb(s) from $projects project(s), manifest shape OK."
  say "This is NOT a build and NOTHING was written. The count above is only"
  say "as complete as the credential this ran with: a token that can read"
  say "just the public repositories derives a manifest missing every private"
  say "project and looks entirely healthy doing it. Do not read this number"
  say "as the size of the verb surface."
  exit 0
fi

cat "$manifest"
say ""
say "derived $verb_count verb(s) from $projects project(s)"

# --- 6. assemble the tree CI commits ------------------------------------
# The meta-repo's whole content, laid out as <project>/bin/<verb> +
# <project>/man/<verb>.1, so a consumer clones ONE repository instead of
# fetching from N. This is what makes a new self-dev account need read on
# one repo rather than four hand-made per-repo deploy keys
# (realisateur/MONKEY.md §8.1: "the credentials were a memory, not a
# script").
#
# Assembled from the SHA, never the branch name -- `bashified` may have
# moved since the manifest was derived minutes ago, and committing a tree
# the manifest does not describe would make the pin a lie.
if [ -n "$ASSEMBLE" ]; then
  mkdir -p "$ASSEMBLE" || die "cannot create $ASSEMBLE"
  # Only ever prune paths this build owns. A blanket wipe of $ASSEMBLE
  # would take the meta-repo's own .git, README and workflow with it.
  while IFS=$'\t' read -r project _ _ _; do
    [ -n "$project" ] || continue
    printf '%s\n' "$project"
  done < "$rows" | sort -u > "$tmp/projects"

  # WHAT THE PREVIOUS BUILD OWNED, so retirement can actually take effect.
  #
  # Each project directory is rm -rf'd and re-copied below, so a project
  # that CHANGED is handled. A project that LEFT was not: nothing removed
  # its directory, so its verbs stayed in the meta-repo tree, git add -A
  # re-committed them every night, and every consumer kept installing a
  # verb the manifest no longer names. That is not a cosmetic leak -- it
  # silently voids the retirement mechanism VERB-DISTRIBUTION.md section 5
  # rests on. `quatre-vingt-douze` was archived on 2026-08-04 precisely so
  # that `cueille` would stop being declared twice; with this loop missing,
  # archiving it would have removed the row from the manifest and left the
  # executable sitting in the build.
  #
  # Verified 2026-08-04: three assembles into one directory, with a fake
  # `quatre-vingt-douze/bin/cueille` planted between runs; it survived all
  # of them. bin/tests/cut-verb-build-test.sh now holds that case.
  #
  # The previous build's OWN manifest is the authority on what to prune --
  # never a directory listing. $ASSEMBLE also contains the meta-repo's
  # README, its .github/ and its .git, and guessing which top-level entries
  # are projects would eventually delete one of those.
  if [ -f "$ASSEMBLE/manifest.tsv" ]; then
    awk -F'\t' '!/^#/ && NF>=1 && $1 != "" {print $1}' "$ASSEMBLE/manifest.tsv" \
      | sort -u > "$tmp/prev-projects"
    while read -r gone; do
      [ -n "$gone" ] || continue
      case "$gone" in */*|.|..) continue ;; esac   # never leave $ASSEMBLE
      [ -d "$ASSEMBLE/$gone" ] || continue
      rm -rf "${ASSEMBLE:?}/$gone"
      say "  RETIRED  $gone no longer declares a verb -- removed from the build"
    done < <(comm -23 "$tmp/prev-projects" "$tmp/projects")
  fi

  while read -r project; do
    [ -n "$project" ] || continue
    sha="$(awk -F'\t' -v p="$project" '$1==p{print $3; exit}' "$rows")"
    url="$(awk -F'\t' -v p="$project" '$1==p{print $4; exit}' "$rows")"
    work="$tmp/fetch/$project"
    mkdir -p "$work"
    git -C "$work" init -q 2>/dev/null || die "git init failed for $project"
    git -C "$work" remote add origin "$url" 2>/dev/null || die "git remote failed for $project"
    git -C "$work" fetch -q --depth 1 origin "$sha" 2>/dev/null \
      || die "cannot fetch $project at $sha -- refusing to assemble a partial build"
    git -C "$work" checkout -q FETCH_HEAD 2>/dev/null \
      || die "cannot check out $sha for $project"

    rm -rf "${ASSEMBLE:?}/$project"
    mkdir -p "$ASSEMBLE/$project"
    # THE WHOLE bashified TREE, not just bin/ + man/.
    #
    # This copied only bin/ and man/ first, on the reasoning that a build's
    # job is to be executable. Every verb in the resulting build was broken:
    #
    #   ./sequestria/bin/capte: line 19: .../sequestria/lib/verb.sh:
    #       No such file or directory
    #   ./sequestria/bin/capte: line 31: verb_parse: command not found
    #
    # Verbs source `lib/verb.sh` from their project root, and each project
    # carries its OWN copy (they have already forked -- gardien-garde's is
    # uniquely richer). So the lib travels per project or not at all.
    #
    # Copying the tree wholesale rather than adding `lib` to the list,
    # because the next such dependency would fail exactly the same way and
    # the bashified branch is already a total purge -- the whole tree is
    # ~30K per project. Guessing which subdirectories matter is what broke
    # this once already.
    rm -rf "$work/.git"
    cp -a "$work/." "$ASSEMBLE/$project/"
    say "  assembled $project at ${sha:0:12}"
  done < "$tmp/projects"

  cp "$manifest" "$ASSEMBLE/manifest.tsv"
  printf '%s\n' "$build_id" > "$ASSEMBLE/BUILD_ID"

  # Prove the tree matches the promise before CI is allowed to commit it.
  #
  # THE EXECUTABLE BIT IS NOT A WITNESS. This check was `-f && -x` and it
  # passed on a build in which EVERY VERB WAS BROKEN -- the lib/ omission
  # above. The file existed and was executable; it just could not run.
  # BUILD-DISCIPLINE's rule ("'working' backed by a test name or human-sense
  # witness, not exit code alone") applies to the builder as much as to what
  # it builds, so the witness is now: the verb runs, prints its own name,
  # and does not report a missing file or an undefined function.
  #
  # `--help` is the safe invocation: every bashified verb routes it through
  # lib/verb.sh or lib/cli-guard.sh before doing any work. Bounded by
  # timeout so one hung verb cannot hang the nightly build.
  bad=0
  while IFS=$'\t' read -r project verb _ _; do
    [ -n "${verb:-}" ] || continue
    f="$ASSEMBLE/$project/bin/$verb"
    if [ ! -f "$f" ] || [ ! -x "$f" ]; then
      say "  BAD $project/bin/$verb missing or not executable"; bad=$((bad+1)); continue
    fi
    out="$(timeout 20 "$f" --help 2>&1)"; rc=$?
    case "$out" in
      *'No such file or directory'*|*'command not found'*|*'unbound variable'*)
        say "  BAD $project/bin/$verb ran but is missing something it sources:"
        say "      $(printf '%s' "$out" | head -1)"
        bad=$((bad + 1)); continue ;;
    esac
    # 0 is the norm; some verbs treat --help as a usage exit. Anything else
    # (including the 124 timeout) is a verb that cannot introduce itself.
    case "$rc" in
      0|2) : ;;
      *) say "  BAD $project/bin/$verb --help exited $rc"; bad=$((bad + 1)) ;;
    esac
  done < <(grep -v '^#' "$manifest")
  [ "$bad" -eq 0 ] || die "$bad verb(s) did not assemble runnably. Refusing."

  # --- 6a. every command declares which CHANNEL it belongs to -------------
  # bin/verb-kind-lint.sh, run against the tree that was just assembled --
  # which is the only place in this pipeline where the files are on local
  # disk and their headers can be read for free. Section 2 reads the git
  # TREE listing (paths and modes), not blobs, so asking this question there
  # would cost one extra API call per verb inside the loop whose flakes
  # already produce the BLIND refusals above.
  #
  # WHAT IT REFUSES. A product declaring `# KIND: product` must not ride the
  # nightly workchain cut: this build is deliberately built NOT to move
  # between cuts (see provision/verbs-meta/build-verbs.yml, "that stability
  # is the feature"), and a product wants the opposite. And a command that
  # declares NOTHING and was not in the build when the grandfather ratchet
  # was seeded is refused on its first night, which is what stops the next
  # product entering the same way this one did.
  #
  # NOT run under --dry-run: a dry run's read is short by an unknown amount
  # by construction, so its manifest is the wrong population to grade.
  #
  # This lint lives in realisateur beside this script, so it is found
  # relative to THIS file rather than looked up on PATH -- CI stages this
  # repository at a path of its own choosing and there is no `verb-kind-lint`
  # on a runner's PATH.
  kindlint="$(dirname "${BASH_SOURCE[0]}")/verb-kind-lint.sh"
  if [ ! -f "$kindlint" ]; then
    # A missing guard is a finding, not an inconvenience.
    die "cannot find verb-kind-lint.sh beside this script. Refusing to cut a build whose channel declarations were never checked."
  fi
  krc=0
  bash "$kindlint" --build "$ASSEMBLE" >&2 || krc=$?
  case "$krc" in
    0) : ;;
    2) die 'verb-kind-lint could not read the assembled build. That is BLIND, not clean -- refusing.' ;;
    *) die 'the assembled build carries a command in the wrong channel, or one that declares no channel at all. See the lines above. Refusing.' ;;
  esac

  say "assembled $verb_count verb(s) under $ASSEMBLE"
fi

if [ "$WRITE" -eq 1 ]; then
  dest="$BUILD_ROOT/$build_id"
  mkdir -p "$dest" || die "cannot create $dest"
  cp "$manifest" "$dest/manifest.tsv"
  say "wrote $dest/manifest.tsv"
  say "install it with: install-verb-build.sh --build $build_id --apply"
fi
exit 0
