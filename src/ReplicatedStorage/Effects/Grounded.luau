local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Effect = require(ReplicatedStorage.Classes.Effect)
local Types = require(ReplicatedStorage.Classes.Types)

local PlayerSpeedManager = RunService:IsServer()
    and require(game:GetService("ServerScriptService").Managers.PlayerManager.PlayerSpeedManager)
    or nil

--[=[
    Pinned to a walk.

    Doesn't slow your base speed at all — it just takes sprinting away. That's a much
    more interesting punishment than a raw slow, because it caps your escape speed
    without making you feel like you're wading through mud, and it's the natural
    counter to the fliers and the dashers on the roster.

    Also drains your stamina to nothing so the moment it drops you still can't
    immediately burst away.
]=]
return Effect.New({
    Name = "Grounded",
    Description = "You can't sprint. Your legs still work — you just aren't going anywhere fast.",
    Duration = 5,
    Level = 1,
    ShowInGUI = true,

    ApplyEffect = function(_own: Types.Effect, _level: number, char: Model)
        if not RunService:IsServer() then
            return
        end

        local Player = Players:GetPlayerFromCharacter(char)
        if not Player or not PlayerSpeedManager.ManagedPlayers[Player] then
            return
        end

        -- Named lock rather than setting `CanSprint` directly, so this and Snared
        -- don't hand sprinting back to each other while both are still running.
        PlayerSpeedManager.AddSprintLock(Player, "Grounded")

        -- Empty the tank so there's no instant getaway the second this wears off.
        local Stamina = char:FindFirstChild("PlayerAttributes")
        Stamina = Stamina and Stamina:FindFirstChild("Stamina")
        if Stamina then
            Stamina.Value = 0
        end
    end,

    RemoveEffect = function(_own: Types.Effect, char: Model)
        if not RunService:IsServer() then
            return
        end

        local Player = Players:GetPlayerFromCharacter(char)
        if not Player then
            return
        end

        PlayerSpeedManager.RemoveSprintLock(Player, "Grounded")
    end,
})
