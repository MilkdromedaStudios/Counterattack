--[=[
    TORNADO

    A cyclone crosses the arena on a wandering path, dragging everything near it into
    orbit and throwing it upwards.

    Ported from NDS's `tornado` / `updatetornado`. The orbital maths is the original's,
    because it is genuinely good — a target is pulled tangentially around the funnel with a
    slight inward bias, and lift scales with how high it already is, which is what makes it
    look like a funnel rather than a fan.

    What changed: the path is generated in ARENA space instead of the hardcoded
    `math.random(-85, 70)` box NDS used, and it only ever moves characters. NDS ran the
    same routine over every part in the map and deleted a random half of what it caught;
    doing that here would demolish the arena mid-fight.
]=]

local Config = require(script.Parent.Parent.Config)

local FUNNEL_HEIGHT = 260
--- Studs from the eye at which a target starts being dragged.
local PULL_RADIUS = 55
--- Inside this, the target is in the wall of the funnel and gets the full treatment.
local CORE_RADIUS = 14
local TRAVEL_TIME = 80
local ORBIT_SPEED = 95
local LIFT = 55
local CONTACT_DAMAGE = 6

--- Builds the visible funnel: a stack of spinning, translucent cones.
local function BuildFunnel(Context): (Model, {BasePart})
    local Funnel = Instance.new("Model")
    Funnel.Name = "Tornado"
    Funnel.Parent = Context.Effects
    Context:Track(Funnel)

    local Rings = {}
    local RingCount = 16

    for i = 1, RingCount do
        local Alpha = (i - 1) / (RingCount - 1)
        local Ring = Instance.new("Part")
        Ring.Anchored = true
        Ring.CanCollide = false
        Ring.CanQuery = false
        Ring.CanTouch = false
        Ring.CastShadow = false
        Ring.Shape = Enum.PartType.Cylinder
        Ring.Material = Enum.Material.SmoothPlastic
        Ring.Color = Color3.fromRGB(90, 88, 82)
        Ring.Transparency = 0.55 + Alpha * 0.25
        local Width = CORE_RADIUS * 2 * (0.45 + Alpha * 2.4)
        Ring.Size = Vector3.new(FUNNEL_HEIGHT / RingCount * 1.4, Width, Width)
        Ring.Parent = Funnel
        table.insert(Rings, Ring)
    end

    return Funnel, Rings
end

return {
    Name = "Tornado",
    Warning = "TORNADO",
    Hint = "Stay clear of its path — it will not stay in one place.",
    Duration = TRAVEL_TIME,

    Buildup = function(Context)
        Context:SetVisuals({
            FogColor = Color3.fromRGB(96, 92, 80),
            FogEnd = 850,
            FogStart = 50,
            Brightness = 0.5,
            Tint = Color3.fromRGB(150, 140, 110),
            TintAlpha = 0.1,
            --[[
                Grit in the air and at the edges of vision.

                This is the presentation the SANDSTORM used to own, and it belongs here
                instead: a funnel tearing across an arena throws up far more debris than
                a weather front does, and unlike the sandstorm the thing hurting you is
                still plainly visible in the middle of it. You can see the tornado through
                the dust, which is the difference between atmosphere and a blindfold.
            ]]
            Dust = true,
            Vignette = "Dust",
            Shake = 0.25,
        })
        Context:Sound(Config.Sounds.Wind, 0.5)
    end,

    Run = function(Context)
        local Funnel, Rings = BuildFunnel(Context)

        -- A wandering path across the arena rather than a straight line, so nowhere is
        -- reliably safe for the whole event.
        local Path = {}
        for _ = 1, 8 do
            table.insert(Path, Context:RandomPoint(0.85))
        end

        local Started = os.clock()
        local Spin = 0

        Context:Sound(Config.Sounds.TornadoRoar, 0.6, Funnel:FindFirstChildWhichIsA("BasePart"))

        while Context:Wait() do
            local Elapsed = os.clock() - Started
            local Progress = math.clamp(Elapsed / TRAVEL_TIME, 0, 1)

            -- Where along the path the eye is right now, interpolated between waypoints.
            local Scaled = Progress * (#Path - 1) + 1
            local Index = math.clamp(math.floor(Scaled), 1, #Path - 1)
            local Eye = Path[Index]:Lerp(Path[Index + 1], Scaled - Index)

            Spin += 0.35

            for i, Ring in Rings do
                local Alpha = (i - 1) / (#Rings - 1)
                local Wobble = CFrame.new(math.sin(Spin + i) * (2 + Alpha * 9), 0, math.cos(Spin + i * 0.7) * (2 + Alpha * 9))
                Ring.CFrame = CFrame.new(Eye + Vector3.new(0, Alpha * FUNNEL_HEIGHT, 0))
                    * Wobble
                    * CFrame.Angles(0, Spin * (0.4 + Alpha), math.pi * 0.5)
            end

            for _, Character in Context:Fighters() do
                local Root = Character:FindFirstChild("HumanoidRootPart")
                if not Root then
                    continue
                end

                local Flat = Vector3.new(Root.Position.X - Eye.X, 0, Root.Position.Z - Eye.Z)
                local Distance = Flat.Magnitude
                if Distance > PULL_RADIUS then
                    continue
                end

                --[[
                    Tangential velocity plus a small inward pull, exactly as the original.
                    `+ 0.35` on the angle is what turns "sucked straight in" into "dragged
                    around the outside", which is the difference between the funnel reading
                    as a vacuum and reading as a cyclone.
                ]]
                local Angle = math.atan2(Flat.X, Flat.Z) + 0.35
                local Orbit = Vector3.new(math.sin(Angle), 0, math.cos(Angle)) * math.max(Distance - 6, 0)
                local Goal = Eye + Orbit

                local Height = math.clamp((Root.Position.Y - Context.Region.GroundY) / FUNNEL_HEIGHT, 0, 1)
                local Strength = 1 - math.clamp((Distance - CORE_RADIUS) / (PULL_RADIUS - CORE_RADIUS), 0, 1)
                Strength = math.clamp(Strength + 0.1, 0, 1)

                local Direction = (Goal - Root.Position)
                if Direction.Magnitude > 0.01 then
                    Direction = Direction.Unit
                end

                Root.AssemblyLinearVelocity = Direction * ORBIT_SPEED * Strength * (1 + Height)
                    + Vector3.new(0, LIFT * Strength * (0.6 + Height), 0)

                local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
                if Humanoid and Distance < CORE_RADIUS * 2 then
                    -- Ragdoll-ish: they've lost their footing, they don't get to keep
                    -- fighting while airborne in the middle of a tornado.
                    Humanoid.PlatformStand = true
                    task.delay(2.5, function()
                        if Humanoid and Humanoid.Parent then
                            Humanoid.PlatformStand = false
                        end
                    end)
                end

                Context:Damage(Character, CONTACT_DAMAGE * Strength * 0.1, "Tornado")
            end

            if Config.DestroyMapParts then
                for _, Part in Context:LooseParts() do
                    local Flat = Vector3.new(Part.Position.X - Eye.X, 0, Part.Position.Z - Eye.Z)
                    if Flat.Magnitude > PULL_RADIUS then
                        continue
                    end

                    local Angle = math.atan2(Flat.X, Flat.Z) + 0.35
                    Part.AssemblyLinearVelocity = Vector3.new(math.sin(Angle), 0, math.cos(Angle)) * ORBIT_SPEED
                        + Vector3.new(0, LIFT, 0)
                end
            end

            if Progress >= 1 then
                break
            end
        end
    end,

    Cleanup = function(Context)
        Context:ClearVisuals(5)
    end,
}
