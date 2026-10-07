----- || LIBRARIES || -----
Libraries = require("../Connector")
Cache = Libraries.Cache "ServerService"
local Types = require("../Types")



----- || MAIN || -----
Cache.Constructor = Cache.Constructor or {
	ServerLock = false,
	ServerLockRank = "None",

	JoinPlayer = function(self: Types.ServerService, senderId: number, userId: number)
		game:GetService("MessagingService"):PublishAsync("Nexus Dynamics", {
			["request"] = "join",
			["type"] = "universal",

			["userid"] = userId,
			["senderid"] = senderId,
		})
	end,

	Shutdown = function(self: Types.ServerService)
		local m = Instance.new("Message", workspace)
		m.Text = require(Libraries.Templates.Messages).Shutdown
		task.wait(1)

		local function kickPlayer(player)
			player:Kick(m.Text)
		end

		for _, player in game:GetService("Players"):GetPlayers() do kickPlayer(player) end
		game:GetService("Players").PlayerAdded:Connect(kickPlayer)
	end,

	Migrate = function(self: Types.ServerService)
		if (#game:GetService("Players"):GetPlayers() == 0) or game:GetService("RunService"):IsStudio() then return end

		local m = Instance.new("Message", workspace)
		m.Text = require(Libraries.Templates.Messages).Migrate

		task.wait(2)

		local reservedServerCode = game:GetService("TeleportService"):ReserveServer(game.PlaceId)
		local function teleportPlayer(player)
			game:GetService("TeleportService"):TeleportToPrivateServer(game.PlaceId, reservedServerCode, { player })
		end

		for _,player in pairs(game:GetService("Players"):GetPlayers()) do teleportPlayer(player) end
		game:GetService("Players").PlayerAdded:Connect(teleportPlayer)
		game:BindToClose(function()	
			repeat task.wait() until #game:GetService("Players"):GetPlayers() == 0
		end)
	end,

	UniversalShutdown = function(self: Types.ServerService)
		game:GetService("MessagingService"):PublishAsync("Nexus Dynamics", {
			["request"] = "shutdown",
			["type"] = "universal",
		})
	end,

	UniversalMigrate = function(self: Types.ServerService)
		game:GetService("MessagingService"):PublishAsync("Nexus Dynamics", {
			["request"] = "migrate",
			["type"] = "universal",
		})
	end,

	IsServerLocked = function(self: Types.ServerService)
		return shared["Nexus Dynamics // Cache"].ServerLock ~= nil
	end,

	Lock = function(self: Types.ServerService, lock: boolean, rankName: string?)
		self.ServerLock = lock
		self.ServerLockRank = rankName or "None"

		if (lock) then
			self.ServerLocked:Fire(rankName)
		else
			self.ServerUnlocked:Fire()
		end
	end,

	UniversalLock = function(self: Types.ServerService, lock: boolean, rankName: string)
		game:GetService("MessagingService"):PublishAsync("Nexus Dynamics", {
			["request"] = `{lock and "" or "un"}lock`,
			["type"] = "universal",

			["value"] = rankName,
		})
	end,

	ServerLocked = Libraries.Signal.new();
}

return Cache.Constructor :: Types.ServerService