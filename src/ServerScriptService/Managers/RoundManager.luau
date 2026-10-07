local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapManager = require(ServerScriptService.Managers.MapManager)
local ServerCharacterManager = require(ServerScriptService.Managers.ServerCharacterManager)
-- Safe to require at the top: `PlayerManager` only reaches back for `RoundManager` lazily,
-- inside `_RegisterKill`, precisely so this direction stays acyclic.
local PlayerManager = require(ServerScriptService.Managers.PlayerManager)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local GameMode = require(ReplicatedStorage.Modules.GameMode)
local KillEscalation = require(ReplicatedStorage.Modules.KillEscalation)
local TimeManager = require(ServerScriptService.Managers.TimeManager)
local CommonFunctions = require(ServerScriptService.System.CommonFunctions)

local RoundState: StringValue = ReplicatedStorage.RoundInfo.CurrentState
local PlayersRemaining: Folder = ReplicatedStorage.RoundInfo.PlayersRemaining

--[=[
    ROUND MANAGER — FREE FOR ALL

    The arena is a place, not a match.

    The map is spawned once when the server starts and stays up for the life of the
    server. Pressing PLAY teleports you into it immediately — there is no queue, no
    minimum player count, no round timer and no winner. You fight until you die, land
    back in the lobby, and press PLAY again.

    That means almost none of the round machinery below runs in this mode. It's all still
    here, and all of it comes back the moment `GameMode.Enabled` is set to `false`, which
    restores the original Killer-vs-Survivors round game exactly as it was.
]=]
local RoundManager = {
    Utils = {},
    Callables = {},
    Threads = {},
    PlayerConnections = {},
    CurrentRound = {
        PlayersAccepted = {},
        PlayersRemaining = {},
        Killers = {
            {
                Player = nil,
                Character = nil,
            },
        },
        KillerIndex = {},
        StartedLMS = false,
        --- Kills each fighter has racked up this match, keyed by UserId.
        Killstreaks = {},
    },
    --- Players who pressed PLAY and are waiting for the next match to begin.
    ---
    --- Classic mode only. The arena never queues anybody — you go straight in.
    Queue = {},
    --- `true` once the persistent arena map is up and PLAY is usable.
    ArenaOpen = false,
    --- Prints a step-by-step trace of every round start to the Output window.
    --- Leave it on while building; set it to `false` when the game is stable.
    TracePlay = true,
    --- What a player is spawned as when their equipped killer isn't available to them —
    --- currently only when they have an `OwnerOnly` character equipped and aren't an owner.
    FallbackKiller = "NullexVoyd",
    --- Timestamps (`time()`) marking when a dead player may press PLAY again.
    RespawnLocks = {},
    StopLoop = false,
    CanSpawnKiller = true, --for debugging purposes
    CanInitLMS = true, --for debugging purposes
}

function RoundManager:Init()
    RoundManager.CurrentRound.Killers = {}

    Players.PlayerRemoving:Connect(function(Player: Player)
        RoundManager.Utils.RemoveFromQueue(Player)
        RoundManager.RespawnLocks[Player.UserId] = nil
        RoundManager.CurrentRound.Killstreaks[Player.UserId] = nil
        RoundManager.CurrentRound.PlayersRemaining[Player.UserId] = nil

        --[[
            `PlayersAccepted` is only ever cleared by `EndRound`, which never runs in Free
            For All — the arena has no rounds to end. Left alone it grows for the life of
            the server and holds a strong reference to every player who has ever pressed
            PLAY, including everyone who has since left.
        ]]
        local Accepted = table.find(RoundManager.CurrentRound.PlayersAccepted, Player)
        if Accepted then
            table.remove(RoundManager.CurrentRound.PlayersAccepted, Accepted)
        end

        -- Same story: death hooks belonging to a player who is gone.
        if RoundManager.PlayerConnections[Player.UserId] then
            for _, Connection in RoundManager.PlayerConnections[Player.UserId] do
                Connection:Disconnect()
            end
            RoundManager.PlayerConnections[Player.UserId] = nil
        end
    end)

    if GameMode.IsRoundBased() then
        --[=[
            COUNTERATTACK — rounds with an intermission.

            The timings live in `GameMode.Config`, and they're copied into `TimeManager`
            here so there is exactly one place to edit them. `MinimumPlayerAmount` is what
            makes the lobby clock sit still until enough people have loaded, which is the
            behaviour you want between rounds on a quiet server.
        ]=]
        TimeManager.Config.LobbyTime = GameMode.GetLobbyTime()
        TimeManager.Config.RoundTime = GameMode.Config.MatchTime
        TimeManager.Config.LastManStandingTime = GameMode.Config.FinalDuelTime
        TimeManager.Config.MinimumPlayerAmount = GameMode.GetMinimumFighters()
        TimeManager.Config.WaitForEnoughPlayers = true

        TimeManager.SetTime(GameMode.GetLobbyTime())
        TimeManager.CanDecreaseTime = true
        TimeManager.OnTimerEnd = function()
            RoundManager.Utils.OnLobbyTimerEnd()
        end

        RoundState.Value = "Lobby"

        task.defer(RoundManager.Utils.ReportSetupProblems)
        return
    end

    if GameMode.Enabled then
        -- Open arena: no rounds, so nothing should ever be counting down.
        TimeManager.CanDecreaseTime = false
        TimeManager.OnTimerEnd = function() end

        task.defer(RoundManager.Utils.OpenArena)
        task.defer(RoundManager.Utils.ReportSetupProblems)
        return
    end

    -- Classic round game.
    TimeManager.OnTimerEnd = function()
        RoundManager.Utils.OnLobbyTimerEnd()
    end
end

--[=[
    Brings the arena up. Called once, when the server starts.

    The map is never torn down after this — it's the persistent place everyone drops
    into, so `RoundState` is parked on "InRound" for the life of the server. Systems
    that gate on being in a round (chase music, the terror radius) read that value, and
    in an always-open arena they should simply always be live.
]=]
function RoundManager.Utils.OpenArena()
    if not GameMode.Enabled or RoundManager.ArenaOpen then
        return
    end

    local Map = MapManager.GetRandomMap()
    if not Map then
        warn("[RoundManager] The arena could not open because there are no usable maps in `ServerStorage.Maps`. PLAY will not work until you add one.")
        return
    end

    RoundManager.ArenaOpen = true
    RoundState.Value = "InRound"
    workspace:SetAttribute("LMS", false)

    -- Say it here as well as in the setup report. A map with no spawn points loads
    -- perfectly and looks completely fine right up until somebody presses PLAY and falls
    -- out of the world, so it's worth flagging the moment the map goes up.
    local SpawnProblem = RoundManager.Utils.DescribeSpawnPointProblem()
    if SpawnProblem then
        warn("[Dysymmetrical FFA] \""..Map.Name.."\" is up, but "..SpawnProblem.." Nobody can drop in until that's fixed.")
    end

    -- No countdown in an arena. Park the clock so the HUD timer sits still rather than
    -- ticking toward an event that will never happen.
    TimeManager.CanDecreaseTime = false
    TimeManager.SetTime(0)

    print("[Dysymmetrical FFA] Arena open: "..Map.Name..". Press PLAY to drop in.")
end

