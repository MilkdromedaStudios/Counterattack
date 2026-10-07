local Types = require("../Types")


return {
	new = function(table)
		local self = setmetatable(
			{
				_changed = Instance.new("BindableEvent"),
				table.unpack(table)
			},

			{
				__index = function(self, key)
					return self[key] 
				end,

				__newindex = function(self, key, value)
					self[key] = value
					self._changed:Fire(key, value)
				end,
			}
		)

		rawset(self, "Changed", self._changed.Event)
		return self
	end
} :: Types.Changed