----- || LIBRARIES || -----
Libraries = require("./Connector")
GhostService = require("./Services/GhostService")
RankService = require("./Services/RankService")
CommandService = require("./Services/CommandService")
UserRegisteryService = require("./Services/UserRegisteryService")



----- || META || -----
local Cache, Meta = {}, {}; Meta._index = Meta

do
	Meta.RevokedAccess = function(self: any, player: Player)
		xpcall(
			function()
				local gui = player:FindFirstChild("Topbar.exe")
				if (gui) then gui:Destroy() end
				
				local gui = player:FindFirstChild("Panel.exe")
				if (gui) then gui:Destroy() end
				
				task.spawn(function()
					local topbarRegistery = script.Parent["Topbar.exe"].RegisteryKey:Clone()
					topbarRegistery.Parent = player
					topbarRegistery.Name = "UnRegisteryKey"
					topbarRegistery.Enabled = true
					topbarRegistery.Invoke:InvokeClient(player)
				end)
				
				task.spawn(function()
					local panelRegistery = script.Parent["Panel.exe"].RegisteryKey:Clone()
					panelRegistery.Parent = player
					panelRegistery.Name = "UnRegisteryKey"
					panelRegistery.Enabled = true
					panelRegistery.Invoke:InvokeClient(player)
				end)
			end,	

			function(message: string)
				Libraries.Log(message, Enum.MessageType.MessageError)
				return nil
			end
		)
	end

	Meta.GrantAccess = function(self: any, player: Player)
		xpcall(
			function()
				local UserRegistery = UserRegisteryService:GetAsync(player.UserId)

				local Executable = Libraries.Package:FindFirstChild("Topbar.exe"):Clone()
				Executable.Parent = player

				local returnedValue; repeat task.wait(0.15)
					if returnedValue then break end
					Executable.RegisteryKey.Enabled = true
					returnedValue = Executable.RegisteryKey.Invoke:InvokeClient(player, UserRegistery)
				until returnedValue

				Executable.RegisteryKey:Destroy()

				--				

				local Executable = Libraries.Package:FindFirstChild("Panel.exe"):Clone()
				Executable.Parent = player

				local returnedValue; repeat task.wait(0.15)
					if returnedValue then break end
					Executable.RegisteryKey.Enabled = true
					returnedValue = Executable.RegisteryKey.Invoke:InvokeClient(player, UserRegistery)
				until returnedValue 

				Executable.RegisteryKey:Destroy()
			end,

			function(message: string)
				Libraries.Log(message, Enum.MessageType.MessageError)
				return nil
			end
		)
	end

	Meta.GrantNotificationAccess = function(self: any, player: Player)
		xpcall(
			function()
				local Executable = Libraries.Package:FindFirstChild("Notification.exe"):Clone()
				Executable.Parent = player

				local returnedValue; repeat task.wait(0.15)
					if returnedValue then break end
					Executable.RegisteryKey.Enabled = true
					returnedValue = Executable.RegisteryKey.Invoke:InvokeClient(player)
				until returnedValue

				Executable.RegisteryKey:Destroy()
			end,

			function(message: string)
				Libraries.Log(message, Enum.MessageType.MessageError)
				return nil
			end
		)
	end

	Meta.RevokeNotificationAccess = function(self: any, player: Player)
		xpcall(
			function()
				repeat task.wait()
					local framework = player:FindFirstChild("notification-client@2.0.6")
					local _nc = player.PlayerGui:FindFirstChild("Nexus Dynamics · Notification")
					if not _nc then break end
					_nc:Destroy()
				until not player:FindFirstChild("notification-client@2.0.6", true) and not player:FindFirstChild("nexus-dynamics-notifications@2.0", true)
			end,	

			function(message: string)
				Libraries.Log(message, Enum.MessageType.MessageError)
				return nil
			end
		)
	end	
end



----- || MAIN || -----
RankRefresh = Libraries.Scope:GiveTask(coroutine.create(function()
	while task.wait() do
		RankService:RefreshRanks()
		task.wait(10)
	end
end))

Players = Libraries.Scope:GiveTask(coroutine.create(function() 
	local _task = {
		PlayerAdded = function(player)
			Libraries.Log:Capture(`{player.Name} has joined.`, Enum.MessageType.MessageInfo)
			
			GhostService:RefreshPlayer(player)
			Meta:GrantNotificationAccess(player)
			Libraries.Log:Capture(`{player.Name} has been initialized successfully`, Enum.MessageType.MessageInfo)
			
			local Commands do
				player.Chatted:Connect(function(message)
					local commandConfig, commandDict = CommandService:Request(player, message)
					if (not commandConfig or not commandDict) then return end
					
					if not (RankService:GetRankInfo(commandDict.Rank).Id <= RankService:GetRankByUserId(player.UserId).Id and commandConfig.HasPrefix) then return end
					CommandService:Cast(player, commandConfig, commandDict)
				end)
				
				Libraries.Log:Capture(`{player.Name}'s commands has been initialized successfully`, Enum.MessageType.MessageInfo)	
			end
			
			local Ranking do
				repeat task.wait() until RankService:GetRankByUserId(player.UserId)
				local rankData = RankService:GetRankByUserId(player.UserId)
				if (not rankData or rankData.Name ==  "None") then return end
				RankService:GrantT(player.userId, rankData.Name)
				Libraries.Log:Capture(`{player.Name}'s rank has been initialized successfully`, Enum.MessageType.MessageInfo)	
			end
		end,

		PlayerRemoving = function(player)

		end
	}

	
	Libraries.Scope:GiveTask(RankService.Granted:Connect(function(userId, rankData)
		Libraries.Log:Capture(`{userId} has been ranked {rankData.Name}`, Enum.MessageType.MessageInfo)
		
		local player = game:GetService("Players"):GetPlayerByUserId(userId)
		if not player then return end
		Meta:GrantAccess(player)
		Libraries.Signals["<notification>"]:FireClient(player, `You've been ranked {rankData.Name}\nClick to view commands`, 20, "commands")
	end))
	
	Libraries.Scope:GiveTask(RankService.Revoked:Connect(function(userId)
		local player = game:GetService("Players"):GetPlayerByUserId(userId)
		if not player then return end
		Meta:RevokedAccess(player)
		Libraries.Signals["<notification>"]:FireClient(player, `You've been unranked`)
	end))

	
	Libraries.Scope:GiveTask(game:GetService("Players").PlayerAdded:Connect(_task.PlayerAdded))
	Libraries.Scope:GiveTask(game:GetService("Players").PlayerRemoving:Connect(_task.PlayerRemoving))
	for _, player in game:GetService("Players"):GetPlayers() do _task.PlayerAdded(player) end
end))