--[=[
    Checks the live arena for somewhere to actually put a fighter.

    @return A sentence naming what's wrong, or `nil` if the spawn points are fine.

    Free For All doesn't care which role folder a spawn part sits in — it pools every
    `BasePart` under the chosen layout — so the only thing that matters is that at least
    one exists somewhere under `SpawnPoints`.
]=]
function RoundManager.Utils.DescribeSpawnPointProblem(): string?
    local MapFolder = workspace:FindFirstChild("Map")
    if not MapFolder then
        -- No map loaded yet. `OpenArena` reports that separately; nothing to add here.
        return nil
    end

    --[[
        Deliberately identical to `ServerCharacterManager._GetFreeForAllSpawn`, which is
        what actually places people — same recursive `SpawnPoints` lookup, same fallbacks.
        If that function would find somewhere to stand, this one must not complain. A setup
        report that cries wolf about a working map is worse than no report at all.
    ]]
    local SpawnPoints = ServerCharacterManager.FindSpawnPointsFolder()

    if SpawnPoints then
        for _, Descendant in SpawnPoints:GetDescendants() do
            if Descendant:IsA("BasePart") then
                return nil
            end
        end
    end

    for _, Descendant in MapFolder:GetDescendants() do
        if Descendant:IsA("SpawnLocation") then
            return nil
        end
    end

    return "the arena has nowhere to put a fighter, so everyone would spawn at the world origin and fall out "..
        "of the world.\n"..
        "     FIX: inside your map model, add a Folder named `SpawnPoints`, and put some parts in it — "..
        "anchored, invisible, non-collidable, sitting on the ground where fighters should appear.\n"..
        "     Sub-folders are optional. Anything under `SpawnPoints` counts, however you nest it. "..
        "Plain Roblox `SpawnLocation` objects anywhere in the map work too."
end

