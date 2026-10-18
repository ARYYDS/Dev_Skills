# Read stdin as UTF-8 (no BOM) and write CF_UNICODETEXT via Set-Clipboard.
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
$text = [Console]::In.ReadToEnd()
if ($null -eq $text) { $text = '' }
Set-Clipboard -Value $text
