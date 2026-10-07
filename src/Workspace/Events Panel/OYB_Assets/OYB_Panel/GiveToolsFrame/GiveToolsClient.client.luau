local frame = script.Parent
local oybEventFolder = game.ReplicatedStorage:WaitForChild("OYBEVENT")
local adminEvent = oybEventFolder:WaitForChild("OYB_AdminEvent")
local clientEvent = oybEventFolder:WaitForChild("OYB_ClientEvent")
local eventToolsFolder = oybEventFolder:WaitForChild("EventTools")

local fetchedOwnerId = nil

local targetBtn = frame:FindFirstChild("TargetBtn")
local targetScroll = frame:FindFirstChild("TargetScroll")
local targetInput = frame:FindFirstChild("TargetInput")
local toolBtn = frame:FindFirstChild("ToolBtn")
local toolScroll = frame:FindFirstChild("ToolScroll")
local giveBtn = frame:FindFirstChild("GiveBtn")
local removeBtn = frame:FindFirstChild("RemoveBtn")
local checkPlayerBtn = frame:FindFirstChild("CheckPlayerBtn")
local offlineToggleBtn = frame:FindFirstChild("OfflineToggleBtn")
local allToolsToggleBtn = frame:FindFirstChild("AllToolsToggleBtn")
local playerInfoScroll = frame:FindFirstChild("PlayerInfoScroll")

local function autoScaleBtn(btn)
	if btn then
		btn.TextScaled = true
		btn.TextWrapped = true
	end
end

autoScaleBtn(giveBtn)
autoScaleBtn(removeBtn)
autoScaleBtn(checkPlayerBtn)

local currentTargetMode = "All"
local selectedToolId = ""
local isOfflineEnabled = false
local isAllToolsEnabled = false

local function fixScroll(scroll)
	if not scroll then return end
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ScrollBarThickness = 6
	scroll.Visible = false
	if not scroll:FindFirstChildOfClass("UIListLayout") then
		local layout = Instance.new("UIListLayout", scroll)
		layout.Padding = UDim.new(0, 5)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
end

fixScroll(targetScroll)
fixScroll(toolScroll)
fixScroll(playerInfoScroll)

local function createFromTemplate(parentScroll, text, onClickCallback)
	local template = parentScroll:FindFirstChild("Template")
	if not template then return end
	local btn = template:Clone()
	btn.Name = text
	btn.Text = "  " .. text
	btn.Visible = true
	btn.Parent = parentScroll
	btn.MouseButton1Click:Connect(onClickCallback)
	return btn
end

if offlineToggleBtn then
	offlineToggleBtn.Text = "No"
	offlineToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
	offlineToggleBtn.Font = Enum.Font.GothamBlack
	offlineToggleBtn.TextScaled = true
	offlineToggleBtn.MouseButton1Click:Connect(function()
		isOfflineEnabled = not isOfflineEnabled
		if isOfflineEnabled then
			offlineToggleBtn.Text = "Yes"
			offlineToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
		else
			offlineToggleBtn.Text = "No"
			offlineToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
		end
	end)
end

if allToolsToggleBtn then
	allToolsToggleBtn.Text = "No"
	allToolsToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
	allToolsToggleBtn.Font = Enum.Font.GothamBlack
	allToolsToggleBtn.TextScaled = true
	allToolsToggleBtn.MouseButton1Click:Connect(function()
		isAllToolsEnabled = not isAllToolsEnabled
		if isAllToolsEnabled then
			allToolsToggleBtn.Text = "Yes"
			allToolsToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
		else
			allToolsToggleBtn.Text = "No"
			allToolsToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
		end
	end)
end

if targetBtn and targetScroll then
	targetBtn.Text = "All"
	if targetInput then targetInput.Visible = false end
	targetBtn.MouseButton1Click:Connect(function()
		targetScroll.Visible = not targetScroll.Visible
		if toolScroll then toolScroll.Visible = false end
		if playerInfoScroll then playerInfoScroll.Visible = false end
	end)
	createFromTemplate(targetScroll, "All Players", function()
		currentTargetMode = "All"
		targetBtn.Text = "All"
		targetScroll.Visible = false
		if targetInput then targetInput.Visible = false end
	end)
	createFromTemplate(targetScroll, "Custom Player", function()
		currentTargetMode = "Custom"
		targetBtn.Text = "Custom"
		targetScroll.Visible = false
		if targetInput then targetInput.Visible = true end
	end)
