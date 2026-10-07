----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)



----- || MAIN || -----
dictionary = {
	
	["Behavior"] = {
		["Gravity"] = Libraries.Common "WriteOnly" { LayoutOrder = 1 }
			:Title("GRAVITY")
			:Description("How much gravity affects physics.")
			:Values {
				
				Libraries.Interactions "TextBox" {}
				:Placeholder("0")
				:SetValue(workspace.Gravity)
				:Connection(function( self )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end

						--

						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Workspace",

							Property = "Gravity",

							Values = {
								{workspace.Gravity, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(workspace, "Gravity", self.Value)
					end)
				end),
			},


		["AirDensity"] = Libraries.Common "WriteOnly" { LayoutOrder = 2 }
			:Title("AIR DENSITY")
			:Description("The air density at ground level.")
			:Values {

				Libraries.Interactions "TextBox" {}
				:Placeholder("0")
				:SetValue(workspace.AirDensity)
				:Connection(function( self )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end

						--

						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Workspace",

							Property = "AirDensity",

							Values = {
								{workspace.AirDensity, self.Value}
							}
						}

						--

						script.Callback:InvokeServer(workspace, "AirDensity", self.Value)
					end)
				end),
			},
	},
}


return dictionary