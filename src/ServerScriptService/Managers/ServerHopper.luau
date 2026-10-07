--[=[
    SERVER HOPPER

    Moves a lonely server's players into a busier one, so nobody sits in an empty lobby
    watching a clock that won't start.

    WHY IT'S BUILT THIS WAY
    -----------------------
    The obvious approach — ask Roblox's web API which servers are running — does not work
    from inside a game. `HttpService` refuses requests to roblox.com domains, so a server
    cannot list its own game's other servers. There is no in-engine API for it either.

    So the servers tell each other. `MemoryStoreService` is shared across every server of a
    place, and every server writes its own JobId and player count into a sorted map on a
    heartbeat. A server that finds itself short of players reads that map, picks the
    busiest server that still has room, and teleports its players straight into it by
    JobId. Entries carry a short TTL, so a server that dies simply ages out of the list
    instead of leaving a ghost for people to be sent to.

    THE RULES IT PLAYS BY
    ---------------------
    Getting this wrong is worse than not having it — two half-empty servers can spend all
    day throwing players at each other. Four guards stop that:

      1. A target must have at least as many players as us, and ties are broken by JobId
         so only ONE of an equal pair ever moves. Without that, two one-player servers
         swap populations forever and are no less lonely afterwards.
      2. A target must have room for all of us, or we don't go.
      3. We wait `PatienceSeconds` of being under-populated before doing anything, so a
         server that's briefly quiet between rounds isn't torn down.
      4. Never mid-round. Only from the lobby, and never while a round is running.

    It is also completely inert in Studio: `TeleportService` doesn't work there, and a
    test session should never try to hop.
]=]

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local GameMode = require(ReplicatedStorage.Modules.GameMode)
local Utils = require(ReplicatedStorage.Modules.Utils)

local RoundState: StringValue = ReplicatedStorage.RoundInfo.CurrentState

local ServerHopper = {
    --- Master switch.
    Enabled = true,

    --[=[
        Below this many players, this server counts as under-populated and starts looking
        for somewhere better.

        Defaults to whatever it takes to start a round — being unable to start is exactly
        the problem this solves.
    ]=]
    MinimumPlayers = GameMode.Config.MinimumFighters,

    --- Seconds of being under-populated before we actually move anybody.
    ---
    --- Long enough that a server which is quiet for a moment between rounds is left alone.
    PatienceSeconds = 45,

    --- Seconds between registry heartbeats.
    HeartbeatSeconds = 15,

    --- How long a registry entry lives without being refreshed. Must comfortably exceed
    --- `HeartbeatSeconds` or healthy servers will drop out of their own list.
    EntryTTL = 60,

    --- Don't send anyone to a server at or above this. Roblox's own cap is
    --- `Players.MaxPlayers`; this leaves headroom so we never arrive at a full server.
    MaxTargetPlayers = 0, --resolved in `Init` from `Players.MaxPlayers`

    --- Seconds to wait after a failed hop before trying again.
    RetryCooldown = 90,

    --- Prints what it's doing. Worth leaving on until you've seen it work in a live game.
    Verbose = true,
}

local Registry = MemoryStoreService:GetSortedMap("Counterattack_ServerRegistry")

--- `time()` after which another hop may be attempted.
local NextAttemptAllowed = 0
--- `time()` this server first became under-populated, or `nil` while healthy.
local UnderpopulatedSince: number? = nil

local function Log(...)
    if ServerHopper.Verbose then
        print("[ServerHopper]", ...)
    end
end

--------------------------------------------------------------------------------
-- REGISTRY
--------------------------------------------------------------------------------

--- Publishes this server's headcount so other servers can find it.
function ServerHopper._Heartbeat()
    local Count = #Players:GetPlayers()

    --[[
        A server with nobody in it deliberately removes itself rather than advertising
        zero. Nothing should ever be sent to an empty server — that's the state this whole
        system exists to get people out of.
    ]]
    if Count <= 0 then
        pcall(function()
            Registry:RemoveAsync(game.JobId)
        end)
        return
    end

    local Success, Err = pcall(function()
        Registry:SetAsync(game.JobId, {
            Players = Count,
            InRound = RoundState.Value == "InRound",
        }, ServerHopper.EntryTTL)
    end)

    if not Success then
        warn("[ServerHopper] Couldn't publish to the server registry: "..tostring(Err))
    end
end

