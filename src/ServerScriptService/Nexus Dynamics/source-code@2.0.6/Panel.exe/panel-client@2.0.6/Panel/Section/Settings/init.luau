----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || MAIN || -----
return function( panel: any )
	
	local Page = Libraries.Windows "Page" {
		Parent = panel.Section,
		Size = UDim2.fromScale(1, 1),
		Name = "Settings",
	} Page.Element.UIListLayout.FillDirection = Enum.FillDirection.Horizontal


	local Navigation = Libraries.Windows "Sidebar" {
		Parent = Page.Element,
		Size = UDim2.new(0, 208, 1, 0),
	}


	local Properties = Libraries.Windows "Page" {
		Parent = Page.Element,
		Size = UDim2.new(0, 614, 1, 0)
	}
	
	
	
	--
	
	local Services = {
		
		["General"] = Libraries.scope:New "TextButton" {
			Name = "General",
			Parent = Navigation.Element.Frame,
			BackgroundColor3 = Libraries.Color "--Sidebar-Button-Even",
			LayoutOrder = 1,
			AutoButtonColor = true,
			Size = UDim2.new(1, -1, 0, 45),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					Padding = UDim.new(0, 10),
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "UIPadding" {
					PaddingLeft = UDim.new(0, 25),
					PaddingRight = UDim.new(0, 25),
				},

				Libraries.scope:New "ImageLabel" {
					Name = "Icon",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(20, 20),
					Image = "rbxassetid://8445470984",
					ImageColor3 = Libraries.Color "--Sidebar-Icon",
					ImageRectOffset = Vector2.new(404, 804),
					ImageRectSize = Vector2.new(96, 96)
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					Text = "General",
					TextSize = 16,
					TextColor3 = Libraries.Color "--Sidebar-Text",
					TextTransparency = 0.3,
				}
			}
		},
		
		["Appearance"] = Libraries.scope:New "TextButton" {
			Name = "Appearance",
			Parent = Navigation.Element.Frame,
			BackgroundColor3 = Libraries.Color "--Sidebar-Button-Even",
			LayoutOrder = 2,
			AutoButtonColor = true,
			Size = UDim2.new(1, -1, 0, 45),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					Padding = UDim.new(0, 10),
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "UIPadding" {
					PaddingLeft = UDim.new(0, 25),
					PaddingRight = UDim.new(0, 25),
				},

				Libraries.scope:New "ImageLabel" {
					Name = "Icon",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(20, 20),
					Image = "rbxassetid://8445470826",
					ImageColor3 = Libraries.Color "--Sidebar-Icon",
					ImageRectOffset = Vector2.new(4, 4),
					ImageRectSize = Vector2.new(96, 96)
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					Text = "Appearance",
					TextSize = 16,
					TextColor3 = Libraries.Color "--Sidebar-Text",
					TextTransparency = 0.3,
				}
			}
		},
		
		["Notifications"] = Libraries.scope:New "TextButton" {
			Name = "Notifications",
			Parent = Navigation.Element.Frame,
			BackgroundColor3 = Libraries.Color "--Sidebar-Button-Odd",
			LayoutOrder = 3,
			AutoButtonColor = true,
			Size = UDim2.new(1, -1, 0, 45),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					Padding = UDim.new(0, 10),
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "UIPadding" {
					PaddingLeft = UDim.new(0, 25),
					PaddingRight = UDim.new(0, 25),
				},

				Libraries.scope:New "ImageLabel" {
					Name = "Icon",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(20, 20),
					Image = "rbxassetid://8445471332",
					ImageColor3 = Libraries.Color "--Sidebar-Icon",
					ImageRectOffset = Vector2.new(4, 504),
					ImageRectSize = Vector2.new(96, 96)
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					Text = "Notifications",
					TextSize = 16,
					TextColor3 = Libraries.Color "--Sidebar-Text",
					TextTransparency = 0.3,
				}
			}
		},
		
		["Debug Bar"] = Libraries.scope:New "TextButton" {
			Name = "Debug Bar",
			Parent = Navigation.Element.Frame,
			BackgroundColor3 = Libraries.Color "--Sidebar-Button-Even",
			LayoutOrder = 4,
			AutoButtonColor = true,
			Size = UDim2.new(1, -1, 0, 45),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					Padding = UDim.new(0, 10),
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "UIPadding" {
					PaddingLeft = UDim.new(0, 25),
					PaddingRight = UDim.new(0, 25),
				},

				Libraries.scope:New "ImageLabel" {
					Name = "Icon",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(20, 20),
					Image = "rbxassetid://8445471173",
					ImageColor3 = Libraries.Color "--Sidebar-Icon",
					ImageRectOffset = Vector2.new(804, 704),
					ImageRectSize = Vector2.new(96, 96)
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					Text = "Debug Bar",
					TextSize = 16,
					TextColor3 = Libraries.Color "--Sidebar-Text",
					TextTransparency = 0.3,
				}
			}
		},	
		
		["Keybinds"] = Libraries.scope:New "TextButton" {
			Name = "Keybinds",
			Parent = Navigation.Element.Frame,
			BackgroundColor3 = Libraries.Color "--Sidebar-Button-Even",
			LayoutOrder = 5,
			AutoButtonColor = true,
			Size = UDim2.new(1, -1, 0, 45),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					Padding = UDim.new(0, 10),
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "UIPadding" {
					PaddingLeft = UDim.new(0, 25),
					PaddingRight = UDim.new(0, 25),
				},

				Libraries.scope:New "ImageLabel" {
					Name = "Icon",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(20, 20),
					Image = "rbxassetid://8445471499",
					ImageColor3 = Libraries.Color "--Sidebar-Icon",
					ImageRectOffset = Vector2.new(804, 4),
					ImageRectSize = Vector2.new(96, 96)
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					Text = "Keybinds",
					TextSize = 16,
					TextColor3 = Libraries.Color "--Sidebar-Text",
					TextTransparency = 0.3,
				}
			}
		},	
		
		["Topbar"] = Libraries.scope:New "TextButton" {
			Name = "Topbar",
			Parent = Navigation.Element.Frame,
			BackgroundColor3 = Libraries.Color "--Sidebar-Button-Even",
			LayoutOrder = 6,
			AutoButtonColor = true,
			Size = UDim2.new(1, -1, 0, 45),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					Padding = UDim.new(0, 10),
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "UIPadding" {
					PaddingLeft = UDim.new(0, 25),
					PaddingRight = UDim.new(0, 25),
				},

				Libraries.scope:New "ImageLabel" {
					Name = "Icon",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(20, 20),
					Image = "rbxassetid://8445519476",
					ImageColor3 = Libraries.Color "--Sidebar-Icon",
					ImageRectOffset = Vector2.new(784, 420),
					ImageRectSize = Vector2.new(48, 48)
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					Text = "Topbar",
					TextSize = 16,
					TextColor3 = Libraries.Color "--Sidebar-Text",
					TextTransparency = 0.3,
				}
			}
		},		
	}
	
	--
	
	local Pages = {
		["General"] = Libraries.Windows "ScrollFrame" {
			Size = UDim2.fromOffset(614, 457)
		},
		
		["Appearance"] = Libraries.Windows "ScrollFrame" {
			Size = UDim2.fromOffset(614, 457)
		},
		
		["Notifications"] = Libraries.Windows "ScrollFrame" {
			Size = UDim2.fromOffset(614, 457)
		},
		
		["Debug Bar"] = Libraries.Windows "ScrollFrame" {
			Size = UDim2.fromOffset(614, 457)
		},
		
		["Keybinds"] = Libraries.Windows "ScrollFrame" {
			Size = UDim2.fromOffset(614, 457)
		},
		
		["Topbar"] = Libraries.Windows "ScrollFrame" {
			Size = UDim2.fromOffset(614, 457)
		},
	}
	
	--
	
	for pageName, scrollFrame in Pages do

		local servicePage = Libraries.Windows "Page" {
			Name = pageName,
			Parent = Properties.Element,
			Size = UDim2.new(0, 614, 1, 0)
		}

		scrollFrame.Element.Parent = servicePage.Element
		
		--
		
		if script:FindFirstChild(pageName) and script:FindFirstChild(pageName):IsA("ModuleScript") then
			for _, batch in require(script:FindFirstChild(pageName)) do
				local category = batch.Name
				batch.Name = nil
				
				Libraries.Common "Header" {
					Parent = scrollFrame.Element,
					LayoutOrder = #scrollFrame.Element:GetChildren()
				}:Title(category)
				
				for _, pageElement in batch do
					if typeof(pageElement) == "Instance" and pageElement:IsA("GuiObject") then 
						pageElement.Parent = scrollFrame.Element
						pageElement.LayoutOrder = #scrollFrame.Element:GetChildren()
						continue
					end

					pageElement.Element.Parent = scrollFrame.Element
					pageElement.Element.LayoutOrder = #scrollFrame.Element:GetChildren()
				end 
				
				Libraries.Common "Empty" {
					Parent = scrollFrame.Element,
					Size = UDim2.new(1, 0, 0, 35),
					LayoutOrder = #scrollFrame.Element:GetChildren(),
				}
			end
		end
	end
	
	--

	task.spawn(function()
		for pageName, TextButton in Services do
			TextButton.Activated:Connect(function() 
				for _, page in Properties.Element:GetChildren() do
					if not page:IsA("Frame") then continue end
					page.Visible = page.Name == pageName 
				end
				
				for _, button in Services do
					button.BackgroundColor3 = Libraries.Color(button == TextButton and `--Sidebar-Button-Active` or (button.LayoutOrder % 2 == 0 and `--Sidebar-Button-Even` or `--Sidebar-Button-Odd`))
					button.Icon.ImageColor3 = Libraries.Color(`--Sidebar-Icon{button == TextButton and `-Active` or ``}`)
					button.Label.TextColor3 = Libraries.Color(`--Sidebar-Text{button == TextButton and `-Active` or ``}`)
				end
			end)
		end
		
		for _, page in Properties.Element:GetChildren() do
			if not page:IsA("Frame") then continue end
			page.Visible = page.Name == "General" 
		end
		
		local TextButton = Services.General
		for _, button in Services do
			button.BackgroundColor3 = Libraries.Color(button == TextButton and `--Sidebar-Button-Active` or (button.LayoutOrder % 2 == 0 and `--Sidebar-Button-Even` or `--Sidebar-Button-Odd`))
			button.Icon.ImageColor3 = Libraries.Color(`--Sidebar-Icon{button == TextButton and `-Active` or ``}`)
			button.Label.TextColor3 = Libraries.Color(`--Sidebar-Text{button == TextButton and `-Active` or ``}`)
		end
	end)
	
	--
	
	return {

		TabChanged = Libraries.Maid.signal("TabChanged"),

		ChangeTab = function( self: any, tabName: string )
			self.TabChanged:Fire(tabName)

			for _, page in Properties.Element:GetChildren() do
				if not page:IsA("Frame") then continue end
				page.Visible = page.Name == tabName 
			end	

			return self	
		end,

		Enable = function( self: any )
			Page.Element.Visible = true
			return self
		end,

		Disable = function( self: any )
			Page.Element.Visible = false
			return self
		end,
	}		
end