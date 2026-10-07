script.Parent.OnClientInvoke = function(data)
	if (data.type == "fov") then
		workspace.CurrentCamera.FieldOfView = data.fov
	end
	
	if (data.type == "warp") then
		local distort = 1-0.005
		local distortDirection = -0.005
		repeat game:GetService("RunService").RenderStepped:Wait()
			if distort < 0.005 then
				distort = 0.005
				distortDirection = 0.005
			elseif distort > 1 then
				distort = 1
				distortDirection = -0.005
			end
			workspace.CurrentCamera.CFrame *= CFrame.new(0,0,0,distort,0,0,0,distort,0,0,0,1)
			distort = distort + distortDirection
		until distort > 1
	end
	
	if (data.type == "blur") then
		if (data.undo) then
			local BlurEffect = game:GetService("Lighting"):FindFirstChild("Nexus Dynamics // BlurEffect")
			if (BlurEffect) then BlurEffect:Destroy() end
			
			return
		end
		
		local BlurEffect = game:GetService("Lighting"):FindFirstChild("Nexus Dynamics // BlurEffect") or Instance.new("BlurEffect", game:GetService("Lighting"))
		BlurEffect.Name = "Nexus Dynamics // BlurEffect"
		BlurEffect.Size = data.intensity
	end	
	
	if (data.type == "ragdoll") then
		if (data.undo) then
			workspace.CurrentCamera.CameraSubject = game:GetService("Players").LocalPlayer.Character.Humanoid

			game:GetService("Players").LocalPlayer.Character.Animate.Disabled = false
			game:GetService("Players").LocalPlayer.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			game:GetService("Players").LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			
			return
		end
		
		workspace.CurrentCamera.CameraSubject = game:GetService("Players").LocalPlayer.Character

		game:GetService("Players").LocalPlayer.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		game:GetService("Players").LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)

		for _,v in game:GetService("Players").LocalPlayer.Character.Humanoid:GetPlayingAnimationTracks() do v:Stop(0) end

		game:GetService("Players").LocalPlayer.Character.Animate.Disabled = true
	end	
	
	if (data.type == "coregui") then
		if (Enum.CoreGuiType[data.typeOf]) then
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType[data.typeOf], data.state)
			return
		end
		
		game:GetService("StarterGui"):SetCore(data.typeOf, data.state)
	end	
end