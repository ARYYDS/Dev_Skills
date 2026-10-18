# Dev_Skills index

Canonical skill tree. Edit files here. Grok / DSH / agents see the same folders through junctions.

Machine-readable copy: [`index.json`](index.json).

## Discovery

| Client | Path | Kind |
|---|---|---|
| Grok | `C:\Users\ARYYDS\.grok\skills\<name>` | junction → `D:\Dev_Skills\<name>` |
| DSH | `C:\Users\ARYYDS\.dsh\skills\<name>` | junction (`WSL-PWSH-9P-Errors`) |
| agents | `C:\Users\ARYYDS\.agents\skills\<name>` | junction (`WSL-PWSH-9P-Errors`) |

`reverse-engineer-anything` stays under `C:\Users\ARYYDS\.agents\skills\` (REA pack, not copied here).

## Skills

| Name | Slash | Files | Bytes | Role |
|---|---|---:|---:|---|
| [WSL-PWSH-9P-Errors](WSL-PWSH-9P-Errors/SKILL.md) | `/serein-optane-wsl` | 5 | 21807 | Serein compile on FedoraLinux-43 user SR; git fetch not 9P; pwsh quoting |
| [clipboard-repair](clipboard-repair/SKILL.md) | `/clipboard-repair` | 8 | 13776 | Windows clipboard CJK mojibake |

## Trees

```
D:\Dev_Skills\
|-- INDEX.md
|-- index.json
|-- WSL-PWSH-9P-Errors\
|   |-- SKILL.md
|   |-- references\
|   |   |-- 9p.md
|   |   |-- layout.md
|   |   `-- pwsh.md
|   `-- scripts\
|       `-- prune-linux-src.ps1
`-- clipboard-repair\
    |-- SKILL.md
    |-- references\
    |   `-- windows-clipboard-encoding.md
    `-- scripts\
        |-- apply-env.cmd
        |-- apply-host.ps1
        |-- copy-unicode.cmd
        |-- copy-unicode.ps1
        |-- profile-snippet.ps1
        `-- repair-clipboard.ps1
```

## serein-optane-wsl files

| Path | Lines | Bytes |
|---|---:|---:|
| `SKILL.md` | 170 | 8790 |
| `references/9p.md` | 111 | 6619 |
| `references/layout.md` | 57 | 2316 |
| `references/pwsh.md` | 69 | 3295 |
| `scripts/prune-linux-src.ps1` | 26 | 787 |

## clipboard-repair files

| Path | Lines | Bytes |
|---|---:|---:|
| `SKILL.md` | 91 | 4669 |
| `references/windows-clipboard-encoding.md` | 61 | 3395 |
| `scripts/apply-host.ps1` | 80 | 3113 |
| `scripts/repair-clipboard.ps1` | 38 | 1199 |
| `scripts/profile-snippet.ps1` | 30 | 964 |
| `scripts/copy-unicode.ps1` | 5 | 232 |
| `scripts/apply-env.cmd` | 4 | 148 |
| `scripts/copy-unicode.cmd` | 2 | 56 |
