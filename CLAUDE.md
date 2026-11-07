# Working in this repo

Rojo project developed on a Raspberry Pi — **there is no Roblox Studio here.** Models from
the Creator Store are added with the scripts in `tools/` and synced by Rojo.

`ROBLOX_API_KEY` (Open Cloud) is in the environment. **Never print it, echo it, log it, put
it on a command line, or write it to a file.** The tools pass it to curl on stdin.

## Where models go

| Instance path | Folder on disk | Rojo owns it? |
|---|---|---|
| `Workspace.RojoModels` | `src/Workspace/Models` | Yes, fully synced |
| `ServerStorage.RojoModels` | `src/ServerStorage/Models` | Yes, fully synced |
| `ReplicatedStorage.RojoModels` | `src/ReplicatedStorage/Models` | Yes, fully synced |

Every service has `$ignoreUnknownInstances: true`, so anything hand-placed in Studio survives
a sync. The three `Models` folders are excluded from their parent's directory scan
(`globIgnorePaths`) so they appear only once, as `RojoModels`. They are kept in git with
`.gitkeep`; Rojo fails to build if one is missing.

Character rigs are the exception: they go where the game code looks them up
(`ReplicatedStorage.Assets.Characters.Killer.<Name>`, see `RIG_SETUP.md`), only when asked.

## Adding a model

1. **Search:** run `tools/search-models.sh "<query>" [count]`. It prints id, name, creator,
   verified, and script count.
2. **Show the top options and wait for the user's pick.** Prefer verified creators and
   Roblox. Mention unverified creators and models that contain scripts.
3. **Download** into the right folder: `tools/fetch-model.sh <assetId> src/<Service>/Models/<Name>.rbxm`.
   The file name becomes the instance name, so match it exactly, including case.
4. **Audit** (below), then **wait for approval** before keeping it. If the user rejects it,
   delete the file.
5. Confirm it builds: `rojo build -o /tmp/x.rbxl` (delete the output afterwards).

## Script audit after every download

List **every** `Script`, `LocalScript`, and `ModuleScript` in the model, with its path and
size. Read their source and flag:

- `require(<number>)`: loads remote code by asset ID (the classic backdoor)
- `getfenv` / `setfenv`, `loadstring`
- Any `HttpService` use (`GetAsync`, `PostAsync`, `RequestAsync`)
- Obfuscated code: long escaped strings, `\x`/`\ddd` byte soup, huge one-line scripts,
  `string.char` chains, base64 blobs, meaningless variable names
- `MarketplaceService` prompts, `TeleportService`, `Players:Kick`, `:Destroy()` on services,
  writing to `game.Players`/`ServerScriptService`, `InsertService`
- Scripts in odd places (inside parts or values) or with blank or misleading names

Do not keep the model until the user approves the audit.

## Hard rules

- **Never edit `.rbxm` files by hand.** Position and configure models from Luau scripts
  (`PivotTo`, `SetAttribute`, adding missing children at runtime).
- **Never touch anything outside the `RojoModels` folders unless the user asks.** That
  includes `default.project.json` mappings and existing scripts.
- Show a diff before changing `default.project.json`.

## Toolchain

- `tools/inspect-rbxm.py <file>`: reads .rbxm/.rbxl without Studio. Runs the R6 rig check
  and lists every script, flagging suspicious ones. Use it for the audit.
- `tools/fetch-rigs.py --quarantine <dir outside src>`: finds, downloads and audits a rig for
  every character module that has none. Installs the first compatible one.
- `tools/verify-rigs.py test.rbxl`: confirms every character path exists in a built place.

`rojo` 7.7.0 and `jq` live in `~/.local/bin` (Rojo version pinned in `rokit.toml`).
Text files use CRLF line endings; keep them.
