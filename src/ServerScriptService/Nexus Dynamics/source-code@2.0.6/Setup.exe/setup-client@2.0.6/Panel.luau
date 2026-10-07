----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("setup-client@2.0.6").Connector)
scope = require(script:FindFirstAncestor("setup-client@2.0.6").Libraries.Fusion)
scope = scope.scoped(scope)

color = Libraries.Color

local Canceled, Tab, Cache = false, "None", {}
local Instructions = {
	["HttpService"] = "Go to Game Settings and turn on Allow HTTP requests.",
	["APIServices"] = "Go to Game Settings and turn on Allow API Services.", 
	["ThirdPartySales"] = "Go to Game Settings and turn on Allow Third Party Sales.", 
	["ThirdPartyTeleports"] = "Go to Game Settings and turn on Allow Third PartyT eleports.", 
	["Parent"] = "Parent the model to Workspace, ServerScriptService, or Players", 
	["Finishing"] = "",
}



----- || MAIN || -----
ScreenGui = Libraries.Common "ScreenGui" {
	Name = "nexus-dynamics-setup@2.0",
	Parent = script:FindFirstAncestorWhichIsA("Player").PlayerGui,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,	
}



function LaunchPanel()
	shared["Nexus Dynamics // Setup"].Panel = Libraries.Windows "Panel" {
		Parent = ScreenGui,
		Size = UDim2.fromOffset(822, 566),
		Visible = false,
	}
	
	shared["Nexus Dynamics // Setup"].Panel.Close.MouseButton1Click:Connect(function()
		shared["Nexus Dynamics // Setup"]:Close()
		if (game:GetService("RunService"):IsStudio()) then
			local message = Instance.new("Message", workspace)
			message.Text = "Rejoin Studio Play-Test"
			game:GetService("Players").LocalPlayer:Kick("Rejoin Studio Play-Test")
		end
		task.wait(1)
		ScreenGui:Destroy()
	end)
	
	scope:New "UIScale" {
		Parent =  shared["Nexus Dynamics // Setup"].Panel.Element,
		Scale = 1
	}

	scope:New "ImageLabel" {
		Parent = shared["Nexus Dynamics // Setup"].Panel.Top,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		Image = "rbxassetid://13636059383",
		ImageColor3 = color "--Primary-Text-Color",
	}
	
	Libraries:Open()
end

