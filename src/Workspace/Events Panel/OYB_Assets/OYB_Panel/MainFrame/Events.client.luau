local mainFrame = script.Parent
local oybEventFolder = game.ReplicatedStorage:WaitForChild("OYBEVENT")
local adminEvent = oybEventFolder:WaitForChild("OYB_AdminEvent")
local clientEvent = oybEventFolder:WaitForChild("OYB_ClientEvent")

local eventsScroll = mainFrame:WaitForChild("EventsScroll", 5)
local btnStop = mainFrame:WaitForChild("StopEvent", 5)

eventsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
eventsScroll.ScrollBarThickness = 6
eventsScroll.ClipsDescendants = true

local listLayout = eventsScroll:FindFirstChildOfClass("UIListLayout")
if not listLayout then
	listLayout = Instance.new("UIListLayout")
	listLayout.Parent = eventsScroll
end
listLayout.Padding = UDim.new(0, 8)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

local defaultEvents = {
	{ ID = "Party", DisplayName = "Phonk Event", ButtonColor = Color3.fromRGB(255, 153, 0), TextColor = Color3.fromRGB(255, 255, 255) },
	{ ID = "MemeParty", DisplayName = "MemeParty Event", ButtonColor = Color3.fromRGB(204, 51, 255), TextColor = Color3.fromRGB(255, 255, 255) },
	{ ID = "Taco", DisplayName = "Taco Event", ButtonColor = Color3.fromRGB(255, 218, 170), TextColor = Color3.fromRGB(0, 0, 0) },
	{ ID = "Zombie", DisplayName = "Zombie Event", ButtonColor = Color3.fromRGB(40, 150, 40), TextColor = Color3.fromRGB(255, 255, 255) },
	{ ID = "Space", DisplayName = "Space Event", ButtonColor = Color3.fromRGB(0, 0, 100), TextColor = Color3.fromRGB(255, 255, 255) },
	{ ID = "Anime", DisplayName = "Anime Aura", ButtonColor = Color3.fromRGB(255, 69, 0), TextColor = Color3.fromRGB(255, 255, 255) }
}

local function generateEventButtons(customEventsList)
	for _, child in ipairs(eventsScroll:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local buttonHeight = 45
	local orderCounter = 1

	for _, eventData in ipairs(defaultEvents) do
		local newBtn = Instance.new("TextButton")
		newBtn.Name = eventData.ID .. "Button"
		newBtn.Size = UDim2.new(0.9, 0, 0, buttonHeight) 
		newBtn.LayoutOrder = orderCounter 
		newBtn.BackgroundColor3 = eventData.ButtonColor
		newBtn.Text = eventData.DisplayName
		newBtn.Font = Enum.Font.GothamBlack 
		newBtn.TextColor3 = eventData.TextColor 
		newBtn.TextScaled = true
		newBtn.Visible = true 
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = newBtn
		newBtn.Parent = eventsScroll
		newBtn.MouseButton1Click:Connect(function()
			adminEvent:FireServer("TriggerEvent", eventData.ID)
		end)
		orderCounter = orderCounter + 1
	end

	if customEventsList then
		for _, customData in ipairs(customEventsList) do
			local newBtn = Instance.new("TextButton")
			newBtn.Name = customData.ID .. "Button"
			newBtn.Size = UDim2.new(0.9, 0, 0, buttonHeight) 
			newBtn.LayoutOrder = orderCounter 
			newBtn.BackgroundColor3 = Color3.fromRGB(customData.Color.R, customData.Color.G, customData.Color.B)
			newBtn.Text = customData.DisplayName
			newBtn.Font = Enum.Font.GothamBlack 
			newBtn.TextColor3 = Color3.fromRGB(255, 255, 255) 
			newBtn.TextScaled = true
			newBtn.Visible = true 
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = newBtn
			newBtn.Parent = eventsScroll
			newBtn.MouseButton1Click:Connect(function()
				adminEvent:FireServer("TriggerEvent", customData)
			end)
			orderCounter = orderCounter + 1
		end
	end


end

generateEventButtons()

local ogStopText = btnStop and btnStop.Text or "Stop"
local ogStopColor = btnStop and btnStop.BackgroundColor3 or Color3.fromRGB(255, 50, 50)
local activeCooldownTicket = 0

clientEvent.OnClientEvent:Connect(function(action, data)
	if action == "SyncCustomEvents" then
		generateEventButtons(data)
	elseif action == "AdminSystemMsg" then
		if data.status == "error" and data.msg == "Cooldown" then
			activeCooldownTicket = activeCooldownTicket + 1
			local myTicket = activeCooldownTicket
			local remaining = math.ceil(data.time)
			btnStop.BackgroundColor3 = Color3.fromRGB(255, 120, 0)
			task.spawn(function()
				while remaining > 0 and activeCooldownTicket == myTicket do
					btnStop.Text = "Wait (" .. remaining .. "s)"
					task.wait(1)
					remaining = remaining - 1
				end
				if activeCooldownTicket == myTicket then
					btnStop.Text = ogStopText
					btnStop.BackgroundColor3 = ogStopColor
				end
			end)
		end
	end
end)

if btnStop then
	btnStop.MouseButton1Click:Connect(function()
		adminEvent:FireServer("TriggerEvent", "Stop")
	end)
end