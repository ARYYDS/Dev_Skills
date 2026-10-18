# Windows clipboard encoding (Clipboard-Repair)

## Formats

Windows text clipboard is three 8/16-bit formats, no `CF_UTF8TEXT`:

- `CF_UNICODETEXT` — UTF-16LE. Write this.
- `CF_TEXT` — ANSI. Code page from `CF_LOCALE` → `LOCALE_IDEFAULTANSICODEPAGE`.
- `CF_OEMTEXT` — OEM page from the same LCID.

If the writer omits `CF_LOCALE`, the system uses the **current keyboard layout** LCID. US English → ANSI 1252, OEM 437. zh-CN keyboard → ANSI 936.

Clipboard History (Win+V) registers as a format listener and **requests `CF_UNICODETEXT` on every copy**. That forces synthesis and stores the result. A bad 8-bit write becomes a permanent history item of wrong Unicode.

## Why ACP 65001 does not fix this

`GetACP()` / Beta UTF-8 changes process ANSI APIs. Clipboard synthesis uses the locale’s default ANSI page, and **no locale has UTF-8 as that page**. There is no UTF-8 keyboard.

Raymond Chen, *The Old New Thing*, 2025-12-08 … 2025-12-18:

- https://devblogs.microsoft.com/oldnewthing/20251209-00/?p=111854
- https://devblogs.microsoft.com/oldnewthing/20251210-00/?p=111856 (`CF_LOCALE` from keyboard)
- https://devblogs.microsoft.com/oldnewthing/20251216-00/?p=111873 (Clipboard History is the interloper)
- https://devblogs.microsoft.com/oldnewthing/20251217-00/?p=111880 (UTF-8 as ACP vs clipboard)
- https://devblogs.microsoft.com/oldnewthing/20251218-00/?p=111882 (write UTF-16LE `CF_UNICODETEXT`)

Microsoft Learn: per-process `activeCodePage` UTF-8 — https://learn.microsoft.com/en-us/windows/apps/design/globalizing/use-utf8-code-page

## Fingerprint math

`本地控制协议` GBK bytes `B1 BE B5 D8 BF D8 D6 C6 D0 AD D2 E9` read as Latin-1 → `±¾µØ¿ØÖÆÐ­Òé`.

Reverse: Latin-1 getbytes → GBK getstring.

## Community write-path bugs (same class)

| Case | Fingerprint | Write path | Fix they shipped |
|---|---|---|---|
| Claude Code #44331 | UTF-8 as GBK | UTF-8 bytes in `CF_TEXT`, ACP 936 synthesizes Unicode | `Set-Clipboard` UTF-8 |
| Gemini CLI #6904 | CJK garbled `/copy` | `clip.exe` | `Set-Clipboard` |
| mcp-clipboard #129 | `—` → `â€"` | Python UTF-8 stdin → PS `InputEncoding` OEM/1252 | `InputEncoding = UTF8` or Base64 |
| xterm.js #6002 / VS Code #319821 / Cursor | UTF-8 as Latin-1 | OSC 52 `atob()` without UTF-8 decode | `TextDecoder` |
| WSL #4852 / tmux-yank | box-drawing mojibake | `clip.exe` on UTF-8 | `iconv -t utf16le \| clip.exe` or `utf8clip` |
| Grok Bot iOS 2026-10 | `国际` → `å›½é™…` | app Copy button Latin-1 | system Select Text → Copy |
| Far Manager `ClipboardUnicodeWorkaround` | locale mismatch | OS-synthesized Unicode from `CF_TEXT` | reread `CF_TEXT` with right CP |
| pi-coding-agent #2347, Hermes #35107 | `/copy` CJK | native module / PS stdin | Unicode / Base64 PS |

`clip.exe` writes `CF_TEXT` using the console code page; it does not transcode. It also accepts BOM-less UTF-16LE. A UTF-8 BOM is treated as data.

utf8clip: https://github.com/bluemarsh/utf8clip

## Host policy used here

User-level only:

- `GROK_CLIPBOARD_NO_OSC52=1` (env, not `config.toml`)
- PowerShell profile UTF-8 no BOM for stdin/`Set-Clipboard`
- `%USERPROFILE%\.grok\bin\copy-unicode.*` and `repair-clipboard.ps1`
- Grok backup `%USERPROFILE%\.grok\last-copy.txt`

Leave HKLM `ACP`/`OEMCP` alone unless the user explicitly wants Beta UTF-8 for **console files**, knowing GBK Win32 apps will break.
