#!/usr/bin/env python3
"""PreToolUse guard for Serein builds and tests on Win11 (Dev_Skills/claude/hooks/serein-build-guard.py).

Claude Code runs it before Bash, PowerShell and mcp__USGL__exec calls (see claude/settings.hooks.json).
For a command that targets Win11 (the Win11 SSH server, or a local command that calls wsl.exe):
  - the first matching call per session/agent gets extra context: load /serein-optane-wsl, plus the red lines;
  - a red-line violation is denied with the reason and the right form.
Anything else: no output, exit 0. A bug in this script never blocks a tool call.

Self-test: python -I serein-build-guard.py --self-test
"""
import hashlib
import json
import os
import re
import sys
import tempfile

WIN11_SERVER_IDS = {
    s.strip()
    for s in os.environ.get("SEREIN_WIN11_SERVER_IDS", "3752dc88-f99a-4cef-9de0-083602fdd77a").split(",")
    if s.strip()
}

WSL_CALL = r"(?<![\w.-])wsl(?:\.exe)?(?=\s)"
# A local command only targets WSL when wsl/wsl.exe sits in command position (start of a line or after ; & | ( ),
# so commit messages, heredocs and greps that merely mention these words are left alone.
LOCAL_WSL_AT_CMD = re.compile(r"(?:^|[\n;&|(]\s*)(?:&\s*)?(?:['\"]?[\w:\\/. -]*[\\/])?wsl(?:\.exe)?['\"]?\s", re.I)
WIN11_MARKERS = re.compile(
    WSL_CALL + r"|FedoraLinux-43|DESKTOP-C4JG869|100\.92\.71\.18|[Oo]:[\\/]Serein|/o/Serein", re.I
)
BUILD_WORDS = re.compile(
    WSL_CALL + r"|\b(?:cargo|rustc|go\s+(?:build|test|vet|run|generate|mod)|git\s+(?:worktree|fetch|clone|push)"
    r"|make|cmake|npm|pnpm|wt\.sh|bg\.sh|Build-Client\.ps1|build-server\.sh|gen-proto\.sh|check-boundaries\.sh)\b",
    re.I,
)

REMINDER = (
    "Win11 Serein build/test context. If the skill /serein-optane-wsl is not loaded in this conversation, "
    "load it with the Skill tool before going on. Red lines: "
    "(1) Windows work on O:\\Serein in Git Bash; Linux work on P: as FedoraLinux-43 user SR. "
    "(2) Source only through GitHub: each side runs git fetch in its own repo; never /mnt/<letter>, \\\\wsl$, "
    "or a file piped into wsl.exe; retired: D:\\Workspace\\Serein ARC, fed.sh, run-locked.sh. "
    "(3) wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc '...', never '--'; from Git Bash export "
    "MSYS_NO_PATHCONV=1 and write --cd '~'. "
    "(4) Rust: one CARGO_TARGET_DIR per Cargo workspace being built (wt.sh target), never global; Go: one pool per side. "
    "(5) Delete one-shot worktrees (wt.sh rm) and v2/test/* branches (wt.sh delbranch) when the test ends. "
    "(6) Jobs over 10 minutes: scripts/bg.sh, then read the log on its own side."
)


def _wsl_segments(cmd):
    """Yield the text from each wsl/wsl.exe invocation to the end of its line."""
    for m in re.finditer(WSL_CALL, cmd, re.I):
        end = cmd.find("\n", m.end())
        yield cmd[m.end(): end if end >= 0 else len(cmd)]