end

local function refreshToolScroll()
	if not toolScroll then return end
	for _, child in ipairs(toolScroll:GetChildren()) do
		if child.Name ~= "Template" and not child:IsA("UIListLayout") then child:Destroy() end
	end
	for _, tool in ipairs(eventToolsFolder:GetChildren()) do
		if tool:IsA("Tool") then
			createFromTemplate(toolScroll, tool.Name, function()
				selectedToolId = tool.Name
				toolBtn.Text = tool.Name
				toolScroll.Visible = false
			end)
		end
	end
end
refreshToolScroll()

if toolBtn and toolScroll then
	toolBtn.Text = "Select"
	toolBtn.MouseButton1Click:Connect(function()
		refreshToolScroll()
		toolScroll.Visible = not toolScroll.Visible
		if targetScroll then targetScroll.Visible = false end
		if playerInfoScroll then playerInfoScroll.Visible = false end
	end)
end

local function getRequestData()
	local tName = (currentTargetMode == "Custom" and targetInput) and targetInput.Text or "All"
	local tValue = selectedToolId
	if isAllToolsEnabled then tValue = "ALL_TOOLS" end
	return { TargetType = currentTargetMode, TargetName = tName, ToolValue = tValue, IncludeOffline = isOfflineEnabled }
end

if giveBtn then
	local originalGiveText = giveBtn.Text
	local originalGiveColor = giveBtn.BackgroundColor3
	giveBtn.MouseButton1Click:Connect(function()
		-- 🛠️ التعديل الثالث: التأكد بشكل صحيح من الصلاحية هنا للوحة التولز
		if fetchedOwnerId == false then
			giveBtn.Text = "Owner Only!"
			giveBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			task.wait(1.5)
			giveBtn.Text = originalGiveText
			giveBtn.BackgroundColor3 = originalGiveColor
			return
		end
		giveBtn.Text = "Wait..."
		adminEvent:FireServer("ToolAction", {Action = "Give", Data = getRequestData()})
		task.wait(1)
		giveBtn.Text = originalGiveText
	end)
end

if removeBtn then
	local removeClicks = 0
	local removeTicket = 0
	local originalText = "Remove"
	local originalColor = removeBtn.BackgroundColor3
	removeBtn.MouseButton1Click:Connect(function()
		-- 🛠️ التعديل الرابع: نفس الشيء لزر إزالة التولز
		if fetchedOwnerId == false then
			removeBtn.Text = "Owner Only!"
			removeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			task.wait(1.5)
			removeBtn.Text = originalText
			removeBtn.BackgroundColor3 = originalColor
			return
		end
		if currentTargetMode == "All" and isAllToolsEnabled then
			removeBtn.Text = "Error: Need Custom!"
			removeBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
			task.wait(2)
			removeBtn.Text = originalText
			removeBtn.BackgroundColor3 = originalColor
			return
		end
		local requiredClicks = (currentTargetMode == "All") and 3 or 1
		if removeClicks < requiredClicks then
			removeClicks = removeClicks + 1
			removeTicket = removeTicket + 1
			local myTicket = removeTicket
			removeBtn.Text = "Sure? (" .. removeClicks .. "/" .. requiredClicks .. ")"
			removeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			task.delay(3, function()
				if removeTicket == myTicket then
					removeClicks = 0
					removeBtn.Text = originalText
					removeBtn.BackgroundColor3 = originalColor
				end
			end)
		else
			removeClicks = 0
			removeTicket = removeTicket + 1
			removeBtn.Text = "Wait..."
			adminEvent:FireServer("ToolAction", {Action = "Remove", Data = getRequestData()})
			task.wait(1)
			removeBtn.Text = originalText
			removeBtn.BackgroundColor3 = originalColor
		end
	end)
end

