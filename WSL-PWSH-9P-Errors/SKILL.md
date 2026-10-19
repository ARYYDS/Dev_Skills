---
name: serein-optane-wsl
description: "Load before any Serein compile, build, test, cargo, go test, git fetch or worktree, or WSL job on Win11 DESKTOP-C4JG869. Windows work lives on O: (Git Bash, O:\\Serein). Linux work lives on P: as FedoraLinux-43 user SR. GitHub is the only path between them: each side runs git fetch; no /mnt, no \\\\wsl$, no files over wsl.exe stdin. Call WSL with --exec, never --. Test branches and one-shot worktrees are deleted when the test ends. Use when compiling or testing Serein, fetching github.com/ARYYDS/Serein-ARC, adding worktrees, or the user runs /serein-optane-wsl."
when_to_use: "Serein compile, build, test, cargo build/check/test, go build/test/vet, musl, WSL, wsl.exe, FedoraLinux-43, user SR, O: drive, P: drive, Optane, git worktree, git fetch, test branch, CARGO_TARGET_DIR, GOCACHE, 9P, /mnt, Git Bash, pwsh quoting, SSH to Win11, long build over 10 minutes, /serein-optane-wsl, 编译, 构建, 测试, 多分支, 删分支"
when-to-use: "Serein compile, build, test, cargo, go test, WSL, FedoraLinux-43, SR, O:, P:, worktree, fetch, test branch, CARGO_TARGET_DIR, GOCACHE, 9P, pwsh, Git Bash, /serein-optane-wsl, 编译, 构建, 测试, 多分支, 删分支"
whenToUse: "Serein compile, build, test, cargo, go test, WSL, FedoraLinux-43, SR, O:, P:, worktree, fetch, test branch, CARGO_TARGET_DIR, GOCACHE, 9P, pwsh, Git Bash, /serein-optane-wsl, 编译, 构建, 测试, 多分支, 删分支"
metadata:
  short-description: "Serein on Win11: O: Windows, P: SR Linux, GitHub fetch only, --exec, delete test branches"
argument-hint: "<line-or-commit>"
---

# Content map

Read this file, then `references/layout.md`. Read `references/pwsh.md` before writing any wsl.exe command line and `references/9p.md` when a path choice is unclear. Do not invent roots.

```
serein-optane-wsl/
|-- SKILL.md               procedure (this file)
|   1 Roles                which side does what
|   2 Calling WSL          --exec, quoting per shell
|   3 Source               GitHub is the only path
|   4 Worktrees            wt.sh line / oneshot / rm / prune
|   5 Rust and Go caches   one target per building workspace; Go one pool
|   6 Test branches        create, fetch on both sides, test, delete
|   7 Long jobs            bg.sh, logs, waiting
|   8 Forbidden
|   9 Preflight
|-- references/layout.md   drives, roots, parents, keys, first-time setup
|-- references/9p.md       why nothing crosses Windows <-> WSL2
|-- references/pwsh.md     pwsh 7, cmd.exe over SSH, Git Bash: what each eats
|-- scripts/wt.sh          worktrees and test branches (runs natively on either side)
`-- scripts/bg.sh          long jobs that outlive the SSH call (Windows side launcher)
```

# Workflow

## 1. Roles

| Side | Drive | Root | Shell | Does |
|---|---|---|---|---|
| Windows | O: OptaneWin | `O:\Serein\` (repo.git, wt, src), caches `O:\WinCache\` | Git Bash | Windows compile, test, product install and CLI/TUN tests |
| Linux | P: OptaneWSL (VHDX) | `/home/SR/` (repo.git, wt, src), caches `~/.cache` | bash in FedoraLinux-43 as SR | Linux compile, test, musl packages |
| Dev machine | - | `C:\code\...` | - | edits, commits, pushes to GitHub; no builds |

Identity check (from cmd.exe over SSH, which is what the Win11 SSH tool runs):

```bat
wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc "echo $WSL_DISTRO_NAME $(id -un) $HOME $PWD"
```

Expect `FedoraLinux-43 SR /home/SR /home/SR`. Stop on `fedoraremix`, `Fedora43`, user `ARYYDS`, or a cwd under `/mnt/`.

## 2. Calling WSL

Always `wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc '<script>'`.

- `--exec` hands the script straight to bash. `--` (and no separator at all) first runs the line through the default shell, which expands every `$VAR` and `$(...)` before your script assigns them. Measured: `X=abc; echo $X` prints `X=[]` with `--` and `X=[abc]` with `--exec`. Any block that assigns a variable and uses it later is broken under `--`.
- `--cd ~` instead of `wsl ~`: the bare `~` form only works as the first argument and pwsh 7 expands it to `C:\Users\ARYYDS`.
- Each shell eats different characters before wsl.exe sees them. pwsh 7: single-quote the script. cmd.exe: double-quote the script, single quotes inside, no `"` inside. Git Bash: `export MSYS_NO_PATHCONV=1` and write `--cd '~'`, or `~` becomes `C:/Users/ARYYDS` and `/home/SR/x` becomes `C:/Program Files/Git/home/SR/x`. Details and examples: `references/pwsh.md`.
- A script that does not fit on one line belongs in a repository (this one, or Serein-ARC) and runs from that side's own fetched copy. Never pipe a script file into wsl.exe.