def red_line(cmd):
    """Return a deny reason, or None."""
    for seg in _wsl_segments(cmd):
        head = re.split(r"\s(?:ba)?sh\s+-l?c\b", seg, maxsplit=1)
        runs_shell = len(head) == 2
        uses_exec = re.search(r"(?:^|\s)(?:--exec|-e)(?=\s|$)", head[0]) is not None
        if runs_shell and not uses_exec and "$" in head[1]:
            return ("wsl.exe without --exec runs the line through the default shell first, so variables the script "
                    "assigns are expanded to empty before it uses them (measured X=[] vs X=[abc]). "
                    "Use: wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc '<script>'.")
        if re.search(r"(?:-d|--distribution)\s+['\"]?(?:fedoraremix|Fedora43)\b", seg, re.I):
            return "fedoraremix and Fedora43 are retired. Linux work runs on FedoraLinux-43 as SR."
        if re.search(r"(?:-u|--user)\s+['\"]?ARYYDS\b", seg):
            return "ARYYDS is nologin on FedoraLinux-43. Use -u SR."
    if re.search(r"(?<![\w/.])/mnt/[A-Za-z](?=[/\s'\"`;:)|]|$)", cmd):
        return ("/mnt/<letter> is 9P into Windows drives. Nothing moves between Windows and WSL2; "
                "each side fetches from GitHub into its own filesystem.")
    if re.search(r"(?:\\\\|//)wsl(?:\$|\.localhost)", cmd, re.I):
        return ("\\\\wsl$ / \\\\wsl.localhost is 9P into the Linux disk. Nothing moves between Windows and WSL2; "
                "each side fetches from GitHub into its own filesystem.")
    if re.search(r"\|\s*&?\s*(?:[\w:\\/. -]*[\\/])?wsl(?:\.exe)?\b", cmd, re.I):
        return ("Piping a file or script into wsl.exe moves a file from Windows into WSL2, which is forbidden. "
                "Put the script in a repository and run the side's own fetched copy, or pass a one-line command as argv.")
    if re.search(r"(?<![\w-])(?:fed\.sh['\"]?\s+(?:--exclusive\s+)?(?:run|put|exec|get)|run-locked\.sh['\"]?\s+\S)", cmd):
        return ("fed.sh and run-locked.sh belong to the retired D:\\Workspace flow. "
                "Use Dev_Skills scripts/wt.sh on the side that builds.")
    for m in re.finditer(r"bash(?:\.exe)?['\"]?\s+-l?c\s+(\"[^\"]*\"|'[^']*')", cmd, re.I):
        script = m.group(1)
        if re.search(WSL_CALL + r".*--cd\s+~(?!['\"])", script, re.I | re.S):
            return ("Inside Git Bash an unquoted ~ becomes C:/Users/ARYYDS before wsl.exe sees it. "
                    "Write --cd '~' and export MSYS_NO_PATHCONV=1.")
    if re.search(r"setx\s+CARGO_TARGET_DIR|SetEnvironmentVariable\(\s*['\"]CARGO_TARGET_DIR['\"]\s*,\s*['\"]", cmd, re.I):
        return "A global CARGO_TARGET_DIR is forbidden. Use one per building Cargo workspace (wt.sh target)."
    return None


HEREDOC = re.compile(r"<<-?[ \t]*(['\"]?)([A-Za-z_][\w]*)\1[^\n]*\n.*?\n[ \t]*\2[ \t]*(?=\n|$)", re.S)


def decide(event):
    """Return the hook's JSON output as a dict, or None for no output."""
    tool = event.get("tool_name") or ""
    tin = event.get("tool_input") or {}
    cmd = tin.get("command")
    if not isinstance(cmd, str) or not cmd:
        return None
    cmd = HEREDOC.sub("<<heredoc", cmd)  # heredoc bodies are data (commit messages, file text), not commands
    if tool.startswith("mcp__") and tool.endswith("__exec"):
        if tin.get("serverId") not in WIN11_SERVER_IDS:
            return None
    elif tool in ("Bash", "PowerShell"):
        if not LOCAL_WSL_AT_CMD.search(cmd):
            return None
    else:
        return None
    reason = red_line(cmd)
    if reason:
        return {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                       "permissionDecisionReason": "serein-build-guard: " + reason}}
    if not BUILD_WORDS.search(cmd):
        return None
    key = "-".join(re.sub(r"[^A-Za-z0-9]", "", str(event.get(k) or "")) for k in ("session_id", "agent_id"))
    key = key + "-" + hashlib.sha1(str(event.get("transcript_path") or "").encode("utf-8")).hexdigest()[:10]
    marker_dir = os.path.join(tempfile.gettempdir(), "serein-build-guard")
    marker = os.path.join(marker_dir, key or "nosession")
    if os.path.exists(marker):
        return None
    try:
        os.makedirs(marker_dir, exist_ok=True)
        with open(marker, "w", encoding="ascii") as f:
            f.write("1")
    except OSError:
        pass
    return {"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": REMINDER}}


