--Made by Stickmasterluke



sp=script.Parent
frames=10

wait()
for frame=1,frames do
	wait()
	for i,v in ipairs(sp:GetChildren()) do
		if v then
			if v.className=="Part" then
				v.Transparency=frame/frames
			end
		end
	end
end
sp:destroy()




