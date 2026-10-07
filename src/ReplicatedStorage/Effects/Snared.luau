local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Effect = require(ReplicatedStorage.Classes.Effect)
local Types = require(ReplicatedStorage.Classes.Types)

local PlayerSpeedManager = RunService:IsServer()
    and require(game:GetService("ServerScriptService").Managers.PlayerManager.PlayerSpeedManager)
    or nil

--[=[
    Caught in something.

    Deliberately *not* a stun: you keep your abilities and your slash, you just can't
    walk out of range. That makes it a setup tool rather than a delete button — being
    snared next to somebody is dangerous, being snared across the map is survivable.

    Level scales how hard the root is. Level 5+ pins you completely.
]=]
return Effect.New({
    Name = "Snared",
    Description = "Roots you in place. You can still fight back — you just can't walk away.",
    Duration = 2.5,
    Level = 3,
    ShowInGUI = true,

    ApplyEffect = function(_own: Types.Effect, level: number, char: Model)
        if not RunService:IsServer() then
            return
        end

        local Player = Players:GetPlayerFromCharacter(char)
        if not Player then
            return
        end

        -- Level 5 is a total root; anything lower leaves a crawl.
        PlayerSpeedManager.AddSpeedFactor(Player, "Snared", math.clamp(1 - 0.2 * level, 0, 1))

        -- Sprinting out of a snare would defeat the point. Named lock rather than
        -- setting `CanSprint` directly, so overlapping effects don't unlock each other.
        PlayerSpeedManager.AddSprintLock(Player, "Snared")
    end,

    RemoveEffect = function(_own: Types.Effect, char: Model)
        if not RunService:IsServer() then
            return
        end

        local Player = Players:GetPlayerFromCharacter(char)
        if not Player then
            return
        end

        PlayerSpeedManager.RemoveSpeedFactor(Player, "Snared")
        PlayerSpeedManager.RemoveSprintLock(Player, "Snared")
    end,
})