function Page(name, alt)
	Tab = alt or name
	return Libraries.Switch(name) {
		["License Agreement"] = function()
			local properties; properties = {
				Element = scope:New "Frame" {
					Parent = shared["Nexus Dynamics // Setup"].Panel.Section,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),

					[scope.Children] = {
						scope:New "UIListLayout" {
							Padding = UDim.new(0, 12),
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Top,
						},

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 50),
							PaddingRight = UDim.new(0, 50),
							PaddingTop = UDim.new(0, 50),
						},

						scope:New "TextLabel" {
							Name = "Title",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.XY,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.new(),
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Text = "License Agreement",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
							TextSize = 40,
							TextColor3 = Color3.fromRGB(215, 215, 215),

							[scope.Children] = {
								scope:New "UIPadding" {
									PaddingBottom = UDim.new(0, 16),
								},
							}
						},

						scope:New "Frame" {
							Name = "Content",
							BackgroundTransparency = 1,
							Size = UDim2.new(1, 0, 0, 264),
							LayoutOrder = 2,

							[scope.Children] = {
								scope:New "UICorner" {
									CornerRadius = UDim.new(0, 8)
								},

								scope:New "UIStroke" {
									ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
									Color = color "--Top-Border",
									Thickness = 1,
								},
								
								scope:New "ScrollingFrame" {
									BackgroundTransparency = 1,
									Size = UDim2.fromScale(1, 1),
									AutomaticCanvasSize = Enum.AutomaticSize.Y,
									CanvasSize = UDim2.new(),
									ScrollBarThickness = 6,
									ScrollingDirection = Enum.ScrollingDirection.Y,
									
									[scope.Children] = {
										scope:New "UIListLayout" {
											Padding = UDim.new(0, 1),
											FillDirection = Enum.FillDirection.Vertical,
											SortOrder = Enum.SortOrder.LayoutOrder,
											Wraps = false,
										},
										
										scope:New "UIPadding" {
											PaddingBottom = UDim.new(0, 10),
											PaddingLeft = UDim.new(0, 10),
											PaddingRight = UDim.new(0, 10),
											PaddingTop = UDim.new(0, 10),
										}
									}
								}
							}
						},

						scope:New "Frame" {
							Name = "Checkbox",
							BackgroundTransparency = 1,
							Size = UDim2.new(1, 0, 0, 20),
							LayoutOrder = 3,

							[scope.Children] = {
								scope:New "UIListLayout" {
									Padding = UDim.new(0, 10),
									FillDirection = Enum.FillDirection.Horizontal,
									SortOrder = Enum.SortOrder.LayoutOrder,
									HorizontalAlignment = Enum.HorizontalAlignment.Left,
									VerticalAlignment = Enum.VerticalAlignment.Center,
								},

								scope:New "TextLabel" {
									AnchorPoint = Vector2.new(0, 0),
									AutomaticSize = Enum.AutomaticSize.XY,
									Position = UDim2.fromScale(0.5, 0.225),
									Size = UDim2.new(),
									LayoutOrder = 2,
									BackgroundTransparency = 1,
									Text = "I agree to the terms and conditions as set out by the license agreement.",
									FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
									TextSize = 16,
									TextColor3 = Color3.fromRGB(215, 215, 215),
								},

								scope:New "TextButton" {
									Size = UDim2.fromOffset(15, 15),
									BackgroundColor3 = color "--Accent",
									BackgroundTransparency = 1,
									FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
									Text = "",
									TextSize = 16,
									TextColor3 = Color3.fromRGB(255, 255, 255),
									TextXAlignment = Enum.TextXAlignment.Center,
									TextYAlignment = Enum.TextYAlignment.Center,

									[scope.Children] = {
										scope:New "UICorner" {
											CornerRadius = UDim.new(0, 4)
										},

										scope:New "UIStroke" {
											ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
											Color = color "--Top-Border",
											Thickness = 1,
										}
									}
								}
							}
						}
					}
				},

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,
				
				Value = false,
				Checked = Libraries.Maid.signal("Checked"), 
				Changed = Libraries.Maid.signal("Changed"),	
			}

			properties.Element.Checkbox.TextButton.MouseButton1Click:Connect(function()
				properties.Element.Checkbox.TextButton.BackgroundTransparency = properties.Element.Checkbox.TextButton.BackgroundTransparency == 0 and 1 or 0
				properties.Element.Checkbox.TextButton.Text = properties.Element.Checkbox.TextButton.BackgroundTransparency == 0 and "✓" or ""
				properties.Checked:Fire(properties.Element.Checkbox.TextButton.BackgroundTransparency == 0)
				properties.Value = properties.Element.Checkbox.TextButton.BackgroundTransparency == 0
			end)
			
			for i, text in {
					"<font size='24' weight='bold'>CC BY-NC-ND License (For Design)</font>",
					"The <b>Creative Commons Attribution-NonCommercial-NoDerivatives (CC BY-NC-ND)</b> license permits users to:",
					"• <b>Share</b>: Copy and redistrubute the material in any medium or format.",
					"• <b>Attribute</b>: Credit the creator appropriately by including the name of the creator and link to the original work.",
					"",
					"However, users are <b>prohibited from:</b>",
					"• Using the material for <b>commercial purposes</b>, meaning any activity intended for financial gain.",
					"• Creating <b>derivative works</b> or adaptations, including remix, transform, tranlsation, or build upon the original material.",	
					"• Applying additional <b>legal or technological restrictions</b> that prevent others from exercising the rights granted by this license.",
					"<font size='16' weight='bold'></font>",
					"<font size='24' weight='bold'>MIT License (For Source-Code)</font>",
					"The <b>MIT License</b> is a highly permissive open-source license granting users wide-ranging rights to:",
					"• <b>Use:</b> Employ the software for any purpose, whether personal, educational, or commercial.",
					"• <b>Modify:</b> Alter the source code or create derivative works based on the original software.",
					"• <b>Distribute:</b> Share the original software or any modified versions without restrictions.",
					"• <b>Sublicense:</b> Grant these rights to other users under the same terms. do",
					"• <b>Sell:</b> Commercialize the software, including selling original or modified versions.",
					"",
					"<b>Obligations of Users:</b>",
					"• <b>Include:</b>Users must include the original copyright notice and a copy of the MIT License in any distributed version of the software.",
					'• <b>Accept:</b> Users acknowledge that the software is provided "as-is," without any warranties of fitness for a specific purpose or liability for potential damages.',
					"<font size='16' weight='bold'></font>",
					"<font size='24' weight='bold'>Intellectual Property Rights</font>",
					"The intellectual property (IP) rights for the materials and software governed by this agreement are retained solely by <b>Dev Equip</b> and its developer <b>DonKingFrog</b>. do",
					"<b>Key Conditions:</b>",
					"• Any unauthorized use of the materials or software outside the scope of these licenses may result in legal action.",
					"• Dev Equip reserves the right to modify or update this agreement as necessary, with updated terms taking effect upon publication.",
			} do
				scope:New "TextLabel" {
					Parent = properties.Element.Content.ScrollingFrame,
					AnchorPoint = Vector2.new(0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Position = UDim2.fromScale(0.5, 0.225),
					Size = UDim2.new(1, 0, 0, 0),
					LayoutOrder = i,
					BackgroundTransparency = 1,
					Text = text,
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextSize = #text > 0 and 16 or 5,
					TextColor3 = Color3.fromRGB(215, 215, 215),
					TextWrapped = true,
					RichText = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					
					[scope.Children] = {
						scope:New "UIPadding" {
							PaddingBottom = UDim.new(0, 16),
						},
					}
				}
			end
			
			return properties
		end,
		
		["Checking Environment"] = function()
			local properties; properties = {
				Element = scope:New "Frame" {
					Parent = shared["Nexus Dynamics // Setup"].Panel.Section,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),

					[scope.Children] = {
						scope:New "UIListLayout" {
							Padding = UDim.new(0, 12),
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Top,
						},

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 50),
							PaddingRight = UDim.new(0, 50),
							PaddingTop = UDim.new(0, 50),
						},

						scope:New "TextLabel" {
							Name = "Title",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.XY,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.new(),
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Text = "Checking Environment",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
							TextSize = 40,
							TextColor3 = Color3.fromRGB(215, 215, 215),

							[scope.Children] = {
								scope:New "UIPadding" {
									PaddingBottom = UDim.new(0, 16),
								},
							}
						},

						scope:New "TextLabel" {
							Name = "Status",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.XY,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.new(),
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Text = "Status",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,
							TextColor3 = Color3.fromRGB(215, 215, 215),

							[scope.Children] = {
								scope:New "UIPadding" {
									PaddingBottom = UDim.new(0, 16),
								},
							}
						},
						
						scope:New "TextLabel" {
							Name = "Http",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.fromScale(1, 0),
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Text = "Checking Http request",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,
							TextColor3 = Color3.fromRGB(215, 215, 215),
							TextXAlignment = Enum.TextXAlignment.Left,
						},
						
						scope:New "TextLabel" {
							Name = "API",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.fromScale(1, 0),
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Text = "Checking API Services",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,
							TextTransparency = 0.5,
							TextColor3 = Color3.fromRGB(215, 215, 215),
							TextXAlignment = Enum.TextXAlignment.Left,
						},

						scope:New "TextLabel" {
							Name = "Sales",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.fromScale(1, 0),
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Text = "Checking Third Party Sales",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,
							TextTransparency = 0.5,
							TextColor3 = Color3.fromRGB(215, 215, 215),
							TextXAlignment = Enum.TextXAlignment.Left,
						},

						scope:New "TextLabel" {
							Name = "Teleports",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.fromScale(1, 0),
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Text = "Checking Third Party Teleports",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,
							TextTransparency = 0.5,
							TextColor3 = Color3.fromRGB(215, 215, 215),
							TextXAlignment = Enum.TextXAlignment.Left,
						},

						scope:New "TextLabel" {
							Name = "Parent",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.fromScale(1, 0),
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Text = "Checking Parent",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,
							TextTransparency = 0.5,
							TextColor3 = Color3.fromRGB(215, 215, 215),
							TextXAlignment = Enum.TextXAlignment.Left,
						},

						scope:New "TextLabel" {
							Name = "Finishing",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.fromScale(1, 0),
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Text = "Finishing up",
							TextTransparency = 0.5,
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,
							TextColor3 = Color3.fromRGB(215, 215, 215),
							TextXAlignment = Enum.TextXAlignment.Left,
						},
					}
				},

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,

				Changed = Libraries.Maid.signal("Changed"),	
			}
			
			
			properties.HttpService = properties.Element:FindFirstChild("Http")
			properties.APIServices = properties.Element:FindFirstChild("API")
			properties.ThirdPartySales = properties.Element:FindFirstChild("Sales")
			properties.ThirdPartyTeleports = properties.Element:FindFirstChild("Teleports")
			properties.Parent = properties.Element:FindFirstChild("Parent")
			properties.Finishing = properties.Element:FindFirstChild("Finishing")
			
			return properties
		end,
		
		["Admin"] = function()
			local properties; properties = {
				Element = scope:New "Frame" {
					Parent = shared["Nexus Dynamics // Setup"].Panel.Section,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),

					[scope.Children] = {
						scope:New "UIListLayout" {
							Padding = UDim.new(0, 12),
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Top,
						},

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 50),
							PaddingRight = UDim.new(0, 50),
							PaddingTop = UDim.new(0, 50),
						},

						scope:New "TextLabel" {
							Name = "Title",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.XY,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.new(),
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Text = "Admin",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
							TextSize = 40,
							TextColor3 = Color3.fromRGB(215, 215, 215),
						},

						scope:New "TextLabel" {
							Name = "Description",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.XY,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.new(),
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Text = "Give people administrative permissions",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,
							TextColor3 = Color3.fromRGB(215, 215, 215),

							[scope.Children] = {
								scope:New "UIPadding" {
									PaddingBottom = UDim.new(0, 16),
								},
							}
						},

						scope:New "Frame" {
							Name = "Content",
							BackgroundTransparency = 1,
							Size = UDim2.new(1, 0, 0, 264),
							LayoutOrder = 2,

							[scope.Children] = {
								scope:New "UICorner" {
									CornerRadius = UDim.new(0, 8)
								},

								scope:New "UIStroke" {
									ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
									Color = color "--Top-Border",
									Thickness = 1,
								},

								scope:New "ScrollingFrame" {
									BackgroundTransparency = 1,
									Size = UDim2.new(1, 0, 0.8, -25),
									Position = UDim2.fromOffset(0, 25),
									CanvasSize = UDim2.new(),
									ScrollBarImageTransparency = 1,
									ScrollBarThickness = 0,
									AutomaticCanvasSize = Enum.AutomaticSize.Y,

									[scope.Children] = {
										scope:New "UIListLayout" {
											Padding = UDim.new(0, 0),
											FillDirection = Enum.FillDirection.Vertical,
											SortOrder = Enum.SortOrder.LayoutOrder,
											Wraps = false,
											HorizontalAlignment = Enum.HorizontalAlignment.Left,
											VerticalAlignment = Enum.VerticalAlignment.Top,
										},
	
										scope:New "Frame" {
											Name = "New",
											AutomaticSize = Enum.AutomaticSize.Y,
											LayoutOrder = 9999,
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 0),

											[scope.Children] = {
												scope:New "UIPadding" {
													PaddingTop = UDim.new(0, 12),
													PaddingLeft = UDim.new(0, 8),
												},
												
												scope:New "TextButton" {
													Name = "Button",
													AutomaticSize = Enum.AutomaticSize.XY,
													BackgroundColor3 = color "--Accent",
													Size = UDim2.fromScale(0, 0),
													Text = "New",
													FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
													TextSize = 16,
													TextColor3 = color "--Accent-Text-Color",
													TextXAlignment = Enum.TextXAlignment.Left,

													[scope.Children] = {
														scope:New "UIPadding" {
															PaddingLeft = UDim.new(0, 6),
															PaddingRight = UDim.new(0, 6),
															PaddingTop = UDim.new(0, 6),
															PaddingBottom = UDim.new(0, 6),
														},

														scope:New "UICorner" {
															CornerRadius = UDim.new(0, 4),
														},
													}
												}
											}	
										},
									}
								},

								scope:New "Frame" {
									BackgroundColor3 = color "--Top-Background",
									Size = UDim2.new(1, 0, 0, 25),

									[scope.Children] = {
										scope:New "UICorner" {
											CornerRadius = UDim.new(0, 8),
										},
										
										scope:New "Frame" {
											BackgroundColor3 = color "--Top-Background",
											AnchorPoint = Vector2.new(0, 1),
											Position = UDim2.fromScale(0, 1),
											Size = UDim2.new(1, 0, 0, 12),
											ZIndex = 0,
										},
										
										scope:New "Frame" {
											BackgroundTransparency = 1,
											Size = UDim2.fromScale(1, 1),
											
											[scope.Children] = {
												scope:New "UIListLayout" {
													FillDirection = Enum.FillDirection.Horizontal,
													SortOrder = Enum.SortOrder.LayoutOrder,
													HorizontalFlex = Enum.UIFlexAlignment.Fill,
													HorizontalAlignment = Enum.HorizontalAlignment.Left,
													VerticalAlignment = Enum.VerticalAlignment.Center,
													Wraps = false,
													Padding = UDim.new(0, 16);
												},
												
												scope:New "UIPadding" {
													PaddingLeft = UDim.new(0, 12),
												},
												
												scope:New "TextLabel" {
													AutomaticSize = Enum.AutomaticSize.X,
													BackgroundTransparency = 1,
													LayoutOrder = 1,
													Size = UDim2.fromScale(1, 1),
													Text = "Name",
													FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
													TextSize = 16,
													TextColor3 = Color3.fromRGB(215, 215, 215),
													TextXAlignment = Enum.TextXAlignment.Left,
												},
												
												scope:New "TextLabel" {
													AutomaticSize = Enum.AutomaticSize.X,
													BackgroundColor3 = Color3.fromRGB(0, 0, 0),
													BackgroundTransparency = 0.8,
													LayoutOrder = 2,
													Size = UDim2.fromScale(1, 1),
													Text = "Type",
													FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
													TextSize = 16,
													TextColor3 = Color3.fromRGB(215, 215, 215),
													TextXAlignment = Enum.TextXAlignment.Left,
													
													[scope.Children] = {
														scope:New "UIPadding" {
															PaddingLeft = UDim.new(0, 12),
														}
													}
												},
												
												scope:New "TextLabel" {
													AutomaticSize = Enum.AutomaticSize.X,
													BackgroundTransparency = 1,
													LayoutOrder = 3,
													Size = UDim2.fromScale(1, 1),
													Text = "Rank",
													FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
													TextSize = 16,
													TextColor3 = Color3.fromRGB(215, 215, 215),
													TextXAlignment = Enum.TextXAlignment.Left,
												},
											}
										},
									}
								},
							}
						},
					}
				},

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,

				Changed = Libraries.Maid.signal("Changed"),	
			}

			return properties
		end,
			
		["Rank"] = function()
			local properties; properties = {
				Element = scope:New "Frame" {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					ClipsDescendants = false,
					
					[scope.Children] = {
						scope:New "UIListLayout" {
							Padding = UDim.new(0, 12),
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Top,
						},

						scope:New "UIPadding" {
							PaddingLeft = UDim.new(0, 50),
							PaddingRight = UDim.new(0, 50),
							PaddingTop = UDim.new(0, 50),
						},

						scope:New "TextLabel" {
							Name = "Title",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.XY,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.new(),
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Text = "Add Rank",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
							TextSize = 40,
							TextColor3 = Color3.fromRGB(215, 215, 215),
						},

						scope:New "TextLabel" {
							Name = "Description",
							AnchorPoint = Vector2.new(0, 0),
							AutomaticSize = Enum.AutomaticSize.XY,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.new(),
							LayoutOrder = 2,
							BackgroundTransparency = 1,
							Text = "Add a person, group, or condition for an administrator rank.",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,
							TextColor3 = Color3.fromRGB(215, 215, 215),

							[scope.Children] = {
								scope:New "UIPadding" {
									PaddingBottom = UDim.new(0, 16),
								},
							}
						},

						scope:New "ScrollingFrame" {
							Name = "Content";
							BackgroundTransparency = 1,
							Size = UDim2.new(1, 0, 0, 264),
							CanvasSize = UDim2.new(),
							LayoutOrder = 3,
							ScrollBarImageTransparency = 1,
							ScrollBarThickness = 0,
							ClipsDescendants = false,
							AutomaticCanvasSize = Enum.AutomaticSize.Y,

							[scope.Children] = {
								scope:New "UIListLayout" {
									Padding = UDim.new(0, 10),
									FillDirection = Enum.FillDirection.Vertical,
									SortOrder = Enum.SortOrder.LayoutOrder,
									Wraps = false,
									HorizontalAlignment = Enum.HorizontalAlignment.Left,
									VerticalAlignment = Enum.VerticalAlignment.Top,
								},
								
								scope:New "UIPadding" {
									PaddingLeft = UDim.new(0, 3),
									PaddingRight = UDim.new(0, 3),
									PaddingBottom = UDim.new(0, 8),
									PaddingTop = UDim.new(0, 8),
								},
							}
						},
					}
				},

				Visible = function( self, name )
					if (self[name]) and (typeof(self[name]) == "Instance") then
						self[name].Parent = self.Element.Content
					elseif (self[name]) and (typeof(self[name]) == "table") then
						self[name].Element.Parent = self.Element.Content
					end
				end,

				Hide = function( self, name )  
					if (self[name]) and (typeof(self[name]) == "Instance") then
						self[name].Parent = nil
					elseif (self[name]) and (typeof(self[name]) == "table") then
						self[name].Element.Parent = nil
					end
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

				Changed = Libraries.Maid.signal("Changed"),	
			}

			properties.Type = Libraries.Interactions "Dropdown" { LayoutOrder = 1, Parent = properties.Element.Content, Size = UDim2.new(1, 0, 0, 40), ZIndex = 5, }
				:Title("Type")
				:Default("User")
				:SetOptions({
					"User",
					"Group",
					"PrivateServerOwner",
					"Friends",
					"Free",
					"Gamepass",
					"Asset",
				})
				:Connection(function(self)					
					self.Changed:Connect(function()
						if (self.Value == "User") then
							properties:Visible "Username"
							properties:Hide "Group"
							properties:Hide "Asset"
							properties:Hide "Gamepass"
						elseif (self.Value == "Group") then
							properties:Hide "Username"
							properties:Visible "Group"
							properties:Hide "Asset"
							properties:Hide "Gamepass"
						elseif (self.Value == "PrivateServerOwner") then
							properties:Hide "Username"
							properties:Hide "Group"
							properties:Hide "Asset"
							properties:Hide "Gamepass"
						elseif (self.Value == "Friends") then
							properties:Hide "Username"
							properties:Hide "Group"
							properties:Hide "Asset"
							properties:Hide "Gamepass"
						elseif (self.Value == "Free") then
							properties:Hide "Username"
							properties:Hide "Group"
							properties:Hide "Asset"
							properties:Hide "Gamepass"
						elseif (self.Value == "Gamepass") then
							properties:Hide "Username"
							properties:Hide "Group"
							properties:Hide "Asset"
							properties:Visible "Gamepass"
						elseif (self.Value == "Asset") then
							properties:Hide "Username"
							properties:Hide "Group"
							properties:Visible "Asset"
							properties:Hide "Gamepass"
						end
					end)
				end)

			properties.Username = Libraries.Interactions "Search" {  LayoutOrder = 5, Parent = properties.Element.Content, Size = UDim2.new(1, 0, 0, 40), ZIndex = 4, }
				:Title("Username")
				:Placeholder("Username")
				:SetValue("")

			properties.Group = scope:New "Frame" {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 5,
				Size = UDim2.fromScale(1, 0),
				ZIndex = 4,
				
				[scope.Children] = {
					scope:New "UIListLayout" {
						Padding = UDim.new(0, 8),
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalFlex = Enum.UIFlexAlignment.Fill,
					}
				}
			}

			properties.GroupId = Libraries.Interactions "Search" { Parent = properties.Group,  LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), ZIndex = 1, }
				:Title("Group Id")
				:Placeholder("(specify id)")
				:SetValue("")
			
			properties.GroupRank = Libraries.Interactions "Search" { Parent = properties.Group , LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 40), ZIndex = 2, }
				:Title("Group Rank")
				:Placeholder("0-255")
				:SetValue("")
			
			properties.Asset = Libraries.Interactions "Search" { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 40), ZIndex = 4, }
				:Title("Asset")
				:Placeholder("(specify id)")
				:SetValue("")
			
			properties.Gamepass = Libraries.Interactions "Search" { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 40), ZIndex = 4, }
				:Title("Gamepass")
				:Placeholder("(specify id)")
				:SetValue("")
			
			properties.Rank = Libraries.Interactions "Dropdown" { LayoutOrder = 10, Parent = properties.Element.Content, Size = UDim2.new(1, 0, 0, 40), ZIndex = 1, }
				:Title("Rank")
				:Select("(Select Option)")
				:SetOptions({
					"Developer",
					"Admin",
					"Mod",
					"VIP",
				})
			
			return properties
		end,
			
		["Loading"] = function()
			local properties; properties = {
				Element = scope:New "Frame" {
					Parent = shared["Nexus Dynamics // Setup"].Panel.Section,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),

					[scope.Children] = {
						scope:New "TextLabel" {
							Name = "Title",
							AnchorPoint = Vector2.new(0.5, 0),
							AutomaticSize = Enum.AutomaticSize.XY,
							Position = UDim2.fromScale(0.5, 0.225),
							Size = UDim2.new(),
							BackgroundTransparency = 1,
							Text = "Nexus Dynamics",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
							TextSize = 50,
							TextColor3 = color "--Primary-Text-Color",
						},

						scope:New "TextLabel" {
							Name = "Description",
							AnchorPoint = Vector2.new(0.5, 0),
							AutomaticSize = Enum.AutomaticSize.XY,
							Position = UDim2.fromScale(0.5, 0.325),
							Size = UDim2.new(),
							BackgroundTransparency = 1,
							Text = "Manage with precision, innovate with ease",
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 20,
							TextColor3 = color "--Primary-Text-Color",
						},

						scope:New "ImageLabel" {
							Name = "T1",
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.75),
							Size = UDim2.fromOffset(75, 75),

							Image = "rbxassetid://76188912702252"
						},

						scope:New "ImageLabel" {
							Name = "T2",
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.75),
							Size = UDim2.fromOffset(75, 75),

							Image = "rbxassetid://93899498595709"
						},

						scope:New "ImageLabel" {
							Name = "T3",
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.75),
							Size = UDim2.fromOffset(75, 75),

							Image = "rbxassetid://83452082795879"
						},

						scope:New "TextLabel" {
							Name = "Alt",
							AnchorPoint = Vector2.new(0.5, 0),
							AutomaticSize = Enum.AutomaticSize.XY,
							Position = UDim2.fromScale(0.5, 0.9),
							Size = UDim2.new(),
							Text = alt,
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 18,
							TextColor3 = color "--Primary-Text-Color",
						}
					}
				},

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,

				Changed = Libraries.Maid.signal("Changed"),	
			}

			task.spawn(function() while task.wait() and (properties.Element.Parent) do
					properties.Element.T1.Rotation -= 1.5
					properties.Element.T2.Rotation += 4.5
					properties.Element.T3.Rotation -= 4.5
				end end)

			return properties
		end,
		
		["Finalizing"] = function()
			local properties; properties = {
				Element = scope:New "Frame" {
					Parent = shared["Nexus Dynamics // Setup"].Panel.Section,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),

					[scope.Children] = {
						scope:New "ImageLabel" {
							Name = "T1",
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.45),
							Size = UDim2.fromOffset(75, 75),

							Image = "rbxassetid://76188912702252"
						},

						scope:New "ImageLabel" {
							Name = "T2",
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.45),
							Size = UDim2.fromOffset(75, 75),

							Image = "rbxassetid://93899498595709"
						},

						scope:New "ImageLabel" {
							Name = "T3",
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.45),
							Size = UDim2.fromOffset(75, 75),

							Image = "rbxassetid://83452082795879"
						},

						scope:New "TextLabel" {
							Name = "Alt",
							AnchorPoint = Vector2.new(0.5, 0),
							AutomaticSize = Enum.AutomaticSize.XY,
							Position = UDim2.fromScale(0.5, 0.55),
							Size = UDim2.new(),
							Text = "Finalizing your settings",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 18,
							TextColor3 = color "--Primary-Text-Color",
						}
					}
				},

				Properties = function( self, properties: { [string]: any } ) 
					for propertyName, propertyValue in properties do pcall(function() self.Element[propertyName] = propertyValue end) end
					self.Changed:Fire()
					return self
				end,

				Connection = function( self, func: (...any) -> ...any )
					coroutine.wrap(func)()
					return self
				end,

				Changed = Libraries.Maid.signal("Changed"),	
			}

			task.spawn(function() while task.wait() and (properties.Element.Parent) do
					properties.Element.T1.Rotation -= 1
					properties.Element.T2.Rotation += 3
					properties.Element.T3.Rotation -= 3
				end end)

			return properties
		end,
	}	
