----- || LIBRARIES || -----
local Package = script:FindFirstAncestor("setup-client@2.0.6")
local Fusion = require(Package.Libraries.Fusion)
local Maid = require(Package.Libraries.Maid)
local color = require(Package.Libraries.Theme)



----- || TYPE CHECK || -----
type Prompt = ("Prompt") -> ( properties: {[string]: any} ) -> any
type Panel = ("Panel") -> ( properties: {[string]: any} ) -> any
type Page = ("Page") -> ( properties: {[string]: any} ) -> any
type ScrollFrame = ("ScrollFrame") -> ( properties: {[string]: any} ) -> any

type elements = Panel & Page & ScrollFrame & Popup



----- || MAIN || -----
return function( name: string )
	return function( inputProperties )
		
		if name == "Prompt" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "CanvasGroup" {
					AnchorPoint = Vector2.new(0.5, 0.5),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = color "--Background",
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(455, 0),

					[scope.Children] = {

						scope:New "UICorner" {
							CornerRadius = UDim.new(0, 10),
						},

						scope:New "UIListLayout" {
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Top
						},

						scope:New "Frame" {
							Name = "Content",
							AnchorPoint = Vector2.new(0.5, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundColor3 = color "--Top-Background",
							LayoutOrder = 1,
							Size = UDim2.fromScale(1, 0),

							[scope.Children] = {
								scope:New "UIListLayout" {
									Padding = UDim.new(0, 8),
									FillDirection = Enum.FillDirection.Vertical,
									SortOrder = Enum.SortOrder.LayoutOrder,
									HorizontalAlignment = Enum.HorizontalAlignment.Left,
									VerticalAlignment = Enum.VerticalAlignment.Top
								},

								scope:New "Frame" {
									Name = "Content",
									AnchorPoint = Vector2.new(0.5, 0),
									AutomaticSize = Enum.AutomaticSize.Y,
									BackgroundTransparency = 1,
									LayoutOrder = 1,
									Size = UDim2.fromScale(1, 0),

									[scope.Children] = {
										scope:New "UIListLayout" {
											Padding = UDim.new(0, 8),
											FillDirection = Enum.FillDirection.Vertical,
											SortOrder = Enum.SortOrder.LayoutOrder,
											HorizontalAlignment = Enum.HorizontalAlignment.Left,
											VerticalAlignment = Enum.VerticalAlignment.Top
										},

										scope:New "UIPadding" {
											PaddingTop = UDim.new(0, 18),
											PaddingRight = UDim.new(0, 25),
											PaddingLeft = UDim.new(0, 25),
											PaddingBottom = UDim.new(0, 8),
										},

										scope: New "TextLabel" {
											Name = "Title",
											AutomaticSize = Enum.AutomaticSize.Y,
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 0),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
											TextSize = 27,
											TextColor3 = color "--AccountTab-Text-Color",
											TextWrapped = true,
											TextXAlignment = Enum.TextXAlignment.Left,
											TextYAlignment = Enum.TextYAlignment.Top,
										},

										scope: New "TextLabel" {
											Name = "Description",
											AutomaticSize = Enum.AutomaticSize.Y,
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 0),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
											TextSize = 15,
											TextTransparency = 0.3,
											TextColor3 = color "--Primary-Text-Color",
											TextWrapped = true,
											TextXAlignment = Enum.TextXAlignment.Left,
											TextYAlignment = Enum.TextYAlignment.Top,
										},

										scope:New "Frame" {
											BackgroundTransparency = 1,
											Size = UDim2.new(1, 0, 0, 1),	
										},

										scope: New "TextLabel" {
											Name = "Alt",
											AutomaticSize = Enum.AutomaticSize.Y,
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 0),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
											TextSize = 15,
											TextColor3 = color "--Primary-Text-Color",
											TextTransparency = 0.75,
											TextWrapped = true,
											TextXAlignment = Enum.TextXAlignment.Left,
											TextYAlignment = Enum.TextYAlignment.Top,
										},
									}
								},

								scope:New "Frame" {
									AnchorPoint = Vector2.new(0, 1),
									BackgroundColor3 = color "--Top-Border",
									Size = UDim2.new(1, 0, 0, 1),
									LayoutOrder = 2,
								}
							}
						},

						scope:New "Frame" {
							Name = "Action",
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							LayoutOrder = 2,
							Size = UDim2.fromScale(1, 0),

							[scope.Children] = {
								scope:New "UIListLayout" {
									FillDirection = Enum.FillDirection.Horizontal,
									SortOrder = Enum.SortOrder.LayoutOrder,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									VerticalAlignment = Enum.VerticalAlignment.Top,
									HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
								},

								scope:New "UIPadding" {
									PaddingTop = UDim.new(0, 15),
									PaddingRight = UDim.new(0, 15),
									PaddingLeft = UDim.new(0, 15),
									PaddingBottom = UDim.new(0, 15),
								},

								scope:New "TextButton" {
									Name = "ButtonA",
									Size = UDim2.new(0.485, 0, 0, 40),
									BackgroundColor3 = color "--Accent",
									FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
									Text = "ButtonA",
									TextColor3 =  color "--Accent-Text-Color",
									TextSize = 16,

									[scope.OnEvent "MouseButton1Click"] = function(...)
										properties.ButtonAPressed:Fire(...)
									end,

									[scope.Children] = {
										scope:New "UICorner" {
											CornerRadius = UDim.new(0, 8)
										}
									}
								},

								scope:New "TextButton" {
									Name = "ButtonB",
									Size = UDim2.new(0.485, 0, 0, 40),
									BackgroundColor3 = color "--Button-Background",
									FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
									Text = "ButtonB",
									TextColor3 =  color "--Button-Text-Color",
									TextSize = 16,

									[scope.OnEvent "MouseButton1Click"] = function(...)
										properties.ButtonBPressed:Fire(...)
									end,

									[scope.Children] = {
										scope:New "UICorner" {
											CornerRadius = UDim.new(0, 8)
										},

										scope:New "UIStroke" {
											ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
											Color = color "--Button-Border",
											Thickness = 1,
										}
									}
								}
							}
						}
					}
				},


				--				

				Title = function( self, text: string )
					self.Element.Content.Content.Title.Text = text
					self.Changed:Fire("Title")
					return self
				end,

				Description = function( self, text: string )
					self.Element.Content.Content.Description.Text = text
					self.Changed:Fire("Description")
					return self
				end,

				Alt = function( self, text: string )
					if not text or #text == 0 then
						self.Element.Content.Content.Frame.Visible = false
						self.Element.Content.Content.Alt.Visible = false
						self.Changed:Fire("Alt")
						return self	
					end

					self.Element.Content.Content.Alt.Text = text
					self.Changed:Fire("Alt")
					return self
				end,

				ButtonA = function( self, text: string )
					self.Element.Action.ButtonA.Text = text
					self.Changed:Fire("ButtonA")
					return self
				end,

				ButtonB = function( self, text: string )
					self.Element.Action.ButtonB.Text = text
					self.Changed:Fire("ButtonB")
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


				ButtonAPressed = Maid.signal("Changed"),
				ButtonBPressed = Maid.signal("Changed"),
				Changed = Maid.signal("Changed"),
			}


			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
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
									VerticalFlex = Enum.UIFlexAlignment.Fill
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
									Name = "Section",
									LayoutOrder = 3,
									BackgroundTransparency = 1,
									Size = UDim2.fromScale(1, 1),
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
			properties.Section = properties.Element.MainFrame.Section
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
	end
end :: elements