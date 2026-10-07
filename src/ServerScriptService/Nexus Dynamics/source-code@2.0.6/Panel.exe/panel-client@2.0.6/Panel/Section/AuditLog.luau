----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || MAIN || -----
return function( panel: any )
	
	local Page = Libraries.Windows "Page" {
		Parent = panel.Section,
		Size = UDim2.fromScale(1, 1),
		Name = "AuditLog",
	}
	
	local ScrollFrame = Libraries.Windows "ScrollFrame" {
		Parent = Page.Element,
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 1),
	}	
	
	Libraries.scope:New "TextLabel" {
		Name = "None",
		Parent = ScrollFrame.Element,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Position = UDim2.new(0.075, 13, 0.225, 0),
		Size = UDim2.fromScale(1, 0),


		Text = "None",
		FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		RichText = true,
		TextSize = 17,
		TextColor3 = Libraries.Color "--Description-Text-Color",
		TextXAlignment = Enum.TextXAlignment.Center,
	}
	
	local UIPadding = Instance.new("UIPadding", Page.Element)
	UIPadding.PaddingTop = UDim.new(0, 25)
	ScrollFrame.Element.UIListLayout.Padding = UDim.new(0, 12)
		
	--
	
	local conversion = {
		["update"] = "updated",
	}
	
	--
	
	Libraries.Logs.MessageOut:Connect(function( logData )
		
		if logData.Index == "Manager" then		
			if logData.Property == "Skybox" then
				local format = {
					Label = `<font transparency="0">{logData.Sender.Name}</font> {conversion[logData.Type:lower()] or logData.Type:lower()} Skybox to <font transparency="0" color="#fa0"><i>{logData.Values[1][1]}</i></font> in <font transparency="0">{logData.Index}</font>`,
					Timestamp = `{os.date("*t", logData.Timestamp).day == os.date("*t").day and `Today at {Libraries.Util.ConvertToLocalTime(logData.Timestamp, 12)}` or os.date("*t", logData.Timestamp).day == os.date("*t").day-1 and `Yesterday at {Libraries.Util.ConvertToLocalTime(logData.Timestamp, 12)}` or `{os.date("*t", logData.Timestamp).year}/{os.date("*t", logData.Timestamp).month}/{os.date("*t", logData.Timestamp).day} at {Libraries.Util.ConvertToLocalTime(logData.Timestamp, 12)}` }`,
				}


				local Template; Template = Libraries.scope:New "Frame" {
					Parent = ScrollFrame.Element,
					LayoutOrder = 9999999 - #ScrollFrame.Element:GetChildren(),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 65),

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingTop = UDim.new(0, 2),
							PaddingLeft = UDim.new(0, 35),
							PaddingRight = UDim.new(0, 35),
						},

						Libraries.scope:New "TextButton" {
							Name = "Hitbox",
							AutomaticSize = Enum.AutomaticSize.Y,
							AutoButtonColor = true,
							BackgroundColor3 = Libraries.Color "--TextBox-Background",
							Size = UDim2.fromScale(1, 1),

							[Libraries.scope.OnEvent "Activated"] = function( inputObject: InputObject, clickCount: number )
								Template.Hitbox.Details.Visible = not Template.Hitbox.Details.Visible
								Template.Hitbox.Chevron.Rotation = Template.Hitbox.Details.Visible and 90 or 0 
							end,

							[Libraries.scope.Children] = {

								Libraries.scope:New "UICorner" {
									CornerRadius = UDim.new(0, 5),
								},

								Libraries.scope:New "UIPadding" {
									PaddingLeft = UDim.new(0, 25),
									PaddingRight = UDim.new(0, 15),
								},

								Libraries.scope:New "UIStroke" {
									ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
									Color = Libraries.Color "--TextBox-Border",
								},

								--

								Libraries.Common "UserThumbnail" {
									Size = UDim2.fromOffset(40, 40),
									AnchorPoint = Vector2.new(0, 0.5),
									Position = UDim2.fromScale(0, 0.5),
								}:SetUserId(logData.Sender.Id).Element,

								--

								Libraries.scope:New "Frame" {
									Name = "Divider",
									AnchorPoint = Vector2.new(0, 0.5),
									BackgroundColor3 = Libraries.Color "--Border",
									Position = UDim2.fromScale(0.075, 0.5),
									Size = UDim2.fromOffset(1, 40),
								},

								Libraries.scope:New "TextLabel" {
									Name = "Label",
									AutomaticSize = Enum.AutomaticSize.XY,
									BackgroundTransparency = 1,
									LayoutOrder = 1,
									Position = UDim2.new(0.075, 13, 0.225, 0),
									Size = UDim2.new(),

									Text = format.Label,
									FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
									RichText = true,
									TextSize = 17,
									TextColor3 = Libraries.Color "--Description-Text-Color",
									TextXAlignment = Enum.TextXAlignment.Left,
								},

								Libraries.scope:New "TextLabel" {
									Name = "Timestamp",
									AutomaticSize = Enum.AutomaticSize.XY,
									BackgroundTransparency = 1,
									LayoutOrder = 1,
									Position = UDim2.new(0.075, 13, 0.525, 0),
									Size = UDim2.new(),

									Text = format.Timestamp,
									FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
									RichText = true,
									TextSize = 15,
									TextColor3 = Libraries.Color "--Description-Text-Color",
									TextXAlignment = Enum.TextXAlignment.Left,
								},

								Libraries.scope:New "Frame" {
									Name = "Details",
									AutomaticSize = Enum.AutomaticSize.Y,
									BackgroundTransparency = 1,
									Position = UDim2.fromScale(0, 1),
									Size = UDim2.fromScale(1, 0),
									Visible = false,

									[Libraries.scope.Children] = {

										Libraries.scope:New "UIListLayout" {
											SortOrder = Enum.SortOrder.LayoutOrder,
										},
									}
								},

								Libraries.scope:New "ImageLabel" {
									Name = "Chevron",
									AnchorPoint = Vector2.new(1, 0.5),
									BackgroundTransparency = 1,
									Position = UDim2.fromScale(1, 0.5),
									Size = UDim2.fromOffset(25, 25),
									Image = "rbxassetid://77623958555585",
									ImageColor3 = color "--Description-Text-Color",
									Visible = false,
								}
							}
						}
					}
				}

				--

				Libraries.scope:New "ImageLabel" {
					Name = "Icon",
					Parent = Template.Hitbox.Thumbnail,
					AnchorPoint = Vector2.new(1, 1),
					BackgroundColor3 = color "--TextBox-Background",
					Position = UDim2.fromScale(1.1, 1.1),
					Size = UDim2.fromOffset(20, 20),

					Image = "rbxassetid://115685602002775",


					[Libraries.scope.Children] = {

						Libraries.scope:New "UICorner" {
							CornerRadius = UDim.new(1, 0),
						}
					}
				}
				
				if (ScrollFrame.Element:FindFirstChild("None")) then ScrollFrame.Element:FindFirstChild("None"):Destroy() end	
			else
				local format = {
					Label = `<font transparency="0">{logData.Sender.Name}</font> {conversion[logData.Type:lower()] or logData.Type:lower()} {logData.Origin:lower()} in <font transparency="0">{logData.Index}</font>`,
					Timestamp = `{os.date("*t", logData.Timestamp).day == os.date("*t").day and `Today at {Libraries.Util.ConvertToLocalTime(logData.Timestamp, 12)}` or os.date("*t", logData.Timestamp).day == os.date("*t").day-1 and `Yesterday at {Libraries.Util.ConvertToLocalTime(logData.Timestamp, 12)}` or `{os.date("*t", logData.Timestamp).year}/{os.date("*t", logData.Timestamp).month}/{os.date("*t", logData.Timestamp).day} at {Libraries.Util.ConvertToLocalTime(logData.Timestamp, 12)}` }`,

					Details = {}
				}

				for x, values in logData.Values do

					if typeof(values[1]) == "Color3" then

						if shared["Nexus Dynamics"].Config.ColorWheelOutput:lower() == "rgb" then
							format.Details[x] = `{logData.Type} {logData.Origin:lower()} <font transparency="0">{logData.Property}</font> from <font transparency="0" color="#{values[1]:ToHex()}"><i>{math.floor(values[1].R)}, {math.floor(values[1].G)}, {math.floor(values[1].B)}</i></font> <font size="22" transparency="0.3">→</font> <font transparency="0" color="#{values[2]:ToHex()}"><i>{math.floor(values[2].R)}, {math.floor(values[2].G)}, {math.floor(values[2].B)}</i></font>`
						elseif shared["Nexus Dynamics"].Config.ColorWheelOutput:lower() == "hsv" then
							local H1, S1, V1 = values[1]:ToHSV()
							local H2, S2, V2 = values[2]:ToHSV()
							format.Details[x] = `{logData.Type} {logData.Origin:lower()} <font transparency="0">{logData.Property}</font> from <font transparency="0" color="#{values[1]:ToHex()}"><i>{math.floor(H1*359)}, {math.floor(S1*255)}, {math.floor(V1*255)}</i></font> <font size="22" transparency="0.3">→</font> <font transparency="0" color="#{values[2]:ToHex()}"><i>{math.floor(H2*359)}, {math.floor(S2*255)}, {math.floor(V2*255)}</i></font>`
						elseif shared["Nexus Dynamics"].Config.ColorWheelOutput:lower() == "new" then
							format.Details[x] = `{logData.Type} {logData.Origin:lower()} <font transparency="0">{logData.Property}</font> from <font transparency="0" color="#{values[1]:ToHex()}"><i>{math.floor(values[1].R*100)/100}, {math.floor(values[1].G*100)/100}, {math.floor(values[1].B*100)/100}</i></font> <font size="22" transparency="0.3">→</font> <font transparency="0" color="#{values[2]:ToHex()}"><i>{math.floor(values[2].R*100)/100}, {math.floor(values[2].G*100)/100}, {math.floor(values[2].B*100)/100}</i></font>`
						elseif shared["Nexus Dynamics"].Config.ColorWheelOutput:lower() == "hex" then
							format.Details[x] = `{logData.Type} {logData.Origin:lower()} <font transparency="0">{logData.Property}</font> from <font transparency="0" color="#{values[1]:ToHex()}"><i>#{values[1]:ToHex()}</i></font> <font size="22" transparency="0.3">→</font> <font transparency="0" color="#{values[2]:ToHex()}"><i>#{values[2]:ToHex()}</i></font>`
						else
							format.Details[x] = `{logData.Type} {logData.Origin:lower()} <font transparency="0">{logData.Property}</font> from <font transparency="0" color="#{BrickColor.new(values[1]).Color:ToHex()}"><i>{BrickColor.new(values[1]).Name}</i></font> <font size="22" transparency="0.3">→</font> <font transparency="0" color="#{BrickColor.new(values[2]).Color:ToHex()}"><i>{BrickColor.new(values[2]).Name}</i></font>`
						end

						continue
					end

					--

					if typeof(values[1]) == "EnumItem" then
						format.Details[x] = `{logData.Type} {logData.Origin:lower()} <font transparency="0">{logData.Property}</font> from <font transparency="0" color="#fa0"><i>{values[1].Name}</i></font> <font size="22" transparency="0.3">→</font> <font transparency="0" color="#fa0"><i>{values[2].Name}</i></font>`
						continue
					end

					--

					if typeof(values[1]) == "boolean" then
						format.Details[x] = `{logData.Type} {logData.Origin:lower()} <font transparency="0">{logData.Property}</font> from <font transparency="0" color="#fa0"><i>{values[1] and "TRUE" or "FALSE"}</i></font> <font size="22" transparency="0.3">→</font> <font transparency="0" color="#fa0"><i>{values[2] and "TRUE" or "FALSE"}</i></font>`
						continue
					end

					--

					if tonumber(values[1]) and tonumber(values[2]) then
						format.Details[x] = `{logData.Type} {logData.Origin:lower()} <font transparency="0">{logData.Property}</font> from <font transparency="0" color="#fa0"><i>{math.floor(tonumber(values[1])*100)/100}</i></font> <font size="22" transparency="0.3">→</font> <font transparency="0" color="#fa0"><i>{math.floor(tonumber(values[2])*100)/100}</i></font>`
						continue
					end

					--

					format.Details[x] = `{logData.Type} {logData.Origin:lower()} <font transparency="0">{logData.Property}</font> from <font transparency="0" color="#fa0"><i>{values[1]}</i></font> <font size="22" transparency="0.3">→</font> <font transparency="0" color="#fa0"><i>{values[2]}</i></font>`
				end


				local Template; Template = Libraries.scope:New "Frame" {
					Parent = ScrollFrame.Element,
					LayoutOrder = 9999999 - #ScrollFrame.Element:GetChildren(),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 65),

					[Libraries.scope.Children] = {

						Libraries.scope:New "UIPadding" {
							PaddingTop = UDim.new(0, 2),
							PaddingLeft = UDim.new(0, 35),
							PaddingRight = UDim.new(0, 35),
						},

						Libraries.scope:New "TextButton" {
							Name = "Hitbox",
							AutomaticSize = Enum.AutomaticSize.Y,
							AutoButtonColor = true,
							BackgroundColor3 = Libraries.Color "--TextBox-Background",
							Size = UDim2.fromScale(1, 1),

							[Libraries.scope.OnEvent "Activated"] = function( inputObject: InputObject, clickCount: number )
								Template.Hitbox.Details.Visible = not Template.Hitbox.Details.Visible
								Template.Hitbox.Chevron.Rotation = Template.Hitbox.Details.Visible and 90 or 0 
							end,

							[Libraries.scope.Children] = {

								Libraries.scope:New "UICorner" {
									CornerRadius = UDim.new(0, 5),
								},

								Libraries.scope:New "UIPadding" {
									PaddingLeft = UDim.new(0, 25),
									PaddingRight = UDim.new(0, 15),
								},

								Libraries.scope:New "UIStroke" {
									ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
									Color = Libraries.Color "--TextBox-Border",
								},

								--

								Libraries.Common "UserThumbnail" {
									Size = UDim2.fromOffset(40, 40),
									AnchorPoint = Vector2.new(0, 0.5),
									Position = UDim2.fromScale(0, 0.5),
								}:SetUserId(logData.Sender.Id).Element,

								--

								Libraries.scope:New "Frame" {
									Name = "Divider",
									AnchorPoint = Vector2.new(0, 0.5),
									BackgroundColor3 = Libraries.Color "--Border",
									Position = UDim2.fromScale(0.075, 0.5),
									Size = UDim2.fromOffset(1, 40),
								},

								Libraries.scope:New "TextLabel" {
									Name = "Label",
									AutomaticSize = Enum.AutomaticSize.XY,
									BackgroundTransparency = 1,
									LayoutOrder = 1,
									Position = UDim2.new(0.075, 13, 0.225, 0),
									Size = UDim2.new(),

									Text = format.Label,
									FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
									RichText = true,
									TextSize = 17,
									TextColor3 = Libraries.Color "--Primary-Text-Color",
									TextXAlignment = Enum.TextXAlignment.Left,
								},

								Libraries.scope:New "TextLabel" {
									Name = "Timestamp",
									AutomaticSize = Enum.AutomaticSize.XY,
									BackgroundTransparency = 1,
									LayoutOrder = 1,
									Position = UDim2.new(0.075, 13, 0.525, 0),
									Size = UDim2.new(),

									Text = format.Timestamp,
									FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
									RichText = true,
									TextSize = 15,
									TextColor3 = Libraries.Color "--Description-Text-Color",
									TextXAlignment = Enum.TextXAlignment.Left,
								},

								Libraries.scope:New "Frame" {
									Name = "Details",
									AutomaticSize = Enum.AutomaticSize.Y,
									BackgroundTransparency = 1,
									Position = UDim2.fromScale(0, 1),
									Size = UDim2.fromScale(1, 0),
									Visible = false,

									[Libraries.scope.Children] = {

										Libraries.scope:New "UIListLayout" {
											SortOrder = Enum.SortOrder.LayoutOrder,
										},
									}
								},

								Libraries.scope:New "ImageLabel" {
									Name = "Chevron",
									AnchorPoint = Vector2.new(1, 0.5),
									BackgroundTransparency = 1,
									Position = UDim2.fromScale(1, 0.5),
									Size = UDim2.fromOffset(25, 25),
									Image = "rbxassetid://77623958555585",
									ImageColor3 = color "--Description-Text-Color",
									Visible = logData.Values and #logData.Values > 0
								}
							}
						}
					}
				}

				--

				Libraries.scope:New "ImageLabel" {
					Name = "Icon",
					Parent = Template.Hitbox.Thumbnail,
					AnchorPoint = Vector2.new(1, 1),
					BackgroundColor3 = color "--TextBox-Background",
					Position = UDim2.fromScale(1.1, 1.1),
					Size = UDim2.fromOffset(20, 20),

					Image = "rbxassetid://115685602002775",


					[Libraries.scope.Children] = {

						Libraries.scope:New "UICorner" {
							CornerRadius = UDim.new(1, 0),
						}
					}
				}

				--

				for x, text in format.Details do

					Libraries.scope:New "TextLabel" {
						Parent = Template.Hitbox.Details,
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						LayoutOrder = x,

						FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
						Text = `<font transparency="0" color="#fa0">{x} - </font>{text}`,
						RichText = true,
						TextSize = 17,
						TextColor3 = color "--Description-Text-Color",
						TextYAlignment = Enum.TextYAlignment.Top,
						TextXAlignment = Enum.TextXAlignment.Left,

						[Libraries.scope.Children] = {

							Libraries.scope:New "UIPadding" {
								PaddingTop = UDim.new(0, 10),
								PaddingBottom = UDim.new(0, 10),
							}
						}
					}
				end
				
				if (ScrollFrame.Element:FindFirstChild("None")) then ScrollFrame.Element:FindFirstChild("None"):Destroy() end	
			end
		end
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