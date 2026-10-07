Libraries = require(script.Connector)
Core = require(script.Core)



----- || FLY || -----
Libraries.Notification.OnInvoke = function(message, timer, type)
	Libraries:Notify(message, timer, type)
end

Libraries.Signals["<notification>"].OnClientEvent:Connect(function(message, timer, type, speaker)
	if typeof(message) == "table" then
		Libraries:Notify(message.message, message.timer, message.type, message.speaker)
		return
	end
	
	Libraries:Notify(message, timer, type, speaker)
end)

Libraries.Signals["<fly>"].OnClientEvent:Connect(function(state: boolean, speed: number, collision: boolean)
	shared["Nexus Dynamics"].FlyState = state
	shared["Nexus Dynamics"].FlySpeed = speed or shared["Nexus Dynamics"].FlySpeed or 100 
	shared["Nexus Dynamics"].FlyCollision = collision
	
	Libraries:Fly(state, speed, collision)
end)

return true