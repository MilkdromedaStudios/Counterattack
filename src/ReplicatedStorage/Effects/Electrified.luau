local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Effect = require(ReplicatedStorage.Classes.Effect)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)

--- Damage per tick per level.
local DAMAGE_PER_LEVEL = 4
--- Seconds between ticks. Much faster than `Burning`'s, which is the point of it.
local TICK = 0.4

--- Ticking threads, keyed by character, so re-applying doesn't run two loops at once.
local ActiveCharges: {[Model]: thread} = {}

--[=[
    Carrying a charge. Pikachu's electricity, and Shadow's Chaos Spear.

    WHY NOT JUST USE `Burning`?
    --------------------------
    Two reasons, and only one of them is flavour.

      * BURNING IS ATTRITION; THIS IS A SIGNAL. Six seconds of slow ticks follows you out of
        a fight. This resolves in a second and a half of fast ones, so it lives and dies
        inside the engagement that applied it.
      * PIKACHU'S KIT CHAINS OFF IT. `Thunderbolt` jumps preferentially to targets already
        carrying a charge, and `Static` reads it too. That needs a condition on the victim
        that is specifically electrical — reusing `Burning` would have let Steve's lava
        bucket feed Pikachu's chain lightning.

    Structurally it is `Burning`'s sibling and follows it deliberately: one thread per
    character, raw `TakeDamage` rather than `DamagePlayer` (routing ticks through there would
    re-trigger the hit vignette, the hitmarker and the post-damage speed burst three times
    over), and kill credit read from the engine's `Character.Killer`.
]=]
return Effect.New({
    Name = "Electrified",
    Description = "Carrying a charge. A few fast ticks of damage, and electrical attacks seek you out while it lasts.",
    Duration = 1.5,
    Level = 1,
    ShowInGUI = true,

    ApplyEffect = function(_own: Types.Effect, level: number, char: Model, duration: number)
        if not RunService:IsServer() then
            -- Arcs on your own body, so you know you're carrying a charge without reading
            -- the HUD. Only on the local character: forty emitters across the arena is not
            -- worth the frames.
            local Root = Utils.Character.GetRootPart(char)
            if not Root or Players.LocalPlayer.Character ~= char then
                return
            end

            local Arc = Instance.new("ParticleEmitter")
            Arc.Name = "ElectrifiedVFX"
            Arc.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            Arc.Color = ColorSequence.new(Color3.fromRGB(255, 240, 90), Color3.fromRGB(255, 255, 255))
            Arc.Lifetime = NumberRange.new(0.1, 0.25)
            Arc.Rate = 30 * level
            Arc.Speed = NumberRange.new(3, 9)
            Arc.SpreadAngle = Vector2.new(180, 180)
            Arc.LightEmission = 1
            Arc.Size = NumberSequence.new(0.5)
            Arc.Parent = Root

            task.delay(duration, function()
                if Arc and Arc.Parent then
                    Arc:Destroy()
                end
            end)

            return
        end

        if ActiveCharges[char] then
            task.cancel(ActiveCharges[char])
            ActiveCharges[char] = nil
        end

        local Humanoid = char:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid then
            return
        end

        local Source = char:FindFirstChild("Killer")

        ActiveCharges[char] = task.spawn(function()
            local Elapsed = 0

            while Elapsed < duration do
                Elapsed += task.wait(TICK)

                if not (char and char.Parent and Humanoid and Humanoid.Health > 0) then
                    break
                end

                Humanoid:TakeDamage(DAMAGE_PER_LEVEL * math.clamp(level, 1, 3))

                if Source and Source.Value then
                    -- Refresh the credit so it doesn't time out mid-charge.
                    Source.Value = Source.Value
                end
            end

            ActiveCharges[char] = nil
        end)
    end,

    RemoveEffect = function(_own: Types.Effect, char: Model)
        if not RunService:IsServer() then
            local Root = Utils.Character.GetRootPart(char)
            local Arc = Root and Root:FindFirstChild("ElectrifiedVFX")
            if Arc then
                Arc:Destroy()
            end
            return
        end

        if ActiveCharges[char] then
            task.cancel(ActiveCharges[char])
            ActiveCharges[char] = nil
        end
    end,
})
