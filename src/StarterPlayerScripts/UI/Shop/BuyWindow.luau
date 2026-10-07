--[=[
    BUY WINDOW — the "Purchase X for N$?" confirmation.

    WHY THIS FILE BUILDS ITS OWN UI
    -------------------------------
    THIS WAS THE BROKEN SHOP.

    The window was a Studio-authored `Frame` living as a child of this ModuleScript, and
    `BuyWindow.New` opened with `script:FindFirstChild("Window"):Clone()`. The frame is not
    in the repository — `ShopUI` and `Templates` were both exported to `.rbxmx` next to the
    shop script, and `Window` was missed. So in any place built from source, that line
    indexes `nil` and throws, which means:

        * clicking PURCHASE on a card did nothing at all;
        * `Shop.CreateBuyWindow` threw before assigning `Shop.BuyWindow`, so nothing was
          left in a recoverable state and no error reached the player;
        * nothing in the game could be bought.

    Shipping another `.rbxmx` would have fixed the symptom and left the cause: a menu that
    silently stops existing depending on which copy of the project you opened. So the window
    is built from code instead. It cannot go missing, it needs no asset, and if the Studio
    prefab IS present it is still preferred — so anyone who has styled it keeps their
    styling.

    IT ALSO EXPLAINS ITSELF NOW
    ---------------------------
    The old one printed "you're too poor." for every possible failure, because the server
    only ever returned a bare `false`. `BuyItem` now returns a reason, and this shows it:
    already owned, data not loaded and genuinely too poor are three different problems and
    only one of them is the player's fault.
]=]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Utils = require(ReplicatedStorage.Modules.Utils)
local Network = require(ReplicatedStorage.Modules.Network)
local Signal = require(ReplicatedStorage.Utils.Signal)

local BuyWindow = {}
BuyWindow.__index = BuyWindow

--- What the button says when the server refuses, by the reason it gave.
local REFUSALS = {
    TooPoor = "you're too poor.",
    AlreadyOwned = "you already own it!",
    NoData = "your data hasn't loaded yet.",
    InvalidItem = "that can't be bought.",
    NoPlayer = "something went wrong.",
}

--------------------------------------------------------------------------------
-- THE FRAME
--------------------------------------------------------------------------------

--[=[
    Builds the confirmation window from scratch.

    Deliberately matches the structure the rest of this file expects —
    `PriceTag`, `Buy.Button`, `Buy.TextLabel`, `Cancel.Button`, `Cancel.TextLabel` — so the
    code below neither knows nor cares whether it got the Studio prefab or this.
]=]
local function BuildWindow(): Frame
    local Window = Instance.new("Frame")
    Window.Name = "Window"
    Window.AnchorPoint = Vector2.new(0.5, 0.5)
    Window.Position = UDim2.fromScale(0.5, 0.5)
    Window.Size = UDim2.fromScale(0.253, 0.202)
    Window.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    Window.BorderSizePixel = 0
    -- Above the cards and the side panel, which are plain children of the shop frame.
    Window.ZIndex = 50
    Window.ClipsDescendants = true

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Window

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(95, 95, 110)
    Stroke.Thickness = 2
    Stroke.Parent = Window

    local Padding = Instance.new("UIPadding")
    Padding.PaddingTop = UDim.new(0, 14)
    Padding.PaddingBottom = UDim.new(0, 14)
    Padding.PaddingLeft = UDim.new(0, 14)
    Padding.PaddingRight = UDim.new(0, 14)
    Padding.Parent = Window

    local PriceTag = Instance.new("TextLabel")
    PriceTag.Name = "PriceTag"
    PriceTag.Size = UDim2.fromScale(1, 0.5)
    PriceTag.BackgroundTransparency = 1
    PriceTag.Font = Enum.Font.GothamMedium
    PriceTag.Text = "Purchase?"
    PriceTag.TextColor3 = Color3.fromRGB(255, 255, 255)
    PriceTag.TextScaled = true
    PriceTag.TextWrapped = true
    PriceTag.Parent = Window

    local Constraint = Instance.new("UITextSizeConstraint")
    Constraint.MaxTextSize = 22
    Constraint.Parent = PriceTag

    --[=[
        One button.

        Both buttons want the same shape and differ only in colour, position and label, so
        building them from one closure keeps them identical and halves the chance of the
        two drifting apart when somebody restyles one of them.
    ]=]
    local function MakeButton(name: string, label: string, colour: Color3, xScale: number): Frame
        local Holder = Instance.new("Frame")
        Holder.Name = name
        Holder.Size = UDim2.fromScale(0.46, 0.34)
        Holder.Position = UDim2.fromScale(xScale, 0.62)
        Holder.BackgroundColor3 = colour
        Holder.BorderSizePixel = 0
        Holder.Parent = Window

        local HolderCorner = Instance.new("UICorner")
        HolderCorner.CornerRadius = UDim.new(0, 7)
        HolderCorner.Parent = Holder

        local Text = Instance.new("TextLabel")
        Text.Name = "TextLabel"
        Text.Size = UDim2.fromScale(1, 1)
        Text.BackgroundTransparency = 1
        Text.Font = Enum.Font.GothamBold
        Text.Text = label
        Text.TextColor3 = Color3.fromRGB(255, 255, 255)
        Text.TextScaled = true
        Text.Parent = Holder

        local TextConstraint = Instance.new("UITextSizeConstraint")
        TextConstraint.MaxTextSize = 18
        TextConstraint.Parent = Text

        -- A transparent button over the whole holder, rather than making the holder itself
        -- a TextButton: the prefab is laid out this way and the click handlers below look
        -- for `Buy.Button`, so matching it keeps one code path for both sources.
        local Button = Instance.new("TextButton")
        Button.Name = "Button"
        Button.Size = UDim2.fromScale(1, 1)
        Button.BackgroundTransparency = 1
        Button.Text = ""
        Button.Parent = Holder

        return Holder
    end

    MakeButton("Buy", "BUY", Color3.fromRGB(45, 130, 70), 0.02)
    MakeButton("Cancel", "CANCEL", Color3.fromRGB(120, 45, 45), 0.52)

    return Window
