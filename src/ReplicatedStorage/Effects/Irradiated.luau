local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Effect = require(ReplicatedStorage.Classes.Effect)
local Types = require(ReplicatedStorage.Classes.Types)

local PlayerSprintManager = RunService:IsServer()
    and require(game:GetService("ServerScriptService").Managers.PlayerManager.PlayerSprintManager)
    or nil

--- Damage per tick per level. Lower than Burning — this one is about the stamina lock.
local DAMAGE_PER_LEVEL = 2
local TICK = 1

local ActiveTicks: {[Model]: thread} = {}

--[=[
    Radiation sickness.

    Weaker damage over time than `Burning`, but it also stops stamina from regenerating
    for its whole duration — so anyone caught in a fallout zone can't just sprint away
    and wait it out. It's what makes Nuker's zones actually threatening instead of
    something you walk through.
]=]
return Effect.New({
    Name = "Irradiated",
    Description = "Chips away at your health and stops stamina from regenerating while it lasts.",
    Duration = 8,
    Level = 1,
    ShowInGUI = true,

    ApplyEffect = function(_own: Types.Effect, level: number, char: Model, duration: number)
        if not RunService:IsServer() then
            return
        end

        if ActiveTicks[char] then
            task.cancel(ActiveTicks[char])
            ActiveTicks[char] = nil
        end

        local Humanoid = char:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid then
            return
        end

        local Player = Players:GetPlayerFromCharacter(char)
        local Managed = Player and PlayerSprintManager.ManagedPlayers[Player]
        if Managed then
            Managed.CanGainStamina = false
        end

        ActiveTicks[char] = task.spawn(function()
            local Elapsed = 0

            while Elapsed < duration do
                Elapsed += task.wait(TICK)

                if not (char and char.Parent and Humanoid and Humanoid.Health > 0) then
                    break
                end

                Humanoid:TakeDamage(DAMAGE_PER_LEVEL * level)
            end

            ActiveTicks[char] = nil
        end)
    end,

    RemoveEffect = function(_own: Types.Effect, char: Model)
        if not RunService:IsServer() then
            return
        end

        if ActiveTicks[char] then
            task.cancel(ActiveTicks[char])
            ActiveTicks[char] = nil
        end

        local Player = Players:GetPlayerFromCharacter(char)
        local Managed = Player and PlayerSprintManager.ManagedPlayers[Player]
        if Managed then
            Managed.CanGainStamina = true
        end
    end,
})
