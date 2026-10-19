# Dev_Skills

Workstation agent skills for Serein on Win11 (DESKTOP-C4JG869): the O:/P: compile workflow, plus Windows clipboard repair, plus the Claude Code hook that enforces the workflow.

This repository is the canonical tree. Only the dev machine (`C:\code\Dev_Skills`) pushes. Win11 keeps two pull-only copies, one per side, and nothing is copied between them.

## Architecture

```
                         github.com/ARYYDS/Dev_Skills
              push |              | pull --ff-only          | pull --ff-only
                   |              v                         v
  dev machine C:\code\Dev_Skills   Win11 Windows D:\Dev_Skills   Win11 Linux (SR) ~/Dev_Skills
   |-- junction ~/.claude/skills/serein-optane-wsl    |-- junctions:                 `-- scripts run natively
   `-- ~/.claude/settings.json PreToolUse hook         |   %USERPROFILE%\.grok\skills\<name>
                                                       |   %USERPROFILE%\.dsh\skills\serein-optane-wsl
                                                       |   %USERPROFILE%\.agents\skills\serein-optane-wsl
                                                       `-- scripts run natively in Git Bash
```

### Serein source path (WSL-PWSH-9P-Errors)

```
        github.com/ARYYDS/Serein-ARC (private)
         ^ fetch / push v2/test/*          ^ fetch / push v2/test/*
         |  own deploy key                 |  own deploy key (made inside ext4)
  O: OptaneWin (Windows, Git Bash)     P: OptaneWSL -> FedoraLinux-43 ext4, user SR
  O:\Serein\repo.git                   ~/repo.git
  O:\Serein\wt\<line>                  ~/wt/<line>
  O:\Serein\src\<8hex>-<job>           ~/src/<8hex>-<job>
  O:\WinCache\{target,go-build,...}    ~/.cache/{target,go-build,...}
         X------ no /mnt, no \\wsl$, no files piped into wsl.exe ------X
```

| Lane | Where | How source moves |
|---|---|---|
| Windows compile and product tests | `O:\Serein\wt` or `src` | `git fetch` into `O:\Serein\repo.git`, then `scripts/wt.sh` |
| Linux compile and tests | `~/wt` or `~/src` on ext4 | `git fetch` into `~/repo.git`, then `scripts/wt.sh` |
| One-shot test | `src/<8hex>-<job>` on each side | `wt.sh oneshot`; `wt.sh rm` when the test ends |
| Test branch | `v2/test/<topic>-<yyyymmdd>` | pushed for the test, `wt.sh delbranch` when it ends |
| Forbidden | `/mnt/<letter>`, `\\wsl$`, stdin into wsl.exe | any copy between Windows and WSL2 |

### Shells

Call WSL as `wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc '...'`; never `--`, which expands `$VAR` before the script assigns it. pwsh, cmd.exe over SSH and Git Bash each eat different characters first: [`WSL-PWSH-9P-Errors/references/pwsh.md`](WSL-PWSH-9P-Errors/references/pwsh.md).

## Skills

| Folder | Slash | Role |
|---|---|---|
| [`WSL-PWSH-9P-Errors`](WSL-PWSH-9P-Errors/SKILL.md) | `/serein-optane-wsl` | Serein compile and test on O: (Windows) and P: (FedoraLinux-43, SR); GitHub fetch only; worktrees; test branches; long jobs |
| [`clipboard-repair`](clipboard-repair/SKILL.md) | `/clipboard-repair` | Windows clipboard CJK mojibake (`CF_UNICODETEXT`); Grok-specific, not installed into Claude |
| [`claude`](claude/README.md) | - | Claude Code skill junction and the `serein-build-guard` PreToolUse hook |

Human index: [`INDEX.md`](INDEX.md). JSON: [`index.json`](index.json).

## Install

The slash name is the directory name in the client's skills root, so the junction is named after the slash, not the folder:

```bat
:: Win11 (Grok / DSH / agents), target D:\Dev_Skills
mklink /J "%USERPROFILE%\.grok\skills\serein-optane-wsl" "D:\Dev_Skills\WSL-PWSH-9P-Errors"
:: dev machine (Claude Code), target C:\code\Dev_Skills
mklink /J "%USERPROFILE%\.claude\skills\serein-optane-wsl" "C:\code\Dev_Skills\WSL-PWSH-9P-Errors"
```

Claude reads `name`, `description` and `when_to_use`; Grok and DSH read `when-to-use` / `whenToUse`. Both spellings are kept in the frontmatter.
