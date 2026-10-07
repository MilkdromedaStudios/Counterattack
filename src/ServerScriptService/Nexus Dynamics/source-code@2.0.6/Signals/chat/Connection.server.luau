script.Parent.OnClientEvent:Connect(function( type, instance, message ) 
	
	local __suc, __error = pcall(function()
		
		--| @ Legacy
		if game:GetService("TextChatService").ChatVersion == Enum.ChatVersion.LegacyChatService then

			if type == "bubblechat" then
				game:GetService("Chat"):Chat(instance, message, Enum.ChatColor.White)

				return
			end

			if type == "chat" then

				game.StarterGui:SetCore("ChatMakeSystemMessage", { 
					Text = message, 
					Color = Color3.fromRGB(255, 255, 255), 
					Font = Enum.Font.Arial, 
					FontSize = Enum.FontSize.Size24 
				})	

				return
			end

			return
		end


		--| @ New
		if type == "bubblechat" then game:GetService("TextChatService"):DisplayBubble(instance, message) return end
		if type == "chat" then if instance == game:GetService("Players").LocalPlayer then game:GetService("TextChatService"):FindFirstChild("TextChannels"):FindFirstChild("RBXGeneral"):SendAsync(message) end return end
	end)

	if not __suc then
		shared["Nexus Dynamics // Cache"][__error] = game:GetService("RunService"):IsStudio() and tick() or os.time()
	end
end)