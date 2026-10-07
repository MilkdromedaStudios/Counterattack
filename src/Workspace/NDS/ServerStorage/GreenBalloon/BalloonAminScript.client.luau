--Made by Stickmasterluke


local sp=script.Parent


wait()	--gets previous character or soemthing bad if no wait here
local plr=game.Players.LocalPlayer
local sharedstorage=game:GetService("ReplicatedStorage")

while not plr.Character and plr.Character.Parent==game.Workspace do
	wait()
end
local h = plr.Character:WaitForChild("Humanoid",5)
local rigType = h.RigType == Enum.HumanoidRigType.R6 and 'R6' or 'R15'
local balloonholdanim = h:LoadAnimation(sharedstorage:WaitForChild("BalloonHoldAnimation"..rigType,5))
local balloonfloatanim = h:LoadAnimation(sharedstorage:WaitForChild("BalloonFloatAnimation"..rigType,5))


function setstate(state)
	if equipped then
		if state=="FreeFalling" or state=="FallingDown" or state=="PlatformStanding" then
			if balloonfloatanim then
				balloonfloatanim:Play()
			end
		else
			if balloonfloatanim then
				balloonfloatanim:Stop(.5)
			end
		end
	end
end

h.Seated:connect(function() setstate("Seated") end)
h.Running:connect(function() setstate("Running") end)
h.Jumping:connect(function() setstate("Jumping") end)
h.Climbing:connect(function() setstate("Climbing") end)
h.Swimming:connect(function() setstate("Swimming") end)
h.GettingUp:connect(function() setstate("GettingUp") end)
h.FreeFalling:connect(function() setstate("FreeFalling") end)
h.FallingDown:connect(function() setstate("FallingDown") end)
h.PlatformStanding:connect(function() setstate("PlatformStanding") end)

sp.Equipped:connect(function()
	equipped=true
	balloonholdanim:Play()
end)

sp.Unequipped:connect(function()
	equipped=false
	balloonfloatanim:Stop(.5)
	balloonholdanim:Stop(.5)
end)

--[[
while true do
	wait(1)
	script.Parent.Handle.BillboardGui.TextLabel2.Text = 'Client: '..tostring(script.Parent.Handle.BodyForce.force.Y)
	randomshade = .8+math.random()*.2
	script.Parent.Handle.BillboardGui.TextLabel2.BackgroundColor3 = Color3.new(randomshade,randomshade,randomshade)
end
]]