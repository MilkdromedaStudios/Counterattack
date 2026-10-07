--


local Tool = script.Parent
local handle=Tool:WaitForChild("Handle",5)
local upAndAway = false
local humanoid = nil
local head = nil
local upAndAwayForce=handle.BodyForce
isfloating=false

local equalizingForce = 236 / 1.2 -- amount of force required to levitate a mass
local gravity = 1.05 -- things float at > 1

local height = nil
local maxRise =  75

function float(lift)
	if not isfloating then
		isfloating=true
		while equipped do
			lift=recursiveGetLift(Tool.Parent)
			upAndAwayForce.force=Vector3.new(0,lift*.8,0)
			--if Tool.Handle.Position.y > height + maxRise then
			if Tool.Handle.Position.y>300 then
				equipped=false
				Tool.Handle.Pop:Play()
				Tool.GripPos=Vector3.new(0,-.4,0)
				Tool.Handle.Mesh.MeshId = "http://www.roblox.com/asset/?id=26725510"
			end
			for i=1,4 do
				updateBalloonSize()
				wait(1/20)
			end
		end
		upAndAwayForce.force=Vector3.new(0,0,0)
		isfloating=false
	end
end

function onEquipped()
	Tool.Handle.Mesh.MeshId="http://www.roblox.com/asset/?id=25498565"
	equipped = true
	--[[Tool.GripPos = Vector3.new(0,-1,0)
	Tool.GripForward = Vector3.new(0,1,0)
	Tool.GripRight = Vector3.new(0,0,-1)
	Tool.GripUp = Vector3.new(1,0,0)]]
	Tool.Grip = CFrame.new(0,-1,0,0,1,0,0,0,-1,-1,0,0)
	local hrp = Tool.Parent:FindFirstChild('HumanoidRootPart')
	if hrp then
		height = hrp.Position.y
	else
		height = 0
	end
	lift=recursiveGetLift(Tool.Parent)
	float(lift)
end

function onUnequipped()
	equipped = false
	--[[Tool.GripForward = Vector3.new(1,0,0)
	Tool.GripRight = Vector3.new(0,0,1)
	Tool.GripUp = Vector3.new(0,1,0)]]
	handle.Mesh.Scale = Vector3.new(1,1,1)
end

Tool.Unequipped:connect(onUnequipped)
Tool.Equipped:connect(onEquipped)

function recursiveGetLift(node)
	local m = 0
	local c = node:GetChildren()
	if (node:FindFirstChild("Head") ~= nil) then head = node:FindFirstChild("Head") end -- nasty hack to detect when your parts get blown off

	for i=1,#c do
		if c[i]:IsA("BasePart") then	
			if (head ~= nil and (c[i].Position - head.Position).magnitude < 10) then -- GROSS
				if c[i].Name == "Handle" then
					m = m + (c[i]:GetMass() * equalizingForce * 1) -- hack that makes hats weightless, so different hats don't change your jump height
				else
					m = m + (c[i]:GetMass() * equalizingForce * gravity)
				end
			end
		end
		m = m + recursiveGetLift(c[i])
	end
	return m
end

function updateBalloonSize()
	local range=(height+maxRise)-Tool.Handle.Position.y
	--[[if range<maxRise/3 then
		Tool.Handle.Mesh.Scale=Vector3.new(1,1,1)*2
	elseif range<maxRise*(2/3) then
		Tool.Handle.Mesh.Scale=Vector3.new(1,1,1)*1.5
	else
		Tool.Handle.Mesh.Scale=Vector3.new(1,1,1)
	end]]
	Tool.Handle.Mesh.Scale=Vector3.new(1,1,1)*(2-math.min(1,math.max(0,range/maxRise)))
end

--[[
while true do
	wait(1)
	script.Parent.Handle.BillboardGui.TextLabel1.Text = 'Server: '..tostring(script.Parent.Handle.BodyForce.force.Y)
	randomshade = .8+math.random()*.2
	script.Parent.Handle.BillboardGui.TextLabel1.BackgroundColor3 = Color3.new(randomshade,randomshade,randomshade)
end
]]


