----- || LIBRARIES || -----
Libraries = require("../Connector")
local Types = require("../Types")

RankService = require("../Services/RankService")
ServerService = require("../Services/ServerService")



----- || MIGRATION || -----
do
	if not (game:GetService("RunService"):IsStudio()) and (#game.PrivateServerId > 0 and game.PrivateServerOwnerId == 0) then
		local waitTime = 5
		local function playerAdded(player)
			task.wait(waitTime)
			waitTime = waitTime / 2
			game:GetService("TeleportService"):Teleport(game.PlaceId, player)
			task.delay(5, function()
				game:GetService("TeleportService"):Teleport(game.PlaceId, player)
			end)
		end

		game:GetService("Players").PlayerAdded:Connect(playerAdded)
		for _,player in pairs(game:GetService("Players"):GetPlayers()) do playerAdded(player) end

		return true
	end	
end



----- || SERVER LOCK || -----
function serverLock(player)
	local rank = RankService:GetRankByUserId(player.UserId)
	if (ServerService.ServerLock) and (RankService:GetRankInfo(ServerService.ServerLockRank).Id > rank) then
		player:Kick(`Server has been locked for {ServerService.ServerLockRank}+`)
	end
end

Libraries.Scope:GiveTask(game:GetService("Players").PlayerAdded:Connect(serverLock))
for _, player in game:GetService("Players"):GetPlayers() do serverLock(player) end
ServerService.ServerLocked:Connect(function()
	for _, player in game:GetService("Players"):GetPlayers() do serverLock(player) end	
end)

return true