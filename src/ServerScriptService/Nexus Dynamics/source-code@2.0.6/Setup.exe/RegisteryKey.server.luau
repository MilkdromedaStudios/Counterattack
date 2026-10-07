repeat task.wait() until script:IsDescendantOf(game:GetService("Players")) and script:FindFirstChild("Invoke")
script.Invoke.OnClientInvoke = function( userReg: any, checkEnvironment: any, data: any)
	if (script.Name == "RegisteryKey") then
		local Framework = script.Parent:FindFirstChild("setup-client@2.0.6")
		if not Framework then return false end
		checkEnvironment.Finishing = true
		
		_G["setup-client@2.0.6\data"] = data
		_G["setup-client@2.0.6\config"] = userReg.UserSettings
		_G["setup-client@2.0.6\colors"] = userReg.ColorSettings
		_G["setup-client@2.0.6\buildinfo"] = userReg.BuildInfo
		_G["setup-client@2.0.6\environment"] = checkEnvironment
		require(Framework)
		
		return true
	end

	local Gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("nexus-dynamics-setup@2.0")
	if (Gui) then Gui:Destroy() end
end