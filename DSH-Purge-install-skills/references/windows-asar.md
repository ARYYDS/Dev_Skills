# Windows official Desktop and `app.asar`

Official Desktop ships a sealed `resources\app.asar` (~180 MB). Electron
loads that archive in preference to `resources\app` whenever the file
exists.

## Extract

Apply (`forApply: true`) does:

1. `extractAsarToSide` → `resources\app.dshpurge-next`
2. `overlayAsarUnpacked` copies native files from `app.asar.unpacked`
3. `commitExtractedDir` renames `app.dshpurge-next` → `resources\app`
4. Patches files under `resources\app\dsh\node_modules\@deepseek-ai`

If the helper dies between 1 and 3, `app.dshpurge-next` can be complete
(tens of thousands of files, `@deepseek-ai` present) while `resources\app`
is still missing. Resume: overlay, tray-quit, commit, then patch. Do not
extract a second copy on top.

## Rename the archive (`original-fs`)

Node inside `DeepSeek Harness.exe` (`ELECTRON_RUN_AS_NODE=1`) uses an
asar-aware `fs`. `statSync('resources\\app.asar').isFile()` is **false**
even though the file is on disk. A script that does
`if (exists && isFile()) rename` will print “asar already gone” and leave
the archive in place.

Use the plugin's `diskFs()` / `original-fs` and `renameAsarAside(asarPath)`.
After success: `app.asar` gone, `app.asar.bak` (or `.purge-*.bak`) present,
`resources\app\package.json` name `@deepseek-ai/dsh-desktop`.

## File lock

A live Desktop holds `app.asar`. Rename fails until every
`DeepSeek Harness` process exits, including tray. Closing the window is not
exit.

Community Windows handoff writes a helper that waits for quit, then moves
the archive. It does not kill Electron on a timer. If the helper never
runs, the operator tray-quits (or, with explicit user consent, stops the
process) and then `renameAsarAside`.

## Live proof after reopen

Renderer command line contains `--app-path=...\resources\app`.
Host command line points at
`resources\app\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\index.js`.

`--app-path=...\resources\app.asar` means the archive is still winning.

## Official upgrade

A Desktop update restores `app.asar`. Patches in `resources\app` are then
ignored. Apply again, rename the new archive, tray-quit, reopen.
