function onChildAdded(child)
	if child.Name == "SeatWeld" then
		child.C0 = CFrame.new(0,(script.Parent.Size.y/2 + 1.5),0)
		child.C1 = CFrame.new(0,0,0)
	end
end

script.Parent.ChildAdded:connect(onChildAdded)