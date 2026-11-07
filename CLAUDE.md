# Working in this repo

Rojo project developed on a Raspberry Pi — **there is no Roblox Studio here.** Character
models from the Creator Store are added with the scripts in `tools/` and synced by Rojo.

`ROBLOX_API_KEY` (Open Cloud) is in the environment. **Never print it, echo it, log it, put
it on a command line, or write it to a file.** The tools pass it to curl on stdin.

## What Rojo syncs: character models only

`default.project.json` maps exactly one folder. `rojo serve` and `rojo build` touch nothing else.

| Instance path | Folder on disk |
|---|---|
| `ReplicatedStorage.Assets.Characters.Killer.<Name>` | `src/ReplicatedStorage/Assets/Characters/Killer/<Name>.rbxm` |
| `ReplicatedStorage.Assets.Characters.Survivor.<Name>` | `src/ReplicatedStorage/Assets/Characters/Survivor/<Name>.rbxm` |

`ReplicatedStorage`, `Assets` and `Characters` all have `$ignoreUnknownInstances: true`, so
everything else in the place (scripts, maps, UI, other assets) is left exactly as it is in
Studio. The rest of `src/` is not synced. `pack.project.json` still maps the whole game.
`src/*/Models` are no longer mapped.

Every rig must **load as-is**: a classic R6 body with Humanoid (RigType R6),
HumanoidRootPart (also the PrimaryPart) and the six Motor6Ds in the root of the model. Nothing
repairs rigs at runtime any more (`CharacterRigFixes.server.luau` is not synced). After adding
a rig, run `tools/bake-rigs.py` and then `tools/verify-rigs.py`.
Ravel and Scrapheap are hand-built: leave them alone.

## Adding a model

1. **Search:** run `tools/search-models.sh "<query>" [count]`. It prints id, name, creator,
   verified, and script count.
2. **Show the top options and wait for the user's pick.** Prefer verified creators and
   Roblox. Mention unverified creators and models that contain scripts.
3. **Download** into the right folder: `tools/fetch-model.sh <assetId> src/ReplicatedStorage/Assets/Characters/<Role>/<Name>.rbxm`.
   The file name becomes the instance name, so match it exactly, including case.
4. **Audit** (below), then **wait for approval** before keeping it. If the user rejects it,
   delete the file.
5. Bake and verify: `tools/bake-rigs.py <Name>`, then `rojo build -o /tmp/x.rbxl &&
   tools/verify-rigs.py /tmp/x.rbxl` (delete the output afterwards).

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

- **Never edit `.rbxm` files by hand.** The only sanctioned rewrite is
  `tools/bake-rigs.py`. It has Rojo convert the file to XML, edits the instance tree, and
  has Rojo write a fresh .rbxm.
- **Never sync anything but character models, and never touch files outside
  `src/ReplicatedStorage/Assets/Characters` unless the user asks.** That includes
  `default.project.json` mappings and existing scripts.
- Show a diff before changing `default.project.json`.

## Toolchain

- `tools/inspect-rbxm.py <file>`: reads .rbxm/.rbxl without Studio. Runs the R6 rig check
  and lists every script, flagging suspicious ones. Use it for the audit.
- `tools/fetch-rigs.py --quarantine <dir outside src>`: finds, downloads and audits a rig for
  every character module that has none. Installs the first compatible one.
- `tools/bake-rigs.py [--check] [Name ...]`: builds the rig repairs into the .rbxm (unwrap a
  nested rig, convert an R15 body to R6, rebuild Humanoid/HumanoidRootPart/Motor6Ds keeping
  the pose, Commander's Grenade and Deagle). Rigs that already pass are not rewritten.
  R15 conversion adds invisible R6 limbs sized to the R15 parts, welds the R15 parts onto
  them (renamed `Body_<Name>`), and removes a stock root `Animate` script. A rig with a
  non-standard body gets the same conversion from its `CUSTOM_BODIES` entry, which names the
  children that make up each R6 limb (Fog is one). T-posed arms are lowered about the
  shoulder, and shoulder/hip joints go where the body's real joints are.
- `tools/verify-rigs.py test.rbxl`: confirms every character path in a built place holds a rig
  that loads as-is.

`rojo` 7.7.0 and `jq` live in `~/.local/bin` (Rojo version pinned in `rokit.toml`).
Text files use CRLF line endings; keep them.
