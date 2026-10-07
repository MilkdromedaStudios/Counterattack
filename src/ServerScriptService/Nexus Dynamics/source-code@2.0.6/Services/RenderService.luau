----- || LIBRARIES || -----
Libraries = require("../Connector")
Cache = Libraries.Cache "RenderService"
local Types = require("../Types")



----- || MAIN || -----
Cache.Constructor = Cache.Constructor or {	
	StaticEffect = function( self: any, name: string, properties: {[string]: any}? )
		Libraries.Signals:FindFirstChild("<render>"):FireAllClients({
			["From"] = "RenderService",
			["EffectType"] = "StaticEffect",
			["EffectName"] = name,
			["Properties"] = properties,
		})
	end,

	UnStaticEffect = function( self: any, name: string )
		Libraries.Signals:FindFirstChild("<render>"):FireAllClients({
			["From"] = "RenderService",
			["EffectType"] = "UnStaticEffect",
			["EffectName"] = name,
		})
	end,

	LiveEffect = function( self: any, name: string, properties: {[string]: any}? )
		Libraries.Signals:FindFirstChild("<render>"):FireAllClients({
			["From"] = "RenderService",
			["EffectType"] = "LiveEffect",
			["EffectName"] = name,
			["Properties"] = properties,
		})
	end,

	UnLiveEffect = function( self: any, name: string )
		Libraries.Signals:FindFirstChild("<render>"):FireAllClients({
			["From"] = "RenderService",
			["EffectType"] = "UnLiveEffect",
			["EffectName"] = name,
		})
	end,
}

return Cache.Constructor :: Types.RenderService