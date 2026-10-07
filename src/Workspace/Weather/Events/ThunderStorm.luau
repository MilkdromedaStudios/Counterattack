--[=[
    THUNDER STORM

    Lightning walks the arena and prefers whatever is standing highest.

    NDS's `createlightning` built its bolt by stepping a point downwards, checking a
    Region3 for anything taller nearby and snapping to it. The same idea is here, with the
    region query replaced by a spherecast — Region3 is deprecated, capped at 100 results,
    and on a large arena it silently returned whichever hundred parts it felt like.

    The "prefers high ground" behaviour is the entire point of the event: it is the one
    piece of weather that punishes a player for taking the rooftop, so it must actually
    find the rooftop.
]=]

local Config = require(script.Parent.Parent.Config)

local SEGMENT_RANGE = 45
local MAX_SEGMENTS = 22
local STRIKE_RADIUS = 14
local STRIKE_DAMAGE = 70

--[=[
    Finds what the bolt should hit: the highest thing near a point, fighters included.

    Fighters are checked separately and given a deliberate bias, because a player standing
    on open ground is exactly who this event is for and the geometry around them will
    almost always be taller.
]=]
local function PickTarget(Context, Around: Vector3): Vector3
    local Best = Context:GroundAt(Around)

    local Params = OverlapParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {Context.Effects}
    Params.MaxParts = 60

    local Nearby = workspace:GetPartBoundsInRadius(
        Vector3.new(Around.X, (Context.Region.GroundY + Context.Region.TopY) * 0.5, Around.Z),
        SEGMENT_RANGE,
        Params
    )

    for _, Part in Nearby do
        local Top = Part.Position + Vector3.new(0, Part.Size.Y * 0.5, 0)
        if Top.Y > Best.Y then
            Best = Top
        end
    end

    for _, Character in Context:Fighters() do
        local Root = Character:FindFirstChild("HumanoidRootPart")
        if not Root then
            continue
        end

        local Flat = Vector3.new(Root.Position.X - Around.X, 0, Root.Position.Z - Around.Z)
        if Flat.Magnitude <= SEGMENT_RANGE and Root.Position.Y >= Best.Y - 8 then
            Best = Root.Position
        end
    end

    return Best
end

local function Strike(Context)
    local Origin = Context:RandomPoint(0.85)
    local Target = PickTarget(Context, Origin)

    local Bolt = Instance.new("Model")
    Bolt.Name = "Lightning"
    Bolt.Parent = Context.Effects
    Context:Track(Bolt, 0.6)

    -- Walk down from the clouds to the target in jagged steps. Each segment is a thin
    -- neon part rotated to point at the next.
    local Point = Vector3.new(Target.X, Context.Region.SkyY, Target.Z)
    local Segments = 0

    while Segments < MAX_SEGMENTS and Point.Y > Target.Y do
        Segments += 1

        local Remaining = Point.Y - Target.Y
        local Drop = math.min(Remaining, Context.Rand:NextNumber(20, 60))
        --[[
            The jitter shrinks as the bolt gets close to the ground.

            Constant jitter (what NDS used) makes the last segment land up to 40 studs from
            whatever the bolt was aiming at, so the strike and the damage happen in visibly
            different places.
        ]]
        local Spread = math.clamp(Remaining / 120, 0, 1) * 22
        local Next = Vector3.new(
            Point.X + Context.Rand:NextNumber(-Spread, Spread),
            Point.Y - Drop,
            Point.Z + Context.Rand:NextNumber(-Spread, Spread)
        )

        if Remaining - Drop <= 0.01 then
            Next = Target
        end

        local Length = (Next - Point).Magnitude
        local Segment = Instance.new("Part")
        Segment.Anchored = true
        Segment.CanCollide = false
        Segment.CanQuery = false
        Segment.CanTouch = false
        Segment.CastShadow = false
        Segment.Material = Enum.Material.Neon
        Segment.Color = Color3.fromRGB(215, 235, 255)
        Segment.Size = Vector3.new(0.8, Length, 0.8)
        Segment.CFrame = CFrame.lookAt(Point:Lerp(Next, 0.5), Next) * CFrame.Angles(math.pi * 0.5, 0, 0)
        Segment.Parent = Bolt

        Point = Next
    end

    local Light = Instance.new("PointLight")
    Light.Brightness = 8
    Light.Range = 60
    Light.Color = Color3.fromRGB(200, 225, 255)
    Light.Parent = Bolt:FindFirstChildWhichIsA("BasePart") or Bolt

    Context:Sound(Config.Sounds.Thunder, 0.8, Target, Context.Rand:NextNumber(0.9, 1.1))
    Context:SetVisuals({Flash = true})

    for _, Character in Context:Fighters() do
        local Root = Character:FindFirstChild("HumanoidRootPart")
        if not Root then
            continue
        end

        local Distance = (Root.Position - Target).Magnitude
        if Distance > STRIKE_RADIUS then
            continue
        end

        local Falloff = 1 - math.clamp(Distance / STRIKE_RADIUS, 0, 1)
        Context:Damage(Character, STRIKE_DAMAGE * (0.4 + Falloff * 0.6), "Lightning")
    end
end

return {
    Name = "Thunder Storm",
    Warning = "THUNDER STORM",
    Hint = "Stay off the high ground and out of the open.",
    Duration = 85,

    Buildup = function(Context)
        Context:SetVisuals({
            FogColor = Color3.fromRGB(48, 52, 62),
            FogEnd = 700,
            FogStart = 40,
            Brightness = 0.35,
            Tint = Color3.fromRGB(120, 140, 190),
            TintAlpha = 0.1,
            Rain = true,
        })
        Context:Sound(Config.Sounds.Wind, 0.4)
    end,

    Run = function(Context)
        while Context:Wait(Context.Rand:NextNumber(1.2, 2.6)) do
            Strike(Context)
        end
    end,

    Cleanup = function(Context)
        Context:ClearVisuals(5)
    end,
}
