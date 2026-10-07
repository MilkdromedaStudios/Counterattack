----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || MAIN || -----
return function( panel: any )
	
	local Operators = {
		Libraries.scope:New "UIListLayout" {
			Parent = panel.Top.Left,
			Padding = UDim.new(0, 5),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,	
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},

		Libraries.scope:New "UIPadding" {
			Parent = panel.Top.Left,
			PaddingLeft = UDim.new(0, 12),
		},

		Libraries.scope:New "UIListLayout" {
			Parent = panel.Top.Center,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,	
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},

		Libraries.scope:New "UIListLayout" {
			Parent = panel.Top.Right,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,	
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
	}
	
	local Gui = {
		["Cloud"] = Libraries.scope:New "ImageLabel" {
			Name = "Cloud",
			Parent = panel.Top.Left,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(18, 18),
			Image = "rbxassetid://76543842866264",
			ImageColor3 = color "--Primary-Text-Color",
			ImageRectOffset = Vector2.new(324, 764),
			ImageRectSize = Vector2.new(36, 36),
		},

		["Clock"] = Libraries.scope:New "TextLabel" {
			Name = "Clock",
			Parent = panel.Top.Left,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.fromScale(0, 1),
			FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
			TextSize = 15,
			TextColor3 = Libraries.Color "--Clock-Text-Color",
			Text = "N/A",
		}	,
		
		["Logo"] = Libraries.scope:New "ImageLabel" {
			Name = "Logo",
			Parent = panel.Top.Center,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(20, 20),
			Image = "rbxassetid://13636059383",
			ImageColor3 = color "--Primary-Text-Color",
		}		
	}	
	
	
	--
	
	local Debounces = {
		IsDragging = false,
		InitialDrag = Vector2.new(),
		InitialPos = UDim2.fromScale(0, 0),
	}
	
	panel.Element.MainFrame.Top.InputBegan:Connect(function(input)
		if not Libraries.Config.Draggable or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then return end

		Debounces["IsDragging"] = true
		Debounces["InitialDrag"] = input.Position
		Debounces["InitialPos"] = panel.Element.Position

		input.Changed:Connect(function()
			if input.UserInputState ~= Enum.UserInputState.End then return end
			Debounces["IsDragging"] = false
		end)
	end)

	panel.Element.MainFrame.Top.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		Debounces["DragInput"] = input
	end)

	game:GetService("UserInputService").InputChanged:Connect(function(input)
		if input ~= Debounces["DragInput"] then return end
		if not Debounces["IsDragging"] then return end
		
		local delta = input.Position - (Debounces["InitialDrag"] or UDim2.new(0, 0, 0, 0))
		panel.Element.Position = UDim2.new(Debounces["InitialPos"].X.Scale, Debounces["InitialPos"].X.Offset + delta.X, Debounces["InitialPos"].Y.Scale, Debounces["InitialPos"].Y.Offset + delta.Y)
		shared["Nexus Dynamics"].Position = UDim2.new(Debounces["InitialPos"].X.Scale, Debounces["InitialPos"].X.Offset + delta.X, Debounces["InitialPos"].Y.Scale, Debounces["InitialPos"].Y.Offset + delta.Y) 

		if panel.Element.Position.Y.Scale == 0.5 and panel.Element.Position.Y.Offset >= 500 then
			Debounces["IsDragging"] = false
			Debounces["InitialDrag"] = UDim2.new(0.5, 0, 0.5, 0)
			Debounces["InitialPos"] = UDim2.new(0.5, 0, 0.5, 0)

			Libraries:Close()
			_G["topbar-client@2.0.6"]:Show()
			
			repeat task.wait() until not panel.Element.Visible
			panel.Element.Position = UDim2.new(0.5, 0, 0.5, 0)
			shared["Nexus Dynamics"].Position = UDim2.fromScale(0.5, 0.5)
		end
	end)
	
	
	panel.Element.MainFrame.Top.Right.Close.MouseButton1Click:Connect(function()
		Libraries:Close()
		_G["topbar-client@2.0.6"]:Show()
	end)
	
	task.spawn(function()
		while task.wait(1) and shared["Nexus Dynamics"] do
			Gui.Clock.Text = `• {Libraries.Util.GetLocalTime(Libraries.Config.Use24HourClock and 24 or 12)}`
			Gui.Clock.Visible = Libraries.Config.ClockEnabled
		end
	end)
	
	Libraries.Libraries.Theme.ThemeUpdated.Event:Connect(function()
		Gui.Cloud.ImageColor3 = color "--Primary-Text-Color"
		Gui.Clock.TextColor3 = color "--Clock-Text-Color"
		Gui.Logo.ImageColor3 = color "--Primary-Text-Color"
	end)
end