end

function Actions(skip, next) 
	local Actions = scope:New "Frame" {
		Name = "Actions",
		Parent = shared["Nexus Dynamics // Setup"].Panel.Section,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 75),
		BackgroundTransparency = 1,

		[scope.Children] = {
			scope:New "UIListLayout" {
				Padding = UDim.new(0, 8),
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			},

			scope:New "UIPadding" {
				PaddingLeft = UDim.new(0, 25),
				PaddingRight = UDim.new(0, 25),
			},

			Libraries.Interactions "Button" {
				Name = "Skip",
				BackgroundTransparency = 1,
				TextSize = 20,
				Text = "Skip",
				FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				TextColor3 = color "--Primary-Text-Color",
			}.Element,

			Libraries.Interactions "Button" {
				Name = "Next",
				BackgroundColor3 = color "--Accent",
				Text = "Next",
				FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				TextSize = 20,
				TextColor3 = color "--Accent-Text-Color",
			}.Element,
		}
	}

	
	if skip then
		Actions.Skip.UIPadding.PaddingBottom = UDim.new(0, 10)
		Actions.Skip.UIPadding.PaddingTop = UDim.new(0, 10)
		Actions.Skip.UIPadding.PaddingRight = UDim.new(0, 25)
		Actions.Skip.UIPadding.PaddingLeft = UDim.new(0, 25)
		Actions.Skip.UIStroke:Destroy()
	else 
		Actions.Skip:Destroy()
	end
	
	if next then
		Actions.Next.UICorner.CornerRadius = UDim.new(0, 8)
		Actions.Next.UIPadding.PaddingBottom = UDim.new(0, 10)
		Actions.Next.UIPadding.PaddingTop = UDim.new(0, 10)
		Actions.Next.UIPadding.PaddingRight = UDim.new(0, 50)
		Actions.Next.UIPadding.PaddingLeft = UDim.new(0, 50)
	else 
		Actions.Next:Destroy()
	end
	
	return Actions
