# User-level Unicode clipboard host setup. Does not change HKLM ACP/OEMCP.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$bin = Join-Path $env:USERPROFILE '.grok\bin'
New-Item -ItemType Directory -Force -Path $bin | Out-Null

foreach ($name in @('copy-unicode.ps1', 'copy-unicode.cmd', 'repair-clipboard.ps1', 'apply-host.ps1', 'apply-env.cmd', 'profile-snippet.ps1')) {
    $src = Join-Path $here $name
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $bin $name) -Force
    }
}

# copy-unicode.cmd in ~/.grok/bin must call the bin copy of the ps1
$cmd = @"
@echo off
pwsh -NoProfile -File "%USERPROFILE%\.grok\bin\copy-unicode.ps1"
"@
Set-Content -LiteralPath (Join-Path $bin 'copy-unicode.cmd') -Value $cmd -Encoding Ascii

[Environment]::SetEnvironmentVariable('GROK_CLIPBOARD_NO_OSC52', '1', 'User')
$env:GROK_CLIPBOARD_NO_OSC52 = '1'

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ([string]::IsNullOrEmpty($userPath)) { $userPath = '' }
if ($userPath -notlike ('*{0}*' -f $bin)) {
    $newPath = if ($userPath.Trim().Length -eq 0) { $bin } else { "$bin;$userPath" }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
}
if ($env:Path -notlike ('*{0}*' -f $bin)) {
    $env:Path = "$bin;$env:Path"
}

try {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
} catch {
    Write-Output "execution policy: $($_.Exception.Message)"
}

$marker = 'clipboard-repair: UTF-8 pipes'
$snippet = Get-Content -LiteralPath (Join-Path $here 'profile-snippet.ps1') -Raw
$profiles = @(
    (Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $HOME 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
)
foreach ($p in $profiles) {
    $dir = Split-Path -Parent $p
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if (Test-Path -LiteralPath $p) {
        $cur = Get-Content -LiteralPath $p -Raw
        if ($cur -notlike "*$marker*") {
            Add-Content -LiteralPath $p -Value "`r`n$snippet" -Encoding utf8
        }
    } else {
        Set-Content -LiteralPath $p -Value $snippet -Encoding utf8
    }
}

$probe = "本地控制协议"
Set-Clipboard -Value $probe
Start-Sleep -Milliseconds 200
$got = Get-Clipboard -Raw
$ok = ($got -eq $probe)

$gbkBytes = [Text.Encoding]::GetEncoding(936).GetBytes($probe)
$mojibake = [Text.Encoding]::GetEncoding(28591).GetString($gbkBytes)
Set-Clipboard -Value $mojibake
& (Join-Path $bin 'repair-clipboard.ps1')
$repaired = Get-Clipboard -Raw
$repairOk = ($repaired -eq $probe)
Set-Clipboard -Value $probe

$cp = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage'
Write-Output "ACP=$($cp.ACP) OEMCP=$($cp.OEMCP) (unchanged)"
Write-Output "GROK_CLIPBOARD_NO_OSC52=$([Environment]::GetEnvironmentVariable('GROK_CLIPBOARD_NO_OSC52','User'))"
Write-Output "Set-Clipboard Unicode roundtrip ok=$ok"
Write-Output "Repair GBK-as-Latin1 ok=$repairOk"
Write-Output "bin=$bin"
if (-not $ok) { exit 3 }
if (-not $repairOk) { exit 4 }
