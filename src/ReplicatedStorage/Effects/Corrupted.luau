local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Effect = require(ReplicatedStorage.Classes.Effect)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)

--[=[
    1x1x1x1's mark. Being partly deleted.

    A STACKING TELL, NOT A SLOW.

    Corruption does no damage and takes nothing away. What it does is make you progressively
    easier to kill specifically by 1x1x1x1 — every one of its abilities reads the level and
    hits harder, further or longer against someone already corrupted. That is the whole
    character: a killer with poor raw numbers that converts time spent near you into damage
    later.

    The levels, and what reads them:

      1-2  Green tint on your body. Visible to everyone, including you.
      3-4  Your screen starts glitching, and your aura is revealed to 1x1x1x1 through walls.
      5    Full corruption. `Reality Break` becomes available to its caster.

    The counterplay is to break off and let it expire, which is why the duration is short
    for a mark — ten seconds — and does not refresh the whole stack, only extend it.
]=]
return Effect.New({
    Name = "Corrupted",
    Description = "Partly deleted. Every one of 1x1x1x1's attacks hits a corrupted target harder, and at high corruption it can see you through walls.",
    Duration = 10,
    Level = 1,
    ShowInGUI = true,

    ApplyEffect = function(_own: Types.Effect, level: number, char: Model, duration: number)
        if not RunService:IsServer() then
            return
        end

        local Target = Players:GetPlayerFromCharacter(char)
        if not Target then
            return
        end

        --[[
            From level 3, the victim is visible to whoever corrupted them.

            `Character.Killer` is the engine's "who hurt me last", which is exactly the right
            owner for this: the reveal follows whoever is actually applying the stacks rather
            than needing 1x1x1x1 to register itself anywhere.

            Revealed only to THEM, not to everybody — that is what separates this from
            `Marked`. Corruption is a private advantage for one killer, not a public
            broadcast.
        ]]
        if level >= 3 then
            local Source = char:FindFirstChild("Killer")
            local Hunter = Source and Source.Value

            if Hunter and Hunter ~= Target then
                Utils.Player.RevealPlayerAuraTo(Hunter, char, math.min(duration, 6), Color3.fromRGB(40, 235, 120))
            end
        end
    end,

    RemoveEffect = function()
        -- The tint is drawn by the ability that applied it, on a Debris timer, and the
        -- reveal carries its own lifetime from `RevealPlayerAuraTo`. Nothing to undo.
    end,
})
