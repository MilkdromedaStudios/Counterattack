local panel = script.Parent
local mainFrame = panel:WaitForChild("MainFrame", 5)
local adminFrame = panel:WaitForChild("AdminManagerFrame", 5)
local announceFrame = panel:WaitForChild("AnnouncementsFrame", 5)
local customFrame = panel:WaitForChild("CustomEventFrame", 5)
local giveToolsFrame = panel:WaitForChild("GiveToolsFrame", 5)
local toggleBtn = panel:WaitForChild("ToggleButton", 5)

local function openWindow(targetFrame)
	if adminFrame then adminFrame.Visible = false end
	if announceFrame then announceFrame.Visible = false end
	if customFrame then customFrame.Visible = false end
	if giveToolsFrame then giveToolsFrame.Visible = false end
	if targetFrame then targetFrame.Visible = true end
end

if toggleBtn then
	toggleBtn.MouseButton1Click:Connect(function()
		mainFrame.Visible = not mainFrame.Visible
		if not mainFrame.Visible then openWindow(nil) end
	end)
end

if mainFrame:FindFirstChild("CloseButton") then
	mainFrame.CloseButton.MouseButton1Click:Connect(function()
		mainFrame.Visible = false
		openWindow(nil)
	end)
end

if announceFrame:FindFirstChild("CloseAnnouncementsBtn") then
	announceFrame.CloseAnnouncementsBtn.MouseButton1Click:Connect(function() openWindow(nil) end)
end

if adminFrame:FindFirstChild("CloseManagerButton") then
	adminFrame.CloseManagerButton.MouseButton1Click:Connect(function() openWindow(nil) end)
end

if customFrame:FindFirstChild("CloseCustomBtn") then
	customFrame.CloseCustomBtn.MouseButton1Click:Connect(function() openWindow(nil) end)
end

if giveToolsFrame and giveToolsFrame:FindFirstChild("CloseToolsBtn") then
	giveToolsFrame.CloseToolsBtn.MouseButton1Click:Connect(function() openWindow(nil) end)
end

if mainFrame:FindFirstChild("OpenAnnouncementsBtn") then
	mainFrame.OpenAnnouncementsBtn.MouseButton1Click:Connect(function() openWindow(announceFrame) end)
end

if mainFrame:FindFirstChild("ManageAdminsButton") then
	mainFrame.ManageAdminsButton.MouseButton1Click:Connect(function() openWindow(adminFrame) end)
end

if mainFrame:FindFirstChild("OpenCustomBtn") then
	mainFrame.OpenCustomBtn.MouseButton1Click:Connect(function() openWindow(customFrame) end)
end

if mainFrame:FindFirstChild("GiveToolsButton") then
	mainFrame.GiveToolsButton.MouseButton1Click:Connect(function() openWindow(giveToolsFrame) end)
end