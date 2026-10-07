script.Parent.Triggered:Connect(function(plr)
	require(game:GetService("ServerScriptService").Managers.ServerCharacterManager).SetupCharacter(plr, "NullexVoyd", "Killer")
end)