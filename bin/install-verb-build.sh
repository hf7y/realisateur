#!/usr/bin/env bash
# install-verb-build.sh -- install a pinned verb build from the meta-repo,
# so every user path runs the SAME verbs and none of them move while agents
# merge the next ones.
#
# THE LAYOUT
#   ~/.local/share/verb-builds/
#     repo/                      one clone of hf7y/verbs (the meta-repo)
#     2026-08-05T0130Z/          a build, extracted from tag build/<id>
#       manifest.tsv             <project> <verb> <sha> <repo_url>
#       vim-arcade/bin/entraine
#     2026-08-04T0130Z/          yesterday's, kept for rollback
#     current -> 2026-08-05T0130Z
#
#   ~/.local/bin/entraine -> ~/.local/share/verb-builds/current/vim-arcade/bin/entraine
#
# WHY `current` IS A SYMLINK AND THE ~/.local/bin LINKS ARE WRITTEN ONCE
# Adopting a build, or rolling back, repoints ONE symlink -- so the verb
# set changes all at once or not at all. N independent `git pull`s cannot
# express that: they half-succeed, and leave you running a verb set that
# never existed as a whole and cannot be named in a bug report.
#
# WHAT THIS REPLACES
# A verb today is a symlink into a `bashified` WORKTREE of a full dev clone
# (senechal bin/installe:194-213). Hence: deleting ~/Documents/Projects/
# vim-arcade breaks `entraine`, because vim-arcade-verbs/.git is a POINTER
# into vim-arcade/.git/worktrees/. Measured on mandark 2026-08-04: 807M of
# dev clones serving 26 verbs whose bashified branches total ~2.3M. A build
# depends on no dev checkout at all -- which is the whole point, because
# development now happens on monkey.
#
# WHAT IT REFUSES TO DO
# Switch to a build it has not fully verified. Every verb the manifest
# promises is confirmed present and executable BEFORE `current` moves; a
# partial build is discarded, not switched to. scheduler's 2026-07-29 total
# dispatch outage was ONE missing symlink that no check on the machine
# could say should have been there.
#
# And it never reports "you are up to date" when it could not look. An
# unreachable remote is BLIND, exit 3 -- the `garde` shape from
# realisateur/MONKEY.md §5, where skipping unreachable destinations made
# "nothing pending" indistinguishable from "everything is proven".
set -uo pipefail

CLI_NAME='install-verb-build.sh'
CLI_SUMMARY='install a pinned verb build from the meta-repo and switch to it atomically'
CLI_USAGE='  install-verb-build.sh --check              is a newer build available?
  install-verb-build.sh --latest --apply    install the newest build and switch
  install-verb-build.sh --build <id> --apply  install one build by id
  install-verb-build.sh --list              builds on this host
  install-verb-build.sh --rollback <id>     switch back to a build already here'
CLI_FLAGS='--check --latest --build --apply --link --list --rollback --build-root --remote'
CLI_POSITIONAL=any   # flag VALUES (--build <id>) read as positionals to cli-guard;
                     # the arg loop below rejects anything genuinely unknown.
CLI_EXITS='  0  done, or --check found you current
  1  refused: incomplete, unverifiable, or --check found a newer build
  2  usage error
  3  BLIND: could not reach the meta-repo. This is not "up to date".'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

BUILD_ROOT="${VERB_BUILD_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/verb-builds}"
REMOTE="${VERB_BUILD_REMOTE:-https://github.com/hf7y/verbs.git}"
BIN="${INSTALLE_BIN:-$HOME/.local/bin}"
REPO="$BUILD_ROOT/repo"
BUILD_ID=''; APPLY=0; LINK=0; LIST=0; CHECK=0; LATEST=0; ROLLBACK=''

