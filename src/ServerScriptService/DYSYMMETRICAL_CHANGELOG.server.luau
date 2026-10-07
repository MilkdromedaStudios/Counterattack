--[[

    ------01/10/2025------
    * Added the shop (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/Shop` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    * Added reward notifications (e.g. when buying a character or getting a character from an achievement) (MAKE SURE TO GO INTO `StarterGui` AND `StarterPlayerScritps/UI/Shop` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------06/10/2025------
    * Added spectator & ragdoll collision group (MAKE SURE TO GO INTO `Collision Groups` IN `Window -> 3D -> Collision Groups` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------08/10/2025------
    * Added shift lock fixes and execution animations (MAKE SURE TO GO INTO `StarterPlayerScripts/PlayerModule/CameraModule` AND REPLACE YOUR `SmoothShiftLock` WITH THE ONE IN THE EXAMPLE PLACE CURRENTLY)
    * Rearranged SFX in character configs (check the diff)

    ------09/10/2025------
    * Added Round Player List (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/RoundPlayerList` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    
    ------16/10/2025------
    * Refactored TerrorRadius to not be a util and be embedded to each character instead
    * Added TopbarPlus for the mod panel

    ------18/10/2025------
    * Added Emote WHEEL using trigonometry that I despise (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/EmotePanel` & `ServerScriptService/Managers/SaveManager/PlayerData/Equipped/Emotes` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------19/10/2025------
    * Added Emote purchasing and equipping (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/Inventory` & `StarterPlayer/StarterPlayerScripts/UI/Shop` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    * Added some loading screen stuff (MAKE SURE TO GO INTO `ReplicatedFirst/Loading` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------20/10/2025------
    * Added Player list UI (MAKE SURE TO GO INTO `StarterGui/PlayerList`, `StarterPlayer/StarterPlayerScripts/UI/PlayerList` & `StarterPlayer/StarterPlayerScripts/UI/PlayerList/PlayerInfoWindow` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    * Added Hide Money option (MAKE SURE TO GO INTO `ServerScriptService/Managers/SaveManager/PlayerData/Settings/Privacy/HideMoney` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------21/10/2025------
    * Added Money & EXP notifications (MAKE SURE TO GO INTO `StarterGui/MoneyXPRewards`, `ServerScriptService/Managers/SaveManager/PlayerData/Settings/Miscellaneous/ShowRewardNotifications` and `StarterPlayer/StarterPlayerScripts/UI/MoneyXPRewards` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    * Added skippable killer intros (MAKE SURE TO GO INTO `ServerScriptService/Managers/SaveManager/PlayerData/Settings/Miscellaneous/DisableKillerIntros` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    * Reminder to switch the scale type of the character renders in the player info window to `Crop` for them to show up correctly without caring about image aspect ratios.
    * Added Credits menu (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/Credits` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------25/10/2025------
    * Added Multi-Killer support in the same round (do what's said under here)
        * Disable collision between the Killer collision group
        * Add a workspace attribute called "KillersAllowed" and make it have a number value
        * Remember that rounds that start without any survivors and don't have `CanSpawnKiller` set to false will end instantly
    
    ------26/10/2025------
    * Added camera shaking when damaged (MAKE SURE TO GO INTO `ServerScriptService/Managers/SaveManager/PlayerData/Settings/Customization/ScreenShakeEnabled` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    * Added camera desaturation when low on health (MAKE SURE TO GO INTO `ServerScriptService/Managers/SaveManager/PlayerData/Settings/Customization/ScreenDesaturation` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    * Added camera fx when killing someone

    ------29/10/2025------
    * Added spectating (MAKE SURE TO DISABLE `StreamingEnabled` IN `Workspace` OR ELSE THIS WON'T WORK; ALSO MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/Spectate` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    * Added a projectile class
    * Added a red vignette when low on health (MAKE SURE TO ENABLE `IgnoreGuiInset` IN `StarterGui/TemporaryUI`)
    * Added custom LMS voicelines depending on the last man standing's character AND skin
    * Added custom kill voicelines depending on the killed player's character AND skin

    ------31/10/2025------
    * Added stun protection (MAKE SURE TO GO INTO `ServerScriptService/Managers/PlayerManager` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    
    ------05/11/2025------
    * Added original sidebar icons & remade some code for them (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/Sidebar` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------06/11/2025------
    * Added new sidebar labels and inverted icon support (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/Sidebar` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------08/11/2025------
    * Added `More Info` to Shop and Inventory (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/Shop` & `StarterPlayer/StarterPlayerScripts/UI/Inventory` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------12/11/2025------
    * Added effect tooltips when checking a `More Info` page (MAKE SURE TO GO INTO `ReplicatedStorage/Classes/Tooltip` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------14/11/2025------
    * Added game changelog (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/Changelog`, `ServerScriptService/Managers/SaveManager/PlayerData/Misc/LastSeenLog` & `ReplicatedStorage/PlaceVersion` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    * Added rules menu (TBF) (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/Rules` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    * Added smaller sidebar icons (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/SideBar` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------16/11/2025------
    * Turned the Stun Protection VFX into a ParticleEmitter (MAKE SURE TO GO INTO `ServerScriptService/Managers/PlayerManager/StunSpawnProtection` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------17/11/2025------
    * Added support for multi-killer intro toasts (MAKE SURE TO GO INTO `ReplicatedStorage/Assets/KillerIntros/KillerNameToast` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------20/11/2025------
    * Added skin previews on card hover (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/Shop/ShopUI/Container/SkinsContainer/Content/SkinPreviewCache` & `StarterPlayer/StarterPlayerScripts/UI/Shop/Templates/CardTemplate` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    Also make sure to add the UIPaddings in the shop and inventory's scrolling frames!

    ------21/11/2025------
    * Made the Attackable collision group collidable with every group but Items, KillerPassthrough, NonCollidable and Ragdolls

    ------16/12/2025------
    * Removed Forsaken equipped labels (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/Inventory/Templates/CardTemplate` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    * Added origin labels (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/Inventory/Templates/CardTemplate` & `StarterPlayer/StarterPlayerScripts/UI/Shop/Templates/CardTemplate` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------20/12/2025------
    * Actually made ability buttons work (MAKE SURE TO GO INTO `ReplicatedStorage/Classes/Ability/AbilityGUI` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)
    
    ------03/01/2026------
    * Added achievements menu (MAKE SURE TO GO INTO `StarterPlayer/StarterPlayerScripts/UI/AchievementsMenu` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------10/01/2026------
    * Added PickableItems (MAKE SURE TO GO INTO `ReplicatedStorage/Classes/Item/ItemGUI`, `ReplicatedStorage/Assets/Items` & `ReplicatedStorage/Assets/PickableItems` IN THE EXAMPLE PLACE TO GRAB WHAT YOU NEED FOR IT TO WORK)

    ------14/08/2026------
    ============================ FREE FOR ALL CONVERSION ============================

    This place no longer runs the asymmetrical Killer vs Survivors ruleset. Everyone
    spawns as a Killer and fights everyone. All of it is switched from one place:
    `ReplicatedStorage/Modules/GameMode`. Set `GameMode.Enabled = false` there and the
    classic 1vX flow comes straight back — none of the old code paths were deleted.

    * Added `ReplicatedStorage/Modules/GameMode` — the single source of truth for the
      mode. Match length, lobby length, minimum fighters, mid-match joining, respawn
      cooldown, spawn protection, rewards and killstreak tiers all live in its `Config`.
      Its `Init()` also sets the `FriendlyFire`, `FreeForAll`, `CooldownsEnabled` and
      `ChargesEnabled` workspace attributes from code, so a fresh clone of the place
      works without anyone adding them by hand in Studio.

    * Added `ReplicatedStorage/Modules/CombatUtils` — shared ability building blocks
      (radius queries, line of sight, damaging zones, dashes, blinks, position swaps).
      Every new killer is built on it. `Blink()` refuses hops over 400 studs because
      `AntiTP` kills anyone who moves 500+ in a frame.

    * Rewrote `ServerScriptService/Managers/RoundManager`:
        * Matches are last-one-standing. `EndRound` now takes a `Player` winner, or
          "Draw", as well as the old "Killer"/"Survivors" strings.
        * Added a PLAY queue. `RoundManager.Callables.RequestJoin()` is the single
          entry point — it queues you, drops you into a live match, or refuses with a
          reason string the client turns into button text.
        * Sudden Death replaces LMS: when only 2 fighters remain everyone left sees
          everyone else's aura and the clock is cut down.
        * Added a start grace period, because characters land in `workspace.Players`
          a frame or two after spawning and the win check used to see an empty arena
          and instantly call the match a draw.

    * Added `ServerScriptService/RemoteHandler/RequestJoinMatch` — the PLAY remote. All
      of the "can this player join" logic stays server-side; the client only asks.

    * Added `StarterPlayerScripts/UI/PlayButton` and `.../UI/ArenaFeed`. Both build
      their UI from code instead of cloning a Studio prefab, so THERE IS NOTHING TO
      COPY OUT OF THE EXAMPLE PLACE FOR THESE TWO. Restyle them via the `Style` table
      at the top of each file.

    * Added 10 killers in `ReplicatedStorage/Characters/Killers`: Verity, Superman,
      1x1x1x1, Fog, Gubby, Nuker, MiniGunner, Hollowmark, Scrapheap and Ravel.
      SCRIPTS ONLY — you still need to make a rig for each one in
      `ReplicatedStorage/Assets/Characters/Killer/<Name>`, named exactly like the module.

    * Added 6 effects in `ReplicatedStorage/Effects`: Burning, Irradiated, Fragile,
      Snared, Grounded and Marked. `Fragile` is wired into `CommonFunctions.DamagePlayer`
      as the inverse of `Resistance`.

    ---------------------------- ENGINE BUGS FIXED ----------------------------

    These were all pre-existing and are worth knowing about even if you revert the mode.

    * `PlayerSprintManager`: killers only drained stamina when a character with the
      `Survivor` role was within 110 studs. That role doesn't exist in Free For All, so
      every fighter had infinite stamina and permanent sprint. Now any non-spectator
      counts as an enemy when the mode is on.

    * `CommonFunctions.DamagePlayer`: read `0.1 * ResistanceValue` where
      `ResistanceValue` is the NumberValue *instance*, not its `.Value`. That threw an
      arithmetic error on every hit against anyone carrying Resistance. Now reads `.Value`.

    * `Hitbox`: when a hit would kill a target and there was no execution animation to
      play, it `return`ed out of the entire hitbox loop instead of skipping that one
      target. A piercing hitbox that killed its first victim silently dropped everyone
      else and never fired its `Ended` callback. Changed to `continue`.

    * `Ability:CanUse()`: the `PreventSlash` attribute was written by Nullex Voyd (and
      now Fog and Mini-Gunner) but read by nothing at all, so abilities that claimed to
      disarm your basic attack never did. `CanUse` checks it now.

    * `NullexVoyd`: Callback Ping removed its speed factor using `self.owner`
      (lowercase), which is nil. The 0.18x speed factor was never removed, leaving him
      at 18% movement speed for the rest of the match. Fixed to `self.Owner`.

    * `TerrorRadiusManager._CheckAsKiller()`: skipped any player who did NOT have
      Undetectable, i.e. the check was inverted and the killer chase layer never fired.
      Now it skips players who DO have Undetectable, which is what was meant.

    * `Ability/Slash`: `Knockback`, `EffectsToApply` and `HitMultiple` set on a slash
      were silently dropped instead of being passed to the hitbox. Now passed through,
      so a killer can give its basic attack knockback or an on-hit status without
      rewriting the whole behaviour.

    ------15/08/2026------
    ==================== MATCH START RELIABILITY ====================

    Fixes for "PLAY fades to black then dumps you back in the lobby". The root cause was
    a missing killer model, but the reason it presented as a *silent* failure was that
    nothing along the start path contained or reported an error.

    * `PlayerManager._RespawnPlayer`: looked up rigs with a direct index
      (`.Assets.Characters[RigType][RigName]`). Indexing a missing child THROWS in
      Roblox rather than returning nil, so a character whose model hadn't been built yet
      raised an error right there — and the `if not char` fallback underneath it was
      unreachable dead code. Now uses `FindFirstChild`, so the ServerStorage fallback and
      the load-empty path actually run, and the warning names the missing rig.

    * `RoundManager._StartFreeForAll`: had no error containment. One character failing
      aborted the whole spawn loop, leaving a match where only some players existed,
      which the win check then instantly resolved — fade to black, then straight back to
      the lobby with no explanation. Now:
        * preflight-checks for maps before anything is committed
        * wraps each player's spawn in its own pcall
        * verifies each player actually made it into the arena
        * calls the new `RoundManager.Utils.AbortStart()` if too few spawned

    * Added `RoundManager.Utils.AbortStart()`: unwinds a failed start properly —
      disconnects death hooks, returns half-spawned players to spectator, destroys the
      map, lifts the fade, resets the clock and puts everyone back in the queue.
      A failed start can no longer leave a black screen.

    * Added `ReplicatedStorage/Modules/PlaceholderRig`: builds a classic Roblox noob
      (yellow head and arms, blue torso, green legs) in code, with a floating name tag
      saying which character it's standing in for.

      `PlayerManager._RespawnPlayer` now spawns one of these when a character has no
      model yet, instead of falling through to `LoadEmpty()` — which quietly made the
      player a SPECTATOR, i.e. they never entered the match at all.

      The player still plays the character they actually chose: module, abilities,
      health, speed, stats and animations are all the real ones. Only the body is a
      stand-in, and it's replaced automatically the moment the real rig exists.

      It's a standard R6 rig with the canonical Motor6D `C0`/`C1` values, so the
      engine's R6 animations drive it correctly. Verified: every part lands in the exact
      R6 rest pose.

    * Added `RoundManager.Utils.ReportSetupProblems()`: prints a setup report to the
      Output window on server start, naming every killer that has no model and flagging
      an empty `ServerStorage.Maps`. Runs once, before anybody presses PLAY.

    * `MapManager.GetRandomMap()`: `Rand:NextInteger(1, 0)` throws, so an empty
      `ServerStorage.Maps` failed with a confusing message about integer ranges. Also
      guarded the `Map` and `SpawnPoints` lookups, which were both unchecked nil derefs.

    * Sudden Death fired on the opening roster of a 2-player match, because the starting
      count already equalled `SuddenDeathAt`. It now also requires the field to have
      actually thinned (`< StartingFighterCount`), and that bar tracks its high-water
      mark so mid-match joiners don't suppress it.

    * `SetupFighter` overwrote a player's death connections without disconnecting the old
      ones, so a respawn could leave stale hooks that fired `_OnPlayerDeath` twice.

    * Switched this codebase's elapsed-time measurement from `os.clock()` to `time()`.
      `os.clock()` returns CPU time in Roblox, not wall time, so it can drift from real
      seconds under load — wrong for respawn cooldowns and grace periods. `time()` is
      monotonic game time and is what these were always meant to use.

    ------15/08/2026 (2)------
    ==================== PERSISTENT ARENA ====================

    The round system is gone from Free For All. There is no matchmaking, no queue and no
    match — PLAY teleports you into the arena, full stop.

    * `RoundManager.Utils.OpenArena()`: spawns the map once on server start and leaves it
      up for the life of the server. `RoundState` is parked on "InRound" permanently,
      because systems that gate on being in a round (terror radius, chase music) should
      always be live in an always-open arena.

    * `RoundManager.Callables.RequestJoin()` is now just: are you already in? are you on
      a respawn cooldown? is the map up? — then teleport. It no longer queues anybody,
      counts players, or starts anything.

    * DELETED (all unreachable in this mode): `_StartFreeForAll`, `AbortStart`,
      `InitSuddenDeath`, `GrantFreeForAllRewards`, and the `MatchStartedAt` /
      `StartGracePeriod` / `StartingFighterCount` tracking. ~200 lines.

    * `StartRound`, `EndRound`, `InitLMS`, `CheckForKillerWin` and `OnLobbyTimerEnd` now
      early-return when `GameMode.Enabled` is true. They are classic-mode only. `EndRound`
      in particular MUST NOT run here — it would tear down the arena everyone is standing in.

    * `GameMode.Config` was cut down to what the arena actually uses: `RespawnCooldown`,
      `JoinProtection`, `SafeSpawnDistance`, `KillReward`, `KillstreakTiers`. The
      match-length / lobby-length / minimum-player settings are kept but only apply to
      classic mode. Sudden Death and the win/runner-up rewards are gone entirely.

    * `RespawnCooldown` dropped 6s -> 3s. It's the only thing between dying and playing
      again, so it should be short. Set it to 0 for instant re-entry.

    * The HUD timer would have sat frozen at "Round ends in… 0:00" forever, so
      `UI/Time` now reuses those two labels to show the live fighter count instead. It
      reads `RoundInfo.PlayersRemaining`, which already replicates.

    * `GameMode.IsMatchLive()` renamed to `GameMode.IsArenaOpen()`.

    * Rules menu and player-facing changelog rewritten — they described matches, rounds
      and Sudden Death, none of which exist any more.

    Everything above is reversed by setting `GameMode.Enabled = false`, which restores the
    original Killer-vs-Survivors round game untouched.

    ------15/08/2026 (3)------
    ==================== THE CAMERA STAYED IN THE LOBBY ====================

    PLAY teleported your fighter into the arena and left the camera behind, locked to the
    spot you pressed the button from.

    ROOT CAUSE
    Roblox only attaches the camera to a character by itself when that character came from
    `Player:LoadCharacter()` / `LoadCharacterAsync()`. Fighters never do. PLAY runs
    `PlayerManager._RespawnPlayer`, which destroys the lobby body, builds the killer rig by
    hand and assigns `Player.Character = char` directly — and assigning that property does
    not move the camera.

    So `workspace.CurrentCamera.CameraSubject` was still pointed at the lobby body's
    `Humanoid`, an instance that had just been destroyed. `BaseCamera:GetSubjectPosition()`
    can't read a usable position out of a destroyed subject, so it falls back to
    `self.lastSubjectPosition` — which is why the camera froze exactly where you left it
    rather than going black or erroring.

    This is also why the lobby always looked fine: respawning after a death goes through
    `LoadEmpty()`, which DOES call `LoadCharacterAsync`, the one path the engine hooks the
    camera up for. Only the hand-built arena spawn was affected.

    * Added `StarterPlayerScripts/Miscellaneous/CameraSubjectManager`: owns the local
      camera subject. Re-aims on every `CharacterAdded`, keeps re-aiming while the rig
      streams in (a `Humanoid` doesn't have a `RootPart` on the frame the model arrives),
      and runs a 4 Hz watchdog that repairs the subject whenever it stops being something
      you can see out of.

      The watchdog's test for "broken" is `not Subject:IsDescendantOf(workspace)` — a
      destroyed instance still answers property reads, so "does it have a value" proves
      nothing. That test is also why it leaves spectating, emote close-ups and the death
      ragdoll camera alone: every one of those points at something really in the world.

    * `PlayerManager._RespawnPlayer` now sets `PrimaryPart` on any rig that doesn't have
      one, falling back to `HumanoidRootPart` -> `Humanoid.RootPart` -> `Torso` -> any
      `BasePart`, and warns which it picked.

      Hand-built models very often ship without it, and it is a silent landmine:
      `Utils.Character.WaitForCharacterLoaded()` yields on
      `GetPropertyChangedSignal("PrimaryPart")`, so on a rig that never sets one EVERY
      `ObserveCharacter` callback waits forever — client ability loading, the killer
      intro's fade-out, the ability GUI. It also makes `PivotTo()` land the character on
      its spawn point accurately instead of by bounding-box centre.

    ------15/08/2026 (4)------
    ==================== AUDIT PASS ====================

    * `CameraSubjectManager` no longer depends on `PlayerInitter` reaching it. That initter
      requires every module under `PlayerScripts` in one loop with no `pcall` around any of
      them, so a single unrelated module erroring silently takes out everything after it.
      Added `StarterPlayerScripts/CameraSubjectFix` — a LocalScript that starts the manager
      directly. `Init()` is idempotent, so whichever runs first wins.

      It also prints one line on startup. If that line isn't in the Output, the fix isn't
      in the running place and nothing else about it is worth debugging.

    * `ServerCharacterManager._PositionCharacter` now returns whether it actually moved
      the character. Every failure path used to return nothing, so `SetupCharacter`
      couldn't tell a good spawn from a bad one and carried on regardless — leaving the
      body at `CFrame.new(0, 10, 0)`, which on most maps means falling out of the world
      the instant you spawn.

      From the player's seat that is indistinguishable from a broken camera: press PLAY,
      body vanishes, view doesn't move. `SetupFighter` now refuses the drop, `DropIntoMatch`
      puts the player back in the lobby, and the button says MAP HAS NO SPAWNS.

    * Added `RoundManager.Utils.DescribeSpawnPointProblem()`, reported both when the arena
      opens and in the startup setup report. A map with no `SpawnPoints` loads perfectly and
      looks completely fine right up until somebody presses PLAY.

    * `MapManager.GetRandomMap()`: off-by-one. The "keep only one spawn layout" cull read
      `#AvailableLayouts > 2`, so a map with exactly two layouts kept both. With two alive
      the layout is re-rolled per spawn, which defeats Free For All's "spawn away from
      everyone else" scoring (it only ever sees one layout's parts) and in classic mode
      lets the killer and survivors spawn from mismatched sets.

    * `CombatUtils.CreateZone()` captured the owner's character once and used it as the
      damage exclusion for the zone's whole lifetime. Zones outlive their caster — die on
      your own fallout, press PLAY, and you can be back in the arena while it's still
      ticking, at which point the exclusion is pointing at your corpse and your NEW body
      starts taking damage from your own ability. Re-read per tick.

    * `RoundManager` leaked on `PlayerRemoving`: `PlayersAccepted` is only ever cleared by
      `EndRound`, which never runs in Free For All, so it grew for the life of the server
      holding a strong reference to every player who ever pressed PLAY. `PlayersRemaining`
      and `PlayerConnections` were leaking the same way. All three are cleaned up now.

    * A failed drop left the player's replicated `RoundInfo.PlayersRemaining` entry behind,
      so the HUD counted a fighter who was standing in the lobby.

    Checked and found correct, for the record: every client-only `OwnerProperties` field
    (`FOVManager`, `TurnToMoveDirection`, `EffectManager`, `EmoteManager`, `InputManager`)
    is behind a `RunService:IsServer()` guard in all 11 killers — the server only ever
    populates `Character`, `Humanoid` and `HRP`. All six new effects use the real
    `ApplyEffect(own, level, char, duration)` parameter order. `Fragile` is correctly wired
    into `CommonFunctions.DamagePlayer`. No unresolved cross-module references.

    ------15/08/2026 (5)------
    ==================== PLAY TRACE ====================

    "Press PLAY, nothing happens, button disappears" has too many possible causes to keep
    guessing at, so the game now says which one it is.

    * Added `RoundManager.TracePlay` (on by default) and `RoundManager.Utils.Trace()`.
      Every PLAY press now prints a step-by-step account to the Output window under a
      `[PLAY]` prefix: who pressed, whether it was refused and why, which killer is
      equipped, whether the rig was found or a placeholder was used, whether a spawn point
      was reached, and the final world position of the body.

      It's a plain `print`, deliberately NOT `Utils.Misc.Print` — that one is gated behind
      the `DebugAllowed` workspace attribute, and this needs to work out of the box.
      Set `TracePlay = false` when the game is stable.

    * `PlayButton` now prints the server's answer, and specifically catches the case where
      there ISN'T one. `Network:FireServerConnection` returns nothing at all — silently —
      when the remote instance is missing on the client, which made the button appear to
      do nothing for no visible reason.

    * `PlayButton` gained a visibility watchdog. Its `ObserveCharacter` driver runs through
      `WaitForCharacterLoaded`, which yields until the character has a `PrimaryPart`, a
      `Humanoid` AND an `Animator` — a rig missing any of those never fires the callback,
      so a half-succeeded spawn could leave the button hidden permanently with no way back
      short of rejoining. Now: if you're a Spectator standing in the lobby, the button is
      on screen, whatever else happened.

    * `SetupFighter` returns a reason string alongside its `nil` so the button can say
      something specific instead of failing blank.

    ------15/08/2026 (6)------
    ==================== ANCHORED RIGS ====================

    The camera trace came back clean — body moved from the lobby to `1425, 512, -752`,
    subject correct, `CameraType=Custom` — and the player still couldn't move. That's a
    different bug wearing the same clothes.

    * `PlayerManager._RespawnPlayer` now unanchors every `BasePart` in a rig on spawn, and
      warns how many it had to undo.

      Models built by hand in Studio are almost always anchored — it's the only sane way to
      build one without it collapsing — and a single anchored part anywhere freezes the
      whole assembly. The Humanoid then reports a perfectly normal WalkSpeed and simply
      never moves.

      Classic mode hid this by accident: `SetupPlayer` anchored the root for the intro and
      `PlayIntro` unanchored it three seconds later, so anchored rigs got quietly fixed on
      the way in. The arena has no intro, so nothing was undoing it. `AntiFly` also treats
      an anchored root as "not flying" and skips its check, so nothing else complained.

    * Added `RoundManager.Utils.DescribeMobility()` to the PLAY trace, reported one second
      after a successful drop (`PlayerSpeedManager` drives WalkSpeed from `PreSimulation`,
      so reading it immediately would always report 0 and cry wolf). It names every reason
      a character can't walk: WalkSpeed, PlatformStand, Sit, anchored root, anchored parts.

    * `Shop`: two unchecked direct indexes, in the killer previews and the skin previews.
      `Model.Humanoid` and an unguarded `GetRootPart(...)` both THROW on a half-built model
      rather than returning nil, which killed the preview thread and orphaned a Camera and
      a WorldModel each time. Half-built models are the normal state of affairs while the
      roster is being made, so both now degrade to "no preview" with a warning naming what
      the model is missing. The preview animation is null-checked too.

    ------15/08/2026 (7)------
    ==================== SPAWN POINTS & THE `Role` RACE ====================

    The trace came back `NoSpawnPoints`. That was the real cause of "PLAY does nothing" all
    along — the arena had nowhere to put anybody.

    * `ServerCharacterManager._GetFreeForAllSpawn()` is now far more forgiving. It tries the
      chosen layout, then ANY `BasePart` under `SpawnPoints` however it's nested, then any
      `SpawnLocation` in the map. Free For All ignores role folders anyway, so there was
      never a reason to demand the exact template nesting —
      `SpawnPoints/Layout1/Killers/part`, `SpawnPoints/Killers/part` and
      `SpawnPoints/part` are all clear statements of intent and all work now.

      `RoundManager.Utils.DescribeSpawnPointProblem()` was relaxed to match exactly, so the
      setup report can't cry wolf about a map that actually works, and its message now
      spells out what to add.

    * REVERTED the destructive half of the previous entry's `MapManager` fix. Culling extra
      spawn layouts by DESTROYING them is dangerous: the template nests role folders inside
      a layout, but a map built as `SpawnPoints/Killers` + `SpawnPoints/Survivors` reads as
      "two layouts", and the cull would have deleted one of its two real spawn folders.

      It now records the choice as a `ChosenLayout` attribute and `_GetSpawnLayout()` reads
      it. Same result — one consistent layout — without touching anybody's map.

    ---- THE `Role` RACE ----

    Five separate stack traces in one session, all the same bug:
    CharacterStatsManager, PlayerList, RoundPlayerList, IntroHandler and Spectate all threw
    "attempt to index nil with 'Value'" reading `Character.Role.Value`.

    `Role` is a normal child, not an attribute. On the LOBBY body,
    `PlayerManager._RespawnPlayer`'s `LoadEmpty()` calls `LoadCharacterAsync()` — which
    parents the character to the world immediately — and only THEN creates `Role`. So the
    client sees the character a frame or two before `Role` arrives, and every callback that
    opens by reading it throws. (The killer path is fine: it parents `Role` to the model
    before the model is parented to the world, so they replicate together.)

    * `Utils.Character.WaitForCharacterLoaded()` now waits for `Role` as well as
      `PrimaryPart`, `Humanoid` and `Animator`. That is the gate every `ObserveCharacter`
      callback in the game passes through, so it fixes all five at the source. Ten-second
      timeout, because hanging forever would be worse than a nil.

    * Added `Utils.Character.GetRole(character)`, returning `nil` when the role isn't known
      yet, and used it at all five crash sites plus `TerrorRadiusManager`. Belt and braces:
      the gate above should mean it's never nil, but these read it every spawn.

    * `Utils.Player.GetClosestPlayerFromPosition()` and
      `Utils.Character.GetCharactersWithRoles()` both walk EVERY character in the world and
      both dereferenced without checking — one body mid-spawn broke targeting and the round
      count for everybody. `GetCharactersWithRoles` had the same problem with
      `FindFirstChildWhichIsA("Humanoid").Health`.

    ------16/08/2026------
    ==================== COUNTERATTACK ====================

    The game is now round-based, and it has a name.

    ---- REBRAND ----

    * `GameMode.Name` is "COUNTERATTACK", with a `Tagline` beside it. Everything
      player-facing reads from those two strings, so renaming the game again is a one-line
      edit. Four alternative names are listed in a comment right there.
    * Rojo project renamed `Counterfeit` -> `KillerRoyale`.
    * `FREE_FOR_ALL_SETUP.md` -> `KILLER_ROYALE_SETUP.md`, rewritten for rounds.
    * Rules menu and the player-facing changelog rewritten again — they described the open
      arena, which is no longer how the game is played.

    ---- ROUNDS ----

    There are now THREE modes behind two booleans, and nothing was deleted to get here:

      Enabled = true,  UseRounds = true    Counterattack. Rounds + intermission. <- LIVE
      Enabled = true,  UseRounds = false   Open arena. PLAY button, no rounds.
      Enabled = false                      Original Killer vs Survivors.

    * Added `RoundManager._StartRoyaleRound()`: everyone loaded is spawned as their
      equipped Killer, frozen for the intro, then let loose. Every spawn is in its own
      `pcall` — one bad rig must never abort the round, which was the original
      "fade to black and back to the lobby" bug and is now structurally impossible.

    * Added `RoundManager.Utils.CheckForRoyaleWin()`, on a 1 Hz loop. One fighter left wins
      it; nobody left is a draw. The loop rather than death hooks alone, so a player LEAVING
      the server still resolves the round.

    * Final two: the clock is cut to `FinalDuelTime` (60s) and the pair are revealed to each
      other, once, so a last two can't hide from each other for the full four minutes.

    * Added `ReturnToIntermission()` and `AbortStart()`. A round that can't start — too few
      players, no map, no spawn points, every rig failing — unwinds cleanly back to the
      lobby clock instead of leaving people on a black screen in a dead round.

    * `EndRound` now guards on `RoundState.Value ~= "InRound"` before doing anything. A
      death landing in the same frame as the round timer expiring used to pay out twice.

    * Death is elimination in this mode: no respawn cooldown, no re-entry, you're out until
      the next round. `RespawnLocks` is deliberately left untouched here.

    * Added `GrantRoyaleRewards()`: winner takes `WinReward` and a `KillerWins`; everyone
      else who made it into the round takes `ParticipationReward`, so a bad round is never
      a total loss.

    * PLAY button and its remote are switched off (not deleted) when `UseRounds` is true.
      `UI/Time` goes back to showing the real clock instead of the fighter count.

    Verified by simulating the state machine over 11 scenarios: normal round, too few
    players, clock expiry, the death+timer double-payout race, mass disconnect, winning by
    opponent disconnect, total spawn failure, partial spawn failure, missing map,
    back-to-back rounds, and final-two announcing exactly once. All pass.

    ---- OWNER PERKS ----

    * Added `ServerScriptService/Managers/OwnerPerks`: named accounts are held at ten
      billion money. The real `Currency.Money` stat is set and then re-asserted whenever
      anything spends it, so shops and prices keep working normally and the balance simply
      never drops. A large number rather than `math.huge` because infinity doesn't survive
      a DataStore round trip and renders as "inf" in the leaderstat.

      Currently listed: UNIOPAY5, matched by username. Add a `UserId` to that entry when
      convenient — usernames can be changed, and the perk would then follow whoever took
      the old name.

    ------16/08/2026 (2)------
    ==================== ESCALATION & THE OVERSEER ====================

    ---- KILL ESCALATION ----

    Added `ReplicatedStorage/Modules/KillEscalation`. Two layers stacked:

      * A small linear boost per kill — +2% max health, +2% damage, +1.5% speed. Stops
        compounding at 10 kills (`SoftCap`).
      * Named perks at 3 / 5 / 7 / 10: BLOODSCENT (see everyone through walls),
        SECOND WIND (kills heal a third of max), FRENZY (cooldowns x0.65, -15% damage
        taken), APEX (doubles everything accrued).

    All of it dies with you. It lives and dies inside one round.

    The health boost is a FRACTION of starting max health, not a flat number: the roster
    runs ~900-1400 health, so a flat bonus would quietly mean something different depending
    on who you picked. The base is captured once on the first kill so the tenth kill is
    worth the same as the first rather than compounding off the running total.

    Anti-snowball, deliberately: the per-kill layer is tiny and capped; every perk tier
    reveals you to the entire server, so power costs you your anonymity in a room where
    everyone can hurt everyone; and dying takes all of it at once with no decay.

    Modelled the curve before shipping it — a 10-kill APEX fighter is 2.35x an untouched
    one in effective HP-per-damage terms. Noticeable, still killable, and visible to
    everybody.

    * `CommonFunctions.DamagePlayer` gained two attribute-driven modifiers:
      `EscalationResistance` (read exactly like the engine's own `Resistance` so the two
      stack predictably) and `EscalationDamageMultiplier`, applied LAST so it scales the
      final number after the target's defences — it makes the attacker stronger rather
      than making the target's armour worse.

    * `Ability:SetOnCooldown()` now reads a `CooldownMultiplier` attribute off the owner's
      character. `0.65` = 35% faster; `0` removes cooldowns entirely. Held on the character
      rather than the ability so anything can grant it and so it dies with the body.

    ---- THE OVERSEER (owner-only) ----

    Added `ReplicatedStorage/Characters/Killers/Overseer`. Not balanced, and not meant to be.

      ARMAGEDDON (Q)  — kills every other fighter in the map. No range, no cooldown.
      DECIMATE (E)    — wide instant blast, applies Burning and Fragile.
      OMNISCIENCE (R) — everyone's aura through everything, for ten minutes.
      Passive         — no cooldowns at all, 50,000 health, stun-immune.

    Access is enforced in THREE independent places, because a killer that ends the round
    on a keypress is exactly what an exploiter would go hunting for:

      1. `RoundManager.Utils.ResolveKillerFor()` refuses to spawn a non-owner as any
         character flagged `Config.OwnerOnly`, and falls them back to `FallbackKiller`.
         This is the important one — it stops the body ever existing.
      2. The character's `OnInit` kills the body of any non-owner wearing it.
      3. Every ability behaviour re-checks on the server on every single use.

    The abilities run server-side, so a faked remote gets it re-checked rather than trusted.

    Hidden from the shop with the engine's existing `Dev` tag (`Shop.SetupCard` already
    skips those), and granted to owners by `OwnerPerks._GrantKillers` using the same
    `PreventSave` NumberValue that `DevItemGrantingManager` uses — so access is decided by
    the owner list every session rather than frozen into a save file. Remove someone from
    the list and they actually lose it.

    ------16/08/2026 (3)------
    ==================== COUNTERATTACK & SERVER HOPPING ====================

    * Renamed again: KILLER ROYALE -> COUNTERATTACK. `GameMode.Name`, the Rojo project,
      and `KILLER_ROYALE_SETUP.md` -> `COUNTERATTACK_SETUP.md`.

    * `OwnerPerks` now matches on UserId (5321643116) rather than username. The username is
      kept beside it for readability only. This matters: usernames can be changed, and the
      perks would otherwise follow whoever picked up the old one.

    ---- SERVER HOPPING ----

    Added `ServerScriptService/Managers/ServerHopper`. A server that can't fill a round
    moves its players into one that can.

    WHY MEMORYSTORE: the obvious approach — asking Roblox's web API which servers are
    running — is impossible from inside a game. `HttpService` refuses requests to
    roblox.com domains and there's no in-engine equivalent. So servers tell each other
    instead: every server writes its JobId and headcount into a `MemoryStoreService` sorted
    map on a 15s heartbeat with a 60s TTL, and a lonely server reads that map and teleports
    into the best entry by JobId. A dead server ages out rather than leaving a ghost entry
    for people to be sent to.

    Four rules, because getting this wrong is worse than not having it — two half-empty
    servers can spend all day throwing players at each other:

      1. Never move toward a SMALLER server. On a tie, the lexicographically smaller JobId
         moves to the larger and never the reverse. String ordering is a total order, so no
         set of servers can form a cycle — two one-player servers reliably become one
         two-player server instead of swapping forever.
      2. Everyone has to fit under `Players.MaxPlayers`, or we don't go.
      3. 45 seconds of being under-populated before anything happens, so a server that's
         briefly quiet between rounds isn't torn down.
      4. Never mid-round, and never while anyone is still loading — teleporting someone
         mid-load drops them on the error screen.

    Inert in Studio, since `TeleportService` doesn't work there.

    Modelled the fleet over 9 configurations before shipping: three lonely servers, two
    lonely, equal-but-healthy, a cascade, a near-full target, five and eight lonely servers,
    a single isolated server, and a genuinely full target. All converge, none cycle, and
    capacity is never exceeded.

    ------16/08/2026 (4)------
    ==================== ROUND CONTROL PANEL ====================

    Added an admin panel for starting rounds by hand, so the game can be tested alone.
    Normally a round can't start until `MinimumFighters` players have loaded, which makes
    solo testing impossible.

    * `StarterPlayerScripts/UI/AdminRoundPanel` — a small floating panel with START ROUND,
      END ROUND, SKIP INTERMISSION and TOGGLE SOLO MODE, plus a live status line. F2 hides
      it.

      Built in code rather than added to the engine's ModPanel. That panel clones
      hand-authored Studio UI (`Bool.luau` does `script:FindFirstChildWhichIsA("ImageLabel")`)
      and only registers a `Bool` prefab, so a new control type can't be built or tested
      without doing Studio work first. This has no such dependency.

    * `ServerScriptService/RemoteHandler/AdminRoundControl` — all the authority. The panel
      hiding its buttons is presentation, not security; every action re-checks permission
      server-side, because an exploiter can unhide a button in a second.

      Allowed: anyone in `OwnerPerks.Owners`, anyone at ServerOwner rank in
      `CommonFunctions.AdminPerms`, and anybody in Studio.

    * `RoundManager.StartRound(force)` / `_StartRoyaleRound(force)` skip the HEADCOUNT
      check only. The map, the spawn points and every individual spawn are still verified
      exactly as normal — those failing would break the round for real rather than just
      make it a lonely one.

    * THE IMPORTANT BIT: `CurrentRound.SoloTest`. A forced round with one player would
      otherwise hit `CheckForRoyaleWin`, see a single fighter alive, declare them the
      winner and end on the very first tick — making the feature useless for the one thing
      it exists for. In a solo test the last-fighter-standing condition and the final-two
      clock cut are both suspended; the round runs until the clock expires or the tester
      dies.

    Verified over 6 scenarios: a forced solo round survives repeated win checks, ends when
    the tester dies, ends on the clock, and a forced round with a real lobby is NOT flagged
    solo and keeps normal win rules. Unforced solo starts are still refused.

    ------16/08/2026 (5)------
    ==================== THE ROUND THAT NEVER ENDED ====================

    Reported as: "it teleports you to the map, then back into the lobby, or into the void,
    or some weird place — and nothing shows up in the logs."

    ROOT CAUSE — `EndRound` cancelled the thread that was running it.

    `Threads["WinCheckLoop"]` is the 1 Hz loop that notices the last fighter standing, and
    it calls `CheckForRoyaleWin` -> `EndRound`. `EndRound` then iterated `Threads` and
    `task.cancel`ed every entry — including the one currently executing it.

    `task.cancel(coroutine.running())` kills the thread mid-function and is NOT an error,
    so nothing was printed and nothing caught it. Which is exactly why the logs were empty.

    Every line after that point was skipped:
      * players were never returned to the lobby
      * `PlayersRemaining` was never cleared
      * `MapManager.DestroyCurrentMap()` NEVER RAN
      * the lobby clock was never restarted

    The next round then cloned a SECOND map into the workspace, both named "Map".
    Everything downstream finds the arena with `workspace:FindFirstChild("Map")`, which
    returns one instance arbitrarily — so spawn points could be read from one map while the
    geometry players could see was the other. Hence the lobby, the void, and "some weird
    place". Nothing errored at any point; it just quietly stopped making sense.

    * FIXED: `EndRound` now skips `coroutine.running()` when cancelling. `StopLoop` already
      tells the win-check loop to exit on its own next iteration, so nothing is lost.
      Unrelated threads are still cancelled as before.

    * BELT AND BRACES: `MapManager.GetRandomMap()` now destroys any map still standing in
      the workspace before parenting a new one, and warns when it has to. Two maps named
      "Map" is a silent catastrophe and "the teardown is supposed to have run" turned out
      not to be good enough.

    ---- 1x1x1x1's DELETE ----

    * It only takes FLOOR now. It used to take any anchored, collidable part in the box,
      so walls, pillars and props went with it — 1x1x1x1 could open a hole in a wall and
      walk through. A part is skipped unless its top surface sits at or below where he's
      aiming.

    * It will never touch anything under a `SpawnPoints` folder. Belt and braces, but
      anything that can break where players spawn is worth being paranoid about.

    * The restore is a raw `task.delay` rather than `self:AddConnection`. `AddConnection`
      hands the thread to the ability's Janitor, which CANCELS it when the character is
      destroyed — so dying, or the round ending, within the 6-second hole duration meant
      the floor never came back at all. Cleanup that must happen has to outlive its caller.

    For the record: it never destroyed anything. It sets `Transparency` and `CanCollide`
    and puts both back exactly as they were.

    ------16/08/2026 (6)------
    ==================== DELETE IS GONE ====================

    1x1x1x1's DELETE has been removed outright and replaced. It is not restricted, not
    made safer — it no longer exists. No ability on the roster touches arena geometry now.

    The reasoning is worth writing down: an ability that edits the world can outlive the
    round that cast it. Every other kind of mistake is scoped to a character or a fight,
    and cleans itself up when they end. That one wasn't, and it's not a class of risk worth
    carrying for one mechanic.

    ---- CRASH (R) ----

    Everyone within 34 studs loses their abilities for 6 seconds. Q, E and R stop
    responding entirely; basic attacks still work. 38 damage and Fragile II on top.

    It fits him better than the hole did. Every other killer takes your health — this one
    takes the buttons you were going to use to keep it.

    * Added an `AbilitiesLocked` character attribute, read in `Ability:CanUse()` alongside
      the existing `PreventSlash`. Implemented in the engine rather than in the character
      so anything can use it later.

      Slash is deliberately exempt. Taking someone's abilities is a strong play; taking
      their ability to fight back at all is a stun, and `Stunned` already exists for that.

    * The unlock is a raw `task.delay`, not `self:AddConnection` — same reasoning as the
      floor restore before it. `AddConnection` hands the thread to the ability's Janitor,
      which cancels it when the caster's character is destroyed. 1x1x1x1 dying inside the
      lock window would otherwise have left his victims with dead abilities for the rest of
      the round and nothing alive to undo it.

    * Caught on the way out: `CommonFunctions` and `TweenService` weren't imported in
      `1x1x1x1.luau` — CRASH would have thrown on first use. Swept all 11 killers for the
      same class of mistake afterwards; nothing else uses a module it doesn't import.

    ------16/08/2026 (7)------
    ==================== THE LOADING SCREEN ====================

    Reported as: no walking animation in the lobby, loading takes forever so you press
    Skip, and afterwards the Inventory won't open.

    All one bug. `ReplicatedFirst/Loading.client.luau` had:

        while #loadedAssets < #assets - 100 or loaded do

    That `or loaded` is inverted. Pressing Skip set `loaded = true`, which made the
    condition permanently TRUE — the loop never exited and NOTHING below it ever ran.

    Below it is `InitScripts`, which starts `PlayerInitter`, which is what runs every UI
    module AND `CharacterInitter` — and `CharacterInitter` is what calls
    `AnimationManager:Init()` on your character. So skipping cost you the walk animation
    and every menu in one go. One word.

    * FIXED to `and not Skipped`. Skip now only abandons the ASSET PRELOAD; initialisation
      still runs, and the loading screen stays up until the game is genuinely ready. It
      used to call `Finish()` straight from the click handler, tearing the screen down
      before anything had started.

    * `PlayerInitter` now `pcall`s each module's `require` and `Init` separately and warns
      by full name on failure. It ran them bare, so ONE module erroring took out every
      module after it in the iteration — and because `Loaded` is set on the last line of
      that loop, it never got set, and the loading screen hung forever waiting for an
      initialisation that had already died. That is the "takes forever to load".

      `ServerScriptService.Initter` has always done this. The client just never did. This
      is also why the camera fix earlier needed its own LocalScript bootstrap — that
      workaround is no longer load-bearing, though it does no harm.

    * Three timeouts added, because a frozen loading screen tells the player nothing:
        * the asset preload gives up after 45s and warns with a count
        * each initter gives up after 60s and warns which module it was stuck on
        * `Finish()` is now idempotent, and the early `if loaded then return end` before it
          is gone — that could leave `ClientLoaded` never set at all

    ------16/08/2026 (8)------
    ==================== NO SHOP, NO SURVIVORS ====================

    ---- THE EMPTY INVENTORY ----

    Reported as: everything loads, but the Killers tab in the Inventory is empty.

    Two causes, stacked.

    1. `Inventory.ReloadContent` ran `SetupBatch("Survivor")` BEFORE `SetupBatch("Killer")`,
       and `SetupBatch` did:

           table.insert(Ordered, Utils.Instance.GetCharacterModule(Type, module.Name))

       `GetCharacterModule` returns nil for a character that no longer exists, and
       `table.insert(t, nil)` THROWS in Luau. So one stale entry in `Purchased.Survivors` —
       a survivor that was removed or renamed — killed the whole function before the KILLER
       list was ever built. The tab came up empty with nothing the player could see.

       Now: nil modules are skipped with a warning naming the entry, and each batch is its
       own `pcall` so a future category can never take the killer list down again.

    2. `Inventory.SelectedSection` defaulted to `"Survivors"` — in both the initial table
       and the reset in `Toggle` — so even a working inventory opened on the wrong tab.
       Both now default to `"Killers"`.

    ---- SURVIVORS REMOVED FROM THE UI ----

    * Inventory: the survivor container is hidden, its topbar tab is hidden, and it's out
      of the `Sections` list so tab-switching never selects it.
    * Shop: `SetupBatch("Survivor")` commented out, survivor container hidden,
      `SelectedSection` moved to Killers.

    Everyone is a killer here, so a survivor list is a tab full of characters nobody can
    play. Containers are hidden rather than destroyed so switching `GameMode.Enabled` back
    to the original Killer-vs-Survivors game only needs these few lines reverted.

    ---- SHOP REMOVED ----

    * `SideBar`: the `Shop` button entry is commented out. Killers aren't bought here.
    * `Shop.Enabled = false`, and `Shop:Init()` now returns early on it.

      That second part is worth having on its own: `Shop:Init` cloned its whole UI and
      built a card — with a ViewportFrame preview each — for every character on join. That
      was time on the loading screen for a menu nobody can now open.

    Both are switched off, not deleted. `Enabled = true` plus five uncommented lines in
    `SideBar.luau` brings the shop back exactly as it was.

    ------16/08/2026 (9)------
    ==================== THE INVISIBLE KILLER TAB ====================

    The empty Killers tab had a THIRD cause, and it's the one that was actually still
    biting after the previous two were fixed.

    Nothing in `Inventory:Init` ever set `KillerContainer.Visible`. The `InventoryUI`
    prefab is authored in Studio with one container already visible — the survivor one,
    because that used to be the default section — and `SwitchSection` is the only thing
    that ever changes it. `SwitchSection` early-returns on the already-selected section:

        if not Inventory.Opened or Inventory.SelectedSection == sectionName then return end

    So once the default moved to Killers, clicking the Killers tab did nothing at all and
    the container stayed hidden. The cards were being built correctly the whole time and
    parented into an invisible frame.

    * `Init` now applies the starting section's visibility from `SelectedSection`, so the
      code decides what's on screen rather than whatever state the prefab was saved in.
      Same fix applied to the Shop for whenever it's switched back on.

    * Added a diagnostic line on every `ReloadContent`, printing the card count, the number
      of `Purchased` entries, whether the container is visible, and the selected section.
      An empty tab has four possible causes that look identical on screen; this separates
      them at a glance.

    Worth noting for the record: all three causes produced exactly the same symptom, which
    is why fixing the first two changed nothing visible.

    ------16/08/2026 (10)------
    ==================== SWEEP ====================

    Scanned the whole client for the bug classes that have actually bitten in this project,
    rather than for style. Four classes, and the ones with real blast radius are fixed.

    ---- `Role.Value` derefs that run automatically ----

    `Role` is a normal child, so `Char.Role.Value` THROWS when it hasn't replicated. Fixed
    the ones that run on every character spawn, worst first:

      * `SideBar` (x2) — the biggest. It runs on every spawn and if it throws the whole
        sidebar dies, taking EVERY menu with it.
      * `CharacterManager` — ability and animation loading.
      * `EffectViewer`, `ChatHistoryToggle`, `CameraShakeOnDamage`.

    Left alone: the `Open()` guards in the menus. They read
    `not LocalPlayer.Character.Role or ...`, which short-circuits, and they only run on a
    user click long after the role exists.

    ---- `require(GetCharacterModule(...))` on other people's characters ----

    `GetCharacterModule` returns nil for a missing character and `require(nil)` throws.
    These matter because they walk EVERY character in the world, so one bad entry breaks
    the feature for everybody rather than for one player:

      * `FootstepPlayer` — also had a raw `character.Role.Value` on the same line.
      * `TerrorRadiusManager:Init`.
      * `TerrorRadiusManager:_CheckAsSurvivor` — the worst of them. It's inside a
        `PreRender` loop, so a killer with no module would have thrown on EVERY FRAME.

    ---- `RoundPlayerList` was permanently empty ----

    It filtered for `Role.Value ~= "Survivor"` and asked for `"Survivor"` modules. There
    are no survivors in Counterattack, so the round list never had a single entry. It now
    reads the role the fighters actually have, which keeps it correct in the classic game
    too, and both module lookups are nil-guarded.

    ---- Checked and found fine ----

    All 44 `AddConnection(task.delay(...))` sites were inspected for the "cleanup cancelled
    when the caster dies" trap that bit the 1x1x1x1 floor restore and the CRASH lock. Every
    remaining one restores state on its OWN caster — FOV, speed factors, head-turn locks —
    which is exactly what SHOULD die with them. No further changes needed.

    ------16/08/2026 (11)------
    ==================== TEST-MODE MEMORY & SOLO ROUNDS ====================

    Reported as: works in Play with a server and client, but eats all the memory — and in
    plain test mode it doesn't work at all. Two separate causes.

    ---- MEMORY ----

    `ReplicatedFirst/Loading` collected EVERY descendant of Workspace, ReplicatedStorage,
    StarterPlayer and StarterGui and handed each one to `ContentProvider:PreloadAsync`
    individually — Folders, Scripts, Values, Motor6Ds and all.

    Two costs. Most of those hold no content, so the call does nothing but burn a round
    trip; and everything that IS content gets pulled into the cache up front whether the
    player ever sees it or not.

    * Filtered to the classes that actually carry a content ID (Decal, Texture, Sound,
      MeshPart, SpecialMesh, ImageLabel, ParticleEmitter, Animation and friends). Not one
      asset that matters is preloaded any less.

    * In Studio the workspace sweep is skipped entirely. A test session runs a server and a
      client process side by side, each with a full copy of everything — the map is by far
      the largest thing in the world and Roblox streams it on demand perfectly well.
      Published servers still preload the lot; players there run one process.

    * Guarded the progress readout against an empty asset list, which the filter now makes
      reachable — it would have printed "nan%".

    ---- SOLO TEST ----

    A solo session has exactly one player, and `MinimumFighters` is 2. The lobby clock sat
    on "Waiting for fighters..." forever and no round ever started.

    * Added `GameMode.GetMinimumFighters()`, returning 1 in Studio while
      `Config.SoloInStudio` is true. Rounds now start on their own in a test session with
      nothing to press.

      Deliberately a FUNCTION, not a value overwritten in `GameMode:Init`. That would only
      have worked if `GameMode:Init` ran before `RoundManager:Init` copies the number into
      `TimeManager` — and nothing guarantees that order, since one lives in
      ReplicatedStorage and the other in ServerScriptService. Resolving at the point of use
      removes the dependency instead of betting on it.

    * All five read sites in `RoundManager` and the admin panel's status line now go
      through it, so the panel reports the number actually in force.

    ------16/08/2026 (12)------
    ==================== THE SHOP UI, EXTRACTED ====================

    The shop's UI now lives in this repository. It syncs with everything else and needs no
    Studio work at all.

    `DysymmetricalExamplePlace.rbxl` was sitting in the repo root the whole time. Rather
    than asking for the usual copy-paste out of it, the two instances the shop needs were
    read straight out of the place file and written next to the code Rojo already syncs:

        src/StarterPlayerScripts/UI/Shop/ShopUI.rbxmx      125 instances
        src/StarterPlayerScripts/UI/Shop/Templates.rbxmx    29 instances

    Rojo maps a `.rbxmx` sibling of `init.luau` as a child of that module, which is exactly
    where `Utils.Instance.FindFirstChild(script, "ShopUI")` looks. Nothing in the shop code
    changed.

    HOW: `.rbxl` is a binary format — LZ4-compressed chunks, transposed numeric arrays,
    zig-zag encoded integers, floats with the sign bit rotated to the bottom. Writing a
    reader for it turned up two encoding details worth recording:

      * UDim2 is stored as FOUR arrays in the order X.Scale, Y.Scale, X.Offset, Y.Offset —
        not scale-then-offset per axis. Reading it the intuitive way puts float bit
        patterns in the offsets: 0.5 comes out as 1056964608.
      * Properties like `Image`, `TopImage` and `BottomImage` are `ContentId`, not String,
        and the XML reader rejects a plain `<string>` for them. Detected by name suffix
        rather than a fixed list — ScrollingFrame alone has three of them.

    VERIFIED by round trip, not by assumption: the built place was parsed back with the
    same reader and compared against the source.

      * 125 and 29 instances, exactly as in the source place
      * every instance name matches
      * 346 property values compared across Size, Position, colours, transparency, text,
        images, ZIndex, AnchorPoint and rotation — ALL IDENTICAL

    The example place was only ever read from. Nothing in it was modified or removed.

    NOT extracted: every other menu's prefabs (SideBar, Inventory, Settings, ModPanel and
    the rest) are still Studio assets in your own place, and they work. Pulling them into
    the repo would overwrite whatever you have there, which is a real risk for no gain —
    the shop was the only one actually missing.

    ------19/08/2026------
    ==================== THE SHOP, RESTORED FROM THE EXAMPLE PLACE ====================

    `UI/Shop` is now byte-identical to `example-palce/Dysymmetrical-main`. Every local
    modification to `init.luau` was discarded — the accumulated fixes had not produced a
    working shop, so the engine's own copy replaces them wholesale.

    KEPT, and deliberately so: `ShopUI.rbxmx` and `Templates.rbxmx`. The example place
    ships neither — upstream expects them copied out of the `.rbxl` by hand in Studio —
    and without them there is no shop UI at all. They stay exactly where (12) put them.

    ---- WHAT THE RESTORE TAKES BACK ----

    The engine's `Shop:Init` has no `if not Shop.Enabled then return end`, so the bug the
    previous entry described cannot occur in it: `Toggle` destroying the UI on a non-
    spectator spawn and the rebuild silently refusing to run. That whole failure was
    introduced locally by the "SHOP REMOVED" kill switch in (12) and is gone with it.

    Also gone: the local preflight, the Inventory-templates fallback, the `Failed` flag and
    the skin-preview nil guards. `SideBar` still reads `Menu.Failed`; on the engine's shop
    that field is simply never set, so the button is always built — which is the behaviour
    the engine has always had.

    ---- WHAT YOU WILL SEE THAT IS DIFFERENT ----

    THE SHOP OPENS ON SURVIVORS. `SelectedSection` is `"Survivors"`, `Sections` contains
    all three containers, and `ReloadContent` runs `SetupBatch("Survivor")`.

    This is consistent, not broken: `ShopUI.rbxmx` is saved with `Content.Survivors`
    visible and `Killers`/`Emotes` hidden, and `SwitchSection` early-returns on the already
    selected section. The engine's default matches the prefab it ships with. (11) hid
    survivors and moved the default to Killers WITHOUT touching the prefab, which is what
    made tabs open blank — the two halves disagreed.

    So the shop will list Commander alongside the killers. If survivors should be out of
    the UI again, that is a deliberate re-edit of the restored file, not a bug to chase.

    ---- CHECKED AGAINST THIS FORK ----

    * Both files parse. Verified with `luau` 0.737.0, not by eye.
    * `Utils.UDim.Zero/FullY/Full/Full20Offset`, `Utils.Character.GetRootPart` /
      `LoadAnimationFromID`, `Utils.Instance.GetCharacterModule` / `GetEmoteModule` /
      `ObserveProperty` / `FindFirstChild`, `Utils.PlayerData.GetPlayerOwned` /
      `GetPlayerSetting` — all present.
    * `PlayerData/Purchased/{Killers,Survivors,Emotes,Skins}` and
      `PlayerData/Settings/Performance/SkinPreviews` — all present.
    * `ReplicatedStorage.Assets.Characters`, `.Assets.Emotes`, `.Characters.Killers`,
      `.Characters.Survivors` — all present, so nothing the module reads at require time
      or in `ReloadContent` is missing.
    * `SetupCard` reads `Config.Name`, `Config.Render` and `Config.Price`. `Commander` and
      `TPose` declare none of the last two, but `Character.GetDefaultSettings` and
      `Emote.GetDefaultSettings` fill them in through `DeepTableOverwrite`, so the cards
      build. Nothing needs editing.
    * `ShopUI.rbxmx` still carries every instance `Init` reaches for — the three section
      containers and their topbar buttons, `SideContainer.ButtonsContainer.{Purchase,
      Skins,MoreInfo}`, `PreviewContainer.{Render,Title,Emote.EmotePreview.Rig}`,
      `SkinsContainer.Content`, `InfoContainer.Contents` — and `Templates.rbxmx` all six
      prefabs. Rojo maps both in as children of the module; `rojo sourcemap` confirms it.

    NOT verified: any of this in a running game. If the shop still does not appear, the
    client Output now says why in one line — `[SideBar] The "Shop" menu failed to load` if
    the module threw, or a `[PlayerInitter]` warning naming `Shop:Init()` if it built
    badly. That message is the next thing worth reading.

    ---------------------------- STUDIO SETUP NEEDED ----------------------------

    * Build a rig for each new killer under `ReplicatedStorage/Assets/Characters/Killer`.
      The model name MUST match the module name exactly (`Verity`, `MiniGunner`,
      `1x1x1x1`, ...) or `PlayerManager._RespawnPlayer` can't find it.
    * Build at least one arena map in `ServerStorage/Maps`. Spawn points matter more
      than they used to — see `FREE_FOR_ALL_SETUP.md` in the repo root.
    * Add the new killers to `ServerScriptService/Managers/SaveManager/PlayerData` under
      `Purchased/Killers` if you want them free, or leave them to be bought in the shop.

    ------04/10/2026------
    ============== ALL 32 KILLERS REWORKED, AND THE SHOP ACTUALLY FIXED ==============

    ---- THE SHOP ----

    The previous entry restored `UI/Shop` byte-identical from the example place and said the
    local fixes were discarded because they "had not produced a working shop". The restore
    could not have worked either, and the reason was never in `UI/Shop` at all:

      1. `Characters/Killers/1x1x1x1.luau` threw on require. It called
         `Character.CreateKiller({...})` without assigning the result, then referenced an
         undeclared `OneXOne` twelve times.
      2. The old shop sorted the roster with `require` calls inside a `table.sort`
         comparator. A comparator that throws aborts the sort, so ONE bad module emptied the
         ENTIRE killer list. That is why the tabs opened blank.
      3. `BuyWindow.luau` did `script:FindFirstChild("Window"):Clone()`. The `Window` prefab
         is not in the repo — only `ShopUI.rbxmx` and `Templates.rbxmx` were ever exported
         — so every purchase attempt indexed nil.

    All three are fixed, and the class of bug is fixed with them: the roster now comes from
    `ReplicatedStorage/Modules/CharacterRegistry`, which `pcall`s each require. A character
    module that throws costs THAT CHARACTER and nothing else. `BuyWindow` prefers the Studio
    prefab and builds its own window procedurally when it is absent, so the shop no longer
    depends on an asset that is not in version control.

    `CharacterRegistry` is now the single authoritative roster. The shop, the inventory,
    `BuyItem`, `EquipItem` and `SaveManager` all read it, so there is no second hardcoded
    killer list to drift. New killers appear in the shop with no edit to the shop.

    ---- A DATASTORE BUG THAT WAS SILENTLY LOSING SAVES ----

    `SaveManager.Save` read `script:FindFirstChild("Equipped")`, which is nil — the real
    path is `script.PlayerData.Equipped` — and then threw inside a `task.spawn`, where
    nothing surfaces it. `Load` wrote `Equipped.Killer.Value = ""` whenever a player's
    equipped killer no longer existed, which is exactly what triggers that throw.

    So one renamed or removed killer stopped a player's data saving. Forever, silently.
    Both halves are fixed and both now fall back through `CharacterRegistry.GetFallback`.

    ---- SERVER AUTHORITY ----

    `BuyItem` used to derive the item type by walking `Module.Parent.Parent.Parent.Name`
    with no check, and read the PRICE off the client-chosen module. A client could hand it
    any ModuleScript in `ReplicatedStorage`. It now validates the instance structurally
    against the registry (`Resolve` / `ResolveSkin`) and takes the price from the registry,
    never the caller. Already-owned and negative-price cases are handled explicitly.

    `EquipItem` checks EXISTENCE before ownership, because a `Purchased` entry outlives a
    renamed module.

    ---- WHAT THE KILLERS DO NOW ----

    All 32 named killers were reworked to play like what they are based on rather than
    sharing one dash-and-projectile kit. Every one has a distinct basic attack, three
    abilities, a passive, and a stated weakness. Five shared services were added so that is
    32 kits and not 32 ability engines: `ProjectileService`, `DeployableService`,
    `SummonService`, `MeterService`, `AbilityFX`, plus `AbilityClient` for the camera work.

    Deployables are the useful trick: a deployable is a `Model` with a `Humanoid` and a
    `HumanoidRootPart` carrying `HitboxPriority`, so EVERY killer's normal attack can
    already destroy them. `Classes/Hitbox` needed no change at all.

    All three services are cleared in `MapManager.DestroyCurrentMap`, which is the one
    function all three teardown call sites go through.

    ---- BALANCE ----

    Two characters were upper-quartile in health AND speed AND sustained damage at once:
      * Superman  1600 HP / 11.5 speed / 2.2s punch  ->  1500 / 11 / 2.9s. Still the hardest
        single swing in the game, now the slowest-cycling one.
      * Shadow    1420 HP  ->  1100. Speed is his identity and the tooltip leads with it, so
        durability was the lever. He is a glass cannon now.

    Shadow's `TooltipText` also ended mid-sentence ("The closest ") and now completes.

    Melee basic-attack damage spans 2.65x across the 35 melee killers, health 1.68x (Sans
    excepted at 650 by design — the Dodge meter is what pays for it), base speed 1.29x.

    ---- CORRECTIONS TO THE PREVIOUS ENTRY'S SETUP NOTES ----

    * The shop no longer needs the `Window` prefab copied out of Studio. It still USES it if
      you put it there.
    * `Purchased/Killers` under `SaveManager/PlayerData` no longer needs new killers added by
      hand to avoid breaking saves. It is still how you make one free.
    * Rigs are still required: `ReplicatedStorage/Assets/Characters/Killer/<ModuleName>`,
      name matching the module EXACTLY. This has not changed and is the one remaining
      Studio-side step for the reworked roster.

    ------05/10/2026------
    ======== WEATHER TRIMMED, NPCs WITHOUT HUMANOIDS, PANELS LOCKED TO THE OWNER ========

    ---- WEATHER: NO MORE BLINDING EVENTS ----

    SANDSTORM and BLIZZARD are deleted. Both were full-screen whiteout events with a heavy
    vignette over the top, and in a fighting arena that is the worst thing weather can do:
    everything else in the pool you can see coming and move away from, those two just took
    the screen away and handed the fight to whoever guessed right.

    The pool is nine, and FLASH FLOOD, TORNADO, METEOR SHOWER and VOLCANIC ERUPTION are now
    the four it is tuned around. They were already written and they were the WEAKEST-looking
    events in the game, because the sandstorm and the blizzard were the only two that ever
    asked for particles or a vignette. Three of the four were drawing neither.

      * Tornado now throws up Dust and a Dust vignette, plus screen shake. That is the
        sandstorm's presentation, and it belongs on a funnel tearing across an arena far
        more than on a weather front — and you can still SEE the tornado through it.
      * Meteor Shower gets Embers and an Ember vignette.
      * Flash Flood and Tsunami get a Water vignette; Tsunami also gets rain.
      * Volcanic Eruption gets an Ash vignette on both of its phases.

    `WeatherHUD.Vignettes` is now a vocabulary of four rather than one blizzard special
    case, and every entry tops out at 0.5 transparency. On purpose: a vignette should say
    something is happening at the edges of the world, never stop you fighting.

    Also removed with them: the `WeatherExposure` attribute and the per-respawn
    `GetAttributeChangedSignal` listener that watched it (nothing writes it now), and the
    `Snow` and `Sand` particle presets. `MaxSimultaneousEvents` is 9, down from 11 — a
    ceiling above the pool size meant the last two escalation steps silently did nothing
    while the log claimed otherwise.

    ---- NPCs: NO HUMANOID, SO NOTHING TO FALL OFF ----

    NEW: `ReplicatedStorage/Modules/NPCService`.

    An NPC there is a model of ANCHORED parts, posed by writing `CFrame` directly, animated
    by a function of elapsed time, with health in an attribute. No `Humanoid`, no `Motor6D`
    joints, no physics assembly, no state machine, no `LoadAnimation`.

    That is four engine systems removed, and each one was a real failure:

      1. THE PHYSICS ASSEMBLY. The Events Panel's cinematic dummy did
         `part.Anchored = (part.Name == "HumanoidRootPart")`, which anchors the root and
         UNANCHORS every limb. With a live Humanoid holding them by joints the limbs sag,
         detach and fall through the floor. That is the "assets dropping" report: parts of
         an NPC arriving on the ground separately from the NPC.
      2. THE STATE MACHINE. A Humanoid decides every frame whether it is Running, Freefall
         or Ragdoll and acts on it. An NPC standing on something that gets deleted leaves.
      3. `LoadAnimation`. Needs a real, public, correctly-typed animation asset, and fails
         SILENTLY otherwise — no error, no warning, a dummy frozen mid-T-pose for the whole
         six seconds. `NPCService.Motion.Channel` is a function of time; nothing to load.
      4. `Humanoid.Health`. Something somewhere always decides a model with a Humanoid is a
         character. The root part here is named `NPCRoot`, NOT `HumanoidRootPart`, so
         nothing that looks for a body can find one.

    `NPCService.ClearAll` is called from `MapManager.DestroyCurrentMap` alongside the other
    three spawning services.

    PLAYER CHARACTERS STILL NEED A HUMANOID. Roblox requires one in `Player.Character`;
    that cannot be changed from here, so `PlaceholderRig` keeps its Humanoid for the bodies
    real players wear. `NPCService` is for everything that is NOT a player.

    ---- WHY PLAYERS WERE ENDING UP INVISIBLE ----

    Three separate causes, all in `OYB_PlayerClient`:

      1. The Zombie theme did `obj.Parent = nil` on clothing and accessories and restored
         them with `data.inst.Parent = data.parent`. Respawn during the event DESTROYS that
         stored parent, so the restore reparented into a destroyed instance and the outfit
         was gone for good — body parts and no clothes. It now hides by transparency and by
         blanking `ShirtTemplate`, neither of which can be orphaned.
      2. Six early returns sat between the cinematic dummy being parented into the world and
         the one call that removes it, and three of them sat after
         `cam.CameraType = Scriptable`. Any of them left a dummy standing in the arena and
         the viewer's camera welded to it — looking at an NPC instead of their own body.
         There is now a single `finish()`, it is idempotent, and every return goes through
         it. `hideDivineCloneInstantly` also restores the camera unconditionally rather than
         only when it is still `Scriptable`.
      3. `humanoid:LoadAnimation` THROWS on a malformed id, and it was the first thing after
         the bookkeeping tables were reset — so one bad id aborted the setup with the
         character registered for a cleanup it never received. It is in a `pcall` now, and
         respawn clears the previous body's entries before the new body is decorated.

    `Settings.NPC_Scale` ships as 1000, which would be a two-kilometre figure standing on
    the arena. It is clamped to 6.

    ---- THE OVERSEER IS SOMETHING YOU CAN ACTUALLY USE ----

    Every ability on it was an instant, unavoidable, map-wide kill: ARMAGEDDON for 100,000
    damage to every alive fighter with no radius test, DECIMATE for 2,500 in a 90 stud
    sphere, and a 5,000 damage basic attack — against a roster whose highest health is
    1,650. All of it on a zero second cooldown.

    So it could only be used ONCE. Dropping in to mess about with a round ended it on the
    first keypress and sent everybody to an intermission.

    The power is unchanged and what the power DOES is not. It starts in PLAYFUL mode and
    nothing it does can kill anybody:

      M1  REBUKE       180 damage in a 120 degree cone and a flinging knockback. Four times
                       the hardest swing on the roster, and it relocates people.
      Q   ARMAGEDDON   Still reaches every fighter in the map at once. In PLAYFUL it throws
                       the entire arena into the air and blinds them briefly.
      E   UPHEAVAL     Replaces DECIMATE. Throws everyone within 90 studs up and outward,
                       harder the closer they were, and leaves them Disoriented. Scatters a
                       fight instead of deleting it.
      R   OMNISCIENCE  Unchanged.
      F   DECREE       NEW. Switches PLAYFUL / LETHAL. Writes a floating label, recolours
                       the body, prints to the Output. Resets to PLAYFUL on every respawn.

    NON-LETHAL IS A CLAMP, NOT A GUESS. `Punish` records health before the hit, lets the
    real `DamagePlayer` pipeline apply Resistance, Fragile and the escalation multipliers,
    and then restores the floor. Picking a "survivable" number instead would mean
    reimplementing that chain here and keeping the copy in step forever, and it would stop
    being survivable the moment somebody stacked Fragile.

    FIXED WHILE IN THERE: Armageddon set `Invincible = false` on every target and LEFT it
    there. That attribute is what spawn protection writes, so one press stripped the
    protection off everybody mid-respawn and nothing put it back — the window had already
    started its own timer and only clears the flag at the end. The previous value is now
    saved and restored on the next frame.

    ---- PANELS: THE OWNER, AND NOBODY ELSE ----

    `OwnerPerks.CanUseControlPanels` is the single answer to "may this account reach into a
    live round", and the round panel, the Events Panel and the ModPanel all defer to it.

    WHAT WAS ACTUALLY OPEN:

      * The round panel asked `PlayerHasPermissionRank(Player, Utils.Ranks.ServerOwner)`,
        which is `Rank < 20`. Moderator is 15 and Developer is 18, and the shipped
        `CommonFunctions.AdminPerms` CONTAINS a Developer — so that account had START ROUND
        and END ROUND in a live server. It also returned true for every player in a Studio
        session, which on a team test is everyone present.
      * The ModPanel used the same check. Its three commands are FREEZE TIME, ABILITY
        COOLDOWNS and ABILITY CHARGES: game-control toggles that change the round for
        everybody, not moderation tools.
      * The Events Panel allowed the owner plus an `extraAdmins` list loaded out of a
        DataStore. Anyone added once kept the panel in every session afterwards, and nothing
        in the repository recorded who. The list is still read and still displayed by the
        admin manager frame; it no longer grants access.

    `ExecuteCommand` HAD NO WORKING PERMISSION CHECK AT ALL. The guard was:

        if Debounce[id] and not HasRank(...) or Commands[name] == nil then return end

    `and` binds tighter than `or`, so that is `(Debounce[id] and not HasRank(...)) or
    (Commands[name] == nil)`. `Debounce[id]` is nil for anybody not currently on cooldown,
    `nil and X` is falsy, and the permission test was never reached. ANY client could fire
    that remote and run ANY registered moderator command — being mid-cooldown was the only
    condition under which permission was ever checked. It also indexed
    `Commands[name].RankRequired` before testing `Commands[name] == nil`, so a made-up
    command name threw inside the remote instead of being refused.

    It is three separate guards now, in order: does the command exist, is this player
    allowed, are they spamming it.

    The three game-control commands say `OwnerOnly = true` rather than a rank number,
    because there IS no rank number that means "only the owner": the comparison is
    `Rank < MandatoryRank` strictly and `Owner` is already the lowest rank at 1, so
    `RankRequired = 1` refuses everybody including the owner. Moderation proper
    (`KillPlayer`, `TurnPlayerInto`, `ChangeKillersAllowed`) is untouched and still runs at
    its own rank.

    To test a panel as another account, add it to `OwnerPerks.Owners` for as long as you
    need it — so the grant is written down rather than implied by the environment.

]]

script:Destroy()