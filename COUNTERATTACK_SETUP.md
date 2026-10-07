# Counterattack — Setup Guide

Everything in this repo is done. This is the list of things that have to happen **in Roblox Studio**, because they're models, animations and images — not code.

Work top to bottom. You can play-test after step 3.

---

## What changed, in one paragraph

There are no survivors any more — everyone is a killer, and everyone can hurt everyone. The game runs in **rounds**. Players wait out an intermission in the lobby, then when the timer hits zero the whole server is dropped into the arena together as their equipped Killers. Death is elimination; you sit the rest of the round out and are back in automatically for the next one. Last one breathing wins, the map comes down, and the intermission starts again. There is no PLAY button — if you're in the server when a round starts, you're in the round. The whole ruleset is controlled from one file, `src/ReplicatedStorage/Modules/GameMode.luau`, including the game's name.

**A round has no clock.** It ends when one fighter is left standing and not one second before — there is no countdown and no draw. The HUD shows how many fighters are left instead of a timer. The intermission still runs on a clock, because that one does end at a fixed time. Set `GameMode.Config.UseMatchTimer = true` to put the round timer back; every timing it needs is still in `Config`.

**Weather runs during rounds.** Meteor showers, blizzards, tornadoes and eight more, cycling for as long as the round lasts, on whatever map is up. See [WEATHER.md](WEATHER.md).

### The three modes

| `Enabled` | `UseRounds` | What you get |
|---|---|---|
| `true` | `true` | **Counterattack.** Rounds and an intermission. This is the game. |
| `true` | `false` | Open arena. No rounds; a PLAY button drops you in whenever you like. |
| `false` | — | The original Dysymmetrical game: one Killer versus a lobby of Survivors. |

Nothing was deleted to get here — all three are live code and switching between them is two booleans.

---

## Step 1 — Sync the code

```
rojo serve default.project.json
```

Connect from the Rojo plugin in Studio. Nothing else to configure — the workspace attributes the game needs (`FriendlyFire`, `FreeForAll`, `KillersAllowed`, `CooldownsEnabled`, `ChargesEnabled`) are now set from code on server start, so you don't have to add them by hand.

> If you'd previously added a `KillersAllowed` attribute in Studio, the code leaves your value alone. Delete it if you want the default.

---

## Step 2 — Build the killer models

This is the big one, and it's the part only you can do.

Each killer needs a rig at:

```
ReplicatedStorage
└── Assets
    └── Characters
        └── Killer
            ├── Verity
            ├── Superman
            ├── 1x1x1x1
            ├── Fog
            ├── Gubby
            ├── Nuker
            ├── MiniGunner
            ├── Hollowmark
            ├── Scrapheap
            └── Ravel
```

**The model name must match the script name exactly.** `MiniGunner`, not `Mini-Gunner` or `Minigunner`. `1x1x1x1` exactly. If the names don't match, the game can't find the rig and falls back to the placeholder noob.

> **You don't have to do this before playing.** Any killer without a model spawns as a classic Roblox noob with its name floating above its head — real abilities, real stats, only the body is a stand-in. Build the rigs whenever you like and they swap in automatically.

Each rig needs:

| Requirement | Why |
|---|---|
| A `Humanoid` in the root of the model | Everything keys off it — the game bails with a warning if it's missing |
| A `HumanoidRootPart` | Hitboxes, abilities and spawning all anchor to it |
| The model's `PrimaryPart` set to that `HumanoidRootPart` | The engine waits on `PrimaryPart` before a character counts as loaded, and `PivotTo` uses it to land you on the spawn point. Set automatically with a warning if you forget, but set it yourself |
| An `Animator` inside the `Humanoid` | Auto-created if missing, but cleaner to include |
| **Every part unanchored** | One anchored part anywhere freezes the whole character — it spawns in the arena and simply can't walk. Unanchored automatically with a warning, but Studio anchors parts by default while you build, so check |
| R6 rig | The engine's animations are R6. There are `.blend` files in `dysassets/Blend Files/` |

Easiest path: duplicate the existing `NullexVoyd` rig ten times, rename each one, and swap the meshes/textures as you build them. That guarantees the structure is right.

### Sizing

Health and speed are already tuned per killer in code, but physical size affects hitbox feel. Keep them roughly human-scale. Gubby is written as small and fast — scale the model down and it'll play correctly without any code change.

---

## Step 3 — Build an arena

Maps live in `ServerStorage/Maps`. You need at least one.

