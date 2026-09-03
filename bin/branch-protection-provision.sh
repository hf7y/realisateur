#!/usr/bin/env bash
set -uo pipefail

CLI_NAME='branch-protection-provision.sh'
CLI_SUMMARY='require what you run: derive every registered repo'"'"'s required checks from the workflows it actually runs, and report the delta. Argument, traps and the per-repo table: hf7y/realisateur#781'
CLI_USAGE='  branch-protection-provision.sh                     --check (default): report, write nothing
  branch-protection-provision.sh <repo>...           report for named repo(s)
  branch-protection-provision.sh --apply [<repo>...] ADD the witnessed checks a repo runs but does not require

  Removal is OUT OF SCOPE. There is no flag that drops a required context:
  a gate that disappears quietly is the failure this exists to prevent, and
  a stale name and a temporarily-broken check look identical from here.'
CLI_FLAGS='--check --apply'
CLI_POSITIONAL=any
CLI_EXITS='  (the ladder is hf7y/etalon bin/lib/exit-codes.sh, cited: no copy lives here)
  0  every repo in scope requires exactly the checks it runs
  1  findings: a wedge, an unprotected repo with CI, or a check it runs and
     does not require -- read the rows
  6  BLIND: the registry would not enumerate, or a repo/workflow/API would not
     answer. NEVER 0 -- a run that could not look has established nothing
  7  REFUSED: --apply would have to REMOVE a required context (a wedge). Out
     of scope on principle; a human decides what stops gating'
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "$HERE/lib/cli-guard.sh"
cli_guard "$@"
. "$HERE/lib/estate-set.sh"

OWNER="$GH_ESTATE_OWNER"
GH_BIN="${GH_BIN:-gh}"
# AFTER GH_BIN: the lib captures REGISTRY_GH from it at source time.
. "$HERE/lib/registry-set.sh"
REGISTRY_MARKER="${REGISTRY_MARKER:-.agent-project}"
WITNESS_PRS="${BPP_WITNESS_PRS:-5}"

MODE=--check
want=()
for a in "$@"; do
  case "$a" in
    --check|--apply) MODE="$a" ;;
    *) want+=("$a") ;;
  esac
done

command -v "$GH_BIN" >/dev/null || { echo "$CLI_NAME: BLIND -- $GH_BIN is not on PATH" >&2; exit 6; }

BLIND=0; FINDINGS=0; REFUSED=0
blind() { printf '  BLIND   %s\n' "$*"; BLIND=$((BLIND+1)); }
say()   { printf '  %-7s %s\n' "$1" "$2"; }

api_get() { "$GH_BIN" api "$1" 2>/dev/null; }

registry() { registry_repos; }   # lib/registry-set.sh -- the marker query has one home

