--[=[
    ARENA FEED

    The little stack of announcements at the top of the screen during a match:
    killstreaks, people dropping in, Sudden Death, and the final result.

    Like the PLAY button this is built from code rather than cloned from a Studio
    prefab, so it works on a fresh clone of the repo with nothing to set up.

    The server pushes text through the `ArenaAnnouncement` remote — see
    `RoundManager.Utils.Broadcast()`.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)
local GameMode = require(ReplicatedStorage.Modules.GameMode)

local LocalPlayer = Players.LocalPlayer

local Style = {
    --- Where the stack sits. Top-centre, under the round timer.
    Position = UDim2.fromScale(0.5, 0.12),
    Size = UDim2.fromScale(0.5, 0.24),
    EntryHeight = UDim2.fromScale(1, 0.2),

    Font = Enum.Font.GothamBold,
    TextColor = Color3.fromRGB(255, 255, 255),
    StrokeColor = Color3.fromRGB(10, 10, 12),

    --- How long a message stays before it fades out.
    Lifetime = 4,
    FadeTime = 0.45,
    --- Oldest messages get dropped past this many on screen.
    MaxEntries = 4,
}

local ArenaFeed = {
    Enabled = true,
    UIInstance = nil,
    Entries = {},
}

local function BuildUI(): Frame
    local Holder = Instance.new("Frame")
    Holder.Name = "ArenaFeed"
    Holder.AnchorPoint = Vector2.new(0.5, 0)
    Holder.Position = Style.Position
    Holder.Size = Style.Size
    Holder.BackgroundTransparency = 1
    -- Purely informational, so it must never eat clicks meant for the game.
    Holder.Active = false

    local Layout = Instance.new("UIListLayout")
    Layout.FillDirection = Enum.FillDirection.Vertical
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Layout.VerticalAlignment = Enum.VerticalAlignment.Top
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Padding = UDim.new(0.02, 0)
    Layout.Parent = Holder

    return Holder
end

--- Drops a message onto the stack. It fades itself out and cleans itself up.
function ArenaFeed.Push(text: string, color: Color3?)
    if not ArenaFeed.UIInstance or not ArenaFeed.Enabled or typeof(text) ~= "string" then
        return
    end

    -- Trim the oldest entries so a burst of kills can't fill the screen.
    while #ArenaFeed.Entries >= Style.MaxEntries do
        local Oldest = table.remove(ArenaFeed.Entries, 1)
        if Oldest and Oldest.Parent then
            Oldest:Destroy()
        end
    end

    local Label = Instance.new("TextLabel")
    Label.Name = "Announcement"
    Label.Size = Style.EntryHeight
    Label.BackgroundTransparency = 1
    Label.Font = Style.Font
    Label.Text = text
    Label.TextColor3 = color or Style.TextColor
    Label.TextScaled = true
    Label.TextTransparency = 1
    -- Newer messages sort below older ones so the list reads top-to-bottom in order.
    Label.LayoutOrder = time() // 1
    Label.Parent = ArenaFeed.UIInstance

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Style.StrokeColor
    Stroke.Thickness = 2
    Stroke.Transparency = 1
    Stroke.Parent = Label

    table.insert(ArenaFeed.Entries, Label)

    local FadeIn = TweenInfo.new(Style.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(Label, FadeIn, {TextTransparency = 0}):Play()
    TweenService:Create(Stroke, FadeIn, {Transparency = 0}):Play()

    task.delay(Style.Lifetime, function()
        if not Label or not Label.Parent then
            return
        end

        local FadeOut = TweenInfo.new(Style.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        TweenService:Create(Label, FadeOut, {TextTransparency = 1}):Play()
        TweenService:Create(Stroke, FadeOut, {Transparency = 1}):Play()

        task.delay(Style.FadeTime, function()
            local Index = table.find(ArenaFeed.Entries, Label)
            if Index then
                table.remove(ArenaFeed.Entries, Index)
            end

            if Label and Label.Parent then
                Label:Destroy()
            end
        end)
    end)
end

function ArenaFeed:Init()
    if RunService:IsServer() or not GameMode.Enabled then
        return
    end

    local Parent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "TemporaryUI")
        or Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "Menus")

    if not Parent then
        warn("[ArenaFeed:Init()] Couldn't find a ScreenGui to parent to (looked for `TemporaryUI` and `Menus` in PlayerGui). Announcements won't show up.")
        return
    end

    if ArenaFeed.UIInstance then
        ArenaFeed.UIInstance.Parent = Parent
    else
        ArenaFeed.UIInstance = BuildUI()
        ArenaFeed.UIInstance.Parent = Parent
    end

    Network:SetConnection("ArenaAnnouncement", "REMOTE_EVENT", function(text: string)
        ArenaFeed.Push(text)
    end)
end

return ArenaFeed
