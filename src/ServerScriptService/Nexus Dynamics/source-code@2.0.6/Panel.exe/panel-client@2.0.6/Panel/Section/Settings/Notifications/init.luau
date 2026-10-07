----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)



----- || MAIN || -----
dictionary = {
	
	{
		Name = "NOTIFICATIONS",
		
		Libraries.Common "WriteOnly" {}
			:Title("ENABLED")
			:Description("Whether notifications are displayed.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.NotificationsEnabled)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.NotificationsEnabled = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("POSITION")
			:Description("Where notifications appear.")
			:Values {
				Libraries.Interactions "Dropdown" {}
				:Default(shared["Nexus Dynamics"].Config.NotificationPosition)
				:SetOptions{
					"Top-Right",
					"Top-Left",
					"Bottom-Right",
					"Bottom-Left",
				}
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.NotificationPosition = self.Value
						game:GetService("Players").LocalPlayer.PlayerGui["nexus-dynamics-notifications@2.0"]:FindFirstChild("UIListLayout", true).HorizontalAlignment = shared["Nexus Dynamics"].Config.NotificationPosition:lower():find("right") and Enum.HorizontalAlignment.Right or shared["Nexus Dynamics"].Config.NotificationPosition:lower():find("left") and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
						game:GetService("Players").LocalPlayer.PlayerGui["nexus-dynamics-notifications@2.0"]:FindFirstChild("UIListLayout", true).VerticalAlignment = shared["Nexus Dynamics"].Config.NotificationPosition:lower():find("bottom") and Enum.VerticalAlignment.Bottom or shared["Nexus Dynamics"].Config.NotificationPosition:lower():find("top") and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Center
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("ALERTS")
			:Description("Whether warn/error notifications are received.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.Alerts)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.Alerts = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("FLY PROMPT")
			:Description("Whether the fly command displays the fly prompt.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.FlyPromptEnabled)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.FlyPromptEnabled = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
	},	
}

return dictionary