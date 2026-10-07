----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)



----- || MAIN || -----
dictionary = {
	
	["Appearance"] = {
		["Ambient"] = Libraries.Common "WriteOnly" { LayoutOrder = 1 }
			:Title("AMBIENT")
			:Description("The hue of the global lighting.")
			:Values {

				Libraries.Interactions "ColorPicker" {}
				:SetValue(game:GetService("Lighting").Ambient)
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						self:SetValue(color)
					end)			
				end)

				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Lighting",

							Property = "Ambient",

							Values = {
								{game:GetService("Lighting").Ambient, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("Lighting"), "Ambient", self.Value)
					end)
				end)
			},


		["Brightness"] = Libraries.Common "WriteOnly" { LayoutOrder = 2 }
			:Title("BRIGHTNESS")
			:Description("How much global light each part in workspace rececives.")
			:Values {

				Libraries.Interactions "TextBox" {}
				:Placeholder("0")
				:SetValue(game:GetService("Lighting").Brightness)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Lighting",

							Property = "Brightness",

							Values = {
								{game:GetService("Lighting").Brightness, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("Lighting"), "Brightness", self.Value)
					end)
				end)
			},


		["ColorShiftTop"] = Libraries.Common "WriteOnly" { LayoutOrder = 3 }
			:Title("COLORSHIFT TOP")
			:Description("The hue of objects on its top surface.")
			:Values {

				Libraries.Interactions "ColorPicker" {}
				:SetValue(game:GetService("Lighting").ColorShift_Top)
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						self:SetValue(color)
					end)			
				end)

				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Lighting",

							Property = "ColorShift_Top",

							Values = {
								{game:GetService("Lighting").ColorShift_Top, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("Lighting"), "ColorShift_Top", self.Value)
					end)
				end)
			},


		["ColorShiftBottom"] = Libraries.Common "WriteOnly" { LayoutOrder = 4 }
			:Title("COLORSHIFT BOTTOM")
			:Description("The hue of objects on its bottom surface.")
			:Values {

				Libraries.Interactions "ColorPicker" {}
				:SetValue(game:GetService("Lighting").ColorShift_Bottom)
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						self:SetValue(color)
					end)			
				end)

				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Lighting",

							Property = "ColorShift_Bottom",

							Values = {
								{game:GetService("Lighting").ColorShift_Bottom, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("Lighting"), "ColorShift_Bottom", self.Value)
					end)
				end)
			},


		["DiffuseScale"] = Libraries.Common "WriteOnly" { LayoutOrder = 5 }
			:Title("DIFFUSE SCALE")
			:Description("Scale of 0-1 on how much diffuse factors lighting.")
			:Values {

				Libraries.Interactions "Slider" {}
				:SetValue(game:GetService("Lighting").EnvironmentDiffuseScale, 0, 1, 100)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Lighting",

							Property = "EnvironmentDiffuseScale",

							Values = {
								{game:GetService("Lighting").EnvironmentDiffuseScale, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("Lighting"), "EnvironmentDiffuseScale", self.Value)
					end)
				end)
			},


		["SpecularScale"] = Libraries.Common "WriteOnly" { LayoutOrder = 6 }
			:Title("SPECULAR SCALE")
			:Description("Scale of 0-1 on how much specular factors lightning.")
			:Values {

				Libraries.Interactions "Slider" {}
				:SetValue(game:GetService("Lighting").EnvironmentSpecularScale, 0, 1, 100)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Lighting",

							Property = "EnvironmentSpecularScale",

							Values = {
								{game:GetService("Lighting").EnvironmentSpecularScale, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("Lighting"), "EnvironmentSpecularScale", self.Value)
					end)
				end)
			},


		["GlobalShadows"] = Libraries.Common "WriteOnly" { LayoutOrder = 7 }
			:Title("GLOBAL SHADOWS")
			:Description("Toggles voxel-based dynamic lighting for the game.")
			:Values {

				Libraries.Interactions "Toggle" {}
				:Default(game:GetService("Lighting").GlobalShadows)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Lighting",

							Property = "GlobalShadows",

							Values = {
								{game:GetService("Lighting").GlobalShadows, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("Lighting"), "GlobalShadows", self.Value)
					end)
				end)
			},


		["OutdoorAmbient"] = Libraries.Common "WriteOnly" { LayoutOrder = 8 }
			:Title("OUTDOOR AMBIENT")
			:Description("The hue of open areas. (Requires Global Shadows)")
			:Values {

				Libraries.Interactions "ColorPicker" {}
				:SetValue(game:GetService("Lighting").OutdoorAmbient)
				:Pressed(function( self: any )
					local picker = shared["Nexus Dynamics"].Popups.ColorPicker:New()
					:SetColor(self.Value)
					:Applied(function( color: Color3 )
						self:SetValue(color)
					end)			
				end)

				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Lighting",

							Property = "OutdoorAmbient",

							Values = {
								{game:GetService("Lighting").OutdoorAmbient, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("Lighting"), "OutdoorAmbient", self.Value)
					end)
				end)
			},


		["ShadowSoftness"] = Libraries.Common "WriteOnly" { LayoutOrder = 9 }
			:Title("SHADOW SOFTNESS")
			:Description("Scale of 0-1 on how soft the edges of shadows are.")
			:Values {

				Libraries.Interactions "Slider" {}
				:SetValue(game:GetService("Lighting").ShadowSoftness, 0, 1, 100)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Lighting",

							Property = "ShadowSoftness",

							Values = {
								{game:GetService("Lighting").ShadowSoftness, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("Lighting"), "ShadowSoftness", self.Value)
					end)
				end)
			},
	},
	
	["Behavior"] = {
		["ClockTime"] = Libraries.Common "WriteOnly" { LayoutOrder = 10 }
			:Title("CLOCK TIME")
			:Description("The time of the world.")
			:Values {

				Libraries.Interactions "Slider" {}
				:SetValue(game:GetService("Lighting").ClockTime, 0, 24, 10)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Lighting",

							Property = "ClockTime",

							Values = {
								{game:GetService("Lighting").ClockTime, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("Lighting"), "ClockTime", self.Value)
					end)
				end)
			},


		["GeographicLatitude"] = Libraries.Common "WriteOnly" { LayoutOrder = 11 }
			:Title("GEOGRAPHIC LATITUDE")
			:Description("The latitude position of the sun.")
			:Values {

				Libraries.Interactions "Slider" {}
				:SetValue(game:GetService("Lighting").GeographicLatitude, 0, 360, 1)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Lighting",

							Property = "GeographicLatitude",

							Values = {
								{game:GetService("Lighting").GeographicLatitude, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("Lighting"), "GeographicLatitude", self.Value)
					end)
				end)
			},


		["ExposureCompensation"] = Libraries.Common "WriteOnly" { LayoutOrder = 12 }
			:Title("EXPOSURE COMPENSATION")
			:Description("Apply bias level to tonemap brightness.")
			:Values {

				Libraries.Interactions "Slider" {}
				:SetValue(game:GetService("Lighting").ExposureCompensation, -3, 3, 100)
				:Connection(function( self: any )
					self.Changed:Connect(function(property)
						if property ~= "Value" then return end
						
						--
						
						Libraries.Logs:New "Manager" {
							Type = "Update",
							Origin = "Lighting",

							Property = "ExposureCompensation",

							Values = {
								{game:GetService("Lighting").ExposureCompensation, self.Value}
							}
						}
						
						--
						
						script.Callback:InvokeServer(game:GetService("Lighting"), "ExposureCompensation", self.Value)
					end)
				end)
			},		
	},
	
	["Skybox"] = {},
}



