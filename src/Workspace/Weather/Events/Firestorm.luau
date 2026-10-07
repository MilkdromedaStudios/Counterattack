--[=[
    FIRESTORM

    Patches of fire take hold across the arena and spread outward from where they started.

    NDS's `fire` disaster required maps to be authored with `FireStarter` parts, walked the
    whole model tree once a second incrementing a `FireTag` on every burning part, and
    spread by Region3 to neighbours. No map in THIS game has `FireStarter` parts, so that
    version of the event would do precisely nothing here — which is exactly the class of
    silent no-op this port is meant to avoid.

    Instead the fire seeds itself: a handful of blazes start at random points on the arena
    floor, each grows over its lifetime, and each periodically throws a child blaze a short
    distance away. The result is the same shape of hazard — a growing, moving no-go area
    that eventually covers a meaningful part of the map — with no authoring requirement.
]=]

local Config = require(script.Parent.Parent.Config)

local SEED_COUNT = 5
local SEED_INTERVAL = 7
local BURN_RADIUS_START = 9
local BURN_RADIUS_END = 22
local BURN_LIFETIME = 34
local BURN_DAMAGE = 18
local SPREAD_CHANCE = 0.4
local SPREAD_DISTANCE = 26
local MAX_BLAZES = 26

--- Live fires for the current run. Reset by `Buildup`; a module-level table is safe here
--- because the runner never starts the same event twice at once.
local Blazes = {}

--- Lights one fire at a point on the floor and lets it live out its lifetime.
local function Ignite(Context, Position: Vector3, Generation: number)
    if #Blazes >= MAX_BLAZES then
        return
    end

    local Ground = Context:GroundAt(Position)

    local Blaze = Context:Part({
        Name = "Blaze",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(1, BURN_RADIUS_START * 2, BURN_RADIUS_START * 2),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(255, 120, 40),
        Transparency = 0.55,
        CFrame = CFrame.new(Ground + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi * 0.5),
    })

    local Emitter = Instance.new("ParticleEmitter")
    Emitter.Texture = "rbxassetid://242201991"
    Emitter.Rate = 60
    Emitter.Lifetime = NumberRange.new(0.6, 1.4)
    Emitter.Speed = NumberRange.new(6, 14)
    Emitter.SpreadAngle = Vector2.new(40, 40)
    Emitter.LightEmission = 1
    Emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(180, 40, 0))
    Emitter.Size = NumberSequence.new(6, 0)
    Emitter.EmissionDirection = Enum.NormalId.Right
    Emitter.Parent = Blaze

    local Light = Instance.new("PointLight")
    Light.Brightness = 4
    Light.Range = 40
    Light.Color = Color3.fromRGB(255, 140, 50)
    Light.Parent = Blaze

    local Record = {Part = Blaze, Position = Ground, Radius = BURN_RADIUS_START}
    table.insert(Blazes, Record)

    task.spawn(function()
        local Started = os.clock()
        local NextSpread = Started + Context.Rand:NextNumber(4, 9)

        while Context.Running and Blaze.Parent do
            local Elapsed = os.clock() - Started
            if Elapsed >= BURN_LIFETIME then
                break
            end

            local Alpha = Elapsed / BURN_LIFETIME
            Record.Radius = BURN_RADIUS_START + (BURN_RADIUS_END - BURN_RADIUS_START) * math.sin(Alpha * math.pi)
            Blaze.Size = Vector3.new(1, Record.Radius * 2, Record.Radius * 2)
            Emitter.Size = NumberSequence.new(Record.Radius * 0.5, 0)

            --[[
                Fires stop reproducing after a few generations.

                Without a generation cap this is exponential: every blaze spawns blazes
                that spawn blazes, and within a minute the entire arena is on fire and
                nobody can move anywhere. Three generations covers a good chunk of the map
                and still leaves somewhere to stand.
            ]]
            if Generation < 3 and os.clock() >= NextSpread then
                NextSpread = os.clock() + Context.Rand:NextNumber(5, 11)
                if Context.Rand:NextNumber() < SPREAD_CHANCE then
                    local Angle = Context.Rand:NextNumber() * math.pi * 2
                    local Offset = Vector3.new(math.cos(Angle), 0, math.sin(Angle)) * SPREAD_DISTANCE
                    Ignite(Context, Ground + Offset, Generation + 1)
                end
            end

            task.wait(0.2)
        end

        local Index = table.find(Blazes, Record)
        if Index then
            table.remove(Blazes, Index)
        end
        if Blaze.Parent then
            Blaze:Destroy()
        end
    end)
end

return {
    Name = "Firestorm",
    Warning = "FIRESTORM",
    Hint = "The fire spreads. Don't let it corner you.",
    Duration = 85,

    Buildup = function(Context)
        Blazes = {}
        Context:SetVisuals({
            FogColor = Color3.fromRGB(90, 45, 25),
            FogEnd = 800,
            FogStart = 40,
            Brightness = 0.6,
            Tint = Color3.fromRGB(255, 130, 60),
            TintAlpha = 0.14,
            Embers = true,
        })
    end,

    Run = function(Context)
        Context:Sound(Config.Sounds.Fire, 0.6)

        for _ = 1, SEED_COUNT do
            Ignite(Context, Context:RandomPoint(0.8), 1)
        end

        local NextSeed = os.clock() + SEED_INTERVAL

        while Context:Wait(0.25) do
            if os.clock() >= NextSeed then
                NextSeed = os.clock() + SEED_INTERVAL
                Ignite(Context, Context:RandomPoint(0.85), 1)
            end

            for _, Character in Context:Fighters() do
                local Root = Character:FindFirstChild("HumanoidRootPart")
                if not Root then
                    continue
                end

                for _, Record in Blazes do
                    local Flat = Vector3.new(
                        (Root :: BasePart).Position.X - Record.Position.X,
                        0,
                        (Root :: BasePart).Position.Z - Record.Position.Z
                    )

                    -- Only burns people actually standing in it, not people on a walkway
                    -- twenty studs above it.
                    if Flat.Magnitude <= Record.Radius and math.abs((Root :: BasePart).Position.Y - Record.Position.Y) < 12 then
                        Context:Damage(Character, BURN_DAMAGE * 0.25, "Fire")
                        break
                    end
                end
            end
        end
    end,

    Cleanup = function(Context)
        Blazes = {}
        Context:ClearVisuals(5)
    end,
}
