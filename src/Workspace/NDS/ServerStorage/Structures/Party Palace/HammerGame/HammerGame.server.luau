--Made by Stickmasterluke


local sp = script.Parent

local button = sp:WaitForChild('Button')

local debounce = false

button.Touched:connect(function(hit)
	if hit and hit.Parent and not debounce and button and button.Velocity.magnitude == 0 then
		local strength = math.abs(hit.Velocity.y)
		local hitSound = button:FindFirstChild('HitSound')
		if strength > 10 and hitSound then
			hitSound:Play()
		end
		wait(.1)
		if strength > 65 then
			debounce = true
			local bell = sp:FindFirstChild('Bell')
			if bell then
				local bellSound = bell:FindFirstChild('BellSound')
				if bellSound then
					bellSound:Play()
				end
				local bellMesh = bell:FindFirstChild('Mesh')
				if bellMesh then
					bellMesh.Scale = Vector3.new(1.25,1.25,1.25)
				end
				wait(1)
				if bellMesh then
					bellMesh.Scale = Vector3.new(1,1.25,1)
				end
			end
			wait(1)
			debounce = false
		end
	end
end)


