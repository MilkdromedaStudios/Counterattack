----- || LIBRARIES || -----
Libraries = require("../Connector")
Cache = Libraries.Cache "BanService"
local Types = require("../Types")



----- || MAIN || -----
Cache.Constructor = Cache.Constructor or {	
	IsBanned = function(self: Types.BanService, userId: number)		
		local history = Libraries.Util.PagesToTable(game:GetService("Players"):GetBanHistoryAsync(userId))		
		return history[#history][1].Ban, history[#history][1]
	end,
	
	--

	PlaceBan = function(self: Types.BanService, userIds: {number}, reason: string?, duration: number?)
		repeat task.wait() table.remove(userIds, Libraries.Util.GetDeveloperId()) until not table.find(userIds, Libraries.Util.GetDeveloperId())
		
		local config: Types.BanConfigType = {
			UserIds = userIds,
			Duration = duration or -1,
			DisplayReason = reason or "None Provided",
			PrivateReason = "Ban enforced by an administrator of Nexus Dynamics 2.0.",
			ApplyToUniverse = false,
		}

		xpcall(
			function()
				game:GetService("Players"):BanAsync(config)
				self.PlaceBanned:Fire(userIds, reason, duration)
			end,

			function(message: string)
				Libraries.Log:Capture(message, Enum.MessageType.MessageError)
				return nil
			end
		)
	end,

	UniverseBan = function(self: Types.BanService, userIds: {number}, reason: string?, duration: number?)
		repeat task.wait() table.remove(userIds, Libraries.Util.GetDeveloperId()) until not table.find(userIds, Libraries.Util.GetDeveloperId())
		
		for _, userId in userIds do
			warn(userId)
		end
		
		local config: Types.BanConfigType = {
			UserIds = userIds,
			Duration = duration or -1,
			DisplayReason = reason or "None Provided",
			PrivateReason = "Ban enforced by an administrator of Nexus Dynamics 2.0.",
			ApplyToUniverse = true,
		}

		xpcall(
			function()
				game:GetService("Players"):BanAsync(config)
				self.UniverseBanned:Fire(userIds, reason, duration)
			end,

			function(message: string)
				Libraries.Log:Capture(message, Enum.MessageType.MessageError)
				return nil
			end
		)
	end,

	UnBan = function(self: Types.BanService, userIds: {number})
		xpcall(
			function()
				game:GetService("Players"):UnbanAsync({ UserIds = userIds, ApplyToUniverse = false, })
				game:GetService("Players"):UnbanAsync({ UserIds = userIds, ApplyToUniverse = true, })
				

				self.UnBanned:Fire(userIds)
			end,

			function(message: string)
				Libraries.Log:Capture(message, Enum.MessageType.MessageError)
				return nil
			end
		)
	end,

	--

	PlaceBanned = Libraries.Signal.new(),
	UniverseBanned = Libraries.Signal.new(),
	UnBanned = Libraries.Signal.new(),
}

return Cache.Constructor :: Types.BanService