--[=[
    Finds the best server to send this server's players to.

    @return The target's JobId and its player count, or `nil` if there's nowhere better.
]=]
function ServerHopper._FindBestServer(): (string?, number?)
    local Success, Entries = pcall(function()
        -- The map is keyed by JobId, so the range comes back in JobId order rather than by
        -- headcount. 100 is plenty to sort through in Lua and well inside the API's limit.
        return Registry:GetRangeAsync(Enum.SortDirection.Ascending, 100)
    end)

    if not Success then
        warn("[ServerHopper] Couldn't read the server registry: "..tostring(Entries))
        return nil, nil
    end

    local OwnCount = #Players:GetPlayers()

    local BestId, BestCount = nil, 0

    for _, Entry in Entries do
        local JobId = Entry.key
        local Info = Entry.value

        if JobId == game.JobId or typeof(Info) ~= "table" then
            continue
        end

        local Count = tonumber(Info.Players) or 0

        -- Rule 1: never move toward a smaller server.
        if Count < OwnCount then
            continue
        end

        --[=[
            Rule 1b — the tie.

            Two equally-lonely servers both want to merge, and if both act they simply
            swap populations and are just as lonely as before, forever.

            Breaking the tie on JobId gives the pair a direction: the lexicographically
            SMALLER JobId moves to the larger, never the reverse. Because string ordering
            is a total order, there is no set of servers that can form a cycle — so two
            one-player servers reliably become one two-player server, and never bounce.
        ]=]
        if Count == OwnCount and game.JobId >= JobId then
            continue
        end

        -- Rule 2: everyone has to fit.
        if Count + OwnCount > ServerHopper.MaxTargetPlayers then
            continue
        end

        if Count > BestCount then
            BestId, BestCount = JobId, Count
        end
    end

    return BestId, BestCount
end

--------------------------------------------------------------------------------
-- HOPPING
--------------------------------------------------------------------------------

--- Is it safe to move people right now?
function ServerHopper._CanHop(): boolean
    if not ServerHopper.Enabled or RunService:IsStudio() then
        return false
    end

    if time() < NextAttemptAllowed then
        return false
    end

    -- Rule 4: never pull anybody out of a live round.
    if RoundState.Value == "InRound" then
        return false
    end

    local Loaded = Utils.Player.GetLoadedPlayers(false)
    if #Loaded <= 0 then
        return false
    end

    -- Everybody has to have finished loading. Teleporting somebody mid-load loses their
    -- session and can drop them on the error screen.
    if #Loaded ~= #Players:GetPlayers() then
        return false
    end

    return true
end

--- Moves everyone on this server into `jobId`.
function ServerHopper._HopTo(jobId: string, targetCount: number)
    local Party = Players:GetPlayers()
    if #Party <= 0 then
        return
    end

    Log(("Moving %d player(s) to a server with %d in it."):format(#Party, targetCount))

    local Options = Instance.new("TeleportOptions")
    Options.ServerInstanceId = jobId

    local Success, Err = pcall(function()
        return TeleportService:TeleportAsync(game.PlaceId, Party, Options)
    end)

    if Success then
        -- Take ourselves out of the registry: everyone is leaving, so this server must not
        -- keep advertising the headcount it's about to lose.
        pcall(function()
            Registry:RemoveAsync(game.JobId)
        end)
        return
    end

    warn("[ServerHopper] Teleport failed: "..tostring(Err))
    NextAttemptAllowed = time() + ServerHopper.RetryCooldown
end

--- The main loop body. Decides whether this server should be looking for a better one.
function ServerHopper._Tick()
    ServerHopper._Heartbeat()

    if not ServerHopper._CanHop() then
        return
    end

    local Count = #Players:GetPlayers()

    if Count >= ServerHopper.MinimumPlayers then
        -- Healthy. Reset the patience clock.
        if UnderpopulatedSince then
            Log("Population recovered — no longer looking to move.")
        end
        UnderpopulatedSince = nil
        return
    end

    -- Rule 3: wait before acting, so a momentary lull doesn't empty the server.
    if not UnderpopulatedSince then
        UnderpopulatedSince = time()
        Log(("Only %d player(s) here. Waiting %ds before looking for a busier server.")
            :format(Count, ServerHopper.PatienceSeconds))
        return
    end

    if time() - UnderpopulatedSince < ServerHopper.PatienceSeconds then
        return
    end

    local TargetId, TargetCount = ServerHopper._FindBestServer()
    if not TargetId then
        -- Nowhere better exists. Stay put and keep checking; another server may fill up.
        return
    end

    ServerHopper._HopTo(TargetId, TargetCount)
end

function ServerHopper:Init()
    if not RunService:IsServer() then
        return
    end

    -- Resolved here rather than at module scope: `Players.MaxPlayers` isn't meaningful
    -- until the server is actually running.
    if ServerHopper.MaxTargetPlayers <= 0 then
        ServerHopper.MaxTargetPlayers = Players.MaxPlayers
    end

    if RunService:IsStudio() then
        Log("Studio session — server hopping is disabled. It only works in a live game.")
        return
    end

    if not ServerHopper.Enabled then
        return
    end

    -- Stop advertising the moment the server starts shutting down, so nobody is sent to a
    -- server that is on its way out.
    game:BindToClose(function()
        pcall(function()
            Registry:RemoveAsync(game.JobId)
        end)
    end)

    Log("Active. Servers with fewer than "..ServerHopper.MinimumPlayers.." player(s) will look for a busier one.")

    task.spawn(function()
        -- A short stagger before the first tick so twenty servers booting at once don't
        -- all hit MemoryStore on the same frame.
        task.wait(math.random(1, ServerHopper.HeartbeatSeconds))

        while true do
            local Success, Err = pcall(ServerHopper._Tick)
            if not Success then
                warn("[ServerHopper] Tick errored: "..tostring(Err))
            end

            task.wait(ServerHopper.HeartbeatSeconds)
        end
    end)
end

return ServerHopper
