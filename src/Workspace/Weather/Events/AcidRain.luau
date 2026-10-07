--[=[
    ACID RAIN

    Rain that burns. Being under cover is the whole defence.

    NDS's `makerainray` cast a ray per droplet, dealt 5 damage if it found a player, and
    then progressively recoloured whatever it struck through a green-to-black chain until
    the part fell apart. The corrosion chain is kept behind `Config.DestroyMapParts` — it
    is lovely and it is also a slow way to dissolve an arena — but the ray-per-droplet
    damage model is intact, because it is what makes a roof mean something.

    Unlike the blizzard, this is a fast light tick rather than a slow heavy one: acid rain
    should feel like pressure to move somewhere, not like a death sentence for being
    caught out for a second.
]=]

local Config = require(script.Parent.Parent.Config)

--[[
    Roughly forty-five droplets a second across the whole arena.

    NDS ran a hundred and twenty, but nothing else was happening in that game — here the
    same thread budget is shared with an active fight, and every droplet is a raycast plus
    a part plus a fade task. Forty-five still reads as heavy rain and leaves the frame
    budget to the thing players are actually doing.
]]
local TICK = 1 / 15
local DROPS_PER_TICK = 3
local DROP_DAMAGE = 5

local CORROSION = {
    [Color3.fromRGB(163, 162, 165)] = Color3.fromRGB(58, 125, 21),
    [Color3.fromRGB(58, 125, 21)] = Color3.fromRGB(120, 144, 130),
    [Color3.fromRGB(120, 144, 130)] = Color3.fromRGB(27, 42, 53),
}

local function Corrode(Part: BasePart)
    local Next = CORROSION[Part.Color]
    Part.Color = Next or Color3.fromRGB(163, 162, 165)
end

--[=[
    One droplet.

    `Aimed` targets a specific fighter instead of a random point. The event alternates
    between the two: random drops sell the storm, aimed drops make sure somebody standing
    still in the open is actually being rained on rather than statistically missed.
]=]
local function Droplet(Context, Direction: Vector3, Aimed: Vector3?)
    local Origin: Vector3

    if Aimed then
        Origin = Aimed - Direction * 220
    else
        local Ground = Context:RandomPoint()
        Origin = Vector3.new(Ground.X, Context.Region.SkyY, Ground.Z) - Direction * 40
    end

    local Length = (Context.Region.SkyY - Context.Region.GroundY) + 320
    local Hit = Context:Raycast(Origin, Direction, Length)
    local Landing = Hit and Hit.Position or (Origin + Direction * Length)

    if Hit then
        local Model = Hit.Instance:FindFirstAncestorOfClass("Model")
        if Model and Model:FindFirstChildWhichIsA("Humanoid") then
            Context:Damage(Model, DROP_DAMAGE, "AcidRain")
        elseif Config.DestroyMapParts and not Hit.Instance.Anchored then
            Corrode(Hit.Instance)
        end
    end

    local Distance = (Landing - Origin).Magnitude
    if Distance < 1 then
        return
    end

    local Streak = Context:Part({
        Name = "AcidDrop",
        Size = Vector3.new(0.22, 0.22, math.min(Distance, 55)),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(120, 200, 70),
        Transparency = 0.35,
        CFrame = CFrame.lookAt(Landing - Direction * math.min(Distance, 55) * 0.5, Landing),
    }, 0.35)

    task.spawn(function()
        for i = 1, 5 do
            if not Streak.Parent then
                return
            end
            Streak.Transparency = 0.35 + (i / 5) * 0.65
            task.wait()
        end
    end)
end

return {
    Name = "Acid Rain",
    Warning = "ACID RAIN",
    Hint = "Get under cover. It eats through anything left in the open.",
    Duration = 80,

    Buildup = function(Context)
        Context:SetVisuals({
            FogColor = Color3.fromRGB(70, 88, 52),
            FogEnd = 700,
            FogStart = 30,
            Brightness = 0.45,
            Tint = Color3.fromRGB(150, 220, 110),
            TintAlpha = 0.14,
            Rain = true,
        })
        Context:Sound(Config.Sounds.Rain, 0.5)
    end,

    Run = function(Context)
        local Angle = Context.Rand:NextNumber() * math.pi * 2
        local Wind = Vector3.new(math.cos(Angle) * 0.22, -1, math.sin(Angle) * 0.22).Unit

        while Context:Wait(TICK) do
            for _ = 1, DROPS_PER_TICK do
                Droplet(Context, Wind)
            end

            for _, Character in Context:Fighters() do
                if Context.Rand:NextNumber() > 0.25 then
                    continue
                end

                local Root = Character:FindFirstChild("HumanoidRootPart")
                if Root then
                    Droplet(Context, Wind, (Root :: BasePart).Position)
                end
            end
        end
    end,

    Cleanup = function(Context)
        Context:ClearVisuals(5)
    end,
}
