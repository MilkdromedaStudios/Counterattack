----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || MAIN || -----
return function( panel: any )

	local Operators = {
		Libraries.scope:New "UIListLayout" {
			Parent = panel.Bottom.Left,
			Padding = UDim.new(0, 20),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,	
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},

		Libraries.scope:New "UIPadding" {
			Parent = panel.Bottom.Left,
			PaddingLeft = UDim.new(0, 15),
		},
		
		Libraries.scope:New "UIListLayout" {
			Parent = panel.Bottom.Right,
			Padding = UDim.new(0, 25),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,	
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},

		Libraries.scope:New "UIPadding" {
			Parent = panel.Bottom.Right,
			PaddingRight = UDim.new(0, 15),
		},	
	}

	local Gui = {
		
		["Errors"] = Libraries.scope:New "Frame" {
			Name = "Errors",
			Parent = panel.Bottom.Left,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 1),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,	
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "ImageLabel" {
					Name = "Icon",
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(13, 13),
					Image = "rbxassetid://8445470559",
					ImageColor3 = color "--Error",
					ImageRectOffset = Vector2.new(904, 504),
					ImageRectSize = Vector2.new(96, 96),
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = 13,
					TextColor3 = Libraries.Color "--Error",
					
					Text = "0",

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
						},
					}
				}
			}
		},

		["Warnings"] = Libraries.scope:New "Frame" {
			Name = "Warnings",
			Parent = panel.Bottom.Left,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 1),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,	
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "ImageLabel" {
					Name = "Icon",
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(13, 13),
					Image = "rbxassetid://8445470392",
					ImageColor3 = color "--Warning",
					ImageRectOffset = Vector2.new(104, 704),
					ImageRectSize = Vector2.new(96, 96),
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = 13,

					TextColor3 = Libraries.Color "--Warning",
					
					Text = "0",

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
						},
					}
				}
			}
		},

		["Memory Usage"] = Libraries.scope:New "Frame" {
			Name = "Memory Usage",
			Parent = panel.Bottom.Left,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 1),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,	
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "TextLabel" {
					Name = "Title",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = 13,

					TextColor3 = Libraries.Color "--Warning",
					
					Text = "Memory Usage:",

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
						},
					}
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = 13,

					TextColor3 = Libraries.Color "--Primary-Text-Color",
					
					Text = "0 MB",

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
						},
					}
				}
			}
		},	

		["Avg. Ping"] = Libraries.scope:New "Frame" {
			Name = "Avg. Ping",
			Parent = panel.Bottom.Left,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 1),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,	
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "TextLabel" {
					Name = "Title",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = 13,

					TextColor3 = Libraries.Color "--Warning",
					
					Text = "Avg. Ping:",

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
						},
					}
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = 13,

					TextColor3 = Libraries.Color "--Primary-Text-Color",
					
					Text = "0 ms",

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
						},
					}
				}
			}
		},
	
		["FPS"] = Libraries.scope:New "Frame" {
			Name = "FPS",
			Parent = panel.Bottom.Right,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 1),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,	
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "TextLabel" {
					Name = "Title",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = 13,

					TextColor3 = Libraries.Color "--Primary-Text-Color",
					
					Text = "FPS:",

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
						},
					}
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = 13,

					TextColor3 = Libraries.Color "--Primary-Text-Color",
					
					Text = "0",

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
						},
					}
				}
			}
		},

		["Region"] = Libraries.scope:New "Frame" {
			Name = "Region",
			Parent = panel.Bottom.Right,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 1),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,	
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "TextLabel" {
					Name = "Title",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = 13,

					TextColor3 = Libraries.Color "--Primary-Text-Color",
					
					Text = "Region:",

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
						},
					}
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = 13,

					TextColor3 = Libraries.Color "--Primary-Text-Color",
					
					Text = "N/A",

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
						},
					}
				}
			}
		},

		["Version"] = Libraries.scope:New "Frame" {
			Name = "Version",
			Parent = panel.Bottom.Right,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0, 1),

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,	
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				Libraries.scope:New "TextLabel" {
					Name = "Title",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = 13,

					TextColor3 = Libraries.Color "--Primary-Text-Color",
					
					Text = "Version:",

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
						},
					}
				},

				Libraries.scope:New "TextLabel" {
					Name = "Label",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0, 1),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = 13,

					TextColor3 = Libraries.Color "--Primary-Text-Color",
					
					Text = "0",

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 8),
						},
					}
				}
			}
		},	
	}
	

	--


	local log = { 0, 0 }

	--

	task.spawn(function()
		local cache = {game:GetService("RunService"):IsStudio() and time or os.clock, nil, game:GetService("RunService"):IsStudio() and time() or os.clock(), {}}
		
		game:GetService("LogService").MessageOut:Connect(function(message, messageType)
			log[1] += messageType == Enum.MessageType.MessageError and 1 or 0
			log[2] += messageType == Enum.MessageType.MessageWarning and 1 or 0
		end)

		for _, line in game:GetService("LogService"):GetLogHistory() do
			log[1] += line.messageType == Enum.MessageType.MessageError and 1 or 0
			log[2] += line.messageType == Enum.MessageType.MessageWarning and 1 or 0
		end
		
		local connection; connection = game:GetService("RunService").Heartbeat:Connect(function()
			if not shared["Nexus Dynamics"] then connection:Disconnect() end
			
			pcall(function()
				cache[2] = cache[1]()
				for Index = #cache[4], 1, -1 do
					cache[4][Index + 1] = cache[4][Index] >= cache[2] - 1 and cache[4][Index] or nil
				end

				cache[4][1] = cache[2]

				local FPS = math.clamp((math.floor((cache[1]() - cache[3] >= 1 and #cache[4] or #cache[4] / (cache[1]() - cache[3])))*10)/10, 0, 999)
				local Physics = math.clamp(math.floor(game:GetService("Stats").PhysicsReceiveKbps * 1000)/10, 0, 999)

				Gui.FPS.Label.Text = `{FPS % 1 == 0 and FPS..".0" or FPS}/s`
				Gui.Errors.Label.Text, Gui.Warnings.Label.Text = log[1], log[2]

				--

				Gui["Memory Usage"].Visible = Libraries.Config.MemoryUsage
				Gui["Avg. Ping"].Visible = Libraries.Config.AvgPing
				Gui.Region.Visible = Libraries.Config.Region
				Gui.Version.Visible = Libraries.Config.Version
				Gui.Errors.Visible, Gui.Warnings.Visible = Libraries.Config.Errors, Libraries.Config.Warnings
				Gui.FPS.Visible = Libraries.Config.FPS

				panel.Section.Size = Libraries.Config.DebugbarEnabled and UDim2.new(1, 0, 0, 458) or UDim2.new(1, 0, 0, 488)
				panel.Bottom.Visible = Libraries.Config.DebugbarEnabled
			end)
		end)
		
		while task.wait(0.5) and shared["Nexus Dynamics"] do
			local lastTick = tick(); script.RemoteFunction:InvokeServer()
			local delta = math.floor( (tick() - lastTick) * 1000)

			--

			Gui["Memory Usage"].Label.Text = `N/A MB`
			Gui["Avg. Ping"].Label.Text = `{delta} ms`
		end
	end)	
	
	--
	
	task.spawn(function()
		while task.wait(1) and shared["Nexus Dynamics"] do
			Gui.Region.Label.Text = `{game:GetService("Players"):GetAttribute("ServerRegion") or "N/A"}`
			Gui.Version.Label.Text = "2.0.6"
		end
	end)
	
	--
	
	Libraries.Libraries.Theme.ThemeUpdated.Event:Connect(function()
		Gui.Errors.Icon.ImageColor3 = color "--Error"
		Gui.Errors.Label.TextColor3 = color "--Error"
		Gui.Warnings.Icon.ImageColor3 = color "--Warning"
		Gui.Warnings.Label.TextColor3 = color "--Warning"
		Gui["Memory Usage"].Title.TextColor3 = color "--Warning"
		Gui["Memory Usage"].Label.TextColor3 = color "--Primary-Text-Color"
		Gui["Avg. Ping"].Title.TextColor3 = color "--Warning"
		Gui["Avg. Ping"].Label.TextColor3 = color "--Primary-Text-Color"
		Gui.FPS.Title.TextColor3 = color "--Description-Text-Color"
		Gui.FPS.Label.TextColor3 = color "--Primary-Text-Color"
		Gui.Region.Title.TextColor3 = color "--Description-Text-Color"
		Gui.Region.Label.TextColor3 = color "--Primary-Text-Color"
		Gui.Version.Title.TextColor3 = color "--Description-Text-Color"
		Gui.Version.Label.TextColor3 = color "--Primary-Text-Color"
	end)
end