if checkPlayerBtn then
	local ogCheckText = checkPlayerBtn.Text
	local ogCheckColor = checkPlayerBtn.BackgroundColor3
	checkPlayerBtn.MouseButton1Click:Connect(function()
		if playerInfoScroll and playerInfoScroll.Visible then
			playerInfoScroll.Visible = false
			checkPlayerBtn.Text = ogCheckText
			checkPlayerBtn.BackgroundColor3 = ogCheckColor
			return
		end
		if currentTargetMode == "All" then
			checkPlayerBtn.Text = "Error: Select 1!"
			task.delay(2, function() checkPlayerBtn.Text = ogCheckText end)
			return
		end
		if targetInput and targetInput.Text ~= "" then
			checkPlayerBtn.Text = "Wait..."
			if targetScroll then targetScroll.Visible = false end
			if toolScroll then toolScroll.Visible = false end
			if playerInfoScroll then playerInfoScroll.Visible = true end
			adminEvent:FireServer("ToolAction", {Action = "CheckPlayer", TargetName = targetInput.Text})
			task.wait(1)
			checkPlayerBtn.Text = "Close Info"
			checkPlayerBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		end
	end)
end

clientEvent.OnClientEvent:Connect(function(action, data)
	if action == "SyncOwnerData" then
		fetchedOwnerId = data
	elseif action == "AdminSystemMsg" then
		if data.msg:find("Owner") then
			local ogGive = giveBtn and giveBtn.Text or "Give"
			local ogRemove = removeBtn and removeBtn.Text or "Remove"
			if giveBtn then giveBtn.Text = "Owner Only!" giveBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50) end
			if removeBtn then removeBtn.Text = "Owner Only!" removeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50) end
			task.wait(2)
			if giveBtn then giveBtn.Text = ogGive giveBtn.BackgroundColor3 = Color3.fromRGB(45, 150, 45) end
			if removeBtn then removeBtn.Text = ogRemove removeBtn.BackgroundColor3 = Color3.fromRGB(150, 45, 45) end
		end
	elseif action == "RefreshPlayerInfo" then
		if not playerInfoScroll then return end
		for _, child in ipairs(playerInfoScroll:GetChildren()) do
			if child.Name ~= "PlayerToolTemplate" and not child:IsA("UIListLayout") then child:Destroy() end
		end
		local template = playerInfoScroll:FindFirstChild("PlayerToolTemplate")
		if not template then return end
		local targetUser = data.PlayerName
		local tools = data.Tools
		if not tools or next(tools) == nil then
			local noToolBtn = template:Clone()
			noToolBtn.Name = "NoTools"
			noToolBtn.Visible = true
			local lbl = noToolBtn:FindFirstChild("InfoLbl")
			if lbl then lbl.Text = "No Tools." end
			local delBtn = noToolBtn:FindFirstChild("DelBtn")
			if delBtn then delBtn.Visible = false end
			noToolBtn.Parent = playerInfoScroll
			return
		end
		for toolKey, toolData in pairs(tools) do
			local actualToolId = type(toolData) == "table" and toolData.id or toolKey
			local itemFrame = template:Clone()
			itemFrame.Name = toolKey
			itemFrame.Visible = true
			local infoLbl = itemFrame:FindFirstChild("InfoLbl")
			if infoLbl then
				infoLbl.Text = toolKey
				infoLbl.TextScaled = true
			end
			local delBtn = itemFrame:FindFirstChild("DelBtn")
			if delBtn then
				local isConfirmingDel = false
				local delTicket = 0
				delBtn.MouseButton1Click:Connect(function()
					if not isConfirmingDel then
						isConfirmingDel = true
						delTicket = delTicket + 1
						local myTicket = delTicket
						delBtn.Text = "Sure?"
						delBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
						task.delay(3, function()
							if isConfirmingDel and delTicket == myTicket then
								isConfirmingDel = false
								delBtn.Text = "Del"
								delBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
							end
						end)
					else
						local cleanTarget = targetUser:gsub(" %(.+%)", "")
						adminEvent:FireServer("ToolAction", {
							Action = "Remove",
							Data = {
								TargetType = "Custom",
								TargetName = cleanTarget,
								ToolValue = actualToolId,
								IncludeOffline = true
							}
						})
						itemFrame:Destroy()
					end
				end)
			end
			itemFrame.Parent = playerInfoScroll
		end
	end
end)