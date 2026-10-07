----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)



----- || MAIN || -----
dictionary = {
	
	{
		Name = "KEYBINDS",
		
		Libraries.Common "WriteOnly" {}
			:Title("MENU")
			:Description("Binds a key to toggle the menu wheel.")
			:Values {
				Libraries.Interactions "Button" {}
				:Placeholder(shared["Nexus Dynamics"].Config.Menu)
				:Connection(function(self)
					local isBusy = false
					
					self.Element.MouseButton1Click:Connect(function()
						if isBusy then return end isBusy = true
						self:Placeholder("Press Any Key")
						shared["Nexus Dynamics"].Keybinding = true
						local connection; connection = game:GetService("UserInputService").InputBegan:Connect(function(input)
							if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
							connection:Disconnect()
							shared["Nexus Dynamics"].Config.Menu = input.KeyCode.Name
							shared["Nexus Dynamics"].SaveUserSettings()
							self:Placeholder(input.KeyCode.Name)
							isBusy = false
							task.delay(0.5, function() shared["Nexus Dynamics"].Keybinding = true end)
						end)
					end)
				end)
				
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("COMMAND PROMPT")
			:Description("Binds a key to toggle the command prompt.")
			:Values {
				Libraries.Interactions "Button" {}
				:Placeholder(shared["Nexus Dynamics"].Config.CommandPrompt)
				:Connection(function(self)
					local isBusy = false

					self.Element.MouseButton1Click:Connect(function()
						if isBusy then return end isBusy = true
						self:Placeholder("Press Any Key")
						shared["Nexus Dynamics"].Keybinding = true
						local connection; connection = game:GetService("UserInputService").InputBegan:Connect(function(input)
							if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
							connection:Disconnect()
							shared["Nexus Dynamics"].Config.CommandPrompt = input.KeyCode.Name
							shared["Nexus Dynamics"].SaveUserSettings()
							self:Placeholder(input.KeyCode.Name)
							isBusy = false
							task.delay(0.5, function() shared["Nexus Dynamics"].Keybinding = true end)
						end)
					end)
				end)
			},
		
		Libraries.Common "WriteOnly" {}
			:Title("SHELL")
			:Description("Binds a key to toggle the shell prompt.")
			:Values {
				Libraries.Interactions "Button" {}
				:Placeholder(shared["Nexus Dynamics"].Config.Shell)	
				:Connection(function(self)
					local isBusy = false

					self.Element.MouseButton1Click:Connect(function()
						if isBusy then return end isBusy = true
						self:Placeholder("Press Any Key")
						shared["Nexus Dynamics"].Keybinding = true
						local connection; connection = game:GetService("UserInputService").InputBegan:Connect(function(input)
							if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
							connection:Disconnect()
							shared["Nexus Dynamics"].Config.Shell = input.KeyCode.Name
							shared["Nexus Dynamics"].SaveUserSettings()
							self:Placeholder(input.KeyCode.Name)
							isBusy = false
							task.delay(0.5, function() shared["Nexus Dynamics"].Keybinding = true end)
						end)
					end)
				end)
			},
	},	
}


return dictionary