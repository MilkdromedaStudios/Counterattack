--Made by Stickmasterluke


local sp = script.Parent
local player = game.Players.LocalPlayer
local sps = sp:WaitForChild("SurviversPage")
local multiDisasterSplash = sp:WaitForChild("MultiDisasterSplash")
local multiDisasterNumberList = multiDisasterSplash:WaitForChild('NumberShading'):WaitForChild('NumberList')
local multiDisasterNameLabelTemplate = multiDisasterSplash:WaitForChild('NameLabelTemplate')
local oldcontent = game.Workspace:WaitForChild("ContentModel")
local sharedstorage = game:GetService("ReplicatedStorage")
local event = sharedstorage:WaitForChild("Event")
local notificationholder = sp:WaitForChild("NotificationHolder")
local hoverSound = sp:WaitForChild('HoverSound')
local tickSound = sp:WaitForChild('TickSound')
local multiDisasterSound = sp:WaitForChild('MultiDisasterSound')
local warningHint = sp:WaitForChild('Hint')
local hintText = warningHint:WaitForChild('List'):WaitForChild('HintText')
local userInputService = game:GetService('UserInputService')
local wmp = sp:WaitForChild('WeatherMachinePage')
local guiService = game:GetService('GuiService')
local introPage = sp:WaitForChild('IntroPage')
local readyButton = introPage:WaitForChild('ReadyButton')
local wmButton = game.Workspace:WaitForChild('WeatherMachine'):WaitForChild('Button')
local wmpPowerButton = wmp:WaitForChild('PowerButton')
local wmpCancelButton = wmp:WaitForChild('CancelButton')
local mapVotePage = sp:WaitForChild('MapVotePage')
local mapVotePageFrame = mapVotePage:WaitForChild('Frame')
local mapVoteChoice1 = mapVotePageFrame:WaitForChild('Choice1')
local mapVoteChoice2 = mapVotePageFrame:WaitForChild('Choice2')
local mapVoteChoice3 = mapVotePageFrame:WaitForChild('Choice3')
local mapVotesStorage = sharedstorage:WaitForChild('MapVotes')
local mapVoteChoice1Tag = mapVotesStorage:FindFirstChild('Choice1')
local mapVoteChoice2Tag = mapVotesStorage:FindFirstChild('Choice2')
local mapVoteChoice3Tag = mapVotesStorage:FindFirstChild('Choice3')


local marketPlaceService = game:GetService('MarketplaceService')
local powerUpMachineProductId = 36120455

local testing = false
local inputType = userInputService.GamepadEnabled and 'Controller' or 'Computer'
local disasters = {"Meteor Shower","Flash Flood","Thunder Storm","Fire","Tornado","Tsunami","Blizzard","Sandstorm","Volcanic Eruption","Earthquake","Acid Rain"}

--test line:    event=game.ReplicatedStorage.Event event:FireAllClients("PointsAwarded","Stickmasterluke",math.random(1,12))

function lockMovement(lock)
	if player and player.Character and player.Character.Parent then
		local humanoid = player.Character:FindFirstChild('Humanoid')
		if userInputService.GamepadEnabled and humanoid then
			humanoid.WalkSpeed = lock and 0 or 16
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not lock)
		end
	end
end


function inputRecieved(input)
	inputType = input.UserInputType == Enum.UserInputType.Gamepad1 and 'Controller' or 'Computer'
	userInputService.MouseIconEnabled = inputType == 'Computer'
end
userInputService.InputBegan:connect(inputRecieved)
userInputService.InputEnded:connect(inputRecieved)
userInputService.MouseIconEnabled = inputType == 'Computer'

