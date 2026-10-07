----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || MAIN || -----
return function( panel: any ) 
	
	local Page = Libraries.Windows "Page" {
		Parent = panel.Section,
		Size = UDim2.fromScale(1, 1),
		Name = "Manager",
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
		
		["Workspace"] = Libraries.scope:New "TextButton" {
			Name = "Workspace",
			Parent = Navigation.Element.Frame,
			BackgroundColor3 = Libraries.Color "--Sidebar-Button-Odd",
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
					Size = UDim2.fromOffset(22, 22),
					Image = "rbxassetid://15557991882",
				},
				
				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					Text = "Workspace",
					TextSize = 16,
					TextColor3 = Libraries.Color "--Primary-Text-Color",
					TextTransparency = 0.3,
				}
			}
		},
		
		["Terrain"] = Libraries.scope:New "TextButton" {
			Name = "Terrain",
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
					Size = UDim2.fromOffset(22, 22),
					Image = "rbxassetid://16107818020",
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					Text = "Terrain",
					TextSize = 16,
					TextColor3 = Libraries.Color "--Primary-Text-Color",
					TextTransparency = 0.3,
				}
			}
		},
		
		["Lighting"] = Libraries.scope:New "TextButton" {
			Name = "Lighting",
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
					Size = UDim2.fromOffset(22, 22),
					Image = "rbxassetid://15557982866",
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					Text = "Lighting",
					TextSize = 16,
					TextColor3 = Libraries.Color "--Primary-Text-Color",
					TextTransparency = 0.3,
				}
			}
		},		
		
		["CoreGui"] = Libraries.scope:New "TextButton" {
			Name = "CoreGui",
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
					Size = UDim2.fromOffset(22, 22),
					Image = "rbxassetid://15558006668",
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					Text = "CoreGui",
					TextSize = 16,
					TextColor3 = Libraries.Color "--Primary-Text-Color",
					TextTransparency = 0.3,
				}
			}
		},	
		
		["Sounds"] = Libraries.scope:New "TextButton" {
			Name = "Sounds",
			Parent = Navigation.Element.Frame,
			BackgroundColor3 = Libraries.Color "--Sidebar-Button-Odd",
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
					Size = UDim2.fromOffset(22, 22),
					Image = "rbxassetid://15558011871",
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					Text = "Sounds",
					TextSize = 16,
					TextColor3 = Libraries.Color "--Primary-Text-Color",
					TextTransparency = 0.3,
				}
			}
		},			
	}	
		
	local Pages = {
		["Workspace"] = {
			Libraries.Windows "Title" {}
				:Icon("rbxassetid://15557991882")
				:Title("Workspace")
				:Description("View and adjust properties of workspace."),


			Libraries.Windows "Categories" {}
				:Select("BEHAVIOR")
				:SetOptions {
					"BEHAVIOR",
				},	
			
			Libraries.Windows "ScrollFrame" {
				Size = UDim2.fromOffset(614, 360)
			}
		},
		
		["Terrain"] = {
			Libraries.Windows "Title" {}
				:Icon("rbxassetid://16107818020")
				:Title("Terrain")
				:Description("View and adjust properties of terrain."),


			Libraries.Windows "Categories" {}
				:Select("BEHAVIOR")
				:SetOptions {
					"BEHAVIOR",
					"MATERIALS"
				},	

			Libraries.Windows "ScrollFrame" {
				Size = UDim2.fromOffset(614, 360)
			}
		},
		
		["Lighting"] = {
			Libraries.Windows "Title" {}
				:Icon("rbxassetid://15557982866")
				:Title("Lighting")
				:Description("View and adjust properties of lighting."),


			Libraries.Windows "Categories" {}
				:Select("APPEARANCE")
				:SetOptions {
					"APPEARANCE",
					"BEHAVIOR",
					"SKYBOX"
				},	
			
			Libraries.Windows "ScrollFrame" {
				Size = UDim2.fromOffset(614, 360)
			}
		},
			
		["CoreGui"] = {
			Libraries.Windows "Title" {}
				:Icon("rbxassetid://15558006668")
				:Title("CoreGui")
				:Description("View and adjust properties of coregui."),


			Libraries.Windows "Categories" {}
				:Select("BEHAVIOR")
				:SetOptions {
					"BEHAVIOR",
				},	

			Libraries.Windows "ScrollFrame" {
				Size = UDim2.fromOffset(614, 360)
			}
		},
		
		["Sounds"] = {
			Libraries.Windows "Title" {}
				:Icon("rbxassetid://15558011871")
				:Title("Sounds")
				:Description("View and adjust properties of sounds."),


			Libraries.Windows "Categories" {}
				:Select("BEHAVIOR")
				:SetOptions {
					"BEHAVIOR",
				},	
			
			Libraries.Windows "ScrollFrame" {
				Size = UDim2.fromOffset(614, 360)
			}
		},		
	}
	
	
	
	--
	
	for pageName, array in Pages do

		local servicePage = Libraries.Windows "Page" {
			Name = pageName,
			Parent = Properties.Element,
			Size = UDim2.fromOffset(614, 457)
		}

		--
		
		array[1].Element.Parent = servicePage.Element
		array[2].Element.Parent = servicePage.Element
		array[3].Element.Parent = servicePage.Element
		
		--
		
		if script:FindFirstChild(pageName) and script:FindFirstChild(pageName):IsA("ModuleScript") then
			for category, batch in require(script:FindFirstChild(pageName)) do 
				for _, pageElement in batch do
					if typeof(pageElement) == "Instance" and pageElement:IsA("GuiObject") then 
						pageElement.Parent = array[3].Element
						pageElement.Visible = category:lower() == array[2].Option:lower()
						pageElement:AddTag(`#category-{category:lower()}`)
						
						continue
					end
					
					pageElement.Element.Parent = array[3].Element
					pageElement.Element.Visible = category:lower() == array[2].Option:lower()
					pageElement.Element:AddTag(`#category-{category:lower()}`)
				end 
			end
		end
		
		--
		
		array[2].Selected:Connect(function(category)
			for _, button in array[3].Element:GetChildren() do
				if not button:IsA("GuiObject") then continue end
				
				button.Visible = button:HasTag(`#category-{category:lower()}`)
			end
		end)	
	end	
	
	task.spawn(function()
		for pageName, TextButton in Services do
			TextButton.Activated:Connect(function() 
				for _, page in Properties.Element:GetChildren() do
					if not page:IsA("Frame") then continue end
					page.Visible = page.Name == pageName 
				end
				
				for _, button in Services do
					button.BackgroundColor3 = Libraries.Color(button == TextButton and `--Sidebar-Button-Active` or (button.LayoutOrder % 2 == 0 and `--Sidebar-Button-Even` or `--Sidebar-Button-Odd`))
					button.Label.TextColor3 = Libraries.Color(`--Sidebar-Text{button == TextButton and `-Active` or ``}`)
				end	
			end)
		end
		
		for _, page in Properties.Element:GetChildren() do
			if not page:IsA("Frame") then continue end
			page.Visible = page.Name == "General" 
		end

		local TextButton = Services.Workspace
		for _, button in Services do
			button.BackgroundColor3 = Libraries.Color(button == TextButton and `--Sidebar-Button-Active` or (button.LayoutOrder % 2 == 0 and `--Sidebar-Button-Even` or `--Sidebar-Button-Odd`))
			button.Label.TextColor3 = Libraries.Color(`--Sidebar-Text{button == TextButton and `-Active` or ``}`)
		end
		
		Libraries.Theme.Updated.Event:Connect(function()
			for _, button in Services do
				button.BackgroundColor3 = Libraries.Color(button == TextButton and `--Sidebar-Button-Active` or (button.LayoutOrder % 2 == 0 and `--Sidebar-Button-Even` or `--Sidebar-Button-Odd`))
				button.Label.TextColor3 = Libraries.Color(`--Sidebar-Text{button == TextButton and `-Active` or ``}`)
			end
		end)	
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
			
			for _, button in Services do
				button.BackgroundColor3 = Libraries.Color(button.Name == tabName and `--Sidebar-Button-Active` or (button.LayoutOrder % 2 == 0 and `--Sidebar-Button-Even` or `--Sidebar-Button-Odd`))
				button.Label.TextColor3 = Libraries.Color(`--Sidebar-Text{button.Name == tabName and `-Active` or ``}`)
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