----- || LIBRARIES || -----
FlyModule = require(script:WaitForChild("FlyModule"))



----- || CACHE || -----
local cache = {}



----- || MAIN || -----
script.Parent.OnClientEvent:Connect(function( state: boolean, speed: number?, collision: boolean? )
	local boost = state == shared["Nexus Dynamics"].Flying
	
	shared["Nexus Dynamics"].Flying = false
	task.wait()	
	shared["Nexus Dynamics"].Flying = state
	shared["Nexus Dynamics"].FlySpeed = tonumber(speed) or shared["Nexus Dynamics"].FlySpeed or 100
	
	if state then
		FlyModule:Fly(collision, boost)
	end	
end)