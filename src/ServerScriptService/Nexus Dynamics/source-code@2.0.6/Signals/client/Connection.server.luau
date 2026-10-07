script.Parent.OnClientInvoke = function(name, type, args)	
	for _, command in (game:GetService("CollectionService"):GetTagged("nexus-dynamics@2.0-clientcommands")[1] and require(game:GetService("CollectionService"):GetTagged("nexus-dynamics@2.0-clientcommands")[1]) or {}) do
		if (command.Name:lower() == name:lower()) then
			if (type == "undo") then
				command.UnFunction(game:GetService("Players").LocalPlayer, args)
				break
			end
			
			command.Function(game:GetService("Players").LocalPlayer, args)
			break
		end
	end
	
	for _, command in (game:GetService("CollectionService"):GetTagged("nexus-dynamics@2.0-customclientcommands")[1] and require(game:GetService("CollectionService"):GetTagged("nexus-dynamics@2.0-customclientcommands")[1]) or {}) do
		if (command.Name:lower() == name:lower()) then
			if (type == "undo") then
				command.UnFunction(game:GetService("Players").LocalPlayer, args)
				break
			end

			command.Function(game:GetService("Players").LocalPlayer, args)
			break
		end
	end
end