end



local InitialPrompt do
	local Popup = Libraries.Windows "Prompt" { Parent = ScreenGui }
		:Title("Nexus Dynamics - Installation")
		:Description("Setup procedures to successfully install Nexus Dynamics.")
		:Alt(nil)
		:ButtonA("Run Setup")
		:ButtonB("Cancel")


	Popup.ButtonAPressed:Once(function()
		Popup.Element:Destroy()
		LaunchPanel()
		Page("Loading", "Booting up")
	end)

	Popup.ButtonBPressed:Once(function()
		Popup.Element:Destroy()
		Canceled = true
	end)	
end

local LicenseAgreement do
	repeat task.wait() until Canceled or Tab == "Booting up" 
	if Canceled then ScreenGui:Destroy() return end
	local val = true
	
	task.delay(5, function()
		shared["Nexus Dynamics // Setup"].Panel.Section:FindFirstChild("Frame"):Destroy()
		local page = Page("License Agreement")
		local actions = Actions(false, true)
		actions.Next.BackgroundTransparency = 0.5
		actions.Next.MouseButton1Click:Once(function()
			if (not page.Value) then return end
			val = false
			actions:Destroy()
		end)
		
		page.Checked:Connect(function(bool)
			if not bool and shared["Nexus Dynamics // Setup"].Panel.Section:FindFirstChild("Actions") then 
				actions.Next.BackgroundTransparency = 0.5
			else
				actions.Next.BackgroundTransparency = 0				
			end
		end)
	end)
	
	while task.wait() and (Canceled == false and val == true)  do end
