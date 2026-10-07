local Types = require("../Types")


return function(name: string)
	local cacheKey = `cache@1.0-{name:lower():gsub(" ", "")}`
	_G[cacheKey] = _G[cacheKey] or {}

	if not getmetatable(_G[cacheKey]) then
		_G[cacheKey] = setmetatable(_G[cacheKey] or {}, {
			__index = function(self, key)
				return rawget(self, key)
			end,
			__newindex = function(self, key, value) 
				rawset(self, key, value)
			end,
		})
	end

	return _G[cacheKey]
end :: Types.Cache