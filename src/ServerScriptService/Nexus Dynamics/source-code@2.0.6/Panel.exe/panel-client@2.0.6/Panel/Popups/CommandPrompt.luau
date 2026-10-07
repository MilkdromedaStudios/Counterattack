----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || TYPE CHECK || -----
type _dictionary = {		
	GetQualifierType: ( self: _dictionary, text: string ) -> string
}



----- || MAIN || -----
return function( panel: any )
	local CommandPrompt, Suggestions, Event, Open, Close = Libraries.Windows "CommandPrompt" {}, {}, Libraries.Maid.signal("Event"), Libraries.Maid.signal("Event"), Libraries.Maid.signal("Event")
	
	for i = 1, 5 do
		Suggestions[i] = Libraries.scope:New "TextButton" {
			Name = i,
			Parent = CommandPrompt.Suggestions,
			BackgroundColor3 = Color3.fromRGB(108, 108, 111),
			AutoButtonColor = true,
			BackgroundTransparency = 0.875,
			Size = UDim2.new(1, 0, 0, 30),
			Text = "",
			Visible = false,

			[Libraries.scope.OnEvent "MouseButton1Down"] = function()
				Event:Fire(`{Suggestions[i].Left:FindFirstChild("Name").Text} `)
			end,

			[Libraries.scope.Children] = {

				Libraries.scope:New "UIPadding" {
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				},

				Libraries.scope:New "Frame" {
					Name = "Left",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),

					[Libraries.scope.Children] = {
						Libraries.scope:New "UIListLayout" {
							Padding = UDim.new(0, 8),
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						},

						Libraries.scope:New "ImageLabel" {
							Name = "Icon",
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundTransparency = 0.925,
							Size = UDim2.fromOffset(16, 16),

							[Libraries.scope.Children] = {
								Libraries.scope:New "UICorner" {
									CornerRadius = UDim.new(1, 0)		
								}	
							}
						},

						Libraries.scope:New "TextLabel" {
							Name = "Name",
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundTransparency = 1,
							LayoutOrder = 2,
							Size = UDim2.fromScale(0, 1),
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,

							TextColor3 = Libraries.Color "--Primary-Text-Color",
							TextTransparency = 0.3,
							Text = "NAME",
							TextXAlignment = Enum.TextXAlignment.Left,
						}
					}
				},

				Libraries.scope:New "Frame" {
					Name = "Right",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),

					[Libraries.scope.Children] = {
						Libraries.scope:New "UIListLayout" {
							Padding = UDim.new(0, 8),
							SortOrder = Enum.SortOrder.LayoutOrder,
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Right,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						},

						Libraries.scope:New "Frame" {
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 0.95,
							Size = UDim2.new(0, 1, 1, 0),
						},

						Libraries.scope:New "TextLabel" {
							Name = "Description",
							BackgroundTransparency = 1,
							LayoutOrder = 4,
							Size = UDim2.fromScale(0.52, 1),
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,

							TextColor3 = Libraries.Color "--Primary-Text-Color",
							TextTransparency = 0.3,
							Text = "DESCRIPTION",
							TextXAlignment = Enum.TextXAlignment.Left,

							[Libraries.scope.Children] = {
								Libraries.scope:New "UIPadding" {
									PaddingLeft = UDim.new(0, 8),
								},
							}
						},

						Libraries.scope:New "TextLabel" {
							Name = "RunContext",
							BackgroundTransparency = 1,
							LayoutOrder = 5,
							Size = UDim2.fromScale(0.115, 1),
							FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextSize = 16,

							TextColor3 = Libraries.Color "--Primary-Text-Color",
							Text = "RUNCONTEXT",
							TextXAlignment = Enum.TextXAlignment.Right,
						}
					}
				}
			}
		}
	end
	
	local _config = {
		needle = 1,
		type = "command",
		commandDict = nil,
		pick = 1,
		maxPick = 1,
	}
	
	task.spawn(function()
		repeat task.wait() until shared["Nexus Dynamics"].CommandList	
		local _rules, _flags = table.unpack(Libraries.Signals:FindFirstChild("<command>"):InvokeServer { rules = true } or {})

		local function GetQualifierType( text: string )
			for name, aliases in _rules.QualifierTypes do
				if name:lower() == text or table.find(aliases, text:lower()) then
					return name
				end
			end

			return nil
		end



		--
		
		local function Complete(text)
			CommandPrompt.TextBox.Text = text
			CommandPrompt.TextBox.CursorPosition = #text+1
		end
		
		local function Fill(text)
			local str = ""

			for index, text in CommandPrompt.TextBox.Text:split(" ") do
				str ..= `{index > 1 and " " or ""}{text}`
				if index == _config.needle then break end	
			end	
			
			CommandPrompt.TextBox.Text = str
		end

		local function GenerateSuggestions()
			if not (shared["Nexus Dynamics"].CommandList) then return {} end

			local text = CommandPrompt.TextBox.Text:split(" ")[_config["needle"]]
			local _suggestions = {}

			Libraries.Switch(_config.type and _config.type:lower() or nil) {

				["command"] = function()
					for _, command in shared["Nexus Dynamics"].CommandList or {} do
						if #_suggestions > 4 then break end
						local name = command.Name

						if name:lower():gsub(" ", ""):sub(1, #text) == text:lower():gsub(" ", "") then
							table.insert(_suggestions, command)
						elseif (`un{name}`):lower():gsub(" ", ""):sub(1, #text) == text:lower():gsub(" ", "") then
							table.insert(_suggestions, command)
						end
					end
				end,

				["player"] = function()
					local array = {
						"me",
						"other",
						"all",
						"random",
						"admins",
						"nonadmins",
						"friends",
						"nonfriends",
						"premium",
						"nonpremium",
						"r6",
						"r15"					
					}

					for _, player in game:GetService("Players"):GetPlayers() do table.insert(array, player.name) end
					for _, team in game:GetService("Teams"):GetTeams() do table.insert(array, `%{team.Name}`) end


					for _, item in array do
						if #_suggestions > 4 then break end

						if item:lower():gsub(" ", ""):sub(1, #text) == text:lower():gsub(" ", "") then
							table.insert(_suggestions, item)
						end
					end
				end,

				["team"] = function() 
					local array = game:GetService("Teams"):GetTeams()

					for _, item in array do
						if #_suggestions > 4 then break end
						if item.Name:lower():gsub(" ", ""):sub(1, #text:gsub(" ", "")) == text:lower():gsub(" ", "") then
							table.insert(_suggestions, (item.Name:gsub(" ", "")))
						end
					end
				end,

				["Instance"] = function()
					for _, item in _rules.Classes do
						if #_suggestions > 4 then break end
						if item:lower():sub(1, #text) == text:lower() then
							table.insert(_suggestions, item)
						end
					end
				end,

				["basepart"] = function()
					for _, item in {"Part", "Block", "Cylinder", "Wedge", "CornerWedge", "Sphere", "Meshpart"} do
						if #_suggestions > 4 then break end
						if item:lower():sub(1, #text) == text:lower() then
							table.insert(_suggestions, item)
						end
					end
				end,

				["constraint"] = function()
					for _, item in {"Attachment", "WeldConstraint", "Motor6D"} do
						if #_suggestions > 4 then break end
						if item:lower():sub(1, #text) == text:lower() then
							table.insert(_suggestions, item)
						end
					end	
				end,

				["Effect"] = function()
					for _, item in {"Fire", "Sparkles", "Smoke", "PointLight", "SpotLight", "AreaLight", "Highlight", "ParticleEmitter"} do
						if #_suggestions > 4 then break end
						if item:lower():sub(1, #text) == text:lower() then
							table.insert(_suggestions, item)
						end
					end	
				end,

				["unionoperation"] = function()
					for _, item in Enum.OperationType:GetEnumItems() do
						if #_suggestions > 4 then break end
						if (`Enum.{item.EnumType}.{item.Name}`):lower():sub(1, #text) == text:lower() then
							table.insert(_suggestions, item.Name)
						end
					end	
				end,

				["boolean"] = function()
					_suggestions = {"true", "false"}
				end,

				["enum"] = function()
					for _, enum in Enum:GetEnums() do
						if #_suggestions > 4 then break end
						for _, item in enum:GetEnumItems() do
							if #_suggestions > 4 then break end
							if (`Enum.{item.EnumType}.{item.Name}`):lower():sub(1, #text) == text:lower() then
								table.insert(_suggestions,`Enum.{item.EnumType}.{item.Name}`)
							end
						end	
					end
				end,

				["color"] = function()
					if text:find(",") then return end
					for name, color in Libraries.Util.GetBrickColors() do
						if #_suggestions > 4 then break end
						if name:gsub(" ", ""):lower():sub(1, #text:gsub(" ", "")) == text:lower():gsub(" ", "") then
							table.insert(_suggestions, name)
						end
					end
				end,

				["material"] = function()
					for _, material in Enum.Material:GetEnumItems() do
						if #_suggestions > 4 then break end
						if material.Name:lower():sub(1, #text) == text:lower() then
							table.insert(_suggestions, material.Name)
						end
					end
				end,

				["Rank"] = function()

				end,

				default = function()
					return nil
				end,
			}

			for i, bar in Suggestions do game:GetService('RunService').Heartbeat:Wait()
				bar.BackgroundTransparency = _config.pick == i and 0.625 or 0.875				
				bar.Left:FindFirstChild("Name").Text = (_config.type:lower() == "command") and (_suggestions[i] and _suggestions[i].Name) or _suggestions[i] or ""
				bar.Right:FindFirstChild("Description").Text = (_config.type:lower() == "command") and (_suggestions[i] and _suggestions[i].Description) or ""
				bar.Right:FindFirstChild("RunContext").Text = (_config.type:lower() == "command") and (_suggestions[i] and _suggestions[i].RunContext.Name) or ""
				

				local value = ((_config.type:lower() ~= "command") and _suggestions[i]) and Libraries.Switch(_config.type:lower()) {
					player = function()
						if _suggestions[i]:lower() == "me" then
							return game:GetService("Players"):GetUserThumbnailAsync(game:GetService("Players").LocalPlayer.UserId, "HeadShot", "Size420x420")
						elseif game:GetService("Players"):FindFirstChild(_suggestions[i]) then
							return game:GetService("Players"):GetUserThumbnailAsync(game:GetService("Players")[_suggestions[i]].UserId, "HeadShot", "Size420x420")
						else 
							return nil
						end
					end,

					team = function()
						return game:GetService("Teams")[_suggestions[i]] and game:GetService("Teams")[_suggestions[i]].TeamColor.Color or nil
					end,

					characterappearance = function()
						if _suggestions[i] == "me" then
							return game:GetService("Players"):GetUserThumbnailAsync(game:GetService("Players").LocalPlayer.UserId, "HeadShot", "420x420")
						elseif game:GetService("Players"):FindFirstChild(_suggestions[i]) then
							return nil
						else 
							return game:GetService("Players"):GetUserThumbnailAsync(game:GetService("Players")[_suggestions[i]], "HeadShot", "420x420")
						end
					end,

					material = function()
						for name, array  in Libraries.Util.GetMaterialTextures() do
							if name:lower():gsub(" ", "") == _suggestions[i]:lower():gsub(" ", "") then
								return array
							end
						end
						
						return nil
					end,

					color = function() 
						for name, color in Libraries.Util.GetBrickColors() do
							if name:lower() == _suggestions[i]:lower() then
								return color
							end
						end
					end,	

					default = function() return nil end,
				} or nil

				if value then
					if typeof(value) == "string" then
						bar.Left.Icon.Image = value
						bar.Left.Icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
						bar.Left.Icon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
						bar.Left.Icon.BackgroundTransparency = 0.925
					elseif typeof(value) == "Color3" then
						bar.Left.Icon.Image = "" 	
						bar.Left.Icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
						bar.Left.Icon.BackgroundColor3 = value 	
						bar.Left.Icon.BackgroundTransparency = 0
					elseif typeof(value) == "table" then
						bar.Left.Icon.Image = value.ID
						bar.Left.Icon.ImageColor3 = value.Color
						bar.Left.Icon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
						bar.Left.Icon.BackgroundTransparency = 0.925
					end

					bar.Left.Icon.Visible = Libraries.Config.PreviewIcons and true or false
				else
					bar.Left.Icon.Visible = false
				end
				
				bar.Visible = Libraries.Config.Suggestions and _suggestions[i] ~= nil or false
			end
			
			_config.maxPick = #_suggestions or 1
			return _suggestions or {}
		end
		
		Event:Connect(function(_text)
			local str = ""

			for index, text in CommandPrompt.TextBox.Text:split(" ") do
				local suggestedText = _text

				if index == _config.needle then
					str ..= `{index > 1 and " " or ""}{suggestedText}`
					break
				else
					str ..= `{index > 1 and " " or ""}{text}`
				end	
			end	
			
			Complete(str)
		end)
		
		game:GetService("UserInputService").InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Tab and CommandPrompt.TextBox:IsFocused() and Libraries.Config.Autofill then
				CommandPrompt.TextBox:GetPropertyChangedSignal("Text"):Wait()
				Complete(CommandPrompt.InputBox.Content.AutoFill.Text.." ")
			end
			
			if (input.KeyCode == Enum.KeyCode.Up or input.KeyCode == Enum.KeyCode.Down) and CommandPrompt.TextBox:IsFocused() then
				_config.pick = math.clamp(_config.pick + (input.KeyCode == Enum.KeyCode.Up and -1 or input.KeyCode == Enum.KeyCode.Down and 1), 1, _config.maxPick)
				GenerateSuggestions()
				
				local str = ""

				if CommandPrompt.TextBox.Text ~= "" and Suggestions[_config.pick] then
					for index, text in CommandPrompt.TextBox.Text:split(" ") do
						local suggestedText = (_config.type:lower() == "command") and Suggestions[_config.pick].Left:FindFirstChild("Name").Text or ""

						if index == _config.needle then
							str ..= `{index > 1 and " " or ""}{text..suggestedText:sub(#text+1, #suggestedText)}`
							break
						else
							str ..= `{index > 1 and " " or ""}{text}`
						end	
					end			
				end
				
				CommandPrompt.InputBox.Content.AutoFill.Visible = Libraries.Config.Autofill
				CommandPrompt.InputBox.Content.AutoFill.Text = str
			end
		end)
		
		CommandPrompt.TextBox:GetPropertyChangedSignal("Text"):Connect(function(property) 
			_config.needle = (#CommandPrompt.TextBox.Text:split(" ") or 0) + 0


			if _config.needle > 1 and not _config.commandDict then
				for _, command in shared["Nexus Dynamics"].CommandList do 
					if command.Name:lower() == CommandPrompt.TextBox.Text:split(" ")[1]:lower() then
						_config.commandDict = command
						break
					end
				end
			elseif _config.needle < 2 then
				_config.commandDict = nil
			end

			if _config.commandDict then
				_config.type = _config.commandDict.Arguments[_config.needle-1] or "none"
			else
				_config.type = "command"
			end

			local _suggestions = GenerateSuggestions()
			
			local str = ""

			if CommandPrompt.TextBox.Text ~= "" and _suggestions[_config.pick] then
				for index, text in CommandPrompt.TextBox.Text:split(" ") do
					local suggestedText = (_config.type:lower() == "command") and _suggestions[1].Name or _suggestions[1]
					
					if typeof(suggestedText) == "table" then
						suggestedText = suggestedText.Name or suggestedText[1]
					end
					
					if index == _config.needle then
						str ..= `{index > 1 and " " or ""}{text..suggestedText:sub(#text+1, #suggestedText)}`
						break
					else
						str ..= `{index > 1 and " " or ""}{text}`
					end	
				end			
			end
			
			CommandPrompt.InputBox.Content.AutoFill.Visible = Libraries.Config.Autofill
			CommandPrompt.InputBox.Content.AutoFill.Text = str
		end)

		CommandPrompt.TextBox.FocusLost:Connect(function(enterPressed)
			if not enterPressed then return end
			
			task.spawn(function()
				Libraries.Signals:FindFirstChild("<command>"):InvokeServer {
					request = true,
					message = CommandPrompt.TextBox.Text
				}
			end)
			
			CommandPrompt.TextBox.Text = ""
			CommandPrompt.Element.Parent = nil
			CommandPrompt.Element.Visible = false

			_config = {
				needle = 1,
				type = "command",
				commandDict = nil,
				pick = 1,
				maxPick = 1,
			}

			for _, bar in Suggestions do
				CommandPrompt.TextBox.Text = ""
			end
		end)
		
		Open:Connect(function()
			GenerateSuggestions()
		end)
	end)
	
	CommandPrompt.InputBox.Content.Close.MouseButton1Down:Connect(function()
		Close:Fire()
		CommandPrompt.Element.Parent = nil
		CommandPrompt.Element.Visible = false
		CommandPrompt.TextBox.Text = ""

		_config = {
			needle = 1,
			type = "command",
			commandDict = nil,
			pick = 1,
			maxPick = 1,
		}

		for _, bar in Suggestions do
			CommandPrompt.TextBox.Text = ""
		end
	end)

	game:GetService("UserInputService").InputBegan:Connect(function(input, isBusy)
		if isBusy and input.KeyCode == Enum.KeyCode.Escape then
			CommandPrompt.Element.Parent = nil
			CommandPrompt.Element.Visible = false

			_config = {
				needle = 1,
				type = "command",
				commandDict = nil,
				pick = 1,
				maxPick = 1,
			}

			for _, bar in Suggestions do
				CommandPrompt.TextBox.Text = ""
			end
		end

		if isBusy or input.KeyCode.Name ~= Libraries.Config.CommandPrompt then return end

		if not CommandPrompt.Element.Parent then
			_config = {
				needle = 1,
				type = "command",
				commandDict = nil,
				pick = 1,
				maxPick = 1,
			}

			for _, bar in Suggestions do
				CommandPrompt.TextBox.Text = ""
			end
			
			Open:Fire()
			game:GetService("RunService").Heartbeat:Wait()
			CommandPrompt.Element.Parent = panel.Element.Parent
			CommandPrompt.Element.Visible = true
			task.wait()
			CommandPrompt.TextBox:CaptureFocus()
		else 
			Close:Fire()
			CommandPrompt.TextBox.Text = ""
			CommandPrompt.Element.Parent = nil
			CommandPrompt.Element.Visible = false

			_config = {
				needle = 1,
				type = "command",
				commandDict = nil,
				pick = 1,
				maxPick = 1,
			}

			for _, bar in Suggestions do
				CommandPrompt.TextBox.Text = ""
			end
		end
	end)
	
	return {
		Open = function()
			_config = {
				needle = 1,
				type = "command",
				commandDict = nil,
				pick = 1,
				maxPick = 1,
			}
			
			for _, bar in Suggestions do
				CommandPrompt.TextBox.Text = ""
			end
			
			Open:Fire()
			game:GetService("RunService").Heartbeat:Wait()
			CommandPrompt.Element.Parent = panel.Element.Parent
			CommandPrompt.Element.Visible = true
			task.wait()
			CommandPrompt.TextBox:CaptureFocus()
		end,
		
		Close = function()
			Close:Fire()
			CommandPrompt.TextBox.Text = ""
			CommandPrompt.Element.Parent = nil
			CommandPrompt.Element.Visible = false
			
			_config = {
				needle = 1,
				type = "command",
				commandDict = nil,
				pick = 1,
				maxPick = 1,
			}

			for _, bar in Suggestions do
				CommandPrompt.TextBox.Text = ""
			end
		end,
	}	
end 