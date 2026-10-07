local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local UserService = game:GetService("UserService")
local TextService = game:GetService("TextService")

local MainStore = DataStoreService:GetDataStore("OYBEVENT")

local ADMIN_KEY = "Admins_List"
local CUSTOM_EVENTS_KEY = "Custom_Events"
local REGISTERED_PLAYERS_KEY = "All_Players_List"

local Settings = require(ReplicatedStorage:WaitForChild("Settings"))
local OWNER_ID = Settings.OwnerId

local oybEventFolder = ReplicatedStorage:WaitForChild("OYBEVENT")
local adminEvent = oybEventFolder:WaitForChild("OYB_AdminEvent")
local clientEvent = oybEventFolder:WaitForChild("OYB_ClientEvent")
local oybPanel = ServerStorage:WaitForChild("OYB_Panel")
local eventToolsFolder = oybEventFolder:WaitForChild("EventTools")

-- 🛠️ التعديل الأول: نقل الأدوات الحقيقية لـ ServerStorage عشان تشتغل سكربتاتها تمام
local realToolsFolder = Instance.new("Folder")
realToolsFolder.Name = "RealEventTools"
realToolsFolder.Parent = ServerStorage

for _, tool in ipairs(eventToolsFolder:GetChildren()) do
	if tool:IsA("Tool") then
		local realTool = tool:Clone()
		realTool.Parent = realToolsFolder

		-- تفريغ سكربتات السيرفر من نسخة الواجهة عشان الأمان
		for _, desc in ipairs(tool:GetDescendants()) do
			if desc:IsA("Script") and desc.RunContext == Enum.RunContext.Legacy then
				desc:Destroy()
			end
		end
	end
end
-- 🛠️ نهاية التعديل

local extraAdmins = {}
local savedCustomEvents = {}
local currentActiveEvent = nil
local currentEventStartTime = 0
local isDataLoaded = false

local playerToolsCache = {}
local allRegisteredPlayers = {}

local activePollId = 0
local pollVotes = {Option1 = 0, Option2 = 0}
local lastGlobalEventTime = 0
local globalCooldownEnd = 0
local votedPlayers = {}
local announcementCooldowns = {}
local pollCooldowns = {}

local function filterText(text, userId)
	local success, result = pcall(function()
		return TextService:FilterStringAsync(text, userId):GetNonChatStringForBroadcastAsync()
	end)
	if success and result then return result end
	return "###"
end

--[[
	MAY THIS USER HAVE THE PANEL?

	Deferred to `ServerScriptService.Managers.OwnerPerks.CanUseControlPanels`, which is the
	one gate the whole game uses for control panels.

	WHAT CHANGED. This used to be `userId == OWNER_ID or userId is in extraAdmins`.
	`extraAdmins` is loaded out of a DataStore by the panel's own admin manager, so anyone
	added once kept the panel in every session afterwards, and nothing in the repository
	recorded who that was. The list is still read and still displayed by the admin manager
	frame -- removing it would break that UI -- it just no longer grants access.

	`Settings.OwnerId` is kept as a fallback for when OwnerPerks cannot be required (this
	asset is vendored and may be dropped into a place that does not have it). Falling back
	to a single hardcoded id is the strictest thing available, not the loosest.
]]
local ownerPerksModule = nil
do
	local managers = game:GetService("ServerScriptService"):FindFirstChild("Managers")
	local candidate = managers and managers:FindFirstChild("OwnerPerks")
	if candidate then
		local ok, result = pcall(require, candidate)
		if ok then
			ownerPerksModule = result
		else
			warn("[OYB] Couldn't load OwnerPerks; falling back to Settings.OwnerId only. " .. tostring(result))
		end
	end
end

local function canAccess(userId)
	if ownerPerksModule and ownerPerksModule.CanUseControlPanels then
		-- `CanUseControlPanels` wants a Player, not an id.
		local plr = Players:GetPlayerByUserId(userId)
		if plr then
			return ownerPerksModule.CanUseControlPanels(plr) == true
		end
	end

	return userId == OWNER_ID
end

