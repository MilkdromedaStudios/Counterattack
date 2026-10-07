----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)



----- || MAIN || -----
ScreenGui = Libraries.Common "ScreenGui" {
	Name = "nexus-dynamics@2.0",
	Parent = script:FindFirstAncestorWhichIsA("Player").PlayerGui,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,	
}

shared["Nexus Dynamics"].Panel = Libraries.Windows "Panel" {
	Parent = ScreenGui,
	Size = UDim2.fromOffset(822, 566),
	Visible = false,
}

local scale = Instance.new("UIScale", shared["Nexus Dynamics"].Panel.Element)
task.spawn(function()
	while ScreenGui and task.wait() do
		scale.Scale = math.clamp(ScreenGui.AbsoluteSize.X/1100, 0, 1)	
	end
end)


Libraries:Close()

--



shared["Nexus Dynamics"].Popups = {
	CommandPrompt = require(script.Popups.CommandPrompt)(shared["Nexus Dynamics"].Panel),
	ColorPicker = require(script.Popups.ColorPicker) (shared["Nexus Dynamics"].Panel),
	Skybox = require(script.Popups.Skybox) (shared["Nexus Dynamics"].Panel),
}



--



shared["Nexus Dynamics"].Top = require(script.Top) (shared["Nexus Dynamics"].Panel)
shared["Nexus Dynamics"].Ribbon = require(script.Ribbon) (shared["Nexus Dynamics"].Panel)
shared["Nexus Dynamics"].Bottom = require(script.Bottom) (shared["Nexus Dynamics"].Panel)
shared["Nexus Dynamics"].Section = require(script.Section) (shared["Nexus Dynamics"].Panel)


--

shared["Nexus Dynamics"].Menu = Libraries.Windows "Menu" { Parent = ScreenGui }
shared["Nexus Dynamics"].Menu.Element.Parent = ScreenGui

shared["Nexus Dynamics"].Menu.Opened:Connect(function()
	shared["Nexus Dynamics // Topbar"]:Hide()
end)

shared["Nexus Dynamics"].Menu.Closed:Connect(function(showTopbar: boolean)
	if not showTopbar then return end
	shared["Nexus Dynamics // Topbar"]:Show()
end)

--

game:GetService("Players").LocalPlayer.PlayerGui["nexus-dynamics-notifications@2.0"]:FindFirstChild("UIListLayout", true).HorizontalAlignment = shared["Nexus Dynamics"].Config.NotificationPosition:lower():find("right") and Enum.HorizontalAlignment.Right or shared["Nexus Dynamics"].Config.NotificationPosition:lower():find("left") and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
game:GetService("Players").LocalPlayer.PlayerGui["nexus-dynamics-notifications@2.0"]:FindFirstChild("UIListLayout", true).VerticalAlignment = shared["Nexus Dynamics"].Config.NotificationPosition:lower():find("bottom") and Enum.VerticalAlignment.Bottom or shared["Nexus Dynamics"].Config.NotificationPosition:lower():find("top") and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Center
shared["Nexus Dynamics"].Ribbon:ChangeTab("Dashboard")
return true