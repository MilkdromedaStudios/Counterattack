----- || LIBRARIES || -----
local Package = script:FindFirstAncestor("panel-client@2.0.6")
local Fusion = require(Package.Libraries.Fusion)
local Maid = require(Package.Libraries.Maid)
local Util = require(Package.Libraries.Util)
local Common = require(Package.Elements.Common)
local color = require(Package.Libraries.Theme)



----- || TYPE CHECK || -----
type Tab = ("Tab") -> ( properties: { [string]: any } ) -> any
type AccountTab = ("Tab") -> ( properties: { [string]: any } ) -> any
type Account = ("Account") -> ( properties: { [string]: any } ) -> any
type Command = ("Command") -> ( properties: { [string]: any } ) -> any

type ToggleProperties = {
	Value: boolean,
	Element: TextButton,
	
	Default: ( self: any, value: boolean ) -> ToggleProperties,
	Enable: ( self: any ) -> ToggleProperties,
	Disable: ( self: any ) -> ToggleProperties,
	Properties: ( self: ToggleProperties, properties: {[string]: any}) -> ToggleProperties,
	Connection: ( self: ToggleProperties, func: (...any) -> ...any ) -> ToggleProperties,

	Changed: RBXScriptSignal,
	Activated: RBXScriptSignal,
	Applied: RBXScriptSignal,
} type Toggle = ("Toggle") -> ( properties: { [string]: any } ) -> ToggleProperties

type DropdownProperties = {
	Value: string,
	Element: TextButton,
	List: Frame,

	ShowOptions: ( self: any ) -> DropdownProperties,
	HideOptions: ( self: any ) -> DropdownProperties,
	Select: (( self: any, option: string ) -> DropdownProperties) & (( self: any, option: EnumItem ) -> DropdownProperties),
	Default: (( self: any, option: string ) -> DropdownProperties) & (( self: any, option: EnumItem ) -> DropdownProperties),
	SetOptions: (( self: any, options: {string} ) -> DropdownProperties) & (( self: any, options: {EnumItem} ) -> DropdownProperties),
	AddOption: (( self: any, option: string ) -> DropdownProperties) & (( self: any, option: EnumItem ) -> DropdownProperties),
	RemoveOption: (( self: any, option: string ) -> DropdownProperties) & (( self: any, option: EnumItem ) -> DropdownProperties),
	IsVisible: ( self: any ) -> boolean,
	Properties: ( self: DropdownProperties, properties: {[string]: any}) -> DropdownProperties,
	Connection: ( self: DropdownProperties, func: (...any) -> ...any ) -> DropdownProperties,

	Changed: RBXScriptSignal,
	Activated: RBXScriptSignal,
	Applied: RBXScriptSignal,
} type Dropdown = ("Dropdown") -> ( properties: { [string]: any } ) -> DropdownProperties

type ButtonProperties = {
	Element: TextButton,

	Placeholder: ( self: any, text: string ) -> ButtonProperties,
	Properties: ( self: ButtonProperties, properties: {[string]: any}) -> ButtonProperties,
	Connection: ( self: ButtonProperties, func: (...any) -> ...any ) -> ButtonProperties,

	Changed: RBXScriptSignal,
	Activated: RBXScriptSignal,
	Applied: RBXScriptSignal,
} type Button = ("Button") -> ( properties: { [string]: any } ) -> ButtonProperties

type TextBoxProperties = {
	Value: string | number,
	Element: TextBox,

	SetValue: ( (self: any, text: string) -> TextBoxProperties ) & ( (self: any, value: number) -> TextBoxProperties ),
	Placeholder: ( self: any, text: string ) -> TextBoxProperties,
	Properties: ( self: TextBoxProperties, properties: {[string]: any}) -> TextBoxProperties,
	Connection: ( self: TextBoxProperties, func: (...any) -> ...any ) -> TextBoxProperties,

	Changed: RBXScriptSignal,
	Activated: RBXScriptSignal,
	Applied: RBXScriptSignal,
} type TextBox = ("TextBox") -> ( properties: { [string]: any } ) -> TextBoxProperties

type SearchProperties = {
	Value: string | number,
	Element: TextBox,

	SetValue: ( (self: any, text: string) -> TextBoxProperties ) & ( (self: any, value: number) -> TextBoxProperties ),
	Title: ( (self: any, text: string) -> SearchProperties ) & ( (self: any, value:number) -> SearchProperties ),
	Placeholder: ( self: any, text: string ) -> TextBoxProperties,
	Properties: ( self: TextBoxProperties, properties: {[string]: any}) -> TextBoxProperties,
	Connection: ( self: TextBoxProperties, func: (...any) -> ...any ) -> TextBoxProperties,

	Changed: RBXScriptSignal,
	Activated: RBXScriptSignal,
	Applied: RBXScriptSignal,
} type Search = ("Search") -> ( properties: { [string]: any } ) -> SearchProperties

type ColorPickerProperties = {
	Value: Color3,
	Element: TextButton,

	Pressed: ( self: ColorPickerProperties, func: (...any) -> ...any ) -> ColorPickerProperties,
	SetValue: ( self: any, value: Color3 ) -> ColorPickerProperties,
	Properties: ( self: ColorPickerProperties, properties: {[string]: any}) -> ColorPickerProperties,
	Connection: ( self: ColorPickerProperties, func: (...any) -> ...any ) -> ColorPickerProperties,

	Changed: RBXScriptSignal,
	Activated: RBXScriptSignal,
	Applied: RBXScriptSignal,
} type ColorPicker = ("ColorPicker") -> ( properties: { [string]: any } ) -> ColorPickerProperties

type SliderProperties = {
	Value: number,
	Min: number,
	Max: number,
	Element: TextButton,

	SetValue: ( self: any, value: number, min: number?, max: number?, decimalPlace: number? ) -> SliderProperties,
	SetMin: ( self: any, min: number ) -> SliderProperties,
	SetMax: ( self: any, max: number ) -> SliderProperties,
	Properties: ( self: SliderProperties, properties: {[string]: any}) -> SliderProperties,
	Connection: ( self: SliderProperties, func: (...any) -> ...any ) -> SliderProperties,

	Changed: RBXScriptSignal,
	MouseDrag: RBXScriptSignal,
	Applied: RBXScriptSignal,
} type Slider = ("Slider") -> ( properties: { [string]: any } ) -> SliderProperties


