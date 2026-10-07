----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("notification-client@2.0.6").Connector)



----- || MAIN || -----
local ScreenGui = Instance.new("ScreenGui", script:FindFirstAncestorWhichIsA("Player").PlayerGui)
ScreenGui.Name = "nexus-dynamics-notifications@2.0"
ScreenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling	

Frame = Libraries.scope:New "Frame" {
	Parent = ScreenGui,
	Size = UDim2.fromScale(1 ,1),
	BackgroundTransparency = 1,
	
	[Libraries.scope.Children] = {
		
		Libraries.scope:New "UIListLayout" {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = _G["panel-client@2.0.6\config"] and (_G["panel-client@2.0.6\config"].NotificationPosition:lower():find("right") and Enum.HorizontalAlignment.Right or _G["panel-client@2.0.6\config"].NotificationPosition:lower():find("left") and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center) or Enum.HorizontalAlignment.Right,
			VerticalAlignment = _G["panel-client@2.0.6\config"] and (_G["panel-client@2.0.6\config"].NotificationPosition:lower():find("bottom") and Enum.VerticalAlignment.Bottom or _G["panel-client@2.0.6\config"].NotificationPosition:lower():find("top") and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Center) or Enum.VerticalAlignment.Bottom,
		},
		
		Libraries.scope:New "UIPadding" {
			PaddingBottom = UDim.new(0, 5),
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
			PaddingTop = UDim.new(0, 5),
		},
	}
}

Hint = Libraries.scope:New "TextLabel" {
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.75,
	Size = UDim2.new(1, 0, -0.025, 45),
	Parent = ScreenGui,
	Visible = false,
	
	FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
}

Message = Libraries.scope:New "Frame" {
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.5,
	Size = UDim2.fromScale(1, 1),
	Parent = ScreenGui,
	Visible = false,
	
	[Libraries.scope.Children] = {
		Libraries.scope:New "TextLabel" {
			Name = "From",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0.1),
			Size = UDim2.new(1, 0, 0, 50),
			
			FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 22,
			TextStrokeTransparency = 0.75,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		},
		
		Libraries.scope:New "TextLabel" {
			Name = "Message",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0.468),
			Size = UDim2.new(1, 0, 0, 50),
			
			FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 22,
			TextStrokeTransparency = 0.75,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}
	}
}


