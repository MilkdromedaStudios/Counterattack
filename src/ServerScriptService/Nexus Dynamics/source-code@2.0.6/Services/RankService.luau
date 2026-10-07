----- || LIBRARIES || -----
Libraries = require("../Connector")
Template = require(Libraries.Templates.RankTemplate)
Cache = Libraries.Cache "RankService"
local Types = require("../Types")



----- || MAIN || -----
Cache.Constructor = Cache.Constructor or {
	AutoRankOwner = true,
	RankList = Template,

	RefreshRanks = function(self: Types.RankService)
		self.RankList = Libraries.DataStore:GetAsync("RankService") or Template
		return self
	end,

	GetRankInfos = function(self: Types.RankService) 
		local list = {} :: {Types.RankData}
		for _, rankData in self.RankList.Ranks do
			table.insert(list, { Id = rankData[1], Name = rankData[2] } :: Types.RankData)
		end
		return list
	end,

	GetRankInfo = function(self: Types.RankService, identity: string | number)
		return Libraries.Switch(typeof(identity)) {
			["number"] = function()
				for _, rankInfo in self:GetRankInfos() do
					if rankInfo.Id == identity then return rankInfo end
				end

				return nil
			end,

			["string"] = function() 
				local data = self:GetRankInfos()
				for _, rankInfo in self:GetRankInfos() do
					if rankInfo.Name == identity then return rankInfo end
				end

				return nil
			end,

			default = function()
				return nil
			end,
		}
	end,

	--

	GetRankByUsername = function(self: Types.RankService, name: string)
		local passed, result = xpcall(
			function()
				if self.AutoRankOwner and game:GetService("Players"):GetUserIdFromNameAsync(name) == Libraries.Util.GetDeveloperId() then
					return self:GetRankInfo("Owner")
				end

				for _, rankData in self.RankList.Ranks do
					if typeof(rankData) == "string" or not rankData[3] then continue end
					if not table.find(rankData[3], game:GetService("Players"):GetUserIdFromNameAsync(name)) then continue end
					return {Name = rankData[1], Id = rankData[2]}
				end

				local player = game:GetService("Players"):GetPlayerByUserId(game:GetService("Players"):GetUserIdFromNameAsync(name))
				if not player then return nil end

				for gamepassId, rankName in self.RankList.Assign.Gamepasses do
					pcall(function()
						if game:GetService("MarketplaceService"):UserOwnsGamePassAsync(player.UserId, gamepassId) then
							return self:GetRankInfo(rankName)
						end
					end)	
				end

				for assetId, rankName in self.RankList.Assign.Assets do
					pcall(function()
						if game:GetService("MarketplaceService"):PlayerOwnsAsset(player, assetId) then
							return self:GetRankInfo(rankName)
						end
					end)
				end

				for groupId, roles in self.RankList.Assign.Groups do
					local rankName = roles[tostring(player:GetRankInGroup(groupId))]
					if rankName then
						return self:GetRankInfo(rankName)
					end				
				end

				return {Name="None", Id=0}
			end, 

			function(message: string)
				Libraries.Log:Capture(message, Enum.MessageType.MessageError)
				return nil
			end
		)

		return passed and result or {Name="None", Id=0}
	end,

	GetRankByUserId = function(self: Types.RankService, userId: number)
		local passed, result = xpcall(
			function()
				if self.AutoRankOwner and (tonumber(userId) or 1) == Libraries.Util.GetDeveloperId() then
					return self:GetRankInfo("Owner")
				end

				for _, rankData in self.RankList.Ranks do
					if typeof(rankData) == "string" or not rankData[3] then continue end
					if not table.find(rankData[3], (tonumber(userId) or 1)) then continue end
					return {Id = rankData[1], Name = rankData[2]}
				end

				local player = game:GetService("Players"):GetPlayerByUserId((tonumber(userId) or 1))
				if not player then return nil end

				for gamepassId, rankName in self.RankList.Assign.Gamepasses do
					pcall(function()
						if game:GetService("MarketplaceService"):UserOwnsGamePassAsync(player.UserId, gamepassId) then
							return self:GetRankInfo(rankName)
						end
					end)	
				end

				for assetId, rankName in self.RankList.Assign.Assets do
					pcall(function()
						if game:GetService("MarketplaceService"):PlayerOwnsAsset(player, assetId) then
							return self:GetRankInfo(rankName)
						end
					end)
				end

				for groupId, roles in self.RankList.Assign.Groups do
					local rankName = roles[tostring(player:GetRankInGroup(groupId))]
					if rankName then
						return self:GetRankInfo(rankName)
					end				
				end

				return {Name="None", Id=0}
			end, 

			function(message: string)
				Libraries.Log:Capture(message, Enum.MessageType.MessageError)
				return nil
			end
		)

		return passed and result or {Name="None", Id=0}
	end,

	--

	Grant = function(self: Types.RankService, userId: number, rankName: string)
		xpcall(
			function()
				Libraries.DataStore:UpdateAsync("RankService", function(currentData)
					currentData = currentData or Template

					for _, rankData in currentData.Ranks do
						if rankData[2] ~= rankName or not rankData[3] then continue end
						table.insert(rankData[3], userId)
					end

					self.RankList = currentData
					return currentData
				end)	

				self.Granted:Fire(userId, self:GetRankInfo(rankName))
			end, 

			function(message: string)
				Libraries.Log:Capture(message, Enum.MessageType.MessageError)
			end
		)

	end,

	GrantT = function(self: Types.RankService, userId: number, rankName: string)
		self.Granted:Fire(userId, self:GetRankInfo(rankName))
	end,

	Revoke = function(self: Types.RankService, userId: number)
		xpcall(
			function()
				Libraries.DataStore:UpdateAsync("RankService", function(currentData)
					currentData = currentData or Template

					for _, rankData in currentData.Ranks do
						if not rankData[3] or not table.find(rankData[3], tonumber(userId)) then continue end
						table.remove(rankData[3], table.find(rankData[3], tonumber(userId)))
					end

					self.RankList = currentData
					return currentData
				end)		

				self.Revoked:Fire(userId)
			end, 

			function(message: string)
				Libraries.Log:Capture(message, Enum.MessageType.MessageError)
			end
		)
	end,

	RevokeT = function(self: Types.RankService, userId: number)
		self.Revoked:Fire(userId)
	end,

	--

	Granted = Libraries.Signal.new(),
	Revoked = Libraries.Signal.new(),
	Refreshed = Libraries.Signal.new(),
}

return Cache.Constructor :: Types.RankService