---
name: serein-optane-wsl
description: "Load this skill before Serein compile, cargo build, go test, Linux package, fed.sh, WSL, git worktree, fetch, or Optane/GM7/9P path choice on DESKTOP-C4JG869. Sync with git fetch, never 9P copy. Keep automount off. Quote POSIX for pwsh 7. Linux is wsl -d FedoraLinux-43 -u SR. One-shot test worktrees are removed when the test ends. Use when compiling or testing Serein, fetching github.com/ARYYDS/Serein-ARC, adding worktrees, or the user runs /serein-optane-wsl."
when-to-use: "Serein compile, Serein build, Serein test, cargo build, cargo test, go test, musl, fed.sh, FedoraLinux-43, wsl -d FedoraLinux-43, worktree, GOCACHE, CARGO_TARGET_DIR, 9P, GM7, Optane, pwsh, quoting, /serein-optane-wsl, 编译, 构建, 测试, 多分支, 穿缓存"
whenToUse: "Serein compile, Serein build, Serein test, cargo build, cargo test, go test, musl, fed.sh, FedoraLinux-43, wsl -d FedoraLinux-43, worktree, GOCACHE, CARGO_TARGET_DIR, 9P, GM7, Optane, pwsh, quoting, /serein-optane-wsl, 编译, 构建, 测试, 多分支, 穿缓存"
metadata:
  short-description: "Serein compile: fetch not 9P, parent dirs, pwsh quoting, delete one-shot"
argument-hint: "<line-or-commit>"
---

# Content map

Read this map, then `references/layout.md`, `references/9p.md`, `references/pwsh.md`. Do not invent roots.

```
serein-optane-wsl/
|
|-- SKILL.md                         procedure (this file)
|   L1-9     YAML catalog / triggers
|   L11-59   content map (ASCII)
|   L63-69   1 Identity (quote wsl '~')
|   L71-97   2 Parents then children; bare fetch spec
|   L99-106  3 git fetch --prune, not 9P copy
|   L108-117 4 compile / build / run off 9P
|   L119-130 5 pwsh 7 quoting / CRLF / cwd
|   L132-138 6 live line origin/v2
|   L140-153 7 one-shot; REF then delete
|   L155-162 8 forbidden
|   L164-170 9 preflight + fetch spec
|
|-- references/layout.md             roots and parents only
|   L5-11    disks C/D O P
|   L13-27   identity (FedoraLinux-43, SR)
|   L29-38   parents to mkdir once
|   L40-49   children (line name / 8-hex)
|   L51-57   distros
|
|-- references/9p.md                 9P analysis
|   L7-17    forward /mnt vs reverse \\wsl$
|   L19-35   fetch (TCP) vs copy (9P)
|   L37-59   automount stays false
|   L61-75   compile pitfalls
|   L77-86   build / lock / WSLENV /p
|   L88-99   run / cwd leak / inotify
|   L101-111 preflight commands
|
|-- references/pwsh.md               pwsh 7 vs Linux $
|   L7-18    one parser; quote wsl '~'
|   L20-36   double-quote eats $HOME
|   L38-48   CRLF -> bash $'\\r'
|   L50-56   cwd leak into wsl
|   L58-60   spaces; Linux argv
|   L62-69   checklist
|
|-- scripts/prune-linux-src.ps1      leftover src/ only
    L1-27    worktree list --porcelain; strip CR
```

Windows cache parent = O: (User env). Linux root = `$HOME` of SR on P: VHDX. Live Windows git root = current workspace.

# Workflow

## 1. Identity

```powershell
wsl '~' -d FedoraLinux-43 -u SR -- bash -lc 'echo $WSL_DISTRO_NAME $USER $HOME; pwd'
```

Required: distro `FedoraLinux-43`, user `SR`, home is the Linux root in layout, `pwd` is not `/mnt/...`. Stop on remix, user `ARYYDS`, or cwd under `/mnt/`. Always pass `'~' -d FedoraLinux-43 -u SR`. Quote the tilde in pwsh (`wsl ~` expands to `C:\Users\ARYYDS`). POSIX `$` stays in pwsh **single quotes** (`references/pwsh.md`).

## 2. Parents first, then children

Layout lists **roots** and **parents**. Create a parent if it is missing. Then create the child for this job. Never mkdir a child under C:, D:, `/mnt/`, or remix home.

| Job | Parent (create once) | Child (this job) |
|---|---|---|
| Windows live line | live git root + its worktree parent | `git worktree add` named from the line |
| Windows compile write | Windows cache parent on O: | go/cargo/temp create files inside on first use |
| Linux live line | Linux `wt` parent | `git worktree add` named from the line |
| Linux one-shot test | Linux `src` parent | `git worktree add --detach` named from the commit short hash |
| Linux objects | Linux bare repo | none; `git fetch` only |

```powershell
wsl '~' -d FedoraLinux-43 -u SR -- bash -lc 'mkdir -p "$HOME/wt" "$HOME/src"'
```

Bare repo, only if absent (community: bare clone has **no** `remote.origin.fetch`, so `origin/v2/*` will not appear until this config):

```powershell
wsl '~' -d FedoraLinux-43 -u SR -- bash -lc 'git clone --bare git@github.com:ARYYDS/Serein-ARC.git "$HOME/repo.git" && git -C "$HOME/repo.git" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" && git -C "$HOME/repo.git" fetch origin --prune'
```