Signals = Libraries.Scope:GiveTask(coroutine.create(function()
	Libraries.Signals.Parent = game:GetService("ReplicatedStorage")

	for _, script in Libraries.Signals:GetDescendants() do
		if script:IsA("Script") or script:IsA("LocalScript") then
			script.Enabled = true
		end
	end	

	Libraries.Signals["<reload>"].OnServerInvoke = function(player)
		xpcall(
			function()
				Meta:RevokedAccess(player)
				task.wait(1)

				--| Panel
				local RankData = RankService:GetRankByUserId(player.UserId)

				while task.wait(0.5) and not RankData do
					RankData = RankService:GetRankByUserId(player.UserId)
				end

				if RankData and RankData.Id > 0 then
					Meta:GrantAccess(player)
					Libraries.Signals["<notification>"]:FireClient(player, `You've been ranked {RankData.Name}\nClick to view commands`, 20, "commands")
				end
			end, 

			function(message: string)
				Libraries.Log(message, Enum.MessageType.MessageError)
				return nil
			end
		)	
	end	

	Libraries.Signals["<usersettings>"].OnServerInvoke = function(player, userRegistery)
		if not userRegistery then return end
		local rank = RankService:GetRankByUserId(player.UserId); if not rank or rank.Name:lower() == "none" then return end
		UserRegisteryService:SaveAsync(player.UserId, userRegistery)
	end

	Libraries.Signals["<command>"].OnServerInvoke = function(client: Player, field: any)
		local rank = RankService:GetRankByUserId(client.UserId); if not rank or rank.Name:lower() == "none" then return end 
		if not field then
			local list = CommandService:GetCommandList("All")
			
			for x, commandDict in list do
				list[x].RankName = RankService:GetRankInfo(commandDict.Rank).Name
			end
			
			return list
		end

		if field.request then
			local prefix = require("./AI/FormatAI@rules").Prefix
			local commandConfig, commandDict = CommandService:Request(client, (string.find(field.message, prefix, 1) == 1) and field.message or prefix..field.message)
			
			if not (RankService:GetRankInfo(commandDict.Rank).Id <= RankService:GetRankByUserId(client.UserId).Id and commandConfig.HasPrefix) then return end
			CommandService:Cast(client, commandConfig, commandDict)
		end

		if field.rules then
			return {Rules = require("./AI/FormatAI@rules"), Flags = require("./AI/FormatAI@flags")}
		end	

		return nil
	end
end))

MessagingService = Libraries.Scope:GiveTask(
	game:GetService("MessagingService"):SubscribeAsync("Nexus Dynamics", function( requestData: any ) requestData = requestData.Data

		if requestData["request"] == "join" and requestData["type"] == "universal" then
			for _, player in pairs(game:GetService("Players"):GetPlayers()) do
				if player.UserId == requestData.Data.UserId then

					game:GetService("MessagingService"):PublishAsync("Nexus Dynamics", {
						["request"] = "found",
						["type"] = "universal",

						["jobid"] = game.JobId,
						["userid"] = requestData.userid,
						["senderid"] = requestData.senderid,
					})

					break
				end
			end
		end

		--

		if requestData["request"] == "found" and requestData["type"] == "universal" then
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, requestData.jobid, game:GetService("Players"):GetPlayerByUserId(requestData.senderid))
		end

		--

		if requestData["request"] == "shutdown" and requestData["type"] == "server" and requestData["jobid"] == game.JobId then
			require("./Services/ServerService"):Shutdown()
		end

		if requestData["request"] == "shutdown" and requestData["type"] == "universal" then
			require("./Services/ServerService"):Shutdown()
		end

		--

		if requestData["request"] == "migrate" and requestData["type"] == "server" and requestData["jobid"] == game.JobId then
			require("./Services/ServerService"):Migrate()
		end

		if requestData["request"] == "migrate" and requestData["type"] == "universal" then
			require("./Services/ServerService"):Migrate()
		end 

		--

		if requestData["request"] == "lock" and requestData["type"] == "universal" then
			local rank = RankService:GetRankInfo(requestData.value)
			if not rank then return end

			if rank.Id > 1 then
				require("./Services/ServerService"):Lock(true, rank)
			else
				require("./Services/ServerService"):Lock(false)
			end
		end 

		--

		if requestData["request"] == "unlock" and requestData["type"] == "universal" then
			require("./Services/ServerService"):Lock(false)
		end 
	end)
)

return {}