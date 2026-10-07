----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || MAIN || -----
return function( panel: any )
	
	local Frame = Libraries.scope:New "TextButton" {
		Parent = panel.Element,
		Size = UDim2.fromScale(1 ,1),
		BackgroundColor3 = Libraries.Color "--Shadow",
		BackgroundTransparency = 0.5,
		ZIndex = 5,
		Visible = false,
		
		[Libraries.scope.Children] = {
			
			Libraries.scope:New "UICorner" {
				CornerRadius = UDim.new(0, 10),
			}
		}
	}



	----- || METHODS || -----
	local function createPopup()
		local self = {

			Popup = nil,
			IsDown = { false, false, false },
			IsTyping = false,

			Color = Color3.fromHSV(0, 1, 1),
			
			Show = function( self: any )
				Frame.Visible = true
				self.Popup.Element.Visible = true
				return self
			end,

			Hide = function( self: any )
				Frame.Visible = false
				self.Popup.Element.Visible = false
				return self
			end,

			--

			Applied = Libraries.Maid.signal("Applied"),
			Canceled = Libraries.Maid.signal("Canceled"),
			Changed = Libraries.Maid.signal("Changed"),
		}

		self.Popup = Libraries.Windows "Popup" {
			Size = UDim2.fromOffset(225, 390),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = Frame,
		}

		self.Popup.Element.Shadow.Visible = false	
		self.Popup.Element.AnchorPoint = Vector2.new(0.5, 0.5)
		self.Popup.Element.MainFrame.Section.BackgroundColor3 = Libraries.Color "--Background"
		self.Popup.Element.MainFrame.Section.BackgroundTransparency = 0.5

		--

		Libraries.scope:New "TextButton" {
			Name = "Saturation",
			Parent = self.Popup.Element.MainFrame.Section.Content,
			BackgroundColor3 = Color3.new(1, 0, 0),
			Size = UDim2.fromOffset(225, 200),
			ClipsDescendants = true,

			[Libraries.scope.OnEvent "MouseButton1Down"] = function()
				self.IsDown[1] = true
				self.MousePos = game:GetService("UserInputService"):GetMouseLocation()+Vector2.new(-1,-50) - self.Popup.Element.MainFrame.Section.Content.Saturation.AbsolutePosition

				self.XScale = math.clamp(self.MousePos.X/self.Popup.Element.MainFrame.Section.Content.Saturation.AbsoluteSize.X, 0, 1)
				self.YScale = math.clamp(self.MousePos.Y/self.Popup.Element.MainFrame.Section.Content.Saturation.AbsoluteSize.Y, 0, 1)

				self.Popup.Element.MainFrame.Section.Content.Saturation.Head:TweenSize(UDim2.fromOffset(22, 22), Enum.EasingDirection.InOut, Enum.EasingStyle.Sine, 0.05)
				game:GetService("UserInputService").MouseIconEnabled = false

				local H, S, V = self.Color:ToHSV()
				self.Color = Color3.fromHSV(H, self.XScale, 1-self.YScale)
				self.Changed:Fire("Color")
			end,

			[Libraries.scope.Children] = {

				Libraries.scope:New "Frame" {
					Name = "Head",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.new(1, 0, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(14, 14),
					ZIndex = 3,

					[Libraries.scope.Children] = {

						Libraries.scope:New "UICorner" {
							CornerRadius = UDim.new(1, 0),
						},

						Libraries.scope:New "UIStroke" {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = Libraries.Color "--Slider-Head",
							Thickness = 2,
						},

						Libraries.scope:New "ImageLabel" {
							Name = "Shadow",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(2, 2),
							Image = "http://www.roblox.com/asset/?id=12265146185",
							ImageTransparency = 0.25, 
						}
					}
				},

				Libraries.scope:New "Frame" {
					Name = "Brightness",
					BackgroundColor3 = Color3.new(0, 0, 0),
					Size = UDim2.fromScale(1, 1),
					ZIndex = 2,
					
					[Libraries.scope.Children] = {

						Libraries.scope:New "UIGradient" {
							Rotation = -90,
							Transparency = NumberSequence.new(0, 1)
						}
					}
				},

				Libraries.scope:New "Frame" {
					Name = "Saturation",
					BackgroundColor3 = Color3.new(1, 1, 1),
					Size = UDim2.fromScale(1, 1),
					ZIndex = 1,
					
					[Libraries.scope.Children] = {

						Libraries.scope:New "UIGradient" {
							Rotation = 0,
							Transparency = NumberSequence.new(0, 1)
						}
					}
				},
			}
		} 

		Libraries.scope:New "TextButton" {
			Name = "Hue",
			Parent = self.Popup.Element.MainFrame.Section.Content,
			Position = UDim2.new(0, 16, 0, 215),
			Size = UDim2.new(1, -32, 0, 10),

			[Libraries.scope.OnEvent "MouseButton1Down"] = function()
				self.IsDown[2] = true
				self.MousePos = game:GetService("UserInputService"):GetMouseLocation()+Vector2.new(-1,-50) - self.Popup.Element.MainFrame.Section.Content.Hue.AbsolutePosition

				self.XScale = math.clamp(self.MousePos.X/self.Popup.Element.MainFrame.Section.Content.Hue.AbsoluteSize.X, 0, 1)

				self.Popup.Element.MainFrame.Section.Content.Hue.Head:TweenSize(UDim2.fromOffset(22, 22), Enum.EasingDirection.InOut, Enum.EasingStyle.Sine, 0.05)
				game:GetService("UserInputService").MouseIconEnabled = false

				local H, S, V = self.Color:ToHSV()			
				self.Color = Color3.fromHSV(self.XScale, S, V)
				self.Changed:Fire("Color")
			end,

			[Libraries.scope.Children] =  {

				Libraries.scope:New "UICorner" {
					CornerRadius = UDim.new(1, 0),
				},

				Libraries.scope:New "UIGradient" {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0/6, Color3.fromHSV(0/6, 1, 1)),
						ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6, 1, 1)),
						ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6, 1, 1)),
						ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6, 1, 1)),
						ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6, 1, 1)),
						ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6, 1, 1)),
						ColorSequenceKeypoint.new(6/6, Color3.fromHSV(6/6, 1, 1)),
					})
				},

				Libraries.scope:New "Frame" {
					Name = "Head",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.new(1, 0, 0),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromOffset(14, 14),
					ZIndex = 5,

					[Libraries.scope.Children] = {

						Libraries.scope:New "UICorner" {
							CornerRadius = UDim.new(1, 0),
						},

						Libraries.scope:New "UIStroke" {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = Color3.new(1, 1, 1),
							Thickness = 2,
						},

						Libraries.scope:New "ImageLabel" {
							Name = "Shadow",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(2, 2),
							Image = "http://www.roblox.com/asset/?id=12265146185",
							ImageTransparency = 0.25, 
						}
					}
				},
			}
		}

		Libraries.scope:New "TextButton" {
			Name = "Value",
			Parent = self.Popup.Element.MainFrame.Section.Content,
			Position = UDim2.new(0, 16, 0, 240),
			Size = UDim2.new(1, -32, 0, 10),

			[Libraries.scope.OnEvent "MouseButton1Down"] = function()
				self.IsDown[3] = true
				self.MousePos = game:GetService("UserInputService"):GetMouseLocation()+Vector2.new(-1,-50) - self.Popup.Element.MainFrame.Section.Content.Value.AbsolutePosition

				self.XScale = math.clamp(self.MousePos.X/self.Popup.Element.MainFrame.Section.Content.Value.AbsoluteSize.X, 0, 1)

				self.Popup.Element.MainFrame.Section.Content.Value.Head:TweenSize(UDim2.fromOffset(22, 22), Enum.EasingDirection.InOut, Enum.EasingStyle.Sine, 0.05)
				game:GetService("UserInputService").MouseIconEnabled = false

				local H, S, V = self.Color:ToHSV()			
				self.Color = Color3.fromHSV(H, S, self.XScale)
				self.Changed:Fire("Color")
			end,

			[Libraries.scope.Children] =  {

				Libraries.scope:New "UICorner" {
					CornerRadius = UDim.new(1, 0),
				},

				Libraries.scope:New "UIGradient" {
					Color = ColorSequence.new( Color3.new(0, 0, 0), Color3.new(1, 0, 0) )
				},

				Libraries.scope:New "Frame" {
					Name = "Head",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.new(1, 0, 0),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromOffset(14, 14),
					ZIndex = 5,

					[Libraries.scope.Children] = {

						Libraries.scope:New "UICorner" {
							CornerRadius = UDim.new(1, 0),
						},

						Libraries.scope:New "UIStroke" {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = Color3.new(1, 1, 1),
							Thickness = 2,
						},

						Libraries.scope:New "ImageLabel" {
							Name = "Shadow",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(2, 2),
							Image = "http://www.roblox.com/asset/?id=12265146185",
							ImageTransparency = 0.25, 
						}
					}
				},
			}
		}

		--

		Libraries.scope:New "TextButton" {
			Name = "Output",
			Parent = self.Popup.Element.MainFrame.Section.Content,
			AutoButtonColor = false,
			BackgroundColor3 = Libraries.Color "--Background",
			Position = UDim2.new(0, 8, 1, -98),
			Size = UDim2.new(1, -18, 0, 40),

			[Libraries.scope.OnEvent "Activated"] = function()
				self.Popup.Element.MainFrame.Section.Content.Output.Frame.TextBox:CaptureFocus()
			end,

			[Libraries.scope.Children] = {

				Libraries.scope:New "Frame" {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIListLayout" {
							Padding = UDim.new(0, 10),
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						},

						Libraries.scope:New "UICorner" {
							CornerRadius = UDim.new(0, 8)
						},

						Libraries.scope:New "UIStroke" {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = Libraries.Color "--Border",
							Thickness = 1,
						},

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 15),
							PaddingRight = UDim.new(0, 15),
						},

						Libraries.scope:New "Frame" {
							Name = "Color",
							LayoutOrder = 1,
							Size = UDim2.fromOffset(16, 16),

							[Libraries.scope.Children] = {

								Libraries.scope:New "UICorner" {
									CornerRadius = UDim.new(1, 0)
								},
							}
						},

						Libraries.scope:New "TextBox" {
							BackgroundTransparency = 1,
							LayoutOrder = 2,
							Size = UDim2.fromScale(1, 0.65),

							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							Text = "#ff0000",
							TextSize = 16,
							TextColor3 = Libraries.Color "--Primary-Text-Color",
							TextTransparency = 0,
							TextXAlignment = Enum.TextXAlignment.Left,

							[Libraries.scope.OnEvent "Changed"] = function()
								if not self.Popup or not self.Popup.Element or not self.Popup.Element:FindFirstChild("MainFrame") then return end
								if not self.Popup.Element.MainFrame.Section.Content:FindFirstChild("Output") then return end

								local currentText = string.gsub(self.Popup.Element.MainFrame.Section.Content:FindFirstChild("Output").Frame.TextBox.Text, " ", "")


								--| @ Hexadecimal
								local _, Hex = xpcall(function() return currentText:sub(1, 1) == "#" and Color3.fromHex(currentText) or nil end, function() end)
								if Hex then self.Color = Hex or self.Color; self.Changed:Fire("Color") return end


								--| @ RGB
								local _, RGB = xpcall(function() return #currentText:split(",") == 1 and Color3.fromRGB(currentText:split(",")[1], currentText:split(",")[1], currentText:split(",")[1]) or Color3.fromRGB(currentText:split(",")[1], currentText:split(",")[2], currentText:split(",")[3]) end, function() end)
								if RGB then self.Color = RGB or self.Color; self.Changed:Fire("Color") return end
							end,

							[Libraries.scope.OnEvent "FocusLost"] = function()
								self.IsTyping = false				
								
								if not self.Popup or not self.Popup.Element or not self.Popup.Element:FindFirstChild("MainFrame") then return end
								if not self.Popup.Element.MainFrame.Section.Content:FindFirstChild("Output") then return end

								local currentText = string.gsub(self.Popup.Element.MainFrame.Section.Content:FindFirstChild("Output").Frame.TextBox.Text, " ", "")


								--| @ Hexadecimal
								local _, Hex = xpcall(function() return currentText:sub(1, 1) == "#" and Color3.fromHex(currentText) or nil end, function() end)
								if Hex then self.Color = Hex or self.Color; self.Changed:Fire("Color") return end


								--| @ RGB
								local _, RGB = xpcall(function() return #currentText:split(",") == 1 and Color3.fromRGB(currentText:split(",")[1], currentText:split(",")[1], currentText:split(",")[1]) or Color3.fromRGB(currentText:split(",")[1], currentText:split(",")[2], currentText:split(",")[3]) end, function() end)
								if RGB then self.Color = RGB or self.Color; self.Changed:Fire("Color") return end
							end,

							[Libraries.scope.OnEvent "Focused"] = function()
								self.IsTyping = true
								task.wait(0.1)
								self.Popup.Element.MainFrame.Section.Content.Output.Frame.TextBox.SelectionStart = 0
								self.Popup.Element.MainFrame.Section.Content.Output.Frame.TextBox.CursorPosition = #self.Popup.Element.MainFrame.Section.Content.Output.Frame.TextBox.Text+1
							end,
						},
					}
				},

				Libraries.scope:New "TextLabel" {
					Name = "Title",
					AutomaticSize = Enum.AutomaticSize.X,
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Libraries.Color "--Background",
					Position = UDim2.fromOffset(5, 0),
					Size = UDim2.fromOffset(0, 10),
					ZIndex = 2,

					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					Text = "Output",
					TextSize = 15,
					TextColor3 = Libraries.Color "--Primary-Text-Color",
					TextTransparency = 0.5,

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 6),
							PaddingRight = UDim.new(0, 6),
						},
					},
				},
			}
		}

		Libraries.scope:New "TextButton" {
			Name = "Apply",
			Parent = self.Popup.Element.MainFrame.Section.Content,
			BackgroundColor3 = Libraries.Color "--Accent",
			Position = UDim2.new(0, 8, 1, -46),
			Size = UDim2.new(1, -18, 0, 35),

			FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
			Text = "Apply",
			TextColor3 = Libraries.Color "--Accent-Text-Color",
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,


			[Libraries.scope.OnEvent "MouseEnter"] = function()
				local Button = self.Popup.Element.MainFrame.Section.Content.Apply

				Libraries.Maid.tween {

					[Button] = {
						TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
							BackgroundTransparency = 0.65,
							TextColor3 = Libraries.Color "--Primary-Text-Color",
						}
					},

					[Button.UIStroke] = {
						TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
							Transparency = 0,
						}
					},
				}
			end,

			[Libraries.scope.OnEvent "MouseLeave"] = function()
				local Button = self.Popup.Element.MainFrame.Section.Content.Apply

				Libraries.Maid.tween {

					[Button] = {
						TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
							BackgroundTransparency = 0,
							TextColor3 = Libraries.Color "--Accent-Text-Color",
						}
					},

					[Button.UIStroke] = {
						TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
							Transparency = 1,
						}
					},
				}
			end,

			[Libraries.scope.Children] = {

				Libraries.scope:New "UICorner" {
					CornerRadius = UDim.new(0, 8),
				},

				Libraries.scope:New "UIStroke" {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Libraries.Color "--Accent",
					Thickness = 1,
					Transparency = 1,
				},
			}
		}

		--
		
		self.Popup.Close.Activated:Connect(function()
			self.Canceled:Fire()
			self:Hide()
			self.Popup.Element:Destroy()
		end)
		
		self.Popup.Element.MainFrame.Section.Content.Apply.Activated:Connect(function()
			self.Applied:Fire( self.Color )
			self:Hide()
			self.Popup.Element:Destroy()
		end)
		
		--
	
		game:GetService("UserInputService").InputChanged:Connect(function( inputObject: InputObject )
			if not table.find({ Enum.UserInputType.MouseMovement, Enum.UserInputType.Touch }, inputObject.UserInputType) or #self.IsDown < 1 then return end

			if self.IsDown[1] then
				self.MousePos = game:GetService("UserInputService"):GetMouseLocation()+Vector2.new(-1,-50) - self.Popup.Element.MainFrame.Section.Content.Saturation.AbsolutePosition

				self.XScale = math.clamp(self.MousePos.X/self.Popup.Element.MainFrame.Section.Content.Saturation.AbsoluteSize.X, 0, 1)
				self.YScale = math.clamp(self.MousePos.Y/self.Popup.Element.MainFrame.Section.Content.Saturation.AbsoluteSize.Y, 0, 1)

				local H, S, V = self.Color:ToHSV()			
				self.Color = Color3.fromHSV(H, self.XScale, 1-self.YScale)
				self.Changed:Fire("Color")
			end

			--

			if self.IsDown[2] then
				self.MousePos = game:GetService("UserInputService"):GetMouseLocation()+Vector2.new(-1,-50) - self.Popup.Element.MainFrame.Section.Content.Hue.AbsolutePosition

				self.XScale = math.clamp(self.MousePos.X/self.Popup.Element.MainFrame.Section.Content.Hue.AbsoluteSize.X, 0, 1)

				local H, S, V = self.Color:ToHSV()			
				self.Color = Color3.fromHSV(self.XScale, S, V)
				self.Changed:Fire("Color")
			end

			--

			if self.IsDown[3] then
				self.MousePos = game:GetService("UserInputService"):GetMouseLocation()+Vector2.new(-1,-50) - self.Popup.Element.MainFrame.Section.Content.Value.AbsolutePosition

				self.XScale = math.clamp(self.MousePos.X/self.Popup.Element.MainFrame.Section.Content.Value.AbsoluteSize.X, 0, 1)

				local H, S, V = self.Color:ToHSV()			
				self.Color = Color3.fromHSV(H, S, self.XScale)
				self.Changed:Fire("Color")
			end
		end)

		game:GetService("UserInputService").InputEnded:Connect(function( inputObject: InputObject )
			if not table.find({ Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch }, inputObject.UserInputType) or #self.IsDown < 1 then return end

			if self.IsDown[1] then
				self.MousePos = game:GetService("UserInputService"):GetMouseLocation()+Vector2.new(-1,-50) - self.Popup.Element.MainFrame.Section.Content.Saturation.AbsolutePosition

				self.XScale = math.clamp(self.MousePos.X/self.Popup.Element.MainFrame.Section.Content.Saturation.AbsoluteSize.X, 0, 1)
				self.YScale = math.clamp(self.MousePos.Y/self.Popup.Element.MainFrame.Section.Content.Saturation.AbsoluteSize.Y, 0, 1)

				self.Popup.Element.MainFrame.Section.Content.Saturation.Head:TweenSize(UDim2.fromOffset(14, 14), Enum.EasingDirection.InOut, Enum.EasingStyle.Sine, 0.05)

				local H, S, V = self.Color:ToHSV()
				self.Color = Color3.fromHSV(H, self.XScale, 1-self.YScale)
				self.Changed:Fire("Color")
			end

			--

			if self.IsDown[2] then
				self.MousePos = game:GetService("UserInputService"):GetMouseLocation()+Vector2.new(-1,-50) - self.Popup.Element.MainFrame.Section.Content.Hue.AbsolutePosition

				self.XScale = math.clamp(self.MousePos.X/self.Popup.Element.MainFrame.Section.Content.Hue.AbsoluteSize.X, 0, 1)

				self.Popup.Element.MainFrame.Section.Content.Hue.Head:TweenSize(UDim2.fromOffset(14, 14), Enum.EasingDirection.InOut, Enum.EasingStyle.Sine, 0.05)

				local H, S, V = self.Color:ToHSV()			
				self.Color = Color3.fromHSV(self.XScale, S, V)
				self.Changed:Fire("Color")
			end

			--

			if self.IsDown[3] then
				self.MousePos = game:GetService("UserInputService"):GetMouseLocation()+Vector2.new(-1,-50) - self.Popup.Element.MainFrame.Section.Content.Value.AbsolutePosition

				self.XScale = math.clamp(self.MousePos.X/self.Popup.Element.MainFrame.Section.Content.Value.AbsoluteSize.X, 0, 1)

				self.Popup.Element.MainFrame.Section.Content.Value.Head:TweenSize(UDim2.fromOffset(14, 14), Enum.EasingDirection.InOut, Enum.EasingStyle.Sine, 0.05)

				local H, S, V = self.Color:ToHSV()			
				self.Color = Color3.fromHSV(H, S, self.XScale)
				self.Changed:Fire("Color")
			end

			--

			game:GetService("UserInputService").MouseIconEnabled = true
			self.IsDown = { false, false, false}
		end)	

		--
		
		self.Changed:Connect(function(property)
			if property ~= "Color" then return end

			local H, S, V = self.Color:ToHSV()		
			self.Popup.Element.MainFrame.Section.Content.Saturation.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
			self.Popup.Element.MainFrame.Section.Content.Saturation.Head.BackgroundColor3 = self.Color
			self.Popup.Element.MainFrame.Section.Content.Saturation.Head.Position = UDim2.fromScale(S, 1-V)

			self.Popup.Element.MainFrame.Section.Content.Hue.Head.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
			self.Popup.Element.MainFrame.Section.Content.Hue.Head.Position = UDim2.fromScale(H, 0.5)

			self.Popup.Element.MainFrame.Section.Content.Value.UIGradient.Color = ColorSequence.new( Color3.new(0, 0, 0), Color3.fromHSV(H, S, 1) ) 
			self.Popup.Element.MainFrame.Section.Content.Value.Head.BackgroundColor3 = self.Color
			self.Popup.Element.MainFrame.Section.Content.Value.Head.Position = UDim2.fromScale(V, 0.5)

			self.Popup.Element.MainFrame.Section.Content.Output.Frame.Color.BackgroundColor3 = self.Color

			if self.IsTyping then return end
			
			if shared["Nexus Dynamics"].Config.ColorWheelOutput:lower() == "rgb" then
				self.Popup.Element.MainFrame.Section.Content.Output.Frame.TextBox.Text = `{math.floor((self.Color.R * 255))}, {math.floor((self.Color.G * 255))}, {math.floor((self.Color.B * 255))}`
			elseif shared["Nexus Dynamics"].Config.ColorWheelOutput:lower() == "hsv" then
				local H, S, V = self.Color:ToHSV()
				self.Popup.Element.MainFrame.Section.Content.Output.Frame.TextBox.Text = `{math.floor(H * 359)}, {math.floor(S * 255)}, {math.floor(V * 255)}`
			elseif shared["Nexus Dynamics"].Config.ColorWheelOutput:lower() == "new" then
				self.Popup.Element.MainFrame.Section.Content.Output.Frame.TextBox.Text = `{math.floor(self.Color.R * 100)/100}, {math.floor(self.Color.G * 100)/100}, {math.floor(self.Color.B * 100)/100}`
			elseif shared["Nexus Dynamics"].Config.ColorWheelOutput:lower() == "hex" then
				self.Popup.Element.MainFrame.Section.Content.Output.Frame.TextBox.Text = `#{self.Color:ToHex()}`
			else
				self.Popup.Element.MainFrame.Section.Content.Output.Frame.TextBox.Text = BrickColor.new(self.Color).Name
			end
		end)
		
		--
		
		self.Changed:Fire()
		return self
	end
	
	return {
	
		New = function( self: any )
			local suc, popup = pcall(function()
				local popup = createPopup()
					:Show()
				
				return popup
			end)
			
			if not suc then return end
			
			return {
				
				SetColor = function( self: any, color: Color3 )
					popup.Color = color
					popup.Changed:Fire("Color")
					return self
				end,
				
				Applied = function( self: any, func: ( color: Color3 ) -> RBXScriptSignal  ) 
					return popup.Applied:Once(func)
				end,
				
				Canceled = function( self: any, func: () -> RBXScriptSignal  ) 
					return popup.Canceled:Once(func)
				end,
			}		
		end,
	}
end