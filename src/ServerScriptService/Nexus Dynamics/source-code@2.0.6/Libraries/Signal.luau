local Signal, Types = {}, require("../Types")
Signal.__index = Signal


function Signal.new()
	local self = setmetatable({}, Signal)

	self._bevent = Instance.new("BindableEvent")
	self.Event = self._bevent.Event

	return self
end


function Signal:Fire(...)
	self._bevent:Fire(...)
end

function Signal:Connect(...)
	return self._bevent.Event:Connect(...)
end

function Signal:ConnectParallel(...)
	return self._bevent.Event:ConnectParallel(...)
end


function Signal:Once(...)
	return self._bevent.Event:Once(...)
end


function Signal:Wait()
	return self._bevent.Event:Wait()
end

return Signal :: Types.Signal