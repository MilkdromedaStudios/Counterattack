local TweenService = game:GetService('TweenService')
local MarketplaceService = game:GetService('MarketplaceService')
local Players = game:GetService('Players')
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild('PlayerGui', 100)
local DonationBoardSettings = require(script.Parent.DonationBoardSettings)
local Resources = script.Parent.Resources
local ScrollingFrameAutoScale = require(Resources.ScrollingFrameAutoScale)
local Commas = require(Resources.Commas)

local RemoteEvent = script.Parent.RemoteEvent
local DonateSurfaceUI = script.Parent.Main:WaitForChild('DonateSurfaceUI')
local DonateBillboardUI = script.Parent.Main:WaitForChild('DonateBillboardUI')

local donateBillboardUIOpened = false
local productInfos = {}

DonateSurfaceUI.Adornee = script.Parent.Main
DonateSurfaceUI.Parent = PlayerGui
DonateBillboardUI.Adornee = script.Parent.Main
DonateBillboardUI.Parent = PlayerGui

-- auto scale
ScrollingFrameAutoScale:Do(DonateSurfaceUI.Container.ScrollingFrame, DonateSurfaceUI.Container.ScrollingFrame.UIGridLayout, Enum.AutomaticSize.Y)

-- productInfos
for _, productId in DonationBoardSettings.Products do 
	local productInfo = MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	if productInfo.IsForSale then
		productInfos[productId] = productInfo
	end
end

-- remote event
RemoteEvent.OnClientEvent:Connect(function(t: string, data: any)
	if t == 'DonatedMessage' then
		StarterGui:SetCore('ChatMakeSystemMessage', 
			{Text = string.format('@%s just donated %s! Thank you :)', data.Player.Name, utf8.char(0xE002) .. ' ' .. Commas:Add(data.Amount)), Color = Color3.fromRGB(255, 166, 64), Font = Enum.Font.GothamBold, TextSize = 20})
	end
end)

local function toggleDonateBillboardUI(value: boolean)
	donateBillboardUIOpened = value
	
	DonateBillboardUI.Enabled = true
	
	if value then
		DonateBillboardUI.Container.Visible = true
		local t = TweenService:Create(DonateBillboardUI.Container, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.fromScale(1,1)})
		t:Play()
	else
		DonateBillboardUI.Container.Visible = false
		DonateBillboardUI.Container.Size = UDim2.fromScale(0,0)
	end
end

toggleDonateBillboardUI(false)

-- donate button
do
	local donateBtn = DonateSurfaceUI.Container.Button
	
	donateBtn.Activated:Connect(function()
		toggleDonateBillboardUI(if donateBillboardUIOpened then false else true)
	end)
	donateBtn.MouseEnter:Connect(function()
		TweenService:Create(donateBtn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(25,25,25)}):Play()
	end)
	donateBtn.MouseLeave:Connect(function()
		TweenService:Create(donateBtn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(50,50,50)}):Play()
	end)
end

-- billboard ui 
do
	
	
	DonateBillboardUI.Container.Close.Activated:Connect(function()
		toggleDonateBillboardUI(false)
	end)
	
	for i, productId in DonationBoardSettings.Products do 
		local productInfo = productInfos[productId]
		if not productInfo or not productInfo.IsForSale then continue end 
		
		local cloned = DonateBillboardUI.Container.ScrollingFrame.UIGridLayout.Template:Clone()
		cloned.Name = productId
		cloned.LayoutOrder = i
		cloned.Label.Text = utf8.char(0xE002) .. ' ' .. Commas:Add(productInfo.PriceInRobux or 0)
		cloned.Parent = DonateBillboardUI.Container.ScrollingFrame
		
		cloned.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		cloned.MouseEnter:Connect(function()
			TweenService:Create(cloned, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(50,100,75)}):Play()
		end)
		cloned.MouseLeave:Connect(function()
			TweenService:Create(cloned, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(85,170,127)}):Play()
		end)
	end	
	
	if #DonateBillboardUI.Container.ScrollingFrame:GetChildren() - 1 > 6 then
		ScrollingFrameAutoScale:Do(DonateBillboardUI.Container.ScrollingFrame, DonateBillboardUI.Container.ScrollingFrame.UIGridLayout, Enum.AutomaticSize.Y)
	end
end