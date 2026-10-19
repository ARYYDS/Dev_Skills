#!/usr/bin/env bash
# bg.sh <linux|win> <name> <command...>   Run from Git Bash on Win11 (the Windows side).
# Start a long job that outlives this SSH call and its 10-minute exec cap, and return at once.
#
#   linux  the command runs as SR on FedoraLinux-43, cwd ~, log /home/SR/logs/<name>.log (ext4)
#   win    the command runs in Git Bash, cwd O:\Serein, log O:\WinCache\logs\<name>.log
#
# Why it looks like this (measured 2026-10-18):
#   - A process started in the background inside WSL dies when the distro idles out, about a minute after
#     the last wsl.exe exits. A hidden wsl.exe started with Start-Process keeps the distro alive until the job ends.
#   - "nohup ... &" from an SSH session keeps the SSH call open until its timeout; Start-Process does not.
#   - The command travels as base64 text in argv and is decoded on the side that runs it.
#     No file crosses between Windows and WSL2.
# Read a Linux log:  MSYS_NO_PATHCONV=1 wsl.exe -d FedoraLinux-43 -u SR --cd '~' --exec tail -n 40 /home/SR/logs/<name>.log
# Read a Windows log: tail -n 40 /o/WinCache/logs/<name>.log
set -euo pipefail
[ $# -ge 3 ] || { sed -n '2,16p' "$0"; exit 2; }
case "$(uname -s)" in MINGW*|MSYS*) ;; *) echo "bg.sh runs on the Windows side only" >&2; exit 2;; esac
side=$1
name=$(printf '%s' "$2" | tr -cd 'A-Za-z0-9._-')
[ -n "$name" ] || { echo "empty job name" >&2; exit 2; }
shift 2
b64=$(printf '%s' "$*" | base64 -w0)
case "$side" in
  linux)
    inner="mkdir -p ~/logs; { echo start \$(date -Is); printf %s $b64 | base64 -d | bash -l; echo exit=\$? end \$(date -Is); } > ~/logs/$name.log 2>&1"
    ps="Start-Process -WindowStyle Hidden -FilePath wsl.exe -ArgumentList '-d FedoraLinux-43 -u SR --cd ~ --exec bash -lc \"$inner\"'"
    log=/home/SR/logs/$name.log
    ;;
  win)
    mkdir -p /o/WinCache/logs
    inner="cd /o/Serein; { echo start \$(date -Is); printf %s $b64 | base64 -d | bash -l; echo exit=\$? end \$(date -Is); } > /o/WinCache/logs/$name.log 2>&1"
    ps="Start-Process -WindowStyle Hidden -FilePath 'C:\\Program Files\\Git\\bin\\bash.exe' -ArgumentList '-lc \"$inner\"'"
    log='O:\WinCache\logs\'"$name.log"
    ;;
  *) echo "side must be linux or win" >&2; exit 2 ;;
esac
pwsh -NoProfile -NonInteractive -EncodedCommand "$(printf '%s' "$ps" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)"
echo "started $side job $name; log $log"
