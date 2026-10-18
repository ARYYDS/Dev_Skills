# clipboard-repair: UTF-8 pipes + Unicode clipboard helpers. Does not change ACP.
$script:Utf8NoBom = [Text.UTF8Encoding]::new($false)
try {
    [Console]::InputEncoding = $script:Utf8NoBom
    [Console]::OutputEncoding = $script:Utf8NoBom
    $OutputEncoding = $script:Utf8NoBom
} catch {
}

function Copy-UnicodeText {
    param(
        [Parameter(ValueFromPipeline)]
        [string]$Text
    )
    begin { $script:CopyUnicodeBuf = New-Object System.Collections.Generic.List[string] }
    process { if ($null -ne $Text) { [void]$script:CopyUnicodeBuf.Add($Text) } }
    end {
        $joined = [string]::Join([Environment]::NewLine, $script:CopyUnicodeBuf)
        Set-Clipboard -Value $joined
    }
}

function Repair-ClipboardMojibake {
    $repair = Join-Path $env:USERPROFILE '.grok\bin\repair-clipboard.ps1'
    if (-not (Test-Path -LiteralPath $repair)) {
        Write-Error "missing $repair — run apply-host.ps1"
        return
    }
    & $repair
}
