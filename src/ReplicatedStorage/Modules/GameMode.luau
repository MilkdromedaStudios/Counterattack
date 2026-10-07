--[=[
    GAME MODE — COUNTERATTACK

    The single place the whole ruleset is configured. Every other system reads from here
    instead of hardcoding numbers, so the game can be retuned from one file.

    THE LOOP
    --------
    Everyone waits out an intermission in the lobby. When the timer hits zero the round
    starts, every player is dropped into the arena as their equipped Killer, and everyone
    can hurt everyone. Die and you sit the rest of the round out as a spectator. Last one
    breathing wins, the map comes down, and the intermission starts again.

    THREE MODES, TWO SWITCHES
    -------------------------
      Enabled = true,  UseRounds = true    Counterattack. Rounds and an intermission.
                                           This is the game. <-- YOU ARE HERE

      Enabled = true,  UseRounds = false   Open arena. No rounds; a PLAY button drops you
                                           in whenever you like and the map never comes down.

      Enabled = false                      The original Dysymmetrical engine game:
                                           one Killer versus a lobby of Survivors.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameMode = {
    --[=[
        THE GAME'S NAME.

        Everything player-facing reads from here — the HUD, the round banners, the
        changelog, the credits. Change this one string and the whole game is rebranded.
    ]=]
    Name = "COUNTERATTACK",

    --- Short line shown under the name on banners and menus.
    Tagline = "Ten monsters. One arena. No survivors.",

    --- Master switch. `false` restores the classic Killer vs Survivors game.
    Enabled = true,

    --[=[
        `true`  = rounds with an intermission between them, and no PLAY button.
        `false` = the open arena, where a PLAY button drops you in on demand.
    ]=]
    UseRounds = true,
}

GameMode.Config = {
    ----------------------------------------------------------------------------
    -- ROUND TIMINGS (`UseRounds = true`)
    ----------------------------------------------------------------------------

    --- Seconds of intermission in the lobby between rounds.
    LobbyTime = 30,

    --[=[
        Seconds of intermission in STUDIO.

        The menus — inventory, shop, settings, credits — are only reachable while you're a
        Spectator in the lobby, because during a round you're supposed to be fighting.
        Combined with `SoloInStudio` (one player is enough to start), a 30 second
        intermission meant a test session spent 30 seconds in the lobby and then six
        minutes in a round, so the inventory was almost never open-able.

        Three minutes gives room to actually look at things. The ROUND CONTROL panel's
        SKIP INTERMISSION button starts the round the moment you're ready, so nothing is
        lost by making this generous.
    ]=]
    LobbyTimeInStudio = 180,
    --[=[
        WHETHER A ROUND HAS A CLOCK AT ALL.

        `false` — the default — makes a round pure LAST ONE STANDING: no countdown, no
        draw, no shortened final duel. It ends when one fighter is left breathing and not
        one second before.

        Every timing below still exists and every one of them comes back the moment this is
        `true`, because the intermission needs a clock either way and switching the round
        timer back on shouldn't mean rebuilding it.

        What this changes downstream:
          * `_StartRoyaleRound` parks the clock instead of starting it.
          * `PlayIntro` leaves it parked rather than thawing it at the end of the intro.
          * `CheckForRoyaleWin` still announces the final two and still reveals them to
            each other — it just doesn't cut a clock that isn't running.
          * The HUD swaps the countdown for a live count of who's left, since a frozen
            `0:00` under "Round ends in..." reads as a broken timer.
    ]=]
    UseMatchTimer = false,

    --[=[
        Seconds a round runs before it's called a draw. 360 = six minutes.

        Ignored while `UseMatchTimer` is `false`.
    ]=]
    MatchTime = 360,
    --[=[
        Seconds the round is cut to once only two fighters are left, so a last pair can't
        hide from each other for the rest of the clock.

        This only applies when the round STARTED with more than two — see
        `RoundManager.Utils.CheckForRoyaleWin`. In a two-player round there was never a
        field to thin out, and cutting the clock there just made every small round 90
        seconds long.
    ]=]
    FinalDuelTime = 90,
    --- How many players must be in the server before a round will start.
    MinimumFighters = 2,

    --[=[
        In Studio, only need ONE player.

        A solo test session has exactly one player in it, so a minimum of 2 means the lobby
        clock sits at "Waiting for fighters..." forever and a round never starts — which
        reads as "the game doesn't work in test mode".

        Applied in `GameMode:Init` so a published server is unaffected. Set to `false` if
        you want Studio to behave exactly like the live game.
    ]=]
    SoloInStudio = true,
    --- Seconds players stand frozen at the start of a round while the intro plays.
    IntroTime = 3,

    ----------------------------------------------------------------------------
    -- COMBAT
    ----------------------------------------------------------------------------

    --- Seconds of damage and stun immunity granted on spawning into the arena.
    JoinProtection = 5,
    --- Minimum distance in studs a spawning fighter tries to keep from everyone else.
    SafeSpawnDistance = 60,

    ----------------------------------------------------------------------------
    -- REWARDS
    ----------------------------------------------------------------------------

    KillReward = {Money = 25, EXP = 70, Reason = "killing a fighter"},
    WinReward = {Money = 150, EXP = 250, Reason = "winning a round"},
    --- Everyone who made it into the round but didn't win.
    ParticipationReward = {Money = 15, EXP = 40, Reason = "surviving the arena"},

    --- Streak counts that announce to the whole server. Purely cosmetic.
    KillstreakTiers = {
        [3] = "is on a RAMPAGE",
        [5] = "is UNSTOPPABLE",
        [7] = "is a MASSACRE",
        [10] = "has become DEATH ITSELF",
    },

    ----------------------------------------------------------------------------
    -- OPEN-ARENA ONLY (`UseRounds = false`)
    ----------------------------------------------------------------------------

    --- Seconds a dead fighter waits before PLAY works again. `0` for instant re-entry.
    RespawnCooldown = 3,
}

--- Attributes mirrored onto `workspace` so client code and the mod panel can read the mode.
GameMode.Attributes = {
    --- Read by `Hitbox` — with this on, anyone can damage anyone regardless of role.
    FriendlyFire = true,
    --- Read by `RoundManager` — how many players get the Killer role. Here it's everyone.
    KillersAllowed = math.huge,
    --- Read by UI to know which ruleset is live.
    FreeForAll = true,
}

--- The `StringValue` holding the current round state (`"Lobby"` / `"InRound"`).
local RoundState: StringValue = ReplicatedStorage.RoundInfo.CurrentState

function GameMode:Init()
    if not RunService:IsServer() then
        return
    end

    -- Set from code rather than from Studio attributes so a fresh clone of the place
    -- works without anyone having to remember to add them by hand.
    workspace:SetAttribute("FreeForAll", GameMode.Enabled)
    workspace:SetAttribute("FriendlyFire", GameMode.Enabled)

    -- `KillersAllowed` is consumed as a number by the round flow, so it gets a real
    -- number rather than `math.huge` (attributes can't hold infinity).
    if workspace:GetAttribute("KillersAllowed") == nil then
        workspace:SetAttribute("KillersAllowed", GameMode.Enabled and 32 or 1)
    end

    if GameMode.Config.SoloInStudio and RunService:IsStudio() then
        print("[Counterattack] Studio session — one player is enough to start a round. (GameMode.Config.SoloInStudio)")
    end

    -- Both of these exist in the original engine but are never initialised anywhere,
    -- which silently disables cooldowns and charges on a fresh place. Default them on.
    if workspace:GetAttribute("CooldownsEnabled") == nil then
        workspace:SetAttribute("CooldownsEnabled", true)
    end
    if workspace:GetAttribute("ChargesEnabled") == nil then
        workspace:SetAttribute("ChargesEnabled", true)
    end
end

--[=[
    How many players a round actually needs to start.

    A FUNCTION rather than a mutated config value on purpose. Overwriting
    `Config.MinimumFighters` from `GameMode:Init` would only work if that ran before
    `RoundManager:Init` copies it into `TimeManager` — and nothing guarantees that order,
    since one lives in ReplicatedStorage and the other in ServerScriptService. Resolving it
    at the point of use removes the dependency entirely.
]=]
function GameMode.GetMinimumFighters(): number
    if GameMode.Config.SoloInStudio and RunService:IsStudio() then
        return 1
    end

    return GameMode.Config.MinimumFighters
end

--[=[
    How long the intermission actually runs for.

    Same shape and same reasoning as `GetMinimumFighters` — resolved at the point of use
    rather than written over `Config` in `Init`, so it can't depend on which module
    initialises first.
]=]
function GameMode.GetLobbyTime(): number
    if RunService:IsStudio() then
        return GameMode.Config.LobbyTimeInStudio
    end

    return GameMode.Config.LobbyTime
end

--- `true` when rounds and an intermission are running, rather than the open arena.
function GameMode.IsRoundBased(): boolean
    return GameMode.Enabled and GameMode.UseRounds
end

--[=[
    `true` when a live round is counting down to something.

    A function rather than a bare read of `Config.UseMatchTimer` because it also has to be
    false in the open arena, which has no rounds to time — the HUD and the round flow both
    want one question answered ("is there a clock?"), not two.
]=]
function GameMode.HasMatchTimer(): boolean
    return GameMode.IsRoundBased() and GameMode.Config.UseMatchTimer == true
end

--[=[
    Returns `true` while the arena is up and holding a fight.

    In round mode that means a round is actually in progress. In the open arena it's true
    for the life of the server.
]=]
function GameMode.IsArenaOpen(): boolean
    return RoundState.Value == "InRound"
end

--- Returns every alive fighter character currently in the arena.
---
--- Everyone shares the `Killer` role here, so this can't use the role split the way the
--- classic mode does — it walks the player folder directly instead.
function GameMode.GetAliveFighters(): {Model}
    local Fighters = {}

    for _, Char: Model in workspace.Players:GetChildren() do
        local Role = Char:FindFirstChild("Role")
        if not Role or Role.Value == "Spectator" then
            continue
        end

        if Char:GetAttribute("Dead") == true then
            continue
        end

        local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid or Humanoid.Health <= 0 then
            continue
        end

        table.insert(Fighters, Char)
    end

    return Fighters
end

--- Returns the killstreak announcement for a given streak count, or `nil` if this
--- streak isn't a milestone.
function GameMode.GetKillstreakMessage(streak: number): string?
    return GameMode.Config.KillstreakTiers[streak]
end

return GameMode
