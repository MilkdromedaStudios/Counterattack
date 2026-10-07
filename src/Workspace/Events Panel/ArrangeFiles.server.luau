local model = script.Parent

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local settings = model:FindFirstChild("Settings")
if settings then
	settings.Parent = ReplicatedStorage
end

local assetsFolder = model:FindFirstChild("OYB_Assets")
if assetsFolder then
	local brain = assetsFolder:FindFirstChild("OYB_ServerBrain")
	if brain then 
		brain.Parent = ServerScriptService 
	end

	local oybEvent = assetsFolder:FindFirstChild("OYBEVENT")
	if oybEvent then 
		oybEvent.Parent = ReplicatedStorage 
	end

	local panel = assetsFolder:FindFirstChild("OYB_Panel")
	if panel then 
		panel.Parent = ServerStorage 
	end

	local client = assetsFolder:FindFirstChild("OYB_PlayerClient")
	if client then 
		local targetSps = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts") or StarterPlayer:WaitForChild("StarterPlayerScripts")
		client.Parent = targetSps
	end

	assetsFolder:Destroy()
end

script:Destroy()