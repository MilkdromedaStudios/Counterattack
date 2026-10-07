local Types = require("./Types")
Cache = require("./Libraries/Cache") ""

if (not Cache.Data) then 
	dictionary = {

		File = script:FindFirstAncestor("Nexus Dynamics"),
		Custom = script:FindFirstAncestor("Nexus Dynamics").Custom,

		--

		Package = script:FindFirstAncestor("source-code@2.0.6"),
		Libraries = script:FindFirstAncestor("source-code@2.0.6"):FindFirstChild("Libraries"),
		Services = script:FindFirstAncestor("source-code@2.0.6"):FindFirstChild("Services"),
		Templates = script:FindFirstAncestor("source-code@2.0.6"):FindFirstChild("Templates"),

		--

		Cache = require("./Libraries/Cache"),
		Changed = require("./Libraries/Changed"),
		Log = require("./Libraries/Log"),	
		Maid = require("./Libraries/Maid"),
		Signal = require("./Libraries/Signal"),
		Util = require("./Libraries/Util"),

		--

		DataStore = game:GetService("DataStoreService"):GetDataStore("Nexus Dynamics // Data v2.0"),
		Signals =  script:FindFirstAncestor("source-code@2.0.6"):FindFirstChild("Signals"),

		--

		Elapsed = tick(), 
		Scope = require("./Libraries/Maid").new(),

		--

		Switch = function(case: any)
			return function(cases: {[string]: () -> any})
				if cases[case] then
					return cases[case]()
				elseif cases.default then
					return cases.default()
				end

				return nil
			end
		end,
	}

	Cache.Data = dictionary	
end

return Cache.Data :: Types.Connector