wf_parse() {   # triggers, PR branch filter and jobs of one workflow; a file it cannot parse yields no jobs, which the caller reports BLIND
  awk '
    function flushjob(){ if(job!="") printf "JOB\t%s\t%s\t%s\n", job, (jname==""?job:jname), juses;
                         job=""; jname=""; juses="-" }
    { sub(/\r$/,"") }
    /^[A-Za-z_][A-Za-z0-9_.-]*:/ {
      flushjob(); inbr=0; trig="";
      if ($0 ~ /^on:/) { sec="on"; rest=$0; sub(/^on:[ \t]*/,"",rest);
        gsub(/[^A-Za-z0-9_]/," ",rest); n=split(rest,a," ");
        for(i=1;i<=n;i++) if(a[i]!="") print "TRIG\t" a[i];
      } else if ($0 ~ /^jobs:/) { sec="jobs" } else { sec="other" }
      next
    }
    sec=="on" && /^  [A-Za-z_]+:/ { trig=$0; sub(/^  /,"",trig); sub(/:.*$/,"",trig);
                                    print "TRIG\t" trig; inbr=0; next }
    sec=="on" && (trig=="pull_request" || trig=="pull_request_target") {
      if ($0 ~ /^    branches:/) { rest=$0; sub(/^    branches:[ \t]*/,"",rest);
        gsub(/[^A-Za-z0-9_.\/*-]/," ",rest); n=split(rest,a," ");
        for(i=1;i<=n;i++) if(a[i]!="") print "PRBRANCH\t" a[i];
        inbr=(n==0); next }
      if (inbr && $0 ~ /^ *- /) { v=$0; sub(/^ *- */,"",v); gsub(/[^A-Za-z0-9_.\/*-]/,"",v);
                                  if(v!="") print "PRBRANCH\t" v; next }
      if ($0 ~ /^    [A-Za-z_]+:/) inbr=0
      next
    }
    sec=="jobs" && /^  [A-Za-z0-9_-]+:[ \t]*$/ { flushjob(); job=$0; sub(/^  /,"",job);
                                                 sub(/:[ \t]*$/,"",job); next }
    sec=="jobs" && job!="" && /^    name:/ { jname=$0; sub(/^    name:[ \t]*/,"",jname);
                                            gsub(/"/,"",jname); sub(/[ \t]+$/,"",jname); next }
    sec=="jobs" && job!="" && /^    uses:/ { juses=$0; sub(/^    uses:[ \t]*/,"",juses);
                                            sub(/[ \t]*#.*/,"",juses); sub(/[ \t]+$/,"",juses); next }
    END{ flushjob() }
  '
}

wf_text() {   # <slug> <path> [ref] -- one workflow file, or nothing (rc 1)
  local ref="${3:-}" out
  out="$(api_get "repos/$1/contents/$2${ref:+?ref=$ref}")" || return 1
  printf '%s' "$out" | jq -r '.content // empty' 2>/dev/null | base64 -d 2>/dev/null
}

CJ=''
declare -A CALLEE_JOBS=()   # uses-string -> newline-separated callee job display names
declare -A DEPENDS=()       # owner-repo named by a uses:, so etalon is derived, never typed

callee_jobs() {   # <uses> <slug> -> CJ, the callee jobs that are the second half of a `caller / callee` context. TRAP: never call this in a command substitution -- the subshell would discard the cache AND the graded-by repo, which is how the first draft scanned etalon zero times
  local uses="$1" slug="$2" cslug cpath cref
  CJ=""
  if [ -n "${CALLEE_JOBS[$uses]+set}" ]; then CJ="${CALLEE_JOBS[$uses]}"; return 0; fi
  case "$uses" in
    ./*)          cslug="$slug"; cpath="${uses#./}"; cref="" ;;
    */*/.github/workflows/*)
                  cslug="${uses%%/.github/*}"; cpath=".github/workflows/${uses##*/.github/workflows/}"
                  cref="${cpath##*@}"; cpath="${cpath%@*}"
                  [ "$cref" = "$cpath" ] && cref="" ;;
    *)            return 1 ;;
  esac
  [ "${cslug%%/*}" = "$OWNER" ] && [ "$cslug" != "$slug" ] && DEPENDS["$cslug"]=1
  CJ="$(wf_text "$cslug" "$cpath" "$cref" | wf_parse | awk -F'\t' '$1=="JOB"{print $3}')"
  [ -n "$CJ" ] || return 1
  CALLEE_JOBS["$uses"]="$CJ"
}

witnessed() {   # names that reached a REAL CONCLUSION on a pull_request-event run. TRAP: `skipped` and absent are not evidence (`carry` is if:push, groc-mangr `enable` is types:-filtered, etalon `runtime` is off by default), and the run-id filter is the other half -- a merged PR head is also a main sha carrying main's push jobs
  local slug="$1" runs sha pat
  runs="$(api_get "repos/$slug/actions/runs?event=pull_request&per_page=50")" || return 0
  sha="$(printf '%s' "$runs" | jq -r '.workflow_runs[0].head_sha // empty' 2>/dev/null)"
  [ -n "$sha" ] || return 0
  pat="$(printf '%s' "$runs" | jq -r --arg s "$sha" \
         '[.workflow_runs[]|select(.head_sha==$s)|.id|tostring]|join("|")' 2>/dev/null)"
  [ -n "$pat" ] || return 0
  api_get "repos/$slug/commits/$sha/check-runs?per_page=100" \
    | jq -r --arg p "$pat" '.check_runs[]?
         | select(.conclusion != null and .conclusion != "skipped")
         | select(.details_url // "" | test("/runs/(" + $p + ")/"))
         | .name' 2>/dev/null | sort -u
  return 0
}

required() {   # <slug> <branch> -- required contexts, or nothing. TRAP: an unprotected branch 404s and gh prints the 404 BODY to stdout, so a naive [ -n ] read 18 of 18 as protected when 16 had none. Gate on the EXIT STATUS, never the body
  local out
  out="$(api_get "repos/$1/branches/$2/protection")" || return 1
  printf '%s' "$out" | jq -r '.required_status_checks.contexts[]?' 2>/dev/null
  return 0
}

in_set() { local n="$1"; shift; local e; for e in "$@"; do [ "$e" = "$n" ] && return 0; done; return 1; }

scan() {
  local name="$1"; local slug="$OWNER/$name"
  local branch tree paths p text parsed
  local -a produced=() req=() wedge=() missing=() candidate=()
  local prot=no wit trig prbr uses disp

  branch="$(api_get "repos/$slug" | jq -r '.default_branch // empty' 2>/dev/null)"
  [ -n "$branch" ] || { blind "$name: the repo would not answer -- not read, not clean"; return; }

  tree="$(api_get "repos/$slug/git/trees/$branch?recursive=1")" \
    || { blind "$name: the tree at $branch would not answer"; return; }
  [ "$(printf '%s' "$tree" | jq -r '.truncated' 2>/dev/null)" = true ] \
    && { blind "$name: the tree came back truncated -- workflows may be missing from it"; return; }
  paths="$(printf '%s' "$tree" | jq -r '.tree[]?|select(.path|test("^\\.github/workflows/.*\\.ya?ml$"))|.path' 2>/dev/null)"

  for p in $paths; do
    text="$(wf_text "$slug" "$p" "$branch")" \
      || { blind "$name: $p would not answer"; return; }
    parsed="$(printf '%s' "$text" | wf_parse)"
    trig="$(printf '%s' "$parsed" | awk -F'\t' '$1=="TRIG"{print $2}')"
    printf '%s\n' "$trig" | grep -qxE 'pull_request|pull_request_target' || continue
    prbr="$(printf '%s' "$parsed" | awk -F'\t' '$1=="PRBRANCH"{print $2}')"   # a filter naming other branches means this never reports on a PR into $branch -- senechal's runtime.yml is keyed to bashified
    if [ -n "$prbr" ] && ! printf '%s\n' "$prbr" | grep -qxF "$branch"; then
      say filter "$p is keyed to pull_request branch(es) [$(printf '%s' "$prbr" | paste -sd, -)]; '$branch' is not among them literally, so its jobs are NOT counted as produced"
      continue
    fi
    while IFS=$'\t' read -r _ _ disp uses; do
      [ -n "$disp" ] || continue
      if [ "$uses" = "-" ]; then
        produced+=("$disp")
      else
        callee_jobs "$uses" "$slug" \
          || { blind "$name: $p job '$disp' calls '$uses', which would not resolve -- its contexts are unknown"; return; }
        while read -r j; do [ -n "$j" ] && produced+=("$disp / $j"); done <<<"$CJ"
      fi
    done < <(printf '%s' "$parsed" | awk -F'\t' '$1=="JOB"')
  done

  mapfile -t produced < <(printf '%s\n' ${produced[@]+"${produced[@]}"} | awk 'NF && !seen[$0]++')
  mapfile -t req < <(required "$slug" "$branch")
  [ "${#req[@]}" -gt 0 ] && prot=yes
  wit="$(witnessed "$slug")"

  for r in ${req[@]+"${req[@]}"}; do
    in_set "$r" ${produced[@]+"${produced[@]}"} || wedge+=("$r")
  done
  for p in ${produced[@]+"${produced[@]}"}; do
    in_set "$p" ${req[@]+"${req[@]}"} && continue
    if printf '%s\n' "$wit" | grep -qxF "$p"; then missing+=("$p"); else candidate+=("$p"); fi
  done

  printf '\n%s (%s)\n' "$name" "$branch"
  if [ "$prot" = yes ]; then say requires "$(IFS=,; echo "${req[*]}")"
  else say requires "(unprotected -- nothing gates a merge here)"; fi
  if [ "${#produced[@]}" -gt 0 ]; then
    say runs "$(printf '%s\n' "${produced[@]}" | sort -u | paste -sd, -)"
  else
    say runs "(no workflow runs on a pull request into $branch)"
  fi

  if [ "${#wedge[@]}" -gt 0 ]; then
    say WEDGE "required, and NO workflow produces it: $(IFS=,; echo "${wedge[*]}")"
    printf '          every PR here is unmergeable until a workflow produces that name,\n'
    printf '          or a human removes it. This script will not remove it.\n'
    FINDINGS=$((FINDINGS+1))
    if [ "$MODE" = --apply ]; then
      say REFUSED "--apply will not rewrite protection carrying a wedge (removal is out of scope)"
      REFUSED=$((REFUSED+1))
      return
    fi
  fi
  if [ "${#candidate[@]}" -gt 0 ]; then
    say candid. "declared, never reached a conclusion on a PR run, NOT proposed: $(IFS=,; echo "${candidate[*]}")"
    printf '          a matrix job reports per leg; an always-skipped or filtered job gates nothing.\n'
  fi

  if [ "${#missing[@]}" -eq 0 ]; then
    if [ "$prot" = no ] && [ "${#produced[@]}" -eq 0 ]; then
      say NOCI "no PR check exists to require. Protecting it would gate on nothing, or wedge it. This is #317's worklist, not a defect of this repo."
      FINDINGS=$((FINDINGS+1))
    elif [ "$prot" = no ]; then
      say UNPROT "runs checks and requires none -- 'gh pr merge --auto' has nothing to queue behind (#288)"
      FINDINGS=$((FINDINGS+1))
    elif [ "${#wedge[@]}" -eq 0 ]; then
      say ok "requires exactly what it runs"
    fi
    [ "$prot" = no ] || return
  else
    say MISSING "runs and does not require: $(IFS=,; echo "${missing[*]}")"
    [ "$MODE" = --apply ] || FINDINGS=$((FINDINGS+1))   # under --apply only apply() counts it, so a run that closes its own delta exits 0
  fi

  local -a add=(${req[@]+"${req[@]}"} ${missing[@]+"${missing[@]}"})
  [ "${#add[@]}" -gt 0 ] || return
  say remedy "require [$(IFS=,; echo "${add[*]}")] on $slug@$branch"
  if [ "$MODE" != --apply ]; then
    say refused "no write: --apply was not given (this mode reports and changes nothing)"
    return
  fi
  apply "$slug" "$branch" "${add[@]}"
}

apply() {   # ADD ONLY, read-modify-write: enforce_admins is a separate decision (#168 scoped it to realisateur and scheduler) and this script never makes it
  # PUT REPLACES THE WHOLE PROTECTION OBJECT, so every field this payload does
  # not carry forward is DELETED. `required_pull_request_reviews` and
  # `restrictions` were literal `null` here, which is why adding a required
  # context would silently drop a review requirement -- including the Code
  # Owner review on `.github/workflows/**` that is the whole guard on the App's
  # `workflows: write` grant (#922). A guard this script can erase is not one.
  # Both are now carried forward, and both are RESHAPED: the GET returns
  # `restrictions.users[].login` and `dismissal_restrictions` as objects, the
  # PUT wants bare logins and slugs, so echoing the GET back is a 422.
  local slug="$1" branch="$2"; shift 2
  local cur payload now
  cur="$(api_get "repos/$slug/branches/$branch/protection")" || cur='{}'
  payload="$(printf '%s\n' "$@" | jq -R . | jq -sc --argjson cur "$cur" '
    { required_status_checks: { strict: ($cur.required_status_checks.strict // false), contexts: (.|unique) },
      enforce_admins: ($cur.enforce_admins.enabled // false),
      required_pull_request_reviews:
        (if ($cur.required_pull_request_reviews // null) == null then null
         else ($cur.required_pull_request_reviews
               | { dismiss_stale_reviews:           (.dismiss_stale_reviews // false),
                   require_code_owner_reviews:      (.require_code_owner_reviews // false),
                   required_approving_review_count: (.required_approving_review_count // 0),
                   require_last_push_approval:      (.require_last_push_approval // false) })
         end),
      restrictions:
        (if ($cur.restrictions // null) == null then null
         else ($cur.restrictions
               | { users: [ .users[]?.login // empty ],
                   teams: [ .teams[]?.slug  // empty ],
                   apps:  [ .apps[]?.slug   // empty ] })
         end),
      allow_force_pushes: ($cur.allow_force_pushes.enabled // false),
      allow_deletions: ($cur.allow_deletions.enabled // false) }')"
  if ! printf '%s' "$payload" | "$GH_BIN" api -X PUT "repos/$slug/branches/$branch/protection" --input - >/dev/null 2>&1; then
    say FAILED "could not write protection on $slug (needs admin)"
    FINDINGS=$((FINDINGS+1)); return
  fi
  mapfile -t now < <(required "$slug" "$branch")   # verify by RE-READING, never by the write's exit status
  for c in "$@"; do
    in_set "$c" ${now[@]+"${now[@]}"} && continue
    blind "$slug: wrote protection and the re-read does not carry '$c' -- treat as unprotected"
    return
  done
  say applied "now requires [$(IFS=,; echo "${now[*]}")]"
}

echo "branch-protection-provision ($MODE) -- $OWNER, $(date '+%Y-%m-%d %H:%M')"
[ "$MODE" = --apply ] || echo "(read-only: reports the delta, writes nothing -- pass --apply to ADD what a repo runs)"

reg="$(registry)" || reg=""
if [ -z "$reg" ]; then
  echo "BLIND: the $REGISTRY_MARKER registry would not enumerate. Recording NO rows" >&2
  echo "rather than an empty one -- absence here means 'could not look', never 'there are none'." >&2
  exit 6
fi

names=()
for p in $reg; do
  if [ "${#want[@]}" -gt 0 ]; then in_set "$p" "${want[@]}" || continue; fi
  names+=("$p")
done
cli_require_matched want names

echo "registry: $(printf '%s\n' "$reg" | grep -c .) repo(s) carry $REGISTRY_MARKER"
for n in "${names[@]}"; do scan "$n"; done

dep=()   # hf7y/etalon carries no .agent-project and holds the guard 16 repos are graded by, so scan-set membership is DERIVED from the `uses:` above rather than typed
for d in "${!DEPENDS[@]}"; do
  n="${d#*/}"
  printf '%s\n' "$reg" | grep -qxF "$n" && continue
  if [ "${#want[@]}" -gt 0 ]; then in_set "$n" "${want[@]}" || continue; fi
  dep+=("$n")
done
if [ "${#dep[@]}" -gt 0 ]; then
  printf '\n-- graded-by: not in the registry, but every caller above is graded by it --\n'
  for n in "${dep[@]}"; do scan "$n"; done
fi

printf '\n== %d finding(s), %d refused, %d BLIND, out of %d repo(s) ==\n' \
  "$FINDINGS" "$REFUSED" "$BLIND" "$(( ${#names[@]} + ${#dep[@]} ))"
[ "$BLIND" -gt 0 ] && { echo "$CLI_NAME: $BLIND repo(s) unread -- the counts above are NOT trustworthy."; exit 6; }
[ "$REFUSED" -gt 0 ] && exit 7
[ "$FINDINGS" -gt 0 ] && exit 1
exit 0
