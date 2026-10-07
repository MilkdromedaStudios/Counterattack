----- || LIBRARIES || -----
Libraries = require("../Connector")
Cache = Libraries.Cache "UserRegisteryService"
Template = require("../Templates/UserRegistery")
local Types = require("../Types")



----- || MAIN || -----
Cache.Constructor = Cache.Constructor or {	
	GetAsync = function(self: Types.UserRegisteryService, userId: number)
		local data = Libraries.DataStore:GetAsync("UserSettings\Panel")
		data = data and data[tostring(userId)] or Template

		for key, array in data do
			if not array or typeof(array) ~= "string" then continue end
			data[key] = {}

			for index, value in (typeof(array) == "string" and game:GetService("HttpService"):JSONDecode(array) or array) do
				if typeof(value) == "string" and value:sub(1, 1) == "#" then
					data[key][index] = Color3.fromHex(value)
				else
					data[key][index] = value
				end 	 
			end
		end

		return data
	end,

	SaveAsync = function(self: Types.UserRegisteryService, userId: number, data: any)
		xpcall(
			function()
				if not data then return end

				for key, array in data do
					if not array or typeof(array) ~= "table" then continue end

					for index, value in array do
						if typeof(value) == "Color3" then data[key][index] = `#{value:ToHex()}` end
					end

					data[key] = game:GetService("HttpService"):JSONEncode(data[key])
				end

				Libraries.DataStore:UpdateAsync("UserSettings\Panel", function(pastData)
					pastData = pastData or {}
					pastData[tostring(userId)] = data or pastData[tostring(userId)] or Template
					return pastData
				end)
			end,

			function(message)
				Libraries.Log:Capture(message, Enum.MessageType.MessageError)
				return nil
			end
		)
	end,

	RemoveAsync = function(self: Types.UserRegisteryService, userId: number)
		xpcall(
			function()        
				Libraries.DataStore:UpdateAsync("UserSettings\Panel", function(pastData)
					pastData = pastData or {}
					pastData[tostring(userId)] = nil
					return pastData
				end)
			end,

			function(message)
				Libraries.Log:Capture(message, Enum.MessageType.MessageError)
				return nil
			end
		)
	end,

	UpdateAsync = function(self: Types.UserRegisteryService, userId: number, callback: (data: any) -> any?)
		Libraries.DataStore:UpdateAsync("UserSettings\Panel", function(pastData)
			pastData = pastData or {}

			local data = callback(pastData[tostring(userId)])
			pastData[tostring(userId)] = data or pastData[tostring(userId)] or Template
			return pastData
		end)
	end,
}

return Cache.Constructor :: Types.UserRegisteryService