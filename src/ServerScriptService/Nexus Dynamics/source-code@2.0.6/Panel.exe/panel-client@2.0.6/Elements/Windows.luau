----- || LIBRARIES || -----
local Package = script:FindFirstAncestor("panel-client@2.0.6")
local Fusion = require(Package.Libraries.Fusion)
local Maid = require(Package.Libraries.Maid)
local color = require(Package.Libraries.Theme)



----- || TYPE CHECK || -----
type Menu = ("Menu") -> ( properties: {[string]: any} ) -> any
type Panel = ("Panel") -> ( properties: {[string]: any} ) -> any
type Page = ("Page") -> ( properties: {[string]: any} ) -> any
type ScrollFrame = ("ScrollFrame") -> ( properties: {[string]: any} ) -> any
type Sidebar = ("Sidebar") -> ( properties: {[string]: any} ) -> any
type Title = ("Title") -> ( properties: {[string]: any} ) -> any
type Categories = ("Categories") -> ( properties: {[string]: any} ) -> any
type Popup = ("Popup") -> ( properties: {[string]: any} ) -> any
type CommandPrompt = ("CommandPrompt") -> ( properties: {[string]: any} ) -> any

type elements = Panel & Page & ScrollFrame & Sidebar & Title & Categories & Popup & Menu & CommandPrompt



