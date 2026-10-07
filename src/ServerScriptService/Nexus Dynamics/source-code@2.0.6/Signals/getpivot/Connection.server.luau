script.Parent.OnServerInvoke = function(player, target)
	return target.Character and target.Character:GetPivot() or player.Character:GetPivot() + Vector3.new(0, 5, 0)
end