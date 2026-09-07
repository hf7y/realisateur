#!/usr/bin/env bash
# push-verb-build.sh -- mandark side of hf7y/realisateur#892: mandark cuts or
# fetches a dated verb build and PUSHES it onto a host, then swaps that
# host's `current` atomically. The host runs nothing of ours to make that
# happen -- no installer, no root checkout, no per-account clock. It just has
# a directory tree that gets atomically repointed.
#
# This is the reverse of install-verb-build.sh (host pulls, host switches
# itself). That script is not touched here and stays exactly what a
# consumer-side account still uses today; this one is the new producer side.
#
# TRAP: "the host runs nothing of ours" means no FILE of ours lands on the
#   host, transiently or otherwise -- not merely "no crontab". dresse.sh's
#   own remote_step() tars bin/lib + a named script to a remote mktemp dir
#   and runs it there; that shape is exactly the provisioning-script
#   residency #892 exists to retire, so the swap below does not reuse it.
#   The swap ships as a POSIX command string over ssh's stdin, built from
#   coreutils (ln, mv, readlink, test) only -- nothing with a filename in
#   this repo ever touches the host's disk.
#
# TRAP: the swap primitive is defined ONCE, as atomic_swap_local(). The
#   remote path ships that exact function body over ssh via `declare -f` and
#   runs it there -- so the code this file's own atomicity witness (see
#   bin/tests/push-verb-build.test.sh) exercises locally is byte-identical
#   to what executes on a real host, not a parallel reimplementation that
#   could drift from what was tested.
#
# TRAP: staging happens under the build's OWN id
#   ($REMOTE_ROOT/$BUILD_ID/...), never under `current` or `current.tmp`.
#   Nothing resolves that path until the swap runs, so a transfer that dies
#   partway leaves an inert, unreferenced directory -- not a half-installed
#   live one. The swap itself is `ln -sfn` to a tmp name then `mv -Tf` over
#   `current`, the same idiom install-verb-build.sh already uses: a plain
#   `ln -sfn` over an existing symlink-to-a-directory would create the new
#   link INSIDE the old target instead of replacing it.
#
# TRAP: build-or-fetch is DELEGATED, not reimplemented. --cut calls
#   cut-verb-build.sh --assemble; --fetch calls install-verb-build.sh
#   --latest with no --apply (which fetches the newest APPROVED build,
#   verifies every verb it promises, and leaves it at $BUILD_ROOT/<id>
#   WITHOUT switching anything -- see that script's own APPLY==0 path). A
#   second implementation of "is this build complete" is a second place for
#   that check to go stale.
set -uo pipefail

CLI_NAME='push-verb-build.sh'
CLI_SUMMARY='mandark side: push a cut-or-fetched build tree onto a host and atomically swap its `current` -- the host runs nothing of ours to do it'
CLI_USAGE='  push-verb-build.sh --cut     --host H [--apply]   cut a fresh build here, push it, swap
  push-verb-build.sh --fetch   --host H [--apply]   fetch+verify the latest approved build here, push it, swap
  push-verb-build.sh --build ID --host H [--apply]  push an already-materialized local build by id
  push-verb-build.sh --latest  --host H [--apply]   push the newest already-materialized local build
  push-verb-build.sh --rollback ID --host H [--apply]
                                                     no transfer: H already holds ID -- swap to it directly
  push-verb-build.sh --list --build-root DIR        local builds available to push (no host needed)

--check (default) previews with no writes anywhere, local or remote.
--build-root, --remote-root, --ssh, --rsync and --ssh-timeout are all
overridable so bin/tests/push-verb-build.test.sh can run with no real ssh,
no real host and no network -- same posture as install-verb-build.sh and
selfdev-credentials.sh.'
CLI_FLAGS='--cut --fetch --build --latest --rollback --list --host --build-root --remote-root --ssh --rsync --ssh-timeout --check --apply'
CLI_POSITIONAL=any   # flag VALUES read as positionals to cli-guard; the loop below rejects anything genuinely unknown.
CLI_EXITS='  0  pushed and the swap verified on re-read (or, under --check, could be)
  1  refused: an incomplete local build, a push/swap step failed, or the swap did not verify on re-read
  2  usage error
  6  BLIND: could not reach the host, or (for --fetch) could not reach the release channel. Not "nothing to do".'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUILD_ROOT="${PUSH_BUILD_ROOT:-${VERB_BUILD_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/verb-builds}}"
