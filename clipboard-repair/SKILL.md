---
name: clipboard-repair
description: >
  Diagnose and fix Windows clipboard CJK mojibake (GBK/UTF-8 bytes shown as
  Latin-1/CP1252 in Win+V). Use when Chinese copied from Grok, a TUI, clip.exe,
  OSC 52, PowerShell stdin, or agent output pastes as ±¾µØ, æœ¬åœ°, or 澶嶅埗;
  when CF_TEXT/CF_UNICODETEXT mismatch; keywords 剪贴板乱码, 复制中文乱码,
  GROK_CLIPBOARD_NO_OSC52, /clipboard-repair.
when-to-use: "clipboard mojibake, CF_TEXT, OSC 52, Win+V, 剪贴板乱码, 复制中文乱码, GROK_CLIPBOARD_NO_OSC52, /clipboard-repair"
---

# Clipboard-Repair

Windows 上中文在屏幕上正常、复制后变乱码。根因是写入端交了 8 位 `CF_TEXT`（或 Latin-1 加宽），Win+V 按键盘 `CF_LOCALE` 合成 `CF_UNICODETEXT`。

根治：写入 `CF_UNICODETEXT`（UTF-16LE）。系统「Beta UTF-8 / ACP 65001」修不了这条链。

## 1. 先认指纹

用当前剪贴板或用户贴出的乱码对照。ASCII 仍可读。

| 管道 | `本地控制协议` 变成 | 含义 |
|---|---|---|
| GBK 字节当 CP1252 | `±¾µØ¿ØÖÆÐ­Òé` | `clip.exe` / ANSI `CF_TEXT` / 控制台 CP936，键盘是 en-US |
| UTF-8 字节当 CP1252 | `æœ¬åœ°æŽ§åˆ¶åè®®` | OSC 52 `atob`、PowerShell stdin 按 1252 读 UTF-8 |
| UTF-8 字节当 GBK | `鏈湴鎺у埗鍗忚` | UTF-8 写进 `CF_TEXT`，系统 ACP=936 再合成 Unicode |

同一段话在 Win+V 里一条正常、一条乱码：两次复制走了 Unicode 路径和 8 位路径。屏幕正常只说明终端按 UTF-8 画了格子。

细节与出处见 [references/windows-clipboard-encoding.md](references/windows-clipboard-encoding.md)。

## 2. 代操作（本机 Windows）

技能根目录：本 `SKILL.md` 所在目录。脚本在 `scripts/`。

1. 跑宿主安装（用户级，不改 HKLM ACP）：

```powershell
pwsh -NoProfile -File "$env:USERPROFILE\.grok\skills\clipboard-repair\scripts\apply-host.ps1"
```

技能未拷到 `~\.grok\skills` 时，改用本仓库里 `plugins/clipboard-repair/skills/clipboard-repair/scripts/apply-host.ps1`。

它会：用户环境写入 `GROK_CLIPBOARD_NO_OSC52=1`；把脚本拷到 `%USERPROFILE%\.grok\bin`；把该目录加入用户 PATH；把 UTF-8/`Copy-UnicodeText`/`Repair-ClipboardMojibake` 并进 PowerShell 7 与 5.1 profile；用 `本地控制协议` 做 `Set-Clipboard` 往返和 GBK→Latin-1 修复自检。

2. 让用户完全退出 Grok Desktop（含托盘）并新开终端，使环境变量生效。

3. 当前剪贴板已是乱码时：

```powershell
pwsh -NoProfile -File "$env:USERPROFILE\.grok\skills\clipboard-repair\scripts\repair-clipboard.ps1"
```

或 profile 里的 `Repair-ClipboardMojibake`。

4. 以后复制 UTF-8 管道输出用 `Set-Clipboard` 或：

```bat
type notes.md | copy-unicode.cmd
```

不要把 UTF-8/GBK 字节直接喂给 `clip.exe`。必须过 `clip.exe` 时先转无 BOM 的 UTF-16LE。

## 3. Grok / TUI 复制

| 动作 | 做法 |
|---|---|
| Grok `y` / `/copy` | 本机走 native。`/doctor` 看 Clipboard 是 `native` 还是 `osc 52`。已设 `GROK_CLIPBOARD_NO_OSC52=1` 则关 OSC 52。 |
| 复制失败 | 读 `%USERPROFILE%\.grok\last-copy.txt`（或 `GROK_COPY_FILE`）。也可用 `/copy C:\Temp\out.md`。 |
| 终端选区 | Shift+拖选或 Ctrl+Shift+C，走 conhost/WT 的 `CF_UNICODETEXT`。 |
| SSH/容器 | `grok wrap ssh ...`，让 OSC 52 在本机落成 Unicode。 |
| 仍乱 | 备份文件是 UTF-8 原文；乱的是剪贴板通道。 |

## 4. 不要用这些当剪贴板根治

- 控制面板「Beta：使用 Unicode UTF-8 提供全球语言支持」（ACP/OEMCP=65001）。剪贴板合成跟键盘 LCID，没有 UTF-8 locale。会弄乱 GBK 老程序。
- 只 `chcp 65001`。只影响当前控制台显示/管道，不把 `CF_TEXT` 变成 Unicode。
- 进程 `activeCodePage=UTF-8` 清单。该进程若仍写 `CF_TEXT`，Win+V 仍按键盘 ANSI 页合成。

终端显示乱码可以只改 PowerShell profile 的 `[Console]::InputEncoding` / `$OutputEncoding`（`apply-host.ps1` 已写）。

## 5. 写入端规则（改工具时）

- `SetClipboardData(CF_UNICODETEXT, utf16le)` 或 .NET `Set-Clipboard` 或 `arboard` Unicode。
- PowerShell 管道：`[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)` 再 `Set-Clipboard`。
- 替换 `clip.exe`：`utf8clip`，或 `iconv -f utf8 -t utf16le | clip.exe`（WSL）。
- ANSI 老工具、内容已是 GBK 的 `CF_TEXT`：复制瞬间键盘切到中文，让 `CF_LOCALE` 的 ANSI 页变成 936。治标。

## 6. 回复用户时

先报指纹属于哪一行，再说已执行的安装/修复命令和验证结果。未跑 `apply-host.ps1` 就不要声称环境变量已生效。
