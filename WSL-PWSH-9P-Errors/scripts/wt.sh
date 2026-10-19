#!/usr/bin/env bash
# wt.sh - Serein worktrees on Win11 (DESKTOP-C4JG869). Each side runs its own copy, fetched from GitHub.
# Nothing crosses between Windows and WSL2: no /mnt, no \\wsl$, no files over wsl.exe stdin.
#
#   Windows (O:)  Git Bash:
#     bash /d/Dev_Skills/WSL-PWSH-9P-Errors/scripts/wt.sh <command> ...
#   Linux (P:, FedoraLinux-43 user SR):
#     wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc 'bash ~/Dev_Skills/WSL-PWSH-9P-Errors/scripts/wt.sh <command> ...'
#
# Commands
#   check                              preflight for this side
#   fetch                              git fetch --prune origin
#   line <branch>                      live worktree wt/<branch> at origin/v2/<branch> (add, or move in place)
#   oneshot <ref> <job>                detached worktree src/<8hex>-<job>; ref "-" means origin/v2/main
#   target <worktree> <client|server>  CARGO_TARGET_DIR for that Cargo workspace of that worktree
#   rm <worktree>                      remove a worktree under wt/ or src/ and its target directories
#   prune [--job J] [--older-than H] [--yes]
#                                      list one-shot worktrees (remove them with --yes)
#   delbranch <v2/test/...>            delete a test branch on GitHub, then fetch --prune
set -euo pipefail

die() { echo "wt.sh: $*" >&2; exit 2; }