----- || METHODS || -----
function createPopup(hitbox)
	
	local self = {
		
		Template = nil,
		Popup = nil,
		Message = nil,
		Timer = nil,
		
		SetTimer = function( self: any, timer: number )
			self.__timer = timer or 20
			
			coroutine.wrap(function()
				while self.__timer > 0 do
					self.Timer.Text = tostring(self.__timer)
					self.__timer -= 1
					task.wait(1)
				end

				self:Hide()
				task.wait(0.25)
				self.Template:Destroy()
			end)()
			
			return self
		end,

		SetContent = function( self: any, text: string )
			self.Message.Text = text
			return self
		end,

		Show = function( self: any )
			self.Popup.Element:TweenPosition(UDim2.fromScale(0, 0), "Out", "Back", 0.25)
			return self
		end,

		Hide = function( self: any )
			self.Popup.Element:TweenPosition(UDim2.fromScale(1.5, 0), "Out", "Back", 0.25)
			return self
		end,
	}
	
	
	self.Template = hitbox and Libraries.scope:New "TextButton" {
		Parent = Frame,
		Size = UDim2.fromOffset(245, 100),
		BackgroundTransparency = 1,
		Text = ""
	} or Libraries.scope:New "Frame" {
		Parent = Frame,
		Size = UDim2.fromOffset(245, 100),
		BackgroundTransparency = 1,
	}

	self.Popup = Libraries.Windows "Popup" {
		Size = UDim2.fromOffset(245, 100),
		Parent = self.Template,
		Position = UDim2.fromScale(1.5, 0)
	}	
	
	self.Message = Libraries.scope:New "TextLabel" {
		Name = "Label",
		Parent = self.Popup.Element.MainFrame.Section.Content,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 1),
		FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		Text = "N/A",
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = Libraries.Color "--Primary-Text-Color",
		TextTransparency = 0,

		[Libraries.scope.Children] = {

			Libraries.scope:New "UIPadding" {
				PaddingTop = UDim.new(0, 15),
				PaddingRight = UDim.new(0, 15),
				PaddingLeft = UDim.new(0, 15),
				PaddingBottom = UDim.new(0, 15),
			},
		}
	}

	self.Timer = Libraries.scope:New "TextLabel" {
		Name = "Label",
		Parent = self.Popup.Element.MainFrame.Top.Left,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Size = UDim2.new(),
		FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		Text = "N/A",
		TextSize = 15,
		TextColor3 = Libraries.Color "--Primary-Text-Color",
		TextTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		
		[Libraries.scope.Children] = {

			Libraries.scope:New "UIPadding" {
				PaddingLeft = UDim.new(0, 10)
			},
			
			Libraries.scope:New "Frame" {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Libraries.Color "--Border",
				BackgroundTransparency = 0.75,
				Position = UDim2.new(1, 8, 0.5, 0),
				Size = UDim2.new(0, 1, 1, 0)
			}	
		}
	}
	
	Libraries.scope:New "ImageLabel" {
		Name = "Logo",
		Parent = self.Popup.Element.MainFrame.Top.Center,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(18, 18),
		Image = "rbxassetid://13636059383",
		ImageColor3 = Libraries.Color "--Primary-Text-Color",
	}
	
	--
	
	self.Popup.Close.Activated:Connect(function()
		self.__timer = 0
		self:Hide()
	end)
	
	--
	
	return self
end

