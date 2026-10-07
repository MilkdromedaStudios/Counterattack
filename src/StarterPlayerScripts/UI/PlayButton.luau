--[=[
    THE BIG PLAY BUTTON

    Sits in the middle-bottom of the lobby screen. Pressing it drops you into the arena:
    if a match is already running you're teleported straight into the fight, and if one
    isn't, you queue up and the match fires the moment enough fighters are ready.

    This whole UI is built from code on purpose. Every other menu in the engine clones a
    prefab that has to be authored by hand in Roblox Studio, which means a fresh clone of
    the repo has a broken menu until somebody rebuilds it. This one just works — restyle
    it by editing the `Style` table below, or swap in your own frame by pointing
    `PlayButton.UIInstance` at it before `Init()` runs.

    It hides itself the moment you stop being a Spectator (i.e. the moment you're
    actually in the arena) and comes back when you return to the lobby.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)
local GameMode = require(ReplicatedStorage.Modules.GameMode)

local LocalPlayer = Players.LocalPlayer
local RoundState: StringValue = ReplicatedStorage.RoundInfo.CurrentState

--- Everything visual lives here so the look can be retuned without touching the logic.
local Style = {
    Size = UDim2.fromScale(0.26, 0.13),
    --- Anchored to the bottom centre, lifted clear of the chat bar and the ability row.
    Position = UDim2.fromScale(0.5, 0.86),
    MinimumSize = Vector2.new(240, 74),

    Colors = {
        Idle = Color3.fromRGB(168, 22, 30),
        Hover = Color3.fromRGB(214, 38, 46),
        -- Spare accents, unused by the three live states but kept for restyling.
        Accent = Color3.fromRGB(196, 132, 24),
        Positive = Color3.fromRGB(28, 148, 74),
        Disabled = Color3.fromRGB(62, 62, 68),
        Text = Color3.fromRGB(255, 255, 255),
        Stroke = Color3.fromRGB(12, 12, 14),
    },

    Font = Enum.Font.GothamBlack,
    SubFont = Enum.Font.GothamMedium,

    HoverScale = 1.06,
    PressScale = 0.95,
    TweenTime = 0.18,
}

local Tween = TweenInfo.new(Style.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local PlayButton = {
    Enabled = true,
    UIInstance = nil,
    --- Set while a join request is in flight so double clicks can't stack requests.
    Requesting = false,
    --- Mirrors the server's view of things. Refreshed on state changes.
    Status = {
        --- Whether the arena map is up. If it isn't, PLAY can't do anything.
        ArenaOpen = true,
        --- Seconds left on this player's respawn cooldown.
        RespawnWait = 0,
        --- Whether they're already in the arena.
        Fighting = false,
    },
}

--------------------------------------------------------------------------------
-- UI CONSTRUCTION
--------------------------------------------------------------------------------

local function BuildUI(): Frame
    local Holder = Instance.new("Frame")
    Holder.Name = "PlayButton"
    Holder.AnchorPoint = Vector2.new(0.5, 0.5)
    Holder.Position = Style.Position
    Holder.Size = Style.Size
    Holder.BackgroundTransparency = 1
    Holder.Visible = false

    local Ratio = Instance.new("UIAspectRatioConstraint")
    Ratio.AspectRatio = 3.4
    Ratio.DominantAxis = Enum.DominantAxis.Width
    Ratio.Parent = Holder

    local SizeClamp = Instance.new("UISizeConstraint")
    SizeClamp.MinSize = Style.MinimumSize
    SizeClamp.Parent = Holder

    -- The button itself lives inside the holder so hover scaling doesn't fight the
    -- anchor/aspect constraints on the holder.
    local Button = Instance.new("TextButton")
    Button.Name = "Button"
    Button.AnchorPoint = Vector2.new(0.5, 0.5)
    Button.Position = UDim2.fromScale(0.5, 0.5)
    Button.Size = UDim2.fromScale(1, 1)
    Button.BackgroundColor3 = Style.Colors.Idle
    Button.AutoButtonColor = false
    Button.Text = ""
    Button.Parent = Holder

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0.14, 0)
    Corner.Parent = Button

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Style.Colors.Stroke
    Stroke.Thickness = 3
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Parent = Button

    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(178, 178, 178)),
    })
    Gradient.Rotation = 90
    Gradient.Parent = Button

    local Layout = Instance.new("UIListLayout")
    Layout.FillDirection = Enum.FillDirection.Vertical
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Layout.VerticalAlignment = Enum.VerticalAlignment.Center
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Button

    local Label = Instance.new("TextLabel")
    Label.Name = "Label"
    Label.LayoutOrder = 1
    Label.Size = UDim2.fromScale(0.9, 0.5)
    Label.BackgroundTransparency = 1
    Label.Font = Style.Font
    Label.Text = "PLAY"
    Label.TextColor3 = Style.Colors.Text
    Label.TextScaled = true
    Label.Parent = Button

    local LabelStroke = Instance.new("UIStroke")
    LabelStroke.Color = Style.Colors.Stroke
    LabelStroke.Thickness = 2
    LabelStroke.Parent = Label

    local SubLabel = Instance.new("TextLabel")
    SubLabel.Name = "SubLabel"
    SubLabel.LayoutOrder = 2
    SubLabel.Size = UDim2.fromScale(0.9, 0.24)
    SubLabel.BackgroundTransparency = 1
    SubLabel.Font = Style.SubFont
    SubLabel.Text = GameMode.Name
    SubLabel.TextColor3 = Style.Colors.Text
    SubLabel.TextTransparency = 0.25
    SubLabel.TextScaled = true
    SubLabel.Parent = Button

    return Holder
