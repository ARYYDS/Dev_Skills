# pwsh 7 pitfalls (this skill)

The command tool is PowerShell 7. It parses the line **before** `wsl.exe` or Git Bash starts. Most failed Linux compiles here are quoting, not the compiler.

The host-wide rule is `~/.grok/rules/02-windows-shell-contract.md`. This file is the subset that breaks Serein WSL jobs.

## One parser

| Job | Layer | Invocation |
|---|---|---|
| Linux compile / git fetch / worktree | WSL | `wsl -d FedoraLinux-43 -u SR -- bash -lc '...'` |
| Long POSIX body | file then WSL | UTF-8 no BOM, LF, then `wsl ... bash /tmp/job.sh` |
| Git on `D:\` / `C:\` | Git Bash | `& 'C:\Program Files\Git\bin\bash.exe' -lc '...'` |
| Env, disks, `wsl.exe` control | pwsh | cmdlets, `-LiteralPath` |

Do not nest `pwsh -Command` around bash around `wsl`. Do not type bare `bash` (`C:\Windows\System32\bash.exe` is the WSL launcher, not Git Bash).

Microsoft's `wsl ~` (start in Linux `$HOME`) is for CMD. In pwsh 7, unquoted `~` is `C:\Users\ARYYDS`. Measured: `wsl ~ -d FedoraLinux-43` becomes `wsl C:\Users\ARYYDS ...` and Linux prints `C:UsersARYYDS: command not found`. Use `wsl '~' -d FedoraLinux-43 -u SR -- bash -lc '...'`.

## `$` is eaten in double quotes

pwsh expands `$HOME`, `$PWD`, `$C`, `$FULL`, `$_`, `$?`, `$(git ...)` inside `"..."` before Linux sees the string.

```powershell
# wrong: Linux gets HOME=C:UsersARYYDS or empty
wsl -d FedoraLinux-43 -u SR -- bash -lc "echo HOME=$HOME GOCACHE=$GOCACHE"

# right: POSIX $ stays
wsl -d FedoraLinux-43 -u SR -- bash -lc 'echo HOME=$HOME GOCACHE=$GOCACHE'

# right: pwsh fills only the Windows path, Linux keeps $HOME
$wt = '/home/SR/src/84e2550a'
wsl -d FedoraLinux-43 -u SR -- bash -lc "cd '$wt' && . ~/.serein-env && pwd"
```

`&&` and `|` inside a **double-quoted** `wsl ... "..."` string are also pwsh operators. Put the whole Linux script in **single quotes**, or in a file.

## CRLF

A here-string or `Get-Content` piped into `wsl` often has `\r`. Linux then reports `$'\r': command not found` or `bash\r`.

```powershell
$script = Get-Content -Raw -LiteralPath $env:TEMP\agent-job.sh
$script = $script -replace "`r`n","`n" -replace "`r","`n"
$script | & wsl.exe -d FedoraLinux-43 -u SR -- bash -lc 'tr -d "\r" > /tmp/job.sh && bash /tmp/job.sh'
```

Write the job with the harness `Write` tool (still strip CR on the way in). Do not `Set-Content` a Linux script without `-NoNewline` awareness; prefer piping through `tr -d '\r'`.

## cwd leak

`wsl.exe` can inherit the PowerShell working directory. From `D:\Serein ARC` that becomes `/mnt/d/...` **if** automount is on. Automount is off on FedoraLinux-43, so the cwd may be `$HOME` or an empty `/mnt/d` dir. Always `cd` inside the Linux script:

```powershell
wsl -d FedoraLinux-43 -u SR -- bash -lc 'cd "$HOME" && . ~/.serein-env && pwd'
```

## Spaces and Windows paths

`'D:\Serein ARC'` is one pwsh argv. Do not pass that path into Linux as a compile root (9P). WSL argv after `--` is a **Linux** path (`/home/SR/...`).

## Checklist (every WSL compile)

1. Distro and user written: `wsl '~' -d FedoraLinux-43 -u SR` (quote the tilde)
2. Linux script in pwsh **single quotes**, or a LF file
3. `. ~/.serein-env` after `cd` to the worktree
4. No `$HOME` / `$C` in pwsh double quotes unless you mean pwsh to expand them
5. CR stripped
6. `pwd` is not `/mnt/...`
