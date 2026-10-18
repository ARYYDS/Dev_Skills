# Dev_Skills

Workstation agent skills: compile/WSL/9P/pwsh rules, plus Windows clipboard repair.

Canonical tree is this repository. On the workstation, Grok / DSH / agents load the same folders through directory junctions.

## Architecture

```
                         github.com/ARYYDS/Dev_Skills
                                      |
                                      v
                              D:\Dev_Skills
                                      |
          +---------------------------+---------------------------+
          |                           |                           |
     INDEX.md                    index.json                   skills
     (human index)               (machine index)                  |
                                                                  |
                    +------------------------+--------------------+
                    |                                             |
           WSL-PWSH-9P-Errors                              clipboard-repair
           YAML name: serein-optane-wsl                    YAML name: clipboard-repair
                    |                                             |
                    |-- SKILL.md  (procedure)                     |-- SKILL.md
                    |-- references/layout.md  (roots)             |-- references/
                    |-- references/9p.md      (9P pits)           `-- scripts/
                    |-- references/pwsh.md    (pwsh $ / CRLF)
                    `-- scripts/prune-linux-src.ps1
                    |
                    v  junctions (same inode tree)
     C:\Users\<you>\.grok\skills\<folder>
     C:\Users\<you>\.dsh\skills\<folder>
     C:\Users\<you>\.agents\skills\<folder>
```

### Compile / fetch path (WSL-PWSH-9P-Errors)

```
  Windows NTFS                         TCP                         Linux ext4
  live git + O: cache                  git fetch                   $HOME  (WSL user)
  cargo / go / TEMP                    GitHub                      wt/  src/  repo.git
         \                               |                                /
          \                              |                               /
           X-------- no /mnt 9p ---------+-------- no \\wsl$ -----------X
           X-------- no robocopy trees --+-------- automount=false -----X
```

| Lane | Where | How source moves |
|---|---|---|
| Windows compile | NTFS cache parent | native `cargo` / `go` |
| Linux compile | WSL2 ext4 | `git fetch` then `git worktree add` |
| One-shot test | `$HOME/src/<8hex>` | detach worktree; `worktree remove` when done |
| Forbidden | `/mnt/<letter>`, `\\wsl$\` | 9P copy/migrate |

### pwsh 7

The command tool parses **before** `wsl.exe` starts. POSIX `$HOME` / `$(...)` must sit in a **single-quoted** PowerShell string, or in an LF file. Quote `wsl '~'`. Strip `\r` before bash. Details: [`WSL-PWSH-9P-Errors/references/pwsh.md`](WSL-PWSH-9P-Errors/references/pwsh.md).

## Skills

| Folder | Slash | Role |
|---|---|---|
| [`WSL-PWSH-9P-Errors`](WSL-PWSH-9P-Errors/SKILL.md) | `/serein-optane-wsl` | Linux compile on FedoraLinux-43; fetch not 9P; parent dirs then worktrees |
| [`clipboard-repair`](clipboard-repair/SKILL.md) | `/clipboard-repair` | Windows clipboard CJK mojibake (`CF_UNICODETEXT`) |

Human index: [`INDEX.md`](INDEX.md). JSON: [`index.json`](index.json).

## Install

Copy or junction a skill folder into the client skills root so the directory name matches the folder here:

```text
%USERPROFILE%\.grok\skills\WSL-PWSH-9P-Errors
%USERPROFILE%\.dsh\skills\WSL-PWSH-9P-Errors
```

Grok / DSH / Claude load `SKILL.md` YAML `name` + `description` first, then the body on trigger.
