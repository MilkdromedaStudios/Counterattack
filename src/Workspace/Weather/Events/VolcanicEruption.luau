--[=[
    VOLCANIC ERUPTION

    A cone pushes up out of the edge of the arena and starts throwing lava over it.

    NDS built its volcano out of ~200 procedurally placed `dirtpart` fragments — a cone of
    overlapping slabs — and then flung unanchored lava boulders from the crater. The cone
    is rebuilt the same way here, scaled to the arena and placed on its EDGE rather than at
    a fixed radius of 300 from the origin, so it never lands in the middle of the fight or
    a thousand studs out in the void.

    The lava bombs are flown by hand for the same reason the meteors are: server-authored
    arcs hit where the client saw them, and unanchored boulders don't get to shove players
    around according to whoever happens to own the physics.
]=]

local Config = require(script.Parent.Parent.Config)

local FRAGMENT_RINGS = 4
local LAVA_COLORS = {
    Color3.fromRGB(196, 40, 28),
    Color3.fromRGB(218, 133, 66),
    Color3.fromRGB(245, 205, 48),
}
local BOMB_DAMAGE = 45
local BOMB_RADIUS = 14
local POOL_DAMAGE = 22

--- Places the cone. Returns the crater position the bombs come out of.
local function BuildVolcano(Context): Vector3
    local Angle = Context.Rand:NextNumber() * math.pi * 2
    local Base = Context:GroundAt(Vector3.new(
        Context.Region.Center.X + math.cos(Angle) * Context.Region.Radius * 0.9,
        0,
        Context.Region.Center.Z + math.sin(Angle) * Context.Region.Radius * 0.9
    ))

    local Height = math.clamp(Context.Region.Radius * 0.35, 45, 130)
    local BaseRadius = math.clamp(Context.Region.Radius * 0.5, 60, 200)
    local CrownRadius = BaseRadius * 0.16

    local Volcano = Instance.new("Model")
    Volcano.Name = "Volcano"
    Volcano.Parent = Context.Effects
    Context:Track(Volcano)

    local function Fragment(Distance: number, Rotation: number)
        local Inverse = 1 - Distance
        local Size = Vector3.new(
            (BaseRadius / math.pi) * (0.5 + Distance * 0.5),
            Height * 0.142 * (0.5 + Context.Rand:NextNumber() * 0.5),
            (BaseRadius - CrownRadius) * (0.3 + Context.Rand:NextNumber() * 0.2)
        )

        local Part = Instance.new("Part")
        Part.Anchored = true
        Part.CanCollide = true
        Part.CanQuery = true
        Part.Material = Enum.Material.Slate
        Part.Color = Color3.fromRGB(86, 66, 54)
        Part.Size = Size
        Part.CFrame = CFrame.new(Base - Vector3.new(0, Size.Y * 0.5, 0))
            * CFrame.Angles(0, Rotation, 0)
            * CFrame.new(0, Height * (Inverse ^ 1.5), CrownRadius + Size.Z * 0.25 + Distance * (BaseRadius - Size.Z - CrownRadius))
            * CFrame.Angles(Inverse * math.pi * 0.25, 0, (Inverse + 0.1) * 0.2 * (Context.Rand:NextNumber() - 0.5))
        Part.Parent = Volcano
    end

    for ring = 1, FRAGMENT_RINGS do
        local Count = 10 + ring * 10
        for i = 1, Count do
            Fragment((ring - 1) / (FRAGMENT_RINGS - 1), (i / Count) * math.pi * 2)
        end
    end
    for _ = 1, 110 do
        Fragment(Context.Rand:NextNumber(), Context.Rand:NextNumber() * math.pi * 2)
    end

    -- The glowing crater cap.
    local Crater = Instance.new("Part")
    Crater.Anchored = true
    Crater.CanCollide = false
    Crater.CanQuery = false
    Crater.Shape = Enum.PartType.Cylinder
    Crater.Material = Enum.Material.Neon
    Crater.Color = Color3.fromRGB(255, 130, 40)
    Crater.Size = Vector3.new(2, CrownRadius * 2, CrownRadius * 2)
    Crater.CFrame = CFrame.new(Base + Vector3.new(0, Height * 0.92, 0)) * CFrame.Angles(0, 0, math.pi * 0.5)
    Crater.Parent = Volcano

    return Base + Vector3.new(0, Height, 0)
end

