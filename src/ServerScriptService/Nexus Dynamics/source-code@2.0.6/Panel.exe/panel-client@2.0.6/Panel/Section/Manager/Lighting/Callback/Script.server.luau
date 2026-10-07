script.Parent.OnServerInvoke = function( player: Player, instance: Instance, property: string, value: any )
	
	if property ~= "Skybox" then
		pcall(function()
			instance[property] = value
		end)
		
		return
	end
	
	--
	
	local Skybox = Instance.new("Sky", game:GetService("Lighting"))
	for propertyName, value in value do
		pcall(function() Skybox[propertyName] = value end)
	end
end