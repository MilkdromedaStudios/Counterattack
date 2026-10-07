--[=[
    TSUNAMI

    One enormous wave crosses the whole arena from one side to the other. There is
    nowhere to hide from it; the only answer is to be above it when it arrives.

    NDS's `tsunami` slid a pre-built wave model 2000 studs across the map on a fixed
    heading and used a Region3 sweep along its length to break whatever it passed through.
    The wave is built procedurally here — a curved wall of segments scaled to the arena —
    and the Region3 sweep is replaced by a flat "are you in front of the wall and below its
    crest" test, which is both cheaper and, unlike Region3, not capped at 100 results.
]=]

local Config = require(script.Parent.Parent.Config)

local CREST_DAMAGE = 60
local WAVE_TIME = 26
local SEGMENTS = 14

return {
    Name = "Tsunami",
    Warning = "TSUNAMI",
    Hint = "Climb. It crosses the whole arena.",
    Duration = WAVE_TIME + 14,

    Buildup = function(Context)
        Context:SetVisuals({
            FogColor = Color3.fromRGB(46, 74, 96),
            FogEnd = 1200,
            FogStart = 60,
            Brightness = 0.55,
            Tint = Color3.fromRGB(90, 160, 210),
            TintAlpha = 0.1,
            Rain = true,
            Vignette = "Water",
        })
        Context:Sound(Config.Sounds.Wind, 0.6)
    end,

    Run = function(Context)
        local Heading = Context.Rand:NextNumber() * math.pi * 2
        local Direction = Vector3.new(math.cos(Heading), 0, math.sin(Heading))

        local Travel = Context.Region.Radius * 2 + 200
        local Crest = math.clamp((Context.Region.TopY - Context.Region.GroundY) * 0.55, 30, 110)
        local Width = Context.Region.Radius * 2.4
        local Thickness = 26

        local Wave = Instance.new("Model")
        Wave.Name = "Tsunami"
        Wave.Parent = Context.Effects
        Context:Track(Wave)

        -- The wall is a row of segments with a sine profile, so the wave has a curl to it
        -- rather than being a flat slab. Purely cosmetic; the hit test uses the plane.
        local Parts = {}
        for i = 1, SEGMENTS do
            local Alpha = (i - 0.5) / SEGMENTS
            local Height = Crest * (0.55 + 0.45 * math.sin(Alpha * math.pi))

            local Segment = Instance.new("Part")
            Segment.Anchored = true
            Segment.CanCollide = false
            Segment.CanQuery = false
            Segment.CanTouch = false
            Segment.Material = Enum.Material.Glass
            Segment.Color = Color3.fromRGB(38, 84, 116)
            Segment.Transparency = 0.28
            Segment.Size = Vector3.new(Width / SEGMENTS, Height, Thickness)
            Segment.Parent = Wave
            Parts[i] = {Part = Segment, Alpha = Alpha, Height = Height}
        end

        local Foam = Instance.new("ParticleEmitter")
        Foam.Rate = 120
        Foam.Lifetime = NumberRange.new(0.6, 1.6)
        Foam.Speed = NumberRange.new(4, 14)
        Foam.SpreadAngle = Vector2.new(50, 50)
        Foam.Color = ColorSequence.new(Color3.fromRGB(235, 245, 250))
        Foam.Size = NumberSequence.new(6, 0)
        Foam.Transparency = NumberSequence.new(0.3, 1)
        Foam.Parent = Parts[math.ceil(SEGMENTS / 2)].Part

        Context:Sound(Config.Sounds.Wind, 0.9)

        local Started = os.clock()
        local Perp = Vector3.new(-Direction.Z, 0, Direction.X)

        while Context:Wait() do
            local Alpha = (os.clock() - Started) / WAVE_TIME
            if Alpha >= 1 then
                break
            end

            local Distance = -Travel * 0.5 + Travel * Alpha
            local Center = Context.Region.Center + Direction * Distance

            for i, Record in Parts do
                local Offset = (Record.Alpha - 0.5) * Width
                Record.Part.CFrame = CFrame.lookAt(
                    Center + Perp * Offset + Vector3.new(0, Record.Height * 0.5 - 4, 0),
                    Center + Perp * Offset + Direction + Vector3.new(0, Record.Height * 0.5 - 4, 0)
                ) * CFrame.Angles(math.rad(-12 - i % 3 * 3), 0, 0)
            end

            local CrestY = Context.Region.GroundY + Crest

            for _, Character in Context:Fighters() do
                local Root = Character:FindFirstChild("HumanoidRootPart")
                if not Root then
                    continue
                end

                --[[
                    Signed distance along the heading. Anyone from the face of the wave to
                    one thickness behind it is inside it; anyone above the crest is clear,
                    which is what makes "get high" a real answer and not just a delay.
                ]]
                local Along = ((Root :: BasePart).Position - Center):Dot(Direction)
                if Along > 0 or Along < -Thickness * 1.5 then
                    continue
                end
                if (Root :: BasePart).Position.Y > CrestY then
                    continue
                end

                Context:Damage(Character, CREST_DAMAGE * 0.12, "Tsunami")
                Context:Shove(Character, Direction * 55 + Vector3.new(0, 22, 0))
            end
        end
    end,

    Cleanup = function(Context)
        Context:ClearVisuals(5)
    end,
}