function createFlyPopup(speed: number, collision: boolean?)
	
	local self = {
		Template = nil,
		Popup = nil,
		
		State = true,
		Collision = collision or false,
		Speed = speed or shared["Nexus Dynamics"].FlySpeed,
		
		
		Show = function( self: any )
			self.Popup.Element:TweenPosition(UDim2.fromScale(0, 0), "Out", "Back", 0.25)
			if (self.Disconnect) then self.Disconnect:Disconnect() end
			self.Disconnect = game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
				if (gameProcessed) then return end

				if (input.KeyCode == Enum.KeyCode.F) and (self.Template and self.Template.Parent) then
					self:SetState(not self.State)
					self.State = not self.State

					shared["Nexus Dynamics"].Signals["<command>"]:InvokeServer({
						request = true,

						player = game:GetService("Players").LocalPlayer,
						message = shared["Nexus Dynamics"].FlyCollision and (`{shared["Nexus Dynamics"].FlyState and "fly" or "unfly"} me {shared["Nexus Dynamics"].FlySpeed}`) or (`{shared["Nexus Dynamics"].FlyState and "noclip" or "clip"} me {shared["Nexus Dynamics"].FlySpeed}`)
					})
				end
			end)
			return self
		end,

		Hide = function( self: any )
			self.Popup.Element:TweenPosition(UDim2.fromScale(1.5, 0), "Out", "Back", 0.25)
			self.Disconnect:Disconnect()
			return self
		end,
		
		--
		
		SetSpeed = function( self: any, speed: number )
			self.SpeedInputBox.Frame.TextBox.Text = speed
			shared["Nexus Dynamics"].FlySpeed = speed
			return self
		end,
		
		SetState = function( self: any, state: boolean )
			shared["Nexus Dynamics"].FlyState = state
			
			if state then
				self.Buttons.State.TextLabel.Text = "Disable"
				self.Buttons.State.TextLabel.TextColor3 = Libraries.Color "--Button-Text-Color"
				self.Buttons.State.BackgroundColor3 = Libraries.Color "--Button-Background"
			else
				self.Buttons.State.TextLabel.Text = "Enable"
				self.Buttons.State.TextLabel.TextColor3 = Libraries.Color "--Accent-Text-Color"
				self.Buttons.State.BackgroundColor3 = Libraries.Color "--Accent"
			end
			return self
		end,
		
		SetCollision = function( self: any, collision: boolean )
			shared["Nexus Dynamics"].FlyCollision = collision
			
			if not collision then
				self.Buttons.Collision.TextLabel.TextColor3 = Libraries.Color "--Button-Text-Color"
				self.Buttons.Collision.BackgroundColor3 = Libraries.Color "--Button-Background"
			else
				self.Buttons.Collision.TextLabel.TextColor3 = Libraries.Color "--Accent-Text-Color"
				self.Buttons.Collision.BackgroundColor3 = Libraries.Color "--Accent"
			end
			return self
		end,
	}

	self.Template = Libraries.scope:New "Frame" {
		Parent = Frame,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(245, 0),
		BackgroundTransparency = 1,
	}

	self.Popup = Libraries.Windows "Popup" {
		Size = UDim2.fromOffset(245, 125),
		Parent = self.Template,
		Position = UDim2.fromScale(1.5, 0)
	}	

	Libraries.scope:New "ImageLabel" {
		Name = "Logo",
		Parent = self.Popup.Element.MainFrame.Top.Center,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(18, 18),
		Image = "rbxassetid://13636059383",
		ImageColor3 = Libraries.Color "--Primary-Text-Color",
	}
	
	Libraries.scope:New "UIListLayout" {
		Parent = self.Popup.Element:FindFirstChild("Section", true).Content,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}
	
	Libraries.scope:New "UIPadding" {
		Parent = self.Popup.Element:FindFirstChild("Section", true).Content,
		PaddingRight = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
	}
	
	--
	
	self.SpeedInputBox = Libraries.scope:New "TextButton" {
		Name = "InputBox",
		Parent = self.Popup.Element:FindFirstChild("Section", true).Content,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(15, 15, 19),
		Size = UDim2.new(1, 0, 0, 35),
		Text = "",
		
		[Libraries.scope.Children] = {
			Libraries.scope:New "UICorner" {
				CornerRadius = UDim.new(0, 8),
			},
			
			Libraries.scope:New "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(255, 255, 255),
				Transparency = 0.9,
			},
			
			Libraries.scope:New "Frame" {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				
				[Libraries.scope.Children] = {
					Libraries.scope:New "UIListLayout" {
						Padding = UDim.new(0, 10),
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					},
					
					Libraries.scope:New "UIPadding" {
						PaddingRight = UDim.new(0, 15),
						PaddingLeft = UDim.new(0, 15),
					},
				
					Libraries.scope:New "TextBox" {
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						LayoutOrder = 2,
						ClearTextOnFocus = false,
						Size = UDim2.fromScale(1, 0.65),
						
						FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						Text = "50",
						PlaceholderColor3 = Color3.fromRGB(255, 255, 255),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
					}
				},
			},
			
			Libraries.scope:New "TextLabel" {
				AnchorPoint = Vector2.new(0, 0.5),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Color3.fromRGB(15, 15, 19),
				LayoutOrder = 2,
				Position = UDim2.fromOffset(5, 0),
				Size = UDim2.fromOffset(0, 10),
				
				FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Text = "Fly Speed",
				TextWrapped = false,
				TextSize = 15,
				TextTransparency = 0.5,
				
				[Libraries.scope.Children] = {
					Libraries.scope:New "UIPadding" {
						PaddingRight = UDim.new(0, 6),
						PaddingLeft = UDim.new(0, 6),
					}
				}
			},
		}
	}
	
	self.Buttons = Libraries.scope:New "Frame" {
		Parent = self.Popup.Element:FindFirstChild("Section", true).Content,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		
		[Libraries.scope.Children] = {
			Libraries.scope:New "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				
				HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
			},
			
			Libraries.scope:New "TextButton" {
				Name = "State",
				Parent = self.Popup.Element:FindFirstChild("Section", true).Content,
				BackgroundColor3 = Color3.fromRGB(22, 22, 26),
				Position = UDim2.fromOffset(0, 12),
				Size = UDim2.new(0.447, 0, 0, 28),
				Text = "",

				[Libraries.scope.Children ] = {
					Libraries.scope:New "UICorner" {
						CornerRadius = UDim.new(0, 8)
					},

					Libraries.scope:New "UIStroke" {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.fromRGB(216, 216, 255),
						Transparency = 0.9,
					},

					Libraries.scope:New "TextLabel" {
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.9, 0.65),
						ZIndex = 4,

						TextColor3 = Color3.fromRGB(255, 255, 255),
						Text = "Disable",
						TextSize = 18,
						FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
						TextXAlignment = Enum.TextXAlignment.Center, 
						TextYAlignment = Enum.TextYAlignment.Center,
					}
				}
			},
			
			Libraries.scope:New "TextButton" {
				Name = "Collision",
				Parent = self.Popup.Element:FindFirstChild("Section", true).Content,
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(22, 22, 26),
				Position = UDim2.fromOffset(1, -12),
				Size = UDim2.new(0.447, 0, 0, 28),
				Text = "",

				[Libraries.scope.Children ] = {
					Libraries.scope:New "UICorner" {
						CornerRadius = UDim.new(0, 8)
					},

					Libraries.scope:New "UIStroke" {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.fromRGB(216, 216, 255),
						Transparency = 0.9,
					},

					Libraries.scope:New "TextLabel" {
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.9, 0.65),
						ZIndex = 4,

						TextColor3 = Color3.fromRGB(255, 255, 255),
						Text = "Collision",
						TextSize = 18,
						FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
						TextXAlignment = Enum.TextXAlignment.Center, 
						TextYAlignment = Enum.TextYAlignment.Center,
					}
				}
			}
		}
	}
	
	--	
	
	self.SpeedInputBox.Frame.TextBox.FocusLost:Connect(function(enter)
		if not enter then return end
		self.Speed = tonumber(self.SpeedInputBox.Frame.TextBox.Text) or tonumber(self.Speed) or 0
		self:SetSpeed(self.Speed)
		
		--
		
		shared["Nexus Dynamics"].Signals["<command>"]:InvokeServer({
			request = true,
			
			player = game:GetService("Players").LocalPlayer,
			message = shared["Nexus Dynamics"].FlyCollision and (`{shared["Nexus Dynamics"].FlyState and "fly" or "unfly"} me {shared["Nexus Dynamics"].FlySpeed}`) or (`{shared["Nexus Dynamics"].FlyState and "noclip" or "clip"} me {shared["Nexus Dynamics"].FlySpeed}`)
		})
	end)
	
	self.Buttons.State.Activated:Connect(function()
		self:SetState(not self.State)
		self.State = not self.State
		
		shared["Nexus Dynamics"].Signals["<command>"]:InvokeServer({
			request = true,
			
			player = game:GetService("Players").LocalPlayer,
			message = shared["Nexus Dynamics"].FlyCollision and (`{shared["Nexus Dynamics"].FlyState and "fly" or "unfly"} me {shared["Nexus Dynamics"].FlySpeed}`) or (`{shared["Nexus Dynamics"].FlyState and "noclip" or "clip"} me {shared["Nexus Dynamics"].FlySpeed}`)
		})
	end)
	
	self.Buttons.Collision.Activated:Connect(function()
		self.Collision = not self.Collision
		self:SetCollision(self.Collision)
		
		shared["Nexus Dynamics"].Signals["<command>"]:InvokeServer({
			request = true,

			player = game:GetService("Players").LocalPlayer,
			message = shared["Nexus Dynamics"].FlyCollision and (`{shared["Nexus Dynamics"].FlyState and "fly" or "unfly"} me {shared["Nexus Dynamics"].FlySpeed}`) or (`{shared["Nexus Dynamics"].FlyState and "noclip" or "clip"} me {shared["Nexus Dynamics"].FlySpeed}`)
		})
	end)
	
	self.Popup.Close.Activated:Connect(function()
		self:Hide()
	end)
	
	--
	
	self:SetSpeed(self.Speed)
	self:SetState(self.State)
	self:SetCollision(self.Collision)
	return self
