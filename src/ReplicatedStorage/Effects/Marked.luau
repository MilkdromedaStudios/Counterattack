local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Effect = require(ReplicatedStorage.Classes.Effect)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)

--[=[
    Painted for everyone to see.

    A marked fighter's aura is revealed to every other fighter in the arena for the
    duration — there's no hiding it and no cleansing it. Several killers key off this:
    Hollowmark can blink to whoever's marked, and Verity reads marks as "known truths".

    It doesn't do damage on its own. Being visible in a free for all is punishment enough.
]=]
return Effect.New({
    Name = "Marked",
    Description = "Your aura is visible to every fighter in the arena until it wears off.",
    Duration = 10,
    Level = 1,
    ShowInGUI = true,

    ApplyEffect = function(_own: Types.Effect, _level: number, char: Model, duration: number)
        if not RunService:IsServer() then
            return
        end

        local MarkedPlayer = Players:GetPlayerFromCharacter(char)
        if not MarkedPlayer then
            return
        end

        -- Show them to everyone else who's still fighting.
        for _, Other: Model in workspace.Players:GetChildren() do
            if Other == char then
                continue
            end

            local Role = Other:FindFirstChild("Role")
            if not Role or Role.Value == "Spectator" then
                continue
            end

            local OtherPlayer = Players:GetPlayerFromCharacter(Other)
            if not OtherPlayer then
                continue
            end

            Utils.Player.RevealPlayerAuraTo(OtherPlayer, char, duration, Color3.fromRGB(255, 96, 208))
        end
    end,

    RemoveEffect = function()
        -- The aura highlights carry their own lifetime from `RevealPlayerAuraTo`, so
        -- there's nothing to tear down here.
    end,
})