end

local Environment do
	repeat task.wait() until Canceled or Tab == "License Agreement" 
	if Canceled then ScreenGui:Destroy() return end
	shared["Nexus Dynamics // Setup"].Panel.Section:FindFirstChild("Frame"):Destroy()
	local page = Page("Checking Environment")


	for _, item in {"HttpService", "APIServices", "ThirdPartySales", "ThirdPartyTeleports", "Parent", "Finishing"} do
		page[item].TextTransparency = 0
		local length = math.random(1, 8)/2
		local count = 0
		local text = page[item].Text
		local dots = {".", ". .", ". . ."}

		repeat
			task.wait(0.5)

			local dotIndex = (count % #dots) + 1
			local currentDots = dots[dotIndex]

			page[item].Text = text .. " " .. currentDots
			count += 1
		until count/2 >= length


		if (_G["setup-client@2.0.6\environment"][item]) then
			page[item].Text = `<s>{text}</s> <font color="#00ff00" size="20" weight="bold">✓</font>`
			page[item].RichText = true
			page[item].TextTransparency = 0.5
			continue
		end

		page[item].Text = `<font size="15">An error occured</font>\n{text}: [{Instructions[item]}]`
		page[item].RichText = true
		page[item].TextColor3 = Color3.fromRGB(205, 50, 50)		
		page[item].TextSize = 18

		return true
	end

	shared["Nexus Dynamics // Setup"].Panel.Section:FindFirstChild("Frame"):Destroy()
	Page("Loading", "Getting Ready")
end

local Admin do
	repeat task.wait() until Canceled or Tab == "Getting Ready" 
	if Canceled then ScreenGui:Destroy() return end
	task.delay(5, function()
		shared["Nexus Dynamics // Setup"].Panel.Section:FindFirstChild("Frame"):Destroy()
		local page, rankpage = Page("Admin"), Page("Rank")
		local actions, rankActions = Actions(false, true), Actions(true, true)
		rankActions.Parent, rankActions.Next.Text, rankActions.Skip.Text = nil, "Rank", "Cancel"
		rankpage.Element.Parent = nil
		
		actions.Next.MouseButton1Click:Once(function()
			local ranks = {

				Ranks = {
					{5,      "Owner",                       };
					{4,      "Developer",      { "", 0 }    };
					{3,      "Admin",          { "", 0 }    };
					{2,      "Mod",            { "", 0 }    };
					{1,      "VIP",            { "", 0 }    };
					{0,      "None",                        };

					{-1,     "Banland",        { "", 0 }    };

					`FreeAdmin:                         None`;
					`Friends:                           None`;
					`PrivateServerOwner:                None`;																																																																																
				},

				Assign = {

					Assets = {
						[0] = "None",	
					},

					Gamepasses = {
						[0] = "None",
					},

					Groups = {
						[0] = {
							[255] = "Owner",
						},
					},																																																																											   
				}
			}
			
			for _, frame in page.Element.Content.ScrollingFrame:GetChildren() do
				if (not frame:IsA("Frame")) or (not  frame:FindFirstChild("Frame")) then continue end
				local _name, _type, _rank = frame.Frame:FindFirstChild("Name").Text, frame.Frame:FindFirstChild("Type").Text, frame.Frame:FindFirstChild("Rank").Text
				
				if (_type:lower() == "user") then
					for x, rank in ranks.Ranks do
						if (typeof(rank) == "string") or (rank[2]:lower() ~= _rank:lower()) then continue end
						local id = game:GetService("Players"):GetUserIdFromNameAsync(_name)
						if not id then continue end
						table.insert(ranks.Ranks[x][3], id)
					end
				elseif (_type:lower() == "group") then
					local splitInfo = _name:split(" ")
					
					if (ranks.Assign.Groups[tonumber(splitInfo[1]) or 0]) then
						if splitInfo[1] and splitInfo[2] then
							ranks.Assign.Groups[tonumber(splitInfo[1]) or 0][tonumber(splitInfo[2]:sub(2, #splitInfo[2]-1) or 0)] = _rank
						end
					else
						if splitInfo[1] and splitInfo[2] then
							ranks.Assign.Groups[tonumber(splitInfo[1]) or 0] = {
								[tonumber(splitInfo[2]:sub(2, #splitInfo[2]-1) or 0)] = _rank
							}
						end
					end
				elseif (_type:lower() == "free") then
					for x, rank in ranks.Ranks do
						if (typeof(rank) ~= "string") or (not rank:lower():find("freeadmin")) then continue end
						ranks.Ranks[x] = `FreeAdmin:                         {_rank}`;
						break
					end
				elseif (_type:lower() == "friends") then
					for x, rank in ranks.Ranks do
						if (typeof(rank) ~= "string") or (not rank:lower():find("friends")) then continue end
						ranks.Ranks[x] = `Friends:                           {_rank}`;
						break
					end
				elseif (_type:lower() == "privateserverowner") then
					for x, rank in ranks.Ranks do
						if (typeof(rank) ~= "string") or (not rank:lower():find("privateserverowner")) then continue end
						ranks.Ranks[x] = `PrivateServerOwner:                {_rank}`;
						break
					end
				elseif (_type:lower() == "asset") then
					ranks.Assign.Assets[tonumber(_name) or 0] = _rank
				elseif (_type:lower() == "gamepass") then
					ranks.Assign.Gamepasses[tonumber(_name) or 0] = _rank
				end
			end
			
			if (game:GetService("ReplicatedStorage"):FindFirstChild("nexus-dynamics@2.0-failsafe", true)) then
				task.spawn(function() game:GetService("ReplicatedStorage"):FindFirstChild("nexus-dynamics@2.0-failsafe", true):InvokeServer(ranks) end)
			else
				error("Couldn't find remote function ['nexus-dynamics@2.0-failsafe'].")
			end
			
			page.Element:Destroy()
			rankpage.Element:Destroy()
			actions:Destroy()
			rankActions:Destroy()
			Page("Finalizing")
		end)
		
		local function generateLabel(name, rankType, rank, Order, removable)	
			local remove = removable and scope:New "TextButton" {
				Name = "Remove",
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 40, 1, 0),
				Text = "X",
				FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				TextSize = 16,
				TextColor3 = Color3.fromRGB(255, 0, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			} or nil
			
			if (remove) then
				remove.MouseButton1Click:Once(function()
					if (not remove.Parent) then return end 
					remove.Parent.Parent.Parent:Destroy()
				end)
			end
			
			return scope:New "Frame" {
				Parent = page.Element.Content.ScrollingFrame,
				BackgroundColor3 = color "--Top-Background",
				BackgroundTransparency = 0.5,
				Size = UDim2.new(1, 0, 0, 25),

				[scope.Children] = {

					scope:New "Frame" {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),

						[scope.Children] = {
							scope:New "UIListLayout" {
								FillDirection = Enum.FillDirection.Horizontal,
								SortOrder = Enum.SortOrder.LayoutOrder,
								HorizontalFlex = Enum.UIFlexAlignment.Fill,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Wraps = false,
								Padding = UDim.new(0, 16);
							},

							scope:New "UIPadding" {
								PaddingLeft = UDim.new(0, 12),
							},

							scope:New "TextLabel" {
								Name = "Name",
								BackgroundTransparency = 1,
								LayoutOrder = 1,
								Size = UDim2.fromScale(1, 1),
								Text = name,
								FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
								TextSize = 16,
								TextColor3 = Color3.fromRGB(215, 215, 215),
								TextXAlignment = Enum.TextXAlignment.Left,
							},

							scope:New "TextLabel" {
								Name = "Type",
								BackgroundColor3 = Color3.fromRGB(0, 0, 0),
								BackgroundTransparency = 0.8,
								LayoutOrder = 2,
								Size = UDim2.fromScale(1, 1),
								Text = rankType,
								FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
								TextSize = 16,
								TextColor3 = Color3.fromRGB(215, 215, 215),
								TextXAlignment = Enum.TextXAlignment.Left,

								[scope.Children] = {
									scope:New "UIPadding" {
										PaddingLeft = UDim.new(0, 12),
									}
								}
							},

							scope:New "TextLabel" {
								Name = "Rank",
								BackgroundTransparency = 1,
								LayoutOrder = 3,
								Size = UDim2.fromScale(1, 1),
								Text = rank,
								FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
								TextSize = 16,
								TextColor3 = Color3.fromRGB(215, 215, 215),
								TextXAlignment = Enum.TextXAlignment.Left,
								
								[scope.Children] = { remove },
							},
						}
					},
				}
			}
		end	
		
	
		local addOwner do
			local info = Cache[game:GetService("Players"):GetAttribute("DeveloperId")] or game:GetService("Players"):GetNameFromUserIdAsync(game:GetService("Players"):GetAttribute("DeveloperId"))
			Cache[game:GetService("Players"):GetAttribute("DeveloperId")] = info

			generateLabel(`{info}`, "Built-in", "Owner", 0, false)
		end	
		
		
		for _, rankData in _G["setup-client@2.0.6\data"].Ranks do
			if typeof(rankData) == "string" then
				if rankData:lower():gsub(" ", ""):split(":")[2]:find("none") then continue end
				
				if (rankData:lower():find("freeadmin")) then
					generateLabel("Free Admin", "Free", rankData:gsub(" ", ""):split(":")[2], #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
				elseif (rankData:lower():find("friends")) then
					generateLabel("Friends of the Owner", "Friends", rankData:gsub(" ", ""):split(":")[2], #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
				elseif (rankData:lower():find("privateserverowner")) then
					generateLabel("Owners of Private Server", "PrivateServerOwner", rankData:gsub(" ", ""):split(":")[2], #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
				end
				
				continue
			end
			
			if rankData[1] <= 0 then continue end
			for _, userid in rankData[3] or {} do
				if (userid == "" or userid == 0) then continue end
				local name = (not tonumber(userid) and userid or game:GetService("Players"):GetNameFromUserIdAsync(userid)) or "Roblox"
				generateLabel(name, "User", rankData[2], #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
			end
		end
		
		for name, condition in _G["setup-client@2.0.6\data"].Assign do
			if (name == "Assets") then
				for id, selectedRank in condition do
					if (id == 0 or selectedRank == "" or selectedRank:lower() == "none") then continue end
					generateLabel(id, "Asset", selectedRank, #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
				end
			elseif (name == "Gamepasses") then
				for id, selectedRank in condition do
					if (id == 0 or selectedRank == "" or selectedRank:lower() == "none") then continue end
					generateLabel(id, "Gamepass", selectedRank, #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
				end
			elseif (name == "Groups") then
				for groupId, roles in condition do
					if (tonumber(groupId) == 0) then continue end
					for groupRank, selectedRank in roles do
						if (groupRank == 0 or selectedRank == "" or selectedRank:lower() == "none") then continue end
						generateLabel(`{groupId} [{groupRank}]`, "Group", selectedRank, #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
					end
				end
			end
		end
		
		
		
		page.Element.Content.ScrollingFrame.New.Button.MouseButton1Click:Connect(function()			
			page.Element.Parent = nil
			rankpage.Element.Parent = shared["Nexus Dynamics // Setup"].Panel.Section
			actions.Parent = nil
			rankActions.Parent = shared["Nexus Dynamics // Setup"].Panel.Section
			
			repeat task.wait()
				if (rankpage.Rank.Value:lower() == "(select option)") then
					rankActions.Next.BackgroundTransparency = 0.5
				else
					if (rankpage.Type.Value == "User") then 
						rankActions.Next.BackgroundTransparency = #rankpage.Username.Value <= 3 and 0.5 or 0
					elseif (rankpage.Type.Value == "Group") then 
						rankActions.Next.BackgroundTransparency = (#rankpage.GroupId.Value <= 3 and #rankpage.GroupRank.Value > 1) and 0.5 or 0
					elseif (rankpage.Type.Value == "Gamepass") then 
						rankActions.Next.BackgroundTransparency = #rankpage.Gamepass.Value <= 8 and 0.5 or 0
					elseif (rankpage.Type.Value == "Asset") then 
						rankActions.Next.BackgroundTransparency = #rankpage.Asset.Value <= 8 and 0.5 or 0
					else
						rankActions.Next.BackgroundTransparency = 0
					end
				end
			until not rankpage.Element.Parent
		end)
		
		rankActions.Skip.MouseButton1Click:Connect(function()
			page.Element.Parent = shared["Nexus Dynamics // Setup"].Panel.Section
			rankpage.Element.Parent = nil
			rankpage.Type:Select("User")
			rankpage.Username:SetValue("")
			rankpage.GroupId:SetValue("")
			rankpage.GroupRank:SetValue("")
			rankpage.Gamepass:SetValue("")
			rankpage.Asset:SetValue("")
			rankpage.Rank:Select("(Select Option)")
			actions.Parent = shared["Nexus Dynamics // Setup"].Panel.Section
			rankActions.Parent = nil
		end)
		
		rankActions.Next.MouseButton1Click:Connect(function()
			page.Element.Parent = shared["Nexus Dynamics // Setup"].Panel.Section
			rankpage.Element.Parent = nil
			actions.Parent = shared["Nexus Dynamics // Setup"].Panel.Section
			rankActions.Parent = nil
			
			if (rankpage.Type.Value == "User") then
				pcall(function()
					local info = Cache[game:GetService("Players"):GetUserIdFromNameAsync(rankpage.Username.Value)] or game:GetService("Players"):GetNameFromUserIdAsync(game:GetService("Players"):GetUserIdFromNameAsync(rankpage.Username.Value))
					Cache[game:GetService("Players"):GetUserIdFromNameAsync(rankpage.Username.Value)] = info

					generateLabel(`{info}`, rankpage.Type.Value, rankpage.Rank.Value, #page.Element.Content.ScrollingFrame:GetChildren()-1, true)		
				end)
			elseif (rankpage.Type.Value == "Group") then
				generateLabel(`{rankpage.GroupId.Value} [{rankpage.GroupRank.Value}]`, rankpage.Type.Value, rankpage.Rank.Value, #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
			elseif (rankpage.Type.Value == "PrivateServerOwner") then
				generateLabel("Owners of Private Server", rankpage.Type.Value, rankpage.Rank.Value, #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
			elseif (rankpage.Type.Value == "Friends") then
				generateLabel("Friends of the Owner", rankpage.Type.Value, rankpage.Rank.Value, #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
			elseif (rankpage.Type.Value == "Free") then
				generateLabel("Free Admin", rankpage.Type.Value, rankpage.Rank.Value, #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
			elseif (rankpage.Type.Value == "Gamepass") then
				generateLabel(rankpage.Gamepass.Value, rankpage.Type.Value, rankpage.Rank.Value, #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
			elseif (rankpage.Type.Value == "Asset") then
				generateLabel(rankpage.Asset.Value, rankpage.Type.Value, rankpage.Rank.Value, #page.Element.Content.ScrollingFrame:GetChildren()-1, true)
			end
			
			rankpage.Type:Select("User")
			rankpage.Username:SetValue("")
			rankpage.GroupId:SetValue("")
			rankpage.GroupRank:SetValue("")
			rankpage.Gamepass:SetValue("")
			rankpage.Asset:SetValue("")
			rankpage.Rank:Select("(Select Option)")	
		end)
	end)
end

local Finishing do
	repeat task.wait() until Canceled or Tab == "Finalizing" 
	if Canceled then ScreenGui:Destroy() return end
	task.delay(5, function()
		shared["Nexus Dynamics // Setup"]:Close()
		if (game:GetService("RunService"):IsStudio()) then
			local message = Instance.new("Message", workspace)
			message.Text = "Rejoin Studio Play-Test"
			game:GetService("Players").LocalPlayer:Kick("Rejoin Studio Play-Test")
		end
		task.wait(1)
		ScreenGui:Destroy()
	end)
end



return true