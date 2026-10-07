local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Effect = require(ReplicatedStorage.Classes.Effect)
local Types = require(ReplicatedStorage.Classes.Types)

local PlayerSpeedManager = RunService:IsServer()
    and require(game:GetService("ServerScriptService").Managers.PlayerManager.PlayerSpeedManager)
    or nil

--[=[
    Lost your footing. Banana peels, Fall Guy shoves, Yoshi's tongue letting go.

    DELIBERATELY NOT A STUN.

    It would have been easy to make a banana peel a stun, and it would have been wrong. The
    brief for these characters is comedy that is still dangerous, and a stun is not funny —
    it is a window in which you watch yourself die. So Slipping takes away your SPEED and
    your SPRINT for under a second and leaves everything else: you can still swing, still
    use abilities, still turn and fight.

    Short, too. Three quarters of a second, and it does not refresh itself into a lock —
    `OverwriteExistingEffect` means a second banana resets the same short timer rather than
    adding to it. Three Minions chaining peels cannot hold anyone still.

    The slip is sold almost entirely by the `Woozy` screen effect its appliers fire
    alongside it: the camera sways, you can see perfectly, and for a moment you cannot aim.
]=]
return Effect.New({
    Name = "Slipping",
    Description = "You lost your footing. Slow and unable to sprint for a moment — but you can still fight.",
    Duration = 0.75,
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

        -- Hard on speed, because it is over so quickly. Floored so it is never a root.
        PlayerSpeedManager.AddSpeedFactor(Player, "Slipping", math.clamp(1 - 0.2 * level, 0.35, 1))
        PlayerSpeedManager.AddSprintLock(Player, "Slipping")
    end,

    RemoveEffect = function(_own: Types.Effect, char: Model)
        if not RunService:IsServer() then
            return
        end

        local Player = Players:GetPlayerFromCharacter(char)
        if not Player then
            return
        end

        PlayerSpeedManager.RemoveSpeedFactor(Player, "Slipping")
        PlayerSpeedManager.RemoveSprintLock(Player, "Slipping")
    end,
})
