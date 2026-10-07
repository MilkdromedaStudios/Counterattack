----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)



----- || MAIN || -----
dictionary = {
	
	["Behavior"] = {
		["AmbientReverb"] = Libraries.Common "WriteOnly" { LayoutOrder = 1 }
			:Title("AMBIENT REVERB")
			:Description("The ambient sound environment preset.")
			:Values {

				Libraries.Interactions "Dropdown" {}
				:Default(game:GetService("SoundService").AmbientReverb)
				:SetOptions(Enum.ReverbType:GetEnumItems())
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Sounds",

							Property = "AmbientReverb",

							Values = {
								{game:GetService("SoundService").AmbientReverb, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("SoundService"), "AmbientReverb", self.Value)
					end)
				end)
			},


		["DistanceFactor"] = Libraries.Common "WriteOnly" { LayoutOrder = 2 }
			:Title("DISTANCE FACTOR")
			:Description("The number of studs to be considered a meter by SoundService.")
			:Values {

				Libraries.Interactions "TextBox" {}
				:Placeholder("0")
				:SetValue(game:GetService("SoundService").DistanceFactor)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Sounds",

							Property = "DistanceFactor",

							Values = {
								{game:GetService("SoundService").DistanceFactor, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("SoundService"), "DistanceFactor", self.Value)
					end)
				end)
			},


		["DopplerScale"] = Libraries.Common "WriteOnly" { LayoutOrder = 3 }
			:Title("DOPPLER SCALE")
			:Description("Determines the degree of which 3D sounds pitch.")
			:Values {

				Libraries.Interactions "TextBox" {}
				:Placeholder("0")
				:SetValue(game:GetService("SoundService").DopplerScale)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Sounds",

							Property = "DopplerScale",

							Values = {
								{game:GetService("SoundService").DopplerScale, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("SoundService"), "DopplerScale", self.Value)
					end)
				end)
			},


		["RespectFilteringEnabled"] = Libraries.Common "WriteOnly" { LayoutOrder = 4 }
			:Title("RESPECT FILTERING")
			:Description("Whether sound playback from client will replicate to the server.")
			:Values {

				Libraries.Interactions "Toggle" {}
				:Default(game:GetService("SoundService").RespectFilteringEnabled)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Sounds",

							Property = "RspectFilteringEnabled",

							Values = {
								{game:GetService("SoundService").RespectFilteringEnabled, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("SoundService"), "RespectFilteringEnabled", self.Value)
					end)
				end)
			},


		["RolloffScale"] = Libraries.Common "WriteOnly" { LayoutOrder = 5 }
			:Title("ROLLOFF SCALE")
			:Description("How fast sound volume attenuates, or 'rolls off'.")
			:Values {

				Libraries.Interactions "TextBox" {}
				:Placeholder("0")
				:SetValue(game:GetService("SoundService").RolloffScale)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Sounds",

							Property = "RolloffScale",

							Values = {
								{game:GetService("SoundService").RolloffScale, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("SoundService"), "RolloffScale", self.Value)
					end)
				end)
			},
	},
}


return dictionary