----- || MAIN || -----
return function( name: string )
	return function( inputProperties )

		if name == "Menu" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "CanvasGroup" {
					Name = "Menu",
					GroupTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					Visible = false,

					[scope.Children] = {
						scope:New "Frame" {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromOffset(400, 400),

							[scope.Children] = {
								scope:New "Frame" {
									Name = "Details",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									Position = UDim2.fromScale(0.5, 0.5),
									Rotation = -45,
									Size = UDim2.fromScale(1, 1),

									[scope.Children] = {
										scope:New "ImageLabel" {
											AnchorPoint = Vector2.new(0.5, 0),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.5, 0),
											Rotation = -0.3,
											Size = UDim2.fromScale(0.39, 0.268),

											Image = "rbxassetid://118983816977231",
											ImageTransparency = 0.95,
										},

										scope:New "ImageLabel" {
											AnchorPoint = Vector2.new(0.5, 1),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.5, 1),
											Rotation = 179.7,
											Size = UDim2.fromScale(0.39, 0.268),

											Image = "rbxassetid://118983816977231",
											ImageTransparency = 0.95,
										},

										scope:New "ImageLabel" {
											AnchorPoint = Vector2.new(1, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(1.06, 0.5),
											Rotation = 89,
											Size = UDim2.fromScale(0.39, 0.268),

											Image = "rbxassetid://118983816977231",
											ImageTransparency = 0.95,
										},

										scope:New "ImageLabel" {
											AnchorPoint = Vector2.new(0, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(-0.06, 0.5),
											Rotation = 270,
											Size = UDim2.fromScale(0.39, 0.268),

											Image = "rbxassetid://118983816977231",
											ImageTransparency = 0.95,
										},
									}
								},

								scope:New "Frame" {
									Name = "Hover",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									Position = UDim2.fromScale(0.5, 0.5),
									Size = UDim2.fromScale(1, 1),
									ZIndex = 2,

									[scope.Children] = {
										scope:New "ImageLabel" {
											Name = "Highlight",
											AnchorPoint = Vector2.new(0.5, 0),
											BackgroundTransparency = 1,
											Position = UDim2.new(0.5, -1, 0, 0),
											Size = UDim2.new(0.39, -3, 0.273, 0),

											Image = "rbxassetid://70586284586744",
											ImageColor3 = color "--Accent",
										},

										scope:New "ImageLabel" {
											Name = "Tint",
											AnchorPoint = Vector2.new(0.5, 0),
											BackgroundTransparency = 1,
											Position = UDim2.new(0.5, -1, 0, 0),
											Size = UDim2.new(0.39, -3, 0.273, 0),

											Image = "rbxassetid://118983816977231",
											ImageColor3 = color "--Accent",
											ImageTransparency = 0.8,
										}
									}
								},

								scope:New "Frame" {
									Name = "Middle",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									Position = UDim2.fromScale(0.5, 0.5),
									Size = UDim2.fromScale(0.5, 0.5),
									ZIndex = 2,

									[scope.Children] = {
										scope:New "UICorner" {
											CornerRadius = UDim.new(1, 0),
										}
									}
								},

								scope:New "ImageLabel" {
									Name = "Background",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									Position = UDim2.fromScale(0.5, 0.5),
									Size = UDim2.fromScale(1, 1),

									Image = "rbxassetid://106433145920117",
									ImageColor3 = color "--Bottom-Background",
									ImageTransparency = 0.1,

									[scope.Children] = {
										scope:New "Frame" {
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundColor3 = Color3.new(85, 85, 100),
											Position = UDim2.fromScale(0.5, 0.5),
											Rotation = 67.5,
											Size = UDim2.new(1, 0, 0, 1),

											[scope.Children] = {
												scope:New "UIGradient" {
													Transparency = NumberSequence.new({
														NumberSequenceKeypoint.new(0, 0.9),
														NumberSequenceKeypoint.new(0.25, 0.1),
														NumberSequenceKeypoint.new(0.251, 1),
														NumberSequenceKeypoint.new(0.749, 1),
														NumberSequenceKeypoint.new(0.75, 0.1),
														NumberSequenceKeypoint.new(1, 0.9),
													})
												}
											}
										},

										scope:New "Frame" {
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundColor3 = Color3.new(85, 85, 100),
											Position = UDim2.fromScale(0.5, 0.5),
											Rotation = 22.5,
											Size = UDim2.new(1, 0, 0, 1),

											[scope.Children] = {
												scope:New "UIGradient" {
													Transparency = NumberSequence.new({
														NumberSequenceKeypoint.new(0, 0.9),
														NumberSequenceKeypoint.new(0.25, 0.1),
														NumberSequenceKeypoint.new(0.251, 1),
														NumberSequenceKeypoint.new(0.749, 1),
														NumberSequenceKeypoint.new(0.75, 0.1),
														NumberSequenceKeypoint.new(1, 0.9),
													})
												}
											}
										},

										scope:New "Frame" {
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundColor3 = Color3.new(85, 85, 100),
											Position = UDim2.fromScale(0.5, 0.5),
											Rotation = 112.5,
											Size = UDim2.new(1, 0, 0, 1),

											[scope.Children] = {
												scope:New "UIGradient" {
													Transparency = NumberSequence.new({
														NumberSequenceKeypoint.new(0, 0.9),
														NumberSequenceKeypoint.new(0.25, 0.1),
														NumberSequenceKeypoint.new(0.251, 1),
														NumberSequenceKeypoint.new(0.749, 1),
														NumberSequenceKeypoint.new(0.75, 0.1),
														NumberSequenceKeypoint.new(1, 0.9),
													})
												}
											}
										},	

										scope:New "Frame" {
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundColor3 = Color3.new(85, 85, 100),
											Position = UDim2.fromScale(0.5, 0.5),
											Rotation = 157.5,
											Size = UDim2.new(1, 0, 0, 1),

											[scope.Children] = {
												scope:New "UIGradient" {
													Transparency = NumberSequence.new({
														NumberSequenceKeypoint.new(0, 0.9),
														NumberSequenceKeypoint.new(0.25, 0.1),
														NumberSequenceKeypoint.new(0.251, 1),
														NumberSequenceKeypoint.new(0.749, 1),
														NumberSequenceKeypoint.new(0.75, 0.1),
														NumberSequenceKeypoint.new(1, 0.9),
													})
												}
											}
										},	

										scope:New "TextButton" {
											Name = "Close",
											AnchorPoint = Vector2.new(0.5, 1),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.5, 1),
											Size = UDim2.fromOffset(100, 100),
											Text = "",
										},

										scope:New "TextButton" {
											Name = "Commands",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.765, 0.227),
											Size = UDim2.fromOffset(100, 100),
											Rotation = 45,
											Text = "",
										},

										scope:New "TextButton" {
											Name = "Console",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.23, 0.232),
											Size = UDim2.fromOffset(100, 100),
											Rotation = 45,
											Text = "",
										},

										scope:New "TextButton" {
											Name = "AuditLog",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.765, 0.764),
											Size = UDim2.fromOffset(100, 100),
											Rotation = 45,
											Text = "",
										},

										scope:New "TextButton" {
											Name = "Dashboard",
											AnchorPoint = Vector2.new(0.5, 0),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.5, 0),
											Size = UDim2.fromOffset(100, 100),
											Rotation = 0,
											Text = "",
										},

										scope:New "TextButton" {
											Name = "Settings",
											AnchorPoint = Vector2.new(0, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0, 0.5),
											Size = UDim2.fromOffset(100, 100),
											Rotation = 0,
											Text = "",
										},

										scope:New "TextButton" {
											Name = "Manager",
											AnchorPoint = Vector2.new(1, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(1, 0.5),
											Size = UDim2.fromOffset(100, 100),
											Rotation = 0,
											Text = "",
										},

										scope:New "TextButton" {
											Name = "CommandBar",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.237, 0.757),
											Size = UDim2.fromOffset(100, 100),
											Rotation = 45,
											Text = "",
										},
									}
								},

								scope:New "Frame" {
									Name = "Icons",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundTransparency = 1,
									Position = UDim2.fromScale(0.5, 0.5),
									Size = UDim2.fromScale(1, 1),
									ZIndex = 5,

									[scope.Children] = {
										scope:New "ImageLabel" {
											Name = "Settings",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.125, 0.5),
											Size = UDim2.fromOffset(40, 40),

											Image = "rbxassetid://105061980704922", 
											ImageColor3 = color "--Primary-Text-Color",
											ImageRectOffset = Vector2.new(324, 124), 
											ImageRectSize = Vector2.new(36, 36),
										},

										scope:New "ImageLabel" {
											Name = "AuditLog",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.765, 0.762),
											Size = UDim2.fromOffset(40, 40),

											Image = "rbxassetid://8445470559", 
											ImageColor3 = color "--Primary-Text-Color",
											ImageRectOffset = Vector2.new(604, 604),
											ImageRectSize = Vector2.new(96, 96),
										},

										scope:New "ImageLabel" {
											Name = "Dashboard",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.5, 0.125),
											Size = UDim2.fromOffset(40, 40),

											Image = "rbxassetid://105061980704922",
											ImageColor3 = color "--Primary-Text-Color",
											ImageRectOffset = Vector2.new(644, 404),
											ImageRectSize = Vector2.new(36, 36),
										},

										scope:New "ImageLabel" {
											Name = "Console",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.23, 0.23),
											Size = UDim2.fromOffset(50, 55),

											Image = "rbxassetid://16267350643",
											ImageColor3 = color "--Primary-Text-Color",
										},

										scope:New "ImageLabel" {
											Name = "Commands",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.765, 0.23),
											Size = UDim2.fromOffset(40, 40),

											Image = "rbxassetid://8445470392", 
											ImageColor3 = color "--Primary-Text-Color",
											ImageRectOffset = Vector2.new(304, 104),
											ImageRectSize = Vector2.new(96, 96),
										},

										scope:New "ImageLabel" {
											Name = "Close",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.5, 0.875),
											Size = UDim2.fromOffset(25, 25),

											Image = "rbxassetid://70449303391980",
											ImageColor3 = color "--Close",
										},

										scope:New "ImageLabel" {
											Name = "Manager",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.875, 0.5),
											Size = UDim2.fromOffset(40, 40),

											Image = "rbxassetid://8445470189", 
											ImageColor3 = color "--Primary-Text-Color",
											ImageRectOffset = Vector2.new(904, 304), 
											ImageRectSize = Vector2.new(96, 96),
										},

										scope:New "ImageLabel" {
											Name = "CommandBar",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											Position = UDim2.fromScale(0.24, 0.755),
											Size = UDim2.fromOffset(40, 40),

											Image = "rbxassetid://8445470392",
											ImageColor3 = color "--Primary-Text-Color",
											ImageRectOffset = Vector2.new(804, 4),
											ImageRectSize = Vector2.new(96, 96),
										},
									}
								}
							}
						},

						scope:New "TextButton" {
							Name = "Hitbox",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(1, 1),
							ZIndex = 0,
							Text = "",
						}
					}
				},

				Visible = false,
				State = false,
				Hover = nil,
				PreviousHover = nil,

				FieldOfView = workspace.CurrentCamera.FieldOfView,
				BlurEffect = Instance.new("BlurEffect"),

				--

				Close = function( self: any, showTopbar: boolean? )
					if not self.Visible then return end self.Closed:Fire(showTopbar)
					self.Visible, self.PreviousHover, self.Hover, self.State = false, nil, nil, false

					Maid.tween({
						[self.BlurEffect] = {
							TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {
								Size = 0,
							}
						},

						[workspace.CurrentCamera] = {
							TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								FieldOfView = self.FieldOfView
							}
						},

						[self.Element] = {
							TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.InOut), {
								GroupTransparency = 1,
								Size = UDim2.fromScale(0.9, 0.9),
								Position = UDim2.fromScale(0.5, 0.45),
							}
						}	
					})

					task.delay(0.25, function()
						self.BlurEffect.Parent = game:GetService("Lighting")
						self.Element.Visible = false
					end)
				end,

				Open = function( self: any )
					if self.Visible then return end shared["Nexus Dynamics"]:Close(); self.Opened:Fire()
					self.Visible, self.PreviousHover, self.Hover, self.State = true, nil, nil, true
					self.BlurEffect.Parent = game:GetService("Lighting")

					self.Element.GroupTransparency, self.Element.Size, self.Element.Position = 1, UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.5, 0.6)
					self.Element.Visible, self.Element.Frame.Hover.Tint.ImageTransparency, self.Element.Frame.Hover.Highlight.ImageTransparency = true, 1, 1

					Maid.tween({
						[self.BlurEffect] = {
							TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {
								Size = 12,
							}
						},

						[workspace.CurrentCamera] = {
							TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								FieldOfView = self.FieldOfView + 15
							}
						},

						[self.Element] = {
							TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.InOut), {
								GroupTransparency = 0,
								Size = UDim2.fromScale(1, 1),
								Position = UDim2.fromScale(0.5, 0.5),
							}	
						}	
					})

					self.Element.Frame.Hover.Tint.ImageColor3, self.Element.Frame.Hover.Tint.ImageTransparency = self.Element.Frame.Hover.Rotation == 180 and color "--Close" or color "--Accent", self.Hover and 0.8 or 1 
					self.Element.Frame.Hover.Highlight.ImageColor3, self.Element.Frame.Hover.Highlight.ImageTransparency = self.Element.Frame.Hover.Rotation == 180 and color "--Close" or color "--Accent",  self.Hover and 0 or 1

					local buttons = {
						self.Element.Frame.Background["Dashboard"],
						self.Element.Frame.Background["Commands"],
						self.Element.Frame.Background["Manager"],
						self.Element.Frame.Background["AuditLog"],
						self.Element.Frame.Background["Close"],
						self.Element.Frame.Background["CommandBar"],
						self.Element.Frame.Background["Settings"],
						self.Element.Frame.Background["Console"],
					}

					for x, button in buttons do
						button = self.Element.Frame.Icons[button.Name]
						button.ImageColor3 = self.Hover and ( (x * 45) - 45 == self.Element.Frame.Hover.Rotation and (button.Name ~= "Close" and color "--Primary-Text-Color" or color "--Close") or (button.Name ~= "Close" and color "--Primary-Text-Color" or Color3.fromRGB(175, 33, 33))) or (button.Name ~= "Close" and color "--Primary-Text-Color" or Color3.fromRGB(175, 33, 33))
					end	
				end,

				Redirect = function( self: any, name: string )					
					if table.find({"Dashboard", "Commands", "Manager"}, name) then
						shared["Nexus Dynamics"].Ribbon:ChangeTab(name or "Dashboard")
					elseif name == "AuditLog" then
						shared["Nexus Dynamics"].Ribbon:ChangeTab("AuditLog")
					elseif name == "Console" then
						game:GetService("StarterGui"):SetCore("DevConsoleVisible", not game.StarterGui:GetCore("DevConsoleVisible"))
						self:Close(true)
						return
					elseif name == "Settings" then
						shared["Nexus Dynamics"].Ribbon:ChangeTab("Settings")
					elseif name == "CommandBar" then
						shared["Nexus Dynamics"].Popups.CommandPrompt:Open()
						self:Close(true)
						return
					end

					self:Close()
					shared["Nexus Dynamics"]:Open()
				end,

				Keybinds = {
					["One"] = function( self: any )
						self:Redirect("Dashboard")
						self:Close()
					end,

					["Two"] = function( self: any )
						self:Redirect("Commands")
						self:Close()
					end,

					["Three"] = function( self: any )
						self:Redirect("Manager")
						self:Close()
					end,

					["Four"] = function( self: any )
						self:Redirect("Audit Log")
						self:Close()
					end,

					["Five"] = function( self: any )
						self:Close()
					end,

					["Six"] = function( self: any )
						self:Redirect("Tools")
						self:Close()
					end,

					["Seven"] = function( self: any )
						self:Redirect("Settings")
						self:Close()
					end,

					["Eight"] = function( self: any )
						self:Redirect("Console")
						self:Close()
					end,
				},

				Opened = Maid.signal("Opened"),
				Selected = Maid.signal("Selected"),
				Closed = Maid.signal("Closed"),
			}

			--

			local connection; connection = game:GetService("UserInputService").InputBegan:Connect(function(input, isBusy)
				if not shared["Nexus Dynamics"] then connection:Disconnect() return end
				if not isBusy and properties.Visible and input.UserInputType == Enum.UserInputType.Keyboard and properties.Keybinds[input.KeyCode.Name] then
					properties.Keybinds[input.KeyCode.Name](properties)
				end

				if not shared["Nexus Dynamics"].IsOpen and not isBusy and not shared["Nexus Dynamics"].Keybinding then 
					if input.KeyCode == Enum.KeyCode[shared["Nexus Dynamics"].Config.Menu or "M"] then
						properties.State = not properties.State
						if properties.State then properties:Open() else properties:Close(true) end
					end		

					--

					if input.KeyCode == Enum.KeyCode.Escape then
						properties.State = false 
						properties:Close(true) 
					end 
				end				
			end)

			properties.Element.Hitbox.MouseButton1Down:Connect(function()
				properties:Close(true)
			end)

			task.spawn(function()
				local buttons = {
					properties.Element.Frame.Background["Dashboard"],
					properties.Element.Frame.Background["Commands"],
					properties.Element.Frame.Background["Manager"],
					properties.Element.Frame.Background["AuditLog"],
					properties.Element.Frame.Background["Close"],
					properties.Element.Frame.Background["CommandBar"],
					properties.Element.Frame.Background["Settings"],
					properties.Element.Frame.Background["Console"],
				}

				for x, button in buttons do
					local function rotate(degree)
						Maid.tween({
							[properties.Element.Frame.Hover] = {
								TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),

								{
									Rotation = degree
								}	
							}
						})
					end

					button.MouseEnter:Connect(function()
						if not properties.Visible then return end
						properties.PreviousHover = properties.Hover and (properties.Hover == properties.PreviousHover and properties.PreviousHover or properties.Hover) or properties.PreviousHover

						--

						local previousSection, currentSection = table.find(buttons, properties.PreviousHover), x
						properties.Hover = button

						if (previousSection == currentSection) or (not previousSection and currentSection) then
							properties.Element.Frame.Hover.Rotation = (currentSection * 45) - 45
						end


						local case = {
							[1] = function()
								if table.find({8, 7, 6}, currentSection) then
									properties.Element.Frame.Hover.Rotation = ( (currentSection * 45) - 45 ) + ((previousSection * 45))
								end	
							end,

							[2] = function()
								if table.find({8, 7}, currentSection) then
									properties.Element.Frame.Hover.Rotation = ( (currentSection * 45) - 45 ) + ((previousSection * 45))
								end
							end,

							[3] = function()
								if currentSection == 8 then
									properties.Element.Frame.Hover.Rotation = ( (currentSection * 45) - 45 ) + ((previousSection * 45))
								end
							end,

							[6] = function()
								if table.find({1, 2}, currentSection) then
									properties.Element.Frame.Hover.Rotation = ( (currentSection * 45) - 45 ) + (((previousSection * 45) - 45) - 360)
								end
							end,

							[7] = function()
								if table.find({1, 2, 3}, currentSection) then
									properties.Element.Frame.Hover.Rotation = ( (currentSection * 45) - 45 ) + (((previousSection * 45) - 45) - 360)
								end
							end,

							[8] = function()
								if table.find({1, 2, 3, 4}, currentSection) then
									properties.Element.Frame.Hover.Rotation = ( (currentSection * 45) - 45 ) + (((previousSection * 45) - 45) - 360)
								end
							end,

						}

						if case[previousSection] then case[previousSection]() end
						rotate((currentSection * 45)-45)

						--

						properties.Element.Frame.Hover.Tint.ImageColor3, properties.Element.Frame.Hover.Tint.ImageTransparency = properties.Element.Frame.Hover.Rotation == 180 and color "--Close" or color "--Accent", properties.Hover and 0.8 or 1  
						properties.Element.Frame.Hover.Highlight.ImageColor3, properties.Element.Frame.Hover.Highlight.ImageTransparency = properties.Element.Frame.Hover.Rotation == 180 and color "--Close" or color "--Accent", properties.Hover and 0 or 1

						for x, button in buttons do
							button = properties.Element.Frame.Icons[button.Name]
							button.ImageColor3 = properties.Hover and ( (x * 45) - 45 == properties.Element.Frame.Hover.Rotation and (button.Name ~= "Close" and color "--Primary-Text-Color" or color "--Close") or (button.Name ~= "Close" and color "--Primary-Text-Color" or Color3.fromRGB(175, 33, 33))) or (button.Name ~= "Close" and color "--Primary-Text-Color" or Color3.fromRGB(175, 33, 33))
						end	
					end)	
				end

				properties.Element.Frame.Background.MouseLeave:Connect(function()
					if not properties.Visible then return end

					--

					properties.PreviousHover = properties.Hover
					properties.Hover = false
				end)

				properties.Element.Frame.Middle.MouseEnter:Connect(function()
					if not properties.Visible then return end

					--

					properties.PreviousHover = properties.Hover
					properties.Hover = false
				end)

				game:GetService("UserInputService").InputBegan:Connect(function( input: InputObject, isBusy: boolean )
					if not properties.Visible then return end

					--

					if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and properties.Hover then
						if properties.Hover.Name == "Close" then return properties:Close(true) end				

						properties:Redirect(properties.Hover.Name or "Dashboard")
						properties:Close()

						return
					end
				end)

				game:GetService("UserInputService").InputChanged:Connect(function( input: InputObject, isBusy: boolean )
					if not properties.Visible then return end

					--

					if (input.UserInputType == Enum.UserInputType.MouseMovement) then 

						properties.Element.Frame.Hover.Tint.ImageColor3, properties.Element.Frame.Hover.Tint.ImageTransparency = properties.Element.Frame.Hover.Rotation == 180 and color "--Close" or color "--Accent", properties.Hover and 0.8 or 1 
						properties.Element.Frame.Hover.Highlight.ImageColor3, properties.Element.Frame.Hover.Highlight.ImageTransparency = properties.Element.Frame.Hover.Rotation == 180 and color "--Close" or color "--Accent",  properties.Hover and 0 or 1

						for x, button in buttons do
							button = properties.Element.Frame.Icons[button.Name]
							button.ImageColor3 = properties.Hover and ( (x * 45) - 45 == properties.Element.Frame.Hover.Rotation and (button.Name ~= "Close" and color "--Primary-Text-Color" or color "--Close") or (button.Name ~= "Close" and color "--Primary-Text-Color" or Color3.fromRGB(175, 33, 33))) or (button.Name ~= "Close" and color "--Primary-Text-Color" or Color3.fromRGB(175, 33, 33))
						end
					end
				end)	
			end)

			--

			for propertyName, propertyValue in inputProperties do pcall(function() properties.Elemenet[propertyName] = propertyValue end) end
			return properties	
		end

		--

		if name == "Panel" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "Frame" {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,		
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(822, 566),

					[scope.Children] = {

						scope:New "UIAspectRatioConstraint" {
							AspectRatio = 1.453
						},

						scope:New "CanvasGroup" { 
							Name = "MainFrame",
							GroupColor3 = color "--Tint",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = color "--Background",
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(1, 1),

							[scope.Children] = {

								scope:New "UICorner" {
									CornerRadius = UDim.new(0, 10),
								},

								scope:New "UIListLayout" {
									SortOrder = Enum.SortOrder.LayoutOrder,	
								},

								--

								scope:New "Frame" {
									Name = "Top",	
									LayoutOrder = 1,
									BackgroundColor3 = color "--Top-Background",
									Size = UDim2.new(1, 0, 0, 38),
									ZIndex = 3,

									[scope.Children] = {

										scope:New "Frame" {
											Name = "Border",
											AnchorPoint = Vector2.new(0, 1),
											BackgroundColor3 = color "--Top-Border",
											Position = UDim2.fromScale(0, 1),
											Size = UDim2.new(1, 0, 0, 1),
										},

										scope:New "Frame" {
											Name = "Left",
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),
										},	

										scope:New "Frame" {
											Name = "Center",
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),
										},

										scope:New "Frame" {
											Name = "Right",
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),

											[scope.Children] = {

												scope:New "UIListLayout" {
													FillDirection = Enum.FillDirection.Horizontal,
													SortOrder = Enum.SortOrder.LayoutOrder,	
													HorizontalAlignment = Enum.HorizontalAlignment.Right,
													VerticalAlignment = Enum.VerticalAlignment.Center,
												},

												scope:New "TextButton" {
													Name="Close",
													BackgroundColor3 = color "--Close",
													BackgroundTransparency = 1,
													Size = UDim2.fromScale(1, 1),

													[scope.Children] = { 

														scope:New "UIAspectRatioConstraint" {
															DominantAxis = Enum.DominantAxis.Height,
														},

														scope:New "ImageLabel" {
															AnchorPoint = Vector2.new(0.5, 0.5),
															BackgroundTransparency = 1,
															Position = UDim2.fromScale(0.5, 0.5),
															Size = UDim2.fromOffset(18, 18),
															Image = "rbxassetid://76543842866264",
															ImageColor3 = color "--Primary-Text-Color",
															ImageRectOffset = Vector2.new(284, 4),
															ImageRectSize = Vector2.new(24, 24),
														}
													}
												}
											}
										},
									}
								},

								scope:New "Frame" {
									Name = "Ribbon",
									LayoutOrder = 2,
									BackgroundColor3 = color "--Ribbon-Background",
									Size = UDim2.new(1, 0, 0, 40),
									ZIndex = 2,

									[scope.Children] = {

										scope:New "Frame" {
											Name = "Shadow",
											Size = UDim2.new(1, 0, 0, 10),
											ZIndex = 100,

											[scope.Children] = {

												scope:New "UIGradient" {
													Color = ColorSequence.new(Color3.new()),
													Rotation = 90,
													Transparency = NumberSequence.new(0.756, 1),
												}
											}
										},

										scope:New "Frame" {
											Name = "Border",
											AnchorPoint = Vector2.new(0, 1),
											BackgroundColor3 = color "--Ribbon-Border",
											Position = UDim2.fromScale(0, 1),
											Size = UDim2.new(1, 0, 0, 1),
										},

										scope:New "Frame" {
											Name = "Left",
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),

											[scope.Children] = {

												scope:New "UIListLayout" {
													FillDirection = Enum.FillDirection.Horizontal,
													SortOrder = Enum.SortOrder.LayoutOrder,	
													HorizontalAlignment = Enum.HorizontalAlignment.Left,
													VerticalAlignment = Enum.VerticalAlignment.Center,
												},
											}
										},	

										scope:New "Frame" {
											Name = "Center",
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),

											[scope.Children] = {

												scope:New "UIListLayout" {
													FillDirection = Enum.FillDirection.Horizontal,
													SortOrder = Enum.SortOrder.LayoutOrder,	
													HorizontalAlignment = Enum.HorizontalAlignment.Center,
													VerticalAlignment = Enum.VerticalAlignment.Center,
												},
											}
										},

										scope:New "Frame" {
											Name = "Right",
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),

											[scope.Children] = {

												scope:New "UIListLayout" {
													FillDirection = Enum.FillDirection.Horizontal,
													SortOrder = Enum.SortOrder.LayoutOrder,	
													HorizontalAlignment = Enum.HorizontalAlignment.Right,
													VerticalAlignment = Enum.VerticalAlignment.Center,
												},
											}
										},
									}
								},

								scope:New "Frame" {
									Name = "Section",
									LayoutOrder = 3,
									BackgroundTransparency = 1,
									Size = UDim2.new(1, 0, 0, 458),
									ZIndex = 1,

									[scope.Children] = {

										scope:New "Frame" {
											Name = "Shadow",
											Size = UDim2.new(1, 0, 0, 10),
											ZIndex = 100,
											[scope.Children] = {

												scope:New "UIGradient" {
													Color = ColorSequence.new(Color3.new()),
													Rotation = 90,
													Transparency = NumberSequence.new(0.756, 1),
												}
											}
										}
									}
								},

								scope:New "Frame" {
									Name = "Bottom",
									LayoutOrder = 4,
									BackgroundColor3 = color "--Bottom-Background",
									Size = UDim2.new(1, 0, 0, 30),
									ZIndex = 2,

									[scope.Children] = {

										scope:New "Frame" {
											Name = "Border",
											BackgroundColor3 = color "--Bottom-Border",
											Size = UDim2.new(1, 0, 0, 1),
										},

										scope:New "Frame" {
											Name = "Left",
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),
										},	

										scope:New "Frame" {
											Name = "Right",
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),
										},	
									}
								},
							}
						},

						scope:New "ImageLabel" {
							Name = "Shadow",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,		
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(1.059, 1.088),
							Image = "rbxassetid://15298624572",
							ZIndex = -1,
						},
					}
				},


				--				


				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
			}

			--
			properties.Top = properties.Element.MainFrame.Top
			properties.Ribbon = properties.Element.MainFrame.Ribbon
			properties.Section = properties.Element.MainFrame.Section
			properties.Bottom = properties.Element.MainFrame.Bottom
			properties.Close = properties.Top.Right.Close

			--

			properties.Close.MouseEnter:Connect(function()
				Maid.tween(properties.Close) {
					TweenInfo.new(0.15, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut),

					{
						BackgroundTransparency = 0,
					}
				}
			end)

			properties.Close.MouseLeave:Connect(function()
				Maid.tween(properties.Close) {
					TweenInfo.new(0.15, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut),

					{
						BackgroundTransparency = 1,
					}
				}
			end)

			--

			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.MainFrame.GroupColor3 = color "--Tint"
				properties.Element.MainFrame.BackgroundColor3 = color "--Background"
				properties.Element.MainFrame.Top.BackgroundColor3 = color "--Top-Background"
				properties.Element.MainFrame.Top.Border.BackgroundColor3 = color "--Top-Border"
				properties.Element.MainFrame.Top.Right.Close.BackgroundColor3 = color "--Close"
				properties.Element.MainFrame.Top.Right.Close.ImageLabel.ImageColor3 = color "--Primary-Text-Color"
				properties.Element.MainFrame.Ribbon.BackgroundColor3 = color "--Ribbon-Background"
				properties.Element.MainFrame.Ribbon.Border.BackgroundColor3 = color "--Ribbon-Border"
				properties.Element.MainFrame.Bottom.BackgroundColor3 = color "--Bottom-Background"
				properties.Element.MainFrame.Bottom.Border.BackgroundColor3 = color "--Bottom-Border"
			end)

			--

			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties	
		end

		--

		if name == "Page" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "Frame" {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),

					[scope.Children] = {

						scope:New "UIListLayout" {
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Center
						},	
					}
				},


				--				


				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
			}

			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end

		--

		if name == "ScrollFrame" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "ScrollingFrame" {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.new(),
					ScrollBarImageColor3 = color "--ScrollBar",
					ScrollBarThickness = 0.6,

					[scope.Children] = {

						scope:New "UIListLayout" {
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
						},

						scope:New "UIPadding" {
							PaddingBottom = UDim.new(0, 50),
						}	
					}
				},


				--				


				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,


				--

				Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
					if not properties.Element or #properties.Element:GetChildren() == 0 then return end
					properties.Element.ScrollBarImageColor3 = color "--ScrollBar"
				end),

				--				

				Changed = Maid.signal("Changed"),
			}

			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end

		--

		if name == "Sidebar" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "ScrollingFrame" {
					Name = "Navigation",
					BackgroundColor3 = color "--Sidebar-Background",
					Size = UDim2.fromScale(0.253, 1),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.new(),
					ScrollBarImageColor3 = color "--ScrollBar",
					ScrollBarThickness = 0.6,

					[scope.Children] = {

						scope:New "Frame" {
							Name = "Border",
							AnchorPoint = Vector2.new(1, 0),
							BackgroundColor3 = color "--Border",
							LayoutOrder = 2,
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.new(0, 1, 1, 0),
						},

						scope:New "Frame" {
							BackgroundTransparency = 1,
							Size = UDim2.fromOffset(208, 457),

							[scope.Children] = {

								scope:New "UIListLayout" {
									FillDirection = Enum.FillDirection.Vertical,
									SortOrder = Enum.SortOrder.LayoutOrder,
								},	
							}
						},
					}
				},


				--				


				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
			}

			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.BackgroundColor3 = color "--Sidebar-Background"
				properties.Element.ScrollBarImageColor3 = color "--ScrollBar"
				properties.Element.Border.BackgroundColor3 = color "--Border"
			end)

			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end

		--

		if name == "Title" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "Frame" {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = color "--Title-Background",
					Size = UDim2.fromScale(1, 0),

					[scope.Children] = {

						scope:New "UIListLayout" {
							Padding = UDim.new(0, 10),
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						},

						scope:New "UIPadding" {
							PaddingBottom = UDim.new(0, 30),
							PaddingLeft = UDim.new(0, 35),
							PaddingRight = UDim.new(0, 35),
							PaddingTop = UDim.new(0, 30),
						},

						scope:New "ImageLabel" {
							Name = "Icon",
							BackgroundTransparency = 1,
							LayoutOrder = 1,
							Size = UDim2.fromOffset(50, 50),
							Visible = false,
						},

						scope:New "Frame" {
							BackgroundTransparency = 1,
							LayoutOrder = 2,
							Size = UDim2.fromOffset(300, 50),

							[scope.Children] = {

								scope:New "UIListLayout" {
									Padding = UDim.new(0, 5),
									SortOrder = Enum.SortOrder.LayoutOrder,
									VerticalAlignment = Enum.VerticalAlignment.Center,
								},

								scope:New "TextLabel" {
									Name = "Title",
									AutomaticSize = Enum.AutomaticSize.X,
									BackgroundTransparency = 1,
									LayoutOrder = 1,
									Size = UDim2.fromOffset(0, 30),
									FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
									Text = "N/A",
									TextSize = 30,
									TextColor3 = color "--Primary-Text-Color",
									TextTransparency = 0,
								},

								scope:New "TextLabel" {
									Name = "Description",
									AutomaticSize = Enum.AutomaticSize.X,
									BackgroundTransparency = 1,
									LayoutOrder = 1,
									Size = UDim2.fromOffset(0, 16),
									FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
									Text = "N/A",
									TextSize = 16,
									TextColor3 = color "--Primary-Text-Color",
									TextTransparency = 0.5,
								}
							}
						},					
					}
				},


				--				


				Icon = function( self, rbxassetid: string, imageRectOffset: Vector2?, imageRectSize: Vector2? )
					self.Element.Icon.Image = rbxassetid
					self.Element.Icon.Visible = rbxassetid and #rbxassetid:gsub(" ", "")>0
					if imageRectOffset then self.Element.Icon.ImageRectOffset = imageRectOffset end
					if imageRectSize then self.Element.Icon.ImageRectSize = imageRectSize end
					self.Changed:Fire()
					return self
				end,

				Title = function( self, text: string )
					self.Element.Frame.Title.Text = text
					self.Element.Frame.Title.Visible = text and #text:gsub(" ", "")>0
					self.Changed:Fire()
					return self
				end,

				Description = function( self, text: string )
					self.Element.Frame.Description.Text = text
					self.Element.Frame.Description.Visible = text and #text:gsub(" ", "")>0
					self.Changed:Fire()
					return self
				end,

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
			}

			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.BackgroundColor3 = color "--Title-Background"
				properties.Element.Frame.Title.TextColor3 = color "--Primary-Text-Color"
				properties.Element.Frame.Description.TextColor3 = color "--Description-Text-Color"
			end)

			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end

		--

		if name == "Categories" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Options = {},
				Option = "None",
				Element = scope:New "Frame" {
					BackgroundColor3 = color "--Title-Background",
					Size = UDim2.new(1, 0, 0, 30),
					ClipsDescendants = true,

					[scope.Children] = {

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 35),
							PaddingRight = UDim.new(0, 35),
						},

						scope:New "Frame" {
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),

							[scope.Children] = {

								scope:New "UIListLayout" {
									Padding = UDim.new(0, 15),
									FillDirection = Enum.FillDirection.Horizontal,
									SortOrder = Enum.SortOrder.LayoutOrder,
									VerticalAlignment = Enum.VerticalAlignment.Center,
								},
							}
						},

						scope:New "Frame" {
							Name = "Border",
							AnchorPoint = Vector2.new(0, 1),
							BackgroundColor3 = color "--Border",
							Position = UDim2.new(0, -35, 1, 0),
							Size = UDim2.new(1, 0, 0, 1),
						},					
					}
				},


				--				


				Select = function( self, option: string )
					self.Option = option
					self.Changed:Fire("Option")
					self.Selected:Fire(option)
					return self
				end,

				SetOptions = function( self, options: {string} )
					self.Options = options
					self.Changed:Fire("Options")
					self:Select(options[1])
					return self
				end,

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
				Selected = Maid.signal("Selected"),
			}

			--

			properties.Changed:Connect(function(property)
				if property == "Options" then 
					for _, button in properties.Element.Frame:GetChildren() do 
						if not button:IsA("TextButton") then continue end
						button:Destroy()
					end

					--

					for _, option in properties.Options do

						scope:New "TextButton" {
							AutomaticSize = Enum.AutomaticSize.X,
							Parent = properties.Element.Frame,
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(0, 1),
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
							Text = option,
							TextSize = 15,
							TextColor3 = color "--Primary-Text-Color",
							TextTransparency = 0.3,

							[scope.OnEvent "Activated"] = function()
								properties:Select(option)
							end,

							[scope.Children] = {

								scope: New "UISizeConstraint" {
									MaxSize = Vector2.new(185, math.huge)
								},

								scope:New "UIPadding" {
									PaddingBottom = UDim.new(0, 8),
									PaddingTop = UDim.new(0, 8),
								},

								scope:New "UICorner" {
									CornerRadius = UDim.new(0, 5),
								},

								scope:New "Frame" {
									Name = "Border",
									AnchorPoint = Vector2.new(0, 1),
									BackgroundColor3 = color "--Border",
									Position = UDim2.new(0, 0, 1, 8),
									Size = UDim2.new(1, 0, 0, 2),
								},
							}
						}
					end
				end
			end)

			properties.Selected:Connect(function( option: string )
				for _, button in properties.Element.Frame:GetChildren() do 
					if not button:IsA("TextButton") then continue end

					if button.Text == option then
						button.BackgroundColor3 = color "--Accent"
						button.BackgroundTransparency = 1
						button.TextColor3 = color "--Primary-Text-Color"
						button.TextTransparency = 0

						button.Border.BackgroundColor3 = color "--Accent"
						button.Border.BackgroundTransparency = 0
					else
						button.BackgroundTransparency = 1
						button.TextColor3 = color "--Primary-Text-Color"
						button.TextTransparency = 0.75

						button.Border.BackgroundTransparency = 1
					end
				end
			end)

			--

			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.BackgroundColor3 = color "--Title-Background"
				properties.Element.Border.BackgroundColor3 = color "--Border"
			end)

			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end

		--

		if name == "Popup" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "Frame" {
					BackgroundTransparency = 1,		
					Size = UDim2.fromOffset(245, 100),

					[scope.Children] = {

						scope:New "CanvasGroup" { 
							Name = "MainFrame",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = color "--Background",
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(1, 1),

							[scope.Children] = {

								scope:New "UICorner" {
									CornerRadius = UDim.new(0, 5),
								},

								scope:New "UIListLayout" {
									SortOrder = Enum.SortOrder.LayoutOrder,	
								},

								--

								scope:New "Frame" {
									Name = "Top",	
									LayoutOrder = 1,
									BackgroundColor3 = color "--Top-Background",
									Size = UDim2.new(1, 0, 0, 27),

									[scope.Children] = {

										scope:New "Frame" {
											Name = "Border",
											AnchorPoint = Vector2.new(0, 1),
											BackgroundColor3 = color "--Top-Border",
											Position = UDim2.fromScale(0, 1),
											Size = UDim2.new(1, 0, 0, 1),
										},

										scope:New "Frame" {
											Name = "Left",
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),

											[scope.Children] = {

												scope:New "UIListLayout" {
													FillDirection = Enum.FillDirection.Horizontal,
													SortOrder = Enum.SortOrder.LayoutOrder,	
													HorizontalAlignment = Enum.HorizontalAlignment.Left,
													VerticalAlignment = Enum.VerticalAlignment.Center,
												},
											}
										},	

										scope:New "Frame" {
											Name = "Center",
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),

											[scope.Children] = {

												scope:New "UIListLayout" {
													FillDirection = Enum.FillDirection.Horizontal,
													SortOrder = Enum.SortOrder.LayoutOrder,	
													HorizontalAlignment = Enum.HorizontalAlignment.Center,
													VerticalAlignment = Enum.VerticalAlignment.Center,
												},
											}
										},

										scope:New "Frame" {
											Name = "Right",
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),

											[scope.Children] = {

												scope:New "UIListLayout" {
													FillDirection = Enum.FillDirection.Horizontal,
													SortOrder = Enum.SortOrder.LayoutOrder,	
													HorizontalAlignment = Enum.HorizontalAlignment.Right,
													VerticalAlignment = Enum.VerticalAlignment.Center,
												},

												scope:New "TextButton" {
													Name="Close",
													BackgroundColor3 = color "--Close",
													BackgroundTransparency = 1,
													Size = UDim2.fromScale(1, 1),

													[scope.Children] = { 

														scope:New "UIAspectRatioConstraint" {
															DominantAxis = Enum.DominantAxis.Height,
														},

														scope:New "ImageLabel" {
															AnchorPoint = Vector2.new(0.5, 0.5),
															BackgroundTransparency = 1,
															Position = UDim2.fromScale(0.5, 0.5),
															Size = UDim2.fromOffset(18, 18),
															Image = "rbxassetid://76543842866264",
															ImageColor3 = color "--Primary-Text-Color",
															ImageRectOffset = Vector2.new(284, 4),
															ImageRectSize = Vector2.new(24, 24),
														}
													}
												}
											}
										},
									}
								},

								scope:New "Frame" {
									Name = "Section",
									LayoutOrder = 3,
									BackgroundTransparency = 1,
									Size = UDim2.new(1, 0, 1, -27),

									[scope.Children] = {

										scope:New "Frame" {
											Name = "Shadow",
											Size = UDim2.new(1, 0, 0, 10),
											ZIndex = 2,
											[scope.Children] = {

												scope:New "UIGradient" {
													Color = ColorSequence.new(Color3.new()),
													Rotation = 90,
													Transparency = NumberSequence.new(0.756, 1),
												}
											}
										},

										scope:New "Frame" {
											Name = "Content",
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),
										}
									}
								},
							}
						},

						scope:New "ImageLabel" {
							Name = "Shadow",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,		
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(1.059, 1.088),
							Image = "rbxassetid://15298624572",
							ZIndex = -1,
						},
					}
				},


				--				


				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
			}

			--

			properties.Close = properties.Element.MainFrame.Top.Right.Close

			--

			properties.Close.MouseEnter:Connect(function()
				Maid.tween(properties.Close) {
					TweenInfo.new(0.15, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut),

					{
						BackgroundTransparency = 0,
					}
				}
			end)

			properties.Close.MouseLeave:Connect(function()
				Maid.tween(properties.Close) {
					TweenInfo.new(0.15, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut),

					{
						BackgroundTransparency = 1,
					}
				}
			end)

			--

			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.MainFrame.BackgroundColor3 = color "--Background"
				properties.Element.MainFrame.Top.BackgroundColor3 = color "--Top-Background"
				properties.Element.MainFrame.Top.Border.BackgroundColor3 = color "--Top-Border"
				properties.Element.MainFrame.Top.Right.Close.BackgroundColor3 = color "--Close"
				properties.Element.MainFrame.Top.Right.Close.ImageLabel.ImageColor3 = color "--Primary-Text-Color"
			end)

			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end

		--

		if name == "CommandPrompt" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "CanvasGroup" {
					AutomaticSize = Enum.AutomaticSize.Y,
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = color "--Background",
					Position = UDim2.fromScale(0.5, 0.09),
					Size = UDim2.fromOffset(765, 0),

					[scope.Children] = {
						scope:New "UICorner" {
							CornerRadius = UDim.new(0, 5),
						},

						scope:New "UIListLayout" {
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
						},

						scope:New "TextButton" {
							Name = "InputBox",
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundColor3 = color "--Top-Background",
							Size = UDim2.fromScale(1, 0),
							LayoutOrder = 1,
							AutoButtonColor = false,
							Text = "",

							[scope.Children] = {
								scope:New "UIPadding" {
									PaddingTop = UDim.new(0, 6),
									PaddingLeft = UDim.new(0, 6),
									PaddingRight = UDim.new(0, 6),
									PaddingBottom = UDim.new(0, 6),
								},

								scope:New "Frame" {
									Name = "Content",
									AnchorPoint = Vector2.new(0.5, 0),
									BackgroundColor3 = Color3.fromRGB(108, 108, 111),
									BackgroundTransparency = 0.9,
									Position = UDim2.fromScale(0.5, 0),
									Size = UDim2.new(1, 0, 0, 27),

									[scope.Children] = {
										scope:New "UIStroke" {
											ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
											Color = Color3.fromRGB(108, 108, 111),
											Transparency = 0.61,
										},

										scope:New "UICorner" {
											CornerRadius = UDim.new(0, 2),
										},

										scope:New "TextBox" {
											BackgroundTransparency = 1,
											AnchorPoint = Vector2.new(0.5, 0.5),
											Position = UDim2.fromScale(0.5, 0.5),
											Size = UDim2.new(1, -50, 1, 0),

											PlaceholderText = "Type a command",
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
											TextSize = 16,

											TextColor3 = color "--Primary-Text-Color",
											TextTransparency = 0.3,
											Text = "",
											TextXAlignment = Enum.TextXAlignment.Left,
											TextYAlignment = Enum.TextYAlignment.Center,
										},
										
										scope:New "ImageButton" {
											Name = "Close",
											AnchorPoint = Vector2.new(1, 0.5),
											Position = UDim2.fromScale(0.99, 0.5),
											Size = UDim2.fromOffset(16, 16),
											BackgroundTransparency = 1,													
											Image = "rbxassetid://76543842866264",
											ImageColor3 = Color3.fromRGB(108, 108, 111),
											ImageRectOffset = Vector2.new(284, 4),
											ImageRectSize = Vector2.new(24, 24),
										},
										
										scope:New "TextLabel" {
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											LayoutOrder = 0,
											Position = UDim2.fromScale(0.5, 0.5),
											Size = UDim2.new(1, -25, 1, 0),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
											TextSize = 16,

											TextColor3 = color "--Primary-Text-Color",
											TextTransparency = 0.5,
											Text = "/:",
											TextXAlignment = Enum.TextXAlignment.Left,
											TextYAlignment = Enum.TextYAlignment.Center,
										},

										scope:New "TextLabel" {
											Name = "AutoFill",
											AnchorPoint = Vector2.new(0.5, 0.5),
											BackgroundTransparency = 1,
											LayoutOrder = 0,
											Position = UDim2.fromScale(0.5, 0.5),
											Size = UDim2.new(1, -50, 1, 0),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
											TextSize = 16,

											TextColor3 = color "--Primary-Text-Color",
											TextTransparency = 0.5,
											Text = "",
											TextXAlignment = Enum.TextXAlignment.Left,
											TextYAlignment = Enum.TextYAlignment.Center,
										}
									}
								},

								scope:New "Frame" {
									AnchorPoint = Vector2.new(0.5, 1),
									BackgroundTransparency = 0.95,
									Position = UDim2.fromScale(0.5, 1),
									Size = UDim2.new(1, 0, 0, 1),
								},
							}
						},	

						scope:New "Frame" {
							Name = "Suggestions",
							AutomaticSize = Enum.AutomaticSize.Y,
							AnchorPoint = Vector2.new(0.5, 1),
							BackgroundColor3 = color "--Background",
							LayoutOrder = 2,
							Size = UDim2.fromScale(1, 0),

							[scope.Children] = {
								scope:New "UIListLayout" {
									FillDirection = Enum.FillDirection.Vertical,
									SortOrder = Enum.SortOrder.LayoutOrder,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
								},
							}
						},	

						scope:New "Frame" {
							Name = "Bottom",
							BackgroundColor3 = color "--Bottom-Background",
							Size = UDim2.new(1, 0, 0, 27),
							LayoutOrder = 3,

							[scope.Children] = {
								scope:New "Frame" {
									AnchorPoint = Vector2.new(0.5, 0),
									BackgroundColor3 = Color3.fromRGB(108, 108, 111),
									BackgroundTransparency = 0.9,
									Position = UDim2.fromScale(0.5, 0),
									Size = UDim2.fromScale(1, 1),

									[scope.Children] = {
										scope:New "Frame" {
											AnchorPoint = Vector2.new(0.5, 0),
											BackgroundTransparency = 0.95,
											Position = UDim2.fromScale(0.5, 0),
											Size = UDim2.new(1, 0, 0, 1),
										},
									}
								},
							}
						}
					}
				},


				--
				
				Show = function( self )
					self.Element.Visible = true
					self.Changed:Fire()
					return self
				end,
				
				Hide = function( self )
					self.Element.Visible = false
					self.Changed:Fire()
					return self
				end,
				
				
				SetPrediction = function( self, text: string )
					self.Element.InputBox.Content.AutoFill.Text = text
					self.Changed:Fire()
					return self
				end,
				
				SetText = function( self, text: string )
					self.Element.InputBox.Content.TextBox.Text = text
					self.Changed:Fire()
					return self
				end,
				
				
				--
				
				
				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,
				
				
				--


				Changed = Maid.signal("Changed"),
			}	

			--

			properties.InputBox = properties.Element.InputBox
			properties.TextBox = properties.Element.InputBox.Content.TextBox
			properties.Suggestions = properties.Element.Suggestions
			properties.Bottom = properties.Element.Bottom

			--

			properties.InputBox.MouseButton1Click:Connect(function()
				properties.InputBox.Content.TextBox:CaptureFocus()
			end)
			
			--
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end
	end
end :: elements