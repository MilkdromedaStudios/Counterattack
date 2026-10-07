----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)



----- || MAIN || -----
dictionary = {
	
	{
		Name = "APPEARANCE",
		
		Libraries.Common "WriteOnly" {}
			:Title("THEME")
			:Description("Colors of the current panel.")
			:Values {
				Libraries.Interactions "Dropdown" {}
				:Default(shared["Nexus Dynamics"].Config.Theme)
				:SetOptions {
					"Dark",
					"Light",
					"Midnight",
					"Haze",
					"Modern",
					"Scifi",
					"Coffee",
					"Retro",
					"Custom",
				}
				:Connection(function(self)
					self.Changed:Connect(function(property) if property ~= "Value" then return end
						shared["Nexus Dynamics // Notification"]:Notify(`Rejoin for themes to take full effect.`, 20)
						shared["Nexus Dynamics"].Config.Theme = self.Value
						
						local preset = script:FindFirstChild(`@preset-{self.Value:lower()}`)
						if not preset then return end
						warn("Found "..preset.Name)
						for index, value in require(preset) do
							_G["panel-client@2.0.6\colors"][index] = Color3.fromHex(value)
						end
						
						shared["Nexus Dynamics"].SaveUserSettings()
						task.wait(1)
						shared["Nexus Dynamics"].Reload()
					end)
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("Export")
			:Description("Export the current theme as a json file.")
			:Values {
				Libraries.Interactions "Button" {}
					:Placeholder("Export")
					:Connection(function(self)
						self.Activated:Connect(function()
							shared["Nexus Dynamics // Notification"]:Notify(`Check console/output for json.`, 20)
							local colors = {}
							for name, value in _G["panel-client@2.0.6\colors"] do colors[name] = "#"..value:ToHex() end
							script.Callback:InvokeServer(colors, "export")
						end)
					end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("Import")
			:Description("Import a theme with a json file.")
			:Values {
				Libraries.Interactions "TextBox" {Name="TextBox"}
					:SetValue("")
					:Placeholder("Json"),
				
				Libraries.Interactions "Button" {}
					:Placeholder("Import")
					:Connection(function(self)
						self.Activated:Connect(function()
							shared["Nexus Dynamics // Notification"]:Notify(`Rejoin for themes to take full effect.`, 20)
							local colors = script.Callback:InvokeServer(self.Element.Parent.TextBox.Text, "import")
							for name, value in colors do _G["panel-client@2.0.6\colors"][name] = Color3.fromHex(value) end
							shared["Nexus Dynamics"].Config.Theme = "Custom"
							shared["Nexus Dynamics"].SaveUserSettings()
							shared["Nexus Dynamics"].Reload()					
						end)
					end)
			},
	},	
	
	{
		Name = "COLORS",
		
		Libraries.Common "WriteOnly" {}
			:Title("TINT")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Tint")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Tint"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("ACCENT")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Accent")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Accent"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("ACCENT TEXT COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Accent-Text-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Accent-Text-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("PRIMARY TEXT COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Primary-Text-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Primary-Text-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SECONDARY TEXT COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Secondary-Text-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Secondary-Text-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("DESCRIPTION TEXT COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Description-Text-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Description-Text-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("ERROR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Error")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Error"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("WARNING")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Warning")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Warning"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TOP BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Top-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Top-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TOP BORDER")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Top-Border")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Top-Border"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("RIBBON BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Ribbon-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Ribbon-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("RIBBON BORDER")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Ribbon-Border")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Ribbon-Border"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("BOTTOM BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Bottom-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Bottom-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("BOTTOM BORDER")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Bottom-Border")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Bottom-Border"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("CLOSE")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Close")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Close"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("CLOCK TEXT COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Clock-Text-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Clock-Text-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SIDEBAR BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Sidebar-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Sidebar-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SIDEBAR BUTTON ODD")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Sidebar-Button-Odd")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Sidebar-Button-Odd"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SIDEBAR BUTTON EVEN")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Sidebar-Button-Even")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Sidebar-Button-Even"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SIDEBAR BUTTON ACTIVE")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Sidebar-Button-Active")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Sidebar-Button-Active"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SIDEBAR ICON")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Sidebar-Icon")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Sidebar-Icon"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SIDEBAR ICON ACTIVE")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Sidebar-Icon-Active")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Sidebar-Icon-Active"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SIDEBAR TEXT")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Sidebar-Text")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Sidebar-Text"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SIDEBAR TEXT ACTIVE")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Sidebar-Text-Active")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Sidebar-Text-Active"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("PROFILE BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Profile-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Profile-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("PROFILE CARD COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Profile-Card-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Profile-Card-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SKYBOX INDEX BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Skybox-Index-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Skybox-Index-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TITLE BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Title-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Title-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TAB BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Tab-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Tab-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TAB BACKGROUND ACTIVE")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Tab-Background-Active")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Tab-Background-Active"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TAB BACKGROUND HOVER")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Tab-Background-Hover")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Tab-Background-Hover"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TAB BORDER")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Tab-Border")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Tab-Border"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TAB TEXT COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Tab-Text-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Tab-Text-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TAB ICON COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Tab-Icon-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Tab-Icon-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("ACCOUNTTAB BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--AccountTab-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--AccountTab-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},

		Libraries.Common "WriteOnly" {}
			:Title("ACCOUNTTAB BACKGROUND ACTIVE")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--AccountTab-Background-Active")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--AccountTab-Background-Active"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("ACCOUNTTAB BACKGROUND HOVER")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--AccountTab-Background-Hover")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--AccountTab-Background-Hover"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("ACCOUNTTAB BORDER")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--AccountTab-Border")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--AccountTab-Border"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("ACCOUNTTAB TEXT COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--AccountTab-Text-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--AccountTab-Text-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},

		Libraries.Common "WriteOnly" {}
			:Title("ACCOUNTTAB ICON COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--AccountTab-Icon-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--AccountTab-Icon-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("BUTTON BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Button-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Button-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("BUTTON BORDER")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Button-Border")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Button-Border"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("BUTTON TEXT COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Button-Text-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Button-Text-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("DROPDOWN BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Dropdown-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Dropdown-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},

		Libraries.Common "WriteOnly" {}
			:Title("DROPDOWN BORDER")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Dropdown-Border")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Dropdown-Border"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("DROPDOWN TEXT COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Dropdown-Text-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Dropdown-Text-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TEXTBOX BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--TextBox-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--TextBox-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},

		Libraries.Common "WriteOnly" {}
			:Title("TEXTBOX BORDER")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--TextBox-Border")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--TextBox-Border"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TEXTBOX TEXT COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--TextBox-Text-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--TextBox-Text-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TEXTBOX PLACEHOLDER COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--TextBox-Placeholder-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--TextBox-Placeholder-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SHADOW")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Shadow")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Shadow"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TOGGLE HEAD OFF")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Toggle-Head-Off")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Toggle-Head-Off"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TOGGLE HEAD ON")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Toggle-Head-On")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Toggle-Head-On"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TOGGLE BACKGROUND OFF")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Toggle-Background-Off")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Toggle-Background-Off"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("TOGGLE BACKGROUND ON")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Toggle-Background-On")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Toggle-Background-On"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("OPTION SELECTED")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Option-Selected")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Option-Selected"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SLIDER HEAD")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Slider-Head")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Slider-Head"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SLIDER BACKGROUND")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Slider-Background")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Slider-Background"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SLIDER FILLER")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Slider-Filler")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Slider-Filler"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SLIDER TEXT COLOR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Slider-Text-Color")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Slider-Text-Color"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("DEFAULT ACCOUNT")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Default-Account")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Default-Account"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("BORDER")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--Border")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--Border"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SCROLLBAR")
			:Description()
			:Values {
				Libraries.Interactions "ColorPicker" {} 
				:SetValue(Libraries.Color "--ScrollBar")
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						_G["panel-client@2.0.6\colors"]["--ScrollBar"] = color
						self:SetValue(color)
						shared["Nexus Dynamics"].Config.Theme = "Custom"
						shared["Nexus Dynamics"].SaveUserSettings()
						task.delay(1, function() shared["Nexus Dynamics"].Theme.Updated:Fire() end)
					end)			
				end)
			},
	},		
}


return dictionary