type elements = Tab & Account & Command & Toggle & Dropdown & Button & TextBox & Search & ColorPicker & Slider



----- || INDEX || -----
local infos = {
	["toggle"] = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
}



----- || MAIN || -----
return function( name: string )
	return function( inputProperties )
		if name == "Tab" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Active = false,
				Element = scope:New "TextButton" {
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = color "--Tab-Background",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(0, 1),

					[scope.OnEvent "Activated"] = function( inputObject: InputObject, clickCount: number )
						properties.Activated:Fire(inputObject, clickCount)
					end,

					[scope.OnEvent "MouseEnter"] = function() 
						properties.MouseEnter:Fire()

						if properties.Active then return end
						properties.Element.BackgroundColor3 = color "--Tab-Background-Hover"
						properties.Element.Border.Visible = true
					end,

					[scope.OnEvent "MouseLeave"] = function() 
						properties.MouseLeave:Fire()

						if properties.Active then return end
						properties.Element.BackgroundColor3 = color "--Tab-Background"
						properties.Element.Border.Visible = false
					end,

					[scope.Children] = {

						scope:New "Frame" {
							Name = "Border",
							AnchorPoint = Vector2.new(0, 1),
							BackgroundColor3 = color "--Tab-Border",
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.new(1, 0, 0, 1),
							Visible = false,
						},

						scope:New "Frame" {
							Name = "Content",
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(0, 1),

							[scope.Children] = {

								scope:New "UIListLayout" {
									FillDirection = Enum.FillDirection.Horizontal,
									SortOrder = Enum.SortOrder.LayoutOrder,	
									VerticalAlignment = Enum.VerticalAlignment.Center,
								},

								scope:New "UIPadding" {
									PaddingLeft = UDim.new(0, 20),
									PaddingRight = UDim.new(0, 20),
								},

								scope:New "ImageLabel" {
									Name = "Icon",
									BackgroundTransparency = 1,
									Size = UDim2.fromOffset(20, 20),
									LayoutOrder = 1,
									ImageColor3 = color "--Tab-Icon-Color",
								},

								scope:New "TextLabel" {
									Name = "Label",
									AutomaticSize = Enum.AutomaticSize.X,
									BackgroundTransparency = 1,
									LayoutOrder = 2,
									Size = UDim2.fromScale(0, 1),
									FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
									TextSize = 15,
									TextColor3 = color "--Tab-Text-Color",

									[scope.Children] = {

										scope:New "UIPadding" {
											PaddingLeft = UDim.new(0, 8),
										},
									}
								}
							}
						},
					}
				},


				--				

				
				SetActive = function( self )
					self.Active = true
					
					self.Element.BackgroundColor3 = color "--Tab-Background-Active"
					self.Element.BackgroundTransparency = 0
					self.Element.Border.Visible = true
					self.Element.Content.Icon.ImageColor3 = color "--Secondary-Text-Color"
					self.Element.Content.Label.TextColor3 = color "--Secondary-Text-Color"
					
					self.Changed:Fire("Active")
					return self
				end,
				
				SetInActive = function( self )
					self.Active = false
					
					self.Element.BackgroundColor3 = color "--Tab-Background"
					self.Element.BackgroundTransparency = 1
					self.Element.Border.Visible = false
					self.Element.Content.Icon.ImageColor3 = color "--Tab-Icon-Color"
					self.Element.Content.Label.TextColor3 = color "--Tab-Text-Color"
					
					self.Changed:Fire("Active")
					return self
				end,
				
				Icon = function( self, rbxassetid: string, imageRectOffset: Vector2?, imageRectSize: Vector2? )
					self.Element.Content.Icon.Image = rbxassetid
					self.Element.Content.Icon.ImageRectOffset = imageRectOffset or self.Element.Content.Icon.ImageRectOffset
					self.Element.Content.Icon.ImageRectSize = imageRectSize or self.Element.Content.Icon.ImageRectSize
					self.Changed:Fire()
					return self
				end,
				
				Title = function( self, text: string )
					self.Element.Content.Label.Text = text
					self.Changed:Fire()
					return self
				end,
				
				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (self: any, ...any) -> ...any )
					coroutine.wrap(func)(self)
					return self
				end,


				--

				
				Changed = Maid.signal("Changed"),
				MouseEnter = Maid.signal("MouseEnter"),
				MouseLeave = Maid.signal("MouseLeave"),
				Activated = Maid.signal("Activated"),
			}
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.BackgroundColor3 = color "--Tab-Background"
				properties.Element.Border.BackgroundColor3 = color "--Tab-Border"
				properties.Element.Content.Icon.ImageColor3 = color "--Tab-Icon-Color"
				properties.Element.Content.Label.TextColor3 = color "--Tab-Text-Color"
			end)
		
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end
		
		if name == "AccountTab" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Active = false,
				Element = scope:New "TextButton" {
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = color "--AccountTab-Background",
					Size = UDim2.new(1, 0, 0, 40),

					[scope.OnEvent "Activated"] = function( inputObject: InputObject, clickCount: number )
						properties.Activated:Fire(inputObject, clickCount)
					end,

					[scope.OnEvent "MouseEnter"] = function() 
						properties.MouseEnter:Fire()

						if properties.Active then return end
						properties.Element.BackgroundColor3 = color "--AccountTab-Background-Hover"
					end,

					[scope.OnEvent "MouseLeave"] = function() 
						properties.MouseLeave:Fire()

						if properties.Active then return end
						properties.Element.BackgroundColor3 = color "--AccountTab-Background"
					end,

					[scope.Children] = {

						scope:New "Frame" {
							Name = "Border",
							AnchorPoint = Vector2.new(0, 1),
							BackgroundColor3 = color "--AccountTab-Border",
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.new(1, 0, 0, 1),
							Visible = true,
						},

						scope:New "Frame" {
							Name = "Content",
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(0, 1),

							[scope.Children] = {

								scope:New "UIListLayout" {
									FillDirection = Enum.FillDirection.Horizontal,
									SortOrder = Enum.SortOrder.LayoutOrder,	
									VerticalAlignment = Enum.VerticalAlignment.Center,
								},

								scope:New "UIPadding" {
									PaddingLeft = UDim.new(0, 20),
									PaddingRight = UDim.new(0, 20),
								},

								scope:New "ImageLabel" {
									Name = "Icon",
									BackgroundTransparency = 1,
									Size = UDim2.fromOffset(20, 20),
									LayoutOrder = 1,
									ImageColor3 = color "--AccountTab-Icon-Color",
									ImageTransparency = 0.3,
								},

								scope:New "TextLabel" {
									Name = "Label",
									AutomaticSize = Enum.AutomaticSize.X,
									BackgroundTransparency = 1,
									LayoutOrder = 2,
									Size = UDim2.fromScale(0, 1),
									FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
									TextSize = 15,
									TextColor3 = color "--AccountTab-Text-Color",
									TextTransparency = 0.3,

									[scope.Children] = {

										scope:New "UIPadding" {
											PaddingLeft = UDim.new(0, 8),
										},
									}
								}
							}
						},
					}
				},


				--				


				SetActive = function( self )
					self.Active = true

					self.Element.BackgroundColor3 = color "--AccountTab-Background-Active"
					self.Element.Border.Visible = true
					self.Element.Content.Icon.ImageTransparency = 0
					self.Element.Content.Label.TextTransparency = 0

					self.Changed:Fire("Active")
					return self
				end,

				SetInActive = function( self )
					self.Active = false

					self.Element.BackgroundColor3 = color "--AccountTab-Background"
					self.Element.Border.Visible = false
					self.Element.Content.Icon.ImageTransparency = 0.3
					self.Element.Content.Label.TextTransparency = 0.3

					self.Changed:Fire("Active")
					return self
				end,
				

				SetBorder = function( self, bool: boolean )
					self.Element.Border.Visible = bool
					self.Changed:Fire("Border")
					return self
				end,
				
				Icon = function( self, rbxassetid: string, imageRectOffset: Vector2?, imageRectSize: Vector2? )
					self.Element.Content.Icon.Image = rbxassetid
					self.Element.Content.Icon.ImageRectOffset = imageRectOffset or self.Element.Content.Icon.ImageRectOffset
					self.Element.Content.Icon.ImageRectSize = imageRectSize or self.Element.Content.Icon.ImageRectSize
					self.Changed:Fire()
					return self
				end,

				Title = function( self, text: string )
					self.Element.Content.Label.Text = text
					self.Changed:Fire()
					return self
				end,

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (self: any, ...any) -> ...any )
					coroutine.wrap(func)(self)
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
				MouseEnter = Maid.signal("MouseEnter"),
				MouseLeave = Maid.signal("MouseLeave"),
				Activated = Maid.signal("Activated"),
			}
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.BackgroundColor3 = color "--AccountTab-Background"
				properties.Element.Border.BackgroundColor3 = color "--AccountTab-Border"
				properties.Element.Content.Icon.ImageColor3 = color "--AccountTab-Icon-Color"
				properties.Element.Content.Label.TextColor3 = color "--AccountTab-Text-Color"
			end)
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end
		
		--
		
		if name == "Account" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				UserId = false,
				Element = scope:New "TextButton" {
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Text = "",
					Size = UDim2.fromScale(0, 1),

					[scope.Children] = {

						scope:New "UIListLayout" {
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						},

						scope:New "UIPadding" {
							PaddingRight = UDim.new(0, 12),
						},

						Common "UserThumbnail" {
							Size = UDim2.fromOffset(24, 24),
						}:SetUserId(game:GetService("Players").LocalPlayer.UserId).Element,

						scope:New "TextLabel" {
							Name = "Label",
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundTransparency = 1,
							LayoutOrder = 2,
							Size = UDim2.fromScale(0, 1),
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
							TextSize = 15,
							TextColor3 = color "--Primary-Text-Color",
							TextTransparency = 0.3,

							[scope.Children] = {

								scope:New "UIPadding" {
									PaddingLeft = UDim.new(0, 8),
								},
							}
						},

						scope:New "ImageLabel" {
							Name = "Icon",
							BackgroundTransparency = 1,
							LayoutOrder = 3,
							Size = UDim2.fromOffset(20, 20),
							Image = "rbxassetid://105061980704922",
							ImageColor3 = color "--Primary-Text-Color",
							ImageRectOffset = Vector2.new(324, 524),
							ImageRectSize = Vector2.new(36, 36),
						}
					}
				},


				--				


				SetUserId = function( self, id: number )
					local chatColor = Util.GetChatColor(id)
					local userInfo = game:GetService("UserService"):GetUserInfosByUserIdsAsync({id})[1]

					self.Element.Thumbnail.Icon.Image = game:GetService("Players"):GetUserThumbnailAsync(id, "HeadShot", "Size420x420")
					self.Element.Thumbnail.Icon.BackgroundColor3, self.Element.Thumbnail.UIStroke.Color = chatColor, chatColor
					self.Element.Label.Text = userInfo.Username
					
					self.Changed:Fire()
					return self
				end,

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (self: any, ...any) -> ...any )
					coroutine.wrap(func)(self)
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
			}
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.Label.TextColor3 = color "--Primary-Text-Color"
				properties.Element.Icon.ImageColor3 = color "--Primary-Text-Color"
			end)
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end
		
		--
		
		if name == "Command" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "Frame" {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 0),

					[scope.Children] = {

						scope:New "UIListLayout" {
							Padding = UDim.new(0, 10),
							SortOrder = Enum.SortOrder.LayoutOrder,
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

										scope: New "Frame" {
											AutomaticSize = Enum.AutomaticSize.Y,
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 0),

											[scope.Children] = {

												scope:New "UIListLayout" {
													Padding = UDim.new(0, 5),
													FillDirection = Enum.FillDirection.Horizontal,
													SortOrder = Enum.SortOrder.LayoutOrder,
													VerticalAlignment = Enum.VerticalAlignment.Center,
												},

												scope:New "TextLabel" {
													Name = "Title",
													AutomaticSize = Enum.AutomaticSize.XY,
													BackgroundTransparency = 1,
													LayoutOrder = 1,
													Size = UDim2.new(),
													FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
													Text = "N/A",
													TextSize = 18,
													TextColor3 = color "--Primary-Text-Color",
												},
												
												scope:New "TextLabel" {
													Name = "Qualifiers",
													AutomaticSize = Enum.AutomaticSize.XY,
													BackgroundTransparency = 1,
													LayoutOrder = 1,
													Size = UDim2.new(),
													FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
													Text = "N/A",
													TextSize = 16,
													TextColor3 = color "--Description-Text-Color",
												},
											}
										},

										scope:New "TextLabel" {
											Name = "Description",
											AutomaticSize = Enum.AutomaticSize.XY,
											BackgroundTransparency = 1,
											LayoutOrder = 1,
											Size = UDim2.new(),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
											Text = "N/A",
											TextSize = 15,
											TextColor3 = color "--Description-Text-Color",
										}
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
											VerticalAlignment = Enum.VerticalAlignment.Center,
											SortOrder = Enum.SortOrder.LayoutOrder,
										},

										scope:New "TextLabel" {
											Name = "Rank",
											AutomaticSize = Enum.AutomaticSize.XY,
											BackgroundTransparency = 1,
											LayoutOrder = 1,
											Size = UDim2.new(),
											FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
											Text = "N/A",
											TextSize = 16,
											TextColor3 = color "--Description-Text-Color",
										}
									}
								}
							}
						},

						scope:New "Frame" {
							Name = "Border",
							AnchorPoint = Vector2.new(0, 1),
							BackgroundColor3 = color "--Border",
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.new(1, 0, 0, 1),
						},
					}
				},


				--				
				
				
				Command = function( self, text: string )
					self.Element.Body.Left.Frame.Title.Text = text
					return self 
				end,
				
				Qualifiers = function( self, text: string )
					self.Element.Body.Left.Frame.Qualifiers.Text = text
					return self 
				end,
				
				Rank = function( self, text: string )
					self.Element.Body.Right.Rank.Text = text
					return self 
				end,
				
				Description = function( self, text: string )
					self.Element.Body.Left.Description.Text = text
					return self
				end,

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (self: any, ...any) -> ...any )
					coroutine.wrap(func)(self)
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
			}
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.Body.Left.Frame.Title.TextColor3 = color "--Primary-Text-Color"
				properties.Element.Body.Left.Frame.Qualifiers.TextColor3 = color "--Description-Text-Color"
				properties.Element.Body.Left.Description.TextColor3 = color "--Description-Text-Color"
				properties.Element.Body.Right.Rank.TextColor3 = color "--Description-Text-Color"
				properties.Element.Border.BackgroundColor3 = color "--Border"
			end)
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end
		
		--
		
		if name == "Toggle" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Value = false,
				Element = scope:New "TextButton" {
					Name = "Value",
					BackgroundColor3 = color "--Toggle-Background-Off",		
					Size = UDim2.fromOffset(37, 14),

					[scope.OnEvent "Activated"] = function( inputObject: InputObject, clickCount: number )
						properties:Default(not properties.Value) 
						properties.Activated:Fire(inputObject, clickCount)
					end,

					[scope.Children] = {

						scope:New "UICorner" {
							CornerRadius = UDim.new(1, 0),
						},

						scope:New "Frame" {
							Name = "Shadow",
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundColor3 = color "--Shadow",
							BackgroundTransparency = 0.9,
							Position = UDim2.new(0, 2, 0.5, 2),
							Size = UDim2.fromOffset(20, 20),

							[scope.Children] = {
								scope:New "UICorner" {
									CornerRadius = UDim.new(1, 0)
								},
							}
						},

						scope:New "Frame" {
							Name = "Head",
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundColor3 = color "--Toggle-Head-Off",
							Position = UDim2.fromScale(0, 0.5),
							Size = UDim2.fromOffset(20, 20),
							ZIndex = 2,

							[scope.Children] = {
								scope:New "UICorner" {
									CornerRadius = UDim.new(1, 0)
								},
							}
						},
					}
				},


				--				

				Default = function( self, value: boolean )
					self.Value = value
					
					Maid.tween {
						[self.Element] = {
							infos.toggle, {
								BackgroundColor3 = value and color "--Toggle-Background-On" or color "--Toggle-Background-Off"	
							}
						},

						[self.Element.Shadow] = {
							infos.toggle, {
								AnchorPoint = value and Vector2.new(1, 0.5) or Vector2.new(0, 0.5),
								Position = value and UDim2.new(1, -2, 0.5, 2) or UDim2.new(0, 2, 0.5, 2)
							}
						},

						[self.Element.Head] = {
							infos.toggle, {
								Position = value and UDim2.fromScale(1, 0.5) or UDim2.fromScale(0, 0.5),
								AnchorPoint = value and Vector2.new(1, 0.5) or Vector2.new(0, 0.5),
								BackgroundColor3 = value and color "--Toggle-Head-On" or color "--Toggle-Head-Off",
							}
						},
					}

					self.Changed:Fire("Value") 
					return self
				end,
				
				Enable = function( self )
					self.Value = true
					
					Maid.tween {
						[self.Element] = {
							infos.toggle, {
								BackgroundColor3 = color "--Toggle-Background-On"		
							}
						},

						[self.Element.Shadow] = {
							infos.toggle, {
								AnchorPoint = Vector2.new(1, 0.5),
								Position = UDim2.new(1, -2, 0.5, 2)
							}
						},

						[self.Element.Head] = {
							infos.toggle, {
								Position = UDim2.fromScale(1, 0.5),
								AnchorPoint = Vector2.new(1, 0.5),
								BackgroundColor3 = color "--Toggle-Head-On"
							}
						},
					}
					
					self.Changed:Fire("Value") 
					return self
				end,
				
				Disable = function( self )
					self.Value = false
					
					Maid.tween {
						[self.Element] = {
							infos.toggle, {
								BackgroundColor3 = color "--Toggle-Background-Off",		
							}
						},

						[self.Element.Shadow] = {
							infos.toggle, {
								AnchorPoint = Vector2.new(0, 0.5),
								Position = UDim2.new(0, 2, 0.5, 2)
							}
						},

						[self.Element.Head] = {
							infos.toggle, {
								Position = UDim2.fromScale(0, 0.5),
								AnchorPoint = Vector2.new(0, 0.5),
								BackgroundColor3 = color "--Toggle-Head-Off",
							}
						},
					}
					
					self.Changed:Fire("Value") 
					return self
				end,

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (self: any, ...any) -> ...any )
					coroutine.wrap(func)(self)
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
				Activated = Maid.signal("Activated"),
				Applied = Maid.signal("Activated"),
			}
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.BackgroundColor3 = color(`--Toggle-Background-{properties.Value and "On" or "Off"}`)
				properties.Element.Head.BackgroundColor3 = color(`--Toggle-Head-{properties.Value and "On" or "Off"}`)
			end)
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end
		
		--
		
		if name == "Dropdown" then
			local scope, properties = Fusion.scoped(Fusion), {}

			properties = {
				Value = "None",
				
				Element = scope:New "TextButton" {
					AutoButtonColor = false,
					BackgroundColor3 = color "--Dropdown-Background",
					Position = UDim2.fromScale(0.25, 0.169),
					Size = UDim2.fromOffset(171, 30),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					Text = "N/A",
					TextSize = 16,
					TextColor3 = color "--Dropdown-Text-Color",
					TextXAlignment = Enum.TextXAlignment.Left,

					[scope.OnEvent "Activated"] = function()
						properties[`{properties:IsVisible() and "Hide" or "Show"}Options`](properties)
						properties.Activated:Fire()
					end,

					[scope.Children] = {

						scope:New "UICorner" {
							CornerRadius = UDim.new(0, 5)
						},

						scope:New "UIStroke" {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = color "--Dropdown-Border",
							Thickness = 1,
						},

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 12),
							PaddingRight = UDim.new(0, 6),
						},

						scope:New "ImageLabel" {
							AnchorPoint = Vector2.new(1, 0.5),
							BackgroundTransparency = 1,
							Position = UDim2.fromScale(1, 0.5),
							Size = UDim2.fromOffset(20, 20),
							Image = "rbxassetid://105061980704922",
							ImageColor3 = color "--Secondary-Text-Color",
							ImageRectOffset = Vector2.new(324, 524),
							ImageRectSize = Vector2.new(36, 36),
							ZIndex = 2,
						},
					}
				},
				
				
				--				

				
				ShowOptions = function( self )

					self.List.Parent = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("nexus-dynamics@2.0")
					self.List.Position = UDim2.fromOffset(self.Element.AbsolutePosition.X, self.Element.AbsolutePosition.Y + 95)
					self.List.Visible = true

					table.sort(self.Options, function(a, b) return a < b end)

					for x, option in self.Options or {} do 
						if self.List.ScrollingFrame:FindFirstChild(option) then continue end

						scope:New "TextButton" {	
							Name = option,
							BackgroundColor3 = self.Value == option and color "--Option-Selected" or color "--Dropdown-Background",
							AutoButtonColor = false,
							Text = option,
							Size = UDim2.new(1, 0, 0, 30),
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,
							TextColor3 = color "--Dropdown-Text-Color",
							TextXAlignment = Enum.TextXAlignment.Left,
							Parent = self.List.ScrollingFrame,

							[scope.OnEvent "Activated"] = function()
								self:Select(option):HideOptions()
							end,

							[scope.Children] = {

								scope:New "UICorner" {
									CornerRadius = UDim.new(0, 5)
								},

								scope:New "UIPadding" {
									PaddingLeft = UDim.new(0, 12)
								},
							}
						}
					end

					Maid.tween(self.List) {
						TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),

						{
							Size = UDim2.fromOffset(171, math.clamp(#self.Options*30, 0, 120))
						}
					}
				end,

				HideOptions = function( self )
					Maid.tween(self.List) {
						TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),

						{
							Size = UDim2.fromOffset(171, 0)
						}
					}

					task.delay(0.05, function()
						if self:IsVisible() then return end
						
						if not self.List:FindFirstChild("ScrollingFrame") then return end
						for _, button in self.List.ScrollingFrame:GetChildren() do
							if not button:IsA("TextButton") then continue end
							button:Destroy()
						end

						self.List.Visible = false
						self.List.Parent = nil
					end)
				end,

				Select = function( self, option: string | EnumItem )
					self.Element.Text = typeof(option) == "EnumItem" and option.Name or option
					self.Value = typeof(option) == "EnumItem" and option.Name or option
					self.Changed:Fire("Value") 
					return self
				end,

				Default = function( self, option: string | EnumItem )
					self.Element.Text = typeof(option) == "EnumItem" and option.Name or option
					self.Value = typeof(option) == "EnumItem" and option.Name or option
					self.Changed:Fire("Value") 
					return self
				end,

				SetOptions = function( self, options: {string | EnumItem} )
					self.Options = {}

					if #options == 1 and typeof(options[1]) == "table" then 
						for _, option in options[1] do
							table.insert(self.Options, typeof(option) == "EnumItem" and option.Name or option)
						end

						return self
					end

					for _, option in options do
						if typeof(option) == "string" then
							table.insert(self.Options, option) continue
						end

						if typeof(option) == "EnumItem" then
							table.insert(self.Options, option.Name) continue
						end
					end

					return self
				end,

				AddOption = function( self, option: string | EnumItem )
					if not self.Options then self.Options = {} end
					table.insert(self.Options, typeof(option) == "EnumItem" and option.Name or option)
					return self
				end,

				RemoveOption = function( self, option: string | EnumItem )
					if not self.Options then self.Options = {} end
					table.remove(self.Options, table.find(self.Options, typeof(option) == "EnumItem" and option.Name or option))
					return self
				end,
				
				IsVisible = function( self ) : boolean
					return (self.List and self.List.Parent ~= nil and self.List.Visible) and (self.List.AbsoluteSize.Y > 0)
				end,

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (self: any, ...any) -> ...any )
					coroutine.wrap(func)(self)
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
				Activated = Maid.signal("Activated"),
				Applied = Maid.signal("Activated"),
			}
			
			properties.List = scope:New "Frame" {
				BackgroundColor3 = color "--Dropdown-Background",
				Position = UDim2.fromOffset(properties.Element.AbsolutePosition.X, properties.Element.AbsolutePosition.Y + properties.Element.AbsoluteSize.Y + 5),
				Size = UDim2.fromOffset(171, 0),

				Parent = nil,
				Visible = true,

				[scope.Children] = {

					scope:New "UICorner" {
						CornerRadius = UDim.new(0, 5)
					},

					scope:New "UIStroke" {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = color "--Dropdown-Border",
						Thickness = 1,
					},

					scope:New "ScrollingFrame" {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1 ,1),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.new(),
						ScrollBarImageColor3 = color "--ScrollBar",
						ScrollBarThickness = 3,

						[scope.Children] = {

							scope:New "UIListLayout" {
								SortOrder = Enum.SortOrder.LayoutOrder,	
								HorizontalAlignment = Enum.HorizontalAlignment.Center
							},	
						}
					}	
				}
			}
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.BackgroundColor3 = color "--Dropdown-Background"
				properties.Element.TextColor3 = color "--Dropdown-Text-Color"
				properties.Element.UIStroke.Color = color "--Dropdown-Border"
				properties.Element.ImageLabel.ImageColor3 = color "--Secondary-Text-Color"
				
				properties.List.BackgroundColor3 = color "--Dropdown-Background"
				properties.List.UIStroke.Color = color "--Dropdown-Border"
				properties.List.ScrollingFrame.ScrollBarImageColor3 = color "--ScrollBar"
			end)
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end
		
		--
		
		if name == "Button" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Element = scope:New "TextButton" {
					AutomaticSize = Enum.AutomaticSize.X,
					AutoButtonColor = false,
					BackgroundColor3 = color "--Button-Background",
					Size = UDim2.fromOffset(0, 30),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
					Text = "Button",
					TextColor3 = color "--Button-Text-Color",
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Center,

					[scope.OnEvent "Activated"] = function()
						properties.Activated:Fire()
					end,

					[scope.Children] = {

						scope:New "UICorner" {
							CornerRadius = UDim.new(0, 5)
						},

						scope:New "UIStroke" {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = color "--Button-Border",
							Thickness = 1,
						},

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 15),
							PaddingRight = UDim.new(0, 15),
						},
					}
				},


				--				


				Placeholder = function( self, text: string )
					self.Element.Text = text
					self.Changed:Fire("Text")
					return self
				end,

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (self: any, ...any) -> ...any )
					coroutine.wrap(func)(self)
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
				Activated = Maid.signal("Activated"),
				Applied = Maid.signal("Activated"),
			}
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.BackgroundColor3 = color "--Button-Background"
				properties.Element.TextColor3 = color "--Button-Text-Color"
				properties.Element.UIStroke.Color = color "--Button-Border"
			end)
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end
		
		--
		
		if name == "TextBox" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Value = "N/A",
				Element = scope:New "TextBox" {
					Name = "Value",
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = color "--TextBox-Background",
					Size = UDim2.fromOffset(0, 30),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					Text = "N/A",
					TextColor3 = color "--TextBox-Text-Color",
					PlaceholderColor3 = color "--TextBox-Placeholder-Color",
					TextTruncate = Enum.TextTruncate.SplitWord,
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Center,

					[scope.OnEvent "Focused"] = function()
						task.wait(0.1)
						properties.Element.SelectionStart = 0
						properties.Element.CursorPosition = #properties.Element.Text+1
					end,

					[scope.OnEvent "FocusLost"] = function()
						properties.Value = properties.Element.Text
						properties.Changed:Fire("Value")
					end,


					[scope.Children] = {
						scope:New "UICorner" {
							CornerRadius = UDim.new(0, 5)
						},

						scope:New "UIStroke" {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = color "--TextBox-Border",
							Thickness = 1,
						},

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 15),
							PaddingRight = UDim.new(0, 15),
						},

						scope:New "UISizeConstraint" {
							MaxSize = Vector2.new(185, 30)
						},
					}
				},


				--				

				SetValue = function( self, text )
					self.Element.Text = typeof(text) == "number" and math.round(text*1000)/1000 or text
					self.Value = typeof(text) == "number" and math.round(text*1000)/1000 or text
					self.Changed:Fire("Value")
					return self
				end :: ( (self: any, text: string) -> any ) & ( (self: any, value: number) -> any ),
				
				Placeholder = function( self, text: string )
					self.Element.PlaceholderText = text
					self.Changed:Fire("PlaceholderText")
					return self
				end,

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (self: any, ...any) -> ...any )
					coroutine.wrap(func)(self)
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
				Activated = Maid.signal("Activated"),
				Applied = Maid.signal("Activated"),
			}
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.BackgroundColor3 = color "--TextBox-Background"
				properties.Element.TextColor3 = color "--TextBox-Text-Color"
				properties.Element.PlaceholderColor3 = color "--TextBox-Placeholder-Color"
				properties.Element.UIStroke.Color = color "--TextBox-Border"
			end)
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end
		
		--
		
		if name == "Search" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Value = "",
				Element = scope:New "TextBox" {
					Name = "Value",
					BackgroundColor3 = color "--Background",
					Size = UDim2.new(1, 0, 0, 30),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					Text = "",
					TextColor3 = color "--TextBox-Text-Color",
					PlaceholderColor3 = color "--TextBox-Placeholder-Color",
					TextTruncate = Enum.TextTruncate.SplitWord,
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,

					[scope.OnEvent "Focused"] = function()
						task.wait(0.1)
						properties.Element.SelectionStart = 0
						properties.Element.CursorPosition = #properties.Element.Text+1
					end,

					[scope.OnEvent "FocusLost"] = function()
						properties.Value = properties.Element.Text
						properties.Changed:Fire("Value")
					end,


					[scope.Children] = {
						scope:New "UICorner" {
							CornerRadius = UDim.new(0, 5)
						},

						scope:New "UIStroke" {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = color "--TextBox-Border",
							Thickness = 1,
						},

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 15),
							PaddingRight = UDim.new(0, 15),
						},
						
						scope:New "TextLabel" {
							Name = "Title",
							AnchorPoint = Vector2.new(0, 0.5);
							AutomaticSize = Enum.AutomaticSize.XY,
							BackgroundColor3 = color "--Background",
							Position = UDim2.fromOffset(0, 0);
							Size = UDim2.new(),
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							Text = "N/A",
							TextColor3 = color "--TextBox-Text-Color",
							TextTransparency = 0.75,
							TextTruncate = Enum.TextTruncate.SplitWord,
							TextSize = 14,
							
							[scope.Children] = {
								scope:New "UIPadding" {
									PaddingLeft = UDim.new(0, 8),
									PaddingRight = UDim.new(0, 8),
								},
							}
						}
					}
				},


				--				

				SetValue = function( self, text )
					self.Element.Text = typeof(text) == "number" and math.round(text*1000)/1000 or text
					self.Value = typeof(text) == "number" and math.round(text*1000)/1000 or text
					self.Changed:Fire("Value")
					return self
				end :: ( (self: any, text: string) -> any ) & ( (self: any, value: number) -> any ),
				
				Title = function( self, text: string )
					self.Element.Title.Text = text
					self.Changed:Fire("Title")
					return self
				end,
				
				Placeholder = function( self, text: string )
					self.Element.PlaceholderText = text
					self.Changed:Fire("PlaceholderText")
					return self
				end,

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (self: any, ...any) -> ...any )
					coroutine.wrap(func)(self)
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
				Activated = Maid.signal("Activated"),
				Applied = Maid.signal("Activated"),
			}

			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.BackgroundColor3 = color "--TextBox-Background"
				properties.Element.TextColor3 = color "--TextBox-Text-Color"
				properties.Element.PlaceholderColor3 = color "--TextBox-Placeholder-Color"
				properties.Element.UIStroke.Color = color "--TextBox-Border"
			end)

			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end
		
		--
		
		if name == "ColorPicker" then
			local scope, properties = Fusion.scoped(Fusion), nil

			properties = {
				Value = Color3.fromRGB(255, 255, 255),
				Element = scope:New "TextButton" {
					Name = "Value",
					AutomaticSize = Enum.AutomaticSize.X,
					AutoButtonColor = false,
					BackgroundColor3 = color "--TextBox-Background",
					Size = UDim2.fromOffset(0, 30),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					Text = "",
					TextColor3 = color "--TextBox-Text-Color",
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Center,

					[scope.OnEvent "Activated"] = function()
						properties.Activated:Fire()
					end,

					[scope.Children] = {

						scope:New "UIListLayout" {
							Padding = UDim.new(0, 10),
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						},

						scope:New "UICorner" {
							CornerRadius = UDim.new(0, 5)
						},

						scope:New "UIStroke" {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = color "--TextBox-Border",
							Thickness = 1,
						},

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 15),
							PaddingRight = UDim.new(0, 15),
						},

						scope:New "Frame" {
							Name = "Color",
							LayoutOrder = 1,
							Size = UDim2.fromOffset(16, 16),

							[scope.Children] = {

								scope:New "UICorner" {
									CornerRadius = UDim.new(1, 0)
								},
							}
						},

						scope:New "TextLabel" {
							Name = "Label",
							AutomaticSize = Enum.AutomaticSize.XY,
							BackgroundTransparency = 1,
							LayoutOrder = 2,
							Size = UDim2.new(),
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							Text = "N/A",
							TextSize = 16,
							TextColor3 = color "--TextBox-Text-Color",
						},
					}
				},


				--				


				Pressed = function( self, func: ( ...any ) -> any )
					self.Activated:Connect(function()
						func(self)
					end)
					
					return self
				end,
				
				SetValue = function( self, value: Color3 )
					self.Element.Color.BackgroundColor3 = value

					if shared["Nexus Dynamics"].Config.ColorWheelOutput:lower() == "rgb" then
						self.Element.Label.Text = `{math.floor((value.R * 255))}, {math.floor((value.G * 255))}, {math.floor((value.B * 255))}`
					elseif shared["Nexus Dynamics"].Config.ColorWheelOutput:lower() == "hsv" then
						local H, S, V = value:ToHSV()
						self.Element.Label.Text = `{math.floor(H * 359)}, {math.floor(S * 255)}, {math.floor(V * 255)}`
					elseif shared["Nexus Dynamics"].Config.ColorWheelOutput:lower() == "new" then
						self.Element.Label.Text = `{math.floor(value.R * self.DecimalPlace)/self.DecimalPlace}, {math.floor(value.G * self.DecimalPlace)/self.DecimalPlace}, {math.floor(value.B * self.DecimalPlace)/self.DecimalPlace}`
					elseif shared["Nexus Dynamics"].Config.ColorWheelOutput:lower() == "hex" then
						self.Element.Label.Text = `#{value:ToHex()}`
					else
						self.Element.Label.Text = BrickColor.new(value).Name
					end

					self.Value = value
					self.Changed:Fire("Value")
					return self
				end,
				
				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (self: any, ...any) -> ...any )
					coroutine.wrap(func)(self)
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
				Activated = Maid.signal("Activated"),
				Applied = Maid.signal("Activated"),
			}
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.BackgroundColor3 = color "--TextBox-Background"
				properties.Element.TextColor3 = color "--TextBox-Text-Color"
				properties.Element.Label.TextColor3 = color "--TextBox-Text-Color"
				properties.Element.UIStroke.Color = color "--TextBox-Border"
			end)
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end
		
		--
		
		if name == "Slider" then
			local scope, properties, cache = Fusion.scoped(Fusion), { Value=0, Min=0, Max=1 }, { Offset=0, DecimalPlace=100 }
			
			properties = {
				DecimalPlace = 100,
				Value = 0,
				Min = 0,
				Max = 1,
				Element = scope:New "TextButton" {
					Name = "Value",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(198, 30),
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					Text = "0",
					TextColor3 = color "--Slider-Text-Color",
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Right,

					[scope.OnEvent "MouseButton1Down"] = function()
						cache.IsDragging = true
						cache.MousePos = game:GetService("UserInputService"):GetMouseLocation()+Vector2.new(-1,-50) - properties.Element.Slider.AbsolutePosition
						cache.Scale = math.clamp(cache.MousePos.X/properties.Element.Slider.AbsoluteSize.X, 0, 1)

						cache.Distance = math.abs(properties.Max) + math.abs(properties.Min)*((properties.Min < 0) and 1 or -1)
						cache.Offset = math.abs(properties.Min)*((properties.Min < 0) and -1 or 1)
						cache.Median = cache.Distance/2 + cache.Offset			

						game:GetService("UserInputService").MouseIconEnabled = false
						properties.Element.Slider.Head:TweenSize(UDim2.fromOffset(22, 22), Enum.EasingDirection.InOut, Enum.EasingStyle.Sine, 0.05)
						properties.Value = math.clamp(math.round((tonumber((cache.Scale * cache.Distance - cache.Offset)) or properties.Min)*cache.DecimalPlace)/cache.DecimalPlace, properties.Min, properties.Max)
						properties.MouseDrag:Fire()
					end,

					[scope.Children] = {

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 15),
							PaddingRight = UDim.new(0, 15),
						},

						scope:New "Frame" {
							Name = "Slider",
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundColor3 = color "--Slider-Background",
							Position = UDim2.fromScale(0, 0.5),
							Size = UDim2.fromOffset(135, 10),

							[scope.Children] = {

								scope:New "UICorner" {
									CornerRadius = UDim.new(1, 0)
								},

								scope:New "Frame" {
									Name = "Filler",
									BackgroundColor3 = color "--Slider-Filler",
									Size = UDim2.fromScale(0, 1),
									ZIndex = 0,

									[scope.Children] = {
										scope:New "UICorner" {
											CornerRadius = UDim.new(1, 0)
										},
									}
								},

								scope:New "Frame" {
									Name = "Head",
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundColor3 = color "--Slider-Head",
									Position = UDim2.fromScale(0, 0.5),
									Size = UDim2.fromOffset(16, 16),
									ZIndex = 2,

									[scope.Children] = {
										scope:New "UICorner" {
											CornerRadius = UDim.new(1, 0)
										},

										scope:New "ImageLabel" {
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
					}
				},


				--				


				SetValue = function( self, value: number, min: number?, max: number?, decimalPlace: number? )
					if decimalPlace and tonumber(decimalPlace) then self.DecimalPlace = decimalPlace end
					if min and tonumber(min) and math.round((tonumber(min) or 0)*self.DecimalPlace)/self.DecimalPlace <= (max or self.Max) then self.Min = min end
					if max and tonumber(max) and math.round((tonumber(max) or 0)*self.DecimalPlace)/self.DecimalPlace >= (min or self.Min) then self.Max = max end

					if not tonumber(value) then return self end
					self.Value = math.clamp(math.round((tonumber(value) or self.Min)*(self.DecimalPlace or 100))/(self.DecimalPlace or 100), self.Min, self.Max)
					self.Changed:Fire("Value")
					return self
				end,
				
				SetMin = function( self, min: number )
					if not tonumber(min) or math.round((tonumber(min) or 0)*self.DecimalPlace)/self.DecimalPlace >= self.Max then return self end

					self.Min = math.round((tonumber(min) or 0)*self.DecimalPlace)/self.DecimalPlace
					self.Changed:Fire("Min")
					return self
				end,
				
				SetMax = function( self, max: number )
					if not tonumber(max) or math.round((tonumber(max) or 0)*self.DecimalPlace)/self.DecimalPlace <= self.Min then return self end

					self.Max = math.round((tonumber(max) or 1)*self.DecimalPlace)/self.DecimalPlace
					self.Changed:Fire("Max")
					return self
				end,

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (self: any, ...any) -> ...any )
					coroutine.wrap(func)(self)
					return self
				end,


				--


				Changed = Maid.signal("Changed"),
				MouseDrag = Maid.signal("MouseDrag"),
				Applied = Maid.signal("Activated"),
			}
			
			--
			
			properties.Changed:Connect(function()
				properties.Element.Text = tostring(properties.Value) 

				local length = (properties.Value - properties.Min) / (properties.Max - properties.Min)
				properties.Element.Slider.Filler.Size = UDim2.new(length, 5, 1, 0)
				properties.Element.Slider.Head.Position = UDim2.fromScale(length, 0.5)
			end)
			
			properties.MouseDrag:Connect(function()
				properties.Element.Text = tostring(properties.Value) 

				local length = (properties.Value - properties.Min) / (properties.Max - properties.Min)
				properties.Element.Slider.Filler.Size = UDim2.new(length, 5, 1, 0)
				properties.Element.Slider.Head.Position = UDim2.fromScale(length, 0.5)
			end)
			
			game:GetService("UserInputService").InputChanged:Connect(function( inputObject: InputObject )
				if not table.find({ Enum.UserInputType.MouseMovement, Enum.UserInputType.Touch }, inputObject.UserInputType) or not cache.IsDragging then return end

				cache.MousePos = game:GetService("UserInputService"):GetMouseLocation()+Vector2.new(-1,-50) - properties.Element.Slider.AbsolutePosition
				cache.Scale = math.clamp(cache.MousePos.X/properties.Element.Slider.AbsoluteSize.X, 0, 1)

				cache.Distance = math.abs(properties.Max) + math.abs(properties.Min)*((properties.Min < 0) and 1 or -1)
				cache.Offset = math.abs(properties.Min)*((properties.Min < 0) and -1 or 1)
				cache.Median = cache.Distance/2 + cache.Offset


				properties.Value = math.clamp(math.round((tonumber((cache.Scale * cache.Distance - cache.Offset)) or properties.Min)*cache.DecimalPlace)/cache.DecimalPlace, properties.Min, properties.Max)
				properties.MouseDrag:Fire()
			end)

			game:GetService("UserInputService").InputEnded:Connect(function( inputObject: InputObject )
				if not table.find({ Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch }, inputObject.UserInputType) or not cache.IsDragging then return end

				cache.IsDragging = false
				cache.MousePos = game:GetService("UserInputService"):GetMouseLocation()+Vector2.new(-1,-50) - properties.Element.Slider.AbsolutePosition
				cache.Scale = math.clamp(cache.MousePos.X/properties.Element.Slider.AbsoluteSize.X, 0, 1)

				cache.Distance = math.abs(properties.Max) + math.abs(properties.Min)*((properties.Min < 0) and 1 or -1)
				cache.Offset = math.abs(properties.Min)*((properties.Min < 0) and -1 or 1)
				cache.Median = cache.Distance/2 + cache.Offset

				game:GetService("UserInputService").MouseIconEnabled = true
				properties.Element.Slider.Head:TweenSize(UDim2.fromOffset(16, 16), Enum.EasingDirection.InOut, Enum.EasingStyle.Sine, 0.05)
				properties:SetValue(cache.Scale * cache.Distance + cache.Offset)
			end)
			
			--
			
			Package.Libraries.Theme.ThemeUpdated.Event:Connect(function()
				if not properties.Element or #properties.Element:GetChildren() == 0 then return end
				properties.Element.TextColor3 = color "--Slider-Text-Color"
				properties.Element.Slider.BackgroundColor3 = color "--Slider-Background"
				properties.Element.Slider.Filler.BackgroundColor3 = color "--Slider-Filler"
				properties.Element.Slider.Head.BackgroundColor3 = color "--Slider-Head"
			end)
			
			for propertyName, propertyValue in inputProperties do pcall(function() properties.Element[propertyName] = propertyValue end) end
			return properties
		end
	end
end :: elements