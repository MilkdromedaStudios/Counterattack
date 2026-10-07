--[=[
    WEATHER — RUNNER

    The clock that decides what weather happens, when, and where.

    THE LOOP
    --------
    A round starts. After `Config.FirstEventDelay` seconds of calm, a batch of events is
    picked, the arena is measured, a warning goes out, everything builds up, and then the
    weather runs. When it ends the arena is cleaned and, after a gap, the next batch begins.

    ESCALATION — WHY THIS IS ALSO THE ROUND TIMER
    ---------------------------------------------
    Rounds are last-one-standing with NO CLOCK. Nothing calls a draw, so a final two who
    both refuse to engage would stand in opposite corners of the map forever.

    Rather than bolt a hidden countdown back on, the ARENA is the deadline. Past
    `Escalation.GracePeriod` every part of this loop turns up:

      * the batch gets another event every `SecondsPerExtraEvent`, up to every event there is
      * the gap between batches collapses towards `MinInterval`, so batches start OVERLAPPING
        and the pile grows past what the count alone would give
      * the build-up shortens, so late warnings are barely warnings
      * damage climbs towards `1 + MaxDamageBonus`

    Left long enough that is eleven simultaneous events at double damage over a map with
    nowhere left to stand, and the round resolves itself. That outcome is intended, not a
    failure mode: it's a soft deadline made of gameplay rather than a hard one made of a
    countdown, and nobody gets told the round is over — they get told to fight now.

    WHERE IT RUNS
    -------------
    Every position comes from `Arena.Measure()`, which measures `workspace.Map` — the model
    `MapManager` puts up for the round. Nothing here knows or cares about NDS's island, and
    nothing reads `Workspace.NDS`, so that folder can be moved to ReplicatedStorage or
    deleted without touching a line of this.

    COUPLING
    --------
    Two touch points with the rest of the game, both read-only and both optional:
      * `ReplicatedStorage.RoundInfo.CurrentState` — tells it when a round is on.
      * `workspace:GetAttribute("WeatherPower")` — the machine's charge, if there is one.
    Take either away and the weather degrades to "runs constantly at one event", rather
    than erroring.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Network = require(ReplicatedStorage.Modules.Network)

local Config = require(script.Parent.Config)
local Arena = require(script.Parent.Arena)
local Context = require(script.Parent.Context)

local EventsFolder = script.Parent.Events

local Runner = {
    --- Contexts for everything currently running, so a round ending can stop all of them.
    Active = {},
    --- Name of the last event picked, for `Config.AvoidRepeats`.
    LastPicked = nil,
    --- Bumped every time the round state changes. A cycle whose generation is stale exits.
    Generation = 0,
    --- `os.clock()` when the current round's cycle started. Drives the escalation.
    RoundStartedAt = nil :: number?,
    --- `os.clock()` of the last "the storm is getting worse" banner.
    LastEscalationNotice = 0,
    --[=[
        Which event modules are running RIGHT NOW, by module name.

        Needed the moment batches start overlapping. Two concurrent runs of the same event
        would share the module's upvalues and collide on the client visual state, which is
        keyed by event name — the first one to finish would clear the fog out from under
        the second. One of each at a time, and with eleven events that is already as big a
        pile as the escalation can ask for.
    ]=]
    RunningModules = {},
}

local Rand = Random.new()

local function Log(...)
    if Config.Debug then
        print("[Weather]", ...)
    end
end

--------------------------------------------------------------------------------
-- EVENT LOADING
--------------------------------------------------------------------------------

--[=[
    Loads every enabled event module once, at startup.

    Each require is its own `pcall`: an event with a syntax error in it should cost you
    that event, not the entire weather system. The warning names the module so a broken one
    is obvious rather than mysteriously absent from the rotation.
]=]
local function LoadEvents(): {[string]: any}
    local Loaded = {}

    for _, Name in Config.EnabledEvents do
        local Module = EventsFolder:FindFirstChild(Name)
        if not Module or not Module:IsA("ModuleScript") then
            warn("[Weather] `Config.EnabledEvents` lists \""..Name.."\" but there is no such ModuleScript in Workspace.Weather.Events. Skipping it.")
            continue
        end

        local Ok, Result = pcall(require, Module)
        if not Ok then
            warn("[Weather] Event \""..Name.."\" failed to load and won't be used: "..tostring(Result))
            continue
        end

        if typeof(Result) ~= "table" or typeof(Result.Run) ~= "function" then
            warn("[Weather] Event \""..Name.."\" doesn't return a table with a `Run` function. Skipping it.")
            continue
        end

        Result.ModuleName = Name
        Loaded[Name] = Result
    end

    return Loaded
end

local Events = LoadEvents()

--------------------------------------------------------------------------------
-- ESCALATION
--------------------------------------------------------------------------------

--- Seconds since the current round's weather cycle began.
local function RoundElapsed(): number
    if not Runner.RoundStartedAt then
        return 0
    end
    return os.clock() - Runner.RoundStartedAt
end

--[=[
    How far into the escalation the round is, from `0` to `1`.

    `0` for the whole grace period, then climbing. This drives the interval, the build-up
    and the damage; the event COUNT uses raw elapsed time instead, because it wants to keep
    climbing past the point where everything else has bottomed out.
]=]
local function EscalationAlpha(): number
    if not Config.Escalation.Enabled then
        return 0
    end

    local Past = RoundElapsed() - Config.Escalation.GracePeriod
    if Past <= 0 then
        return 0
    end

    return math.clamp(Past / math.max(Config.Escalation.IntervalFloorAt - Config.Escalation.GracePeriod, 1), 0, 1)
end

--[=[
    How many events should run at once.

    Three inputs, added: the base, the weather machine's charge, and however many the round
    has earned by dragging on. The escalation term has no ceiling of its own — it's clamped
    only by `MaxSimultaneousEvents`, which is set to the full event list, so a long enough
    round genuinely ends with everything running at once.
]=]
local function SimultaneousCount(): number
    local Power = workspace:GetAttribute("WeatherPower")
    if typeof(Power) ~= "number" then
        Power = 0
    end

    local Extra = 0
    if Config.Escalation.Enabled then
        local Past = RoundElapsed() - Config.Escalation.GracePeriod
        if Past > 0 then
            Extra = math.floor(Past / Config.Escalation.SecondsPerExtraEvent) + 1
        end
    end

    return math.clamp(
        Config.BaseSimultaneousEvents + math.floor(Power) + Extra,
        1,
        Config.MaxSimultaneousEvents
    )
end

--- Seconds of calm before the next batch. Collapses as the round drags on.
local function CurrentInterval(): number
    local Alpha = EscalationAlpha()
    return Config.IntervalBetweenEvents
        + (Config.Escalation.MinInterval - Config.IntervalBetweenEvents) * Alpha
end

--- Seconds of warning before a batch turns lethal. Also shrinks.
local function CurrentBuildup(): number
    local Alpha = EscalationAlpha()
    return Config.BuildupTime
        + (Config.Escalation.MinBuildup - Config.BuildupTime) * Alpha
end

--[=[
    Damage multiplier for a batch starting now.

    Ramps on its OWN clock rather than sharing `EscalationAlpha`, because damage should
    still be climbing after the interval has already bottomed out — that's the part that
    actually finishes a round where two people are hiding from each other.
]=]
local function CurrentDamageScale(): number
    if not Config.Escalation.Enabled then
        return 1
    end

    local Past = RoundElapsed() - Config.Escalation.GracePeriod
    if Past <= 0 then
        return 1
    end

    local Alpha = math.clamp(Past / math.max(Config.Escalation.DamageRampAt, 1), 0, 1)
    return 1 + Config.Escalation.MaxDamageBonus * Alpha
end

--------------------------------------------------------------------------------
-- PICKING
--------------------------------------------------------------------------------

--[=[
    Picks `Count` distinct events.

    `AvoidRepeats` only blocks the event that ran LAST, and only when there is something
    else to pick — otherwise a one-event rotation would deadlock looking for a different
    one, which is how the original's picking loop could hang.
]=]
local function Pick(Count: number): {any}
    local Pool = {}
    for _, Event in Events do
        table.insert(Pool, Event)
    end

    --[[
        An event already running is not available to be picked again. See `RunningModules`.
    ]]
    for Index = #Pool, 1, -1 do
        if Runner.RunningModules[Pool[Index].ModuleName] then
            table.remove(Pool, Index)
        end
    end

    if #Pool == 0 then
        return {}
    end

    --[[
        `Count < #Pool` matters once escalation is running.

        Late in a round the batch wants every event there is. Holding one back because it
        ran last would silently cap the pile at ten out of eleven forever — variety is a
        concern when you're picking one or two, not when you're picking all of them.
    ]]
    if Config.AvoidRepeats and Count < #Pool and #Pool > 1 and Runner.LastPicked then
        for Index = #Pool, 1, -1 do
            if Pool[Index].ModuleName == Runner.LastPicked then
                table.remove(Pool, Index)
                break
            end
        end
    end

    local Chosen = {}
    Count = math.min(Count, #Pool)

    for _ = 1, Count do
        local Index = Rand:NextInteger(1, #Pool)
        table.insert(Chosen, Pool[Index])
        table.remove(Pool, Index)
    end

    if Chosen[1] then
        Runner.LastPicked = Chosen[1].ModuleName
    end

    return Chosen
end

--------------------------------------------------------------------------------
-- RUNNING ONE EVENT
--------------------------------------------------------------------------------

--[=[
    Runs one event end to end on a given arena.

    Everything the event does is wrapped: a `Run` that throws halfway still gets its
    `Cleanup` and still gets its context torn down. That is the difference between one bad
    event and an arena that keeps somebody's fog and half a tornado for the rest of the
    server's life.
]=]
local function RunEvent(Event, Region: Arena.Region, Generation: number, Batch: {Buildup: number, DamageScale: number})
    Runner.RunningModules[Event.ModuleName] = true

    local Ctx = Context.new(Region, Event.Name, Rand:NextInteger(1, 1e9))

    --[[
        The batch's escalation is baked in when the event starts, not read live.

        An event that ramped up mid-run would change how hard it hits while the player is
        already standing in it, which is unreadable. Fixed for the life of the event means
        "the storm that just arrived is worse than the last one" — which is the thing
        players can actually learn from.
    ]]
    Ctx.DamageScale = Batch.DamageScale

    table.insert(Runner.Active, Ctx)

    local function Finish()
        Ctx.Running = false

        if Event.Cleanup then
            local Ok, Err = pcall(Event.Cleanup, Ctx)
            if not Ok then
                warn("[Weather] "..Event.Name.." errored in Cleanup: "..tostring(Err))
            end
        end

        -- Give the fade-out a moment before the parts vanish, so a whiteout doesn't snap
        -- off the instant the timer expires.
        task.delay(4, function()
            Ctx:Stop()
        end)

        local Index = table.find(Runner.Active, Ctx)
        if Index then
            table.remove(Runner.Active, Index)
        end

        Runner.RunningModules[Event.ModuleName] = nil
    end

    Log("building up", Event.Name)

    if Event.Buildup then
        local Ok, Err = pcall(Event.Buildup, Ctx)
        if not Ok then
            warn("[Weather] "..Event.Name.." errored in Buildup: "..tostring(Err))
        end
    end

    -- Interruptible build-up: a round that ends during the warning must not still get the
    -- event 12 seconds later, over the lobby.
    local Waited = 0
    while Waited < Batch.Buildup do
        if not Ctx.Running or Generation ~= Runner.Generation then
            Finish()
            return
        end
        Waited += task.wait(0.25)
    end

    Log("running", Event.Name)

    local Duration = Event.Duration or Config.DefaultDuration

    task.spawn(function()
        local Ok, Err = pcall(Event.Run, Ctx)
        if not Ok then
            warn("[Weather] "..Event.Name.." errored while running: "..tostring(Err))
        end
    end)

    local Elapsed = 0
    while Elapsed < Duration do
        if not Ctx.Running or Generation ~= Runner.Generation then
            break
        end
        Elapsed += task.wait(0.25)
    end

    Log("ended", Event.Name)
    Finish()
end

--------------------------------------------------------------------------------
-- THE CYCLE
--------------------------------------------------------------------------------

local function StopAll()
    Runner.Generation += 1

    for _, Ctx in Runner.Active do
        Ctx.Running = false
        pcall(function()
            Ctx:Stop()
        end)
    end
    table.clear(Runner.Active)
    table.clear(Runner.RunningModules)

    Network:FireAllClientConnection("WeatherVisuals", "REMOTE_EVENT", "All", nil, 1)
    workspace:SetAttribute("CurrentWeather", "")
end

--[=[
    One round's worth of weather: wait, pick, run, repeat until the round ends.

    `Generation` is what stops an old cycle from waking up inside a new round. Every state
    change bumps it; a cycle checks its own copy at each step and exits the moment it goes
    stale. Without it, a round that ended during `IntervalBetweenEvents` would come back to
    life 35 seconds later and start a tornado in an empty lobby.
]=]
local function Cycle(Generation: number)
    local function Stale(): boolean
        return Generation ~= Runner.Generation
    end

    local function Sleep(Seconds: number): boolean
        local Slept = 0
        while Slept < Seconds do
            if Stale() then
                return false
            end
            Slept += task.wait(0.25)
        end
        return not Stale()
    end

    Runner.RoundStartedAt = os.clock()
    Runner.LastEscalationNotice = 0

    if not Sleep(Config.FirstEventDelay) then
        return
    end

    local LastCount = 0

    while not Stale() do
        local Region = Arena.Measure()

        if not Region then
            -- No map up. Normal between rounds and during a teardown; wait for one rather
            -- than aborting the cycle, since the round may simply still be loading.
            if not Sleep(3) then
                return
            end
            continue
        end

        --[=[
            Everything about this batch is read ONCE, here.

            The count, the build-up, the damage and the gap after it are all snapshots of
            how far into the round we are — so a batch behaves consistently from its warning
            to its last tick, and the escalation shows up as "each storm is worse than the
            last" rather than as numbers sliding around underneath a storm that's already
            running.
        ]=]
        local Batch = {
            Buildup = CurrentBuildup(),
            DamageScale = CurrentDamageScale(),
        }

        --[=[
            The count is a TARGET to hold, not a batch size to launch.

            "One, then another, then another" is a statement about how many events are
            blowing at once, so what matters here is that target minus however many are
            already running. Topping up only the difference is what makes the next event
            JOIN the storm instead of replacing it.
        ]=]
        local Target = SimultaneousCount()

        local Running = 0
        for _ in Runner.RunningModules do
            Running += 1
        end

        local Count = Config.AccumulateEvents and math.max(Target - Running, 0) or Target

        if Config.AccumulateEvents and Count == 0 then
            -- Already at target. Poll instead of sleeping a whole interval so the pile is
            -- topped back up promptly when an event ends or the target climbs.
            if not Sleep(2) then
                return
            end
            continue
        end

        local Chosen = Pick(Count)

        if #Chosen == 0 then
            --[[
                Two very different reasons to get nothing back, and only one is a problem.

                Late in an escalated round EVERY event is already running, which is the
                system working exactly as intended — wait for one to finish and pick again
                rather than aborting the cycle and leaving the round with no weather at all
                for the rest of its life.
            ]]
            if next(Runner.RunningModules) then
                if not Sleep(5) then
                    return
                end
                continue
            end

            warn("[Weather] No usable events. Check `Config.EnabledEvents` against Workspace.Weather.Events.")
            return
        end

        local Names = {}
        for _, Event in Chosen do
            table.insert(Names, Event.Name)
        end

        --[[
            `CurrentWeather` has to name everything blowing right now, not just what this
            pass added — once events accumulate, listing only the newcomer would report a
            four-event storm as "Tornado".
        ]]
        local AllNames = {}
        for ModuleName in Runner.RunningModules do
            local Event = Events[ModuleName]
            table.insert(AllNames, Event and Event.Name or ModuleName)
        end
        for _, Name in Names do
            table.insert(AllNames, Name)
        end

        local Total = Running + #Chosen

        workspace:SetAttribute("CurrentWeather", table.concat(AllNames, " + "))
        workspace:SetAttribute("WeatherIntensity", Total)
        Log(("picked %s  (%.0fs in, x%.2f damage, %.0fs buildup)")
            :format(table.concat(Names, ", "), RoundElapsed(), Batch.DamageScale, Batch.Buildup))

        --[=[
            Tell people the storm is ramping, and only when it actually has.

            `Total > LastCount` is the honest trigger — the escalation is REAL to a
            player at the moment another event joins the pile, not at the moment a timer
            crossed a threshold. It counts the whole storm, not the size of this top-up,
            so going from three events to four announces even though only one was added. Rate-limited so a long round doesn't spend itself shouting.

            Without this the ramp reads as the game breaking down rather than as the round
            being brought to a close on purpose.
        ]=]
        if Total > LastCount and LastCount > 0
            and os.clock() - Runner.LastEscalationNotice >= Config.Escalation.AnnounceEvery
        then
            Runner.LastEscalationNotice = os.clock()
            Network:FireAllClientConnection(
                "WeatherWarning",
                "REMOTE_EVENT",
                "THE STORM IS GETTING WORSE",
                ("%d at once now. It is not going to stop. Finish it."):format(Total)
            )
            task.wait(3)
        end
        LastCount = Total

        -- The banner names everything at once so a multi-event round reads as one storm
        -- rather than as three warnings stepping on each other.
        Network:FireAllClientConnection(
            "WeatherWarning",
            "REMOTE_EVENT",
            #Chosen > 1 and table.concat(Names, "  +  ") or Chosen[1].Warning or Chosen[1].Name,
            #Chosen > 1 and "Everything at once. Good luck." or Chosen[1].Hint
        )

        local Longest = 0
        for _, Event in Chosen do
            Longest = math.max(Longest, Event.Duration or Config.DefaultDuration)
            task.spawn(RunEvent, Event, Region, Generation, Batch)
        end

        --[=[
            When the next top-up happens.

            Accumulating, this is just one interval — the pile is checked again while the
            storm is still blowing, so a new event joins rather than replaces. In batch
            mode it waits the storm out first, and only the collapsing `CurrentInterval()`
            makes late batches overlap. Either way the end state is the same: there is
            nowhere left to stand, which is what ends a round two people refuse to end.
        ]=]
        local Wait
        if Config.AccumulateEvents then
            --[[
                Waiting for `Longest` here is what made the old cycle run in batches: the
                arena had to clear before anything else could start. Accumulating means the
                next top-up is due one interval from now regardless of what is still
                blowing.
            ]]
            Wait = Batch.Buildup + CurrentInterval()
        else
            local Overlap = 1 - EscalationAlpha()
            Wait = Batch.Buildup + Longest * Overlap + CurrentInterval()
        end

        if not Sleep(Wait) then
            return
        end
    end
end

--------------------------------------------------------------------------------
-- WIRING
--------------------------------------------------------------------------------

if not Config.Enabled then
    Log("disabled by Config.Enabled")
    return
end

if not RunService:IsServer() then
    return
end

--[[
    Create the client-facing remotes from the SERVER.

    `Network:SetConnection` is what actually makes the RemoteEvent instance, and
    `FireAllClientConnection` silently does nothing when the instance doesn't exist yet. If
    only the clients created them, the first warning of the session would go out before any
    client had loaded and simply vanish. Creating them here means they exist from the
    moment the server boots.
]]
Network:SetConnection("WeatherWarning", "REMOTE_EVENT", function() end)
Network:SetConnection("WeatherVisuals", "REMOTE_EVENT", function() end)

local RoundInfo = ReplicatedStorage:WaitForChild("RoundInfo", 30)
local RoundState: StringValue? = RoundInfo and RoundInfo:FindFirstChild("CurrentState")

if not RoundState then
    warn("[Weather] `ReplicatedStorage.RoundInfo.CurrentState` is missing, so the weather can't tell when a round is on. Running continuously instead.")
    task.spawn(function()
        Runner.Generation += 1
        Cycle(Runner.Generation)
    end)
    return
end

local function OnStateChanged(State: string)
    StopAll()

    if State ~= "InRound" then
        Log("round over — weather stopped")
        return
    end

    local Generation = Runner.Generation
    Log("round started — weather cycle", Generation)
    task.spawn(Cycle, Generation)
end

RoundState.Changed:Connect(OnStateChanged)

-- Catch the case where the server is already in a round when this script starts — the
-- open arena parks `CurrentState` on "InRound" at boot and never changes it again, so
-- waiting for a `Changed` that will never fire would mean no weather at all.
if RoundState.Value == "InRound" then
    task.defer(OnStateChanged, RoundState.Value)
end

Log("ready —", #Config.EnabledEvents, "event(s) configured")
