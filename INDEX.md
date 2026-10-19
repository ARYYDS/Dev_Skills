# Dev_Skills index

Canonical skill tree. Edit and push only from the dev machine (`C:\code\Dev_Skills`). Win11 copies pull with `--ff-only`.

Machine-readable copy: [`index.json`](index.json).

## Discovery

| Client | Machine | Path | Kind |
|---|---|---|---|
| Claude Code | dev machine | `C:\Users\Administrator\.claude\skills\serein-optane-wsl` | junction → `C:\code\Dev_Skills\WSL-PWSH-9P-Errors` |
| Claude Code hook | dev machine | `C:\Users\Administrator\.claude\settings.json` PreToolUse | runs `C:\code\Dev_Skills\claude\hooks\serein-build-guard.py` |
| Grok | Win11 | `C:\Users\ARYYDS\.grok\skills\<name>` | junction → `D:\Dev_Skills\<folder>` (`serein-optane-wsl`, `clipboard-repair`) |
| DSH | Win11 | `C:\Users\ARYYDS\.dsh\skills\serein-optane-wsl` | junction → `D:\Dev_Skills\WSL-PWSH-9P-Errors` |
| agents | Win11 | `C:\Users\ARYYDS\.agents\skills\serein-optane-wsl` | junction → `D:\Dev_Skills\WSL-PWSH-9P-Errors` |
| scripts (Linux) | Win11 FedoraLinux-43, SR | `~/Dev_Skills` | git clone, pull only |

`reverse-engineer-anything` stays under `C:\Users\ARYYDS\.agents\skills\` (REA pack, not copied here).

## Skills

| Name | Slash | Files | Bytes | Role |
|---|---|---:|---:|---|
| [WSL-PWSH-9P-Errors](WSL-PWSH-9P-Errors/SKILL.md) | `/serein-optane-wsl` | 6 | 37735 | Serein on Win11: O: Windows, P: FedoraLinux-43 SR; GitHub fetch only; `--exec`; worktrees; test branches; long jobs |
| [clipboard-repair](clipboard-repair/SKILL.md) | `/clipboard-repair` | 8 | 14224 | Windows clipboard CJK mojibake |
| [claude](claude/README.md) | - | 3 | 13925 | Claude Code junction and `serein-build-guard` PreToolUse hook |

## Trees

```
Dev_Skills\
|-- .gitattributes          eol=lf (cmd/bat crlf)
|-- README.md  INDEX.md  index.json
|-- WSL-PWSH-9P-Errors\
|   |-- SKILL.md
|   |-- references\
|   |   |-- 9p.md
|   |   |-- layout.md
|   |   `-- pwsh.md
|   `-- scripts\
|       |-- wt.sh           worktrees, targets, test branches (either side, natively)
|       `-- bg.sh           long jobs (Windows-side launcher)
|-- clipboard-repair\
|   |-- SKILL.md
|   |-- references\
|   |   `-- windows-clipboard-encoding.md
|   `-- scripts\
|       |-- apply-env.cmd
|       |-- apply-host.ps1
|       |-- copy-unicode.cmd
|       |-- copy-unicode.ps1
|       |-- profile-snippet.ps1
|       `-- repair-clipboard.ps1
`-- claude\
    |-- README.md
    |-- settings.hooks.json
    `-- hooks\
        `-- serein-build-guard.py
```

## serein-optane-wsl files

| Path | Lines | Bytes |
|---|---:|---:|
| `SKILL.md` | 148 | 10301 |
| `references/9p.md` | 107 | 7310 |
| `references/layout.md` | 77 | 5378 |
| `references/pwsh.md` | 56 | 4094 |
| `scripts/wt.sh` | 209 | 8300 |
| `scripts/bg.sh` | 39 | 2352 |

## clipboard-repair files

| Path | Lines | Bytes |
|---|---:|---:|
| `SKILL.md` | 94 | 5117 |
| `references/windows-clipboard-encoding.md` | 61 | 3395 |
| `scripts/apply-host.ps1` | 80 | 3113 |
| `scripts/repair-clipboard.ps1` | 38 | 1199 |
| `scripts/profile-snippet.ps1` | 30 | 964 |
| `scripts/copy-unicode.ps1` | 5 | 232 |
| `scripts/apply-env.cmd` | 4 | 148 |
| `scripts/copy-unicode.cmd` | 2 | 56 |

## claude files

| Path | Lines | Bytes |
|---|---:|---:|
| `README.md` | 37 | 2055 |
| `settings.hooks.json` | 16 | 317 |
| `hooks/serein-build-guard.py` | 195 | 11553 |