```
ServerStorage
└── Maps
    └── YourArena          (Model or Folder)
        └── Map            (Model — the actual geometry)
            └── SpawnPoints
                └── Layout1
                    ├── Killers
                    │   ├── Spawn1   (Part)
                    │   ├── Spawn2
                    │   └── ...
                    └── Survivors
                        ├── Spawn1
                        └── ...
```

Spawn point parts should be **anchored, invisible, non-collidable**, with their base touching the floor.

### The folder nesting is optional

That tree is the engine's template, and classic Killer-vs-Survivors mode needs it exactly. **Counterattack does not.** It pools every part it can find, so all of these work:

```
SpawnPoints/Layout1/Killers/Spawn1     <- the template
SpawnPoints/Killers/Spawn1             <- no layout wrapper
SpawnPoints/Spawn1                     <- just parts in the folder
```

Plain Roblox `SpawnLocation` objects anywhere in the map are also picked up as a last resort.

**What is not optional is having at least one part somewhere.** With none, everybody spawns at the world origin and falls out of the world — so the game refuses the drop instead, puts you back in the lobby, and the button says `MAP HAS NO SPAWNS`. The Output window names the map and tells you what to add.

### This matters more than it used to

In Counterattack the spawn picker **pools every spawn part in the layout**, ignoring which role folder it's in, then picks the one furthest from any living fighter. So:

- **Make a lot of them.** Twelve to twenty spread across the whole map. The old mode only needed a handful.
- Both `Killers` and `Survivors` folders get used. You can dump everything in one folder and leave the other empty if you prefer — the code doesn't care.
- Spread them wide. `GameMode.Config.SafeSpawnDistance` (default 60 studs) is the distance the picker tries to keep between a spawning player and everyone already fighting. If your map is small, lower it or people will keep respawning in the same corner.

Optional extras the engine supports on a map:

| Child | Type | What it does |
|---|---|---|
| `Config` | ModuleScript | `return { Ambience = "rbxassetid://...", AmbienceProperties = {...} }` |
| `Lighting` | ModuleScript | Custom lighting applied while this map is live |
| `Behaviour` | ModuleScript | Runs `:Init()` when the map loads — map events, traps, whatever |
| `ItemSpawns` | Folder | Folders named after PickableItems, each holding spawn parts |

---

## Step 4 — Play-test

Press Play in Studio. A **ROUND CONTROL** panel appears on the left — it's admin-only, and in Studio everyone counts as admin.

| Button | What it does |
|---|---|
| **START ROUND** | Starts a round right now, however few people are in the server |
| **END ROUND** | Ends the round that's running |
| **SKIP INTERMISSION** | Skips the rest of the lobby countdown |
| **TOGGLE SOLO MODE** | Flips the minimum player count between 1 and its configured value |

`F2` hides the panel.

**START ROUND is the one you want for solo testing.** A round forced with one player is flagged as a solo test, which suspends the last-fighter-standing win condition — otherwise the round would end on its first tick with you as the winner. It runs until the clock expires or you die.

In a live game the panel only appears for accounts in `OwnerPerks.Owners` or at ServerOwner rank. Every button is re-validated on the server, so hiding it isn't what keeps it safe.

### Checklist

