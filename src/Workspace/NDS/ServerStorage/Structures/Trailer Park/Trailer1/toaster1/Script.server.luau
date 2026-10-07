humanoid = nil

function onTouched(part)
	if part.Parent ~= nil then
	local h = part.Parent:findFirstChild("Humanoid")
		if h~=nil then
			if isenabled~=0 then
				if h==humanoid then
					return
				end

				local toast=script.Parent.toast:clone()
				isenabled=0
				toast.Parent=game.Workspace
				toast.Transparency=0
				toast.Locked=false
				toast.Anchored=false
				toast.CanCollide=false
				toast.RotVelocity=Vector3.new(math.random(1,10)/5,math.random(1,10)/5,math.random(1,10)/5)
----TODO>: toast.position
				local toastrot=CFrame.new(0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 1, 0)
				toast.CFrame = script.Parent.toaster.CFrame * CFrame.new(Vector3.new(.75,1,0)) * toastrot
				wait(0.4)
				toast.CanCollide=true

				wait(1)
				isenabled=1

				--IF YOU WANT TOAST TO DISAPPEAR AFTER A WHILE, REMOVE THE -- before next two lines.
				
				--wait(120)
				--toast:destroy()
				

			end
		end
	end
end


script.Parent.toaster.Touched:connect(onTouched)