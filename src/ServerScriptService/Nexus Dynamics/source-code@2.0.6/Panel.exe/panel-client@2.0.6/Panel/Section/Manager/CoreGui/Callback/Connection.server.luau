script.Parent.OnServerInvoke = function(plr, data)
	game:GetService("CollectionService"):GetTagged("nexus-dynamics@2.0-signals")[1]["<modifyplayer>"]:InvokeClient(plr, data)
end