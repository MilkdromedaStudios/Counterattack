----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)



----- || MAIN || -----
dictionary = {
	
	["Behavior"] = {

		["Captures"] = Libraries.Common "WriteOnly" { LayoutOrder = 1 }
			:Title("CAPTURES")
			:Description("Determines wheter players can use the captures CoreGui.")
			:Values {

				Libraries.Interactions "Toggle" {}
				:Default(true)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "CoreGui",

							Property = "Captures",

							Values = {
								{game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Captures), self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer({
							type = "coregui",
							typeOf = "Captures",
							state = self.Value,
						})
					end)
				end)
			},
		
		["PlayerList"] = Libraries.Common "WriteOnly" { LayoutOrder = 2 }
			:Title("PLAYERLIST")
			:Description("Determines wheter players can see the playerlist CoreGui.")
			:Values {

				Libraries.Interactions "Toggle" {}
				:Default(true)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "CoreGui",

							Property = "PlayerList",

							Values = {
								{game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList), self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer({
							type = "coregui",
							typeOf = "PlayerList",
							state = self.Value,
						})
					end)
				end)
			},
		
		["Backpack"] = Libraries.Common "WriteOnly" { LayoutOrder = 3 }
			:Title("BACKPACK")
			:Description("Determines wheter players can use the backpack CoreGui.")
			:Values {

				Libraries.Interactions "Toggle" {}
				:Default(true)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "CoreGui",

							Property = "Backpack",

							Values = {
								{game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Backpack), self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer({
							type = "coregui",
							typeOf = "Backpack",
							state = self.Value,
						})
					end)
				end)
			},
		
		["Chat"] = Libraries.Common "WriteOnly" { LayoutOrder = 4 }
			:Title("CHAT")
			:Description("Determines wheter players can use the chat CoreGui.")
			:Values {

				Libraries.Interactions "Toggle" {}
				:Default(true)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "CoreGui",

							Property = "Chat",

							Values = {
								{game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Chat), self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer({
							type = "coregui",
							typeOf = "Chat",
							state = self.Value,
						})
					end)
				end)
			},
		
		["Emotes"] = Libraries.Common "WriteOnly" { LayoutOrder = 5 }
			:Title("EMOTES")
			:Description("Determines wheter players can use the emotes CoreGui.")
			:Values {

				Libraries.Interactions "Toggle" {}
				:Default(true)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "CoreGui",

							Property = "Emotes",

							Values = {
								{game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu), self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer({
							type = "coregui",
							typeOf = "EmotesMenu",
							state = self.Value,
						})
					end)
				end)
			},
		
		["Health"] = Libraries.Common "WriteOnly" { LayoutOrder = 6 }
			:Title("HEALTH")
			:Description("Determines wheter players can see the health CoreGui.")
			:Values {

				Libraries.Interactions "Toggle" {}
				:Default(true)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "CoreGui",

							Property = "Health",

							Values = {
								{game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Health), self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer({
							type = "coregui",
							typeOf = "Health",
							state = self.Value,
						})
					end)
				end)
			},
		
		["SelfView"] = Libraries.Common "WriteOnly" { LayoutOrder = 7 }
			:Title("SELFVIEW")
			:Description("Determines wheter players can use the selfview CoreGui.")
			:Values {

				Libraries.Interactions "Toggle" {}
				:Default(true)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "CoreGui",

							Property = "SelfView",

							Values = {
								{game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.SelfView), self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer({
							type = "coregui",
							typeOf = "SelfView",
							state = self.Value,
						})
					end)
				end)
			},
	},
}


return dictionary