This machine's clone was missing that fetch spec until it was set; `git fetch` only wrote `FETCH_HEAD` and `refs/remotes` was empty.

Windows cache parent: User env already points compile writes there. If a product script still writes under the live git root, point that **process** at the Windows cache parent. Do not robocopy old D:/C: caches.

Cargo uses the worktree's own `target/` (workspace root inside the child). Go uses one GOCACHE under the cache parent. Do not invent extra target directory names.

## 3. Sync is git fetch, not 9P

Windows: commit and `git push origin` to `git@github.com:ARYYDS/Serein-ARC.git`.  
Linux: `git -C "$HOME/repo.git" fetch origin --prune`, then worktree add from `origin/...`. Deploy key is fetch-only.

Do not `cp` / `robocopy` / `tar` / Explorer through `/mnt/*` or `\\wsl$\`. That is 9P copy-migration. `git fetch` is TCP. Details: `references/9p.md`.

Keep FedoraLinux-43 automount off. Do not `mount -t drvfs`, do not add drive letters to `fstab`, do not start remix. Empty `/mnt/c` `/mnt/d` `/mnt/o` `/mnt/p` dirs are not mounts.

## 4. Compile, build, run stay off 9P

| Phase | Stay on | Fail if |
|---|---|---|
| Linux compile / cargo / go test | ext4 under `$HOME` | cwd or GOCACHE under `/mnt/` |
| Windows compile / cargo / go | NTFS cache parent on O: | `\\wsl$\` as target or source |
| Run Linux binary | `cd` the worktree, then exec | PowerShell cwd leaked as `/mnt/d` |
| Run Windows product / CLI / TUN | Win32 on NTFS | ELF or `\\wsl$\` path |

Do not set `WSLENV` with `/p`. `appendWindowsPath` stays false. After `worktree add`, `cd` into the **project tree inside the child** (the git root of this repo is not the crate). Source `~/.serein-env` after that `cd`.

## 5. pwsh 7

The tool is pwsh. Double quotes expand `$HOME` / `$C` / `$(...)` before `wsl` starts. `&&` in double quotes is pwsh, not bash. Here-strings piped into WSL often have `\r`.

```powershell
# POSIX $ lives; then strip CR
$job = Get-Content -Raw -LiteralPath $env:TEMP\agent-job.sh
$job = $job -replace "`r`n","`n"
$job | & wsl.exe -d FedoraLinux-43 -u SR -- bash -lc 'tr -d "\r" > /tmp/job.sh && bash /tmp/job.sh'
```

Full list: `references/pwsh.md`.

## 6. Live line (keep until the line merges)

```powershell
wsl '~' -d FedoraLinux-43 -u SR -- bash -lc 'cd "$HOME" && . ~/.serein-env && git -C "$HOME/repo.git" fetch origin --prune && git -C "$HOME/repo.git" worktree add "$HOME/wt/<line>" origin/v2/<line>'
```

Compile inside that child, in the project tree the job names. One directory, one branch. After the line merges: `git worktree remove` that child.

## 7. One-shot test (detach, then delete)

```powershell
wsl '~' -d FedoraLinux-43 -u SR -- bash -lc 'cd "$HOME" && . ~/.serein-env && git -C "$HOME/repo.git" fetch origin --prune && REF=${REF:-origin/main} && FULL=$(git -C "$HOME/repo.git" rev-parse --verify "$REF^{commit}") && C=$(git -C "$HOME/repo.git" rev-parse --short=8 "$FULL") && git -C "$HOME/repo.git" worktree add --detach "$HOME/src/$C" "$FULL"'
```

`REF` is the job's commit-ish. Do not use bare `HEAD` on the clone: that can stay at clone-time `main` while GitHub has moved. Put add, compile, and remove in **one** LF script (`references/pwsh.md`). After tests:

```bash
git -C "$HOME/repo.git" worktree remove --force "$HOME/src/$C"
git -C "$HOME/repo.git" worktree prune
```

Do not `git archive | tar`. Do not leave the child. `scripts/prune-linux-src.ps1` only sweeps forgotten `src/` children.

## 8. Forbidden

- Copying caches or trees onto O: or into Linux home
- `fedoraremix`, `-u ARYYDS`, `/home/ARYYDS` on P:
- `/mnt/*` and `\\wsl$\` as workspaces; `mount -t drvfs`; automount=true; `WSLENV=.../p`
- Compile writes on C: or D: (GM7)
- Sharing one Cargo `target/` across two worktrees
- pwsh double-quoted Linux `$HOME` / `&&` / bare `bash` / unquoted `wsl ~`

## 9. Preflight

```powershell
wsl '~' -d FedoraLinux-43 -u SR -- bash -lc 'grep -A2 "\[automount\]" /etc/wsl.conf; git -C "$HOME/repo.git" config --get remote.origin.fetch; findmnt -t 9p | grep -E "drvfs|/mnt/[cdop]" && echo FAIL_9P || echo OK_NO_DRVFS; case $PWD in /mnt/*) echo FAIL_MNT;; *) echo OK_EXT4;; esac'
```

Expect fetch spec `+refs/heads/*:refs/remotes/origin/*`.
