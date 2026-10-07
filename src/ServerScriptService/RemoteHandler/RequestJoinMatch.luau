--[=[
    Server side of the big PLAY button.

    The client can only ever *ask* to join. Everything that decides whether that's
    allowed — cooldowns, whether a match is live, whether mid-match joining is on —
    lives in `RoundManager.Callables.RequestJoin`, on the server, where an exploiter
    can't reach it.

    Returns a status string the client turns into button text, plus an optional detail
    number (queue size, or seconds of respawn cooldown left).
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ReplicatedStorage.Modules.Network)
local GameMode = require(ReplicatedStorage.Modules.GameMode)

--- Throttles how often a single player may hit the button, so spamming it can't be
--- used to hammer the round manager.
local Debounce: {[number]: number} = {}
local DEBOUNCE_TIME = 0.75

return function()
    local RoundManager = require(ServerScriptService.Managers.RoundManager)

    Players.PlayerRemoving:Connect(function(Player: Player)
        Debounce[Player.UserId] = nil
    end)

    Network:SetConnection("RequestJoinMatch", "REMOTE_FUNCTION", function(Player: Player): (string, any?)
        if not Player or not Player.Parent then
            return "Rejected"
        end

        local Now = time()
        if Debounce[Player.UserId] and Now < Debounce[Player.UserId] then
            return "Rejected"
        end
        Debounce[Player.UserId] = Now + DEBOUNCE_TIME

        -- The player has to have finished loading before they're allowed to fight,
        -- otherwise their saved data (and therefore their equipped killer) isn't ready.
        if not ReplicatedStorage.LoadedPlayers:FindFirstChild(Player.Name) then
            return "NotLoaded"
        end

        return RoundManager.Callables.RequestJoin(Player)
    end)

    --- Lets the client ask for the live state so its button label stays honest.
    Network:SetConnection("GetMatchStatus", "REMOTE_FUNCTION", function(Player: Player)
        return {
            ArenaOpen = RoundManager.ArenaOpen,
            RespawnWait = RoundManager.Utils.GetRespawnWait(Player),
            Fighting = RoundManager.Utils.IsFighting(Player),
        }
    end)
end
