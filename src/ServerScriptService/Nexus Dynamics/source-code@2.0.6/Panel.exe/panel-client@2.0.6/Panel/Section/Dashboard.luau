----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || MAIN || -----
return function( panel: any )
	
	local Page = Libraries.Windows "Page" {
		Name = "Dashboard",
		Parent = panel.Section,
		Size = UDim2.fromScale(1, 1),
	}
		
	local Profile = Libraries.scope:New "Frame" {
		Name = "Profile",
		Parent = Page.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Libraries.Color "--Profile-Background",
		LayoutOrder = 0,
		Size = UDim2.fromScale(1, 0),

		[Libraries.scope.Children] = {

			Libraries.scope:New "Frame" {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),

				[Libraries.scope.Children] = {

					Libraries.scope:New "UIListLayout" {
						Padding = UDim.new(0, 20),
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					},

					Libraries.scope:New "UIPadding" {
						PaddingTop = UDim.new(0, 25),
					},

					Libraries.scope:New "Frame" {
						Name = "Border",
						AnchorPoint = Vector2.new(0, 1),
						BackgroundColor3 = color "--Border",
						Position = UDim2.fromScale(0, 1),
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 1),
					},

					Libraries.scope:New "Frame" {
						Name = "Profile",
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						LayoutOrder = 1,
						Size = UDim2.new(),

						[Libraries.scope.Children] = {

							Libraries.scope:New "UIListLayout" {
								Padding = UDim.new(0, 10),
								SortOrder = Enum.SortOrder.LayoutOrder,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							},

							Libraries.Common "UserThumbnail" {
								Size = UDim2.fromOffset(54, 54),
								LayoutOrder = 1,
							}:SetUserId(game:GetService("Players").LocalPlayer.UserId).Element,

							Libraries.scope:New "TextLabel" {
								Name = "Nickname",
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								LayoutOrder = 2,
								Size = UDim2.fromOffset(0, 13),
								FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
								Text = `{game:GetService("Players").LocalPlayer.DisplayName}(@{game:GetService("Players").LocalPlayer.Name})`,
								TextSize = 18,
								TextColor3 = Libraries.Color "--Primary-Text-Color",
								TextTransparency = 0,
							},

							Libraries.scope:New "TextLabel" {
								Name = "Status",
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								LayoutOrder = 3,
								Size = UDim2.fromOffset(0, 13),
								FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
								Text = "Welcome Back",
								TextSize = 14,
								TextColor3 = Libraries.Color "--Primary-Text-Color",
								TextTransparency = 0.5,
							}	
						}
					},
				}
			},

			Libraries.scope:New "ImageLabel" {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Image = "rbxassetid://133748586430296",
				ImageColor3 = Libraries.Color "--Profile-Card-Color",
				ImageTransparency = 0.65,
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.new(1, 0, 0, 300),
				ZIndex = 0
			},
			
			Libraries.scope:New "Frame" {
				Name = "Bottom",
				LayoutOrder = 4,
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 30),

				[Libraries.scope.Children] = {

					Libraries.scope:New "Frame" {
						Name = "Right",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						
						[Libraries.scope.Children] = {
							
							Libraries.scope:New "UIListLayout" {
								Padding = UDim.new(0, 25),
								FillDirection = Enum.FillDirection.Horizontal,
								SortOrder = Enum.SortOrder.LayoutOrder,
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							},
							
							Libraries.scope:New "UIPadding" {
								PaddingRight = UDim.new(0, 15),
							},
							
							Libraries.scope:New "Frame" {
								Name = "Players",
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
										TextTransparency = 0.65,
										Text = "Players:",

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
										TextTransparency = 0.3,
										Text = "0/0",

										[Libraries.scope.Children] = {

											Libraries.scope:New "UIPadding" {
												PaddingLeft = UDim.new(0, 8),
											},
										}
									}
								}
							},	
							
							Libraries.scope:New "Frame" {
								Name = "Uptime",
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
										TextTransparency = 0.65,
										Text = "Uptime:",

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
										TextTransparency = 0.3,
										Text = "00:00:00",

										[Libraries.scope.Children] = {

											Libraries.scope:New "UIPadding" {
												PaddingLeft = UDim.new(0, 8),
											},
										}
									}
								}
							},		
						}
					},	
				}
			},	
		}
	}
	
	local ScrollFrame = Libraries.Windows "ScrollFrame" {
		Parent = Page.Element,
		Size = UDim2.new(1, 0, 0, 329),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		LayoutOrder = 3,
	}
		
	local Headers = {
		["Server List"] = Libraries.Common "Header" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 1,
		}:Title("SERVER LIST"),
		
		["Versions"] = Libraries.Common "Header" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 7,
		}:Title("VERSIONS"),
		
		["Experience Holder"] = Libraries.Common "Header" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 11,
		}:Title("EXPERIENCE HOLDER"),
	}
	
	local Empties = { 
		
		Libraries.Common "Empty" {
			Parent = Page.Element.ScrollingFrame,
			Size = UDim2.new(1, 0, 0, 15),
			LayoutOrder = 2,
		},
		
		Libraries.Common "Empty" {
			Parent = Page.Element.ScrollingFrame,
			Size = UDim2.new(1, 0, 0, 15),
			LayoutOrder = 0,
		},
		
		Libraries.Common "Empty" {
			Parent = Page.Element.ScrollingFrame,
			Size = UDim2.new(1, 0, 0, 15),
			LayoutOrder = 6,
		},
		
		Libraries.Common "Empty" {
			Parent = Page.Element.ScrollingFrame,
			Size = UDim2.new(1, 0, 0, 15),
			LayoutOrder = 10,
		},
	}
	
	local Gui = {
			
		UniverseId = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 2,
		}
			:Title("UNIVERSE ID")
			:Description("The ID of the current experience.")
			:Value(game.GameId),


		PlaceId = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 3,
		}
			:Title("PLACE ID")
			:Description("The ID of the current place.")
			:Value(game.PlaceId),

		JobId = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 4,
		}
			:Title("JOB ID")
			:Description("The ID of the current server")
			:Value(game.JobId),


		PrivateServerId = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 5,
		}
			:Title("PRIVATE SERVER ID")
			:Description("The ID of the current private server.")
			:Value(0),
		

		CurrentVersion = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 8,
		}
			:Title("CURRENT VERSION")
			:Description("Place version of the current server.")
			:Value(game.PlaceVersion),


		LatestVersion = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 9,
		}
			:Title("LATEST VERSION")
			:Description("Latest place version of the experience.")
			:Value(game.PlaceVersion),


		CreatorType = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 12,
		}
			:Title("CREATOR TYPE")
			:Description("Whether the experience holder is a player or group.")
			:Value(game.CreatorType.Name),


		CreatorId = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 13,
		}
			:Title("CREATOR ID")
			:Description("The experience holder's userid.")
			:Value(game.PlaceVersion),
	}
	
	
	task.spawn(function()
		while task.wait(1) and shared["Nexus Dynamics"] do
			Profile.Bottom.Right.Players.Label.Text = `{#game:GetService("Players"):GetPlayers()}/{game:GetService("Players").MaxPlayers}`
			Profile.Bottom.Right.Uptime.Label.Text = `{math.floor(workspace.DistributedGameTime/60/60) < 10 and "0"..math.floor(workspace.DistributedGameTime/60/60) or math.floor(workspace.DistributedGameTime/60/60)}:{(math.floor(workspace.DistributedGameTime/60) % 60) < 10 and '0'..(math.floor(workspace.DistributedGameTime/60) % 60) or (math.floor(workspace.DistributedGameTime/60) % 60)}:{(math.floor(workspace.DistributedGameTime%60)) < 10 and "0"..(math.floor(workspace.DistributedGameTime%60)) or (math.floor(workspace.DistributedGameTime%60))}`
		end
	end)
	
	--
	
	Libraries.Libraries.Theme.ThemeUpdated.Event:Connect(function()
		Profile.ImageLabel.ImageColor3 = Libraries.Color "--Profile-Card-Color"
		Profile.BackgroundColor3 = Libraries.Color "--Profile-Background"
	end)
	
	--
	
	return {
		
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