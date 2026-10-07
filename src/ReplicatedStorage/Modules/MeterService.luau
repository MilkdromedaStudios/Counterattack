--[=[
    METER SERVICE

    Resources that are not cooldowns.

    A third of the roster is built around a number that goes up and down: Cuphead's Super
    Meter, the Mini-Gunner's heat, Tails' flight charge, Sans' dodge stamina, Pikachu's
    Static charge, Scrapheap's plates, Hollowmark's marks, Baldi's anger, Kirby's copied
    power. Before this they each kept that number in their own corner of
    `GameplayConfig.Cache` and each invented their own way to show it, which meant three
    of them didn't show it at all.

    HOW IT REPLICATES
    ----------------
    Every meter is a CHARACTER ATTRIBUTE. That is the whole trick, and it is why this module
    is about a hundred lines instead of a networking layer: attributes replicate to every
    client automatically, survive with the character, die with the character, and the client
    can watch one with `GetAttributeChangedSignal`. No remotes, no state to reconcile, no
    chance of the client's copy drifting from the server's.

    SERVER AUTHORITY
    ---------------
    Only the server may write a meter — `Spend`, `Add` and `Set` all refuse on the client.
    A client reading its own heat level is harmless; a client deciding it has a full Super
    Meter is not. The client half is strictly a display.

    THE SHARED TICKER
    ----------------
    One loop at 10 Hz handles regeneration and decay for every meter in the server, and
    stops dead when there are none. A meter with neither regen nor decay — a counter like
    Hollowmark's marks — costs nothing at all; it isn't in the ticker.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MeterService = {
    --- Seconds between regen/decay steps.
    TickRate = 0.1,
}

--[=[
    Definitions per character.

    Keyed by the character model, so a player respawning gets a clean slate and the old
    entry can be dropped by looking at `Parent`. The attribute itself lives on the
    character, so the actual VALUE is never in here — only the rules for changing it.
]=]
local Definitions: {[Model]: {[string]: any}} = {}
local TickThread: thread? = nil

--- Attribute name a meter lives under. Public so UI can subscribe to the right thing.
function MeterService.Attribute(name: string): string
    return "Meter_"..name
end

--------------------------------------------------------------------------------
-- TICKER
--------------------------------------------------------------------------------

local function EnsureTicker()
    if TickThread then
        return
    end

    TickThread = task.spawn(function()
        while next(Definitions) do
            local Delta = task.wait(MeterService.TickRate)

            for Char, Meters in Definitions do
                -- Dead or despawned character: drop the whole entry. The attributes went
                -- with the model, so there is nothing else to clean up.
                if not Char.Parent then
                    Definitions[Char] = nil
                    continue
                end

                for Name, Meter in Meters do
                    if Meter.RegenPerSecond == 0 and Meter.DecayPerSecond == 0 then
                        continue
                    end

                    local Attribute = MeterService.Attribute(Name)
                    local Current = Char:GetAttribute(Attribute) or 0
                    local Target = Current

                    --[=[
                        `RegenDelay` is what makes a spend feel like a spend.

                        Without it, a meter that regenerates is just a cooldown with extra
                        steps — you spend and it immediately starts coming back. The delay
                        gives the moment after spending real weight, which is the point of
                        having a resource instead of a cooldown.
                    ]=]
                    if Meter.RegenPerSecond > 0 and os.clock() >= (Meter.RegenAt or 0) then
                        Target += Meter.RegenPerSecond * Delta
                    end

                    if Meter.DecayPerSecond > 0 and os.clock() >= (Meter.DecayAt or 0) then
                        Target -= Meter.DecayPerSecond * Delta
                    end

                    Target = math.clamp(Target, Meter.Min, Meter.Max)

                    -- Only write when it actually moved: every attribute write replicates.
                    if math.abs(Target - Current) > 0.001 then
                        Char:SetAttribute(Attribute, Target)

                        if Meter.OnChanged then
                            local Ok, Err = pcall(Meter.OnChanged, Target, Current)
                            if not Ok then
                                warn("[MeterService] A meter's `OnChanged` errored: "..tostring(Err))
                            end
                        end
                    end
                end
            end
        end

        TickThread = nil
    end)
end

--------------------------------------------------------------------------------
-- DEFINING
--------------------------------------------------------------------------------

export type MeterSettings = {
    --- Ceiling.
    Max: number?,
    --- Floor. Almost always 0.
    Min: number?,
    --- Value it starts at.
    Start: number?,
    --- Units gained per second. `0` for a meter only abilities fill.
    RegenPerSecond: number?,
    --- Units lost per second. `0` for a meter only abilities drain. Used by heat.
    DecayPerSecond: number?,
    --- Seconds after a spend before regen resumes.
    RegenDelay: number?,
    --- Called on the server whenever the value moves.
    OnChanged: ((value: number, previous: number) -> ())?,
}

--[=[
    Declares a meter on a character.

    Safe to call again for the same name — it replaces the rules and leaves the value
    alone, which is what you want when an ability re-initialises mid-round.
]=]
function MeterService.Define(char: Model, name: string, settings: MeterSettings?)
    if not RunService:IsServer() or not char then
        return
    end

    settings = settings or {}

    Definitions[char] = Definitions[char] or {}

    local Existing = Definitions[char][name]

    Definitions[char][name] = {
        Max = settings.Max or 100,
        Min = settings.Min or 0,
        RegenPerSecond = settings.RegenPerSecond or 0,
        DecayPerSecond = settings.DecayPerSecond or 0,
        RegenDelay = settings.RegenDelay or 0,
        RegenAt = Existing and Existing.RegenAt or 0,
        DecayAt = Existing and Existing.DecayAt or 0,
        OnChanged = settings.OnChanged,
    }

    -- Only seed the value on a first definition, so re-defining doesn't refill it.
    if char:GetAttribute(MeterService.Attribute(name)) == nil then
        char:SetAttribute(MeterService.Attribute(name), settings.Start or 0)
    end

    if (settings.RegenPerSecond or 0) > 0 or (settings.DecayPerSecond or 0) > 0 then
        EnsureTicker()
    end
end

--------------------------------------------------------------------------------
-- READING
--------------------------------------------------------------------------------

--- Current value. Readable on both sides — it's the one thing a client may know.
function MeterService.Get(char: Model?, name: string): number
    if not char then
        return 0
    end

    return char:GetAttribute(MeterService.Attribute(name)) or 0
end

--- Ceiling, or `0` if the meter was never defined on this character.
function MeterService.GetMax(char: Model?, name: string): number
    local Meter = char and Definitions[char] and Definitions[char][name]
    return Meter and Meter.Max or 0
end

--- `0` to `1`, for progress bars.
function MeterService.Fraction(char: Model?, name: string): number
    local Max = MeterService.GetMax(char, name)
    if Max <= 0 then
        return 0
    end

    return math.clamp(MeterService.Get(char, name) / Max, 0, 1)
end

--- Is the meter at its ceiling? The usual gate on an ultimate.
function MeterService.IsFull(char: Model?, name: string): boolean
    local Max = MeterService.GetMax(char, name)
    return Max > 0 and MeterService.Get(char, name) >= Max - 0.001
end

--------------------------------------------------------------------------------
-- WRITING
--------------------------------------------------------------------------------

--- Sets a meter outright, clamped to its range. Server only.
function MeterService.Set(char: Model?, name: string, value: number)
    if not RunService:IsServer() or not char then
        return
    end

    local Meter = Definitions[char] and Definitions[char][name]
    if not Meter then
        -- A meter nothing declared should not silently start existing: the typo that
        -- caused it would otherwise be invisible until a player noticed a dead ability.
        warn("[MeterService.Set()] No meter named \""..name.."\" on "..char.Name..". Call `MeterService.Define` in the ability's `ExtraInit` first.")
        return
    end

    local Attribute = MeterService.Attribute(name)
    local Previous = char:GetAttribute(Attribute) or 0
    local Clamped = math.clamp(value, Meter.Min, Meter.Max)

    char:SetAttribute(Attribute, Clamped)

    if Meter.OnChanged and math.abs(Clamped - Previous) > 0.001 then
        local Ok, Err = pcall(Meter.OnChanged, Clamped, Previous)
        if not Ok then
            warn("[MeterService] A meter's `OnChanged` errored: "..tostring(Err))
        end
    end
end

--- Adds to a meter. Negative amounts are allowed. Server only.
function MeterService.Add(char: Model?, name: string, amount: number)
    if not RunService:IsServer() or not char then
        return
    end

    MeterService.Set(char, name, MeterService.Get(char, name) + amount)
end

--[=[
    Takes `amount` from a meter, but only if there's enough.

    @return `true` if it was spent, `false` if the meter was too low and nothing changed.

    The return value is the whole point: an ability gated on a resource asks
    `if not MeterService.Spend(...) then return end`, and the check and the deduction
    cannot drift apart because they are the same call.
]=]
function MeterService.Spend(char: Model?, name: string, amount: number): boolean
    if not RunService:IsServer() or not char then
        return false
    end

    local Meter = Definitions[char] and Definitions[char][name]
    if not Meter then
        return false
    end

    local Current = MeterService.Get(char, name)
    if Current < amount then
        return false
    end

    MeterService.Set(char, name, Current - amount)

    -- Hold regen off, so spending has a cost beyond the number going down.
    if Meter.RegenDelay > 0 then
        Meter.RegenAt = os.clock() + Meter.RegenDelay
    end

    return true
end

--[=[
    Pauses a meter's decay for a while.

    Heat meters want this: the Mini-Gunner's barrel should not start cooling the instant he
    stops firing, or there is no reason ever to stop firing.
]=]
function MeterService.HoldDecay(char: Model?, name: string, seconds: number)
    if not RunService:IsServer() or not char then
        return
    end

    local Meter = Definitions[char] and Definitions[char][name]
    if not Meter then
        return
    end

    Meter.DecayAt = os.clock() + seconds
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

--- Forgets a character's meters. The attributes die with the model on their own.
function MeterService.Clear(char: Model?)
    if not char then
        return
    end

    Definitions[char] = nil
end

Players.PlayerRemoving:Connect(function(player: Player)
    if player.Character then
        MeterService.Clear(player.Character)
    end
end)

return MeterService
