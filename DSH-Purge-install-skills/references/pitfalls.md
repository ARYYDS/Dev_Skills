# Pitfalls (from a completed 0.2.1-rc.2 + 1.6.27 install)

## Package and Assets

- Changelog for 1.6.27 concatenates older notes. **Assets sit at the very
  bottom** of the Release page (often “Assets 5”). Scroll past 1.6.26….
- GitHub may show Assets as `Loading`. Direct URLs still work:
  `.../releases/download/v1.6.27/dsh-purge-community-1.6.27.tgz`
- **Source code (zip)** is the git tree, not the hashed install tgz.
- npm `dsh plugin add dsh-purge` installs paused upstream **1.1.71**
  (0.2.0-rc.2). 0.2.1 then dies on `{{cwd}}` in `deployment:persona-suffix`.

## PATH / which `dsh`

Desktop may pop **Add the Desktop command to your terminal** when another
`dsh` (standalone CLI tree) precedes Desktop's `dsh.cmd`. Use the full
`<DSH_CLI>` for `plugin add`. Installing the Desktop command is optional;
the plugin add must hit the same profile the GUI uses (`desktop`).

`dsh --profile desktop --dump-config` from an external CLI can fail with
`profile "desktop" is managed exclusively by the Electron application`.

## `link:` without `yaml`

`dsh plugin add <PLUGIN_DIR>` records
`dsh-purge-community: "link:<PLUGIN_DIR>"`. pnpm does **not** install the
plugin's `dependencies`. Main module import chain:

`lib/index.js` → `selfcheck.js` → `permission-state.js` → `yaml`

Symptom: Plugins page main row **Not running**; `/purge-community status`
is answered by the model (Glob/Grep the workspace). Redteam rows Running.

Fix: `npm install yaml@2.9.1` **inside `<PLUGIN_DIR>`**, then tray-quit
and reopen. Installing `yaml` only in the profile or in the user home
does not satisfy Node ESM resolution from `<PLUGIN_DIR>\lib\`.

Tarball / official `install.ps1` already vendors deps.

## Stage confusion

| You see | Actual stage |
|---|---|
| `+ dsh-purge-community 1.6.27` in the terminal | A only |
| Plugins list, toggle on, no Purge rail | A; client not loaded |
| Status: all patches `undefined`, “宿主在 app.asar” | A; B not done |
| `resources\app` exists, renderer still `--app-path=app.asar` | B wrote disk; C not done |
| Left rail **Purge**, “已从解包目录启动”, 25-layer selfcheck green | Done |

`/purge-community status` in an empty New Session is a user message until
the main plugin is Running. After that, `/purge status` is the primary
command (`installCommands` registers `/purge` first).

## Apply / extract

- Helper `host-status` in `ELECTRON_RUN_AS_NODE` is `unknown_runtime`.
  It is not proof the GUI loaded patches.
- CLI `--apply` exits when `ai_base` is null (sealed archive). UI Apply
  extracts first. Match that path (`forApply: true`) for unattended Apply.
- `JSON.stringify` on the full `handoff` object can throw (cycles). Log
  plain fields only (`aiBase`, `extracted`, `asar`, `appDir`).
- `enumeratePatchAiBases` may also patch a **second** `@deepseek-ai` tree
  (standalone CLI). Desktop still needs `resources\app` of `<DSH_ROOT>`.
- Optional patches (`missing_file`): 梁神, hooks, official update
  handoff. They do not block success. Live count near 63/66 is expected.

## Process and cleanup

- Tray-quit, then confirm zero `DeepSeek Harness` processes, before
  renaming `app.asar`.
- After a botched extract, delete `resources\app.dshpurge-next` only if
  it is incomplete. A full next dir can be committed.
- Keep `app.asar.bak` until the user confirms the unpacked host. Moving
  it back to `app.asar` reseals and hides patches.
- Temp helper scripts belong in `%TEMP%`, not inside `<PLUGIN_DIR>`.

## Do not

- Treat Plugins **Uninstall** toggle as Apply.
- `Set-ExecutionPolicy` globally; use `powershell -NoProfile -ExecutionPolicy Bypass -File ...` for `install.ps1`.
- Change the machine npm registry to make Hub install work.
- Claim the left rail will appear before Stage C + main component Running.
- Put host paths, usernames, or tokens into the skill tree.