def self_test():
    w = "3752dc88-f99a-4cef-9de0-083602fdd77a"
    cases = [
        ("mcp__USGL__exec", {"serverId": w, "command": "wsl.exe -d FedoraLinux-43 -u SR -- bash -lc 'C=$(git rev-parse HEAD); echo $C'"}, "deny"),
        ("mcp__USGL__exec", {"serverId": w, "command": "wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc \"C=$(git -C ~/repo.git rev-parse HEAD); echo $C\""}, "ctx"),
        ("mcp__USGL__exec", {"serverId": w, "command": "wsl -d fedoraremix --exec ls"}, "deny"),
        ("mcp__USGL__exec", {"serverId": w, "command": "wsl.exe -d FedoraLinux-43 -u ARYYDS --exec id"}, "deny"),
        ("mcp__USGL__exec", {"serverId": w, "command": "robocopy D:\\x \\\\wsl$\\FedoraLinux-43\\home\\SR\\x"}, "deny"),
        ("mcp__USGL__exec", {"serverId": w, "command": "wsl.exe -d FedoraLinux-43 -u SR --exec bash -lc 'cp -r /mnt/d/x ~/x'"}, "deny"),
        ("mcp__USGL__exec", {"serverId": w, "command": "wsl.exe -d FedoraLinux-43 -u SR --exec bash -lc \"findmnt -t 9p | grep -E 'aname=drvfs|^/mnt/'\""}, "ctx"),
        ("mcp__USGL__exec", {"serverId": w, "command": "type job.sh | wsl.exe -d FedoraLinux-43 -u SR --exec bash"}, "deny"),
        ("mcp__USGL__exec", {"serverId": w, "command": "\"C:\\Program Files\\Git\\bin\\bash.exe\" \"D:\\Workspace\\Serein ARC\\fedora\\fed.sh\" run x y.sh"}, "deny"),
        ("mcp__USGL__exec", {"serverId": w, "command": "\"C:\\Program Files\\Git\\bin\\bash.exe\" -lc \"wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec pwd\""}, "deny"),
        ("mcp__USGL__exec", {"serverId": w, "command": "\"C:\\Program Files\\Git\\bin\\bash.exe\" -lc \"export MSYS_NO_PATHCONV=1; wsl.exe -d FedoraLinux-43 -u SR --cd '~' --exec pwd\""}, "ctx"),
        ("mcp__USGL__exec", {"serverId": w, "command": "git -C O:\\Serein\\repo.git grep -n 'fed.sh' origin/v2/main -- build"}, "none"),
        ("mcp__USGL__exec", {"serverId": w, "command": "dir O:\\WinCache"}, "none"),
        ("mcp__USGL__exec", {"serverId": w, "command": "\"C:\\Program Files\\Git\\bin\\bash.exe\" -lc \"command -v node\" & wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc \"command -v buf\""}, "ctx"),
        ("mcp__USGL__exec", {"serverId": w, "command": "setx CARGO_TARGET_DIR O:\\x"}, "deny"),
        ("mcp__USGL__exec", {"serverId": "other", "command": "wsl -d fedoraremix -- bash -lc 'X=1; echo $X'"}, "none"),
        ("Bash", {"command": "git -C /c/code/Dev_Skills status"}, "none"),
        ("Bash", {"command": "grep -n 'wsl' notes.md"}, "none"),
        ("Bash", {"command": "git commit -q -F - <<'EOF'\nno /mnt, no \\\\wsl$, FedoraLinux-43 user SR; wsl.exe -d fedoraremix is retired\nEOF"}, "none"),
        ("Bash", {"command": "cd /x && wsl.exe -d FedoraLinux-43 -u SR --cd ~ --exec bash -lc 'cp /mnt/c/a ~/a'"}, "deny"),
        ("PowerShell", {"command": "wsl -d FedoraLinux-43 -u SR -- bash -lc 'X=abc; echo $X'"}, "deny"),
        ("Read", {"file_path": "x"}, "none"),
    ]
    tmp = tempfile.mkdtemp(prefix="sbg-selftest-")
    os.environ["TMP"] = os.environ["TEMP"] = os.environ["TMPDIR"] = tmp
    tempfile.tempdir = tmp
    fails = 0
    for i, (tool, tin, want) in enumerate(cases):
        out = decide({"tool_name": tool, "tool_input": tin, "session_id": "selftest%d" % i})
        got = "none"
        if out:
            hso = out["hookSpecificOutput"]
            got = "deny" if hso.get("permissionDecision") == "deny" else "ctx"
        ok = got == want
        fails += not ok
        print("%s %-4s want=%-4s %s %s" % ("ok  " if ok else "FAIL", got, want, tool, tin.get("command", "")[:70]))
    again = decide({"tool_name": cases[1][0], "tool_input": cases[1][1], "session_id": "selftest1"})
    print("%s second call in the same session adds no context" % ("ok  " if again is None else "FAIL"))
    fails += again is not None
    print("self-test: %d failure(s)" % fails)
    return 1 if fails else 0


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        return self_test()
    try:
        raw = sys.stdin.buffer.read().decode("utf-8", "replace")
        out = decide(json.loads(raw) if raw.strip() else {})
    except Exception:
        return 0
    if out:
        sys.stdout.write(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
