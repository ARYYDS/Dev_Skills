@echo off
pwsh -NoProfile -File "%~dp0apply-host.ps1"
if errorlevel 1 exit /b 1
echo Restart Grok Desktop (including tray) and open a new terminal.
