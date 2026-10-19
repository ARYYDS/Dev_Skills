# Shell quoting: pwsh 7, cmd.exe over SSH, Git Bash, and wsl.exe itself

Most failed Linux jobs here are quoting, not the compiler. Up to four parsers can touch one command line before bash runs it. Grok and DSH on Win11 type into pwsh 7. A remote agent over the Win11 SSH tool types into cmd.exe. Windows-side scripts run in Git Bash. wsl.exe is the last layer, and its `--` form adds a shell of its own. The host-wide rule for Grok is `~/.grok/rules/02-windows-shell-contract.md`; this file is the subset that breaks Serein jobs.

## Layer 0: wsl.exe `--` vs `--exec` (all shells)

`wsl.exe ... -- <cmd>` and `wsl.exe ... <cmd>` give the command line to the distro's default shell first (`$SHELL -c '<line>'`). That shell expands `$VAR`, `$(...)`, `~` and globs once, before your `bash -lc` script runs, so variables your script assigns are already empty when it uses them.

```text
measured 2026-10-18, from pwsh 7:
wsl -d FedoraLinux-43 -u SR --   bash -lc 'X=abc && echo "X=[$X]" && C=$(echo hi) && echo "C=[$C]"'   ->  X=[]    C=[]
wsl -d FedoraLinux-43 -u SR --exec bash -lc 'X=abc && echo "X=[$X]" && C=$(echo hi) && echo "C=[$C]"' ->  X=[abc] C=[hi]
```

`$HOME` and `$PWD` look fine under `--` only because the outer shell expands them to the same values. Always write `--cd ~ --exec bash -lc '<script>'`.

## Layer 1a: pwsh 7

| Trap | Wrong | Right |
|---|---|---|
| `$` in double quotes is pwsh's | `wsl ... --exec bash -lc "echo $HOME"` (Linux gets `C:\Users\ARYYDS`) | `wsl ... --exec bash -lc 'echo $HOME'` |
| `&&` and `\|` in double quotes are pwsh operators | `"cd x && make"` | put the whole Linux script in single quotes |
| bare `~` is `C:\Users\ARYYDS` | `wsl ~ -d FedoraLinux-43` (Linux prints `C:UsersARYYDS: command not found`) | `--cd ~` or `--cd '~'` (both give `/home/SR` in pwsh 7.6.6, measured 2026-10-18) |
| `-File` turns `0,1,6` into the number 16 | `pwsh -File x.ps1 -Index 0,1,6` | `pwsh -Command "& .\x.ps1 -Index @(0,1,6)"` |
| bare `bash` | `C:\Windows\System32\bash.exe` is the WSL launcher, not Git Bash | `& 'C:\Program Files\Git\bin\bash.exe' -lc '...'` |

To fill in a Windows-side value while keeping Linux `$`, build the string in pwsh and keep `$` literal: `$wt='/home/SR/src/75b0e120-s1t5'; wsl -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc "cd '$wt' && . ~/.serein-env && pwd"` (here pwsh expands only `$wt`).

## Layer 1b: cmd.exe (the Win11 SSH tool)

| Trap | Right |
|---|---|
| `&`, `\|`, `>` outside double quotes are cmd's | wrap the Linux script in double quotes: `wsl.exe ... --exec bash -lc "a && b \| c > f"` |
| a `"` inside the script ends cmd's quoting; `\"` is not an escape for cmd | use single quotes inside: `bash -lc "echo 'x y'"` |
| `%NAME%` is expanded when NAME is set | avoid `%...%` pairs; `date +%T` alone is safe |
| `~` is literal | `--cd ~` works as written |
| `$` is literal | nothing to do |

For anything longer than one line, run a script from the side's own fetched repo instead of building it in cmd.

## Layer 1c: Git Bash (MSYS)

| Trap | Measured | Right |
|---|---|---|
| `~` is expanded by Git Bash | `--cd ~` became `C:/Users/ARYYDS`; the Linux job never started | `--cd '~'` |
| POSIX-looking arguments are rewritten for native programs | `/home/SR/logs/x.log` reached wsl.exe as `C:/Program Files/Git/home/SR/logs/x.log` | `export MSYS_NO_PATHCONV=1` before calling wsl.exe |
| `nohup wsl.exe ... &` | the SSH call stays open until its timeout | `scripts/bg.sh` (Start-Process, returns at once) |
| CRLF | Git Bash tolerates CRLF scripts; Linux bash does not (`$'\r': command not found`) | the repo has `.gitattributes` with `eol=lf`; Linux reads only its own LF checkout |

## Checklist (every WSL job)

1. `wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc ...`, never `--`
2. Quote the script for the shell you are typing into: pwsh single quotes, cmd double quotes with single quotes inside, Git Bash `MSYS_NO_PATHCONV=1` and `'~'`
3. `cd` to the worktree, then `. ~/.serein-env`
4. Nothing piped into wsl.exe; longer scripts come from the side's own git checkout
5. `pwd` is not `/mnt/...`
