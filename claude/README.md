# Claude Code integration

Claude Code runs on the dev machine (`C:\code`), not on Win11. It drives Win11 over the SSH tool (`mcp__USGL__exec`, server `Win11`, cmd.exe on the far side). Two pieces load this repository into it.

```
C:\code\Dev_Skills  (git clone; pushed to GitHub from here only)
 |-- WSL-PWSH-9P-Errors\ --junction--> %USERPROFILE%\.claude\skills\serein-optane-wsl   (/serein-optane-wsl)
 `-- claude\hooks\serein-build-guard.py <-- %USERPROFILE%\.claude\settings.json  PreToolUse
                                            matcher Bash|PowerShell|mcp__USGL__exec
```

## 1. Skill

The command name is the directory name under `~/.claude/skills`, so the junction is called `serein-optane-wsl`:

```bat
mklink /J "%USERPROFILE%\.claude\skills\serein-optane-wsl" "C:\code\Dev_Skills\WSL-PWSH-9P-Errors"
```

Claude reads `name`, `description` and `when_to_use` from the frontmatter (combined listing text is capped at 1,536 characters). `when-to-use` and `whenToUse` stay for Grok and DSH. `git -C C:\code\Dev_Skills pull --ff-only` updates the skill in place.

## 2. Hook

Merge `settings.hooks.json` into `%USERPROFILE%\.claude\settings.json` (keep the existing hooks). The hook:

- ignores everything that does not target Win11: other SSH servers, and local commands without a `wsl.exe` call or a Win11 path;
- adds context once per session and per subagent on the first Win11 build, test, fetch or WSL command: load `/serein-optane-wsl`, plus the red lines;
- denies the red lines: `wsl` without `--exec` running a script with `$`; `fedoraremix`, `Fedora43`, `-u ARYYDS`; `/mnt/<letter>`; `\\wsl$`; piping into wsl.exe; `fed.sh run|put|exec|get` and `run-locked.sh`; unquoted `--cd ~` inside Git Bash; a global `CARGO_TARGET_DIR`;
- never blocks because of its own bug (any exception: no output, exit 0).

Check it after every change:

```bat
python -I C:\code\Dev_Skills\claude\hooks\serein-build-guard.py --self-test
```

`SEREIN_WIN11_SERVER_IDS` (comma-separated) overrides the Win11 SSH server id if the SSH tool is reconfigured.
