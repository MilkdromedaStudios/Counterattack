----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || MAIN || -----
return function( panel: any )

	local Gui = {
		["Dashboard"] = Libraries.Interactions "Tab" { Parent = panel.Ribbon.Left } 
		 	:Icon("rbxassetid://105061980704922", Vector2.new(644, 404), Vector2.new(36, 36))
		 	:Title("Dashboard"),

		["Commands"] = Libraries.Interactions "Tab" { Parent = panel.Ribbon.Left }
			:Icon("rbxassetid://8445470392", Vector2.new(304, 104), Vector2.new(96, 96))
			:Title("Commands"),

		["Manager"] = Libraries.Interactions "Tab" { Parent = panel.Ribbon.Left }
			:Icon("rbxassetid://8445470189", Vector2.new(904, 304), Vector2.new(96, 96))
			:Title("Manager"),

		["AuditLog"] = Libraries.Interactions "Tab" { Parent = panel.Ribbon.Left }
			:Icon("rbxassetid://8445470559", Vector2.new(604, 604), Vector2.new(96, 96))
			:Title("AuditLog"),	

		["Account"] = Libraries.Interactions "Account" { Parent = panel.Ribbon.Right }
			:SetUserId(game:GetService("Players").LocalPlayer.UserId),
	}
	
	for name, button in Gui do
		if name:lower() == "account" then continue end
		
		button.Activated:Connect(function()
			shared["Nexus Dynamics"].Ribbon.TabChanged:Fire(name)
			
			for name, element in Gui do
				if name:lower() == "account" then continue end
				
				element[`Set{element == button and "" or "In"}Active`](element)
			end
		end)
	end
	
	
	--
	
	
	local dropdown; dropdown = Libraries.scope:New("Frame") {
		Parent = panel.Ribbon,
		Visible = false,
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = color "--Background",
		Position = UDim2.new(1, -10, 1.021, 5),
		Size = UDim2.fromOffset(181, 0),
		ZIndex = 5,
		
		[Libraries.scope.Children] = {
			
			Libraries.scope:New("UICorner") {
				CornerRadius = UDim.new(0, 5),
			},
			
			Libraries.scope:New("UIListLayout") {
				Padding = UDim.new(),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			
			Libraries.scope:New("UIStroke") {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = color "--Border",
				Thickness = 1,
				Transparency = 0.925,
			},
			
			Libraries.Interactions "AccountTab" { Name = "BuildInfo" } 
				:Icon("rbxassetid://105061980704922", Vector2.new(4, 484), Vector2.new(36, 36))
				:Title("Build Info")
				:SetBorder(true)
				:Connection(function(self)
					self.Element.MouseButton1Click:Connect(function()
						dropdown.Visible = false
						shared["Nexus Dynamics"].Ribbon.TabChanged:Fire("BuildInfo")

						for name, element in Gui do
							if name:lower() == "account" then continue end

							element[`Set{element == self.Element and "" or "In"}Active`](element)
						end
					end)
				end).Element,
			
			Libraries.Interactions "AccountTab" { Name = "Settings" } 
				:Icon("rbxassetid://105061980704922", Vector2.new(324, 124), Vector2.new(36, 36))
				:Title("Settings")
				:SetBorder(true)
				:Connection(function(self)
					self.Element.MouseButton1Click:Connect(function()
						dropdown.Visible = false
						shared["Nexus Dynamics"].Ribbon.TabChanged:Fire("Settings")

						for name, element in Gui do
							if name:lower() == "account" then continue end

							element[`Set{element == self.Element and "" or "In"}Active`](element)
						end
					end)
				end).Element,
		}
	}
	
	Gui.Account.Element.MouseButton1Click:Connect(function()
		dropdown.Visible = not dropdown.Visible
	end)
	
	--
	
	
	return {
		TabChanged = Libraries.Maid.signal("TabChanged"),
		
		ChangeTab = function( self: any, tabName: string )
			shared["Nexus Dynamics"].Ribbon.TabChanged:Fire(tabName)

			for name, element in Gui do
				if name:lower() == "account" then continue end

				element[`Set{name == tabName and "" or "In"}Active`](element)
			end
		end,
	}	
end