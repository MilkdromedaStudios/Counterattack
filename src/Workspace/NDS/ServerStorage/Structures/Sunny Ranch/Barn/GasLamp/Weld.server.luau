--

t = script.Parent

function stick(x, y)
	weld = Instance.new("Weld") 
	weld.Part0 = x
	weld.Part1 = y
	local HitPos = x.Position
	local CJ = CFrame.new(HitPos) 
	local C0 = x.CFrame:inverse() *CJ 
	local C1 = y.CFrame:inverse() * CJ 
	weld.C0 = C0 
	weld.C1 = C1 
	weld.Parent = x
end

function Weldnow()
	c = t:children()
	for n = 1, #c do
		if (c[n].className == "Part") then
			if (c[n].Name ~= "MainPart") then
				stick(c[n], t.MainPart)
			end
		end
		if (c[n].className == "WedgePart") then
			if (c[n].Name ~= "MainPart") then
				stick(c[n], t.MainPart)
				wait()
			end
		end
		if (c[n].className == "VehicleSeat") then
			if (c[n].Name ~= "MainPart") then
				stick(c[n], t.MainPart)
			end
		end
		if (c[n].className == "Seat") then
			if (c[n].Name ~= "MainPart") then
				stick(c[n], t.MainPart)
			end
		end
	end
end

wait()
Weldnow()