end



----- || MAIN || -----
Libraries.Notification:Connect(function(data)
	local function WriteEffect(textlabel : TextLabel, text : string) text = tostring(text)
		local myCoroutine = coroutine.wrap(function()
			for i = 1, #text do
				textlabel.Text = text:sub(1, i)
				task.wait(0.01)
			end
		end)

		myCoroutine()

		return {
			Stop = function()
				coroutine.close(myCoroutine)
			end,
		}
	end
	
	if (data.type == "hint") then		
		Hint.Text = ""
		Hint.Visible = true

		WriteEffect(Hint, data.message)

		task.delay(data.timer or 20, function()
			if (Hint.Text ~= data.message) then return end
			Hint.Visible = false
		end) 
	end

	if (data.type == "message") then
		Message.From.Text = (data and data.speaker) and "Message from "..data.speaker.Name or ""
		Message.Visible = true

		WriteEffect(Message.Message, data and data.message or "")

		task.delay(data.timer or 20, function()
			if (Message.Message.Text ~= (data and data.message or "")) then return end
			Message.Visible = false
		end) 
	end
	
	if (data.type == "countdown") then
		local Popup = createPopup()
			:SetContent(data.message)
			:SetTimer(data.timer)
			:Show()

		repeat
			Popup:SetContent(Popup.Timer.Text)
			task.wait(1)
		until not (tonumber(Popup.Timer.Text)) or tonumber(Popup.Timer.Text) < 1
	end
	
	if (_G["panel-client@2.0.6\config"] and not _G["panel-client@2.0.6\config"].NotificationsEnabled) then return end
	
	if (data.type == "prompt") then
		local Popup = Libraries.Windows "Prompt" { Parent = ScreenGui }
			:Title(data.title or "")
			:Description(data.description or "")
			:Alt(data.alt or "")

		if (data.buttonA) then Popup:ButtonA(data.buttonA or "") end
		if (data.buttonB) then Popup:ButtonB(data.buttonB or "") end		
	end
	
	if (data.type == "notification" or data.type == "commands") then
		if (not data.typeOf) or data.type == "notification" then
			local Popup = createPopup()
				:SetContent(data.message)
				:SetTimer(data.timer)
				:Show()
		else
			local Popup = createPopup(true)
				:SetContent(data.message)
				:SetTimer(data.timer)
				:Show()

			Popup.Template.MouseButton1Click:Connect(function()
				shared["Nexus Dynamics"].Ribbon:ChangeTab("Commands")
				shared["Nexus Dynamics"].Menu:Close()
				shared["Nexus Dynamics // Topbar"]:Hide()
				shared["Nexus Dynamics"]:Open()

				Popup:Hide()
			end)
		end
	end
	
	if (data.type == "flying" or data.type == "noclipping") then
		local Popup = shared["Nexus Dynamics // Notification"].Cache["Fly"] or createFlyPopup(data.speed, data.collision)
		shared["Nexus Dynamics // Notification"].Cache["Fly"] = Popup

		Popup.Speed = data.speed	or shared["Nexus Dynamics"].FlySpeed or 100
		Popup.Collision = data.collision or shared["Nexus Dynamics"].FlyCollision or false
		Popup.State = data.state or shared["Nexus Dynamics"].FlyState

		Popup
			:Show()
			:SetSpeed(Popup.Speed)
			:SetCollision(Popup.Collision)
			:SetState(Popup.State)	
	end		
end)


return {}