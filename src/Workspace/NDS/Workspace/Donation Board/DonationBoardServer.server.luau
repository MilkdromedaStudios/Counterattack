local DataStoreService = game:GetService('DataStoreService')
local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local MarketplaceService = game:GetService('MarketplaceService')

local DonationBoardSettings = require(script.Parent.DonationBoardSettings)
local Resources = script.Parent.Resources
local ScrollingFrameAutoScale = require(Resources.ScrollingFrameAutoScale)
local Commas = require(Resources.Commas)

local RemoteEvent = script.Parent.RemoteEvent
local TopDonorsDS = DataStoreService:GetOrderedDataStore('TopDonators')
local DonateSurfaceUI = script.Parent.Main:WaitForChild('DonateSurfaceUI')
local CharacterModel = script.Parent:WaitForChild('CharacterModel')
local CharacterModelEmotes = script.Parent.CharacterModelEmotes
local productInfos = {}


local function init()	
	-- productInfos
	for _, productId in DonationBoardSettings.Products do 
		local productInfo = MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		if productInfo.IsForSale then
			productInfos[productId] = productInfo
		end
	end
	
	-- chat msgs
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if productInfos[productId] and isPurchased then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				RemoteEvent:FireAllClients('DonatedMessage', {Player = player, Amount = productInfos[productId].PriceInRobux})
			end
		end
	end)
	
	-- clamp
	if DonationBoardSettings.TopDonorsListSize then
		DonationBoardSettings.TopDonorsListSize = math.clamp(DonationBoardSettings.TopDonorsListSize, 10, 100)
	else
		DonationBoardSettings.TopDonorsListSize = 25
	end
	
	-- title
	DonateSurfaceUI.Container.Title.Text = 'Top ' .. tostring(DonationBoardSettings.TopDonorsListSize) .. ' Donors'
	
	-- auto scale
	ScrollingFrameAutoScale:Do(DonateSurfaceUI.Container.ScrollingFrame, DonateSurfaceUI.Container.ScrollingFrame.UIGridLayout, Enum.AutomaticSize.Y)
	
	-- clear
	for a,b in DonateSurfaceUI.Container.ScrollingFrame:GetChildren() do 
		if b:IsA('CanvasGroup') then
			b:Destroy()
		end
	end
	
	-- process receipt
	if not DonationBoardSettings.CustomProcessReceipt then
		MarketplaceService.ProcessReceipt = function(receiptInfo)
			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			
			if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
			
			for productId, productInfo in productInfos do 
				if receiptInfo.ProductId == productId then
					local success, err = pcall(function()
						TopDonorsDS:IncrementAsync(player.UserId, productInfo.PriceInRobux)
					end)
					
					if not success then
						return Enum.ProductPurchaseDecision.NotProcessedYet
					else
						return Enum.ProductPurchaseDecision.PurchaseGranted
					end
				end
			end
			
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
end

local function getNameFromUserId(userId: number): string | nil
	local success, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId) 
	end)
	
	if success and result then
		return result :: string
	end
	
	return nil
end

local function getPlayerThumbnail(userId: number, thumbnailType: Enum.ThumbnailType, thumbnailSize: Enum.ThumbnailSize): string
	local thumbnail, isReady = Players:GetUserThumbnailAsync(userId, thumbnailType, thumbnailSize)

	if not isReady then
		thumbnail = "rbxassetid://7313814914"
	end

	return thumbnail
end

local function refreshTopDonors()
	-- clear last
	for a,b in DonateSurfaceUI.Container.ScrollingFrame:GetChildren() do 
		if b:IsA('CanvasGroup') then
			task.spawn(function()
				local t = TweenService:Create(b, TweenInfo.new(0.25), {GroupTransparency = 1})
				t:Play()
				t.Completed:Wait()
				b:Destroy()
			end)
		end
	end
	
	-- new
	local topDonorsData = TopDonorsDS:GetSortedAsync(false, DonationBoardSettings.TopDonorsListSize) :: DataStorePages
	topDonorsData = topDonorsData:GetCurrentPage()
	
	for index, data in topDonorsData do
		local name = getNameFromUserId(data.key)
		local nameFormattedString =  name and ('@' .. name) or 'error fetching name'
		
		local cloned = DonateSurfaceUI.Container.ScrollingFrame.UIGridLayout.Template:Clone()
		cloned.Name = data.key
		cloned.LayoutOrder = index
		cloned.PlayerName.Text = nameFormattedString
		cloned.PlayerRank.Text = '#' .. index
		cloned.PlayerValue.Text = utf8.char(0xE002) .. ' ' .. Commas:Add(data.value)
		cloned.GroupTransparency = 1
		
		-- rank colors
		if index == 1 then
			cloned.BackgroundColor3 = Color3.fromRGB(200, 130, 50)
		elseif index == 2 then
			cloned.BackgroundColor3 = Color3.fromRGB(130, 130, 130)
		elseif index == 3 then
			cloned.BackgroundColor3 = Color3.fromRGB(115, 90, 50)
		else
			cloned.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		end
		
		local playerHeadShotThumbnail = getPlayerThumbnail(data.key, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
		local playerAvatarThumbnail = getPlayerThumbnail(data.key, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size180x180)
		for a,b in cloned:GetChildren() do 
			if b.Name == 'PlayerAvatar' then
				b.Image = playerAvatarThumbnail
			elseif b.Name == 'PlayerHeadShot' then
				b.Image = playerHeadShotThumbnail
			end
		end
		
		cloned.Parent = DonateSurfaceUI.Container.ScrollingFrame
		
		TweenService:Create(cloned, TweenInfo.new(0.25), {GroupTransparency = 0}):Play()
		
		-- character model
		if index == 1 then
			task.spawn(function()
				local description = Players:GetHumanoidDescriptionFromUserId(data.key)
				local humanoid = CharacterModel:FindFirstChildOfClass('Humanoid')
				local animator = humanoid:FindFirstChildOfClass('Animator')
				
				if CharacterModel:WaitForChild('Head'):FindFirstChild('CharacterModelOverhead') then
					CharacterModel:WaitForChild('Head'):FindFirstChild('CharacterModelOverhead'):Destroy()
				end
				
				local characterModelOverhead = script.CharacterModelOverhead:Clone()
				characterModelOverhead.Enabled = true
				characterModelOverhead.Container.PlayerName.Text = nameFormattedString
				characterModelOverhead.Container.PlayerHeadShot.Image = playerHeadShotThumbnail
				
				if not animator then
					animator = Instance.new('Animator')
					animator.Parent = humanoid
				end
				
				for _, animTrack in animator:GetPlayingAnimationTracks() do 
					animTrack:Stop(0)
					animTrack:Destroy()
				end
				
				if description then
					humanoid:ApplyDescriptionReset(description)
					
					characterModelOverhead.Parent = CharacterModel:WaitForChild('Head')
					
					if #CharacterModelEmotes:GetChildren() > 0 then
						local anim = CharacterModelEmotes:GetChildren()[math.random(#CharacterModelEmotes:GetChildren())]
						local animTrack = animator:LoadAnimation(anim)

						animTrack.Looped = true
						animTrack:Play()
					end 
				end				
			end)
		end
		
		task.wait(0.1)
	end
end


init()


while true do 
	DonateSurfaceUI.Container.RefreshingIn.Text = 'Refreshing now...'

	refreshTopDonors()
	
	for i = 60, 1, -1 do
		DonateSurfaceUI.Container.RefreshingIn.Text = 'Refreshing in ' .. tostring(i) .. 's'
		task.wait(1)
	end	
	
	task.wait()
end