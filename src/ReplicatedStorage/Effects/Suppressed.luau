local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Effect = require(ReplicatedStorage.Classes.Effect)
local Types = require(ReplicatedStorage.Classes.Types)

local PlayerSpeedManager = RunService:IsServer()
    and require(game:GetService("ServerScriptService").Managers.PlayerManager.PlayerSpeedManager)
    or nil

--[=[
    Being shot at. Not being shot.

    The Mini-Gunner's rounds build this on anyone they pass near, hit or miss. It is a small
    movement penalty that makes crossing open ground into sustained fire genuinely worse than
    waiting — which is the entire point of a suppression weapon, and something a damage
    number alone cannot express.

    WHY IT IS CAPPED SO LOW
    ----------------------
    Each level is 8% speed and the cap is level 4, so the worst case is about a third slower.
    A suppression effect that could stack to a root would turn the Mini-Gunner from "strong
    at range" into "you cannot approach him", and he already has the highest uninterrupted
    damage on the roster. The cap is enforced by the applier, not here — effects in this
    engine take their level from the caller — but the reasoning belongs with the effect.

    It deliberately does NOT take sprinting away. `Grounded` does that, and a killer who both
    slows you and stops you sprinting from 70 studs away has no counterplay.
]=]
return Effect.New({
    Name = "Suppressed",
    Description = "Pinned down by incoming fire. Slightly slower while it lasts — you can still sprint, and still fight back.",
    Duration = 2,
    Level = 1,
    ShowInGUI = true,

    ApplyEffect = function(_own: Types.Effect, level: number, char: Model)
        if not RunService:IsServer() then
            return
        end

        local Player = Players:GetPlayerFromCharacter(char)
        if not Player then
            return
        end

        -- 8% per level, floored at 0.65 so even a bugged level can't root anybody.
        local Multiplier = math.clamp(1 - 0.08 * math.clamp(level, 1, 4), 0.65, 1)
        PlayerSpeedManager.AddSpeedFactor(Player, "Suppressed", Multiplier)
    end,

    RemoveEffect = function(_own: Types.Effect, char: Model)
        if not RunService:IsServer() then
            return
        end

        local Player = Players:GetPlayerFromCharacter(char)
        if not Player then
            return
        end

        PlayerSpeedManager.RemoveSpeedFactor(Player, "Suppressed")
    end,
})