case "$(uname -s)" in
  MINGW*|MSYS*)
    SIDE=win
    [ -d /o ] || die "O: is missing"
    R=/o/Serein/repo.git
    WT=/o/Serein/wt
    SRC=/o/Serein/src
    TGT=/o/WinCache/target
    ;;
  Linux)
    SIDE=linux
    [ "${WSL_DISTRO_NAME:-}" = FedoraLinux-43 ] || die "Linux side must be FedoraLinux-43 (got '${WSL_DISTRO_NAME:-none}')"
    [ "$(id -un)" = SR ] || die "Linux side must run as SR (got $(id -un))"
    case "$HOME" in /mnt/*) die "HOME is on 9P: $HOME";; esac
    case "$PWD" in /mnt/*) cd "$HOME";; esac
    R=$HOME/repo.git
    WT=$HOME/wt
    SRC=$HOME/src
    TGT=$HOME/.cache/target
    ;;
  *) die "unknown side $(uname -s)" ;;
esac

native() { if [ "$SIDE" = win ]; then cygpath -w "$1"; else printf '%s\n' "$1"; fi; }
safe_name() { printf '%s' "$1" | tr '/\\: ' '____' | tr -cd 'A-Za-z0-9._-'; }
need_repo() { [ -d "$R" ] || die "bare repo $R is missing (see references/layout.md, Parents)"; }

resolve_ref() {
  local ref=$1
  case "$ref" in
    -|'') ref=origin/v2/main ;;
    origin/*|refs/*) ;;
    v2/*) ref=origin/$ref ;;
    *) git -C "$R" rev-parse -q --verify "$ref^{commit}" >/dev/null 2>&1 || ref=origin/v2/$ref ;;
  esac
  git -C "$R" rev-parse --verify "$ref^{commit}"
}

record() {
  local dir=$1
  printf 'source %s commit %s tree %s git %s side %s path %s\n' \
    "$(git -C "$dir" rev-parse --short=8 HEAD)" "$(git -C "$dir" rev-parse HEAD)" \
    "$(git -C "$dir" rev-parse 'HEAD^{tree}')" "$(git --version | cut -d' ' -f3)" "$SIDE" "$(native "$dir")"
}

target_dir() {
  local dir=$1 ws=$2 kind name
  case "$ws" in client|server) ;; *) die "Cargo workspace must be client or server";; esac
  case "$dir" in
    "$WT"/*) kind=wt ;;
    "$SRC"/*) kind=src ;;
    *) die "$dir is not under $WT or $SRC" ;;
  esac
  name=$(basename "$dir")
  native "$TGT/$kind-$name-$ws"
}

find_wt() {
  local a=$1
  case "$a" in
    /*|[A-Za-z]:*) [ "$SIDE" = win ] && a=$(cygpath -u "$a"); printf '%s\n' "$a" ;;
    *) if [ -d "$SRC/$a" ]; then printf '%s\n' "$SRC/$a"; elif [ -d "$WT/$a" ]; then printf '%s\n' "$WT/$a"; else die "no worktree named $a"; fi ;;
  esac
}

cmd_check() {
  local bad=0
  echo "side=$SIDE repo=$(native "$R")"
  if [ -d "$R" ]; then
    echo "fetch.spec=$(git -C "$R" config --get-all remote.origin.fetch | tr '\n' ' ')"
    if git -C "$R" ls-remote -q --heads origin v2/main >/dev/null 2>&1; then echo OK_GITHUB; else echo FAIL_GITHUB; bad=1; fi
  else
    echo "FAIL_NO_REPO"; bad=1
  fi
  if [ "$SIDE" = linux ]; then
    grep -qiE '^[[:space:]]*enabled[[:space:]]*=[[:space:]]*false' /etc/wsl.conf && echo OK_AUTOMOUNT_OFF || { echo FAIL_AUTOMOUNT; bad=1; }
    grep -qiE '^[[:space:]]*appendWindowsPath[[:space:]]*=[[:space:]]*false' /etc/wsl.conf && echo OK_NO_WINPATH || { echo FAIL_WINPATH; bad=1; }
    if findmnt -rn -t 9p -o TARGET,OPTIONS | grep -E 'aname=drvfs|^/mnt/'; then echo FAIL_9P; bad=1; else echo OK_NO_DRVFS; fi
    case "$(go env GOCACHE 2>/dev/null)" in "$HOME"/*) echo OK_GOCACHE;; *) echo FAIL_GOCACHE; bad=1;; esac
  else
    case "${CARGO_HOME:-}" in [Oo]:*) echo OK_CARGO_HOME;; *) echo "FAIL_CARGO_HOME=${CARGO_HOME:-unset}"; bad=1;; esac
    case "$(go env GOCACHE 2>/dev/null)" in [Oo]:*) echo OK_GOCACHE;; *) echo FAIL_GOCACHE; bad=1;; esac
    [ -n "$(git -C "$R" config --get core.sshCommand 2>/dev/null)" ] && echo OK_SSHCOMMAND || { echo FAIL_SSHCOMMAND; bad=1; }
  fi
  if [ -n "${CARGO_TARGET_DIR:-}" ]; then echo "FAIL_GLOBAL_CARGO_TARGET_DIR=$CARGO_TARGET_DIR"; bad=1; else echo OK_NO_GLOBAL_TARGET; fi
  return $bad
}

cmd_fetch() { need_repo; git -C "$R" fetch -q --prune origin; echo "fetched $(git -C "$R" rev-parse --short=8 origin/v2/main) origin/v2/main"; }

cmd_line() {
  [ $# -eq 1 ] || die "usage: line <branch>"
  need_repo
  local b=${1#v2/} full dir
  cmd_fetch >/dev/null
  full=$(git -C "$R" rev-parse --verify "origin/v2/$b^{commit}") || die "origin/v2/$b not found"
  dir=$WT/$(safe_name "$b")
  if [ -e "$dir" ]; then
    [ -z "$(git -C "$dir" status --porcelain)" ] || die "$dir has uncommitted changes"
    git -C "$dir" checkout -q --detach "$full"
  else
    mkdir -p "$WT"
    git -C "$R" worktree add -q --detach "$dir" "$full"
  fi
  record "$dir"
  echo "CARGO_TARGET_DIR client=$(target_dir "$dir" client) server=$(target_dir "$dir" server)"
}

cmd_oneshot() {
  [ $# -eq 2 ] || die "usage: oneshot <ref|-> <job>"
  need_repo
  local job full dir
  job=$(safe_name "$2"); [ -n "$job" ] || die "job name is empty"
  cmd_fetch >/dev/null
  full=$(resolve_ref "$1") || die "ref $1 not found"
  dir=$SRC/$(git -C "$R" rev-parse --short=8 "$full")-$job
  [ ! -e "$dir" ] || die "$dir already exists (another job with this name?)"
  mkdir -p "$SRC"
  git -C "$R" worktree add -q --detach "$dir" "$full"
  record "$dir"
  echo "CARGO_TARGET_DIR client=$(target_dir "$dir" client) server=$(target_dir "$dir" server)"
}

cmd_target() { [ $# -eq 2 ] || die "usage: target <worktree> <client|server>"; target_dir "$(find_wt "$1")" "$2"; }

remove_one() {
  local dir=$1 kind name t
  case "$dir" in "$WT"/*) kind=wt;; "$SRC"/*) kind=src;; *) die "refusing to remove $dir";; esac
  name=$(basename "$dir")
  git -C "$R" worktree remove --force "$dir" 2>/dev/null || rm -rf -- "${dir:?}"
  for t in "${TGT:?}/$kind-$name-client" "${TGT:?}/$kind-$name-server"; do
    [ -e "$t" ] && rm -rf -- "${t:?}"
  done
  echo "removed $(native "$dir")"
}

cmd_rm() { [ $# -eq 1 ] || die "usage: rm <worktree>"; need_repo; remove_one "$(find_wt "$1")"; git -C "$R" worktree prune; }

cmd_prune() {
  need_repo
  local job='' hours='' yes=0 now p age hit
  while [ $# -gt 0 ]; do
    case "$1" in
      --job) job=$(safe_name "${2:?}"); shift 2 ;;
      --older-than) hours=${2:?}; shift 2 ;;
      --yes) yes=1; shift ;;
      *) die "unknown option $1" ;;
    esac
  done
  now=$(date +%s)
  git -C "$R" worktree prune
  for p in "$SRC"/*; do
    [ -d "$p" ] || continue
    age=$(( (now - $(stat -c %Y "$p")) / 3600 ))
    hit=1
    [ -z "$job" ] || case "$(basename "$p")" in *-"$job") ;; *) hit=0;; esac
    [ -z "$hours" ] || [ "$age" -ge "$hours" ] || hit=0
    if [ $hit = 1 ] && [ $yes = 1 ]; then remove_one "$p"; else echo "one-shot $(basename "$p") age_h=$age match=$hit"; fi
  done
  git -C "$R" worktree prune
}

cmd_delbranch() {
  [ $# -eq 1 ] || die "usage: delbranch <v2/test/...>"
  need_repo
  local b=${1#origin/}
  b=${b#refs/heads/}
  case "$b" in v2/test/?*) ;; *) die "only test branches (v2/test/...) may be deleted here: $b";; esac
  git -C "$R" push -q origin --delete "$b"
  git -C "$R" fetch -q --prune origin
  if git -C "$R" rev-parse -q --verify "refs/remotes/origin/$b" >/dev/null; then die "origin/$b still present"; fi
  echo "deleted $b"
}

c=${1:-}; [ $# -gt 0 ] && shift
case "$c" in
  check) cmd_check ;;
  fetch) cmd_fetch ;;
  line) cmd_line "$@" ;;
  oneshot) cmd_oneshot "$@" ;;
  target) cmd_target "$@" ;;
  rm) cmd_rm "$@" ;;
  prune) cmd_prune "$@" ;;
  delbranch) cmd_delbranch "$@" ;;
  *) sed -n '2,24p' "$0"; exit 2 ;;
esac
