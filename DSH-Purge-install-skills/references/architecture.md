# Architecture

Purge Community is a Cordis plugin plus a set of search-replace host patches.
The official Desktop EXE stays the process. There is no second installer EXE
in the GitHub Assets (only a ~1.6 MB tgz).

## Layers (all required for “闸门拆开”)

| Layer | Who | When it loads |
|---|---|---|
| Official host | `DeepSeek Harness.exe` + `@deepseek-ai/*` | Always |
| Plugin code | tgz → `$DSH_HOME\profiles\desktop` | Stage A |
| Host patches (~80) | Apply writes into unpacked `@deepseek-ai` | Stage B, then restart |
| Runtime inject | `prompt-inject.md` / bundled default, every turn | Plugin Running |
| Boost tail | optional, default on | Plugin Running |
| Profile permission | `cordis.patch.yml` | Profile load |
| Preset | “无限制模式” = standard tools + different persona | New session |

Stage A without B leaves Plugins listing the package and **no** left-rail
Purge (client.js never injected). Stage B without C leaves patches on disk
and the running process still serving `app.asar`.

## Profile shape after Stage A

`$DSH_HOME\profiles\desktop\package.json`:

- `dependencies["dsh-purge-community"]` → `link:<PLUGIN_DIR>` or a tarball
- `dsh.profile.bundles` includes `"dsh-purge-community"` at the end

`$DSH_HOME\profiles\desktop\cordis.yml` stays `[]`. The plugin's
`cordis.patch.yml` inserts `dsh-purge`, redteam, presets, store, ui.

## Components on the Plugins page

| Component | `inject` | Typical failure |
|---|---|---|
| `dsh-purge-community` (main) | `systemPrompt`, `tools` | `Not running` if `yaml` missing |
| `.../redteam` | `[]` | Often Running even when main is dead |
| `.../presets-plugin` | `[]` | Same |
| `.../redteam/store` | `[]` | Same |
| `.../redteam/ui` | `[]` | Same |

“Not running” on the main row is inventory `unobserved` (fiber never
started). Slash commands and `sidebar.panellist` (“Purge”) live in the main
module + `client.js`. Subcomponents Running is not success.

## Apply vs status

- `dsh-purge --status` with a sealed archive prints every patch as
  `undefined` and a message that Desktop was found inside `app.asar`.
- UI Apply calls `resolveOfficialAiBase(..., { forApply: true })`, which
  extracts then patches. Bare CLI `--apply` refuses when `ai_base` is null.
- `community.js host-status` from a helper Node process reports
  `unknown_runtime`. Trust the live renderer `--app-path=` and disk layout.

## Provenance

| Tree | Role | Version used here |
|---|---|---|
| `kingcharleslzy-ai/dsh-purge` | Community, 0.2.1 host | **1.6.27** |
| `YuJunZhiXue/dsh-purge` | Upstream, paused | 1.1.71 (0.2.0-rc.2) |

npm name `dsh-purge` follows upstream. Community package name is
`dsh-purge-community`.