- [ ] Output prints `[Dysymmetrical FFA] Setup looks good` (or names what's missing) on server start
- [ ] The HUD clock counts down under "Next round in..."
- [ ] When it hits zero the screen fades and you're in the arena as your equipped killer
- [ ] You're frozen for ~3 seconds, then "FIGHT!" appears and you can move
- [ ] You can damage other players — this is the friendly-fire switch working
- [ ] Dying sends you back to the lobby and you stay out until the next round
- [ ] Killstreak messages appear at the top of the screen at 3, 5, 7 and 10 kills
- [ ] Last one alive wins, the map comes down, and the intermission restarts

---

## Step 5 — Art and audio

Everything below currently uses placeholders. The game runs fine without any of it — this is polish.

### Character renders

Each killer script has:

```lua
Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
```

Replace with your uploaded portrait ID. This is what shows in the Shop, the Inventory and the player list.

### Origin icons

```lua
Origin = {
    TooltipText = "A truth that grew teeth.",
    Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
},
```

Small badge on the character card. Delete the whole `Origin` block if you don't want one.

### Animations

Every killer currently inherits the engine's default killer animations. To give one its own, add to its `Config`:

```lua
AnimationIDs = {
    IdleAnimation = "rbxassetid://...",
    WalkAnimation = "rbxassetid://...",
    RunAnimation  = "rbxassetid://...",
    -- optional:
    Stunned       = "rbxassetid://...",
    StunnedLoop   = "rbxassetid://...",
    StunnedEnd    = "rbxassetid://...",
    PreviewAnimation = "rbxassetid://...",  -- plays on the shop model preview
},
```

Per-ability animations go on the ability itself:

```lua
Confession = Ability.New({
    UseAnimation = "rbxassetid://...",
    ...
})
```

### Sounds

Every `UseSound`, `BlastSound`, `LandSound` etc. in the killer scripts is currently a generic Roblox library sound. Swap the IDs for your own. They're all named clearly at the point of use.

### Chase music

Each killer can have its own four-layer chase theme:

```lua
ChaseThemes = {
    L1 = "rbxassetid://...",   -- 60 studs
    L2 = "rbxassetid://...",   -- 45 studs
    L3 = "rbxassetid://...",   -- 30 studs
    L4 = "rbxassetid://...",   -- chase music, 15 studs
},
```

They all currently share the engine default.

### Killer intros

Optional. A killer gets a cinematic intro if either:

- there's a matching module in `ReplicatedStorage/Assets/KillerIntros/<Name>` (2D intro), **or**
- its `Config.AnimationIDs` has both `KillerRig` and `CameraRig` (3D intro)

With neither, it just shows the name toast, which looks fine. In Counterattack you only ever see the intro for **your own** killer, not one per player.

---

## Step 6 — Shop and unlocks

The shop discovers killers automatically — anything in `ReplicatedStorage/Characters/Killers` shows up with its `Price`. Current prices:

| Killer | Price | Difficulty |
|---|---|---|
| Gubby | 1250 | ★★★☆☆ |
| Nullex Voyd | 1308 | ★★★☆☆ |
| Verity | 1450 | ★★★★☆ |
| Fog | 1600 | ★★★★☆ |
| Scrapheap | 1700 | ★★★☆☆ |
| Nuker | 1750 | ★★★★☆ |
| Mini-Gunner | 1850 | ★★★☆☆ |
| 1x1x1x1 | 1900 | ★★★★★ |
| Hollowmark | 2000 | ★★★★☆ |
| Ravel | 2100 | ★★★★★ |
| Superman | 2200 | ★★☆☆☆ |

To give a killer away free, add an empty `NumberValue` named after it under:

```
ServerScriptService/Managers/SaveManager/PlayerData/Purchased/Killers
```

Only `NullexVoyd` is there right now, which is why that's what everyone starts with.

---

## If rounds don't start

**The server now tells you what's wrong.** Start the game and check the Output window — a setup report prints on server start naming every killer with no model, and flagging an empty `ServerStorage.Maps`. That report is the first place to look.

| Symptom | Cause | Fix |
|---|---|---|
| Rounds never start | No usable map, no spawn points, or not enough players | Output names which. `MinimumFighters = 1` in `GameMode.luau` lets you test alone |
| `[Counterattack] Can't start a round` | The map loaded but has no `SpawnPoints` parts, so there's nowhere to put anybody | Add them — see step 3. Without this everyone would spawn at the world origin and fall out of the world |
| You spawn as a yellow-and-blue noob | That killer has no model yet, so it's using the placeholder body | Working as intended — build the rig and it swaps over automatically |
| Screen fades black then dumps you back in the lobby | Old round-system bug — impossible now, there are no rounds to fail to start | Re-sync. If it somehow persists, send me the Output |
| Your fighter teleports but the camera stays in the lobby | Fixed. Roblox only attaches the camera by itself to characters made by `LoadCharacter`, and arena fighters are built by hand | `CameraSubjectManager` now owns the camera subject. If it ever comes back, check Output for a `[CameraSubjectManager]` warning |
| Camera follows you but sits low, around chest height | The rig's `Humanoid` has no working `RootPart`, so the camera fell back to tracking a body part | Put a `HumanoidRootPart` in the root of the model and set the model's `PrimaryPart` to it |
| A killer spawns but has no abilities, and the ability bar never appears | The model has no `PrimaryPart`, and `WaitForCharacterLoaded` waits on it forever | The game sets one automatically now and warns which part it used — but set it properly in Studio |

**You can play the whole roster before any models exist.** A killer with no rig spawns as a classic Roblox noob with its name floating overhead. You're still playing that character — real abilities, real health, real speed, real animations. Only the body is a stand-in, and it's replaced the moment you build the real model.

---

## Tuning the mode

All in `src/ReplicatedStorage/Modules/GameMode.luau`:

| Setting | Default | What it does |
|---|---|---|
| `LobbyTime` | 30 | Seconds of intermission between rounds |
| `UseMatchTimer` | `false` | **Off = last one standing with no clock.** `true` restores the round timer |
| `MatchTime` | 360 | Seconds a round runs before it's called a draw. Ignored while `UseMatchTimer` is off |
| `FinalDuelTime` | 90 | Clock is cut to this once only two fighters are left. Ignored while `UseMatchTimer` is off |
| `MinimumFighters` | 2 | Players needed to start a round. `1` to test alone |
| `JoinProtection` | 5 | Seconds of immunity when you land in the arena |
| `WinReward` | 150 / 250 | Money and EXP for winning a round |
| `ParticipationReward` | 15 / 40 | Money and EXP for everyone else who played |
| `SafeSpawnDistance` | 60 | Studs the spawn picker tries to keep from other fighters |
| `KillReward` | 25 / 70 | Money and EXP per kill |
| `KillstreakTiers` | 3/5/7/10 | Streak counts that announce to the whole server |

The `MinimumFighters`, `MatchTime` and `LobbyTime` settings below those only apply to classic mode. The arena ignores them.

### What ends a round with no clock

Nothing forces a round to end except somebody winning it — so the **weather** is the
deadline instead. The longer a round runs, the more events pile up at once, the shorter the
gaps and warnings get, and the harder everything hits, until there is nowhere on the map
that isn't being hit by something. A final two who refuse to engage get drowned, buried or
struck by lightning, and the round resolves itself.

They're also revealed to each other for the rest of the round once it's down to two.

See [WEATHER.md](WEATHER.md) for the ramp, and `Config.Escalation` to tune it. If you'd
rather have a hard ceiling on round length, turn `UseMatchTimer` back on.

---

## Restyling the PLAY button

**Counterattack has no PLAY button** — rounds start on their own. This only applies if you switch `GameMode.UseRounds` to `false` and run the open arena instead.

`src/StarterPlayerScripts/UI/PlayButton.luau` builds its UI in code rather than cloning a Studio prefab, so there is nothing to copy out of the example place for it. Edit the `Style` table at the top of that file.

Same deal for the killstreak feed in `ArenaFeed.luau`, which IS used in both modes.

---

## One thing worth flagging

**Superman** is a DC Comics trademarked character. The kit works perfectly well on an original flying bruiser — rename the model, the `Config.Name` and the file, and nothing else has to change. Worth doing if this game is ever going public, since Roblox does act on IP reports. Entirely your call; the character is built and works as-is either way.

---

## Reverting to the old game

Two booleans, in `src/ReplicatedStorage/Modules/GameMode.luau`:

```lua
GameMode.Enabled  = false   -- the original Killer vs Survivors game
```

That restores the original round flow, malice-based killer selection, LMS, survivor rewards, the lot. The new killers stay available — they're just killers again, and the survivor side comes back.

```lua
GameMode.Enabled  = true
GameMode.UseRounds = false  -- the open arena, with a PLAY button
```

That's the no-rounds version: the map goes up on server start and never comes down, and a PLAY button drops you in whenever you like.

---

## Engine bugs that got fixed along the way

These were pre-existing and are worth knowing about even if you revert:

- **Infinite stamina.** Killers only drained stamina near a character with the `Survivor` role. That role doesn't exist in Counterattack, so everyone had permanent sprint.
- **Resistance crashed on hit.** `CommonFunctions.DamagePlayer` did arithmetic on the `NumberValue` instance instead of its `.Value`, throwing an error every time a target with Resistance was hit.
- **Piercing attacks stopped early.** A multi-hit hitbox that killed its first target bailed out of the whole loop and silently dropped everyone else.
- **`PreventSlash` did nothing.** Two abilities set it to disarm the basic attack; nothing ever read it.
- **Nullex Voyd's Callback Ping** left him permanently at 18% movement speed for the rest of the match (a `self.owner` / `self.Owner` typo).
- **Chase music never played** for killers — the proximity check was inverted.
- **Slash `Knockback` and on-hit effects were ignored** — set on a slash, never passed to the hitbox.

Full detail is in `src/ServerScriptService/DYSYMMETRICAL_CHANGELOG.server.luau`.
