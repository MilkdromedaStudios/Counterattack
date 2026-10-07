----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)

----- || MAIN || -----
dictionary = {
	
	{
		Name = "DEBUG BAR",
	

		Libraries.Common "WriteOnly" {}
			:Title("ENABLED")
			:Description("Determines if the debug bar is shown.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.DebugbarEnabled)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.DebugbarEnabled = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
	},	
	
	{
		Name = "DISPLAY",
		
		Libraries.Common "WriteOnly" {}
			:Title("VERSION")
			:Description("Whether the current version of the panel is shown.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.Version)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.Version = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("REGION")
			:Description("Whether the server region is shown.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.Region)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.Region = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("FPS")
			:Description("Whether your FPS is shown.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.FPS)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.FPS = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
	},	
	
	{
		Name = "STATS",
	

		Libraries.Common "WriteOnly" {}
			:Title("ERRORS")
			:Description("Whether error count is shown.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.Errors)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.Errors = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},

		Libraries.Common "WriteOnly" {}
			:Title("WARNINGS")
			:Description("Whether warning count is shown.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.Warnings)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.Warnings = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},

		Libraries.Common "WriteOnly" {}
			:Title("MEMORY USAGE")
			:Description("Whether your memory usage is shown.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.MemoryUsage)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.MemoryUsage = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("AVG PING")
			:Description("Whether your average ping is shown.")
			:Values {
				Libraries.Interactions "Toggle" {}
				:Default(shared["Nexus Dynamics"].Config.AvgPing)
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics"].Config.AvgPing = self.Value
						shared["Nexus Dynamics"].SaveUserSettings()
					end)
				end)
			},
	},	
}

return dictionary

