----- || ENVIRONMENT || -----
do DebugMode = false
	shared["nd diagnostics"] = DebugMode
	Migration = require("./source-code@2.0.6/AI/Server@migration")
	game:GetService("Players"):SetAttribute("DeveloperId", require(script.Libraries.Util).GetDeveloperId())
	game:GetService("Players"):SetAttribute("Prefix", require("./source-code@2.0.6/AI/FormatAI@rules").Prefix)
	
	task.spawn(function()
		local CheckEnvironment do
			local HttpService do
				xpcall( 
					function() 
						game:GetService("HttpService"):GetAsync("https://www.google.com") 
						HttpService = true 
					end, 

					function() 
						HttpService = false 
					end 
				)
			end

			local APIServices, Installation do
				xpcall( 
					function() 
						local DataStore = game:GetService("DataStoreService"):GetDataStore("Nexus Dynamics // Data v2.0")
						DataStore:UpdateAsync("Installation", function(previousData)
							Installation = previousData 
							return previousData
						end) 

						APIServices = true 
					end, 

					function() 
						APIServices = false
					end 
				)
			end

			--

			CheckEnvironment = {
				HttpService = true, 
				APIServices = true,
				ThirdPartySales = true,
				ThirdPartyTeleports = true,
				Parent = table.find({"workspace", "serverscriptservice", "players"}, game:FindFirstChild("Nexus Dynamics", true).Parent.Name:lower()) ~= nil
			}
		end

		local SetupGuide do	
			_G["nd init setup"] = Instance.new("BindableEvent")
			local remoteFunction = Instance.new("RemoteFunction", game:GetService("ReplicatedStorage"))
			remoteFunction.Name = "nexus-dynamics@2.0-failsafe"
			remoteFunction:AddTag("nexus-dynamics@2.0-failsafe")

			remoteFunction.OnServerInvoke = function(plr, data)
				if typeof(data) ~= "table" then return end
				game:GetService("DataStoreService"):GetDataStore("Nexus Dynamics // Data v2.0"):SetAsync("RankService", data)
			end

			local function boot(player, data)
				local userRegistery = require(script:FindFirstChild("UserRegistery", true))

				for key, array in userRegistery do
					if typeof(array) == "string" then
						userRegistery[key] = game:GetService("HttpService"):JSONDecode(array)
					end

					for index, value in userRegistery[key] do
						userRegistery[key][index] = (typeof(value) == "string" and value:sub(1, 1) == "#") and Color3.fromHex(value) or value
					end
				end

				--		

				local player = player

				local Executable = script:FindFirstChild("Setup.exe"):Clone()
				Executable.Parent = player

				local returnedValue; repeat task.wait(0.15)
					if returnedValue then break end
					Executable.RegisteryKey.Enabled = true
					returnedValue = Executable.RegisteryKey.Invoke:InvokeClient(player, userRegistery, CheckEnvironment, data)
				until returnedValue 

				Executable.RegisteryKey:Destroy()
			end

			_G["nd init setup"].Event:Connect(function(player)
				if not game:GetService("RunService"):IsStudio() then warn("Can't use /setup in-game") return end
				local data = game:GetService("DataStoreService"):GetDataStore("Nexus Dynamics // Data v2.0"):GetAsync("RankService") or require("./source-code@2.0.6/Templates/RankTemplate")
				boot(player, data)
			end)

			if table.find(CheckEnvironment, false) then
				SetupGuide = true 

				local data = game:GetService("DataStoreService"):GetDataStore("Nexus Dynamics // Data v2.0"):GetAsync("RankService") or require("./source-code@2.0.6/Templates/RankTemplate")

				boot(game:GetService("Players"):GetPlayers()[1], data) 
				return true 
			end

			SetupGuide = false
		end
	end)
end



----- || LIBRARIES || -----
Libraries = require(script.Connector)



----- || COMMANDS || -----
Libraries.Scope:GiveTask(coroutine.create(function()
	if (not game:GetService("RunService"):IsStudio()) then return end

	local setupCommand = Instance.new("TextChatCommand", game:GetService("TextChatService"))
	setupCommand.Name = "/setup"
	setupCommand.PrimaryAlias = "/setup"

	Libraries.Scope:GiveTask(setupCommand.Triggered:Connect(function(textSource)
		local player = game:GetService("Players"):GetPlayerByUserId(textSource.UserId)
		_G["nd init setup"]:Fire(player)
	end))
	
	--
	
	local debugCommand = Instance.new("TextChatCommand", game:GetService("TextChatService"))
	debugCommand.Name = "/debug"
	debugCommand.PrimaryAlias = "/debug"
	
	Libraries.Scope:GiveTask(debugCommand.Triggered:Connect(function(textSource)
		local history = Libraries.Log:GetLogHistory()

		warn("---------------------------------")
		game:GetService("TestService"):Message("\n\nHistory("..#history.."):\n---------------------------------\n"..game:GetService("HttpService"):JSONEncode(history))
		warn("---------------------------------")
	end))
end))



----- || REGION || -----
Libraries.Scope:GiveTask(coroutine.create(function()
	xpcall(
		function()
			game:GetService("Players"):SetAttribute(
				game:GetService("HttpService"):JSONDecode(game:GetService("HttpService"):GetAsync("http://ip-api.com/json/"))["country"] or "N/A"
			)
		end,
		
		function(message: string)
			Libraries.Log:Capture(message, Enum.MessageType.MessageError)
		end
	)
end))



----- || REPLICATION || -----
do
	local folder = Instance.new("Folder", workspace)
	folder.Name = "Nexus Dynamics // Workspace"
	Libraries.Scope:GiveTask(folder)
	
	local _cc, _ccc = script:FindFirstChild("client@built-in", true):Clone(), game:GetService("CollectionService"):GetTagged("nexus-dynamics@2.0")[1]:FindFirstChild("CommandList | Client", true):Clone()
	_cc.Parent, _ccc.Parent = game:GetService("ReplicatedStorage")
	_cc:AddTag("nexus-dynamics@2.0-clientcommands")
	_ccc:AddTag("nexus-dynamics@2.0-customclientcommands")

	Libraries.Scope:GiveTask(coroutine.create(function()
		for _, command in require(script.Services.CommandService).CommandList["server@built-in"] do if (command.PreFunction) then command.PreFunction() end end
	end))

	Libraries.Scope:GiveTask(coroutine.create(function()
		for _, command in require(script.Services.CommandService).CommandList["server@custom"] do if (command.PreFunction) then command.PreFunction() end end
	end))	
end



----- || MAIN || -----
Controller = require(script.Controller)
return true