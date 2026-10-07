--Made by Stickmasterluke



sp=script.Parent

fatalthreshhold=400
safethreshhold=65
rate=1/22
damage=0

lastvelocity=0

while true do
	local delta=wait(rate)
	local t=sp:FindFirstChild("HumanoidRootPart")
	if t~=nil then
		local currentvelocity=(t.Velocity).magnitude
		local pain=currentvelocity*(rate/delta)-safethreshhold
		if pain>0 then
			damage=damage+(pain/(fatalthreshhold-safethreshhold)*100)
		elseif damage>0 then
			local h=sp:FindFirstChild("Humanoid")
			if h then
				h:TakeDamage(damage)
				damage=0
			end	
		end
		lastvelocity=currentvelocity
	end
end