end

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

--- Pulls the current queue state from the server.
function PlayButton.Refresh()
    if not PlayButton.UIInstance then
        return
    end

    local Success, Result = pcall(function()
        return Network:FireServerConnection("GetMatchStatus", "REMOTE_FUNCTION")
    end)

    if Success and typeof(Result) == "table" then
        PlayButton.Status = Result
    end

    PlayButton.UpdateVisuals()
end

--- Recolours and relabels the button to match whatever the server last told us.
function PlayButton.UpdateVisuals()
    local UI = PlayButton.UIInstance
    if not UI then
        return
    end

    local Button: TextButton = UI.Button
    local Label: TextLabel = Button.Label
    local SubLabel: TextLabel = Button.SubLabel

    local Status = PlayButton.Status
    local Color = Style.Colors.Idle

    -- Three states, and only one of them stops you playing. There's no queue to sit in
    -- and no match to wait for — the arena is always open.
    if Status.RespawnWait and Status.RespawnWait > 0 then
        Label.Text = "WAIT"
        SubLabel.Text = string.format("back in %d…", math.ceil(Status.RespawnWait))
        Color = Style.Colors.Disabled

    elseif Status.ArenaOpen == false then
        Label.Text = "CLOSED"
        SubLabel.Text = "no arena map — check the Output window"
        Color = Style.Colors.Disabled

    else
        Label.Text = "PLAY"
        SubLabel.Text = GameMode.Name
        Color = Style.Colors.Idle
    end

    TweenService:Create(Button, Tween, {BackgroundColor3 = Color}):Play()
end

--- Shows or hides the button. It's only ever visible while sitting in the lobby.
function PlayButton.SetVisible(visible: boolean)
    local UI = PlayButton.UIInstance
    if not UI then
        return
    end

    UI.Visible = visible and PlayButton.Enabled

    if UI.Visible then
        PlayButton.Refresh()
    end
end

--------------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------------

--- Fired when the player actually clicks. Asks the server, then reports back.
function PlayButton.Activate()
    if PlayButton.Requesting or not PlayButton.UIInstance or not PlayButton.UIInstance.Visible then
        return
    end

    PlayButton.Requesting = true
    Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.9})

    local Success, Result, Detail = pcall(function()
        return Network:FireServerConnection("RequestJoinMatch", "REMOTE_FUNCTION")
    end)

    PlayButton.Requesting = false

    if not Success then
        warn("[PlayButton.Activate()] Join request failed:", Result)
        return
    end

    --[[
        `Network:FireServerConnection` returns nothing at all — silently — if the remote
        instance doesn't exist on this client yet. Without this the button would just
        quietly do nothing forever, which is the single most confusing failure this UI
        can have.
    ]]
    if Result == nil then
        warn(
            "[PlayButton.Activate()] The server didn't answer. The `RequestJoinMatch` RemoteFunction is "..
            "missing on this client, so `Network:FireServerConnection` returned nothing. Check that "..
            "`ServerScriptService.RemoteHandler.RequestJoinMatch` ran on the server."
        )
        PlayButton.Flash("NO ANSWER — SEE OUTPUT")
        return
    end

    print("[PlayButton] Server answered:", Result, Detail)

    PlayButton.OnJoinResult(Result, Detail)
end

--- Turns the server's status string into feedback on the button.
function PlayButton.OnJoinResult(result: string, detail: any?)
    local Status = PlayButton.Status

    if result == "Joined" then
        -- We're in the arena. The character swap will hide the button on its own.
        Status.Fighting = true
        PlayButton.SetVisible(false)
        return
    end

    if result == "OnCooldown" then
        Status.RespawnWait = tonumber(detail) or GameMode.Config.RespawnCooldown
        PlayButton.StartCooldownCountdown()

    elseif result == "AlreadyFighting" then
        PlayButton.SetVisible(false)
        return

    elseif result == "NoArena" then
        Status.ArenaOpen = false
        PlayButton.Flash("NO ARENA MAP")

    elseif result == "NoSpawnPoints" then
        -- The map is up but has nowhere to put anybody. Say so on the button rather than
        -- letting the player press PLAY over and over with nothing appearing to happen —
        -- the Output window has the full explanation.
        PlayButton.Flash("MAP HAS NO SPAWNS")

    elseif result == "SetupFailed" then
        PlayButton.Flash("SPAWN FAILED — SEE OUTPUT")

    elseif result == "NotLoaded" then
        PlayButton.Flash("STILL LOADING…")
        return

    elseif result == "ModeDisabled" or result == "Rejected" then
        return
    end

    PlayButton.UpdateVisuals()
end