--- Throws one lava bomb from the crater onto the arena and burns where it lands.
local function ThrowBomb(Context, Crater: Vector3)
    local Target = Context:GroundAt(Context:RandomPoint(0.95))

    local Size = Context.Rand:NextNumber(5, 11)
    local Bomb = Context:Part({
        Name = "LavaBomb",
        Shape = Enum.PartType.Ball,
        Size = Vector3.one * Size,
        Material = Enum.Material.Neon,
        Color = LAVA_COLORS[Context.Rand:NextInteger(1, #LAVA_COLORS)],
        Position = Crater,
    }, 25)

    local Trail = Instance.new("ParticleEmitter")
    Trail.Texture = "rbxassetid://242201991"
    Trail.Rate = 30
    Trail.Lifetime = NumberRange.new(0.4, 0.9)
    Trail.Speed = NumberRange.new(1, 3)
    Trail.LightEmission = 1
    Trail.Color = ColorSequence.new(Color3.fromRGB(255, 180, 70), Color3.fromRGB(160, 30, 0))
    Trail.Size = NumberSequence.new(Size * 0.7, 0)
    Trail.Parent = Bomb

    task.spawn(function()
        --[[
            A fixed-duration parabola between two known points.

            Solving for the arc rather than integrating gravity means the bomb ALWAYS
            lands where the shadow says it will, however long the flight takes. A simulated
            projectile drifts, and a hazard that misses its own telegraph is worse than no
            telegraph at all.
        ]]
        local Flight = 2.2
        local Peak = math.max(60, (Crater - Target).Magnitude * 0.25)
        local Started = os.clock()

        -- Landing marker so it can be dodged.
        local Marker = Context:Part({
            Name = "LavaShadow",
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(0.4, BOMB_RADIUS * 2, BOMB_RADIUS * 2),
            Material = Enum.Material.Neon,
            Color = Color3.fromRGB(255, 90, 30),
            Transparency = 0.6,
            CFrame = CFrame.new(Target + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi * 0.5),
        }, Flight + 0.5)

        while Context.Running and Bomb.Parent do
            local Alpha = (os.clock() - Started) / Flight
            if Alpha >= 1 then
                break
            end

            local Flat = Crater:Lerp(Target, Alpha)
            Bomb.Position = Flat + Vector3.new(0, math.sin(Alpha * math.pi) * Peak, 0)
            task.wait()
        end

        if Marker.Parent then
            Marker:Destroy()
        end

        if not Context.Running or not Bomb.Parent then
            return
        end

        Bomb:Destroy()
        Context:Sound(Config.Sounds.Explosion, 0.5, Target, Context.Rand:NextNumber(0.6, 0.85))

        for _, Character in Context:Fighters() do
            local Root = Character:FindFirstChild("HumanoidRootPart")
            if not Root then
                continue
            end
            local Distance = ((Root :: BasePart).Position - Target).Magnitude
            if Distance <= BOMB_RADIUS then
                Context:Damage(Character, BOMB_DAMAGE * (1 - Distance / BOMB_RADIUS), "Lava")
            end
        end

        -- The cooling pool it leaves behind, which keeps burning for a while.
        local Pool = Context:Part({
            Name = "LavaPool",
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(0.8, BOMB_RADIUS * 1.6, BOMB_RADIUS * 1.6),
            Material = Enum.Material.Neon,
            Color = Color3.fromRGB(255, 110, 30),
            CFrame = CFrame.new(Target + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi * 0.5),
        }, 16)

        task.spawn(function()
            local Cooling = os.clock()
            while Context.Running and Pool.Parent and os.clock() - Cooling < 14 do
                local Alpha = (os.clock() - Cooling) / 14
                Pool.Color = Color3.fromRGB(255, 110, 30):Lerp(Color3.fromRGB(30, 22, 20), Alpha)

                for _, Character in Context:Fighters() do
                    local Root = Character:FindFirstChild("HumanoidRootPart")
                    if not Root then
                        continue
                    end
                    local Flat = Vector3.new(
                        (Root :: BasePart).Position.X - Target.X,
                        0,
                        (Root :: BasePart).Position.Z - Target.Z
                    )
                    if Flat.Magnitude <= BOMB_RADIUS * 0.8 and math.abs((Root :: BasePart).Position.Y - Target.Y) < 10 then
                        Context:Damage(Character, POOL_DAMAGE * 0.3 * (1 - Alpha), "Lava")
                    end
                end

                task.wait(0.3)
            end
        end)
    end)
end

return {
    Name = "Volcanic Eruption",
    Warning = "VOLCANIC ERUPTION",
    Hint = "Keep moving. Watch for the shadow before the lava lands.",
    Duration = 85,

    Buildup = function(Context)
        Context:SetVisuals({
            FogColor = Color3.fromRGB(70, 38, 30),
            FogEnd = 900,
            FogStart = 50,
            Brightness = 0.55,
            Tint = Color3.fromRGB(255, 120, 50),
            TintAlpha = 0.13,
            Embers = true,
            Vignette = "Ash",
            Shake = 0.4,
        })
    end,

    Run = function(Context)
        local Crater = BuildVolcano(Context)

        Context:Sound(Config.Sounds.Rumble, 0.8, Crater, 0.6)
        Context:SetVisuals({
            FogColor = Color3.fromRGB(70, 38, 30),
            FogEnd = 700,
            FogStart = 40,
            Brightness = 0.4,
            Tint = Color3.fromRGB(255, 110, 45),
            TintAlpha = 0.18,
            Embers = true,
            Vignette = "Ash",
            Shake = 0.7,
        })

        while Context:Wait(Context.Rand:NextNumber(0.5, 1.4)) do
            for _ = 1, Context.Rand:NextInteger(1, 2) do
                ThrowBomb(Context, Crater)
            end
        end
    end,

    Cleanup = function(Context)
        Context:ClearVisuals(6)
    end,
}