REMOTE_ROOT="${PUSH_REMOTE_ROOT:-/usr/local/share/verb-builds}"
SSH_BIN="${PUSH_SSH_BIN:-ssh}"
RSYNC_BIN="${PUSH_RSYNC_BIN:-rsync}"
SSH_TIMEOUT="${PUSH_SSH_TIMEOUT:-20}"

MODE="--check"
DO_CUT=0; DO_FETCH=0; DO_LIST=0
BUILD_ID=""; WANT_LATEST=0; ROLLBACK_ID=""
HOST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --cut)          DO_CUT=1 ;;
    --fetch)        DO_FETCH=1 ;;
    --build)        BUILD_ID="${2:?--build needs an id}"; shift ;;
    --latest)       WANT_LATEST=1 ;;
    --rollback)     ROLLBACK_ID="${2:?--rollback needs an id}"; shift ;;
    --list)         DO_LIST=1 ;;
    --host)         HOST="${2:?--host needs a target}"; shift ;;
    --build-root)   BUILD_ROOT="${2:?--build-root needs a value}"; shift ;;
    --remote-root)  REMOTE_ROOT="${2:?--remote-root needs a value}"; shift ;;
    --ssh)          SSH_BIN="${2:?--ssh needs a binary}"; shift ;;
    --rsync)        RSYNC_BIN="${2:?--rsync needs a binary}"; shift ;;
    --ssh-timeout)  SSH_TIMEOUT="${2:?--ssh-timeout needs a value}"; shift ;;
    --check)        MODE="--check" ;;
    --apply)        MODE="--apply" ;;
    *) printf '%s: unknown argument: %s\n' "$CLI_NAME" "$1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*" >&2; }
die() { printf '%s: %s\n' "$CLI_NAME" "$*" >&2; exit 1; }

# ===========================================================================
# THE PRIMITIVES. Pure functions, no ssh -- unit-tested directly in
# bin/tests/push-verb-build.test.sh against plain fixture directories that
# stand in for "a host's build root".
# ===========================================================================

