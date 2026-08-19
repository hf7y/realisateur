#!/usr/bin/env bash
# cut-verb-build.sh -- pin the ecosystem's whole verb surface to one dated,
# immutable BUILD, read live from GitHub with no clone on this host.
#
# A verb is declared by a project's `bashified` branch carrying an executable
# bin/<name> AND a matching man/<name>.1 -- the rule is bin/lib/verb-set.sh's.
# Opt out by name in bin/lib/not-a-verb.tsv.
#
# Every refusal below says so when it fires: an absent verb and a retired one
# are indistinguishable in a manifest.
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
VERB_META_REPO="${VERB_META_REPO:-verbs}"   # holds the published manifest the guard compares against
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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

# --dry-run is for CI with NO org credential (the smoke workflow). Its read is
# short BY CONSTRUCTION, so it must be incapable of producing an installable.
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
if [ "$DRY_RUN" -eq 1 ] && { [ -n "$ASSEMBLE" ] || [ "$WRITE" -eq 1 ]; }; then
  printf '%s: --dry-run cannot be combined with --assemble or --write: a dry run reads with whatever credential it has, so its build is short by an unknown amount and must never become an artifact.\n' \
    "$CLI_NAME" >&2
  exit 2
fi

# An unreadable repository must FAIL LOUDLY, never sit waiting for a
# password. git ls-remote against a repo the credential cannot read will ask
# a terminal for one; in CI there is no terminal and the job hangs to the
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
export GIT_TERMINAL_PROMPT=0

command -v gh >/dev/null 2>&1 || die 'gh is not on PATH -- cannot read the declarations. Refusing to cut an empty build.'
gh auth status >/dev/null 2>&1 \
  || die 'gh is not authenticated. Refusing: an unauthenticated read sees no private repo and would cut a SHORT build that looks complete.'

# --- 1. which repositories carry a bashified branch ---------------------
# `gh repo list` rather than a typed list: a project that bashifies itself
# tomorrow joins the build with nobody editing a file. The private repos
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
say "reading $OWNER's repositories ..."
repos="$(gh repo list "$OWNER" --limit 200 --no-archived --json name -q '.[].name' 2>/dev/null)" \
  || die "cannot list $OWNER's repositories -- BLIND, not empty."
[ -n "$repos" ] || die "$OWNER has no readable repositories -- BLIND, not empty."

# --- 1b. THE REGISTRY: which repos are agent PROJECTS ----------------------
#
# Distinct from the verb set, and the difference is the whole reason this
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
REGISTRY_MARKER="${REGISTRY_MARKER:-.agent-project}"
registry=""
_gql='query($owner:String!){ user(login:$owner){ repositories(first:100, isFork:false, ownerAffiliations:OWNER){
        nodes{ name isArchived marker: object(expression:"HEAD:'"$REGISTRY_MARKER"'"){ __typename } } } } }'
if _reg="$(gh api graphql -F owner="$OWNER" -f query="$_gql" \
             --jq '.data.user.repositories.nodes[] | select(.marker != null and .isArchived == false) | .name' 2>/dev/null)"; then
  registry="$_reg"
  say "registry: $(printf '%s\n' "$registry" | grep -c .) project(s) carry $REGISTRY_MARKER"
else
  # BLIND, and it must not read as "no projects". An empty registry written
  # into the manifest would tell every consumer the estate has no projects,
  # which is an instruction to scan nothing -- the exact shape section 5's
  # BLIND refusal exists to prevent for the verb set.
  say "registry: BLIND -- the marker query failed. Recording NO registry rows"
  say "          rather than an empty one; consumers must treat absence as"
  say "          'could not look', never as 'there are none'."
  registry=""
