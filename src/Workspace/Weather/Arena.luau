--[=[
    WEATHER — ARENA

    Answers one question for the rest of the weather system: *where is the fight?*

    This is the piece that makes the weather land on the ROUND MAP instead of on NDS's
    island. NDS hardcoded its world — a 200 stud radius around the origin, an `Island`
    model, a `Structure` folder, a `WeatherDome`. None of that exists here, and none of it
    is assumed here. The arena is measured from whatever `MapManager` last put in the
    workspace under the name `Map`, every round, and every event positions itself relative
    to the numbers this module returns.

    Consequently a map sitting at (-4000, 200, 3000) gets its weather at
    (-4000, 200, 3000). That was the whole bug with pointing NDS's disasters at this game:
    they all ran at the origin, which for most maps is empty sky.
]=]

local Config = require(script.Parent.Config)

local Arena = {}

export type Region = {
    --- The map instance the measurement came from.
    Map: Instance,
    --- Centre of the arena, at ground level.
    Center: Vector3,
    --- Horizontal distance from `Center` to the edge, plus `Config.ArenaPadding`.
    Radius: number,
    --- Y of the lowest point of the map.
    GroundY: number,
    --- Y of the highest point of the map.
    TopY: number,
    --- Y that falling things spawn at.
    SkyY: number,
    --- Full bounding box size, unpadded.
    Size: Vector3,
}

--[=[
    Finds the live round map, or `nil` when there isn't one.

    Deliberately a plain `FindFirstChild` rather than a wait: the weather asks this
    question once per event, and the honest answer between rounds is "there is no map".
]=]
function Arena.GetMap(): Instance?
    return workspace:FindFirstChild(Config.MapName)
end

--[=[
    Containers inside the map that must not count towards its size.

    `WeatherEffects` is the important one and it is a genuine feedback loop: the weather
    parents everything it spawns in there, INSIDE the map, so that a map teardown cleans it
    up. Measure the map with those parts in it and the tsunami's two-thousand-stud wall or
    a meteor at cloud height becomes part of "how big is the arena" — so the next event
    measures bigger, spawns wider, and the arena grows every cycle until the weather is
    happening over the horizon.

    The rest are `MapManager`'s runtime folders. Ability instances and dropped items can be
    anywhere at all, and none of them are the arena's geometry.
]=]
local IGNORED_CONTAINERS = {
    WeatherEffects = true,
    InGame = true,
    Items = true,
    PermAbilities = true,
}

local function IsIgnored(Map: Instance, Descendant: Instance): boolean
    local Current = Descendant.Parent

    while Current and Current ~= Map do
        if IGNORED_CONTAINERS[Current.Name] then
            return true
        end
        Current = Current.Parent
    end

    return false
end

--[=[
    Measures a map's bounding box.

    `Model:GetBoundingBox()` is used when it can be — it's a single engine call and it is
    exact. A map authored as a FOLDER has no such method, so those are measured by walking
    the parts, which is why this returns a size of zero rather than throwing on an empty
    container.

    The engine call is skipped once any ignored container exists, because it has no way to
    leave one out and would fold the weather's own parts into the answer.
]=]
local function MeasureBounds(Map: Instance): (Vector3, Vector3)
    local HasIgnored = false
    for Name in IGNORED_CONTAINERS do
        if Map:FindFirstChild(Name) then
            HasIgnored = true
            break
        end
    end

    if Map:IsA("Model") and not HasIgnored then
        local Ok, CF, Size = pcall(function()
            local cf, size = Map:GetBoundingBox()
            return cf, size
        end)

        if Ok and CF and Size and Size.Magnitude > 0 then
            return CF.Position - Size * 0.5, CF.Position + Size * 0.5
        end
    end

    local Min: Vector3?, Max: Vector3? = nil, nil

    for _, Descendant in Map:GetDescendants() do
        if not Descendant:IsA("BasePart") then
            continue
        end

        if IsIgnored(Map, Descendant) then
            continue
        end

        --[[
            Skip the giant invisible volumes maps use for kill floors and region triggers.

            One 10,000 stud part is enough to put the measured centre somewhere nobody can
            stand and the radius somewhere over the horizon, which sends every meteor into
            the void. A part that is both enormous and see-through is scenery boundary, not
            arena.
        ]]
        if Descendant.Transparency >= 1 and Descendant.Size.Magnitude > 2000 then
            continue
        end

        local Half = Descendant.Size * 0.5
        local Position = Descendant.Position

        local PartMin = Position - Half
        local PartMax = Position + Half

        Min = Min and Vector3.new(math.min(Min.X, PartMin.X), math.min(Min.Y, PartMin.Y), math.min(Min.Z, PartMin.Z)) or PartMin
        Max = Max and Vector3.new(math.max(Max.X, PartMax.X), math.max(Max.Y, PartMax.Y), math.max(Max.Z, PartMax.Z)) or PartMax
    end

    if not Min or not Max then
        return Vector3.zero, Vector3.zero
    end

    return Min, Max
end

--[=[
    Measures the live round map and returns everything the events need to place
    themselves. Returns `nil` when no map is up.
]=]
function Arena.Measure(): Region?
    local Map = Arena.GetMap()
    if not Map then
        return nil
    end

    local Min, Max = MeasureBounds(Map)
    local Size = Max - Min

    --[[
        A map that measures as nothing is not a reason to refuse to run.

        Streaming, a map that is still being assembled, or a container whose geometry is
        all in a MeshPart that hasn't replicated yet all produce a zero box for a moment.
        Falling back to a sane radius around the origin of the container keeps the weather
        running instead of skipping the round.
    ]]
    local Center: Vector3
    local Radius: number
    local GroundY: number
    local TopY: number

    if Size.Magnitude <= 0 then
        local Origin = Map:IsA("Model") and Map:GetPivot().Position or Vector3.zero
        Center = Origin
        Radius = Config.FallbackRadius
        GroundY = Origin.Y
        TopY = Origin.Y + 100
    else
        Center = Vector3.new((Min.X + Max.X) * 0.5, Min.Y, (Min.Z + Max.Z) * 0.5)
        Radius = math.max(Size.X, Size.Z) * 0.5 + Config.ArenaPadding
        GroundY = Min.Y
        TopY = Max.Y
    end

    return {
        Map = Map,
        Center = Center,
        Radius = Radius,
        GroundY = GroundY,
        TopY = TopY,
        SkyY = TopY + Config.SkyHeight,
        Size = Size,
    }
end

--[=[
    A random point on the arena floor, at `GroundY`.

    `math.sqrt` on the random radius is not decoration: without it points bunch towards the
    centre and half the arena never sees a meteor.
]=]
function Arena.RandomPoint(Region: Region, Rand: Random, RadiusScale: number?): Vector3
    local Scale = RadiusScale or 1
    local Angle = Rand:NextNumber() * math.pi * 2
    local Distance = math.sqrt(Rand:NextNumber()) * Region.Radius * Scale

    return Vector3.new(
        Region.Center.X + math.cos(Angle) * Distance,
        Region.GroundY,
        Region.Center.Z + math.sin(Angle) * Distance
    )
end

--- True when a world position is inside the arena's horizontal footprint.
function Arena.Contains(Region: Region, Position: Vector3, Slack: number?): boolean
    local Flat = Vector3.new(Position.X - Region.Center.X, 0, Position.Z - Region.Center.Z)
    return Flat.Magnitude <= Region.Radius + (Slack or 0)
end

return Arena
