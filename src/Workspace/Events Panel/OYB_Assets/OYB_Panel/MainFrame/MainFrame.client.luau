local mainFrame = script.Parent
local oybEventFolder = game.ReplicatedStorage:WaitForChild("OYBEVENT")
local adminEvent = oybEventFolder:WaitForChild("OYB_AdminEvent")
local clientEvent = oybEventFolder:WaitForChild("OYB_ClientEvent")

local deleteBtn = mainFrame:WaitForChild("DeleteEventBtn", 5)
local deleteScroll = mainFrame:WaitForChild("DeleteScroll", 5)

if not deleteScroll then return end

if deleteBtn then
local isConfirmingGlobalDel = false
deleteBtn.TextScaled = true
deleteBtn.TextWrapped = true
deleteBtn.MouseButton1Click:Connect(function()
if not isConfirmingGlobalDel then
deleteScroll.Visible = not deleteScroll.Visible
end
end)
end

local function populateDeleteList(customEventsList)
local template = deleteScroll:FindFirstChild("Template")
for _, child in ipairs(deleteScroll:GetChildren()) do
if child ~= template and (child:IsA("TextButton") or child:IsA("TextLabel")) then
child:Destroy()
end
end
if not template then return end
if not customEventsList or #customEventsList == 0 then return end
for _, customData in ipairs(customEventsList) do
local btn = template:Clone()
btn.Name = customData.ID
btn.Text = "Trash " .. customData.DisplayName
btn.Visible = true
btn.Parent = deleteScroll
local isConfirming = false
local originalText = btn.Text
local ticket = 0
btn.MouseButton1Click:Connect(function()
if not isConfirming then
isConfirming = true
ticket = ticket + 1
local myTicket = ticket
btn.Text = "Sure?"
btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
task.delay(5, function()
if isConfirming and btn and btn.Parent and ticket == myTicket then
isConfirming = false
btn.Text = originalText
btn.BackgroundColor3 = template.BackgroundColor3
end
end)
else
adminEvent:FireServer("DeleteCustomEvent", customData.ID)
btn:Destroy()
end
end)
end
end

clientEvent.OnClientEvent:Connect(function(action, data)
if action == "SyncCustomEvents" then
populateDeleteList(data)
end
end)