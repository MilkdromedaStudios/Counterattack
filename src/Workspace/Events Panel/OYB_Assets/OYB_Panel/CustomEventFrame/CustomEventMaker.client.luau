local frame = script.Parent
local oybEventFolder = game.ReplicatedStorage:WaitForChild("OYBEVENT")
local adminEvent = oybEventFolder:WaitForChild("OYB_AdminEvent")
local clientEvent = oybEventFolder:WaitForChild("OYB_ClientEvent")

local fetchedOwnerId = nil

local nameInput = frame:WaitForChild("NameInput", 5)
local musicInput = frame:WaitForChild("MusicInput", 5)
local createBtn = frame:WaitForChild("CreateButton", 5)
local themeSelectBtn = frame:WaitForChild("ThemeSelectBtn", 5)
local themeScroll = frame:WaitForChild("ThemeScroll", 5)
local animSelectBtn = frame:WaitForChild("AnimSelectBtn", 5)
local animScroll = frame:WaitForChild("AnimScroll", 5)
local animInput = frame:WaitForChild("AnimInput", 5)
local emojiSelectBtn = frame:WaitForChild("EmojiSelectBtn", 5)
local emojiScroll = frame:WaitForChild("EmojiScroll", 5)

local selectedTheme = ""
local selectedAnimId = ""
local isCustomAnim = false
local selectedEmoji = ""

local allThemes = {
	"Cake", "Lava", "Money", "Glitch", "Winter", "Acid", "Heart", "Ocean", "Shadow", "Alien",
	"Party", "MemeParty", "Taco", "Zombie", "Space", "Anime"
}

local allAnims = {
	{ Name = "No Animation", ID = "" },
	{ Name = "Custom ID", ID = "CUSTOM" },
	{ Name = "Levitate / God Pose", ID = "3337994105" },
	{ Name = "Dance 1", ID = "507771019" },
	{ Name = "Dance 2", ID = "507776043" },
	{ Name = "Dance 3", ID = "507777623" },
	{ Name = "Cheer", ID = "507770677" },
	{ Name = "Laugh", ID = "507770818" },
	{ Name = "Salute", ID = "507770239" },
	{ Name = "Wave", ID = "507769204" }
}

local allEmojis = {
	"✨", "🔥", "⚡", "🌟", "⭐", "👾", "💫", "🎉", "🎊", "🎈",
	"🎇", "🎆", "🎵", "🎶", "🎼", "🎸", "🎧", "🌍", "🌎", "🌏",
	"🌕", "☀️", "☁️", "⛅", "🌤️", "🌈", "☂️", "☔", "❄️", "🚗",
	"🚓", "🚕", "🍔", "🍕", "🍟", "🌭", "🍿", "🍩", "🍦", "⚽",
	"🏀", "🏈", "⚾", "🎾", "🏐", "🎱", "🏓", "🏆", "🎮", "🍎",
	"🤑", "🍉", "🍇", "🍓", "🐱", "🐶", "🐰", "🐻", "🐼", "🐸",
	"🐢", "🐬", "🦋", "🚀", "🚁", "⛵", "🎨", "🧩", "🧸", "🌸"
}

local function createDropdownButton(parentScroll, text, onClickCallback)
	local template = parentScroll:FindFirstChild("Template")
	if not template then return end
	local btn = template:Clone()
	btn.Name = text
	btn.Text = text
	btn.Visible = true
	btn.Parent = parentScroll
	btn.MouseButton1Click:Connect(onClickCallback)
	return btn
end

for _, themeName in ipairs(allThemes) do
	createDropdownButton(themeScroll, themeName, function()
		selectedTheme = themeName
		themeSelectBtn.Text = "Theme: " .. themeName
		themeScroll.Visible = false
	end)
end

for _, animData in ipairs(allAnims) do
	createDropdownButton(animScroll, animData.Name, function()
		animSelectBtn.Text = "Anim: " .. animData.Name
		animScroll.Visible = false
		if animData.ID == "CUSTOM" then
			isCustomAnim = true
			selectedAnimId = ""
			animInput.Visible = true
		else
			isCustomAnim = false
			selectedAnimId = animData.ID
			animInput.Visible = false
		end
	end)
end

for _, emojiIcon in ipairs(allEmojis) do
	createDropdownButton(emojiScroll, emojiIcon, function()
		selectedEmoji = emojiIcon
		emojiSelectBtn.Text = "Emoji: " .. emojiIcon
		emojiScroll.Visible = false
	end)
end

local function toggleScroll(targetScroll)
	local wasVisible = targetScroll.Visible
	themeScroll.Visible = false
	animScroll.Visible = false
	emojiScroll.Visible = false
	targetScroll.Visible = not wasVisible
end

if themeSelectBtn then themeSelectBtn.MouseButton1Click:Connect(function() toggleScroll(themeScroll) end) end
if animSelectBtn then animSelectBtn.MouseButton1Click:Connect(function() toggleScroll(animScroll) end) end
if emojiSelectBtn then emojiSelectBtn.MouseButton1Click:Connect(function() toggleScroll(emojiScroll) end) end

if createBtn then
	local originalCreateText = createBtn.Text
	local originalCreateColor = createBtn.BackgroundColor3
	createBtn.MouseButton1Click:Connect(function()
		-- 🛠️ التعديل الثاني: التحقق بشكل صحيح إذا ما كان اللاعب هو المالك (البيانات ترجع كـ Boolean)
		if fetchedOwnerId == false then
			createBtn.Text = "Owner Only!"
			createBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
			task.wait(1.5)
			createBtn.Text = originalCreateText
			createBtn.BackgroundColor3 = originalCreateColor
			return
		end

		local eName = nameInput.Text
		local eMusic = musicInput.Text

		if eName == "" or selectedTheme == "" then
			createBtn.Text = "Name & Theme Required!"
			task.wait(2)
			createBtn.Text = originalCreateText
			return
		end

		eMusic = string.match(eMusic, "%d+") or ""
		local finalAnimId = isCustomAnim and (string.match(animInput.Text, "%d+") or "") or selectedAnimId

		local randomColors = {
			{R=255, G=80, B=80}, {R=80, G=255, B=150}, {R=80, G=150, B=255},
			{R=255, G=200, B=50}, {R=200, G=80, B=255}, {R=50, G=255, B=200}
		}
		local chosenColor = randomColors[math.random(1, #randomColors)]

		local newCustomEvent = {
			IsCustom = true,
			ID = "Custom_" .. tostring(math.random(1000,9999)),
			DisplayName = eName,
			MusicId = eMusic ~= "" and "rbxassetid://" .. eMusic or nil,
			AnimId = finalAnimId ~= "" and "rbxassetid://" .. finalAnimId or nil,
			Theme = selectedTheme,
			Color = chosenColor,
			Emoji = selectedEmoji ~= "" and selectedEmoji or "✨" 
		}

		adminEvent:FireServer("CreateCustomEvent", newCustomEvent)
		createBtn.Text = "Processing..."
	end)


end

clientEvent.OnClientEvent:Connect(function(action, data)
	if action == "SyncOwnerData" then
		fetchedOwnerId = data
	elseif action == "EventCreationResult" then
		if data.success then
			createBtn.Text = "Event Created!"
			createBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
			task.wait(2)
			createBtn.Text = "Create Event"
			createBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		else
			createBtn.Text = data.msg
			createBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
			task.wait(2.5)
			createBtn.Text = "Create Event"
			createBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		end
	end
end)