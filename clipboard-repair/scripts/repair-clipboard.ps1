# Repair clipboard text stored as 8-bit bytes widened to Latin-1/CP1252.
# Win+V examples: ±¾µØ… (GBK) or æœ¬åœ°… (UTF-8).
$raw = Get-Clipboard -Raw -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($raw)) {
    Write-Output 'clipboard empty'
    exit 1
}

function Test-HasCjk([string]$s) {
    return [regex]::IsMatch($s, '[\u3400-\u9FFF\uF900-\uFAFF]')
}

function Test-HasLatin1Mojibake([string]$s) {
    $n = ([regex]::Matches($s, '[\u00A0-\u00FF]')).Count
    return ($n -ge 2)
}

if (-not (Test-HasLatin1Mojibake $raw)) {
    Write-Output 'clipboard already looks like Unicode text; left unchanged'
    exit 0
}

$latin = [Text.Encoding]::GetEncoding(28591)
$bytes = $latin.GetBytes($raw)
$asGbk = [Text.Encoding]::GetEncoding(936).GetString($bytes)
$asUtf8 = [Text.UTF8Encoding]::new($false).GetString($bytes)

$pick = $null
if ((Test-HasCjk $asGbk) -and -not (Test-HasCjk $raw)) { $pick = $asGbk }
elseif ((Test-HasCjk $asUtf8) -and -not (Test-HasCjk $raw)) { $pick = $asUtf8 }

if ($null -eq $pick) {
    Write-Output 'could not recover CJK from Latin-1 shell; left unchanged'
    exit 2
}

Set-Clipboard -Value $pick
Write-Output 'repaired clipboard to Unicode CJK'
