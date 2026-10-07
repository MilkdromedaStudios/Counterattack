--Made by Stickmasterluke


local sp=script.Parent


local plr = game.Players.LocalPlayer
local event = sp:WaitForChild('Event')
local replicatedStorage = game:GetService('ReplicatedStorage')

local eatanimloaded = nil
local equipanimloaded = nil
local chr = nil
local h = nil


event.OnClientEvent:connect(function(eventinfo)
	if eventinfo=='EatAnim' then
		if eatanimloaded then
			eatanimloaded:Play()
		end
	end
end)

sp.Equipped:connect(function()
	if not chr or not h then
		chr=plr.Character
		h=chr:FindFirstChild('Humanoid')
	end
	if h then
		local rigType = h.RigType == Enum.HumanoidRigType.R6 and 'R6' or 'R15'
		local eatAnimation = replicatedStorage:FindFirstChild('AppleEatAnim'..rigType)
		if not eatanimloaded then
			eatanimloaded = h:LoadAnimation(eatAnimation)
		end
		local equipAnimation = replicatedStorage:FindFirstChild('AppleEquipAnim'..rigType)
		if not equipanimloaded then
			equipanimloaded = h:LoadAnimation(equipAnimation)
		end
	end
	if equipanimloaded then
		equipanimloaded:Play()
	end
end)