# select_local_build <root> <'latest'|id> -- prints "<id>\t<dir>" on success.
# Verifies manifest.tsv exists and every verb it promises is present and
# executable, the same completeness bar install-verb-build.sh holds what IT
# extracts to. A half-written local build must not be pushable.
select_local_build() {
  local root="$1" want="$2" id="" dir="" d cand missing=0 total f project verb
  [ -d "$root" ] || { say "select_local_build: no local build root at $root"; return 1; }
  if [ "$want" = latest ]; then
    for d in "$root"/*/; do
      d="${d%/}"; cand="$(basename "$d")"
      [ "$cand" = repo ] && continue
      [ -f "$d/manifest.tsv" ] || continue
      if [ -z "$id" ] || [[ "$cand" > "$id" ]]; then id="$cand"; dir="$d"; fi
    done
    [ -n "$id" ] || { say "select_local_build: no materialized build under $root (nothing there has a manifest.tsv)"; return 1; }
  else
    id="$want"; dir="$root/$id"
    [ -f "$dir/manifest.tsv" ] || { say "select_local_build: no local build '$id' at $dir (manifest.tsv missing)"; return 1; }
  fi
  while IFS=$'\t' read -r project verb _ _; do
    [ -n "${verb:-}" ] || continue
    f="$dir/$project/bin/$verb"
    if   [ ! -f "$f" ]; then say "  MISSING $project/bin/$verb"; missing=$((missing+1))
    elif [ ! -x "$f" ]; then say "  BAD     $project/bin/$verb is not executable"; missing=$((missing+1))
    fi
  done < <(grep -v '^#' "$dir/manifest.tsv")
  total="$(grep -cv '^#' "$dir/manifest.tsv" || true)"
  [ "${total:-0}" -gt 0 ] || { say "select_local_build: $dir/manifest.tsv has no rows -- refusing to push an empty verb set"; return 1; }
  [ "$missing" -eq 0 ] || { say "select_local_build: $missing verb(s) missing/not-executable in $dir -- refusing to push an incomplete build"; return 1; }
  printf '%s\t%s\n' "$id" "$dir"
}

# atomic_swap_local <root> <id> -- THE swap. ln -sfn to a tmp name, then
# mv -Tf over `current`. This exact body is what runs on a real host too
# (see remote_atomic_swap below): it is shipped over ssh via `declare -f`,
# never retyped.
atomic_swap_local() {
  local root="$1" id="$2"
  [ -f "$root/$id/manifest.tsv" ] || { echo "atomic_swap_local: $root/$id has no manifest.tsv -- refusing to point current at it" >&2; return 1; }
  ln -sfn "$id" "$root/current.tmp" || { echo "atomic_swap_local: cannot write $root/current.tmp" >&2; return 1; }
  mv -Tf "$root/current.tmp" "$root/current" || { echo "atomic_swap_local: cannot move current into place" >&2; return 1; }
}

# ===========================================================================
# THE TRANSPORT. Everything below this line touches ssh/rsync and needs a
# real host to prove end to end; the suite stubs the binaries to prove the
# WIRING (right host, right paths, right propagation of a nonzero exit), and
# says so rather than claiming a network test it cannot run.
# ===========================================================================

# push_tree <ssh> <rsync> <local-dir> <host> <remote-root> <id>
push_tree() {
  local sshbin="$1" rsyncbin="$2" local_dir="$3" host="$4" remote_root="$5" id="$6"
  "$sshbin" -o BatchMode=yes -o ConnectTimeout="$SSH_TIMEOUT" "$host" \
      "mkdir -p $(printf '%q' "$remote_root")" || {
    say "push_tree: could not create $remote_root on $host"; return 1; }
  # Staged under the build's OWN id -- nothing resolves this path until the
  # swap, so a transfer that dies partway is inert, not half-installed.
  "$rsyncbin" -a --delete -e "$sshbin -o BatchMode=yes -o ConnectTimeout=$SSH_TIMEOUT" \
      "$local_dir/" "$host:$remote_root/$id/" || {
    say "push_tree: rsync to $host:$remote_root/$id failed"; return 1; }
}

# remote_atomic_swap <ssh> <host> <remote-root> <id> -- runs
# atomic_swap_local's OWN BODY on the far side over a one-shot ssh session.
# Nothing is written to the host's disk to make this run: the function body
# arrives on ssh's stdin and is interpreted by the remote's own /bin/bash,
# the same way `mkdir -p` above is a string, not a file.
remote_atomic_swap() {
  local sshbin="$1" host="$2" remote_root="$3" id="$4"
  "$sshbin" -o BatchMode=yes -o ConnectTimeout="$SSH_TIMEOUT" "$host" bash -s -- "$remote_root" "$id" <<EOF
set -uo pipefail
$(declare -f atomic_swap_local)
atomic_swap_local "\$1" "\$2"
EOF
}

# verify_remote_build <ssh> <host> <remote-root> <id> -- BLIND-safe existence
# check before a --rollback swap: this host must already hold <id>, or
# pointing current at it would be pointing at nothing.
verify_remote_build() {
  local sshbin="$1" host="$2" remote_root="$3" id="$4"
  "$sshbin" -o BatchMode=yes -o ConnectTimeout="$SSH_TIMEOUT" "$host" \
      "test -f $(printf '%q' "$remote_root/$id/manifest.tsv")" 2>/dev/null
}

# verify_remote_current <ssh> <host> <remote-root> <id> -- WITNESS: read the
# pin back off the host, rather than trusting the swap's own exit code.
verify_remote_current() {
  local sshbin="$1" host="$2" remote_root="$3" id="$4" got
  got="$("$sshbin" -o BatchMode=yes -o ConnectTimeout="$SSH_TIMEOUT" "$host" \
      "readlink $(printf '%q' "$remote_root/current")" 2>/dev/null)"
  [ "$got" = "$id" ]
}

probe_host() {
  local sshbin="$1" host="$2"
  "$sshbin" -o BatchMode=yes -o ConnectTimeout="$SSH_TIMEOUT" "$host" true 2>/dev/null
}

# ===========================================================================
# build-or-fetch, delegated.
# ===========================================================================

sibling() { local n="$1" p; p="$HERE/$n"; [ -x "$p" ] && printf '%s' "$p" || return 1; }

do_cut() {
  local cutter tmp id
  cutter="$(sibling cut-verb-build.sh)" || { say "$CLI_NAME: cut-verb-build.sh is not beside this script -- cannot cut a build here"; return 1; }
  mkdir -p "$BUILD_ROOT" || { say "$CLI_NAME: cannot create $BUILD_ROOT"; return 1; }
  tmp="$(mktemp -d "$BUILD_ROOT/.cut-XXXXXX")" || { say "$CLI_NAME: cannot create a scratch dir under $BUILD_ROOT"; return 1; }
  if ! "$cutter" --assemble "$tmp" >&2; then
    rm -rf "$tmp"; say "$CLI_NAME: cut-verb-build.sh refused -- see rows above"; return 1
  fi
  if [ ! -f "$tmp/BUILD_ID" ]; then
    rm -rf "$tmp"; say "$CLI_NAME: cut-verb-build.sh produced no BUILD_ID -- refusing"; return 1
  fi
  id="$(cat "$tmp/BUILD_ID")"
  if [ -e "$BUILD_ROOT/$id" ]; then
    rm -rf "$tmp"   # already have it -- not an error, just nothing new to keep
  else
    mv "$tmp" "$BUILD_ROOT/$id"
  fi
}

do_fetch() {
  local installer rc
  installer="$(sibling install-verb-build.sh)" || { say "$CLI_NAME: install-verb-build.sh is not beside this script -- cannot fetch a build here"; return 1; }
  mkdir -p "$BUILD_ROOT" || { say "$CLI_NAME: cannot create $BUILD_ROOT"; return 1; }
  # No --apply: fetches the newest APPROVED build, verifies every verb it
  # promises, and leaves it at $BUILD_ROOT/<id> -- install-verb-build.sh's
  # own APPLY==0 path never switches anything, which is exactly the "fetch,
  # don't adopt" primitive this needs. mandark's OWN `current` is untouched.
  "$installer" --build-root "$BUILD_ROOT" --latest >&2
  rc=$?
  case "$rc" in
    0) : ;;
    6) say "$CLI_NAME: BLIND -- could not reach the release channel to fetch a build"; return 6 ;;
    *) say "$CLI_NAME: install-verb-build.sh --latest refused (exit $rc) -- see rows above"; return 1 ;;
  esac
}

# ===========================================================================
# main
# ===========================================================================

if [ "$DO_LIST" -eq 1 ]; then
  [ -d "$BUILD_ROOT" ] || die "no builds at $BUILD_ROOT"
  found=0
  for d in "$BUILD_ROOT"/*/; do
    d="${d%/}"; id="$(basename "$d")"
    [ "$id" = repo ] && continue
    [ -f "$d/manifest.tsv" ] || continue
    found=1
    n="$(grep -cv '^#' "$d/manifest.tsv" 2>/dev/null || echo 0)"
    printf '  %-24s %s verb(s)\n' "$id" "$n"
  done
  [ "$found" -eq 1 ] || say "no locally materialized builds under $BUILD_ROOT (--cut or --fetch makes one)"
  exit 0
fi

# Selection is exclusive: each names a DIFFERENT id to push, so accepting two
# would mean picking one silently -- same reasoning wire-release-channel.sh
# applies to --host/--all/<account>.
sel_n=$((DO_CUT + DO_FETCH + WANT_LATEST + (${#BUILD_ID} > 0 ? 1 : 0) + (${#ROLLBACK_ID} > 0 ? 1 : 0)))
[ "$sel_n" -gt 0 ] || cli_die "name a build: --cut, --fetch, --build <id>, --latest, or --rollback <id>"
[ "$sel_n" -eq 1 ] || cli_die "--cut, --fetch, --build, --latest and --rollback are mutually exclusive -- say which build to push"
[ -n "$HOST" ] || cli_die "--host is required (the target this pushes to and swaps on)"

if [ -n "$ROLLBACK_ID" ]; then
  echo "== push-verb-build --rollback $ROLLBACK_ID -> $HOST ($MODE) =="
  echo "   no transfer: $HOST must already hold $ROLLBACK_ID under $REMOTE_ROOT"

  if ! probe_host "$SSH_BIN" "$HOST"; then
    echo "  BLIND   could not reach $HOST at all (ssh rc=$?). Nothing was checked or changed."
    exit 6
  fi
  echo "  ok      $HOST is reachable"

  if ! verify_remote_build "$SSH_BIN" "$HOST" "$REMOTE_ROOT" "$ROLLBACK_ID"; then
    echo "  BAD     $HOST has no $REMOTE_ROOT/$ROLLBACK_ID/manifest.tsv -- refusing to swap current onto a build that is not there"
    exit 1
  fi
  echo "  ok      $HOST already holds $ROLLBACK_ID"

  if [ "$MODE" = --check ]; then
    echo "  would   swap $HOST's current -> $ROLLBACK_ID"
    echo "== nothing done (--check). Next: $0 --rollback $ROLLBACK_ID --host $HOST --apply =="
    exit 0
  fi

  if ! remote_atomic_swap "$SSH_BIN" "$HOST" "$REMOTE_ROOT" "$ROLLBACK_ID"; then
    echo "  BAD     the swap on $HOST failed or refused -- see rows above"
    exit 1
  fi
  if verify_remote_current "$SSH_BIN" "$HOST" "$REMOTE_ROOT" "$ROLLBACK_ID"; then
    echo "  OK      $HOST's current -> $ROLLBACK_ID (re-read off the host, not inferred from an exit code)"
    exit 0
  else
    echo "  BAD     the swap ran but $HOST's current does NOT read back as $ROLLBACK_ID"
    exit 1
  fi
fi

# --- build-or-fetch, then resolve which local id/dir that produced --------
if [ "$DO_CUT" -eq 1 ]; then
  do_cut || exit $?
  WANT_LATEST=1
elif [ "$DO_FETCH" -eq 1 ]; then
  do_fetch || exit $?
  WANT_LATEST=1
fi

if [ "$WANT_LATEST" -eq 1 ]; then
  sel="$(select_local_build "$BUILD_ROOT" latest)" || exit 1
else
  sel="$(select_local_build "$BUILD_ROOT" "$BUILD_ID")" || exit 1
fi
BUILD_ID="${sel%%$'\t'*}"
BUILD_DIR="${sel#*$'\t'}"

echo "== push-verb-build $BUILD_ID -> $HOST ($MODE) =="
echo "   from $BUILD_DIR"
echo "   to   $HOST:$REMOTE_ROOT"

if ! probe_host "$SSH_BIN" "$HOST"; then
  echo "  BLIND   could not reach $HOST at all. Nothing was pushed or changed."
  exit 6
fi
echo "  ok      $HOST is reachable"
echo "  ok      $BUILD_ID is complete locally: every verb in its manifest is present and executable"

if [ "$MODE" = --check ]; then
  n="$(grep -cv '^#' "$BUILD_DIR/manifest.tsv" || true)"
  echo "  would   push $n verb('s) worth of tree to $HOST:$REMOTE_ROOT/$BUILD_ID"
  echo "  would   swap $HOST's current -> $BUILD_ID (ln -sfn + mv -Tf, atomic)"
  echo "== nothing done (--check). Next: $0 --build $BUILD_ID --host $HOST --apply =="
  exit 0
fi

if ! push_tree "$SSH_BIN" "$RSYNC_BIN" "$BUILD_DIR" "$HOST" "$REMOTE_ROOT" "$BUILD_ID"; then
  echo "  BAD     push to $HOST failed -- current on $HOST is UNCHANGED. Rows above say which step refused."
  exit 1
fi
echo "  OK      $BUILD_ID is on $HOST at $REMOTE_ROOT/$BUILD_ID"

if ! remote_atomic_swap "$SSH_BIN" "$HOST" "$REMOTE_ROOT" "$BUILD_ID"; then
  echo "  BAD     the swap on $HOST failed or refused -- the pushed tree is there but current did not move"
  exit 1
fi
if verify_remote_current "$SSH_BIN" "$HOST" "$REMOTE_ROOT" "$BUILD_ID"; then
  echo "  OK      $HOST's current -> $BUILD_ID (re-read off the host, not inferred from an exit code)"
  exit 0
else
  echo "  BAD     the swap ran but $HOST's current does NOT read back as $BUILD_ID"
  exit 1
fi
