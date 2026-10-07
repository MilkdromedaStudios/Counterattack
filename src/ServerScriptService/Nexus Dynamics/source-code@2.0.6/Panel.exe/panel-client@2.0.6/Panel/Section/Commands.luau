----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || MAIN || -----
return function( panel: any )
	local Page = Libraries.Windows "Page" {
		Parent = panel.Section,
		Size = UDim2.fromScale(1, 1),
		Name = "Commands",
	}

	Libraries.scope:New "UIPadding" { PaddingTop = UDim.new(0, 16), Parent = Page.Element };
	
	local ScrollFrame = Libraries.Windows "ScrollFrame" {
		Parent = Page.Element,
		Size = UDim2.new(1, 0, 1, -40),
		LayoutOrder = 2,
	}
		
	
	local function createTemplate( commandArray: any )
		return Libraries.Interactions("Command") {
			Parent = ScrollFrame.Element,
		}
		:Command(commandArray.Name)
		:Qualifiers(table.concat(commandArray.Qualifiers, " "))
		:Description(commandArray.Description)
		:Rank(commandArray.Rank).Element
	end	
	
	local function Start()
		local Folder = Libraries.Signals 
		shared["Nexus Dynamics"].CommandList = Folder:FindFirstChild("<command>", true):InvokeServer()
		local storage, commandList = {}, shared["Nexus Dynamics"].CommandList 
			
		--
		
		local searchBar = Libraries.Interactions "Search" { Parent = Page.Element, Size = UDim2.new(1, -50, 0, 40)}
			:Title("Search for command")
			:Placeholder("Enter Keyword")
		
		searchBar.Element:GetPropertyChangedSignal("Text"):Connect(function()
			for _, commandInfo in ScrollFrame.Element:GetChildren() do
				if (commandInfo == searchBar) or (not commandInfo:IsA("GuiObject")) then continue end
				commandInfo.Visible = commandInfo.Body.Left.Frame.Title.Text:lower():find(searchBar.Element.Text) ~= nil
			end
		end)
		
		--
		
		for index, commandArray in commandList do local __suc, __error = pcall(function()
				
				local infoArray = {
					Name = `{game:GetService("Players"):GetAttribute("Prefix")}{commandArray.Name}` or "N/A",
					Description = commandArray.Description or "N/A",
					Rank = commandArray.RankName or "N/A", 
					
					Qualifiers = {},
				}
				
				for index, argument in commandArray.Arguments do 
					table.insert(infoArray.Qualifiers, `<{argument}>`)
				end
				
				--
				
				createTemplate(infoArray).LayoutOrder = #ScrollFrame.Element:GetChildren()-1
				
				--
							
				if not (commandArray.HasUndo or commandArray.UnFunction) then return end
				
				infoArray = {
					Name = `{game:GetService("Players"):GetAttribute("Prefix")}un{commandArray.Name}` or "N/A",
					Description = `Undos the {commandArray.Name} command.` or "N/A",
					Rank = infoArray.Rank or "N/A",
					
					Qualifiers = {},
				}
				
				createTemplate(infoArray).LayoutOrder = #ScrollFrame.Element:GetChildren()-1
			end) 
			
			game:GetService("RunService").Heartbeat:Wait()
			
			if not __suc then
				error(__error)
			end
		end
	end
	
	--
	
	task.delay(5, Start)
	
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