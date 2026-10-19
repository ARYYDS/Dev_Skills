# Layout (DESKTOP-C4JG869)

Read this file for roots. `scripts/wt.sh` creates the children. Do not add another root.

## Drives

| Volume | Disk | Role |
|---|---|---|
| O: OptaneWin, 125 GB NTFS | Intel Optane 905P | Windows development: `O:\Serein\` worktrees and bare repo, `O:\WinCache\` caches, pagefile |
| P: OptaneWSL, 224 GB NTFS (64K) | Intel Optane 905P | `P:\WSL\FedoraLinux-43\ext4.vhdx` (Linux root, ext4 about 206 GB) and `P:\WSL\swap.vhdx`. No Windows trees. |
| C: D: | Predator GM7 | OS and tools; `D:\Dev_Skills` (this skill tree). No Serein compile writes. |
| E: F: | Acer N7000 | not used by Serein |

`O:\Serein ARC` is a robocopy of an old workspace, not a source tree. `D:\Workspace\Serein ARC` and its `fed.sh` / `run-locked.sh` are retired.

## Identity

| Field | Windows side | Linux side |
|---|---|---|
| Who | `ARYYDS` in Git Bash | `SR` (uid 1001, wheel) on `FedoraLinux-43` (default distro, `[user] default=SR`) |
| Invoke | `"C:\Program Files\Git\bin\bash.exe" -lc '...'` | `wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc '...'` |
| Bare repo | `O:\Serein\repo.git` | `/home/SR/repo.git` |
| Live lines | `O:\Serein\wt\<branch>` | `/home/SR/wt/<branch>` |
| One-shots | `O:\Serein\src\<8hex>-<job>` | `/home/SR/src/<8hex>-<job>` |
| Rust targets | `O:\WinCache\target\<wt\|src>-<name>-<client\|server>` | `/home/SR/.cache/target/...` |
| Go | `GOCACHE=O:\WinCache\go-build`, `GOMODCACHE=O:\WinCache\go-mod`, `GOPATH=O:\WinCache\go` | `~/.cache/go-build`, `~/.cache/go-mod`, `GOTOOLCHAIN=local` (`~/.serein-env`) |
| Cargo home | `CARGO_HOME=O:\WinCache\cargo` | `~/.cargo` |
| Temp, logs | `TEMP=O:\WinCache\tmp`, `O:\WinCache\logs` | `~/logs` (`/tmp` is tmpfs and is wiped when the distro stops) |
| Dev_Skills | `D:\Dev_Skills` (pull only) | `~/Dev_Skills` (pull only) |
| GitHub key | `C:\Users\ARYYDS\.ssh\serein_arc_deploy_ed25519` via the bare repo's `core.sshCommand` | `~/.ssh/serein_arc_sr_ed25519` via `~/.ssh/config`, generated inside ext4 |
| Remote | `git@github.com:ARYYDS/Serein-ARC.git` | same |

`ARYYDS` on FedoraLinux-43 is `nologin`. `fedoraremix` and `Fedora43` are not used.

Toolchains: the authoritative list with versions and SHA-256 is the "工具链" table in Serein-ARC `build/README.md` (v2/main e5091ed7, 2026-10-18). Tool roots: Windows `O:\WinCache\tools` (`bin\` gitleaks, cargo-deny, buf, sccache; `go\` go1.27.2; `node-v24.21.0-win-x64`; `msys64` for `-race`), put on PATH per job with `GOTOOLCHAIN=local` (the system go 1.27.1 and Node 24.19.0 stay unused); Linux `~/tools` (`SEREIN_ARC_TOOLS`, `~/tools/bin` first on PATH via `~/.serein-env`; go1.27.2, protoc 36.2 and its plugins, gitleaks, cargo-deny, buf 1.73.0, sccache). Rust 1.99.0 on both sides, musl target on Linux. Linux has no `awk`, `jq` or `gh`; only experiment harness scripts use awk.

## Parents (create once if missing)

Windows, Git Bash:

```bash
mkdir -p /o/Serein/wt /o/Serein/src /o/WinCache/target /o/WinCache/cargo /o/WinCache/logs
git clone --bare git@github.com:ARYYDS/Serein-ARC.git /o/Serein/repo.git \
  -c core.sshCommand='ssh -F /dev/null -i C:/Users/ARYYDS/.ssh/serein_arc_deploy_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new'
git -C /o/Serein/repo.git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git -C /o/Serein/repo.git for-each-ref --format='delete %(refname)' refs/heads | git -C /o/Serein/repo.git update-ref --stdin
git -C /o/Serein/repo.git fetch --prune origin
```

Linux, inside SR (one line per call, `--exec`):

```bash
mkdir -p ~/wt ~/src ~/.cache/target ~/logs
git clone -q https://github.com/ARYYDS/Dev_Skills.git ~/Dev_Skills
ssh-keygen -t ed25519 -N '' -C 'Win11 FedoraLinux-43 SR (serein-arc)' -f ~/.ssh/serein_arc_sr_ed25519   # then register the .pub as a deploy key
git clone --bare git@github.com:ARYYDS/Serein-ARC.git ~/repo.git
git -C ~/repo.git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git -C ~/repo.git for-each-ref --format='delete %(refname)' refs/heads | git -C ~/repo.git update-ref --stdin
git -C ~/repo.git fetch --prune origin
```

- A bare clone copies every branch into `refs/heads/*` and sets no fetch spec. Without the spec, `git fetch` only writes `FETCH_HEAD`. With it, branches live in `refs/remotes/origin/*`, and `fetch --prune` removes the ones deleted on GitHub. The clone-time `refs/heads/*` copies never get pruned, so delete them once (the `update-ref --stdin` line).
- Each side has its own key. A key never moves between Windows and WSL2; a new side gets a new key and a new deploy key entry.

## Children

| Kind | Name | Lifetime |
|---|---|---|
| Live worktree | branch name (`/` becomes `_`) | until the line merges, then `wt.sh rm` |
| One-shot worktree | `<8hex>-<job>` | removed by the job that made it, when its test ends |
| Rust target | `<wt\|src>-<name>-<client\|server>` | removed with its worktree |
| Go cache entries | content hash in the side's pool | kept; Go trims entries unused for 5 days |
| Test branch | `v2/test/<topic>-<yyyymmdd>` on GitHub | deleted when the test ends (SKILL.md section 6) |

## Capacity

O: has about 83 GB free (about 108 GB once the user deletes `O:\Serein ARC`). A `rust/client` target is about 5.5 GB and `rust/server` about 1.7 GB; the old D: Go cache reached 54 GB. Check `df` before starting several Rust builds, and remove finished one-shots first.
