---
name: dsh-purge-install-skills
description: >
  Install Purge Community (dsh-purge-community) onto official DeepSeek Harness
  Desktop, apply host patches, unseal app.asar, and verify the left-rail Purge
  page. Use when installing or repairing dsh-purge / Purge Community on DSH
  0.2.1-rc.1/rc.2, when the plugin shows Not running, when slash commands are
  ignored, when status lists patches as undefined, or when the user runs
  /dsh-purge-install-skills.
when_to_use: "dsh-purge, Purge Community, dsh-purge-community, DeepSeek Harness plugin install, app.asar unseal, /purge status, yaml ERR_MODULE_NOT_FOUND, /dsh-purge-install-skills"
when-to-use: "dsh-purge, Purge Community, dsh-purge-community, DeepSeek Harness plugin install, app.asar unseal, /purge status, yaml ERR_MODULE_NOT_FOUND, /dsh-purge-install-skills"
---

# DSH-Purge-install-skills

Install **Purge Community 1.6.27** (`dsh-purge-community`) as a plugin on the
machine's **official DeepSeek Harness Desktop**. It is not a second DSH EXE.

Verified target: official Desktop **0.2.1-rc.2** (rc.1 also). Upstream
`YuJunZhiXue/dsh-purge` **1.1.71** is paused and does not track 0.2.1.

Placeholders only. Never write a host drive letter, username, or install path
into this skill or into chat logs.

| Token | Meaning |
|---|---|
| `$DSH_HOME` | Profile home. Windows default `%USERPROFILE%\.dsh` |
| `<DSH_ROOT>` | Folder that holds `DeepSeek Harness.exe` and `resources\` |
| `<DSH_EXE>` | `<DSH_ROOT>\DeepSeek Harness.exe` |
| `<DSH_CLI>` | `<DSH_ROOT>\resources\runtime\cli\bin\dsh.cmd` |
| `<PLUGIN_DIR>` | Unpacked release root (the `package\` directory inside the tgz) |

Load [references/architecture.md](references/architecture.md),
[references/windows-asar.md](references/windows-asar.md), and
[references/pitfalls.md](references/pitfalls.md) before changing the host.

## 1. Choose the package

- Community (use this): https://github.com/kingcharleslzy-ai/dsh-purge
- Release **v1.6.27** Assets (page bottom, below the changelog):
  - `dsh-purge-community-1.6.27.tgz`
  - `dsh-purge-community.tgz` (same bytes)
  - `SHA256SUMS.txt`
- Ignore GitHub **Source code (zip/tar.gz)**.

Official installer (downloads and hashes the tgz):

```powershell
Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/kingcharleslzy-ai/dsh-purge/master/scripts/install.ps1 -OutFile "$env:TEMP\purge-install.ps1"
& "$env:TEMP\purge-install.ps1" -Version 1.6.27
```

Pin `-DshExe '<DSH_EXE>'` when more than one Desktop exists.

## 2. Three stages (never skip)

```
profile add  →  Apply (unpack + patch)  →  tray-quit and reopen
```

### Stage A — plugin into `desktop` profile

Open Desktop once so `$DSH_HOME\profiles\desktop\package.json` exists.

```powershell
& '<DSH_CLI>' plugin --profile desktop add '<PLUGIN_DIR>'
```

Success: `+ dsh-purge-community 1.6.27` and
`$DSH_HOME\profiles\desktop\package.json` lists the package in `dependencies`
and `dsh.profile.bundles`.

If the add used `link:` / `file:` (a local folder), install plugin deps **in
`<PLUGIN_DIR>`**, not in the profile:

```powershell
Set-Location -LiteralPath '<PLUGIN_DIR>'
npm install yaml@2.9.1 --omit=dev --no-fund --no-audit
```

`package.json` declares `"yaml": "2.9.1"`. Missing `node_modules\yaml` makes
the **main** component `Not running` (`ERR_MODULE_NOT_FOUND` from
`lib/permission-state.js`). Redteam/presets can still show Running.

### Stage B — Apply host patches

Closing the window is not enough. Tray-quit Desktop so `app.asar` is unlocked.

Preferred: after a full quit, open Desktop → left rail **Purge** → **Apply**.

If the rail item is missing, Apply from the Desktop runtime:

```powershell
$env:ELECTRON_RUN_AS_NODE = '1'
$env:DSH_HOME = "$env:USERPROFILE\.dsh"
$env:DSH_PROFILE = 'desktop'
$env:DSH_SURFACE = 'desktop'
```

Then run `<DSH_EXE>` as Node against community `bin\community.js` / the
plugin's `resolveOfficialAiBase({ forApply: true })` path. That extracts
`resources\app.asar` to `resources\app`, writes ~80 patches, and leaves a
handoff to rename the archive.

Electron's default `fs` treats `app.asar` as a directory. Rename the archive
with `original-fs` (`renameAsarAside`). After a successful rename, disk shows
`resources\app\` and `resources\app.asar.bak` (or `.bak`), and **no**
`resources\app.asar`.

### Stage C — tray-quit and reopen

Windows will not load `resources\app` while `app.asar` still exists and the
process is alive. After Apply:

1. Quit from the tray (task manager: zero `DeepSeek Harness` processes).
2. Start `<DSH_EXE>` again.
3. Confirm the renderer `--app-path=` points at `resources\app`, not `app.asar`.

## 3. Success (observed on 0.2.1-rc.2 + 1.6.27)

- Left rail shows **Purge** (with Plugins / Automation tasks).
- Header: host **0.2.1-rc.2**, plugin **1.6.27**, **已从解包目录启动 (换包完成)**.
- Status: on the order of **63/66** live patches; disk writes **72/75** with
  a few N/A (missing optional packages such as 梁神 / hooks).
- **破甲自检 25 层全部在位**.
- Plugins page: `dsh-purge-community` main component **Running**.
- Chat: `/purge status` is handled by the plugin (not by the model).
  `/purge-community status` is only the fallback when `/purge` is taken.

## 4. Agent rules

- Use `<DSH_CLI>` or a full path to Desktop's `dsh.cmd`. A different `dsh` on
  PATH (standalone CLI tree) is a different install.
- Never `dsh plugin add dsh-purge` (npm name → paused upstream 1.1.71).
- Never restore `app.asar.bak` over `app.asar` unless the user asked to unseal
  revert. That reseals the host and hides patches.
- After an official DSH upgrade, `app.asar` comes back. Apply again, then
  tray-quit.
- Stop Desktop before renaming `app.asar`. User must authorize killing the
  GUI; say so before `Stop-Process`.
- Do not put secrets, usernames, or host paths into this skill or into the
  GitHub copy.

Details: [references/pitfalls.md](references/pitfalls.md).
