script.Parent.OnServerInvoke = function( player: Player, instance: Terrain, property: string | Enum.Material, value: any )
	pcall(function()
		if typeof(property) == "EnumItem" then
			instance:SetMaterialColor(property, value)
			return
		end
		
		instance[property] = value
	end)
end