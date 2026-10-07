----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)



----- || MAIN || -----
dictionary = {
	
	["Behavior"] = {
		["WaterColor"] = Libraries.Common "WriteOnly" { LayoutOrder = 1 }
			:Title("WATER COLOR")
			:Description("The color of terrian water.")
			:Values {

				Libraries.Interactions "ColorPicker" {}
				:SetValue(workspace.Terrain.WaterColor)
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						self:SetValue(color)
					end)			
				end)

				:Connection(function( self )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end

						--

						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Terrain",

							Property = "WaterColor",

							Values = {
								{workspace.Terrain.WaterColor, self.Value}
							}
						}

						--

						script.Callback:InvokeServer(workspace.Terrain, "WaterColor", self.Value)
					end)
				end),
			},


		["WaterTransparency"] = Libraries.Common "WriteOnly" { LayoutOrder = 2 }
			:Title("WATER TRANSPARENCY")
			:Description("Opacity of terrain water.")
			:Values {

				Libraries.Interactions "Slider" {}
				:SetValue(workspace.Terrain.WaterTransparency, 0, 1, 100)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Terrain",

							Property = "WaterTransparency",

							Values = {
								{workspace.Terrain.WaterTransparency, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(workspace.Terrain, "WaterTransparency", self.Value)
					end)
				end)
			},


		["WaterReflectance"] = Libraries.Common "WriteOnly" { LayoutOrder = 3 }
			:Title("WATER REFLECTANCE")
			:Description("How much terrain water reflect light.")
			:Values {

				Libraries.Interactions "Slider" {}
				:SetValue(workspace.Terrain.WaterReflectance, 0, 1, 100)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Terrain",

							Property = "WaterReflectance",

							Values = {
								{workspace.Terrain.WaterReflectance, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(workspace.Terrain, "WaterReflectance", self.Value)
					end)
				end)
			},


		["WaveSize"] = Libraries.Common "WriteOnly" { LayoutOrder = 4 }
			:Title("WAVE SIZE")
			:Description("The size of each wave.")
			:Values {

				Libraries.Interactions "Slider" {}
				:SetValue(workspace.Terrain.WaterWaveSize, 0, 1, 100)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Terrain",

							Property = "WaterWaveSize",

							Values = {
								{workspace.Terrain.WaterWaveSize, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(workspace.Terrain, "WaterWaveSize", self.Value)
					end)
				end)
			},


		["WaveSpeed"] = Libraries.Common "WriteOnly" { LayoutOrder = 5 }
			:Title("WAVE SPEED")
			:Description("The speed of each wave.")
			:Values {

				Libraries.Interactions "Slider" {}
				:SetValue(workspace.Terrain.WaterWaveSpeed, 0, 1, 100)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end

						--

						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Terrain",

							Property = "WaterWaveSpeed",

							Values = {
								{workspace.Terrain.WaterWaveSpeed, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(workspace.Terrain, "WaterWaveSpeed", self.Value)
					end)
				end)
			},	
	},
	
	["Materials"] = {},
}

for _, material in Enum.Material:GetEnumItems() do
	if not table.find({528, 788, 800, 804, 816, 820, 836, 848, 880, 896, 912, 1280, 1284, 1296, 1328, 1344, 1360, 1376, 1392, 1536, 1552, 2048}, material.Value) then continue end
	pcall(function()
		if not workspace.Terrain:GetMaterialColor(material) then return end
		
		dictionary.Materials[material.Name] = Libraries.Common "WriteOnly" { LayoutOrder = 1 }
			:Title(`{material.Name:upper()} COLOR`)
			:Description(nil)
			:Values {

				Libraries.Interactions "ColorPicker" {}
				:SetValue(workspace.Terrain:GetMaterialColor(material))
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						self:SetValue(color)
					end)			
				end)

				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end

						--

						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Terrain",

							Property = material.Name,

							Values = {
								{workspace.Terrain:GetMaterialColor(material), self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(workspace.Terrain, material, self.Value)
					end)
				end)
			}
	end)
end

return dictionary