--[=[
    ADMIN ROUND CONTROL — server side

    Backs the round-control panel in `StarterPlayerScripts/UI/AdminRoundPanel`.

    Everything that decides whether a request is allowed lives here, on the server. The
    client panel only hides its buttons from people who shouldn't see them — that's
    presentation, not security, and an exploiter can show them again in a second. Every
    action re-checks permission before it does anything.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ReplicatedStorage.Modules.Network)
local GameMode = require(ReplicatedStorage.Modules.GameMode)
local Utils = require(ReplicatedStorage.Modules.Utils)

local RoundState: StringValue = ReplicatedStorage.RoundInfo.CurrentState

--- The configured minimum, remembered so SOLO can be toggled back off.
local StoredMinimum: number? = nil

--- Stops a held-down button hammering the round manager.
local Debounce: {[number]: number} = {}
local DEBOUNCE_TIME = 0.5

--[=[
    May this player use the round controls?

    THE OWNER LIST, AND NOTHING ELSE. `OwnerPerks.CanUseControlPanels` is the single
    answer to this question in the whole game — see the long comment on it for what this
    used to accept and why each of those was a hole.

    The short version: this function used to return true for any player in Studio, and for
    anybody whose admin rank beat `ServerOwner` (20) — which Moderator (15) and Developer
    (18) both do. The shipped `AdminPerms` list contains a Developer, so an account that
    was never meant to control rounds could start and end them.

    If the gate cannot be loaded at all, nobody gets in. An admin panel that fails OPEN is
    worse than one that fails closed.
]=]
local function CanControl(Player: Player): boolean
    local Success, OwnerPerks = pcall(require, ServerScriptService.Managers.OwnerPerks)
    if not Success then
        warn("[AdminRoundControl] Couldn't load OwnerPerks to verify access — refusing. "..tostring(OwnerPerks))
        return false
    end

    return OwnerPerks.CanUseControlPanels(Player) == true
end

--- The current state, for the panel's status line.
local function BuildStatus()
    local RoundManager = require(ServerScriptService.Managers.RoundManager)
    local TimeManager = require(ServerScriptService.Managers.TimeManager)

    return {
        State = RoundState.Value,
        TimeLeft = math.ceil(TimeManager.CurrentTime),
        --[[
            Whether the number above means anything right now.

            With `GameMode.Config.UseMatchTimer` off a live round has no clock — the timer
            is parked at zero on purpose — so the panel showing "InRound · 0s" would read
            as a stuck timer rather than as the rule it is. The panel swaps the field out
            when this is false.
        ]]
        HasTimer = GameMode.HasMatchTimer(),
        Loaded = #Utils.Player.GetLoadedPlayers(false),
        Alive = #GameMode.GetAliveFighters(),
        Minimum = GameMode.GetMinimumFighters(),
        SoloTest = RoundManager.CurrentRound.SoloTest == true,
        RoundsEnabled = GameMode.IsRoundBased(),
    }
end

local Actions = {}

function Actions.Start(Player: Player): string
    if not GameMode.IsRoundBased() then
        return "Rounds are off — set `GameMode.UseRounds = true`"
    end

    if RoundState.Value == "InRound" then
        return "A round is already running"
    end

    local RoundManager = require(ServerScriptService.Managers.RoundManager)

    -- `true` skips the headcount check only. Map and spawn-point validation still run,
    -- because those failing would break the round for real rather than just make it lonely.
    task.defer(RoundManager.StartRound, true)

    return "Starting a round..."
end

function Actions.End(Player: Player): string
    if RoundState.Value ~= "InRound" then
        return "No round is running"
    end

    local RoundManager = require(ServerScriptService.Managers.RoundManager)
    task.defer(RoundManager.Callables.EndRound, "Draw")

    return "Ending the round"
end

function Actions.Skip(Player: Player): string
    if RoundState.Value == "InRound" then
        return "That's for the intermission — end the round first"
    end

    local TimeManager = require(ServerScriptService.Managers.TimeManager)
    TimeManager.SetTime(0)

    return "Intermission skipped"
end

function Actions.Solo(Player: Player): string
    if StoredMinimum then
        GameMode.Config.MinimumFighters = StoredMinimum
        StoredMinimum = nil
    else
        StoredMinimum = GameMode.Config.MinimumFighters
        GameMode.Config.MinimumFighters = 1
    end

    -- `TimeManager` keeps its own copy, and that's the one gating the lobby clock.
    -- Read through `GetMinimumFighters` so the Studio override is reflected too.
    local TimeManager = require(ServerScriptService.Managers.TimeManager)
    local Effective = GameMode.GetMinimumFighters()
    TimeManager.Config.MinimumPlayerAmount = Effective

    if Effective <= 1 then
        return "Solo mode ON — rounds start with just you"
    end

    return "Solo mode OFF — minimum is "..Effective.." again"
end

return function()
    Network:SetConnection("AdminRoundAction", "REMOTE_FUNCTION", function(Player: Player, action: string)
        if not Player or not Player.Parent or not CanControl(Player) then
            return "No permission"
        end

        local Now = time()
        if Debounce[Player.UserId] and Now < Debounce[Player.UserId] then
            return nil
        end
        Debounce[Player.UserId] = Now + DEBOUNCE_TIME

        local Handler = Actions[action]
        if not Handler then
            return "Unknown action"
        end

        local Success, Result = pcall(Handler, Player)
        if not Success then
            warn("[AdminRoundControl] \""..tostring(action).."\" errored: "..tostring(Result))
            return "Errored — check the Output"
        end

        print("[AdminRoundControl] "..Player.Name.." ran "..action..": "..tostring(Result))

        return Result
    end)

    --[=[
        Tells the panel whether to show itself at all, and what the state is.

        Always returns a TABLE, never nil — even to somebody with no permission, who gets
        `{Allowed = false}`.

        That distinction matters. `Network:FireServerConnection` also returns nil when the
        remote doesn't exist on the client yet, and `PlayerInitter` runs before the client
        waits for `ServerLoaded` (see `ReplicatedFirst/Loading.client.luau`), so the panel
        can genuinely ask before this handler is registered. If "no permission" and "not
        ready yet" both looked like nil, that race would silently mean the panel never
        appears for anybody it loses.
    ]=]
    Network:SetConnection("AdminRoundStatus", "REMOTE_FUNCTION", function(Player: Player)
        if not Player or not Player.Parent or not CanControl(Player) then
            return {Allowed = false}
        end

        local Status = BuildStatus()
        Status.Allowed = true

        return Status
    end)
end
