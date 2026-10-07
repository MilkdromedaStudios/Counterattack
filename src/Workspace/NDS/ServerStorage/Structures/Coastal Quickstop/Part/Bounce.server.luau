function onTouched(part)
	if part.Parent ~= nil then
		local h = part.Parent:findFirstChild("Humanoid")
		local hrp = part.Parent:FindFirstChild('HumanoidRootPart')
		if h~=nil and hrp and h.Health > 0 then
			hrp.Velocity=Vector3.new(0,58,0)
			wait(0.5)
		end			
	end
end

script.Parent.Touched:connect(onTouched)