fi

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
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
        #   [rest: vault:realisateur/guard-archaeology-20260817.md]
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

  # VERBLESS IS NOT BLIND. Filtering to bin/ and man/ inside the fetch made
  # "the call failed" and "declares no verbs" the same empty string, scored as
  # blindness -- so retiring a repo's last verb froze the whole estate's build
  # (2026-08-18: five repos, refused as "did not read", nothing wrong with any
  # of them). Fetch the WHOLE tree and judge the CALL by it, since a git tree
  # is never empty; then filter, and let the filter come back empty in peace.
  whole="$(gh api "repos/$OWNER/$repo/git/trees/$sha?recursive=1" \
             -q '.tree[] | "\(.mode) \(.path)"' 2>/dev/null)"
  if [ -z "$whole" ]; then
    say "  BLIND  $repo: bashified is $sha but its tree did not read"
    blind=$((blind + 1))
    continue
  fi
  tree="$(printf '%s\n' "$whole" | grep -E '^[0-9]+ (bin|man)/' || :)"
  if [ -z "$tree" ]; then
    say "  none   $repo: bashified carries no bin/ or man/ -- declares no verbs"
    continue
  fi

  # The declaration rule, applied to the fetched tree. Same two conditions
  # as verb-set.sh: executable bin/<n> AND man/<n>.1. bibliothecaire's
  # bin/page92.py is executable, has no page, and correctly is not a verb --
  # which is why it has a row in lib/not-a-verb.tsv and not a man page.
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
# WHERE IT LIVES DEPENDS ON WHO IS RUNNING. The published manifest is read
# FIRST -- the only reading that exists everywhere. $BUILD_ROOT is a CONSUMER
# path: absent on the CI runner that cuts nightly, so #399 lost 17 in silence.
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
prev_count=0
prev_where='(nothing published, nothing local)'
if [ "$DRY_RUN" -eq 1 ]; then   # a short read grades the credential, not this
  prev_where='(skipped: --dry-run reads a subset)'
elif published="$(gh api "repos/$OWNER/$VERB_META_REPO/contents/manifest.tsv" \
                  --jq '.content' 2>/dev/null | base64 -d 2>/dev/null)" \
   && [ -n "$published" ]; then
  prev_count="$(printf '%s\n' "$published" | grep -cv '^#' || echo 0)"
  prev_where="github.com/$OWNER/$VERB_META_REPO manifest.tsv"
fi
if [ "$DRY_RUN" -eq 0 ] && [ -L "$BUILD_ROOT/current" ] && [ -f "$BUILD_ROOT/current/manifest.tsv" ]; then
  local_prev="$(grep -cv '^#' "$BUILD_ROOT/current/manifest.tsv" 2>/dev/null || echo 0)"
  if [ "$local_prev" -gt "$prev_count" ]; then
    prev_count="$local_prev"
    prev_where="$BUILD_ROOT/current/manifest.tsv"
  fi
fi
if [ -n "$ASSEMBLE" ] && [ -f "$ASSEMBLE/manifest.tsv" ]; then
  assembled_prev="$(grep -cv '^#' "$ASSEMBLE/manifest.tsv" 2>/dev/null || echo 0)"
  if [ "$assembled_prev" -gt "$prev_count" ]; then
    prev_count="$assembled_prev"
    prev_where="$ASSEMBLE/manifest.tsv"
  fi
fi
[ "$prev_count" -gt 0 ] || say "  note: no previous build readable $prev_where -- the shrink guard cannot fire"
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
  # THE REGISTRY, as comment rows so every consumer's `grep -v '^#'` and this
  # script's own shape check are unaffected -- the manifest's data rows stay
  # exactly "one verb per line" and nothing downstream has to learn a second
  # row type.
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  if [ -n "$registry" ]; then
    printf '# registry: %d project(s) carrying %s on their default branch.\n' \
           "$(printf '%s\n' "$registry" | grep -c .)" "$REGISTRY_MARKER"
    printf '# A PROJECT is not the same set as a repo (46 non-archived here) nor as a\n'
    printf '# verb declarer (12): chezz is registered and declares nothing. Read this\n'
    printf '# block, not `gh repo list`, when you need "what projects exist".\n'
    printf '%s\n' "$registry" | grep . | sed 's/^/# registry\t/'
  fi
  # WHAT THIS BUILD DECIDED NOT TO INCLUDE, AND WHY -- in the artifact every
  # account consumes, not only on the terminal of whoever ran the cut. A
  # half-declaration's whole failure mode is that its consequence lands on a
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
    #   [rest: vault:realisateur/guard-archaeology-20260817.md]
    rm -rf "$work/.git"
    cp -a "$work/." "$ASSEMBLE/$project/"
    say "  assembled $project at ${sha:0:12}"
  done < "$tmp/projects"

  cp "$manifest" "$ASSEMBLE/manifest.tsv"
  printf '%s\n' "$build_id" > "$ASSEMBLE/BUILD_ID"

  # Prove the tree matches the promise before CI is allowed to commit it.
  #
  # THE EXECUTABLE BIT IS NOT A WITNESS. This check was `-f && -x` and it
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
