script.Parent.OnServerInvoke = function( player: Player, instance: Instance, property: string, value: any )
	pcall(function()
		instance[property] = value
	end)
end