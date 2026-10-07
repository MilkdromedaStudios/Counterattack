--Made by Stickmasterluke


local sp = script.Parent

local frame = sp:WaitForChild('Frame')
local spinGlobeValue = sp:WaitForChild('SpinGlobeEnabled')
random = math.random

local ringAVs = {}

for _,ring in pairs(sp:GetChildren()) do
	if ring.Name == 'SpinningRingUnion' then
		local bp = Instance.new('BodyPosition',ring)
		bp.maxForce = Vector3.new(1,1,1)*40000
		bp.Position = frame.Position
		local bav = Instance.new('BodyAngularVelocity',ring)
		ring.Anchored = false
		table.insert(ringAVs,bav)
	end
end

while true do
	wait(2)
	if spinGlobeValue.Value then
		for _,ringAV in pairs(ringAVs) do
			ringAV.AngularVelocity = Vector3.new(random(-2,2),random(-2,2),random(-2,2)) * 3
		end
	else
		for _,ringAV in pairs(ringAVs) do
			ringAV.AngularVelocity = Vector3.new(0,0,0)
		end
	end
end


