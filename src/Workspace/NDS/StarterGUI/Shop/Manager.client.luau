local Player=game:GetService("Players").LocalPlayer
local Template=script:WaitForChild("Template")
--[[]]--
local UI=script.Parent
local MainFrame=UI:WaitForChild("Frame")
local Toggle=UI:WaitForChild("Toggle")
--[[]]--
local TweenService=game:GetService("TweenService")
local Debounce=false
--[[]]--
local function CloseUI()
	local Tween=TweenService:Create(MainFrame,TweenInfo.new(0.6,Enum.EasingStyle.Back,Enum.EasingDirection.In,0,false,0),{Size=UDim2.new(0,0,0,0)})
	Tween.Completed:Connect(function()
		MainFrame.Visible=false
	end)
	Tween:Play()
end
--[[]]--
local GamepassRequests=UI:WaitForChild("Gamepasses")
local function CreateTemplate(Info,ID)
	local NewTemplate=Template:Clone()
	NewTemplate.Name=Info["Name"]
	NewTemplate.PriceBar.TextLabel.Text=Info["PriceInRobux"]
	NewTemplate.TextLabel.Text=Info["Name"]
	NewTemplate.ImageLabel.Image="rbxassetid://"..Info["IconImageAssetId"]
	NewTemplate.TextButton.Activated:Connect(function()
		if Debounce==true then return end
		Debounce=true
		script["Bell"]:Play()
		game:GetService("MarketplaceService"):PromptGamePassPurchase(Player,ID)
		CloseUI()
		task.wait(0.65) Debounce=false
	end)
	NewTemplate.TextButton.MouseEnter:Connect(function()
		TweenService:Create(NewTemplate.TextButton,TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,0),{Size=UDim2.new(0.95,0,.95,0)}):Play()
	end)
	NewTemplate.TextButton.MouseLeave:Connect(function()
		TweenService:Create(NewTemplate.TextButton,TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,0),{Size=UDim2.new(0.9,0,.9,0)}):Play()
	end)
	NewTemplate.Parent=MainFrame.List
end
for i, v in pairs(GamepassRequests:GetChildren()) do 
	if v:IsA("StringValue") then
		if not tonumber(v.Value) then
			warn("Gamepass Shop: "..v.Name.." has an Invalid ID")
		else
			local ID=tonumber(v.Value)
			local Info=game:GetService("MarketplaceService"):GetProductInfo(v.Value,Enum.InfoType.GamePass) or nil
			if not Info then
				warn("Gamepass Shop: "..v.Name.." failed to get Info.")
			else CreateTemplate(Info,ID)
			end
		end
	else warn("Gamepass Shop: "..v.Name.." is not a StringValue.")
	end
end
Toggle.Activated:Connect(function()
	if Debounce==true then return end
	Debounce=true
	script["Click"]:Play()
	if MainFrame.Visible==true then
		CloseUI()
		task.wait(0.65) Debounce=false
	else 
		MainFrame.Position=UDim2.new(0.651,0,0.497,0)
		MainFrame.Size=UDim2.new(0.42,0,0.5,0)
		TweenService:Create(MainFrame,TweenInfo.new(0.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,0),{Position=UDim2.new(0.651,0,0.497,0)}):Play()
		MainFrame.Visible=true
		task.wait(0.35) Debounce=false
	end
end)
--[[]]--
local TestGamepasses=0 -- Creates Empty Gamepass Slots
for i=1, TestGamepasses do 
	local NewTemplate=Template:Clone()
	NewTemplate.Name="Test Gamepass"
	NewTemplate.PriceBar.TextLabel.Text="129"
	NewTemplate.TextLabel.Text="Test 0"..i
	NewTemplate.TextButton.MouseEnter:Connect(function()
		TweenService:Create(NewTemplate.TextButton,TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,0),{Size=UDim2.new(0.95,0,.95,0)}):Play()
	end)
	NewTemplate.TextButton.MouseLeave:Connect(function()
		TweenService:Create(NewTemplate.TextButton,TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,0),{Size=UDim2.new(0.9,0,.9,0)}):Play()
	end)
	NewTemplate.LayoutOrder=999
	NewTemplate.Parent=MainFrame.List
end
--[[]]--