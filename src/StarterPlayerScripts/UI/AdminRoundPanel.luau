--[=[
    ADMIN ROUND PANEL

    A small floating panel for controlling rounds by hand. It exists so the game can be
    tested alone — normally a round can't start until `MinimumFighters` players have
    loaded, which makes solo testing impossible.

      START ROUND   Force a round to begin, however few people are here.
      END ROUND     End the round that's running.
      SKIP          Skip the rest of the intermission.
      SOLO          Toggle the minimum player count between 1 and its configured value.

    WHO SEES IT
    -----------
    THE OWNER, AND NOBODY ELSE. The panel asks the server whether it should exist at all
    and hides itself entirely if the answer is no; the server answers from
    `OwnerPerks.CanUseControlPanels`, which is the owner list and nothing else.

    It used to also show for ServerOwner-rank admins and for every player in a Studio
    session. The rank check was `Rank < 20`, which Moderator (15) and Developer (18) both
    satisfy — and the shipped `CommonFunctions.AdminPerms` contains a Developer — so
    accounts that were never meant to start and end rounds could. To test this panel as
    another account now, add that account to `OwnerPerks.Owners` for as long as you need
    it, so the grant is written down rather than implied by the environment.

    That check is presentation, not security. Everything is re-validated server-side in
    `ServerScriptService/RemoteHandler/AdminRoundControl` before anything happens, because
    an exploiter can unhide a button in about a second.

    BUILT IN CODE
    -------------
    No Studio prefab to copy, deliberately. The engine's own ModPanel clones hand-built
    UI assets, which means adding a new control type to it needs work in Studio before any
    of it can be tested. This has no such dependency — restyle it from the `Style` table.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)

local LocalPlayer = Players.LocalPlayer

local AdminRoundPanel = {
    Enabled = true,
    UIInstance = nil,
    Allowed = false,
    Collapsed = false,
}

--- Restyle from here.
local Style = {
    Size = UDim2.fromScale(0.19, 0.30),
    Position = UDim2.fromScale(0.012, 0.30),
    Corner = UDim.new(0, 10),

    Colors = {
        Panel = Color3.fromRGB(20, 20, 26),
        Header = Color3.fromRGB(150, 24, 32),
        Button = Color3.fromRGB(44, 44, 56),
        ButtonHover = Color3.fromRGB(64, 64, 82),
        Danger = Color3.fromRGB(126, 30, 30),
        Good = Color3.fromRGB(30, 106, 58),
        Text = Color3.fromRGB(235, 235, 240),
        Dim = Color3.fromRGB(160, 160, 175),
    },

    Font = Enum.Font.GothamBold,
    BodyFont = Enum.Font.Gotham,
}

--- Key that shows/hides the whole thing, so it can be kept out of the way for screenshots.
local TOGGLE_KEY = Enum.KeyCode.F2

local Tween = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--- The buttons, in order. `Action` is the string the server dispatches on.
local Buttons = {
    {Label = "START ROUND", Action = "Start", Color = "Good"},
    {Label = "END ROUND", Action = "End", Color = "Danger"},
    {Label = "SKIP INTERMISSION", Action = "Skip", Color = "Button"},
    {Label = "TOGGLE SOLO MODE", Action = "Solo", Color = "Button"},
}

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

local function BuildUI(): Frame
    local Holder = Instance.new("Frame")
    Holder.Name = "AdminRoundPanel"
    Holder.Size = Style.Size
    Holder.Position = Style.Position
    Holder.BackgroundColor3 = Style.Colors.Panel
    Holder.BackgroundTransparency = 0.08
    Holder.BorderSizePixel = 0
    Holder.Visible = false

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = Style.Corner
    Corner.Parent = Holder

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Style.Colors.Header
    Stroke.Thickness = 2
    Stroke.Parent = Holder

    local Layout = Instance.new("UIListLayout")
    Layout.FillDirection = Enum.FillDirection.Vertical
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Padding = UDim.new(0, 4)
    Layout.Parent = Holder

    local Padding = Instance.new("UIPadding")
    Padding.PaddingTop = UDim.new(0, 6)
    Padding.PaddingBottom = UDim.new(0, 6)
    Padding.Parent = Holder

    -- Header
    local Header = Instance.new("TextLabel")
    Header.Name = "Header"
    Header.LayoutOrder = 0
    Header.Size = UDim2.fromScale(0.9, 0.13)
    Header.BackgroundTransparency = 1
    Header.Font = Style.Font
    Header.Text = "ROUND CONTROL"
    Header.TextColor3 = Style.Colors.Header
    Header.TextScaled = true
    Header.Parent = Holder

    -- Live status line
    local Status = Instance.new("TextLabel")
    Status.Name = "Status"
    Status.LayoutOrder = 1
    Status.Size = UDim2.fromScale(0.92, 0.11)
    Status.BackgroundTransparency = 1
    Status.Font = Style.BodyFont
    Status.Text = "…"
    Status.TextColor3 = Style.Colors.Dim
    Status.TextScaled = true
    Status.Parent = Holder

    for index, Spec in Buttons do
        local Button = Instance.new("TextButton")
        Button.Name = Spec.Action
        Button.LayoutOrder = index + 1
        Button.Size = UDim2.fromScale(0.9, 0.14)
        Button.BackgroundColor3 = Style.Colors[Spec.Color]
        Button.BorderSizePixel = 0
        Button.Font = Style.Font
        Button.Text = Spec.Label
        Button.TextColor3 = Style.Colors.Text
        Button.TextScaled = true
        Button.AutoButtonColor = false
        Button.Parent = Holder

        local BC = Instance.new("UICorner")
        BC.CornerRadius = UDim.new(0, 6)
        BC.Parent = Button

        local Base = Style.Colors[Spec.Color]
        Button.MouseEnter:Connect(function()
            TweenService:Create(Button, Tween, {BackgroundColor3 = Style.Colors.ButtonHover}):Play()
        end)
        Button.MouseLeave:Connect(function()
            TweenService:Create(Button, Tween, {BackgroundColor3 = Base}):Play()
        end)

        Button.Activated:Connect(function()
            task.spawn(AdminRoundPanel.Run, Spec.Action)
        end)
    end

    -- Result of the last action
    local Result = Instance.new("TextLabel")
    Result.Name = "Result"
    Result.LayoutOrder = #Buttons + 2
    Result.Size = UDim2.fromScale(0.92, 0.10)
    Result.BackgroundTransparency = 1
    Result.Font = Style.BodyFont
    Result.Text = "F2 hides this panel"
    Result.TextColor3 = Style.Colors.Dim
    Result.TextScaled = true
    Result.Parent = Holder

    return Holder
end

--------------------------------------------------------------------------------
-- BEHAVIOUR
--------------------------------------------------------------------------------

--- Sends an action to the server and shows whatever it says back.
function AdminRoundPanel.Run(action: string)
    local UI = AdminRoundPanel.UIInstance
    if not UI then
        return
    end

    local Success, Result = pcall(function()
        return Network:FireServerConnection("AdminRoundAction", "REMOTE_FUNCTION", action)
    end)

    if Success and typeof(Result) == "string" then
        UI.Result.Text = Result
    elseif not Success then
        UI.Result.Text = "Request failed — see Output"
        warn("[AdminRoundPanel] "..action.." failed: "..tostring(Result))
    end

    AdminRoundPanel.Refresh()
end

--- Pulls the live state and redraws the status line.
function AdminRoundPanel.Refresh()
    local UI = AdminRoundPanel.UIInstance
    if not UI then
        return
    end

    local Success, Status = pcall(function()
        return Network:FireServerConnection("AdminRoundStatus", "REMOTE_FUNCTION")
    end)

    -- A nil answer here is a dropped call, not a verdict — the panel already proved it was
    -- allowed to exist. Leave it alone and try again on the next refresh.
    if not Success or typeof(Status) ~= "table" then
        return
    end

    -- An explicit `Allowed = false` IS a verdict: permission was revoked. Take it away.
    if not Status.Allowed then
        AdminRoundPanel.Allowed = false
        UI.Visible = false
        return
    end

    if not Status.RoundsEnabled then
        UI.Status.Text = "Rounds are OFF (GameMode.UseRounds)"
        return
    end

    -- No clock during a last-one-standing round; "0s" there would look like a bug.
    local Clock = (Status.HasTimer == false and Status.State == "InRound")
        and "no timer"
        or (tostring(Status.TimeLeft).."s")

    UI.Status.Text = ("%s · %s · %d here · %d alive · min %d%s"):format(
        Status.State,
        Clock,
        Status.Loaded,
        Status.Alive,
        Status.Minimum,
        Status.SoloTest and " · SOLO" or ""
    )
end

function AdminRoundPanel.SetVisible(visible: boolean)
    local UI = AdminRoundPanel.UIInstance
    if not UI then
        return
    end

    UI.Visible = visible and AdminRoundPanel.Allowed and AdminRoundPanel.Enabled and not AdminRoundPanel.Collapsed
end

function AdminRoundPanel:Init()
    if RunService:IsServer() then
        return
    end

    --[[
        Ask first, build second. Most players will never be allowed to use this, and there
        is no reason for them to be carrying the UI around in their PlayerGui.

        Spawned because `SetConnection`/`FireServerConnection` yield until the remote
        exists, and `PlayerInitter` runs every module's `Init` in one blocking loop.
    ]]
    task.spawn(function()
        --[=[
            Keep asking until the server actually answers.

            `PlayerInitter` runs before the client waits for `ServerLoaded`, and
            `Network:FireServerConnection` returns nil — silently — when the remote doesn't
            exist on this client yet. A single attempt would therefore lose a race on a
            slow server and the panel would never appear at all.

            The server always answers with a table, so nil means "not ready", and
            `Allowed = false` means a real "no". Only the second one gives up.
        ]=]
        local Status
        local Deadline = time() + 30

        repeat
            local Success, Result = pcall(function()
                return Network:FireServerConnection("AdminRoundStatus", "REMOTE_FUNCTION")
            end)

            if Success and typeof(Result) == "table" then
                Status = Result
                break
            end

            task.wait(0.5)
        until time() > Deadline

        if not Status then
            warn("[AdminRoundPanel] The server never answered `AdminRoundStatus`. Is `ServerScriptService.RemoteHandler.AdminRoundControl` running?")
            return
        end

        if not Status.Allowed then
            -- A real "no". Nothing more to do; this player isn't an admin.
            return
        end

        AdminRoundPanel.Allowed = true

        local Parent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "Menus")
            or Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "TemporaryUI")

        if not Parent then
            warn("[AdminRoundPanel] Couldn't find a ScreenGui to parent to. The panel won't show.")
            return
        end

        AdminRoundPanel.UIInstance = BuildUI()
        AdminRoundPanel.UIInstance.Parent = Parent

        AdminRoundPanel.SetVisible(true)
        AdminRoundPanel.Refresh()

        UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
            if Processed or Input.KeyCode ~= TOGGLE_KEY then
                return
            end

            AdminRoundPanel.Collapsed = not AdminRoundPanel.Collapsed
            AdminRoundPanel.SetVisible(not AdminRoundPanel.Collapsed)
        end)

        -- Keeps the status line honest without needing the server to push anything.
        while AdminRoundPanel.UIInstance and AdminRoundPanel.UIInstance.Parent do
            task.wait(1)
            if AdminRoundPanel.UIInstance.Visible then
                AdminRoundPanel.Refresh()
            end
        end
    end)
end

return AdminRoundPanel
