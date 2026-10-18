# Layout (DESKTOP-C4JG869)

Read this file for roots. The skill creates parents, then children. Do not add a third root.

## Disks

| Volume | Role |
|---|---|
| C: D: | OS, leftover tools, current Windows git workspace. No new compile writes. |
| O: | Windows cache parent. Pagefile. Extra tree copy (not the live workspace). |
| P: | FedoraLinux-43 VHDX and WSL swap only. |

## Identity

| Field | Value |
|---|---|
| Distro | `FedoraLinux-43` |
| User | `SR` |
| Invoke | `wsl '~' -d FedoraLinux-43 -u SR -- bash -lc '...'` |
| Linux root | `$HOME` of `SR` |
| Windows live git root | current workspace (`D:\Serein ARC`) |
| Windows cache parent | `O:\WinCache` (User env already points compile writes here) |
| Remote | `git@github.com:ARYYDS/Serein-ARC.git` |

`ARYYDS` on FedoraLinux-43 is `nologin`. `fedoraremix` and `Fedora43` are not compile distros.

Automount of Windows letters is **off** on FedoraLinux-43. Do not remount them. 9P: `references/9p.md`. pwsh quoting: `references/pwsh.md`.

## Parents (create once if missing)

| Parent | How |
|---|---|
| Linux `$HOME/wt` | `mkdir -p` — live lines |
| Linux `$HOME/src` | `mkdir -p` — one-shot tests only |
| Linux `$HOME/repo.git` | `git clone --bare` then `git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'` (bare clone does not create this; without it `git fetch` only updates `FETCH_HEAD` and `origin/v2/*` does not exist) |
| Linux `$HOME/.cache` | first `go`/`cargo` may create it |
| Windows cache parent | already present; do not copy old caches into it |
| Windows live `wt` | `mkdir` under the live git root when the first Windows line starts |

## Children (this job only)

| Kind | How the name is chosen | Lifetime |
|---|---|---|
| Live worktree | the line name | until the line merges, then `git worktree remove` |
| One-shot worktree | 8-hex of the commit | delete with `git worktree remove` when the test ends |
| Cargo `target/` | default inside that worktree | dies with the worktree |
| Go cache files | content hash under the cache parent | keep |

Do not invent extra cache folder names. Do not robocopy D: or C: caches onto O: or into `$HOME`.

## Distros

| Name | Use |
|---|---|
| `FedoraLinux-43` | Linux compile and test |
| `fedoraremix` | Legacy. Do not start. |
| `Fedora43` | Corrupt. RE only. |
