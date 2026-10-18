# Rescue: remove forgotten one-shot worktrees under the Linux src parent.
# Uses `git worktree list --porcelain` (community). Live wt/ children stay.
$ErrorActionPreference = 'Stop'
$script = @'
set -e
R="$HOME/repo.git"
S="$HOME/src"
[ -d "$R" ] || { echo OK; exit 0; }
git -C "$R" worktree list --porcelain | while IFS= read -r line; do
  case $line in
    worktree\ *)
      p=${line#worktree }
      case $p in
        "$S"/*)
          git -C "$R" worktree remove --force "$p" 2>/dev/null || rm -rf "$p"
          echo "removed $p"
          ;;
      esac
      ;;
  esac
done
git -C "$R" worktree prune
echo OK
'@
$script = $script -replace "`r`n", "`n"
$script | & wsl.exe -d FedoraLinux-43 -u SR -- bash -lc 'tr -d "\r" > /tmp/prune-linux-src.sh && bash /tmp/prune-linux-src.sh'
