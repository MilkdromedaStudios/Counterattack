----- || LIBRARIES || -----
local Package = script:FindFirstAncestor("panel-client@2.0.6")
local Fusion = require(Package.Libraries.Fusion)
local Maid = require(Package.Libraries.Maid)
local Util = require(Package.Libraries.Util)
local color = require(Package.Libraries.Theme)



----- || TYPE CHECK || -----
type ScreenGui = ("ScreenGui") -> ( properties: { [string]: any } ) -> ScreenGui
type Empty = ("Empty") -> ( properties: { [string]: any } ) -> any
type Header = ("Header") -> ( properties: { [string]: any } ) -> any
type ReadOnly = ("ReadOnly") -> ( properties: { [string]: any } ) -> any
type WriteOnly = ("WriteOnly") -> ( properties: { [string]: any } ) -> any
type UserThumbnail = ("UserThumbnail") -> ( properties: { [string]: any } ) -> any

type elements = ScreenGui & Empty & Header & ReadOnly & WriteOnly & UserThumbnail



----- || MAIN || -----
return function( name: string )
	return function( inputProperties )
		if name == "ScreenGui" then return Fusion.scoped(Fusion):New "ScreenGui" (inputProperties) end
		
		--
		
		if name == "Empty" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "Frame" {
					BackgroundTransparency = 1,
					Size = UDim2.new(),
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

		if name == "Header" then
			local scope, properties = Fusion.scoped(Fusion), nil
			
			properties = {
				Element = scope:New "Frame" {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,		
					Size = UDim2.fromScale(1, 0),

					[scope.Children] = {

						scope:New "UIListLayout" {
							Padding = UDim.new(0, 9),
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						},

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 35),
							PaddingRight = UDim.new(0, 35),
							PaddingTop = UDim.new(0, 14),
						},

						scope:New "Frame" {
							Name = "Body",
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							LayoutOrder = 1,
							Size = UDim2.fromScale(1, 0),

							[scope.Children] = {

								scope:New "Frame" {
									Name = "Left",
									BackgroundTransparency = 1,
									Size = UDim2.fromScale(1, 1),

									[scope.Children] = {

										scope:New "UIListLayout" {
											FillDirection = Enum.FillDirection.Horizontal,
											HorizontalAlignment = Enum.HorizontalAlignment.Left,
											VerticalAlignment = Enum.VerticalAlignment.Top,
											SortOrder = Enum.SortOrder.LayoutOrder,
										},

										scope:New "TextLabel" {
											Name = "Title",
											AutomaticSize = Enum.AutomaticSize.XY,
											BackgroundTransparency = 1,
											LayoutOrder = 1,
											Size = UDim2.new(),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
											TextSize = 15,
											TextColor3 = color "--Description-Text-Color",
											Text = "N/A",
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
											HorizontalAlignment = Enum.HorizontalAlignment.Right,
											VerticalAlignment = Enum.VerticalAlignment.Top,
											SortOrder = Enum.SortOrder.LayoutOrder,
										},
									}
								}
							}
						},

						scope:New "Frame" {
							Name = "Border",
							BackgroundColor3 = color "--Border",
							LayoutOrder = 2,
							Size = UDim2.new(1, 0, 0, 1),
						},
					}
				},
				
	
				--				
				
				
				Title = function( self, text: string )
					self.Element.Body.Left.Title.Text = text
					self.Element.Body.Left.Title.Visible = text and #text:gsub(" ", "")>0
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
				end,


				--


				Changed = Maid.signal("Changed"),
			}
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.Body.Left.Title.TextColor3 = color "--Description-Text-Color"
				properties.Element.Border.BackgroundColor3 = color "--Border"
			end)
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end

		--

		if name == "ReadOnly" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "Frame" {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,		
					Size = UDim2.fromScale(1, 0),

					[scope.Children] = {

						scope:New "UIListLayout" {
							Padding = UDim.new(0, 9),
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						},

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 35),
							PaddingRight = UDim.new(0, 35),
							PaddingTop = UDim.new(0, 14),
						},

						scope:New "Frame" {
							Name = "Body",
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							LayoutOrder = 1,
							Size = UDim2.fromScale(1, 0),

							[scope.Children] = {

								scope:New "Frame" {
									Name = "Left",
									BackgroundTransparency = 1,
									Size = UDim2.fromScale(1, 1),

									[scope.Children] = {

										scope:New "UIListLayout" {
											Padding = UDim.new(0, 5),
											FillDirection = Enum.FillDirection.Vertical,
											HorizontalAlignment = Enum.HorizontalAlignment.Left,
											SortOrder = Enum.SortOrder.LayoutOrder,
										},

										scope:New "TextLabel" {
											Name = "Title",
											AutomaticSize = Enum.AutomaticSize.XY,
											BackgroundTransparency = 1,
											LayoutOrder = 1,
											Size = UDim2.new(),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
											TextSize = 15,
											TextColor3 = color "--Primary-Text-Color",
											Text = "N/A",
										},

										scope:New "TextLabel" {
											Name = "Description",
											AutomaticSize = Enum.AutomaticSize.XY,
											BackgroundTransparency = 1,
											LayoutOrder = 2,
											Size = UDim2.new(),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
											TextSize = 15,
											TextColor3 = color "--Description-Text-Color",
											Text = "N/A",
										},
									}
								},

								scope:New "Frame" {
									Name = "Right",
									BackgroundTransparency = 1,
									Size = UDim2.fromScale(1, 1),

									[scope.Children] = {

										scope:New "UIListLayout" {
											VerticalAlignment = Enum.VerticalAlignment.Center,
											HorizontalAlignment = Enum.HorizontalAlignment.Right,
											SortOrder = Enum.SortOrder.LayoutOrder,
										},

										scope:New "TextLabel" {
											Name = "Value",
											AutomaticSize = Enum.AutomaticSize.XY,
											BackgroundTransparency = 1,
											LayoutOrder = 1,
											Size = UDim2.new(),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
											TextSize = 15,
											TextColor3 = color "--Primary-Text-Color",
											TextTransparency = 0,
											Text = "N/A",
										},
									}
								},
							}
						},

						scope:New "Frame" {
							Name = "Border",
							BackgroundColor3 = color "--Border",
							LayoutOrder = 2,
							Size = UDim2.new(1, 0, 0, 1),
						},
					}
				},


				--				


				Title = function( self, text: string )
					self.Element.Body.Left.Title.Text = text or ""
					self.Element.Body.Left.Title.Visible = text and #text:gsub(" ", "")>0
					self.Changed:Fire()
					return self
				end,
				
				Description = function( self, text: string )
					self.Element.Body.Left.Description.Text = text or ""
					self.Element.Body.Left.Description.Visible = text and #text:gsub(" ", "")>0
					self.Changed:Fire()
					return self
				end,
				
				Value = function( self, text: string )
					self.Element.Body.Right.Value.Text = text
					self.Element.Body.Right.Value.Visible = text and #tostring(text):gsub(" ", "")>0
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
				end,


				--


				Changed = Maid.signal("Changed"),
			}
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.Body.Left.Title.TextColor3 = color "--Primary-Text-Color"
				properties.Element.Body.Left.Description.TextColor3 = color "--Description-Text-Color"
				properties.Element.Body.Right.Value.TextColor3 = color "--Primary-Text-Color"
				properties.Element.Border.BackgroundColor3 = color "--Border"
			end)
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end

		--

		if name == "WriteOnly" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "Frame" {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,		
					Size = UDim2.fromScale(1, 0),

					[scope.Children] = {

						scope:New "UIListLayout" {
							Padding = UDim.new(0, 9),
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						},

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 35),
							PaddingRight = UDim.new(0, 35),
							PaddingTop = UDim.new(0, 14),
						},

						scope:New "Frame" {
							Name = "Body",
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							LayoutOrder = 1,
							Size = UDim2.fromScale(1, 0),

							[scope.Children] = {

								scope:New "Frame" {
									Name = "Left",
									BackgroundTransparency = 1,
									Size = UDim2.fromScale(1, 1),

									[scope.Children] = {

										scope:New "UIListLayout" {
											Padding = UDim.new(0, 5),
											FillDirection = Enum.FillDirection.Vertical,
											HorizontalAlignment = Enum.HorizontalAlignment.Left,
											VerticalAlignment = Enum.VerticalAlignment.Center,
											SortOrder = Enum.SortOrder.LayoutOrder,
										},

										scope:New "TextLabel" {
											Name = "Title",
											AutomaticSize = Enum.AutomaticSize.XY,
											BackgroundTransparency = 1,
											LayoutOrder = 1,
											Size = UDim2.new(),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
											TextSize = 15,
											TextColor3 = color "--Primary-Text-Color",
											Text = "N/A",
										},

										scope:New "TextLabel" {
											Name = "Description",
											AutomaticSize = Enum.AutomaticSize.XY,
											BackgroundTransparency = 1,
											LayoutOrder = 2,
											Size = UDim2.new(),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
											TextSize = 15,
											TextColor3 = color "--Description-Text-Color",
											Text = "N/A",
										},
									}
								},

								scope:New "Frame" {
									Name = "Right",
									BackgroundTransparency = 1,
									Size = UDim2.fromScale(1, 1),

									[scope.Children] = {

										scope:New "UIListLayout" {
											Padding = UDim.new(0, 8),
											FillDirection = Enum.FillDirection.Horizontal,
											VerticalAlignment = Enum.VerticalAlignment.Center,
											HorizontalAlignment = Enum.HorizontalAlignment.Right,
											SortOrder = Enum.SortOrder.LayoutOrder,
										},
									}
								},
							}
						},

						scope:New "Frame" {
							Name = "Border",
							BackgroundColor3 = color "--Border",
							LayoutOrder = 2,
							Size = UDim2.new(1, 0, 0, 1),
						},
					}
				},


				--				


				Title = function( self, text: string )
					self.Element.Body.Left.Title.Text = text or ""
					self.Element.Body.Left.Title.Visible = text and #text:gsub(" ", "")>0
					self.Changed:Fire()
					return self
				end,

				Description = function( self, text: string )
					self.Element.Body.Left.Description.Text = text or ""
					self.Element.Body.Left.Description.Visible = text and #text:gsub(" ", "")>0
					self.Changed:Fire()
					return self
				end,
				
				Values = function( self, array: {any} )
					for x=1, #array do
						array[x].Element.Parent = self.Element.Body.Right
						array[x].Element.LayoutOrder = x
					end
					
					return self
				end,
				
				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
				end,


				--


				Changed = Maid.signal("Changed"),
			}
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.Body.Left.Title.TextColor3 = color "--Primary-Text-Color"
				properties.Element.Body.Left.Description.TextColor3 = color "--Description-Text-Color"
				properties.Element.Border.BackgroundColor3 = color "--Border"
			end)
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties	
		end 

		--

		if name == "UserThumbnail" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "Frame" {
					Name = "Thumbnail",
					BackgroundTransparency = 1,		
					Size = UDim2.fromOffset(24, 24),

					[scope.Children] = {

						scope:New "UICorner" {
							CornerRadius = UDim.new(1, 0)
						},

						scope:New "UIStroke" {
							Color = color "--Default-Account",
							Thickness = 1.5,
							Transparency = 0.3,
						},

						scope:New "ImageLabel" {
							Name = "Icon",
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = color "--Default-Account",
							BackgroundTransparency = 0.75,
							LayoutOrder = 1,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(5/6, 5/6),

							[scope.Children] = {

								scope:New "UICorner" {
									CornerRadius = UDim.new(1, 0),
								}
							}
						}
					}
				},


				--			
				
				SetUserId = function( self, id: number )
					local chatColor = Util.GetChatColor(id)
					self.Element.Icon.Image = game:GetService("Players"):GetUserThumbnailAsync(id, "HeadShot", "Size420x420")
					self.Element.Icon.BackgroundColor3, self.Element.UIStroke.Color = chatColor, chatColor
					
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
				end,


				--


				Changed = Maid.signal("Changed"),
			}
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties	
		end
	end
end :: elements