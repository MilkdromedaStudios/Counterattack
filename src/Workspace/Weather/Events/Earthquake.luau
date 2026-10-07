--[=[
    EARTHQUAKE

    The ground shakes, and fissures open across the arena.

    NDS's `earthquake` picked half the parts in its `Island` model every tick, gave them a
    random velocity and broke their joints. That is the correct implementation for a game
    whose point is watching a map fall over, and the wrong one for a fighting arena — the
    floor going out from under a duel isn't a hazard, it's the end of the match.

    So the shake is here as a client-side camera effect (nobody's aim gets stolen by the
    server), and the actual hazard is FISSURES: cracks that open in the floor at telegraphed
    positions, sit there for a few seconds, and hurt anyone standing over them when they
    do. That keeps the event's identity — the ground is against you — while leaving the
    arena intact.

    With `Config.DestroyMapParts` on, the original's part-flinging comes back too.
]=]

local Config = require(script.Parent.Parent.Config)

local FISSURE_INTERVAL = 2.2
local FISSURE_TELEGRAPH = 1.6
local FISSURE_LENGTH = 70
local FISSURE_WIDTH = 9
local FISSURE_DAMAGE = 38
local FISSURE_LIFETIME = 6

--[=[
    Opens one fissure.

    It is drawn as a warning strip first and only becomes lethal after `FISSURE_TELEGRAPH`
    seconds. Unavoidable damage from a hazard with no tell is the fastest way to make an
    event feel unfair, and this one covers a lot of ground.
]=]
local function OpenFissure(Context)
    local Origin = Context:GroundAt(Context:RandomPoint(0.85))
    local Angle = Context.Rand:NextNumber() * math.pi * 2

    local Warning = Context:Part({
        Name = "FissureWarning",
        Size = Vector3.new(FISSURE_WIDTH, 0.2, FISSURE_LENGTH),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(255, 90, 40),
        Transparency = 0.6,
        CFrame = CFrame.new(Origin + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, Angle, 0),
    }, FISSURE_TELEGRAPH + FISSURE_LIFETIME + 1)

    task.spawn(function()
        local Started = os.clock()
        while Context.Running and Warning.Parent and os.clock() - Started < FISSURE_TELEGRAPH do
            Warning.Transparency = 0.75 - math.abs(math.sin((os.clock() - Started) * 8)) * 0.45
            task.wait()
        end

        if not Context.Running or not Warning.Parent then
            return
        end

        Warning.Color = Color3.fromRGB(20, 12, 10)
        Warning.Material = Enum.Material.Slate
        Warning.Transparency = 0
        Warning.Size = Vector3.new(FISSURE_WIDTH, 3, FISSURE_LENGTH)
        Warning.CFrame = CFrame.new(Origin - Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, Angle, 0)

        local Glow = Instance.new("PointLight")
        Glow.Brightness = 2
        Glow.Range = 24
        Glow.Color = Color3.fromRGB(255, 90, 30)
        Glow.Parent = Warning

        Context:Sound(Config.Sounds.Rumble, 0.55, Origin, Context.Rand:NextNumber(0.7, 0.95))

        -- Anyone standing over the crack when it opens falls in.
        local Opened = os.clock()
        while Context.Running and Warning.Parent and os.clock() - Opened < FISSURE_LIFETIME do
            for _, Character in Context:Fighters() do
                local Root = Character:FindFirstChild("HumanoidRootPart")
                if not Root then
                    continue
                end

                local Local = Warning.CFrame:PointToObjectSpace((Root :: BasePart).Position)
                if math.abs(Local.X) <= FISSURE_WIDTH * 0.5
                    and math.abs(Local.Z) <= FISSURE_LENGTH * 0.5
                    and math.abs(Local.Y) <= 8
                then
                    Context:Damage(Character, FISSURE_DAMAGE * 0.2, "Earthquake")
                    Context:Shove(Character, Vector3.new(0, -18, 0))
                end
            end
            task.wait(0.2)
        end
    end)
end

return {
    Name = "Earthquake",
    Warning = "EARTHQUAKE",
    Hint = "The ground is opening up. Watch what's under your feet.",
    Duration = 70,

    Buildup = function(Context)
        Context:SetVisuals({
            FogColor = Color3.fromRGB(80, 70, 62),
            FogEnd = 1100,
            FogStart = 60,
            Brightness = 0.7,
            Shake = 0.35,
        })
        Context:Sound(Config.Sounds.Rumble, 0.5)
    end,

    Run = function(Context)
        Context:SetVisuals({
            FogColor = Color3.fromRGB(80, 70, 62),
            FogEnd = 1100,
            FogStart = 60,
            Brightness = 0.7,
            Shake = 1,
            Dust = true,
        })

        local NextFissure = 0

        while Context:Wait(0.3) do
            if os.clock() >= NextFissure then
                NextFissure = os.clock() + FISSURE_INTERVAL
                OpenFissure(Context)
            end

            if Config.DestroyMapParts then
                local Shake = Vector3.new(
                    Context.Rand:NextNumber(-1, 1),
                    Context.Rand:NextNumber(0, 0.5),
                    Context.Rand:NextNumber(-1, 1)
                ) * 18

                for _, Part in Context:LooseParts() do
                    if Context.Rand:NextNumber() > 0.25 then
                        continue
                    end
                    Part.AssemblyLinearVelocity += Shake
                end
            end
        end
    end,

    Cleanup = function(Context)
        Context:ClearVisuals(4)
    end,
}