## 3. Source: GitHub only

| Repository | Who pushes | Windows copy | Linux copy |
|---|---|---|---|
| `ARYYDS/Serein-ARC` (private) | dev machine (v2 branches as `v2/<name>`); each Win11 side may push reports and test branches with its own deploy key | `O:\Serein\repo.git` (bare) | `~/repo.git` (bare) |
| `ARYYDS/Dev_Skills` (public) | dev machine only (`C:\code\Dev_Skills`) | `D:\Dev_Skills` | `~/Dev_Skills` |

- Win11 updates Dev_Skills with `git -C <copy> pull --ff-only`. Do not edit or commit there; a change goes through the dev machine and GitHub.
- Uncommitted changes are not built. Every build records the line printed by `wt.sh` (`source <8hex> commit ... tree ... git ... side ...`).

## 4. Worktrees (`scripts/wt.sh`)

Run the side's own copy:

```bash
# Windows, Git Bash
bash /d/Dev_Skills/WSL-PWSH-9P-Errors/scripts/wt.sh <command> ...
```

```bat
:: Linux, from cmd.exe over SSH
wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc "git -C ~/Dev_Skills pull -q --ff-only && bash ~/Dev_Skills/WSL-PWSH-9P-Errors/scripts/wt.sh <command> ..."
```

| Command | Effect |
|---|---|
| `line <branch>` | `wt/<branch>` at `origin/v2/<branch>`; adds it, or moves an existing clean one in place to the new commit |
| `oneshot <ref> <job>` | detached `src/<8hex>-<job>`; `-` means `origin/v2/main`; refuses if the name exists |
| `target <worktree> <client\|server>` | prints `CARGO_TARGET_DIR` for that worktree's Cargo workspace |
| `rm <worktree>` | removes the worktree and its target directories |
| `prune [--job J] [--older-than H] [--yes]` | lists one-shot worktrees; removes the matching ones only with `--yes` |
| `fetch`, `check`, `delbranch` | fetch with prune; preflight (section 9); delete a `v2/test/...` branch (section 6) |

- A live line stays until the line merges, then `wt.sh rm <line>`. A one-shot is removed when its test ends, in the same job.
- `<job>` names the work (`c2t15`, `s1t5-audit`), so two jobs on the same commit never share a directory and `prune --job` touches only yours. Never `prune --yes` without `--job` or `--older-than` while other jobs may be running.
- Build inside the worktree's project tree (`rust/client`, `go/...`), not at a Windows path of a Linux tree or the other way round.

## 5. Rust and Go caches