end

--[=[
    The Studio prefab if there is one, otherwise a built one.

    Preferring the prefab means this change is invisible to anyone whose place already has
    the styled window, and the fallback means the shop works for everyone else.
]=]
local function GetWindowTemplate(): Frame
    local Prefab = script:FindFirstChild("Window")

    if Prefab and Prefab:IsA("GuiObject") then
        return Prefab:Clone() :: Frame
    end

    return BuildWindow()
end

--------------------------------------------------------------------------------
-- THE WINDOW
--------------------------------------------------------------------------------

function BuyWindow.New(Shop, Module: ModuleScript, skin: boolean?, Parent: Frame, Card)
    local Window = setmetatable({
        Checking = false,
        Instance = GetWindowTemplate(),
        Connections = {},
        Removed = Signal.new(),
        Purchased = Signal.new(),
    }, BuyWindow)

    if skin == nil then
        skin = false
    end

    local CharInfo = require(Module)
    -- Emote modules keep their fields at the top level rather than under `Config`.
    local Config = CharInfo.Config or CharInfo

    Window.Instance.PriceTag.Text = "Purchase "..tostring(Config.Name or Module.Name)
        .." for "..((tonumber(Config.Price) or 0) > 0 and tostring(Config.Price).."$" or "FREE").."?"

    Window.Instance.Parent = Parent
    Window.Instance.Size = Utils.UDim.Zero

    table.insert(Window.Connections, Window.Instance.Buy.Button.MouseButton1Click:Connect(function()
        if Window.Checking then
            return
        end
        Window.Checking = true
        Window.Instance.Buy.TextLabel.Text = "..."

        local Success, Reason = Network:FireServerConnection("BuyItem", "REMOTE_FUNCTION", Module)

        if Success then
            Window.Instance.Buy.TextLabel.Text = "Purchased!"

            --[[
                Marking the card owned here is a presentation shortcut, and it's guarded
                now: the inventory passes a card and the shop passes a card, but a future
                caller might not, and a nil index in a purchase confirmation would leave the
                player looking at a window that says "..." forever.

                `Shop.ReloadContent` re-reads ownership from the real data a moment later
                through the `Purchased` signal, so this is only about the badge appearing
                instantly rather than a frame later.
            ]]
            if Card and Card.Container and Card.Container:FindFirstChild("Owned") then
                Card.Container.Owned.BackgroundTransparency = 0.55
                Card.Container.Owned.TextLabel.TextTransparency = 0
            end

            Window.Purchased:Fire()

            table.insert(Window.Connections, task.delay(0.75, function()
                Window:Hide()
            end))
        else
            -- The server says WHY now, so say which it was.
            Window.Instance.Buy.TextLabel.Text = REFUSALS[Reason] or "couldn't buy that."

            --[[
                `AlreadyOwned` is not a retryable state, so there is no point re-arming the
                button — and it means the shop's own view of ownership was stale, which the
                signal fixes. Everything else is worth another click.
            ]]
            if Reason == "AlreadyOwned" then
                Window.Purchased:Fire()
                table.insert(Window.Connections, task.delay(1.2, function()
                    Window:Hide()
                end))
            else
                Window.Checking = false
            end
        end
    end))

    table.insert(Window.Connections, Window.Instance.Cancel.Button.MouseButton1Click:Connect(function()
        if Window.Checking then
            return
        end
        Window:Hide()
    end))

    Window:Show()

    return Window
end

function BuyWindow:Show()
    TweenService:Create(self.Instance, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.253, 0.202)}):Play()
end

function BuyWindow:Hide(instant: boolean?)
    if instant == nil then
        instant = false
    end

    self.Removed:Fire()
    self.Removed:DisconnectAll()
    self.Purchased:DisconnectAll()

    for _, connection in self.Connections do
        if typeof(connection) == "thread" then
            if coroutine.status(connection :: thread) ~= "running" then
                task.cancel(connection)
            end
        else
            connection:Disconnect()
        end
    end
    table.clear(self.Connections)

    if not instant then
        TweenService:Create(self.Instance, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        self.Instance.Size = Utils.UDim.Zero
    end

    Debris:AddItem(self.Instance, 0.5)
end

return BuyWindow
