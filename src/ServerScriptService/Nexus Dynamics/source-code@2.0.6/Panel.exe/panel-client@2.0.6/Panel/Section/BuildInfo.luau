----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || MAIN || -----
return function( panel: any )
	task.wait()
	local Page = Libraries.Windows "Page" {
		Parent = panel.Section,
		Size = UDim2.fromScale(1, 1),
		Name = "BuildInfo",
	}
			
	local ScrollFrame = Libraries.Windows "ScrollFrame" {
		Parent = Page.Element,
		Size = UDim2.fromScale(1, 1),
	}
	
	
	
	--
	
	
	
	local Headers = {
		["Environment"] = Libraries.Common "Header" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 0,
		}:Title("ENVIRONMENT"),
		
		["Product Identification"] = Libraries.Common "Header" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 3,
		}:Title("PRODUCT IDENTIFICATION"),
		
		["Service Versions"] = Libraries.Common "Header" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 9,
		}:Title("SERVICE VERSIONS"),
	}
	
	local Empties = { 
		
		Libraries.Common "Empty" {
			Parent = ScrollFrame.Element,
			Size = UDim2.new(1, 0, 0, 35),
			LayoutOrder = 9,
		},
		
		Libraries.Common "Empty" {
			Parent = ScrollFrame.Element,
			Size = UDim2.new(1, 0, 0, 35),
			LayoutOrder = 14,
		},
		
		
		Libraries.Common "Empty" {
			Parent = ScrollFrame.Element,
			Size = UDim2.new(1, 0, 0, 35),
			LayoutOrder = 999999,
		}
	}
	
	local Gui = {
		
		StudioVersion = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 1,
		}
			
			:Title("STUDIO VERSION")
			:Description("Version of Roblox Studio the panel was developed in.")
			:Value(Libraries.BuildInfo.StudioVersion or "N/A"),
		
		ClientVersion = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 2,
		}

			:Title("CLIENT VERSION")
			:Description("Version of Roblox player the panel was developed in.")
			:Value(Libraries.BuildInfo.ClientVersion or "N/A"),
		
		ModelId = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 4,
		}
			
			:Title("MODEL ID")
			:Description("Model assetId for Nexus Dynamics.")
			:Value(Libraries.BuildInfo.ModelId or "N/A"),
		
		ModelDownload = Libraries.Common "WriteOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 5,
		}
			:Title("MODEL")
			:Description("Get Nexus Dynamics for yourself.")
			:Values({
				Libraries.Interactions "Button" {}
					:Placeholder("Get Model"):Connection(function(self)
						self.Activated:Connect(function()
							game:GetService('MarketplaceService'):PromptPurchase(game:GetService("Players").LocalPlayer, Libraries.BuildInfo.ModelId)
						end)
					end)					
			}),
		
		
		PackageId = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 6,
		}
			
			:Title("PACKAGE ID")
			:Description("Package assetId for the source-code.")
			:Value(Libraries.BuildInfo.PackageId or "N/A"),
		
		PackageDownload = Libraries.Common "WriteOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 7,
		}
			:Title("PACKAGE")
			:Description("Get the source-code for yourself.")
			:Values({
				Libraries.Interactions "Button" {}
				:Placeholder("Get Package"):Connection(function(self)
					self.Activated:Connect(function()
						game:GetService('MarketplaceService'):PromptPurchase(game:GetService("Players").LocalPlayer, Libraries.BuildInfo.PackageId)
					end)
				end)					
			}),
		
		Version = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 8,
		}
			
			:Title("VERSION")
			:Description("The version of Nexus Dynamics.")
			:Value(Libraries.BuildInfo.Version or "N/A"),
		
		BanService = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 16,
		}
			
			:Title("BAN SERVICE")
			:Description("Framework to use Roblox's BanAPI effective and selectively.")
			:Value(Libraries.BuildInfo.BanService or "N/A"),
		
		CommandService = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 17,
		}
			
			:Title("COMMAND SERVICE")
			:Description("Framework responsible for applying commands using format AI.")
			:Value(Libraries.BuildInfo.CommandService or "N/A"),
		
		GhostService = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 18,
		}
			
			:Title("GHOST SERVICE")
			:Description("Framework for hiding players from the experience.")
			:Value(Libraries.BuildInfo.GhostService or "N/A"),
		
		NotificationService = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 19,
		}
			
			:Title("NOTIFICATION SERVICE")
			:Description("Responsible for communicating between clients for popup notifications.")
			:Value(Libraries.BuildInfo.NotificationService or "N/A"),
		
		RankService = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 20,
		}
			
			:Title("RANK SERVICE")
			:Description("Responsible for any and all ranking related actions.")
			:Value(Libraries.BuildInfo.RankService or "N/A"),
		
		RenderService = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 21,
		}
			
			:Title("RENDER SERVICE")
			:Description("Conditional framework responsible for applying renders such as inverted colors and more.")
			:Value(Libraries.BuildInfo.RenderService or "N/A"),
		
		ServerService = Libraries.Common "ReadOnly" {
			Parent = ScrollFrame.Element,
			LayoutOrder = 22,
		}
			
			:Title("SERVER SERVICE")
			:Description("Framework utilied in manipulating the server for locking, matchmaking, and migration.")
			:Value(Libraries.BuildInfo.ServerService or "N/A"),
	}

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