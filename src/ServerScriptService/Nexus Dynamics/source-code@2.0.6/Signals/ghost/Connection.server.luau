local PlayerStorage = {}

script.Parent.OnClientEvent:Connect(function( list : { ["number"] : Player }, ghosted: boolean ) 
	
	local __suc, __error = pcall(function()
		for _, player in list do
			if (typeof(player) ~= "Instance" or not player:IsA("Player")) or (player == game:GetService("Players").LocalPlayer) then return end

			--

			if ghosted then
				PlayerStorage[player.UserId] = {player, player.Character}
				player.Parent, player.Character = nil, nil

				continue
			end

			--

			if not PlayerStorage[player.UserId] then return end

			PlayerStorage[player.UserId][1].Parent, PlayerStorage[player.UserId][2].Parent = game:GetService("Players"), workspace
			PlayerStorage[player.UserId][1].Character = PlayerStorage[player.UserId][2]

			--
			
			local pivot = script.Parent["<getpivot>"]:InvokeServer(player)
			if pivot then PlayerStorage[player.UserId][2]:PivotTo(pivot) end

			--

			PlayerStorage[player.UserId] = nil
		end
	end)

	if not __suc then
		error(__error)
	end
end)