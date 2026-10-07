local frame = script.Parent
local oybEventFolder = game.ReplicatedStorage:WaitForChild("OYBEVENT")
local adminEvent = oybEventFolder:WaitForChild("OYB_AdminEvent")

local announceInput = frame:WaitForChild("AnnounceInput", 10)
local announceBtn = frame:WaitForChild("AnnounceButton", 10)
local choice1Input = frame:FindFirstChild("Choice1Input")
local choice2Input = frame:FindFirstChild("Choice2Input")
local timeInput = frame:FindFirstChild("TimeInput")

if announceBtn and announceInput then
	announceInput.ClearTextOnFocus = false
	if choice1Input then choice1Input.ClearTextOnFocus = false end
	if choice2Input then choice2Input.ClearTextOnFocus = false end
	if timeInput then timeInput.ClearTextOnFocus = false end

	announceBtn.MouseButton1Click:Connect(function()
		local text = announceInput.Text
		if text == "" then return end

		local c1 = choice1Input and choice1Input.Text or ""
		local c2 = choice2Input and choice2Input.Text or ""
		local pollTime = timeInput and tonumber(timeInput.Text) or 30 

		if c1 ~= "" and c2 ~= "" then
			local pollData = {
				Question = text,
				Choice1 = c1,
				Choice2 = c2,
				Duration = pollTime
			}
			adminEvent:FireServer("SendPoll", pollData)
		else
			adminEvent:FireServer("SendAnnouncement", text)
		end
	end)


end