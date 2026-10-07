repeat task.wait() until script:IsDescendantOf(game:GetService("Players")) and script:FindFirstChild("Invoke")
script.Invoke.OnClientInvoke = function()
	if (script.Name == "RegisteryKey") then
		local Framework = script.Parent:FindFirstChild("notification-client@2.0.6")
		if not Framework then return false end
		
		require(Framework)

		return true
	end
	
	local Gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("nexus-dynamics-notifications@2.0")
	if (Gui) then Gui:Destroy() end
end