--[=[
    Prints a one-off setup report to the Output window when the server starts.

    Missing models and missing maps are by far the most common reason a match won't
    start, and both used to fail as an unhelpful error in the middle of a round. This
    says so up front, by name, before anybody presses PLAY.
]=]
function RoundManager.Utils.ReportSetupProblems()
    if not GameMode.Enabled then
        return
    end

    local Problems = {}

    -- This one really is fatal. Without a map there is nowhere to spawn anyone.
    if #(MapManager.MapPrefabs or {}) <= 0 then
        table.insert(Problems, "• BLOCKING: no maps in `ServerStorage.Maps`. Matches cannot start without at least one arena.")
    end

    --[=[
        Just as fatal, and much easier to miss: a map that loads fine but has nowhere to
        put anybody. Without a spawn point every fighter lands at the world origin and
        falls out of the world, which from the player's seat is indistinguishable from
        the game simply not working.
    ]=]
    local SpawnProblem = RoundManager.Utils.DescribeSpawnPointProblem()
    if SpawnProblem then
        table.insert(Problems, "• BLOCKING: "..SpawnProblem)
    end

    -- Cross-reference every killer module against the rig folder.
    local RigFolder = Utils.Instance.FindFirstChild(ReplicatedStorage, "Assets.Characters.Killer", 0)
    local SecretRigFolder = Utils.Instance.FindFirstChild(game:GetService("ServerStorage"), "Assets.Characters.Killer", 0)

    local Missing = {}
    for _, Module in ReplicatedStorage.Characters.Killers:GetChildren() do
        if not Module:IsA("ModuleScript") then
            continue
        end

        local HasRig = (RigFolder and RigFolder:FindFirstChild(Module.Name))
            or (SecretRigFolder and SecretRigFolder:FindFirstChild(Module.Name))

        if not HasRig then
            table.insert(Missing, Module.Name)
        end
    end

    -- Not blocking. These still play, wearing a placeholder noob body.
    if #Missing > 0 then
        table.insert(Problems,
            "• "..#Missing.." killer(s) have no model in `ReplicatedStorage.Assets.Characters.Killer` and will "..
            "spawn as a placeholder noob: "..table.concat(Missing, ", ")..
            ". They play normally — real abilities, real stats — only the body is a stand-in."
        )
    end

    if #Problems <= 0 then
        print("[Dysymmetrical FFA] Setup looks good — "..#MapManager.MapPrefabs.." map(s), all killer rigs present.")
        return
    end

    warn("[Dysymmetrical FFA] SETUP NOTES:\n"..table.concat(Problems, "\n").."\nSee FREE_FOR_ALL_SETUP.md.")
end

--------------------------------------------------------------------------------
-- QUEUE / JOINING
--------------------------------------------------------------------------------

--- Returns `true` if this player is currently sitting in the lobby (not fighting).
function RoundManager.Utils.IsInLobby(Player: Player): boolean
    local Char = Player.Character
    if not Char then
        return true
    end

    local Role = Char:FindFirstChild("Role")
    return not Role or Role.Value == "Spectator"
end

--- Returns `true` if this player is alive and in the arena right now.
function RoundManager.Utils.IsFighting(Player: Player): boolean
    if RoundManager.Utils.IsInLobby(Player) then
        return false
    end

    local Humanoid = Utils.Character.GetAlivePlayerHumanoid(Player)
    return Humanoid ~= nil and not Player.Character:GetAttribute("Dead")
end

--[=[
    Prints one line per step of a PLAY press, to the Output window.

    This is a plain `print`, not `Utils.Misc.Print` — the latter is gated behind the
    `DebugAllowed` workspace attribute, and the whole point of this trace is that it
    works out of the box while you're still getting the game standing up.

    Set `RoundManager.TracePlay = false` once you're happy with it.
]=]
function RoundManager.Utils.Trace(...)
    if not RoundManager.TracePlay then
        return
    end

    print("[PLAY]", ...)
end

--- Describes where a character actually ended up, for `Trace`.
function RoundManager.Utils.DescribePosition(Char: Model?): string
    if not Char then
        return "no character"
    end

    local Root = Utils.Character.GetRootPart(Char)
    if not Root then
        return "no root part"
    end

    local P = Root.Position
    return string.format("%.0f, %.0f, %.0f", P.X, P.Y, P.Z)
end

--[=[
    Lists everything that would stop this character from walking, for `Trace`.

    "The camera arrived but I can't move" and "the camera never arrived" look identical
    from the player's seat, and they have nothing to do with each other. This names which
    one you're actually looking at.
]=]
function RoundManager.Utils.DescribeMobility(Char: Model?): string
    if not Char then
        return "no character"
    end

    local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
    local Root = Utils.Character.GetRootPart(Char)

    local Blockers = {}

    if not Humanoid then
        table.insert(Blockers, "NO HUMANOID")
    else
        if Humanoid.WalkSpeed <= 0 then
            table.insert(Blockers, "WalkSpeed is "..tostring(Humanoid.WalkSpeed))
        end
        if Humanoid.PlatformStand then
            table.insert(Blockers, "PlatformStand is on")
        end
        if Humanoid.Sit then
            table.insert(Blockers, "Humanoid is sitting")
        end
    end

    if not Root then
        table.insert(Blockers, "NO ROOT PART")
    elseif Root.Anchored then
        table.insert(Blockers, "root part is ANCHORED")
    end

    local AnchoredParts = 0
    for _, Descendant in Char:GetDescendants() do
        if Descendant:IsA("BasePart") and Descendant.Anchored then
            AnchoredParts += 1
        end
    end
    if AnchoredParts > 0 then
        table.insert(Blockers, AnchoredParts.." anchored part(s)")
    end

    if #Blockers <= 0 then
        return string.format(
            "can move (WalkSpeed %.1f, nothing anchored)",
            Humanoid and Humanoid.WalkSpeed or -1
        )
    end

    return "CANNOT MOVE: "..table.concat(Blockers, "; ")
end

--- Removes a player from the PLAY queue if they're in it.
function RoundManager.Utils.RemoveFromQueue(Player: Player)
    local Index = table.find(RoundManager.Queue, Player)
    if Index then
        table.remove(RoundManager.Queue, Index)
    end
end

--- How many seconds this player still has to wait before they can press PLAY.
---
--- Returns `0` when they're free to go.
function RoundManager.Utils.GetRespawnWait(Player: Player): number
    local Unlock = RoundManager.RespawnLocks[Player.UserId]
    if not Unlock then
        return 0
    end

    return math.max(0, Unlock - time())
end

--[=[
    The single entry point behind the PLAY button.

    Teleports the player into the arena. That's it — there's no queue to join and
    nothing to wait for. The only things that can stop you are being in there already
    and a recent death.

    @return A status string the client uses to word its feedback, and an optional detail.
]=]
function RoundManager.Callables.RequestJoin(Player: Player): (string, any?)
    RoundManager.Utils.Trace(Player.Name.." pressed PLAY. Currently at "..RoundManager.Utils.DescribePosition(Player.Character)..".")

    if not GameMode.Enabled then
        RoundManager.Utils.Trace("-> Refused: GameMode.Enabled is false, so Free For All is switched off.")
        return "ModeDisabled"
    end

    -- Already swinging at people.
    if RoundManager.Utils.IsFighting(Player) then
        RoundManager.Utils.Trace("-> Refused: already fighting. Their current Role is not Spectator and they're alive.")
        return "AlreadyFighting"
    end

    -- Died recently — make them sit out the respawn cooldown.
    local Wait = RoundManager.Utils.GetRespawnWait(Player)
    if Wait > 0 then
        RoundManager.Utils.Trace(("-> Refused: %.1fs of respawn cooldown left."):format(Wait))
        return "OnCooldown", math.ceil(Wait)
    end

    -- The map failed to load at server start. Try once more rather than leaving the
    -- button permanently dead — a map added while the server was live will work.
    if not RoundManager.ArenaOpen then
        RoundManager.Utils.Trace("Arena wasn't open. Trying to open it now...")
        RoundManager.Utils.OpenArena()

        if not RoundManager.ArenaOpen then
            RoundManager.Utils.Trace("-> Refused: no usable map in ServerStorage.Maps.")
            return "NoArena"
        end
    end

    -- Pass the drop's own verdict straight back. It's the only thing that knows whether
    -- the player actually made it somewhere playable.
    return RoundManager.Callables.DropIntoMatch(Player)
end

--- Teleports a player into the arena.
---
--- @return A status string, and an optional detail. `"Joined"` on success.
function RoundManager.Callables.DropIntoMatch(Player: Player): (string, any?)
    RoundManager.Utils.RemoveFromQueue(Player)

    -- Fade in first. `Utils.Player.Fade(..., "Out", ...)` warns and does nothing if
    -- there's no existing fade frame to remove, so the pair has to be balanced —
    -- and it hides the spawn pop, which is what the fade is for.
    Utils.Player.Fade(Player, "In", 0.3, true)

    local Char, Problem = RoundManager.Utils.SetupFighter(Player)
    if not Char then
        --[[
            The spawn didn't take. Whatever half-built body is attached to this player
            right now is not somewhere they can play from — most likely the world origin —
            so put them back in the lobby as a spectator rather than leaving them in it.

            Without this the player is stranded in an unplayable body with the PLAY button
            hidden, and the only way out is rejoining the server.
        ]]
        PlayerManager._RespawnPlayer(Player)

        -- `SetupCharacter` adds the replicated `PlayersRemaining` entry before it knows
        -- whether the spawn took, so it has to come back out or the HUD counts a fighter
        -- who is standing in the lobby.
        local Remaining = PlayersRemaining:FindFirstChild(tostring(Player.UserId))
        if Remaining then
            Remaining:Destroy()
        end

        Utils.Player.Fade(Player, "Out", 0.3, false)
        task.defer(RoundManager.Utils.PushStatus)

        return Problem or "SetupFailed"
    end

    -- Late arrivals get a moment of grace so they aren't instantly deleted while
    -- their character is still streaming in.
    Char:SetAttribute("Invincible", true)
    CommonFunctions.ApplyEffect({
        TargetHumanoid = Char:FindFirstChildWhichIsA("Humanoid"),
        EffectSettings = {
            Name = "SpawnProtection",
            Subfolder = "KillerSpecific",
            Duration = GameMode.Config.JoinProtection,
        },
    })

    task.delay(GameMode.Config.JoinProtection, function()
        if Char and Char.Parent then
            Char:SetAttribute("Invincible", false)
        end
    end)

    Utils.Player.Fade(Player, "Out", 0.5, false)

    RoundManager.Utils.Broadcast(Player.Name .. " dropped in!")

    RoundManager.Utils.Trace(
        "-> Joined. "..Player.Name.."'s body is now at "..RoundManager.Utils.DescribePosition(Char)..
        ". Player.Character matches the new body: "..tostring(Player.Character == Char).."."
    )

    -- Movement is checked a beat later: `PlayerSpeedManager` drives `WalkSpeed` from a
    -- `PreSimulation` connection that hasn't run yet at this point in the frame, so
    -- reading it right now would always report 0 and cry wolf.
    task.delay(1, function()
        if Player.Parent and Player.Character == Char then
            RoundManager.Utils.Trace("   Mobility check: "..RoundManager.Utils.DescribeMobility(Char))
        end
    end)

    return "Joined"
end

--- Called when the lobby timer runs out. Classic mode only.
---
--- The arena has no lobby timer — it's always open, so there's nothing to count down to.
function RoundManager.Utils.OnLobbyTimerEnd()
    -- The open arena has no lobby timer — it's always up, so there's nothing to count
    -- down to. Round mode and classic mode both start a round here.
    if GameMode.Enabled and not GameMode.UseRounds then
        return
    end

    RoundManager.StartRound()
end

--------------------------------------------------------------------------------
-- MATCH LIFECYCLE
--------------------------------------------------------------------------------

--[=[
    Starts a round.

    Which kind depends on the mode. The open arena never "starts" anything — it's up from
    the moment the server boots and players walk in and out of it — so this is a no-op there.
]=]
function RoundManager.StartRound(force: boolean?)
    if GameMode.IsRoundBased() then
        RoundManager._StartRoyaleRound(force)
        return
    end

    if GameMode.Enabled then
        return
    end

    RoundManager._StartClassicRound()
end

--[=[
    COUNTERATTACK ROUND START

    Everybody in the server who has finished loading is dropped into the arena as their
    equipped Killer, frozen for the intro, then let loose on each other.

    Every spawn is wrapped in its own `pcall`. One player's rig failing must not abort the
    whole round — that was the original "fade to black and back to the lobby" bug, and it
    is worth never being able to happen again.
]=]
function RoundManager._StartRoyaleRound(force: boolean?)
    if RoundState.Value == "InRound" then
        return
    end

    local LoadedPlayers = Utils.Player.GetLoadedPlayers(false)

    --[[
        `force` is the `/round start` admin command, and it exists so the game can be
        tested alone. It skips the headcount check ONLY — the map, the spawn points and
        every per-player spawn are still verified exactly as normal, because those failing
        would break the round for real rather than just making it a lonely one.
    ]]
    if not force and #LoadedPlayers < GameMode.GetMinimumFighters() then
        RoundManager.Utils.Trace(("Not starting: %d player(s) loaded, %d needed."):format(#LoadedPlayers, GameMode.GetMinimumFighters()))
        RoundManager.Utils.ReturnToIntermission()
        return
    end

    RoundManager.Utils.Trace(("Starting a round with %d fighter(s).%s"):format(#LoadedPlayers, force and " (forced by an admin)" or ""))

    Utils.Player.Fade(LoadedPlayers, "In", 0.6, true)

    -- Bring up a fresh map for this round.
    local Map = MapManager.GetRandomMap()
    if not Map then
        warn("[Counterattack] Can't start a round — there are no usable maps in `ServerStorage.Maps`.")
        Utils.Player.Fade(LoadedPlayers, "Out", 0.6, false)
        RoundManager.Utils.ReturnToIntermission()
        return
    end

    local SpawnProblem = RoundManager.Utils.DescribeSpawnPointProblem()
    if SpawnProblem then
        warn("[Counterattack] Can't start a round — "..SpawnProblem)
        MapManager.DestroyCurrentMap()
        Utils.Player.Fade(LoadedPlayers, "Out", 0.6, false)
        RoundManager.Utils.ReturnToIntermission()
        return
    end

    -- Fresh round state.
    RoundManager.CurrentRound = {
        Killers = {},
        KillerIndex = {},
        PlayersAccepted = {},
        PlayersRemaining = {},
        StartedLMS = false,
        Killstreaks = {},
        SoloTest = false,
        StartingCount = 0,
    }
    for _, Value in PlayersRemaining:GetChildren() do
        Value:Destroy()
    end

    local Spawned = 0
    for _, Player: Player in LoadedPlayers do
        local Success, Err = pcall(function()
            -- `true` freezes them in place for the intro; `PlayIntro` thaws everyone.
            return RoundManager.Utils.SetupFighter(Player, true)
        end)

        if Success then
            if RoundManager.Utils.IsFighting(Player) then
                Spawned += 1
            end
        else
            warn("[Counterattack] "..Player.Name.." failed to spawn: "..tostring(Err))
        end
    end

    -- Everybody failed, or all but one did. Unwind rather than running a round nobody
    -- is in.
    -- A forced round only needs ONE body in the arena; a normal one needs a real match.
    local Needed = force and 1 or GameMode.GetMinimumFighters()
    if Spawned < Needed then
        warn(("[Counterattack] Only %d fighter(s) made it into the arena, %d needed. Aborting the round."):format(Spawned, Needed))
        RoundManager.Utils.AbortStart(LoadedPlayers)
        return
    end

    RoundState.Value = "InRound"
    workspace:SetAttribute("LMS", false)

    --[=[
        A forced round that couldn't have met the headcount is a SOLO TEST.

        Without this flag the win check sees one fighter alive, declares them the winner
        and ends the round on the first tick — which makes `/round start` useless for the
        exact thing it exists for. In a solo test the round runs until the clock expires or
        the tester dies.
    ]=]
    -- How many actually made it in. Read by the final-two clock cut, which must not fire
    -- in a round that never had more than two people in it.
    RoundManager.CurrentRound.StartingCount = Spawned

    --[=[
        A round with fewer than two fighters has no last-one-standing to find.

        This used to read `force == true and Spawned < ...`, which tied it to the admin
        panel's START ROUND button. But once Studio only needs one player, rounds start
        AUTOMATICALLY off the lobby timer with `force` nil — so `SoloTest` was false, the
        single fighter counted as the last one standing, and the round ended on its very
        first win-check tick. Start, instant end, back to the lobby clock, forever.

        How the round began is irrelevant. What matters is whether there is anybody to
        fight, and with one fighter there isn't.
    ]=]
    RoundManager.CurrentRound.SoloTest = Spawned < 2
    if RoundManager.CurrentRound.SoloTest then
        RoundManager.Utils.Trace("Only one fighter — the last-one-standing win condition is suspended for this round.")
    end

    --[=[
        THE ROUND CLOCK — or the absence of one.

        With `GameMode.Config.UseMatchTimer` off (the default), a round is pure last one
        standing: the timer is parked at zero, `OnTimerEnd` is emptied, and the ONLY thing
        that ends the round is `CheckForRoyaleWin` finding a single fighter left.

        Emptying `OnTimerEnd` matters as much as freezing the clock. `TimeManager` fires it
        the instant `CurrentTime` hits zero, and setting the time to zero here would fire
        it immediately — ending the round as a draw on the frame it started. Leaving the
        old "Draw" handler in place while parking the clock at zero is the one combination
        that looks safe and isn't.
    ]=]
    if GameMode.HasMatchTimer() then
        TimeManager.SetTime(GameMode.Config.MatchTime)
        TimeManager.CanDecreaseTime = false --thawed by `PlayIntro`
        TimeManager.OnTimerEnd = function()
            RoundManager.Callables.EndRound("Draw")
        end
    else
        TimeManager.OnTimerEnd = function() end
        TimeManager.CanDecreaseTime = false
        TimeManager.SetTime(0)
    end

    RoundManager.Utils.Broadcast("The round has begun. "..Spawned.." fighters. Last one breathing wins.")

    -- The win check runs on a loop rather than only on death, so a player leaving or
    -- being removed by anything other than `Humanoid.Died` still resolves the round.
    RoundManager.StopLoop = false
    RoundManager.Threads["WinCheckLoop"] = task.defer(function()
        while task.wait(1) do
            if RoundManager.StopLoop then
                RoundManager.StopLoop = false
                break
            end

            RoundManager.Utils.CheckForRoyaleWin()
        end
    end)

    RoundManager.Callables.PlayIntro()
end

--[=[
    Puts the server back into intermission without ending a round that never began.

    `EndRound` assumes a round actually ran — it pays out, tears down a map and fades
    everybody. When a start is refused before any of that happened, this is the lighter
    path back to the lobby clock.
]=]
function RoundManager.Utils.ReturnToIntermission()
    RoundState.Value = "Lobby"
    TimeManager.SetTime(GameMode.GetLobbyTime())
    TimeManager.CanDecreaseTime = true
    TimeManager.OnTimerEnd = function()
        RoundManager.Utils.OnLobbyTimerEnd()
    end
end

--[=[
    Unwinds a round that failed partway through starting.

    Half-spawned players are put back in the lobby, the map comes down, the fade is
    lifted and the intermission restarts. Without this a failed start leaves people
    staring at a black screen in a dead round.
]=]
function RoundManager.Utils.AbortStart(Players_: {Player})
    RoundManager.StopLoop = true

    for _, Connections in RoundManager.PlayerConnections do
        for _, Connection in Connections do
            Connection:Disconnect()
        end
    end
    table.clear(RoundManager.PlayerConnections)

    for _, Player: Player in Players_ do
        if Player.Parent and not RoundManager.Utils.IsInLobby(Player) then
            pcall(PlayerManager._RespawnPlayer, Player)
        end
    end

    for _, Value in PlayersRemaining:GetChildren() do
        Value:Destroy()
    end

    MapManager.DestroyCurrentMap()

    Utils.Player.Fade(Players_, "Out", 0.6, false)

    RoundManager.Utils.ReturnToIntermission()
end

--- INTERNAL: the original Killer vs Survivors round start, kept for `GameMode.Enabled == false`.
function RoundManager._StartClassicRound()
    local LoadedPlayers = Utils.Player.GetLoadedPlayers(false)
    Utils.Player.Fade(LoadedPlayers, "In", 0.6, true)

    --shuffling so that if there's a tie it chooses a truly random one
    RoundManager.CurrentRound.PlayersAccepted = Utils.Type.ShuffleTable(LoadedPlayers)

    --orders players by malice to choose later
    local PlayersOrderedByMalice = RoundManager.CurrentRound.PlayersAccepted
    table.sort(PlayersOrderedByMalice, function(a, b)
        return Utils.PlayerData.GetPlayerStat(a, "General.Malice") > Utils.PlayerData.GetPlayerStat(b, "General.Malice")
    end)

    MapManager.GetRandomMap()

    local KillersAllowed = workspace:GetAttribute("KillersAllowed") or 1

    for killerIndex = 1, KillersAllowed do
        RoundManager.CurrentRound.Killers[killerIndex] = {
            Player = PlayersOrderedByMalice[killerIndex],
            Character = nil
        }
        RoundManager.CurrentRound.KillerIndex[PlayersOrderedByMalice[killerIndex]] = killerIndex
    end

    for index, Player: Player in PlayersOrderedByMalice do
        local IsKiller = index <= KillersAllowed
        RoundManager.Utils.SetupPlayer(Player, IsKiller and index or nil)

        if RoundManager.CanSpawnKiller and IsKiller then
            continue
        end

        RoundManager.CurrentRound.PlayersRemaining[Player.UserId] = Player
    end

    RoundState.Value = "InRound"
    TimeManager.SetTime(TimeManager.Config.RoundTime)
    TimeManager.OnTimerEnd = function()
        RoundManager.Callables.EndRound("Survivors")
    end
    workspace:SetAttribute("LMS", false)

    RoundManager.StopLoop = false
    task.defer(function()
        while task.wait(1) do
            if RoundManager.StopLoop then
                RoundManager.StopLoop = false
                break
            end

            RoundManager.Utils.CheckForKillerWin()
        end
    end)

    RoundManager.Callables.PlayIntro()
end

--- Function called right when starting a round to unanchor every player after the default intro duration.
function RoundManager.Callables.PlayIntro()
    if GameMode.IsRoundBased() then
        --[=[
            Everyone is a Killer here, so there is no "the killer gets a cinematic while
            the survivors wait" split — the whole server is frozen for the same beat and
            thawed together. `IntroHandler` plays each player their own killer's intro
            over the top of it.
        ]=]
        Utils.Player.Fade(Utils.Player.GetLoadedPlayers(false), "Out", 0.6, false)

        RoundManager.Threads["IntroEndingThread"] = task.delay(GameMode.Config.IntroTime, function()
            -- Only thaw a clock that is supposed to be running. In last-one-standing mode
            -- `_StartRoyaleRound` parked it at zero deliberately, and starting it here
            -- would immediately trip `OnTimerEnd`.
            TimeManager.CanDecreaseTime = GameMode.HasMatchTimer()

            for _, player: Player in RoundManager.CurrentRound.PlayersAccepted do
                local Root = Utils.Character.GetRootPart(player)
                if Root then
                    Root.Anchored = false
                end
            end

            RoundManager.Utils.Broadcast("FIGHT!")
        end)
        return
    end

    if not RoundManager.CanSpawnKiller then
        Utils.Player.Fade(Utils.Player.GetLoadedPlayers(false), "Out", 0.6, false)
    end

    --whatever happens after since every intro lasts the same
    RoundManager.Threads["IntroEndingThread"] = task.delay(3, function()
        TimeManager.CanDecreaseTime = true
        for _, player: Player in RoundManager.CurrentRound.PlayersAccepted do
            local Root = Utils.Character.GetRootPart(player)
            if Root then
                Root.Anchored = false --handled from server
            end
        end
    end)
end

--[=[
    COUNTERATTACK WIN CHECK

    Runs once a second while a round is live. One fighter left standing wins it; nobody
    left is a draw.

    Also shortens the clock when it comes down to a final two, so a last pair can't spend
    four minutes avoiding each other.
]=]
function RoundManager.Utils.CheckForRoyaleWin()
    if not GameMode.IsRoundBased() or RoundState.Value ~= "InRound" then
        return
    end

    local Alive = GameMode.GetAliveFighters()

    if #Alive <= 0 then
        RoundManager.Callables.EndRound("Draw")
        return
    end

    --[[
        One fighter left normally means they've won. In a solo test there was never anybody
        else, so ending here would close the round the instant it opened.
    ]]
    if #Alive == 1 and not RoundManager.CurrentRound.SoloTest then
        RoundManager.Callables.EndRound(Players:GetPlayerFromCharacter(Alive[1]) or "Draw")
        return
    end

    --[=[
        Final two: announce it, reveal them to each other, and — if there is a clock — cut
        it down, once.

        `StartingCount > 2` matters. Without it, a round that BEGAN with two fighters hit
        this on its very first tick and was immediately shortened — so every small round
        was a `FinalDuelTime` round rather than a `MatchTime` one, which is exactly the
        "rounds are too short" complaint.

        A duel is only a duel if there was a crowd to thin out first.

        The clock cut is now conditional. In last-one-standing mode there is no clock to
        cut, and `SetTime(FinalDuelTime)` there would put ninety seconds on a frozen timer
        the HUD isn't even showing. The REVEAL is the part that matters and it happens
        either way — it's what stops a final two from hiding from each other now that
        nothing else will force the issue.
    ]=]
    if #Alive == 2
        and (RoundManager.CurrentRound.StartingCount or 0) > 2
        and not RoundManager.CurrentRound.StartedLMS
        and not RoundManager.CurrentRound.SoloTest
    then
        RoundManager.CurrentRound.StartedLMS = true
        workspace:SetAttribute("LMS", true)

        if GameMode.HasMatchTimer() and TimeManager.CurrentTime > GameMode.Config.FinalDuelTime then
            TimeManager.SetTime(GameMode.Config.FinalDuelTime)
        end

        --[[
            Show them to each other so the duel actually happens.

            With no round clock the reveal has to outlast a stubborn final two rather than
            expire after `FinalDuelTime` and hand them their hiding places back. There is
            nothing left to force the fight once it lapses, so in that mode it's given a
            duration long enough to cover any realistic duel.
        ]]
        local RevealFor = GameMode.HasMatchTimer() and GameMode.Config.FinalDuelTime or 3600

        local A, B = Players:GetPlayerFromCharacter(Alive[1]), Players:GetPlayerFromCharacter(Alive[2])
        if A and B then
            Utils.Player.RevealPlayerAuraTo(A, B, RevealFor)
            Utils.Player.RevealPlayerAuraTo(B, A, RevealFor)
            RoundManager.Utils.Broadcast("FINAL TWO — "..A.Name.." vs "..B.Name.."!")
        end
    end
end

--- Initiates the Last Man Standing sequence (1v1). Classic-mode only.
function RoundManager.Callables.InitLMS(LastMan: Player)
    -- The arena has no last man standing — it never ends and nobody is eliminated.
    if GameMode.Enabled then
        return
    end

    --failsafe
    if not RoundManager.CanInitLMS or RoundManager.CurrentRound.StartedLMS or not RoundManager.CurrentRound.Killers[1] or not RoundManager.CurrentRound.Killers[1].Character then
        return
    end

    RoundManager.CurrentRound.StartedLMS = true
    workspace:SetAttribute("LMS", true)

    for _, Killer in RoundManager.CurrentRound.Killers do
        Utils.Player.RevealPlayerAuraTo(Killer.Player, LastMan, 10)
        Utils.Player.RevealPlayerAuraTo(LastMan, Killer.Player, 10)
    end

    TimeManager.SetTime(TimeManager.Config.LastManStandingTime)

    Network:FireConnection("LMSVoiceline", LastMan)

    local Mod = require(Utils.Instance.GetCharacterModule("Killer", RoundManager.CurrentRound.Killers[1].Character:GetAttribute("CharacterName"), RoundManager.CurrentRound.Killers[1].Character:GetAttribute("CharacterSkinName")))
    local SpecialLMS = Mod.Config.SpecialLastManStandings
    local Specials = SpecialLMS[LastMan.Character:GetAttribute("CharacterName")]

    local Theme = Specials and (Specials[LastMan.Character:GetAttribute("CharacterSkinName")] or Specials["Default"] or Mod.Config.LastManStandingTheme) or Mod.Config.LastManStandingTheme
    Sounds.PlayTheme(Theme, {Name = "LMS", Priority = 999999, TweenTime = 0, Volume = 1, TimePosition = 0})
end

--[=[
    Ends the round and starts the intermission.

    The OPEN ARENA has no end — the map stays up for the life of the server and players
    come and go through it — so this is a no-op when `UseRounds` is off. Calling it there
    would tear down the arena everyone is standing in.
]=]
function RoundManager.Callables.EndRound(winner: Player | "Draw" | "Survivors" | "Killer")
    if GameMode.Enabled and not GameMode.UseRounds then
        return
    end

    -- Already ended, or never started. Without this a death landing in the same frame as
    -- the round timer expiring pays out twice.
    if RoundState.Value ~= "InRound" then
        return
    end
    RoundState.Value = "Lobby"

    --cancelling threads and disconnecting connections
    --[=[
        NEVER CANCEL THE THREAD WE'RE STANDING ON.

        `EndRound` is very often called FROM `Threads["WinCheckLoop"]` — that loop is what
        notices the last fighter standing. This used to `task.cancel` every entry in
        `Threads` unconditionally, which meant cancelling the very thread executing this
        function.

        `task.cancel(coroutine.running())` kills the thread dead, mid-function, and it is
        NOT an error — so nothing is printed and nothing catches it. Every line below this
        point was silently skipped: players were never returned to the lobby, the clock was
        never restarted, and critically `MapManager.DestroyCurrentMap()` never ran.

        The next round then cloned a SECOND map into `workspace`, both named "Map".
        `workspace:FindFirstChild("Map")` picks one of them arbitrarily, so spawn points
        could be read from one map while the geometry you can see is the other — which is
        how people ended up in the lobby, in the void, or somewhere else entirely.

        `StopLoop` above already tells the win-check loop to exit on its own next
        iteration, so skipping it here loses nothing.
    ]=]
    local RunningThread = coroutine.running()
    for _, Thread in RoundManager.Threads do
        if Thread ~= RunningThread then
            pcall(task.cancel, Thread)
        end
    end
    table.clear(RoundManager.Threads)

    --no more music!!1!
    Sounds.StopTheme("LMS", 0)
    workspace:SetAttribute("LMS", false)

    for _, Connections: {RBXScriptConnection} in RoundManager.PlayerConnections do
        for _, Connection in Connections do
            Connection:Disconnect()
        end
    end
    table.clear(RoundManager.PlayerConnections)

    if GameMode.IsRoundBased() then
        RoundManager.Utils.GrantRoyaleRewards(winner)
    else
        RoundManager.Utils.GrantClassicRewards(winner)
    end

    Utils.Player.Fade(Utils.Player.GetLoadedPlayers(), "In", 0.7, true)

    TimeManager.SetTime(GameMode.IsRoundBased() and GameMode.GetLobbyTime() or TimeManager.Config.LobbyTime)

    --respawning everyone left
    for _, Player: Player in RoundManager.CurrentRound.PlayersAccepted do
        if Player and Player.Parent and Utils.Character.GetRole(Player.Character) ~= nil and Utils.Character.GetRole(Player.Character) ~= "Spectator" then
            ServerCharacterManager.SetupCharacter(Player)
        end
    end

    -- Everyone gets a clean slate; nobody is stuck on a respawn lock in the lobby.
    table.clear(RoundManager.RespawnLocks)

    --restarting variables
    RoundManager.CurrentRound = {
        Killers = {},
        KillerIndex = {},
        PlayersAccepted = {},
        PlayersRemaining = {},
        StartedLMS = false,
        Killstreaks = {},
    }

    for _, Value in PlayersRemaining:GetChildren() do
        Value:Destroy()
    end

    task.defer(function()
        MapManager.DestroyCurrentMap()
    end)

    RoundState.Value = "Lobby"

    Utils.Player.Fade(Utils.Player.GetLoadedPlayers(), "Out", 0.7, true)

    TimeManager.OnTimerEnd = function()
        RoundManager.Utils.OnLobbyTimerEnd()
    end
    TimeManager.CanDecreaseTime = true
end

--[=[
    COUNTERATTACK PAYOUT

    The winner takes the win reward and a `KillerWins`. Everyone else who made it into the
    round gets a smaller participation reward, so a bad round is never a total loss.

    `winner` is the surviving Player, or `"Draw"` when the clock ran out or nobody was
    left standing.
]=]
function RoundManager.Utils.GrantRoyaleRewards(winner: Player | string)
    local WinnerName = typeof(winner) == "Instance" and winner.Name or nil

    for _, Player: Player in RoundManager.CurrentRound.PlayersAccepted do
        if not Player or not Player.Parent then
            continue
        end

        if Player == winner then
            CommonFunctions.UpdatePlayerStat(Player, "KillerStats.KillerWins", 1)
            CommonFunctions.GrantRewardToPlayer(Player, GameMode.Config.WinReward)

            task.defer(function()
                CommonFunctions.CompleteAchievement(Player, "Rounds.LastOneBreathing")
                CommonFunctions.IncrementAchievementProgress(Player, "Rounds.Champion", 1)
            end)
        else
            CommonFunctions.GrantRewardToPlayer(Player, GameMode.Config.ParticipationReward)
        end

        -- Everyone who made it into the round played it, win or lose.
        task.defer(function()
            CommonFunctions.IncrementAchievementProgress(Player, "Rounds.Regular", 1)
            CommonFunctions.IncrementAchievementProgress(Player, "Rounds.Veteran", 1)
        end)
    end

    if WinnerName then
        RoundManager.Utils.Broadcast(WinnerName.." is the last one breathing!")
    else
        RoundManager.Utils.Broadcast("Nobody survived. The round is a draw.")
    end
end

--- The original classic-mode reward payout.
function RoundManager.Utils.GrantClassicRewards(winner: string)
    if winner == "Killer" then
        for _, Killer in RoundManager.CurrentRound.Killers do
            CommonFunctions.UpdatePlayerStat(Killer.Player, "KillerStats.KillerWins", 1)
            CommonFunctions.GrantRewardToPlayer(Killer.Player, {Money = 120, EXP = 180, Reason = "winning a match as Killer"})
        end
        Utils.Misc.Print("killer wins")
    elseif winner == "Survivors" then
        for _, Killer in RoundManager.CurrentRound.Killers do
            CommonFunctions.UpdatePlayerStat(Killer.Player, "KillerStats.KillerLosses", 1)
        end
        for _, Player: Player in RoundManager.CurrentRound.PlayersRemaining do
            CommonFunctions.UpdatePlayerStat(Player, "SurvivorStats.SurvivorWins", 1)
            CommonFunctions.GrantRewardToPlayer(Player, {Money = 70, EXP = 110, Reason = "winning a match as Survivor"})
        end
        Utils.Misc.Print("survivors win")
    else
        Utils.Misc.Print("NO ONE WON!!1!")
    end
end

--------------------------------------------------------------------------------
-- DEATH HANDLING
--------------------------------------------------------------------------------

function RoundManager.Callables._OnPlayerDeath(dead: Player, wasKiller: boolean?)
    wasKiller = wasKiller or false

    --disconnect all connections related to this player
    if RoundManager.PlayerConnections[dead.UserId] then
        for _, Connection in RoundManager.PlayerConnections[dead.UserId] do
            Connection:Disconnect()
        end
        RoundManager.PlayerConnections[dead.UserId] = nil
    end

    if GameMode.Enabled then
        RoundManager.CurrentRound.PlayersRemaining[dead.UserId] = nil
        -- Their streak is over. Whoever killed them keeps theirs.
        RoundManager.CurrentRound.Killstreaks[dead.UserId] = nil

        CommonFunctions.UpdatePlayerStat(dead, "KillerStats.KillerLosses", 1)

        local DeadValue = PlayersRemaining:FindFirstChild(tostring(dead.UserId))
        if DeadValue then
            DeadValue:Destroy()
        end

        if GameMode.UseRounds then
            --[=[
                COUNTERATTACK: death is elimination.

                They're out for the rest of the round. `PlayerManager` puts them back in
                the lobby as a spectator a few seconds later, and they're in again
                automatically when the next round starts — there's no button to press and
                no cooldown to serve, so `RespawnLocks` is deliberately untouched.
            ]=]
            local Remaining = #GameMode.GetAliveFighters()
            if Remaining > 1 then
                RoundManager.Utils.Broadcast(dead.Name.." is out. "..Remaining.." left.")
            end

            task.defer(RoundManager.Utils.CheckForRoyaleWin)
            return
        end

        -- Open arena: start the clock on when they can drop back in.
        RoundManager.RespawnLocks[dead.UserId] = time() + GameMode.Config.RespawnCooldown

        -- Nothing else to do. The arena doesn't end, so there's no win condition to
        -- re-evaluate and nobody is eliminated — they just press PLAY again.
        task.defer(RoundManager.Utils.PushStatus)
        return
    end

    if wasKiller then
        --updates killer losses
        CommonFunctions.UpdatePlayerStat(dead, "KillerStats.KillerLosses", 1)
        --removes killer from table using table index
        RoundManager.CurrentRound.Killers[RoundManager.CurrentRound.KillerIndex[dead]] = nil
        RoundManager.CurrentRound.KillerIndex[dead] = nil
        --resorts to maintain the minimum indexes possible
        table.clear(RoundManager.CurrentRound.KillerIndex)
        local NewTable = {}
        for _, killer in ipairs(RoundManager.CurrentRound.Killers) do
            table.insert(NewTable, killer)
        end
        for index, killer in ipairs(NewTable) do
            RoundManager.CurrentRound.KillerIndex[killer.Player] = index
        end
        RoundManager.CurrentRound.Killers = NewTable
    else
        RoundManager.CurrentRound.PlayersRemaining[dead.UserId] = nil --removing from remaining list
    end

    --info
    local DeadRemainingValue = PlayersRemaining:FindFirstChild(tostring(dead.UserId))
    if DeadRemainingValue then
        DeadRemainingValue:Destroy()
    end

    RoundManager.Utils.CheckForKillerWin() --also checks for sudden death
end

--- Called by `PlayerManager` whenever a fighter gets a kill, so streaks can be tracked.
function RoundManager.Callables.RegisterKill(killer: Player)
    if not GameMode.Enabled or not killer then
        return
    end

    local Streak = (RoundManager.CurrentRound.Killstreaks[killer.UserId] or 0) + 1
    RoundManager.CurrentRound.Killstreaks[killer.UserId] = Streak

    --[=[
        ACHIEVEMENTS.

        Deferred, because `CompleteAchievement` can award a Roblox badge and that yields on
        a web call — the engine's own docs say any call that might grant a badge has to be
        deferred so it never stalls the kill it was triggered by.
    ]=]
    task.defer(function()
        if Streak == 1 then
            CommonFunctions.CompleteAchievement(killer, "Combat.FirstBlood")
        end

        CommonFunctions.IncrementAchievementProgress(killer, "Combat.Bloodwork", 1)
        CommonFunctions.IncrementAchievementProgress(killer, "Combat.Prolific", 1)

        local StreakAchievement = ({[3] = "Rampage", [5] = "Unstoppable", [10] = "DeathItself"})[Streak]
        if StreakAchievement then
            CommonFunctions.CompleteAchievement(killer, "Combat."..StreakAchievement)
        end
    end)

    -- Every kill makes them a little stronger, and some of them unlock a perk.
    local Tier = KillEscalation.ApplyKill(killer, Streak)
    if Tier then
        RoundManager.Utils.Broadcast(killer.Name.." "..Tier.Announcement.." — "..Tier.Name.." unlocked!")

        -- One achievement per perk tier. The keys match the tier names with the spaces
        -- taken out, so adding a tier in `KillEscalation` only needs an entry added here.
        local PerkAchievement = ({
            ["BLOODSCENT"] = "Bloodscent",
            ["SECOND WIND"] = "SecondWind",
            ["FRENZY"] = "Frenzy",
            ["APEX"] = "Apex",
        })[Tier.Name]

        if PerkAchievement then
            task.defer(CommonFunctions.CompleteAchievement, killer, "Escalation."..PerkAchievement)
        end
    end

    local Message = GameMode.GetKillstreakMessage(Streak)
    if Message then
        RoundManager.Utils.Broadcast(killer.Name .. " " .. Message .. "!")
    end
end

--- Sends a short announcement to every client's arena feed.
function RoundManager.Utils.Broadcast(text: string)
    Network:FireAllClientConnection("ArenaAnnouncement", "REMOTE_EVENT", text)
end

--- Tells every client to re-read the queue so their PLAY button label stays honest.
function RoundManager.Utils.PushStatus()
    Network:FireAllClientConnection("MatchStatusChanged", "REMOTE_EVENT")
end

--------------------------------------------------------------------------------
-- WIN CHECKING
--------------------------------------------------------------------------------

--[=[
    Checks whether the match is over.

    The arena never ends, so in Free For All this does nothing at all. Nobody wins,
    nobody is eliminated, and the map stays up — the loop is simply fight, die, press
    PLAY, fight again.

    Everything below is the classic round game's win condition.
]=]
function RoundManager.Utils.CheckForKillerWin()
    if GameMode.Enabled then
        return
    end

    if RoundState.Value ~= "InRound" then
        return
    end

    local Count = Utils.Character.GetCharactersWithRoles()
    local Survivors = #Count.Survivor

    if RoundManager.CanSpawnKiller then
        if #Count.Killer <= 0 then
            RoundManager.Callables.EndRound("Survivors")
        elseif Survivors == 1 then
            RoundManager.Callables.InitLMS(Players:GetPlayerFromCharacter(Count.Survivor[1]))
        elseif #RoundManager.CurrentRound.PlayersAccepted > 1 and Survivors <= 0 then
            RoundManager.Callables.EndRound("Killer")
        end
    elseif Survivors <= 0 then
        RoundManager.Callables.EndRound("Killer")
    end
end

--------------------------------------------------------------------------------
-- SPAWNING
--------------------------------------------------------------------------------

--[=[
    Returns the killer this player is actually allowed to spawn as.

    Normally that's whatever they have equipped. If the equipped character is flagged
    `Config.OwnerOnly` and they aren't on the owner list, they get the fallback instead.

    @return The name of the killer to spawn.
]=]
function RoundManager.Utils.ResolveKillerFor(Player: Player, EquippedName: string): string
    local ModuleInstance = Utils.Instance.FindFirstChild(ReplicatedStorage, "Characters.Killers."..EquippedName, 0)
    if not ModuleInstance then
        return EquippedName
    end

    local Success, Module = pcall(require, ModuleInstance)
    if not Success or not Module or not Module.Config or not Module.Config.OwnerOnly then
        return EquippedName
    end

    local OwnerSuccess, OwnerPerks = pcall(require, ServerScriptService.Managers.OwnerPerks)
    if OwnerSuccess and OwnerPerks.IsOwner(Player) then
        return EquippedName
    end

    warn(
        "[RoundManager] "..Player.Name.." has the owner-only killer \""..EquippedName.."\" equipped but isn't "..
        "on the owner list. Spawning them as \""..RoundManager.FallbackKiller.."\" instead. "..
        "Owners are configured in `ServerScriptService.Managers.OwnerPerks`."
    )

    return RoundManager.FallbackKiller
end

--- Gets a character's module depending on a player's equipped values.
function RoundManager.Utils.GetCharacterModule(player: Player, charType: "Killer" | "Survivor")
    local EquippedCharacter = Utils.PlayerData.GetPlayerEquipped(player, charType)
    local EquippedSkin = Utils.PlayerData.GetPlayerEquipped(player, "Skins."..EquippedCharacter)

    return Utils.Instance.GetCharacterModule(charType, EquippedCharacter, EquippedSkin)
end

--[=[
    Spawns a player into the arena as their equipped Killer and wires up their
    death tracking.

    `anchorForIntro` should only be `true` for the fighters present at the match
    start — people dropping in mid-match need to be able to move immediately.

    @return The spawned character, or `nil` plus a status string naming what went wrong.
]=]
function RoundManager.Utils.SetupFighter(Player: Player, anchorForIntro: boolean?): (Model?, string?)
    if not Player or not Player.Parent then
        return
    end

    local EquippedKillerName = Utils.PlayerData.GetPlayerEquipped(Player, "Killer")
    if not EquippedKillerName or #EquippedKillerName <= 0 then
        warn("[RoundManager.Utils.SetupFighter()] "..Player.Name.." has no equipped killer! Skipping...")
        RoundManager.Utils.Trace("-> Failed: no equipped Killer on this player's save data.")
        return nil, "SetupFailed"
    end

    --[=[
        OWNER-ONLY KILLERS.

        A character whose module sets `Config.OwnerOnly` can only be worn by an account
        listed in `OwnerPerks`. This is the first and most important of three checks —
        the other two are in the character's `OnInit` and in each of its ability
        behaviours — because it stops the body ever existing rather than cleaning up
        after it.

        Non-owners silently fall back to the roster default instead of being refused the
        round entirely. Somebody with a stale save shouldn't be locked out of playing.
    ]=]
    EquippedKillerName = RoundManager.Utils.ResolveKillerFor(Player, EquippedKillerName)

    RoundManager.Utils.Trace("Equipped killer is \""..EquippedKillerName.."\". Building their body...")

    -- If this killer has no model built yet, `PlayerManager._RespawnPlayer` stands in a
    -- placeholder noob body. The player still gets the character they actually chose.
    local Char = ServerCharacterManager.SetupCharacter(Player,
        EquippedKillerName,
        "Killer",
        Utils.PlayerData.GetPlayerEquipped(Player, "Skins."..EquippedKillerName)
    )

    if not Char then
        RoundManager.Utils.Trace("-> Failed: SetupCharacter returned nothing. The rig is missing a Humanoid, or _RespawnPlayer bailed.")
        return nil, "SetupFailed"
    end

    RoundManager.Utils.Trace(
        "Body built"..(Char:GetAttribute("PlaceholderRig") and " (placeholder noob — no model for this killer yet)" or "")..
        ". Spawn point reached: "..tostring(Char:GetAttribute("SpawnedProperly"))..
        ". Position: "..RoundManager.Utils.DescribePosition(Char).."."
    )

    --[=[
        The map had no usable spawn point, so this body is sitting at the world origin
        rather than in the arena. Refuse the spawn instead of dropping the player into
        empty space — falling out of the world with a frozen view is a miserable thing to
        debug, and it looks exactly like a camera bug from the player's seat.
    ]=]
    if Char:GetAttribute("SpawnedProperly") == false then
        warn(
            "[RoundManager.Utils.SetupFighter()] Refusing to drop "..Player.Name.." into the arena: the map has no "..
            "usable spawn point, so they'd spawn at the world origin and fall out of the world. Add a `SpawnPoints` "..
            "folder to your arena — see FREE_FOR_ALL_SETUP.md step 3."
        )
        return nil, "NoSpawnPoints"
    end

    -- Track them as a live fighter so `PlayersRemaining` / the round list stay accurate.
    if not table.find(RoundManager.CurrentRound.PlayersAccepted, Player) then
        table.insert(RoundManager.CurrentRound.PlayersAccepted, Player)
    end
    RoundManager.CurrentRound.PlayersRemaining[Player.UserId] = Player
    RoundManager.CurrentRound.Killstreaks[Player.UserId] = 0

    -- Respawning replaces this player's connections. The old ones point at a character
    -- that no longer exists, and leaving them attached means a single death can fire
    -- `_OnPlayerDeath` more than once.
    if RoundManager.PlayerConnections[Player.UserId] then
        for _, Connection in RoundManager.PlayerConnections[Player.UserId] do
            Connection:Disconnect()
        end
        RoundManager.PlayerConnections[Player.UserId] = nil
    end

    -- A rig with no Humanoid means `PlayerManager._RespawnPlayer` fell back to the
    -- default character. Bail rather than erroring on a nil `Died` signal — this is the
    -- symptom you get when a killer's model is missing from
    -- `ReplicatedStorage.Assets.Characters.Killer`, which is easy to hit while building.
    local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
    if not Humanoid then
        warn("[RoundManager.Utils.SetupFighter()] "..Player.Name.."'s character (\""..EquippedKillerName.."\") has no Humanoid! Every killer rig needs one in the root of its model.")
        return Char
    end

    RoundManager.PlayerConnections[Player.UserId] = {
        Player.CharacterRemoving:Connect(function()
            RoundManager.Callables._OnPlayerDeath(Player, true)
        end),

        Humanoid.Died:Connect(function()
            RoundManager.Callables._OnPlayerDeath(Player, true)
        end),
    }

    if anchorForIntro then
        task.wait()
        local Root = Utils.Character.GetRootPart(Char)
        if Root then
            Root.Anchored = true
        end
    end

    return Char
end

--- Sets up a player in the round's player list while also spawning its character.
---
--- Classic-mode path. FFA uses `RoundManager.Utils.SetupFighter()` instead.
function RoundManager.Utils.SetupPlayer(Player: Player, KillerIndex: number)
    local Char

    if KillerIndex and RoundManager.CanSpawnKiller then --RoundManager.CanSpawnKiller is for debugging
        Utils.PlayerData.GetPlayerStat(Player, "General.Malice", false).Value = 1 --resets malice

        local EquippedKillerName = Utils.PlayerData.GetPlayerEquipped(Player, "Killer")

        Char = ServerCharacterManager.SetupCharacter(Player,
            EquippedKillerName,
            "Killer",
            Utils.PlayerData.GetPlayerEquipped(Player, "Skins."..EquippedKillerName)
        )

        RoundManager.PlayerConnections[Player.UserId] = {
            Player.CharacterRemoving:Connect(function()
                RoundManager.Callables._OnPlayerDeath(Player, true)
            end),

            Char.Humanoid.Died:Connect(function()
                RoundManager.Callables._OnPlayerDeath(Player, true)
            end)
        }

        RoundManager.CurrentRound.Killers[KillerIndex].Character = Char
    else
        CommonFunctions.UpdatePlayerStat(Player, "General.Malice", 1) --adds 1 malice

        local EquippedSurvivorName = Utils.PlayerData.GetPlayerEquipped(Player, "Survivor")

        Char = ServerCharacterManager.SetupCharacter(Player,
            EquippedSurvivorName,
            "Survivor",
            Utils.PlayerData.GetPlayerEquipped(Player, "Skins."..EquippedSurvivorName)
        )

        RoundManager.PlayerConnections[Player.UserId] = {
            Player.CharacterRemoving:Connect(function()
                RoundManager.Callables._OnPlayerDeath(Player)
            end),

            Char.Humanoid.Died:Connect(function()
                CommonFunctions.UpdatePlayerStat(Player, "SurvivorStats.SurvivorLosses", 1) --increasing loss stat
                RoundManager.Callables._OnPlayerDeath(Player)
            end)
        }
    end

    --anchoring at beginning of round to unanchor later
    task.wait()
    Utils.Character.GetRootPart(Char).Anchored = true
end

return RoundManager
