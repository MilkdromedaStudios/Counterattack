----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || MAIN || -----
return function( panel: any )
	
	local Frame = Libraries.scope:New "TextButton" {
		Parent = panel.Element,
		Active = true,
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
	local function createPopup( skybox: any )

		local self = {

			Popup = nil,
			Skybox = skybox,
			
			Dragging = false,

			Last = 0,
			CurrentX = 0, DeltaX = 0,
			CurrentY = 0, DeltaY = 0,
			FOV = 0,
			
			Show = function( self: any )
				Frame.Visible = true
				self.Popup.Element.Visible = true
				shared["Nexus Dynamics"].Panel.Element.MainFrame.Section.Manager.Frame.Lighting.ScrollingFrame.Visible = false
				return self
			end,

			Hide = function( self: any )
				Frame.Visible = false
				self.Popup.Element.Visible = false
				shared["Nexus Dynamics"].Panel.Element.MainFrame.Section.Manager.Frame.Lighting.ScrollingFrame.Visible = true
				return self
			end,

			--

			Applied = Libraries.Maid.signal("Applied"),
			Canceled = Libraries.Maid.signal("Canceled"),
			Changed = Libraries.Maid.signal("Changed"),
		}

		self.Popup = Libraries.Windows "Popup" {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(707, 413),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = Frame,
		}

		self.Popup.Element.Shadow.Visible = false	
		self.Popup.Element.MainFrame.Section.BackgroundColor3 = Libraries.Color "--Background"
		self.Popup.Element.MainFrame.Section.BackgroundTransparency = 0.5

		--
		
		Libraries.scope:New "ImageButton" {
			Name = "Container",
			Active = true,
			Parent = self.Popup.Element.MainFrame.Section.Content,
			LayoutOrder = 1,
			BackgroundColor3 = Libraries.Color "--Ribbon-Background",
			Size = UDim2.new(1, 0, 0, 328),
			
			[Libraries.scope.Children] = {
				
				Libraries.scope:New "TextLabel" {
					Name = "FirstTime",
					Active = true,
					BackgroundColor3 = Libraries.Color "--Shadow",
					BackgroundTransparency = 0.25,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 100,
					
					FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					Text = "Drag to look around, scroll to zoom",
					TextSize = 28,
					TextColor3 = Libraries.Color "--Primary-Text-Color",
					TextTransparency = 0,
					TextXAlignment = Enum.TextXAlignment.Center,
				},
				
				Libraries.scope:New "ViewportFrame" {
					Name = "Viewport",
					Active = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					CurrentCamera = Libraries.scope:New "Camera" {
						CFrame = CFrame.new(Vector3.new(0, 0, 0)),
						FieldOfView = 70,
					},

					[Libraries.scope.Children] = {

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
											Texture = self.Skybox["SkyboxBk"] 
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
											Texture = self.Skybox["SkyboxDn"] 
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
											Texture = self.Skybox["SkyboxFt"] 
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
											Texture = self.Skybox["SkyboxLf"] 
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
											Texture = self.Skybox["SkyboxRt"] 
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
											Texture = self.Skybox["SkyboxUp"] 
										},
									},
								},
							}
						}
					},
				},

				Libraries.scope:New "Frame" {
					Name = "Details",
					Active = true,
					AnchorPoint = Vector2.new(0, 1),
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 0, 1),
					Size = UDim2.new(1, 0, 0, 36),

					[Libraries.scope.Children] = {
						
						Libraries.scope:New "ImageLabel" {
							Name = "Background",
							Active = true,
							AnchorPoint = Vector2.new(0, 1),
							BackgroundTransparency = 1,
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.fromScale(1, 2),
							ZIndex = -10,
							
							Image = "http://www.roblox.com/asset/?id=4678208715",
							ImageColor3 = Color3.new(0, 0, 0),
							ImageTransparency = 0.3,
						},
						
						Libraries.scope:New "ImageLabel" {
							Name = "Icon",
							Active = true,
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundTransparency = 1,
							Position = UDim2.new(0, 8, 0.5, 0),
							Size = UDim2.fromOffset(18, 18),

							Image = "rbxassetid://4689880286",
							ImageTransparency = 0.25,
						},

						Libraries.scope:New "TextLabel" {
							Name = "Label",
							Active = true,
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundTransparency = 1,
							Position = UDim2.new(0, 28, 0.5, 0),
							Size = UDim2.new(1, -250, 0, 16),
							
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							Text = self.Skybox.Name,
							TextSize = 15,
							TextColor3 = Libraries.Color "--Primary-Text-Color",
							TextTransparency = 0,
							TextXAlignment = Enum.TextXAlignment.Left,
						},
					}
				}
			}
		}
		
		Libraries.scope:New "TextButton" {
			Name = "Apply",
			Active = true,
			Parent = self.Popup.Element.MainFrame.Section.Content,
			LayoutOrder = 2,
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
			self.Applied:Fire( self.Skybox)
			self:Hide()
			self.Popup.Element:Destroy()
		end)
		
		--
		
		self.Popup.Element.MainFrame.Section.Content.Container.MouseButton1Down:Once(function() 
			Libraries.Maid.tween {
				[self.Popup.Element.MainFrame.Section.Content.Container.FirstTime] = {
					TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						BackgroundTransparency = 1,
						TextTransparency = 1,
					}
				},
			}	
			
			task.delay(0.25, function() if self.Popup.Element.MainFrame.Section.Content.Container.FirstTime then self.Popup.Element.MainFrame.Section.Content.Container.FirstTime:Destroy() end end)
		end)
		
		self.Popup.Element.MainFrame.Section.Content.Container.MouseButton1Down:Connect(function(x, y) self.Dragging = true; self.CurrentX = x; self.CurrentY = y end)	
		game:GetService("UserInputService").InputEnded:Connect(function(input) if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end self.Dragging = false end)
		
		self.Popup.Element.MainFrame.Section.Content.Container.Viewport.MouseMoved:Connect(function(x, y)
			if not self.Dragging then return end
			local Camera = self.Popup.Element.MainFrame.Section.Content.Container.Viewport.CurrentCamera
			
			Camera.CFrame *= CFrame.fromEulerAnglesXYZ((y - self.CurrentY) * 0.005, 0, 0)
			Camera.CFrame = CFrame.Angles(0, (x - self.CurrentX) * 0.005, 0) * ( Camera.CFrame - Camera.CFrame.Position ) + Camera.CFrame.Position

			self.CurrentX, self.DeltaX = x, (x - self.CurrentX) * 0.005
			self.CurrentY, self.DeltaY = y, (y - self.CurrentY) * 0.005
		end)
		
		self.Popup.Element.MainFrame.Section.Content.Container.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
			self.FOV = -input.Position.Z
		end)
		
		local connection; connection = game:GetService("RunService").RenderStepped:Connect(function()
			if not self.Popup or not self.Popup.Element or not self.Popup.Element:FindFirstChild("MainFrame") then return connection:Disconnect() end
			local Camera = self.Popup.Element.MainFrame.Section.Content.Container.Viewport.CurrentCamera
			if not Camera then return end
			
			Camera.CFrame *= CFrame.fromEulerAnglesXYZ(self.DeltaY, 0, 0)
			Camera.CFrame = CFrame.Angles(0, self.DeltaX, 0) * ( Camera.CFrame - Camera.CFrame.Position ) + Camera.CFrame.Position

			self.DeltaX *= 0.95
			self.DeltaY *= 0.95

			Camera.FieldOfView = math.clamp(Camera.FieldOfView + self.FOV, 30, 120)
			self.FOV *= 0.9
		end)
		--
		
		self.Changed:Fire()
		return self
	end
	
	return {
	
		New = function( self: any, skybox: any )
			
			local popup = createPopup(skybox)
				:Show()
			
			return {
								
				Applied = function( self: any, func: ( skybox: any ) -> RBXScriptSignal  ) 
					return popup.Applied:Once(func)
				end,
				
				Canceled = function( self: any, func: () -> RBXScriptSignal  ) 
					return popup.Canceled:Once(func)
				end,
			}		
		end,
	}
end