local Skyboxes = require(script.Skyboxes)

local c=1; for name, properties in Skyboxes do c+=1
	properties.Name = name
	
	dictionary.Skybox[name] = Libraries.scope:New "Frame" {
		Name = "Skybox",
		LayoutOrder = c,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 100),
		
		[Libraries.scope.Children] = {
			
			Libraries.scope:New "UIPadding" {
				PaddingTop = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 30),
				PaddingRight = UDim.new(0, 35),
			},
			
			Libraries.scope:New "ImageButton" {
				Name = "Hitbox",
				BackgroundColor3 = Libraries.Color "--Skybox-Index-Background",
				Size = UDim2.fromScale(1, 1),
				ScaleType = Enum.ScaleType.Stretch,
				
				[Libraries.scope.OnEvent "Activated"] = function()
					shared["Nexus Dynamics"].Popups.Skybox:New(properties)
						:Applied(function( skyboxProperties: any )
							script.Callback:InvokeServer(game:GetService("Lighting"), "Skybox", skyboxProperties)

							Libraries.Logs:New "Manager" {
								Type = "Update",
								Origin = "Lighting",

								Property = "Skybox",

								Values = {
									{skyboxProperties.Name}
								}
							}
						end)
				end,
				
				[Libraries.scope.OnEvent "MouseEnter"] = function()
					Libraries.Maid.tween {
						[dictionary.Skybox[name].Hitbox.Viewport.CurrentCamera] = {
							TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								FieldOfView = 60
							}
						},
					}
				end,
				
				[Libraries.scope.OnEvent "MouseLeave"] = function()
					Libraries.Maid.tween {
						[dictionary.Skybox[name].Hitbox.Viewport.CurrentCamera] = {
							TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
								FieldOfView = 70
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
						Color = Color3.fromRGB(216, 216, 255),
						Thickness = 1,
						Transparency = 0.9,
					},

					Libraries.scope:New "ViewportFrame" {
						Name = "Viewport",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
						CurrentCamera = Libraries.scope:New "Camera" {
							CFrame = CFrame.new(Vector3.new(0, 0, 0)),
							FieldOfView = 70,
						},
						
						[Libraries.scope.Children] = {
							
							Libraries.scope:New "UICorner" {
								CornerRadius = UDim.new(0, 8)
							},

							Libraries.scope:New "Model" {

								[Libraries.scope.Children] = {

									Libraries.scope:New "Part" {
										Name = "Bk",
										Transparency = 1,
										Size = Vector3.one,
										Position = Vector3.zero,
										Orientation = Vector3.new(0, 180, 0),

										[Libraries.scope.Children] = {

											Libraries.scope:New "SpecialMesh" {
												MeshId = "rbxassetid://3083991485",
												MeshType = Enum.MeshType.FileMesh,
												Offset = Vector3.new(0, 0, -0.683),
												Scale = Vector3.one,
												VertexColor = Vector3.one,
											},

											Libraries.scope:New "Decal" {
												Texture = properties["SkyboxBk"] 
											},
										},
									},

									Libraries.scope:New "Part" {
										Name = "Dn",
										Transparency = 1,
										Size = Vector3.one,
										Position = Vector3.zero,
										Orientation = Vector3.new(-90, 90, 0),

										[Libraries.scope.Children] = {

											Libraries.scope:New "SpecialMesh" {
												MeshId = "rbxassetid://3083991485",
												MeshType = Enum.MeshType.FileMesh,
												Offset = Vector3.new(0, 0, -0.683),
												Scale = Vector3.one,
												VertexColor = Vector3.one,
											},

											Libraries.scope:New "Decal" {
												Texture = properties["SkyboxDn"] 
											},
										},
									},

									Libraries.scope:New "Part" {
										Name = "Ft",
										Transparency = 1,
										Size = Vector3.one,
										Position = Vector3.zero,
										Orientation = Vector3.new(0, 0, 0),

										[Libraries.scope.Children] = {

											Libraries.scope:New "SpecialMesh" {
												MeshId = "rbxassetid://3083991485",
												MeshType = Enum.MeshType.FileMesh,
												Offset = Vector3.new(0, 0, -0.683),
												Scale = Vector3.one,
												VertexColor = Vector3.one,
											},

											Libraries.scope:New "Decal" {
												Texture = properties["SkyboxFt"] 
											},
										},
									},

									Libraries.scope:New "Part" {
										Name = "Lf",
										Transparency = 1,
										Size = Vector3.one,
										Position = Vector3.zero,
										Orientation = Vector3.new(0, -90, 0),

										[Libraries.scope.Children] = {

											Libraries.scope:New "SpecialMesh" {
												MeshId = "rbxassetid://3083991485",
												MeshType = Enum.MeshType.FileMesh,
												Offset = Vector3.new(0, 0, -0.683),
												Scale = Vector3.one,
												VertexColor = Vector3.one,
											},

											Libraries.scope:New "Decal" {
												Texture = properties["SkyboxLf"] 
											},
										},
									},

									Libraries.scope:New "Part" {
										Name = "Rt",
										Transparency = 1,
										Size = Vector3.one,
										Position = Vector3.zero,
										Orientation = Vector3.new(0, 90, 0),

										[Libraries.scope.Children] = {

											Libraries.scope:New "SpecialMesh" {
												MeshId = "rbxassetid://3083991485",
												MeshType = Enum.MeshType.FileMesh,
												Offset = Vector3.new(0, 0, -0.683),
												Scale = Vector3.one,
												VertexColor = Vector3.one,
											},

											Libraries.scope:New "Decal" {
												Texture = properties["SkyboxRt"] 
											},
										},
									},

									Libraries.scope:New "Part" {
										Name = "Up",
										Transparency = 1,
										Size = Vector3.one,
										Position = Vector3.zero,
										Orientation = Vector3.new(90, 90, 0),

										[Libraries.scope.Children] = {

											Libraries.scope:New "SpecialMesh" {
												MeshId = "rbxassetid://3083991485",
												MeshType = Enum.MeshType.FileMesh,
												Offset = Vector3.new(0, 0, -0.683),
												Scale = Vector3.one,
												VertexColor = Vector3.one,
											},

											Libraries.scope:New "Decal" {
												Texture = properties["SkyboxUp"] 
											},
										},
									},
								}
							}
						},
					},

					Libraries.scope:New "CanvasGroup" {
						Name = "Details",
						AnchorPoint = Vector2.new(0, 1),
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 0, 1, 1),
						Size = UDim2.new(1, 0, 0, 36),

						[Libraries.scope.Children] = {

							Libraries.scope:New "UICorner" {
								CornerRadius = UDim.new(0, 8),
							},

							Libraries.scope:New "Frame" {
								AnchorPoint = Vector2.new(0, 1),
								BackgroundColor3 = Libraries.Color "--Skybox-Index-Background",
								BackgroundTransparency = 0.3,
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.new(1, 0, 0, 30),

								[Libraries.scope.Children] = {

									Libraries.scope:New "UIPadding" {
										PaddingLeft = UDim.new(0, 15),
										PaddingRight = UDim.new(0, 10),
									},

									Libraries.scope:New "ImageLabel" {
										Name = "Icon",
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundTransparency = 1,
										Position = UDim2.fromScale(1, 0.5),
										Size = UDim2.fromOffset(18, 18),

										Image = "rbxassetid://4689880286",
									},

									Libraries.scope:New "TextLabel" {
										Name = "Label",
										AnchorPoint = Vector2.new(0, 0.5),
										AutomaticSize = Enum.AutomaticSize.X,
										BackgroundTransparency = 1,
										Position = UDim2.fromScale(0, 0.5),
										Size = UDim2.fromScale(0, 1),
										FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
										Text = name,
										TextSize = 15,
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextTransparency = 0,
									},
								}
							}
						}
					}
				}
			}
		},
	}
end

return dictionary