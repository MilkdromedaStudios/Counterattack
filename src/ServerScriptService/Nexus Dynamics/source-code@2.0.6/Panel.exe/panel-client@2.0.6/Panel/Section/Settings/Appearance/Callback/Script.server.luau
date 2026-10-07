script.Parent.OnServerInvoke = function( player: Player, instance: Instance, property: string, value: any )
	if (typeof(instance) == "Instance") then
		pcall(function()
			instance[property] = value
		end)
	end
	
	if (typeof(property) == "string") then
		if (property == "import") then
			return game:GetService("HttpService"):JSONDecode(instance)
		else
			warn("---------------------------------")
			game:GetService("TestService"):Message("\n\nCopy Below:\n---------------------------------\n"..game:GetService("HttpService"):JSONEncode(instance))
			warn("---------------------------------")
		end
	end
end