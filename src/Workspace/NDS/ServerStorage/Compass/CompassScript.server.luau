
--


--todo:this could and should all be in a local script, with a bindable event

local sp = script.Parent
local event = game:GetService("ReplicatedStorage"):WaitForChild('Event')
local player = nil

local equipped = false
local equipCount = 0

sp.Equipped:connect(function()
	equipCount = equipCount + 1
	local thisEquip = equipCount
	equipped = true
	while equipped and thisEquip == equipCount do
		local character = sp.Parent
		player = game.Players:GetPlayerFromCharacter(character)
		if player then
			event:FireClient(player, 'OpenCompass')
		end
		wait(1)
	end
end)
sp.Unequipped:connect(function()
	equipped = false
	if player then
		event:FireClient(player, 'CloseCompass')
	end
end)


