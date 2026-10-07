local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Utils = require(ReplicatedStorage.Modules.Utils)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local LocalPlayer = Players.LocalPlayer

local SideBar = {
    Enabled = true,
    ToggleDuration = 0.5,
    MenuModules = {},
}

type Button = {
    Render: string,
    Type: "Button" | "SmallButton",
    InvertedRender: string?,
    MenuModule: any,
    LayoutOrder: number,
    CloseOnOtherOpen: boolean,
    CloseOthersOnOpen: boolean,
}

local InvertedInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local UI
local BarButtonPrefabs = {
    Button = Utils.Instance.FindFirstChild(script, "Button"),
    SmallButton = Utils.Instance.FindFirstChild(script, "SmallButton"),
}

local function TweenInverted(BarButton, Inverted: boolean)
    for _, Child in BarButton:GetChildren() do
        if #Child:GetChildren() > 0 then
            TweenInverted(Child, Inverted)
        end

        if Child:IsA("TextLabel") then
            local Value = Inverted and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
            TweenService:Create(Child, InvertedInfo, {TextColor3 = Value}):Play()
        elseif Child:IsA("ImageLabel") or Child:IsA("ImageButton") then
            local Value = not Inverted and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
            local Transp = 0
            if Child.Name:lower():find("inverted") then
                Transp = Inverted and 0 or 1
            elseif Child.Parent.Name ~= "Holder" then
                continue
            end

            TweenService:Create(Child, InvertedInfo, {ImageTransparency = Transp, BackgroundColor3 = Value}):Play()
        end
    end
end

function SideBar.Toggle(visible: boolean)
    UI.Visible = visible
    SideBar.Enabled = visible

    for _, m in SideBar.MenuModules do
        if not m.Button then
            continue
        end
        TweenInverted(m.Button, false)
    end
end

function SideBar.CloseAll(Remaining: any)
    for _, menu in SideBar.MenuModules do
        if menu == Remaining or not menu.CloseOnOtherOpen or not menu.UIInstance then continue end
        if menu.Opened then
            menu.Close(SideBar.ToggleDuration)
            if not menu.Button then
                continue
            end
            TweenInverted(menu.Button, false)
        end
    end
end

function SideBar.OpenMenu(Menu)
    Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})
    if not Menu.Opened then
        if Menu.Open(SideBar.ToggleDuration) == "Prevented" then
            return
        end
        if Menu.Button then
            TweenInverted(Menu.Button, true)
        end
        if Menu.CloseOthersOnOpen then
            SideBar.CloseAll(Menu)
        end
    else
        Menu.Close(SideBar.ToggleDuration)
        if Menu.Button then
            TweenInverted(Menu.Button, false)
        end
    end
end