--- Briefly overrides the sub-label with a one-off message.
function PlayButton.Flash(text: string)
    local UI = PlayButton.UIInstance
    if not UI then
        return
    end

    local SubLabel: TextLabel = UI.Button.SubLabel
    SubLabel.Text = text

    task.delay(1.6, function()
        if PlayButton.UIInstance then
            PlayButton.UpdateVisuals()
        end
    end)
end

--- Ticks the respawn cooldown down on the label so the wait is visible.
function PlayButton.StartCooldownCountdown()
    if PlayButton._CooldownThread then
        task.cancel(PlayButton._CooldownThread)
    end

    PlayButton._CooldownThread = task.spawn(function()
        while PlayButton.Status.RespawnWait and PlayButton.Status.RespawnWait > 0 do
            PlayButton.UpdateVisuals()
            PlayButton.Status.RespawnWait -= task.wait(0.25)
        end

        PlayButton.Status.RespawnWait = 0
        PlayButton._CooldownThread = nil
        PlayButton.UpdateVisuals()
    end)
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------

function PlayButton:Init()
    --[=[
        There is no PLAY button in Counterattack. Rounds start on their own when the
        intermission runs out and everybody goes in together, so a button to join would
        have nothing to do.

        The whole UI is left intact behind `GameMode.UseRounds` — flip that to `false` and
        the open-arena mode, and this button with it, come straight back.
    ]=]
    if RunService:IsServer() or not GameMode.Enabled or GameMode.UseRounds then
        return
    end

    -- Reuse whatever's already there on a respawn instead of stacking copies.
    local Parent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "Menus")
        or Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "TemporaryUI")

    if not Parent then
        warn("[PlayButton:Init()] Couldn't find a ScreenGui to parent to (looked for `Menus` and `TemporaryUI` in PlayerGui). The play button won't show up.")
        return
    end

    if PlayButton.UIInstance then
        PlayButton.UIInstance.Parent = Parent
    else
        PlayButton.UIInstance = BuildUI()
        PlayButton.UIInstance.Parent = Parent

        local Button: TextButton = PlayButton.UIInstance.Button
        local BaseSize = Button.Size

        Button.MouseEnter:Connect(function()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.25})
            TweenService:Create(Button, Tween, {
                Size = UDim2.fromScale(BaseSize.X.Scale * Style.HoverScale, BaseSize.Y.Scale * Style.HoverScale),
            }):Play()
        end)

        Button.MouseLeave:Connect(function()
            TweenService:Create(Button, Tween, {Size = BaseSize}):Play()
        end)

        Button.MouseButton1Down:Connect(function()
            TweenService:Create(Button, Tween, {
                Size = UDim2.fromScale(BaseSize.X.Scale * Style.PressScale, BaseSize.Y.Scale * Style.PressScale),
            }):Play()
        end)

        Button.MouseButton1Up:Connect(function()
            TweenService:Create(Button, Tween, {Size = BaseSize}):Play()
        end)

        Button.Activated:Connect(function()
            task.spawn(PlayButton.Activate)
        end)
    end

    -- Visible only while spectating in the lobby.
    Utils.Character.ObserveCharacter(LocalPlayer, function(Char: Model)
        local Role = Char:FindFirstChild("Role")
        PlayButton.SetVisible(Role ~= nil and Role.Value == "Spectator")
    end)

    --[=[
        WATCHDOG

        `ObserveCharacter` above is the primary driver, but it runs through
        `WaitForCharacterLoaded`, which yields until the character has a `PrimaryPart`, a
        `Humanoid` and an `Animator`. A rig missing any of those never fires the callback
        at all — so if a spawn half-succeeds and then gets bounced back to the lobby, the
        button would stay hidden forever and the only way out is rejoining the server.

        This is the escape hatch: whatever else happened, if you are standing in the lobby
        as a Spectator then the button belongs on screen. Cheap enough to run twice a
        second, and it does nothing at all unless the visibility is actually wrong.
    ]=]
    task.spawn(function()
        while true do
            task.wait(0.5)

            local UI = PlayButton.UIInstance
            if UI and PlayButton.Enabled and not PlayButton.Requesting then
                local Char = LocalPlayer.Character
                local Role = Char and Char:FindFirstChild("Role")
                local ShouldShow = Role ~= nil and Role.Value == "Spectator"

                if ShouldShow ~= UI.Visible then
                    PlayButton.SetVisible(ShouldShow)
                end
            end
        end
    end)

    -- A match starting or ending changes what the button should say.
    Utils.Instance.ObserveProperty(RoundState, "Value", function()
        PlayButton.Refresh()
    end)

    -- The server can force a refresh (someone else queued up, match filled, etc.).
    Network:SetConnection("MatchStatusChanged", "REMOTE_EVENT", function()
        PlayButton.Refresh()
    end)
end

--- Lets other menus hide the button while they're open, matching the SideBar pattern.
function PlayButton.Toggle(toggle: boolean)
    PlayButton.Enabled = toggle
    if PlayButton.UIInstance then
        PlayButton.UIInstance.Visible = toggle and PlayButton.UIInstance.Visible
    end
end

return PlayButton
