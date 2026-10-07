--Made by Stickmasterluke


local sp=script.Parent


local healamount=15
local extrawait=6

local handle=sp:WaitForChild('Handle',5)
local eatsound=handle:WaitForChild('EatSound',5)
local sparkles=handle:WaitForChild('Sparkles',5)
local event=sp:WaitForChild('Event')

local equipped=false
local check=true
local chr=nil
local h=nil
local plr=nil
local equipinstant=nil


sp.Activated:connect(function()
	if check and equipped and h and h.Health>0 then
		check=false
		event:FireClient(plr,'EatAnim')
		wait(1)
		if h.Health>0 and equipped then
			--print('Healing',h.Parent,h.Health,'to',h.Health+healamount)
			if h.Health < 100 then	--Will overheal without this check
				h:TakeDamage(-healamount)
			end
			--h.Health=h.Health+healamount
			if eatsound then
				eatsound:Play()
			end
		end
		wait(.62+extrawait)
		check=true
	end
end)

sp.Equipped:connect(function(mouse)
	equipped=true
	chr=sp.Parent
	plr=game.Players:GetPlayerFromCharacter(chr)
	h=chr:FindFirstChild('Humanoid')

	local myequipinstant={}
	equipinstant=myequipinstant
	wait(2)
	if equipped and myequipinstant==equipinstant then
		sparkles.Enabled=true
		wait(.3)
		sparkles.Enabled=false
	end
end)

sp.Unequipped:connect(function()
	equipped=false
end)


