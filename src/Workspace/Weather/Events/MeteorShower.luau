--[=[
    METEOR SHOWER

    Rocks fall out of the sky and detonate on whatever they hit.

    Ported from NDS's `meteorstorm`, with one structural change: the meteors are ANCHORED
    and flown by hand instead of being unanchored parts thrown at the ground.

    NDS could afford real physics — its meteors were supposed to punch the map apart, and
    the map was disposable. Here they are landing on an arena people are fighting in, and
    unanchored server parts hand their simulation to whichever client happens to own them.
    That means the meteor a player sees is not the meteor the server is testing for hits,
    which in a fighting game is the difference between a fair hazard and a lottery.
    Raycasting a hand-flown position is exact on the server and identical for everybody.
]=]

local Config = require(script.Parent.Parent.Config)

local METEOR_SIZES = {4, 6, 9, 12, 16}
local FALL_SPEED = 190
local IMPACT_RADIUS = 18
local IMPACT_DAMAGE = 55
--- Seconds between spawns. Scales with arena size so a big map isn't sparsely peppered.
local BASE_SPAWN_INTERVAL = 0.55

local function Impact(Context, Position: Vector3, Size: number)
    Context:Sound(Config.Sounds.Explosion, 0.7, Position, Context.Rand:NextNumber(0.8, 1.1))

    local Flash = Context:Part({
        Name = "MeteorImpact",
        Shape = Enum.PartType.Ball,
        Size = Vector3.one * Size,
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(255, 180, 80),
        Position = Position,
    }, 1.2)

    task.spawn(function()
        for i = 1, 12 do
            if not Flash.Parent then
                return
            end
            local Alpha = i / 12
            Flash.Size = Vector3.one * (Size + Alpha * IMPACT_RADIUS * 2)
            Flash.Transparency = Alpha
            task.wait()
        end
    end)

    --[[
        A real `Explosion` is still used, but declawed: zero blast pressure, zero joint
        destruction. It's there for the shape of the thing and for anything in the map that
        listens for one — the damage below is what actually decides the outcome, so the
        arena is not quietly disassembled by a hazard that is supposed to hurt PEOPLE.
    ]]
    local Blast = Instance.new("Explosion")
    Blast.Position = Position
    Blast.BlastRadius = Config.DestroyMapParts and IMPACT_RADIUS or 0
    Blast.BlastPressure = Config.DestroyMapParts and 250000 or 0
    Blast.DestroyJointRadiusPercent = Config.DestroyMapParts and 0.5 or 0
    Blast.ExplosionType = Enum.ExplosionType.NoCraters
    Blast.Parent = Context.Effects

    for _, Character in Context:Fighters() do
        local Root = Character:FindFirstChild("HumanoidRootPart")
        if not Root then
            continue
        end

        local Distance = (Root.Position - Position).Magnitude
        if Distance > IMPACT_RADIUS + Size then
            continue
        end

        local Falloff = 1 - math.clamp(Distance / (IMPACT_RADIUS + Size), 0, 1)
        Context:Damage(Character, IMPACT_DAMAGE * Falloff, "Meteor")
        Context:Shove(Character, (Root.Position - Position).Unit * 45 * Falloff + Vector3.new(0, 25 * Falloff, 0))
    end
end

local function SpawnMeteor(Context)
    local Size = METEOR_SIZES[Context.Rand:NextInteger(1, #METEOR_SIZES)]

    local Target = Context:RandomPoint(0.9)
    local Start = Vector3.new(
        Target.X + Context.Rand:NextNumber(-60, 60),
        Context.Region.SkyY,
        Target.Z + Context.Rand:NextNumber(-60, 60)
    )

    local Meteor = Context:Part({
        Name = "Meteor",
        Shape = Enum.PartType.Ball,
        Size = Vector3.one * Size,
        Material = Enum.Material.Slate,
        Color = Color3.fromRGB(60, 40, 34),
        Position = Start,
    }, 20)

    local Fire = Instance.new("ParticleEmitter")
    Fire.Texture = "rbxassetid://242201991"
    Fire.Rate = 45
    Fire.Lifetime = NumberRange.new(0.35, 0.8)
    Fire.Speed = NumberRange.new(2, 6)
    Fire.SpreadAngle = Vector2.new(25, 25)
    Fire.LightEmission = 1
    Fire.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(150, 40, 0))
    Fire.Size = NumberSequence.new(Size * 0.8, 0)
    Fire.Parent = Meteor

    local Light = Instance.new("PointLight")
    Light.Brightness = 3
    Light.Range = Size * 4
    Light.Color = Color3.fromRGB(255, 150, 60)
    Light.Parent = Meteor

    Context:Sound(Config.Sounds.Whoosh, 0.35, Meteor, Context.Rand:NextNumber(0.85, 1.15))

    -- Aim the meteor at the ground under its target rather than at the target's own Y, so
    -- a map with a tall tower still gets hit on the roof and not through it.
    local Landing = Context:GroundAt(Target)
    local Direction = (Landing - Start).Unit

    task.spawn(function()
        local Position = Start
        local Alive = true

        while Alive and Context.Running and Meteor.Parent do
            local Delta = task.wait()
            local Step = FALL_SPEED * Delta

            local Hit = Context:Raycast(Position, Direction, Step + Size * 0.5)
            if Hit then
                Position = Hit.Position
                Alive = false
            else
                Position += Direction * Step
            end

            Meteor.Position = Position

            -- Nothing to hit on the way down (an empty stretch of arena) — stop at the
            -- floor height rather than falling forever into the void.
            if Position.Y <= Context.Region.GroundY - 50 then
                Alive = false
            end
        end

        if not Meteor.Parent then
            return
        end

        Impact(Context, Position, Size)
        Meteor:Destroy()
    end)
end

return {
    Name = "Meteor Shower",
    Warning = "METEOR SHOWER",
    Hint = "Watch the skies and keep something solid over your head.",
    Duration = 80,

    Buildup = function(Context)
        Context:SetVisuals({
            FogColor = Color3.fromRGB(70, 40, 35),
            FogEnd = 900,
            FogStart = 60,
            Brightness = 0.6,
            Tint = Color3.fromRGB(255, 140, 90),
            TintAlpha = 0.12,
            --- Burning fragments drifting down ahead of the rocks that matter.
            Embers = true,
            Vignette = "Ember",
        })
    end,

    Run = function(Context)
        -- One extra meteor in flight for every 150 studs of arena, so a big map gets the
        -- same density of falling rock as a small one rather than the same COUNT.
        local Density = math.max(1, math.floor(Context.Region.Radius / 150))
        local Interval = BASE_SPAWN_INTERVAL / Density

        while Context:Wait(Interval) do
            SpawnMeteor(Context)
        end
    end,

    Cleanup = function(Context)
        Context:ClearVisuals(4)
    end,
}
