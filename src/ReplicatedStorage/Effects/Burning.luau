local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Effect = require(ReplicatedStorage.Classes.Effect)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)

--- Damage per tick per level.
local DAMAGE_PER_LEVEL = 4
--- Seconds between ticks.
local TICK = 0.75

--- Ticking threads, keyed by character, so re-applying doesn't stack two burns.
local ActiveBurns: {[Model]: thread} = {}

return Effect.New({
    Name = "Burning",
    Description = "Deals damage over time. Higher levels burn harder. Kills credited to whoever lit the fire.",
    Duration = 6,
    Level = 1,
    ShowInGUI = true,

    ApplyEffect = function(_own: Types.Effect, level: number, char: Model, duration: number)
        if not RunService:IsServer() then
            -- Client-side heat haze so you can tell you're on fire without checking the HUD.
            local Root = Utils.Character.GetRootPart(char)
            if not Root or Players.LocalPlayer.Character ~= char then
                return
            end

            local Fire = Instance.new("ParticleEmitter")
            Fire.Name = "BurningVFX"
            Fire.Color = ColorSequence.new(Color3.fromRGB(255, 148, 40), Color3.fromRGB(120, 20, 0))
            Fire.Lifetime = NumberRange.new(0.35, 0.7)
            Fire.Rate = 22 * level
            Fire.Speed = NumberRange.new(2, 5)
            Fire.SpreadAngle = Vector2.new(18, 18)
            Fire.Parent = Root

            task.delay(duration, function()
                if Fire and Fire.Parent then
                    Fire:Destroy()
                end
            end)

            return
        end

        -- Only one burn thread per character.
        if ActiveBurns[char] then
            task.cancel(ActiveBurns[char])
            ActiveBurns[char] = nil
        end

        local Humanoid = char:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid then
            return
        end

        -- `Killer` holds whoever last hurt them, which is who set them alight — so a
        -- burn finishing somebody off still counts as that player's kill.
        local Source = char:FindFirstChild("Killer")

        ActiveBurns[char] = task.spawn(function()
            local Elapsed = 0

            while Elapsed < duration do
                Elapsed += task.wait(TICK)

                if not (char and char.Parent and Humanoid and Humanoid.Health > 0) then
                    break
                end

                -- Deliberately raw damage instead of `CommonFunctions.DamagePlayer`:
                -- routing it through there would re-trigger the hit vignette, the speed
                -- burst and the hitmarker on every single tick.
                Humanoid:TakeDamage(DAMAGE_PER_LEVEL * level)

                if Source and Source.Value then
                    -- Refresh the credit so it doesn't time out mid-burn.
                    Source.Value = Source.Value
                end
            end

            ActiveBurns[char] = nil
        end)
    end,

    RemoveEffect = function(_own: Types.Effect, char: Model)
        if not RunService:IsServer() then
            local Root = Utils.Character.GetRootPart(char)
            local Fire = Root and Root:FindFirstChild("BurningVFX")
            if Fire then
                Fire:Destroy()
            end
            return
        end

        if ActiveBurns[char] then
            task.cancel(ActiveBurns[char])
            ActiveBurns[char] = nil
        end
    end,
})