while [ $# -gt 0 ]; do
  case "$1" in
    --build)      BUILD_ID="${2:?--build needs an id}"; shift ;;
    --rollback)   ROLLBACK="${2:?--rollback needs an id}"; shift ;;
    --build-root) BUILD_ROOT="${2:?--build-root needs a value}"; REPO="$BUILD_ROOT/repo"; shift ;;
    --remote)     REMOTE="${2:?--remote needs a value}"; shift ;;
    --latest)     LATEST=1 ;;
    --check)      CHECK=1 ;;
    --apply)      APPLY=1 ;;
    --link)       LINK=1 ;;
    --list)       LIST=1 ;;
    *) printf '%s: unknown argument: %s\n' "$CLI_NAME" "$1" >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '%s\n' "$*" >&2; }
die()  { printf '%s: %s\n' "$CLI_NAME" "$*" >&2; exit 1; }
blind(){ printf '%s: BLIND -- %s. This is not "up to date".\n' "$CLI_NAME" "$*" >&2; exit 3; }
row()  { printf '  %-8s %-18s %s\n' "$1" "$2" "${3:-}" >&2; }

current_id() { readlink "$BUILD_ROOT/current" 2>/dev/null || true; }

# --- purely local modes -------------------------------------------------
if [ "$LIST" -eq 1 ]; then
  [ -d "$BUILD_ROOT" ] || die "no builds on this host ($BUILD_ROOT does not exist)"
  cur="$(current_id)"
  found=0
  for d in "$BUILD_ROOT"/*/; do
    d="${d%/}"; id="$(basename "$d")"
    [ "$id" = repo ] && continue
    [ -f "$d/manifest.tsv" ] || continue
    found=1
    n="$(grep -cv '^#' "$d/manifest.tsv" 2>/dev/null || echo 0)"
    mark='  '; [ "$id" = "$cur" ] && mark='->'
    printf '%s %-24s %s verb(s)\n' "$mark" "$id" "$n"
  done
  [ "$found" -eq 1 ] || say "no builds installed yet"
  exit 0
fi

# Rollback deliberately does NOT touch the network. The build is already
# here and was verified when it was installed; making recovery depend on
# the remote would make it fail in exactly the situation you need it.
if [ -n "$ROLLBACK" ]; then
  [ -f "$BUILD_ROOT/$ROLLBACK/manifest.tsv" ] || die "no installed build '$ROLLBACK' on this host (see --list)"
  ln -sfn "$ROLLBACK" "$BUILD_ROOT/current.tmp" || die "cannot write $BUILD_ROOT/current.tmp"
  mv -Tf "$BUILD_ROOT/current.tmp" "$BUILD_ROOT/current" || die 'cannot move current into place'
  say "current -> $ROLLBACK"
  exit 0
fi

# --- fetch the meta-repo ------------------------------------------------
# BOUNDED, because this runs unattended. Against an UNROUTABLE host the
# kernel's TCP retry took 2m15s to give up -- measured 2026-08-07 against
# 192.0.2.1 (TEST-NET-1) -- so the BLIND verdict was correct and arrived far
# too late to be one. A human at a terminal hits Ctrl-C; cron does not, and
# realisateur#54 filed exactly that: "a monitor row that hangs contributes a
# stuck process every 6 hours and reports nothing, which is a worse failure
# than the one it was added to catch."
#
# Two bounds, because there are two ways to stall:
#   VERB_BUILD_NET_TIMEOUT  wall-clock ceiling on the whole reach, the shape
#                           scheduler/bin/usage-paced-runner.sh already uses
#                           (`timeout 20 git ... fetch`).
#   GIT_TERMINAL_PROMPT=0   a credential prompt no runner will ever answer is
#                           the second, quieter way to wait forever.
# `timeout` exits 124 on expiry, which falls into the same `||` as any other
# failure -- so a slow network and a dead one produce the same BLIND, which
# is right: neither one looked.
NET_TIMEOUT="${VERB_BUILD_NET_TIMEOUT:-45}"
export GIT_TERMINAL_PROMPT=0
mkdir -p "$BUILD_ROOT" || die "cannot create $BUILD_ROOT"
if [ -d "$REPO/.git" ]; then
  timeout "$NET_TIMEOUT" git -C "$REPO" fetch -q --tags --prune origin 2>/dev/null \
    || blind "cannot fetch $REMOTE within ${NET_TIMEOUT}s"
else
  rm -rf "$REPO"
  timeout "$NET_TIMEOUT" git clone -q --bare "$REMOTE" "$REPO/.git" 2>/dev/null \
    || blind "cannot clone $REMOTE within ${NET_TIMEOUT}s"
  git -C "$REPO" config core.bare false 2>/dev/null || true
  timeout "$NET_TIMEOUT" git -C "$REPO" fetch -q --tags origin 2>/dev/null || true
fi

# Newest by tag name. Build ids are UTC timestamps, so lexical sort is
# chronological -- which is why cut-verb-build.sh stamps them that way
# rather than as a bare date that two builds in one day would collide on.
latest_tag="$(git -C "$REPO" tag --list 'build/*' --sort=-refname 2>/dev/null | head -1)"
[ -n "$latest_tag" ] || blind "the meta-repo has no build/* tags -- nothing has been built yet, or the fetch was partial"
latest_id="${latest_tag#build/}"

if [ "$CHECK" -eq 1 ]; then
  cur="$(current_id)"
  if [ "$cur" = "$latest_id" ]; then
    printf 'verbs: up to date (build %s)\n' "$cur"
    exit 0
  fi
  n="$(git -C "$REPO" show "$latest_tag:manifest.tsv" 2>/dev/null | grep -cv '^#' || echo '?')"
  printf 'verbs: a newer build is available\n  yours:  %s\n  latest: %s (%s verbs)\n' \
         "${cur:-<none installed>}" "$latest_id" "$n"
  printf '  adopt it with: install-verb-build.sh --latest --apply\n'
  exit 1
fi

[ "$LATEST" -eq 1 ] && BUILD_ID="$latest_id"
[ -n "$BUILD_ID" ] || { printf '%s: need --check, --latest, --build <id>, --list or --rollback <id>\n' "$CLI_NAME" >&2; exit 2; }

tag="build/$BUILD_ID"
git -C "$REPO" rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1 \
  || die "no such build in the meta-repo: $BUILD_ID (newest is $latest_id)"

# --- extract ------------------------------------------------------------
# `git archive` rather than a checkout: the result is a plain tree with no
# .git, so a build cannot be edited in place and then keep claiming to be
# that build.
DEST="$BUILD_ROOT/$BUILD_ID"
if [ ! -f "$DEST/manifest.tsv" ]; then
  rm -rf "$DEST"; mkdir -p "$DEST" || die "cannot create $DEST"
  git -C "$REPO" archive "$tag" | tar -x -C "$DEST" \
    || { rm -rf "$DEST"; die "could not extract $tag"; }
fi
[ -f "$DEST/manifest.tsv" ] || { rm -rf "$DEST"; die "$tag carries no manifest.tsv -- refusing"; }

# --- verify every verb the manifest promised ----------------------------
# Against the manifest, not against what happened to land. A build is a
# promise about a SET; verifying only what is present cannot notice a verb
# that is absent, which is `deploy-drift-check.sh`'s intersection bug
# (DEXTER-MIGRATION-NOTES: check the DECLARED set, never the intersection,
# or absence reports clean).
say "== build $BUILD_ID =="
missing=0
while IFS=$'\t' read -r project verb sha _; do
  [ -n "${verb:-}" ] || continue
  f="$DEST/$project/bin/$verb"
  if   [ ! -f "$f" ]; then row MISSING "$verb" "$project has no bin/$verb"; missing=$((missing+1))
  elif [ ! -x "$f" ]; then row BAD     "$verb" "not executable"; missing=$((missing+1))
  fi
done < <(grep -v '^#' "$DEST/manifest.tsv")

total="$(grep -cv '^#' "$DEST/manifest.tsv")"
[ "$total" -gt 0 ] || { rm -rf "$DEST"; die 'manifest has no rows -- refusing to install an empty verb set'; }
if [ "$missing" -gt 0 ]; then
  rm -rf "$DEST"
  die "build $BUILD_ID is INCOMPLETE ($missing bad/missing verb(s)). Discarded, and current is unchanged."
fi
say "verified: $total verb(s), all present and executable"

if [ "$APPLY" -eq 0 ]; then
  say "check only, nothing switched. Re-run with --apply to make this build current."
  exit 0
fi

# --- switch, atomically -------------------------------------------------
# ln -sfn then mv -T: a plain `ln -sfn` over an existing symlink-TO-A-
# DIRECTORY creates the new link INSIDE the old target instead of replacing
# it, leaving current pointing at the old build while this script reports
# success.
ln -sfn "$BUILD_ID" "$BUILD_ROOT/current.tmp" || die "cannot write $BUILD_ROOT/current.tmp"
mv -Tf "$BUILD_ROOT/current.tmp" "$BUILD_ROOT/current" || die 'cannot move current into place'
say "current -> $BUILD_ID"

# --- the ~/.local/bin links, written once -------------------------------
# Off by default: `installe` (senechal) owns ~/.local/bin and its manifest,
# and this script does not get to quietly take that over. --link is for a
# host with no installe yet, or for the migration sitting where the two are
# reconciled deliberately. Anything present that is not ours is reported
# and left alone, never clobbered.
if [ "$LINK" -eq 1 ]; then
  mkdir -p "$BIN"
  linked=0; skipped=0
  while IFS=$'\t' read -r project verb _ _; do
    [ -n "${verb:-}" ] || continue
    want="$BUILD_ROOT/current/$project/bin/$verb"
    have="$BIN/$verb"
    if [ -e "$have" ] || [ -L "$have" ]; then
      tgt="$(readlink "$have" 2>/dev/null || true)"
      case "$tgt" in
        "$BUILD_ROOT/current/"*) continue ;;   # already ours; `current` moved for us
        *) row SKIP "$verb" "not ours -> ${tgt:-<real file>}"; skipped=$((skipped+1)); continue ;;
      esac
    fi
    ln -sfn "$want" "$have" && linked=$((linked + 1))
  done < <(grep -v '^#' "$DEST/manifest.tsv")
  say "linked $linked verb(s) into $BIN; $skipped left alone"
  [ "$skipped" -eq 0 ] || say 'the skipped ones are installe-owned -- reconcile deliberately, not by clobbering.'

  # --- drop links for verbs this build no longer promises ---------------
  # The loop above only ever ADDS: it walks the NEW manifest, so a verb a
  # nightly build dropped keeps its old link, now pointing at
  # `current/<project>/bin/<verb>` -- which after the switch above does not
  # exist. PATH search skips a dangling link, so that failure is silent by
  # construction (realisateur#223). Only ever remove a link that resolves
  # into THIS build root; anything else -- installe-owned, or unrelated --
  # is left exactly as it was, same direction guard as the SKIP case above.
  wanted="$(grep -v '^#' "$DEST/manifest.tsv" | cut -f2)"
  dropped=0
  for have in "$BIN"/*; do
    [ -L "$have" ] || continue
    tgt="$(readlink "$have" 2>/dev/null || true)"
    case "$tgt" in
      "$BUILD_ROOT/current/"*) : ;;
      *) continue ;;
    esac
    verb="$(basename "$have")"
    printf '%s\n' "$wanted" | grep -Fxq "$verb" && continue
    rm -f "$have" && { row DROP "$verb" "no longer in build $BUILD_ID's manifest"; dropped=$((dropped+1)); }
  done
  say "dropped $dropped verb(s) no longer in this build"

  # --- the one honest count: manifest rows vs links pointing in here -----
  # "N verbs in the manifest, N links on the host" is the comparison an
  # operator actually reaches for. Report it loudly rather than let a link
  # this loop should have made or removed drift the two apart silently.
  ours=0
  for have in "$BIN"/*; do
    [ -L "$have" ] || continue
    tgt="$(readlink "$have" 2>/dev/null || true)"
    case "$tgt" in "$BUILD_ROOT/current/"*) ours=$((ours + 1)) ;; esac
  done
  if [ "$ours" -ne "$total" ]; then
    say "COUNT MISMATCH: manifest promises $total verb(s), but $ours link(s) in $BIN point into this build root"
  fi
fi
exit 0
