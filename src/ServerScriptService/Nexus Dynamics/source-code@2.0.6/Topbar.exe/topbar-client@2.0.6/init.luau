----- || LIBRARIES || -----
local Fusion = require(script.Libraries.Fusion); Fusion = Fusion.scoped(Fusion)



----- || TYPE CHECKING || -----
type _dictionary = {
	Icon: TextButton,
	ScreenGui: { Centered: ScreenGui, Sides: ScreenGui },

	Center: ( self: _dictionary ) -> _dictionary,
	Right: ( self: _dictionary ) -> _dictionary,
	Left: ( self: _dictionary ) -> _dictionary,

	Hide: ( self: _dictionary ) -> _dictionary,
	Show: ( self: _dictionary ) -> _dictionary,

	Enable: ( self: _dictionary ) -> _dictionary, 
	Disable: ( self: _dictionary ) -> _dictionary, 
}



----- || METHODS || -----
function createIcon()
	local icon = Fusion:New "TextButton" {
		Name = "Nexus Dynamics Topbar Icon",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.3,
		Size = UDim2.fromOffset(44, 44),
		
		[Fusion.Children] = {
			Fusion:New "UICorner" {
				CornerRadius = UDim.new(1, 0),
			},
			
			Fusion:New "Frame" {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.8, 0.8),
				
				[Fusion.Children] = {
					Fusion:New "UICorner" {
						CornerRadius = UDim.new(1, 0),
					},
					
					Fusion:New "ImageLabel" {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(0.6, 0.6),
						Image = "rbxassetid://13636059383",
					}	
				}
			},
		}
	}
	
	icon.MouseEnter:Connect(function()
		icon.Frame.BackgroundTransparency = 0.925
	end)
	
	icon.MouseLeave:Connect(function()
		icon.Frame.BackgroundTransparency = 1
	end)	
	
	return icon	
end

function createCentered()
	
	return Fusion:New "ScreenGui" {
		Name = "topbar-centered@2.0",
		Parent = script:FindFirstAncestorWhichIsA("Player").PlayerGui,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		
		[Fusion.Children] = {
			
			Fusion:New "Frame" {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				
				[Fusion.Children] = {
					Fusion:New "UIListLayout" {
						Padding = UDim.new(0, 12),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					},
					
					Fusion:New "UIPadding" {
						PaddingTop = UDim.new(0, 12),
					}
				}
			}
		}
	}
end

function createSides()

	return Fusion:New "ScreenGui" {
		Name = "topbar-sides@2.0",
		Parent = script:FindFirstAncestorWhichIsA("Player").PlayerGui,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {

			Fusion:New "Frame" {
				Name = "Left",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),

				[Fusion.Children] = {
					Fusion:New "UIListLayout" {
						Padding = UDim.new(0, 12),
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					},

					Fusion:New "UIPadding" {
						PaddingTop = UDim.new(0, 12),
						PaddingLeft = UDim.new(0, 12),
					}
				}
			},
			
			Fusion:New "Frame" {
				Name = "Right",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),

				[Fusion.Children] = {
					Fusion:New "UIListLayout" {
						Padding = UDim.new(0, 12),
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Top,
					},

					Fusion:New "UIPadding" {
						PaddingTop = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
					}
				}
			}	
		}
	}
end



----- || MAIN || -----
dictionary = {
	
	Icon = createIcon(),
	
	ScreenGui = {
		Centered = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("TopbarCentered") or createCentered(),
		Sides = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("TopbarStandard") or createSides(),
	},
	
	
	--
	
	
	Center = function( self: _dictionary )
		self.Icon.Parent = self.ScreenGui.Centered:FindFirstChildWhichIsA("ScrollingFrame", true)  or self.ScreenGui.Centered:FindFirstChildWhichIsA("Frame", true) 
		return self
	end,
	
	Right = function( self: _dictionary )
		self.Icon.Parent = self.ScreenGui.Sides:FindFirstChild("Right", true)  or self.ScreenGui.Centered:FindFirstChild("Right", true)
		return self
	end,
	
	Left = function( self: _dictionary )
		self.Icon.Parent = self.ScreenGui.Sides:FindFirstChild("Left", true)  or self.ScreenGui.Centered:FindFirstChild("Left", true)
		return self
	end,
	
	
	--
	
	
	Hide = function( self: _dictionary )
		self.Icon.Visible = false
		return self
	end,
	
	Show = function( self: _dictionary )
		if shared["Nexus Dynamics"] and shared["Nexus Dynamics"].Config and not shared["Nexus Dynamics"].Config.TopbarEnabled then
			self.Icon.Visible = false
			return self
		end
		
		self.Icon.Visible = true
		return self
	end,

	Disable = function( self: _dictionary )
		self.Icon.Interactable = false
		return self
	end,
	
	Enable = function( self: _dictionary )
		self.Icon.Interactable = true
		return self
	end,
} :: _dictionary


--

dictionary.Icon.BackgroundTransparency = _G["topbar-client@2.0.6\config"].Transparency or 0.3
dictionary[_G["topbar-client@2.0.6\config"].TopbarEnabled and "Show" or "Hide"](dictionary)
dictionary[_G["topbar-client@2.0.6\config"].TopbarPosition or "Center"](dictionary)

dictionary.Icon.MouseButton1Click:Connect(function()
	shared["Nexus Dynamics"].Menu:Open()
end)

--

shared["Nexus Dynamics // Topbar"] = dictionary
return dictionary