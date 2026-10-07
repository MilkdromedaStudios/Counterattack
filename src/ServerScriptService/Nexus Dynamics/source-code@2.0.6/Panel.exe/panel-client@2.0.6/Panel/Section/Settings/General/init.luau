----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)



----- || MAIN || -----
dictionary = {
	
	
	{
		Name = "GENERAL",

		Libraries.Common "WriteOnly" {}
			:Title("DRAGGABLE")
			:Description("Determines if the panel can be moved by dragging with mouse.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.Draggable)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.Draggable = self.Value
						
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},

		Libraries.Common "WriteOnly" {}
			:Title("COLOR WHEEL OUTPUT")
			:Description("Determines the output color type for color values.")
			:Values {
				Libraries.Interactions "Dropdown" {}
				:Default(shared["Nexus Dynamics"].Config.ColorWheelOutput)
				:SetOptions {
					"RGB",
					"HSV",
					"HEX",
					"BRICKCOLOR"					
				}
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.ColorWheelOutput = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
	},
	
	{
		Name = "CLOCK",

		Libraries.Common "WriteOnly" {}
			:Title("USE 24 HOUR CLOCK")
			:Description("Whether notifications are displayed.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.Use24HourClock)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.Use24HourClock = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},

		Libraries.Common "WriteOnly" {}
			:Title("CLOCK ENABLED")
			:Description("Whether notifications are displayed.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.ClockEnabled)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.ClockEnabled = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
	},
	
	{
		Name = "COMMAND PROMPT",
		
		Libraries.Common "WriteOnly" {}
			:Title("SUGGESTIONS")
			:Description("Whether command prompt suggestions are provided based of input.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.Suggestions)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.Suggestions = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("AUTOFILL")
			:Description("Whether TAB will fill suggested within command prompt's input box.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.Autofill)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.Autofill = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("PREVIEW ICONS")
			:Description("Display icons next to suggestions. (i.e. Player Thumbnail, Team Color, Color)")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.PreviewIcons)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.PreviewIcons = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
	}
	
	
}


return dictionary