status = oldcontent.Status
status.Changed:connect(function()
	if player:FindFirstChild("Ready") then
		lockMovement(true)
		wmp.Visible = false
		if mapVotePage.Visible then
			closeMapVote()
		end
		if status.Value=="Survivers" then
			for i5,v5 in ipairs(sps.List:GetChildren()) do
				v5:destroy()
			end
			local survivers=oldcontent.Survivers:GetChildren()
			for i6,v6 in ipairs(survivers) do
				local nnt=sps.NameLabel:clone()
				if #survivers<=10 then
					nnt.Size=UDim2.new(1,0,.08,0)
					nnt.Position=UDim2.new(0,0,((i6-1)%10)*.1+.01,0)
				elseif #survivers<=20 then
					nnt.Size=UDim2.new(.5,0,.08,0)
					nnt.Position=UDim2.new(math.floor((i6-1)/10)/2,0,((i6-1)%10)*.1+.01,0)
				else
					nnt.Size=UDim2.new(.33,0,.08,0)
					nnt.Position=UDim2.new(math.floor((i6-1)/10)/3,0,((i6-1)%10)*.1+.01,0)
				end
				nnt.Text=v6.Name
				nnt.Parent=sps.List
				nnt.Visible=true
			end
			sps.NooneWins.Visible = #survivers==0
			sps.Visible = true
			sp.NextMapPage.Visible = false
			wait(#survivers==0 and 5 or 10)
			sps.Visible = false
		elseif status.Value == "New Map" then
			sp.NextMapPage.List.MapTitle.Text = oldcontent.Information.Value
			sp.NextMapPage.Visible = true
			sps.Visible = false
			wait(5)
			sp.NextMapPage.Visible = false
		end
		lockMovement(false)
	end
end)

game.Workspace:WaitForChild("BillboardBalloon"):WaitForChild("Board"):WaitForChild("ClickDetector").MouseClick:connect(function(thisPlayer)
	if thisPlayer and thisPlayer == player and player:FindFirstChild("Ready") then
		hoverSound:Stop()
		hoverSound:Play()
		event:FireServer('ClickedBalloon')
	end
end)
game.Workspace:WaitForChild("BillboardApple"):WaitForChild("Board"):WaitForChild("ClickDetector").MouseClick:connect(function(thisPlayer)
	if thisPlayer and thisPlayer == player and player:FindFirstChild("Ready") then
		hoverSound:Stop()
		hoverSound:Play()
		event:FireServer('ClickedApple')
	end
end)
game.Workspace:WaitForChild("BillboardCompass"):WaitForChild("Board"):WaitForChild("ClickDetector").MouseClick:connect(function(thisPlayer)
	if thisPlayer and thisPlayer == player and player:FindFirstChild("Ready") then
		hoverSound:Stop()
		hoverSound:Play()
		event:FireServer('ClickedCompass')
	end
end)


local function closeIntro()
	if not player:FindFirstChild("Ready") then
		local tag = Instance.new("BoolValue")
		tag.Name = "Ready"
		tag.Value = true
		tag.Parent = player
		introPage.Visible = false
		hoverSound:Stop()
		hoverSound:Play()
	end
end

if not player:FindFirstChild("Ready") then
	readyButton.MouseButton1Up:connect(closeIntro)
	introPage.Visible = true
	if userInputService.GamepadEnabled then
		guiService.SelectedObject = readyButton
	end
end

function checkWindowSpaceReady()
	return not wmp.Visible and player:FindFirstChild("Ready") and not sps.Visible and not sp.NextMapPage.Visible and not multiDisasterSplash.Visible
end


local mapImages = {
	["Furious Station"] = "http://www.roblox.com/asset/?id=591522321",
	["Raving Raceway"] = "http://www.roblox.com/asset/?id=591522315",
	["Heights School"] = "http://www.roblox.com/asset/?id=591522318",
	["Surf Central"] = "http://www.roblox.com/asset/?id=591522316",
	["Trailer Park"] = "http://www.roblox.com/asset/?id=591522313",
	["Sky Tower"] = "http://www.roblox.com/asset/?id=591522310",
	["Sunny Ranch"] = "http://www.roblox.com/asset/?id=591522309",
	["Glass Office"] = "http://www.roblox.com/asset/?id=591522307",
	["Happy Home"] = "http://www.roblox.com/asset/?id=591522299",
	["Party Palace"] = "http://www.roblox.com/asset/?id=591522306",
	["Arch Park"] = "http://www.roblox.com/asset/?id=591522300",
	["Lucky Mart"] = "http://www.roblox.com/asset/?id=591522304",
	["Coastal Quickstop"] = "http://www.roblox.com/asset/?id=591522297",
	["Fort Indestructible"] = "http://www.roblox.com/asset/?id=591522302",
	["Rakish Refinery"] = "http://www.roblox.com/asset/?id=591522296",
}
local baseMapVoteColor = Color3.fromRGB(35, 181, 103)
local selectedMapVoteColor = Color3.fromRGB(233, 235, 68)

function createVoteTags(choiceTag, choiceGui)
	choiceGui.Image = mapImages[choiceTag.Value] or ''
	local mapNameLabel = choiceGui:FindFirstChild('MapNameLabel')
	if mapNameLabel then
		mapNameLabel.Text = choiceTag.Value
	end
	for _,v in pairs(choiceGui:GetChildren()) do
		if v.Name ~= 'MapNameLabel' then
			v:Destroy()
		end
	end
	local renderCount = 0
	for _,voteTag in pairs(choiceTag:GetChildren()) do
		local votePlayer = game.Players:FindFirstChild(voteTag.Name)
		if votePlayer then
			renderCount = renderCount + 1
			local voteGui = Instance.new('ImageLabel')
			voteGui.Image = "http://www.roblox.com/Thumbs/Avatar.ashx?x=100&y=100&Format=Png&username="..voteTag.Name
			voteGui.Size = UDim2.new(0,32,0,32)
			voteGui.Position = UDim2.new(0, (((renderCount-1)%4))*40 + 4, 1, -40*math.ceil(renderCount/4) + 4)
			voteGui.BackgroundColor3 = Color3.new(1,1,1)
			voteGui.BorderSizePixel = 0
			voteGui.BackgroundTransparency = 1
			voteGui.ZIndex = choiceGui.ZIndex
			voteGui.Parent = choiceGui
		end
	end
	choiceGui.BorderColor3 = choiceTag:FindFirstChild(player.Name) and selectedMapVoteColor or baseMapVoteColor
end

function updateMapVote()
	if mapVotePage.Visible then
		createVoteTags(mapVoteChoice1Tag, mapVoteChoice1)
		createVoteTags(mapVoteChoice2Tag, mapVoteChoice2)
		createVoteTags(mapVoteChoice3Tag, mapVoteChoice3)
	end
end

mapVoteChoice1Tag.ChildAdded:connect(updateMapVote)
mapVoteChoice1Tag.ChildRemoved:connect(updateMapVote)
mapVoteChoice1Tag.Changed:connect(updateMapVote)
mapVoteChoice2Tag.ChildAdded:connect(updateMapVote)
mapVoteChoice2Tag.ChildRemoved:connect(updateMapVote)
mapVoteChoice2Tag.Changed:connect(updateMapVote)
mapVoteChoice3Tag.ChildAdded:connect(updateMapVote)
mapVoteChoice3Tag.ChildRemoved:connect(updateMapVote)
mapVoteChoice3Tag.Changed:connect(updateMapVote)

mapVoteChoice1.MouseButton1Down:connect(function()
	hoverSound:Play()
	event:FireServer('MapVote','Choice1')
	updateMapVote()
end)
mapVoteChoice2.MouseButton1Down:connect(function()
	hoverSound:Play()
	event:FireServer('MapVote','Choice2')
	updateMapVote()
end)
mapVoteChoice3.MouseButton1Down:connect(function()
	hoverSound:Play()
	event:FireServer('MapVote','Choice3')
	updateMapVote()
end)

function openMapVote()
	if not mapVotePage.Visible and not wmp.Visible and player:FindFirstChild("Ready") and not sps.Visible and not sp.NextMapPage.Visible and not multiDisasterSplash.Visible then
		mapVotePage.Visible = true
		if userInputService.GamepadEnabled then
			guiService.SelectedObject = mapVoteChoice1
		end
		updateMapVote()
	end
end
function closeMapVote()
	mapVotePage.Visible = false
end

function openwmp()
	if checkWindowSpaceReady() and script.Parent.AbsoluteSize.Y >= 480 then
		wmp.Visible = true
		wmpCancelButton.ImageColor3 = Color3.fromRGB(255,255,255)
		wmpPowerButton.ImageColor3 = Color3.fromRGB(255,255,255)
		wmpPowerButton.OnLabel.Visible = false
		wmpPowerButton.NormalLabel.Visible = true
		if userInputService.GamepadEnabled then
			guiService.SelectedObject = wmpPowerButton
		end
	end
end

function closewmp()
	if wmp.Visible then
		wmp.Visible = false
		hoverSound:Stop()
		hoverSound:Play()
	end
end

wmButton:WaitForChild('ClickDetector').MouseClick:connect(function(thisPlayer)
	if thisPlayer and thisPlayer == player and player:FindFirstChild("Ready") then
		openwmp()
	end
end)
wmButton.Touched:connect(function(hit)
	if hit and hit.Parent then
		local thisPlayer = game.Players:GetPlayerFromCharacter(hit.Parent)
		if thisPlayer and thisPlayer == player then
			openwmp()
		end
	end
end)

function powerUpMachine()
	marketPlaceService:PromptProductPurchase(game.Players.LocalPlayer, powerUpMachineProductId)
	closewmp()
end

wmpPowerButton.MouseButton1Up:connect(powerUpMachine)
wmpPowerButton.MouseButton1Down:connect(function()
	wmpPowerButton.OnLabel.Visible = true
	wmpPowerButton.NormalLabel.Visible = false
	--wmpPowerButton.ImageColor3 = Color3.fromRGB(200,200,200)	--Looks ugly
end)
wmpPowerButton.MouseEnter:connect(function()
	wmpPowerButton.OnLabel.Visible = true
	wmpPowerButton.NormalLabel.Visible = false
end)
wmpPowerButton.MouseLeave:connect(function()
	wmpPowerButton.OnLabel.Visible = false
	wmpPowerButton.NormalLabel.Visible = true
	wmpPowerButton.ImageColor3 = Color3.fromRGB(255,255,255)
end)

wmpCancelButton.MouseButton1Down:connect(function()
	wmpCancelButton.ImageColor3 = Color3.fromRGB(200,200,200)
end)
wmpCancelButton.MouseEnter:connect(function()
	wmpCancelButton.ImageColor3 = Color3.fromRGB(222,222,222)
end)
wmpCancelButton.MouseLeave:connect(function()
	wmpCancelButton.ImageColor3 = Color3.fromRGB(255,255,255)
end)
wmpCancelButton.MouseButton1Up:connect(closewmp)

local userinputservice = game:GetService('UserInputService')
local buttonsToAccept = {
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.ButtonX] = true,
}
local buttonsToDecline = {
	[Enum.KeyCode.ButtonB] = true,
}