- Rust: one `CARGO_TARGET_DIR` per Cargo workspace that is being built, chosen by who builds and for how long. It lives and dies with its worktree. Not per drive, not per commit hash.
  - `export CARGO_TARGET_DIR="$(bash .../wt.sh target <worktree> client)"` before `cargo` (Windows `O:\WinCache\target\<wt|src>-<name>-<client|server>`, Linux `~/.cache/target/...`).
  - A live line moves in place with `git checkout`; changed files get the current time, so cargo rebuilds what changed. The 2026-10-18 false `Fresh` came from `git archive` keeping commit times, which this flow no longer uses.
  - Never set `CARGO_TARGET_DIR` globally. Two Cargo workspaces never share one target.
- Go: one pool per side. Windows `GOCACHE=O:\WinCache\go-build`, `GOMODCACHE=O:\WinCache\go-mod` (user environment). Linux `~/.cache/go-build`, `~/.cache/go-mod` (`~/.serein-env`, `GOTOOLCHAIN=local`).
- Windows `CARGO_HOME=O:\WinCache\cargo`, `TEMP`/`TMP`/`GOTMPDIR=O:\WinCache\tmp`. Linux `CARGO_HOME=~/.cargo`.

## 6. Test branches

1. Dev machine: commit, then `git push github <commit>:refs/heads/v2/test/<topic>-<yyyymmdd>`.
2. Each side: `wt.sh oneshot origin/v2/test/<topic>-<yyyymmdd> <job>`, build, test, record the source line.
3. Each side: `wt.sh rm <8hex>-<job>`.
4. One side (or the dev machine with `git push github --delete v2/test/<topic>-<yyyymmdd>`): `wt.sh delbranch v2/test/<topic>-<yyyymmdd>`. It refuses anything outside `v2/test/`.
5. The other side: `wt.sh fetch`, and check that `origin/v2/test/<topic>-<yyyymmdd>` is gone.

A test is not finished while its branch or one-shot worktree still exists.

## 7. Long jobs

The SSH tool stops a call after 10 minutes. A process left running inside WSL dies when the distro idles out about a minute after the last wsl.exe exits, and `/tmp` (tmpfs) is wiped with it.

```bash
# Windows, Git Bash: start and return at once
bash /d/Dev_Skills/WSL-PWSH-9P-Errors/scripts/bg.sh linux s1t5-build 'cd ~/src/75b0e120-s1t5 && . ~/.serein-env && go test ./go/server/...'
bash /d/Dev_Skills/WSL-PWSH-9P-Errors/scripts/bg.sh win c2-check 'cd /o/Serein/wt/client-core/rust/client && cargo check'
```

- Logs: `/home/SR/logs/<name>.log` (ext4) and `O:\WinCache\logs\<name>.log`. Read them on their own side (`tail`, counts); they are not copied across.
- Judge the next check from the measured rate, not a fixed short interval.

## 8. Forbidden

- `/mnt/<letter>`, `\\wsl$`, `\\wsl.localhost` as source, target, cache, or cwd; `mount -t drvfs`; automount=true; `WSLENV=.../p`
- Copying trees, caches, keys, or scripts between Windows and WSL2 in either direction, including piping a file into wsl.exe (`Get-Content x | wsl ...`, `fed.sh` style)
- `wsl ... -- bash -c` with variables; unquoted `wsl ~` in pwsh; `--cd ~` unquoted in Git Bash
- `fedoraremix`, `Fedora43`, `-u ARYYDS`, `/home/ARYYDS`
- A global `CARGO_TARGET_DIR`; two Cargo workspaces sharing one target
- Leaving a test branch or a one-shot worktree after the test
- The retired paths `D:\Workspace\Serein ARC`, `fed.sh`, `run-locked.sh`, `O:\Serein ARC` (a robocopy, not a workspace)

## 9. Preflight

```bat
"C:\Program Files\Git\bin\bash.exe" -lc "bash /d/Dev_Skills/WSL-PWSH-9P-Errors/scripts/wt.sh check"
wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc "bash ~/Dev_Skills/WSL-PWSH-9P-Errors/scripts/wt.sh check"
```

Every line must be `OK_...`. A `FAIL_...` line names what to fix before building.
