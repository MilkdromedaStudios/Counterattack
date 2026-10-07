----- || LIBRARIES || -----
Libraries = require("../Connector")
Cache = Libraries.Cache "GhostService"
local Types = require("../Types")



----- || MAIN || -----
Cache.Constructor = Cache.Constructor or {	
	IsGhosted = function( self: Types.GhostService, player: Player )
		return table.find(Cache, player) ~= nil
	end,

	--

	RefreshPlayer = function( self: Types.GhostService, player: Player )
		Libraries.Signals["<ghost>"]:FireClient(player, Cache, true)
	end,

	GhostAsync = function( self: Types.GhostService, player: Player )
		if self:IsGhosted(player) then return end
		table.insert(Cache, player)

		Libraries.Signals["<ghost>"]:FireAllClients({player}, true)
		self.Ghosted:Fire(player)
	end,

	UnghostAsync = function( self: Types.GhostService, player: Player )
		if not self:IsGhosted(player) then return end
		repeat task.wait(); table.remove(Cache, table.find(Cache, player)::number) until not table.find(Cache, player)

		shared["Nexus Dynamics"].ClientInfo.RBXScriptSignals['Ghost // Communication']:FireAllClients({player}, false)
		self.Unghosted:Fire(player)
	end,

	--

	Ghosted = Libraries.Signal.new(),
	Unghosted = Libraries.Signal.new(),
}

return Cache.Constructor :: Types.GhostService