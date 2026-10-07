local hasBeenTimedOut = false

script.Parent.OnClientEvent:Connect(function( Timeout: any )
	
	local __suc, __error = pcall(function()
		local hasData = Timeout[tostring(game:GetService("Players").LocalPlayer.UserId)]
		if not hasData then 
			
			if hasBeenTimedOut then
				hasBeenTimedOut = false
				game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
			end
			
			return
		end
		
		--
		
		if hasData and ((game:GetService("RunService"):IsStudio() and tick() or os.time()) - hasData) < 0 then
			if hasBeenTimedOut then return end
			
			hasBeenTimedOut = true
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		elseif hasData and ((game:GetService("RunService"):IsStudio() and tick() or os.time()) - hasData) >= 0 then
			if not hasBeenTimedOut then return end
			
			hasBeenTimedOut = false
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
		end 
	end)

	if not __suc then
		shared["Nexus Dynamics // Cache"][__error] = game:GetService("RunService"):IsStudio() and tick() or os.time()
	end
	
end)