function SideBar:Init()
    UI = Utils.Instance.FindFirstChild(script, "SideBarUI"):Clone()
    UI.Parent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "SideBar")

    local MoneyLabel = UI.Money.CurrentBalance

    --[=[
        The money label waits for the save data instead of assuming it.

        `GetPlayerStat` gives up after five seconds and returns `nil`, and `nil.Value`
        THREW — taking the whole of `SideBar:Init` with it, which means no sidebar at all
        and therefore no shop, no inventory, no settings. A player joining a server that
        was slow to answer a DataStore call got a game with no menus in it and no
        explanation.

        `PlayerData` is parented onto the player by `SaveManager` after that call returns,
        so the honest fix is to keep looking rather than to fail. The label shows a dash
        until the number arrives.
    ]=]
    MoneyLabel.Text = "— $"

    task.spawn(function()
        local Cash

        while not Cash do
            Cash = Utils.PlayerData.GetPlayerStat(LocalPlayer, "Currency.Money", false)
            if not Cash then
                task.wait(1)
            end
        end

        MoneyLabel.Text = tostring(Cash.Value).." $"
        Cash.Changed:Connect(function(value: number)
            MoneyLabel.Text = tostring(value).." $"
        end)
    end)

    local ButtonContainer = UI.Buttons

    local PlayerUIModules = LocalPlayer.PlayerScripts.UI

    local Buttons: {[string]: Button} = {
        Shop = {
            Render = "rbxassetid://140391842164127",
            Type = "Button",
            InvertedRender = "rbxassetid://106935872381429",
            MenuModule = PlayerUIModules.Shop,
            LayoutOrder = 0,
            CloseOnOtherOpen = true,
            CloseOthersOnOpen = true,
        },
        Inventory = {
            Render = "rbxassetid://124486892591913",
            Type = "Button",
            InvertedRender = "rbxassetid://97795375278271",
            MenuModule = PlayerUIModules.Inventory,
            LayoutOrder = 1,
            CloseOnOtherOpen = true,
            CloseOthersOnOpen = true,
        },
        Achievements = {
            Render = "rbxassetid://113899511427023",
            Type = "Button",
            InvertedRender = "rbxassetid://70778277265275",
            MenuModule = PlayerUIModules.AchievementsMenu,
            LayoutOrder = 2,
            CloseOnOtherOpen = true,
            CloseOthersOnOpen = true,
        },
        Stats = {
            Render = "rbxassetid://130488549713780",
            Type = "Button",
            InvertedRender = "rbxassetid://72911514685580",
            MenuModule = PlayerUIModules.StatsMenu,
            LayoutOrder = 3,
            CloseOnOtherOpen = true,
            CloseOthersOnOpen = true,
        },
        Spectate = {
            Render = "rbxassetid://89862280432932",
            Type = "Button",
            InvertedRender = "rbxassetid://134398825115015",
            MenuModule = PlayerUIModules.Spectate,
            LayoutOrder = 4,
            CloseOnOtherOpen = false,
            CloseOthersOnOpen = false,
        },
        Settings = {
            Render = "rbxassetid://95524701319726",
            Type = "Button",
            InvertedRender = "rbxassetid://113951492478970",
            MenuModule = PlayerUIModules.Settings,
            LayoutOrder = 5,
            CloseOnOtherOpen = true,
            CloseOthersOnOpen = true,
        },
        Credits = {
            Render = "rbxassetid://82434587437333",
            Type = "Button",
            InvertedRender = "rbxassetid://113410904986274",
            MenuModule = PlayerUIModules.Credits,
            LayoutOrder = 6,
            CloseOnOtherOpen = true,
            CloseOthersOnOpen = true,
        },
        Rules = {
            Render = "rbxassetid://83147016587963",
            Type = "SmallButton",
            InvertedRender = "rbxassetid://90249013398230",
            MenuModule = PlayerUIModules.RulesMenu,
            LayoutOrder = 7,
            CloseOnOtherOpen = true,
            CloseOthersOnOpen = true,
        },
        Changelog = {
            Render = "rbxassetid://82434587437333",
            Type = "SmallButton",
            InvertedRender = "rbxassetid://113410904986274",
            MenuModule = PlayerUIModules.Changelog,
            LayoutOrder = 8,
            CloseOnOtherOpen = true,
            CloseOthersOnOpen = true,
        },
    }

    for name, button: Button in Buttons do
        --[=[
            ONE BROKEN MENU MUST NOT COST THE WHOLE SIDEBAR.

            This was a bare `require`. `Buttons` is a dictionary, so the iteration order is
            arbitrary — and a module that throws while loading took the loop down with it,
            leaving however many buttons happened to come first and none of the rest. The
            `ObserveCharacter` hook at the bottom of `Init` never ran either, so the bar
            didn't hide itself during rounds.

            That is not hypothetical: `UI.Shop` had a malformed string literal in it, so
            `require` threw a syntax error, and the shop button plus everything after it in
            the iteration simply never appeared. The syntax error is fixed, but a menu that
            fails to load should degrade to a missing button rather than a missing menu bar.
        ]=]
        local Loaded, Menu = pcall(require, button.MenuModule)
        if not Loaded then
            warn("[SideBar] The \""..name.."\" menu failed to load, so it gets no button: "..tostring(Menu))
            continue
        end

        local BarButton = BarButtonPrefabs[button.Type]:Clone()
        BarButton.Name = name
        BarButton.Icon.Image = button.Render
        BarButton.Button.Image = button.Render
        BarButton.InvertedIcon.Image = button.InvertedRender or BarButton.InvertedIcon.Image
        BarButton.Inverted.Image = button.InvertedRender or BarButton.Inverted.Image
        BarButton.Title.Holder.Label.Text = name
        BarButton.LayoutOrder = button.LayoutOrder
        Menu.CloseOnOtherOpen = button.CloseOnOtherOpen
        Menu.CloseOthersOnOpen = button.CloseOthersOnOpen
        BarButton.Button.MouseButton1Click:Connect(function()
            SideBar.OpenMenu(Menu)
        end)
        Menu.Button = BarButton

        --TODO: replace these variables only if the size is the hidden one to handle resolution changes
        local OriginalSize = BarButton.Size
        local HoverSize = UDim2.fromScale(OriginalSize.X.Scale * 1.2, OriginalSize.Y.Scale * 1.2)

        SideBar.MenuModules[name] = Menu
        BarButton.Parent = ButtonContainer

        --[[
            A menu that couldn't build its UI gets no button.

            The prefabs these menus clone are Studio assets copied from the engine's
            example place, not code in this repository — so it is entirely possible to have
            the Inventory's and not the Shop's. A button that throws on click is worse than
            no button, and this is checked on a delay as well because the menu's own `Init`
            may not have run yet when the sidebar builds.
        ]]
        if Menu.Failed then
            BarButton.Visible = false
        else
            task.delay(5, function()
                if Menu.Failed and BarButton.Parent then
                    BarButton.Visible = false
                end
            end)
        end

        local OriginalYLabelBound = BarButton.Title.Holder.Label.AbsoluteSize.Y
        BarButton.MouseEnter:Connect(function()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
            TweenService:Create(BarButton, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = HoverSize}):Play()
            -- Why does `TextLabel.AutomaticSize` not fucking work with `TextLabel.TextScaled`? No idea! I'm mentally insane! :D
            -- `TextLabel.TextSize` doesn't either. What world are we living in?
            -- 
            -- reading this 2 months later makes me realize i was a dumbass -Dys 2026
            local Size = TextService:GetTextSize(BarButton.Title.Holder.Label.Text, OriginalYLabelBound, BarButton.Title.Holder.Label.Font, BarButton.Title.Holder.Label.AbsoluteSize)
            TweenService:Create(BarButton.Title.Holder, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.15, Size.X + 56, 0.5, 0)
            }):Play()
        end)
        BarButton.MouseLeave:Connect(function()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
            TweenService:Create(BarButton, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = OriginalSize}):Play()
            TweenService:Create(BarButton.Title.Holder, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 0.5, 0)
            }):Play()
        end)

        Utils.Character.ObserveCharacter(LocalPlayer, function(char: Model)
            --[[
                `Failed`, not `UIInstance`.

                The guard is meant to skip menus that could never build — but it was
                reading "is the UI here right now", and `Toggle(false)` DESTROYS the UI on
                purpose whenever the player stops being a spectator. A menu that clears its
                `UIInstance` on teardown would therefore be skipped on the next spawn and
                never rebuilt: gone for the rest of the session.

                The Shop only escaped that because its teardown left a dangling reference
                to a destroyed instance, which happens to be truthy. Depending on that is
                not a plan.
            ]]
            if Menu.Failed then
                return
            end

            -- `GetRole` rather than a raw deref: this runs on every character spawn, and
            -- if it throws the whole sidebar dies — every menu with it.
            Menu.Toggle(Utils.Character.GetRole(char) == "Spectator")
        end)
    end

    Utils.Character.ObserveCharacter(LocalPlayer, function(char: Model)
        SideBar.Toggle(Utils.Character.GetRole(char) == "Spectator")
    end)
end

return SideBar