userInputService.InputBegan:connect(function(input, soaked)
	if buttonsToAccept[input.KeyCode] then
		if introPage.Visible then
			closeIntro()
		end
		if wmp.Visible then
			powerUpMachine()
		end
	elseif buttonsToDecline[input.KeyCode] then
		if introPage.Visible then
			closeIntro()
		end
		if wmp.Visible then
			closewmp()
		end
	end
end)

function openMultiDisasterSplash(power, players)
	if player:FindFirstChild("Ready") then
		if wmp.Visible then
			closewmp()
		end
		if mapVotePage.Visible then
			closeMapVote()
		end
		multiDisasterSplash.Visible = true
		multiDisasterSplash.Position = UDim2.new(1,50,.5,-256)
		multiDisasterNumberList.Position = UDim2.new(0,-1,1,0)
		multiDisasterSound.Pitch = 1
		multiDisasterSound:Play()
		for _,v in pairs(multiDisasterSplash:GetChildren()) do
			if string.sub(v.Name,1,9) == 'NameLabel' and v ~= multiDisasterNameLabelTemplate then
				v:Destroy()
			end
		end
		for i, playerName in pairs(players) do
			local label = multiDisasterNameLabelTemplate:clone()
			label.Name = 'NameLabel'..tostring(i)
			label.Text = playerName
			label.Boldener.Text = playerName
			label.Position = UDim2.new(0, 40+((i+1)%2)*222, 0, math.ceil(i/2)*38+255)
			label.Visible = true
			label.Parent = multiDisasterSplash
		end
		multiDisasterSplash:TweenPosition(UDim2.new(.5,-256,.5,-256),'InOut','Quad', 1, true)
		wait(1)
		for i=1, power do
			local slideTime = 1--.5+(i/power)*1
			multiDisasterNumberList:TweenPosition(UDim2.new(0,-1,-i+1,0),'Out','Bounce', slideTime+.5, true)
			delay(slideTime-.5,function()
				tickSound:Stop()
				tickSound.Pitch = .35+.3*(i/power)
				tickSound:Play()
			end)
			wait(slideTime)
			--todo: play some sparks
		end
		multiDisasterSound.Pitch = 1.25
		multiDisasterSound:Play()
	
		wait(5)
		multiDisasterSplash:TweenPosition(UDim2.new(0,-562,.5,-256),'InOut','Quad', 1, true)
		wait(1)
		multiDisasterSplash.Visible = false
	end
end

event.OnClientEvent:connect(function(...)
	local tuple={...}
	if tuple[1] == 'DisasterWarning' then
		--if userInputService.GamepadEnabled then
			hintText.Text = tuple[2]
			warningHint:TweenPosition(UDim2.new(.35,-30,.05,-15), 'Out', 'Quad', 1, true)
			wait(15)
			warningHint:TweenPosition(UDim2.new(.35,-30,-.1,-90), 'Out', 'Quad', 1, false)
		--end
	elseif tuple[1] == 'Multi-Disaster' then
		openMultiDisasterSplash(tuple[2], tuple[3])
	elseif tuple[1] == 'OpenCompass' then
		openMapVote()
	elseif tuple[1] == 'CloseCompass' then
		closeMapVote()
	end
end)



