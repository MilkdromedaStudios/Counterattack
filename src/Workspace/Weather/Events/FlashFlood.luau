--[=[
    FLASH FLOOD

    The water rises. Whatever is lowest on the map goes first.

    NDS's `flooding` raised a giant plane from a hardcoded Y of 15 up to a hardcoded Y of
    70 and drowned anybody whose head was under it. The mechanic is exactly right and it is
    kept; the hardcoded heights are not, because on a map whose floor sits at Y = 200 that
    version raises water somewhere far below everyone's feet and the event does nothing at
    all.

    Here the water starts just under the arena's own floor and rises to a fraction of the
    arena's HEIGHT, so it always ends up somewhere between "ankle deep" and "only the
    rooftops are left" whatever the map is.
]=]

local Config = require(script.Parent.Parent.Config)

local DROWN_DAMAGE = 14
local RISE_TIME = 55
--- Fraction of the arena's vertical extent the water climbs to. Deliberately not 1: an
--- arena completely underwater has no high ground to run to, which is the entire point.
local FLOOD_FRACTION = 0.55
local MIN_RISE = 25

return {
    Name = "Flash Flood",
    Warning = "FLASH FLOOD",
    Hint = "Get high, and stay there.",
    Duration = 85,

    Buildup = function(Context)
        Context:SetVisuals({
            FogColor = Color3.fromRGB(52, 70, 88),
            FogEnd = 800,
            FogStart = 40,
            Brightness = 0.5,
            Tint = Color3.fromRGB(90, 150, 200),
            TintAlpha = 0.1,
            Rain = true,
            Vignette = "Water",
        })
        Context:Sound(Config.Sounds.Rain, 0.5)
    end,

    Run = function(Context)
        local Height = math.max(Context.Region.TopY - Context.Region.GroundY, MIN_RISE / FLOOD_FRACTION)
        local StartY = Context.Region.GroundY - 4
        local PeakY = Context.Region.GroundY + math.max(Height * FLOOD_FRACTION, MIN_RISE)

        local Width = Context.Region.Radius * 2.5

        local Water = Context:Part({
            Name = "FloodWater",
            Size = Vector3.new(Width, 4, Width),
            Material = Enum.Material.Glass,
            Color = Color3.fromRGB(46, 92, 120),
            Transparency = 0.45,
            Position = Vector3.new(Context.Region.Center.X, StartY, Context.Region.Center.Z),
        })

        Context:Sound(Config.Sounds.Wind, 0.5)

        local Started = os.clock()

        while Context:Wait(0.1) do
            local Elapsed = os.clock() - Started
            local Alpha = math.clamp(Elapsed / RISE_TIME, 0, 1)

            -- A slow swell on top of the rise, so the surface is never quite still and a
            -- player sitting exactly on the waterline is not safe forever.
            local Swell = math.sin(Elapsed * 0.6) * 2.5
            local Level = StartY + (PeakY - StartY) * Alpha + Swell

            --[[
                The slab is grown downwards from the surface rather than kept a fixed
                height, so it fills the arena instead of floating as a sheet with a visible
                gap under it. `Size.Y` is the distance from the surface to well below the
                floor; the centre sits half that below the surface.
            ]]
            local Depth = math.max(Level - (Context.Region.GroundY - 60), 8)
            Water.Size = Vector3.new(Width, Depth, Width)
            Water.Position = Vector3.new(Context.Region.Center.X, Level - Depth * 0.5, Context.Region.Center.Z)

            for _, Character in Context:Fighters() do
                local Head = Character:FindFirstChild("Head")
                if not Head or not Head:IsA("BasePart") then
                    continue
                end

                if Head.Position.Y < Level then
                    Context:Damage(Character, DROWN_DAMAGE * 0.1, "Flood")
                end
            end
        end
    end,

    Cleanup = function(Context)
        Context:ClearVisuals(5)
    end,
}
