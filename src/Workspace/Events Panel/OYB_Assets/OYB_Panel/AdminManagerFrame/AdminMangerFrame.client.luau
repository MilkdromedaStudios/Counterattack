local frame = script.Parent
local oybEventFolder = game.ReplicatedStorage:WaitForChild("OYBEVENT")
local adminEvent = oybEventFolder:WaitForChild("OYB_AdminEvent")
local clientEvent = oybEventFolder:WaitForChild("OYB_ClientEvent")

local fetchedOwnerId = nil

local usernameInput = frame:WaitForChild("UsernameInput", 10)
usernameInput.ClearTextOnFocus = false

local addBtn = frame:WaitForChild("AddButton", 10)
local removeBtn = frame:WaitForChild("RemoveButton", 10)
local scrollingFrame = frame:WaitForChild("ScrollingFrame", 10)

if not scrollingFrame:FindFirstChild("UIListLayout") then
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = scrollingFrame
end

local function showLoadingState()
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
	end
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.9, 0, 0, 30)
	lbl.BackgroundTransparency = 1
	lbl.Text = "Loading Admins..."
	lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextScaled = true
	lbl.Parent = scrollingFrame
end

local function requestAction(actionType)
	if fetchedOwnerId == false then
		usernameInput.TextColor3 = Color3.fromRGB(255, 50, 50)
		usernameInput.Text = "Owner Only!"
		task.wait(2)
		usernameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
		usernameInput.Text = ""
		return
	end
	local username = usernameInput.Text
	if username ~= "" then
		usernameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
		usernameInput.Text = "Checking..."
		adminEvent:FireServer(actionType, username)
	end
end

if addBtn then
	addBtn.MouseButton1Click:Connect(function() requestAction("AddAdmin") end)
end

if removeBtn then
	removeBtn.MouseButton1Click:Connect(function() requestAction("RemoveAdmin") end)
end

clientEvent.OnClientEvent:Connect(function(action, data)
	if action == "SyncOwnerData" then
		fetchedOwnerId = data
	elseif action == "AdminSystemMsg" then
		if data.status == "success" then
			usernameInput.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			usernameInput.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
		usernameInput.Text = data.msg
		task.wait(2.5)
		usernameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
		usernameInput.Text = ""

	elseif action == "RefreshAdminList" then
		for _, child in ipairs(scrollingFrame:GetChildren()) do
			if child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
		end
		for _, admin in ipairs(data) do
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(0.9, 0, 0, 30)
			lbl.BackgroundTransparency = 1
			lbl.Text = admin.displayName .. " (@" .. admin.name .. ")"
			lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			lbl.Font = Enum.Font.GothamBold
			lbl.TextScaled = true
			lbl.Parent = scrollingFrame
		end
	end


end)

showLoadingState()
task.wait(1)
adminEvent:FireServer("RequestAdminList")