local function givePanel(player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui and not playerGui:FindFirstChild("OYB_Panel") then
		local panelClone = oybPanel:Clone()
		panelClone.Parent = playerGui
	end
end

local function removePanel(player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		local ui = playerGui:FindFirstChild("OYB_Panel")
		if ui then ui:Destroy() end
	end
end

local function updateAdminLists()
	for _, p in ipairs(Players:GetPlayers()) do
		if canAccess(p.UserId) then
			givePanel(p)
			clientEvent:FireClient(p, "RefreshAdminList", extraAdmins)
			clientEvent:FireClient(p, "SyncCustomEvents", savedCustomEvents)
			clientEvent:FireClient(p, "SyncOwnerData", p.UserId == OWNER_ID)
		else
			removePanel(p)
		end
	end
end

local function getPlayerNameSmart(playerName)
	local lowerName = string.lower(playerName)
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == lowerName or string.sub(string.lower(p.Name), 1, #lowerName) == lowerName then
			return p.Name
		end
	end
	local success, id = pcall(function() return Players:GetUserIdFromNameAsync(playerName) end)
	if success then
		local s2, info = pcall(function() return UserService:GetUserInfosByUserIdsAsync({id}) end)
		if s2 and info and info[1] then return info[1].Username end
		return playerName
	end
	return nil
end

local function loadRealTool(toolId)
	local t = realToolsFolder:FindFirstChild(toolId) -- 🛠️ تعديل: نسحب الأداة من المجلد الحقيقي
	if t then return t:Clone() end
	return nil
end

local function physicallyGiveTool(player, toolId)
	if toolId == "ALL_TOOLS" then
		local givenAny = false
		for _, toolPart in ipairs(realToolsFolder:GetChildren()) do -- 🛠️ تعديل
			if toolPart:IsA("Tool") then
				local backpack = player:FindFirstChild("Backpack")
				local char = player.Character
				if not (backpack and backpack:FindFirstChild(toolPart.Name)) and not (char and char:FindFirstChild(toolPart.Name)) then
					local newTool = toolPart:Clone()
					task.defer(function()
						if backpack then newTool.Parent = backpack end
						local sg = player:FindFirstChild("StarterGear")
						if sg then toolPart:Clone().Parent = sg end
					end)
					if not playerToolsCache[player.Name] then playerToolsCache[player.Name] = {} end
					playerToolsCache[player.Name][toolPart.Name] = { id = toolPart.Name }
					givenAny = true
				end
			end
		end
		return givenAny
	end

	local backpack = player:FindFirstChild("Backpack")
	local starterGear = player:FindFirstChild("StarterGear")
	local char = player.Character

	if backpack and backpack:FindFirstChild(toolId) then return false end
	if char and char:FindFirstChild(toolId) then return false end

	local newTool = loadRealTool(toolId)
	if newTool then
		task.defer(function()
			if backpack then newTool.Parent = backpack end
			if starterGear then 
				local sgClone = newTool:Clone()
				sgClone.Parent = starterGear 
			end
		end)
		if not playerToolsCache[player.Name] then playerToolsCache[player.Name] = {} end
		playerToolsCache[player.Name][toolId] = { id = toolId }
		return true
	end
	return false
end

local function physicallyRemoveTool(player, toolId)
	local backpack = player:FindFirstChild("Backpack")
	local starterGear = player:FindFirstChild("StarterGear")
	local char = player.Character
	local removed = false

	if toolId == "ALL_TOOLS" then
		if backpack then backpack:ClearAllChildren() removed = true end
		if starterGear then starterGear:ClearAllChildren() removed = true end
		if char then for _, t in ipairs(char:GetChildren()) do if t:IsA("Tool") then t:Destroy() removed = true end end end
		playerToolsCache[player.Name] = {}
		return removed
	end

	if backpack then for _, t in ipairs(backpack:GetChildren()) do if t.Name == toolId then t:Destroy() removed = true end end end
	if char then for _, t in ipairs(char:GetChildren()) do if t:IsA("Tool") and t.Name == toolId then t:Destroy() removed = true end end end
	if starterGear then for _, t in ipairs(starterGear:GetChildren()) do if t.Name == toolId then t:Destroy() removed = true end end end

	if playerToolsCache[player.Name] then playerToolsCache[player.Name][toolId] = nil end
	return removed
end

local function executeLocalToolAction(action, reqData)
	local targets = {}
	if reqData.TargetType == "All" then
		targets = Players:GetPlayers()
	else
		local targetName = getPlayerNameSmart(reqData.TargetName)
		if targetName then
			local p = Players:FindFirstChild(targetName)
			if p then table.insert(targets, p) end
		end
	end

	for _, p in ipairs(targets) do
		if action == "Give" then
			physicallyGiveTool(p, reqData.ToolValue)
		elseif action == "Remove" or action == "ForceRemove" then
			physicallyRemoveTool(p, reqData.ToolValue)
		end
	end
end

local function handleOfflineDataStore(action, reqData)
	local targetNames = {}
	if reqData.TargetType == "Custom" then
		local tName = getPlayerNameSmart(reqData.TargetName)
		if tName then table.insert(targetNames, tName) end
	elseif reqData.TargetType == "All" then
		targetNames = allRegisteredPlayers
	end

	for _, tName in ipairs(targetNames) do
		local success, savedTools = pcall(function() return MainStore:GetAsync("Tools_" .. tName) end)
		savedTools = savedTools or {}

		if action == "Give" then
			if reqData.ToolValue == "ALL_TOOLS" then
				for _, toolPart in ipairs(realToolsFolder:GetChildren()) do -- 🛠️ تعديل
					if toolPart:IsA("Tool") then
						savedTools[toolPart.Name] = { id = toolPart.Name }
					end
				end
			else
				savedTools[reqData.ToolValue] = { id = reqData.ToolValue }
			end
		elseif action == "Remove" or action == "ForceRemove" then
			if reqData.ToolValue == "ALL_TOOLS" then
				savedTools = {}
			else
				savedTools[reqData.ToolValue] = nil
			end
		end
		pcall(function() MainStore:SetAsync("Tools_" .. tName, savedTools) end)
	end
end

local function processToolAction(admin, actionData)
	local action = actionData.Action

	if action == "CheckPlayer" then
		local rName = getPlayerNameSmart(actionData.TargetName)
		if rName then
			local targetPlayer = Players:FindFirstChild(rName)
			if targetPlayer and playerToolsCache[targetPlayer.Name] and next(playerToolsCache[targetPlayer.Name]) ~= nil then
				clientEvent:FireClient(admin, "RefreshPlayerInfo", {PlayerName = targetPlayer.Name, Tools = playerToolsCache[targetPlayer.Name]})
				clientEvent:FireClient(admin, "AdminSystemMsg", {status = "success", msg = "Loaded info"})
			else
				task.spawn(function()
					local s2, offlineTools = pcall(function() return MainStore:GetAsync("Tools_" .. rName) end)
					if s2 and offlineTools and type(offlineTools) == "table" and next(offlineTools) ~= nil then
						clientEvent:FireClient(admin, "RefreshPlayerInfo", {PlayerName = rName .. " (Offline)", Tools = offlineTools})
						clientEvent:FireClient(admin, "AdminSystemMsg", {status = "success", msg = "Loaded Offline Info"})
					else
						clientEvent:FireClient(admin, "RefreshPlayerInfo", {PlayerName = rName, Tools = {}})
						clientEvent:FireClient(admin, "AdminSystemMsg", {status = "error", msg = "No tools found!"})
					end
				end)
			end
		else
			clientEvent:FireClient(admin, "AdminSystemMsg", {status = "error", msg = "Player not found!"})
		end
		return
	end

	local reqData = actionData.Data
	if not reqData then return end

	local finalTargetName = reqData.TargetName
	if reqData.TargetType == "Custom" then
		local rName = getPlayerNameSmart(reqData.TargetName)
		if rName then finalTargetName = rName end
		reqData.TargetName = finalTargetName 
	end

	executeLocalToolAction(action, reqData)
	pcall(function() MessagingService:PublishAsync("OYB_CrossServerTools", {Action = action, Data = reqData, SenderJobId = game.JobId}) end)

	if reqData.IncludeOffline then
		task.spawn(function() handleOfflineDataStore(action, reqData) end)
	end

	clientEvent:FireClient(admin, "AdminSystemMsg", {status = "success", msg = "Command Executed!"})
end

task.spawn(function()
	local retries = 0
	while retries < 5 and not isDataLoaded do
		local success, result, customResult, playersResult = pcall(function()
			return MainStore:GetAsync(ADMIN_KEY), MainStore:GetAsync(CUSTOM_EVENTS_KEY), MainStore:GetAsync(REGISTERED_PLAYERS_KEY)
		end)

		if success then
			if result then extraAdmins = result end
			if customResult then savedCustomEvents = customResult end
			if playersResult then allRegisteredPlayers = playersResult end
			isDataLoaded = true
			updateAdminLists()
			break
		else
			retries = retries + 1
			task.wait(3)
		end
	end
end)

local function saveAllData()
	if not isDataLoaded then return end
	pcall(function()
		MainStore:SetAsync(ADMIN_KEY, extraAdmins)
		MainStore:SetAsync(CUSTOM_EVENTS_KEY, savedCustomEvents)
		MainStore:SetAsync(REGISTERED_PLAYERS_KEY, allRegisteredPlayers)
		for playerName, tools in pairs(playerToolsCache) do
			MainStore:SetAsync("Tools_" .. playerName, tools)
		end
	end)
end

game:BindToClose(function() saveAllData() end)

Players.PlayerAdded:Connect(function(player)
	if not table.find(allRegisteredPlayers, player.Name) then
		table.insert(allRegisteredPlayers, player.Name)
		pcall(function() MainStore:SetAsync(REGISTERED_PLAYERS_KEY, allRegisteredPlayers) end)
	end

	if isDataLoaded and canAccess(player.UserId) then givePanel(player) end

	task.spawn(function()
		local success, savedTools = pcall(function() return MainStore:GetAsync("Tools_" .. player.Name) end)
		if success and savedTools then
			playerToolsCache[player.Name] = savedTools
			for toolName, toolData in pairs(savedTools) do
				local tId = type(toolData) == "table" and toolData.id or toolName
				physicallyGiveTool(player, tId)
			end
		else
			playerToolsCache[player.Name] = {}
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if playerToolsCache[player.Name] then
		pcall(function() MainStore:SetAsync("Tools_" .. player.Name, playerToolsCache[player.Name]) end)
		playerToolsCache[player.Name] = nil
	end
end)

local function triggerEventSystem(eventData, isFromCrossServer, msgTimestamp)
	local currentTimestamp = msgTimestamp or os.time()
	if isFromCrossServer then
		if currentTimestamp < lastGlobalEventTime then return end
		lastGlobalEventTime = currentTimestamp
	else
		lastGlobalEventTime = os.time()
	end

	if eventData == "Stop" then
		currentActiveEvent = nil 
		clientEvent:FireAllClients("PlayEvent", "Stop")
		if not isFromCrossServer then pcall(function() MessagingService:PublishAsync("OYB_GlobalEvents", { SenderJobId = game.JobId, Data = "Stop", Timestamp = lastGlobalEventTime }) end) end
		return
	end

	currentActiveEvent = eventData 
	currentEventStartTime = workspace.DistributedGameTime
	task.spawn(function() clientEvent:FireAllClients("DivineSequence", { eventData = eventData }) end)
	if not isFromCrossServer then pcall(function() MessagingService:PublishAsync("OYB_GlobalEvents", { SenderJobId = game.JobId, Data = eventData, Timestamp = lastGlobalEventTime }) end) end
end

adminEvent.OnServerEvent:Connect(function(player, action, data)
	if type(action) ~= "string" then return end

	if action == "PlayerReady" then
		if currentActiveEvent then
			local timeElapsed = workspace.DistributedGameTime - currentEventStartTime
			clientEvent:FireClient(player, "SyncEvent", { eventData = currentActiveEvent, timeElapsed = timeElapsed })
		end
		if isDataLoaded then
			clientEvent:FireClient(player, "SyncCustomEvents", savedCustomEvents)
		end
		return
	end

	if action == "SubmitVote" then
		if type(data) ~= "table" or type(data.PollId) ~= "number" then return end
		if data.PollId == activePollId and not votedPlayers[player.UserId] then
			votedPlayers[player.UserId] = true
			if data.Choice == 1 then pollVotes.Option1 = pollVotes.Option1 + 1
			elseif data.Choice == 2 then pollVotes.Option2 = pollVotes.Option2 + 1 end
			local voteData = {PollId = activePollId, Votes1 = pollVotes.Option1, Votes2 = pollVotes.Option2}
			clientEvent:FireAllClients("UpdatePollVotes", voteData)
			pcall(function() MessagingService:PublishAsync("OYB_GlobalPollVotes", { SenderJobId = game.JobId, Data = voteData }) end)
		end
		return
	end

	if not canAccess(player.UserId) then return end

	if action == "AutoStop" then 
		triggerEventSystem("Stop", false)
		return 
	end

	if action == "ToolAction" then
		if player.UserId ~= OWNER_ID then
			clientEvent:FireClient(player, "AdminSystemMsg", {status = "error", msg = "Owner Only!"})
			return
		end
		if type(data) ~= "table" then return end
		processToolAction(player, data)
		return
	end

	if action == "SendAnnouncement" then
		if type(data) ~= "string" then return end
		local now = os.time()
		if announcementCooldowns[player.UserId] and now - announcementCooldowns[player.UserId] < 5 then return end
		announcementCooldowns[player.UserId] = now
		local filteredMsg = filterText(data, player.UserId)
		local prefix = player.UserId == OWNER_ID and "<font color='#ff3333'><b>(Owner)</b></font> " or ""
		local nameColor = player.UserId == OWNER_ID and "#ffaa00" or "#00aaff"
		local finalMessage = string.format("%s<font color='%s'><b>%s:</b></font> <font color='#ffffff'>%s</font>", prefix, nameColor, player.DisplayName, filteredMsg)
		clientEvent:FireAllClients("ShowAnnouncement", finalMessage)
		pcall(function() MessagingService:PublishAsync("OYB_GlobalAnnouncements", { SenderJobId = game.JobId, Data = finalMessage }) end)

	elseif action == "SendPoll" then
		if type(data) ~= "table" then return end
		local now = os.time()
		if pollCooldowns[player.UserId] and now - pollCooldowns[player.UserId] < 10 then return end
		pollCooldowns[player.UserId] = now
		activePollId = activePollId + 1
		pollVotes = {Option1 = 0, Option2 = 0}
		votedPlayers = {}
		data.Duration = math.clamp(tonumber(data.Duration) or 30, 5, 120)
		data.PollId = activePollId
		data.SenderName = player.DisplayName
		data.IsOwner = (player.UserId == OWNER_ID)

		data.Question = filterText(data.Question, player.UserId)
		data.Choice1 = filterText(data.Choice1, player.UserId)
		data.Choice2 = filterText(data.Choice2, player.UserId)

		clientEvent:FireAllClients("StartPoll", data)
		pcall(function() MessagingService:PublishAsync("OYB_GlobalPolls", { SenderJobId = game.JobId, Data = data }) end)

	elseif action == "TriggerEvent" then
		if type(data) ~= "string" and type(data) ~= "table" then return end
		if data ~= "Stop" then
			if os.time() < globalCooldownEnd then
				local remaining = globalCooldownEnd - os.time()
				clientEvent:FireClient(player, "AdminSystemMsg", {status = "error", msg = "Cooldown", time = remaining})
				return
			end
			globalCooldownEnd = os.time() + 3
		end
		triggerEventSystem(data, false)

	elseif action == "CreateCustomEvent" then
		if player.UserId ~= OWNER_ID then return end
		if type(data) ~= "table" then return end
		data.DisplayName = filterText(data.DisplayName, player.UserId)
		table.insert(savedCustomEvents, data)
		saveAllData(); updateAdminLists()
		pcall(function() MessagingService:PublishAsync("OYB_CustomSync", { SenderJobId = game.JobId, Data = savedCustomEvents }) end)
		clientEvent:FireClient(player, "EventCreationResult", {success = true})

	elseif action == "DeleteCustomEvent" then
		if player.UserId ~= OWNER_ID then return end
		if data == nil then return end
		for i, eventData in ipairs(savedCustomEvents) do
			if eventData.ID == data then
				table.remove(savedCustomEvents, i)
				saveAllData(); updateAdminLists()
				pcall(function() MessagingService:PublishAsync("OYB_CustomSync", { SenderJobId = game.JobId, Data = savedCustomEvents }) end)
				break
			end
		end

	elseif action == "AddAdmin" then
		if player.UserId ~= OWNER_ID then return end
		if type(data) ~= "string" then return end
		local targetId, realName = getPlayerNameSmart(data)
		if targetId then
			local success, id = pcall(function() return Players:GetUserIdFromNameAsync(targetId) end)
			if success and id and not canAccess(id) then
				local dName = targetId
				pcall(function()
					local info = UserService:GetUserInfosByUserIdsAsync({id})
					if info and info[1] then dName = info[1].DisplayName end
				end)
				table.insert(extraAdmins, {id = id, name = targetId, displayName = dName})
				clientEvent:FireClient(player, "AdminSystemMsg", {status = "success", msg = "Added: " .. dName})
				saveAllData(); updateAdminLists()
				pcall(function() MessagingService:PublishAsync("OYB_AdminSync", { SenderJobId = game.JobId, Data = extraAdmins }) end)
			end
		end
	elseif action == "RemoveAdmin" then
		if player.UserId ~= OWNER_ID then return end
		if type(data) ~= "string" then return end
		local foundName = getPlayerNameSmart(data) or data
		for i, admin in ipairs(extraAdmins) do
			if admin.name:lower() == foundName:lower() then
				table.remove(extraAdmins, i)
				clientEvent:FireClient(player, "AdminSystemMsg", {status = "success", msg = "Removed: " .. admin.name})
				saveAllData(); updateAdminLists()
				pcall(function() MessagingService:PublishAsync("OYB_AdminSync", { SenderJobId = game.JobId, Data = extraAdmins }) end)
				break
			end
		end
	elseif action == "RequestAdminList" then
		if isDataLoaded then clientEvent:FireClient(player, "RefreshAdminList", extraAdmins) end
	end
end)

pcall(function()
	MessagingService:SubscribeAsync("OYB_CrossServerTools", function(msg)
		if msg.Data.SenderJobId ~= game.JobId then executeLocalToolAction(msg.Data.Action, msg.Data.Data) end
	end)
	MessagingService:SubscribeAsync("OYB_GlobalEvents", function(msg)
		if msg.Data.SenderJobId ~= game.JobId then triggerEventSystem(msg.Data.Data, true, msg.Data.Timestamp) end
	end)
	MessagingService:SubscribeAsync("OYB_GlobalAnnouncements", function(msg)
		if msg.Data.SenderJobId ~= game.JobId then clientEvent:FireAllClients("ShowAnnouncement", msg.Data.Data) end
	end)
	MessagingService:SubscribeAsync("OYB_GlobalPolls", function(msg)
		if msg.Data.SenderJobId ~= game.JobId then
			activePollId = msg.Data.Data.PollId; pollVotes = {Option1 = 0, Option2 = 0}
			clientEvent:FireAllClients("StartPoll", msg.Data.Data)
		end
	end)
	MessagingService:SubscribeAsync("OYB_GlobalPollVotes", function(msg)
		if msg.Data.SenderJobId ~= game.JobId and msg.Data.Data.PollId == activePollId then
			pollVotes.Option1 = math.max(pollVotes.Option1, msg.Data.Data.Votes1)
			pollVotes.Option2 = math.max(pollVotes.Option2, msg.Data.Data.Votes2)
			clientEvent:FireAllClients("UpdatePollVotes", msg.Data.Data)
		end
	end)
	MessagingService:SubscribeAsync("OYB_AdminSync", function(msg)
		if msg.Data.SenderJobId ~= game.JobId then extraAdmins = msg.Data.Data; updateAdminLists() end
	end)
	MessagingService:SubscribeAsync("OYB_CustomSync", function(msg)
		if msg.Data.SenderJobId ~= game.JobId then savedCustomEvents = msg.Data.Data; updateAdminLists() end
	end)
end)