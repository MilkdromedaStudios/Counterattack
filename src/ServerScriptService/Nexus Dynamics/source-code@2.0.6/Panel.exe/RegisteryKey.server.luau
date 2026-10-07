repeat task.wait() until script:IsDescendantOf(game:GetService("Players")) and script:FindFirstChild("Invoke")
script.Invoke.OnClientInvoke = function( userReg: any )
	if (script.Name == "RegisteryKey") then
		local Framework = script.Parent:FindFirstChild("panel-client@2.0.6")
		if not Framework then return false end

		_G["panel-client@2.0.6\config"] = userReg.UserSettings
		_G["panel-client@2.0.6\colors"] = userReg.ColorSettings
		_G["panel-client@2.0.6\buildinfo"] = userReg.BuildInfo
		require(Framework)
		
		return true
	end
	
	local Gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("nexus-dynamics@2.0")
	if (Gui) then Gui:Destroy() end
end