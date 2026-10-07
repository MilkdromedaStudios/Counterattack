----- || LIBRARIES || -----
Libraries = require(script:FindFirstAncestor("panel-client@2.0.6").Connector)
local color = require(script:FindFirstAncestor("panel-client@2.0.6").Libraries.Theme)



----- || MAIN || -----
return function( panel: any )
	
	shared["Nexus Dynamics"].Ribbon.TabChanged:Connect(function( pageName: string )
		for name, page in shared["Nexus Dynamics"].Section do 
			page[pageName == name and "Enable" or "Disable"](page)
		end
	end)
	
	--
	
	local Dashboard = require(script.Dashboard)(panel)
		:Disable()
	
	
	local Commands = require(script.Commands)(panel)
		:Disable()
	
	
	local Manager = require(script.Manager)(panel)
		:Disable()
		:ChangeTab("Workspace")
	
	
	local AuditLog = require(script.AuditLog)(panel)
		:Disable()
	
	
	local BuildInfo = require(script.BuildInfo)(panel)
		:Disable()
	
	local Settings = require(script.Settings)(panel)
		:Disable()
	
	--
	
	return {
		["Dashboard"] = Dashboard,
		["Commands"] = Commands,
		["Manager"] = Manager,
		["AuditLog"] = AuditLog,
		
		["BuildInfo"] = BuildInfo,
		["Settings"] = Settings,
	}
end

