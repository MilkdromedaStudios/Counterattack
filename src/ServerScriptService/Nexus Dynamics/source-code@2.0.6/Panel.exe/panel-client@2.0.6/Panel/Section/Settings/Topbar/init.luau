----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)



----- || MAIN || -----
dictionary = {
	
	{
		Name = "TOPBAR",
		
		Libraries.Common "WriteOnly" {}
			:Title("ENABLED")
			:Description("Whether the topbar button is displayed.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.TopbarEnabled)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.TopbarEnabled = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TRANSPARENCY")
			:Description("Background transparency of topbar button.")
			:Values {
				Libraries.Interactions "Slider" {}
				:SetValue(shared["Nexus Dynamics"].Config.Transparency, 0, 1)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics // Topbar"].Icon.BackgroundTransparency = self.Value
						shared["Nexus Dynamics"].Config.Transparency = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("POSITION")
			:Description("Where the topbar button sits on your screen.")
			:Values {
				Libraries.Interactions "Dropdown" {}
				:Default(shared["Nexus Dynamics"].Config.TopbarPosition)
				:SetOptions{
					"Left",
					"Center",
					"Right",
				}
				
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics // Topbar"][self.Value](shared["Nexus Dynamics // Topbar"])
						shared["Nexus Dynamics"].Config.TopbarPosition = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
	},	
	
}

return dictionary