repeat task.wait() until script:IsDescendantOf(game:GetService("Players")) and script:FindFirstChild("Invoke")
script.Invoke.OnClientInvoke = function( userReg: any )
	if (script.Name == "RegisteryKey") then
		local Framework = script.Parent:FindFirstChild("topbar-client@2.0.6")
		if not Framework then return false end

		_G["topbar-client@2.0.6\config"] = userReg.UserSettings
		_G["topbar-client@2.0.6\colors"] = userReg.ColorSettings
		_G["topbar-client@2.0.6\buildinfo"] = userReg.BuildInfo
		
		_G["topbar-client@2.0.6"] = require(Framework)
		return true
	end

	local Gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Nexus Dynamics Topbar Icon", true)
	if (Gui) then Gui:Destroy() end
end