local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SideBar = require(script.Parent.SideBar)
local Utils = require(ReplicatedStorage.Modules.Utils)

local LocalPlayer = Players.LocalPlayer

local CreditsMenu = {
    Enabled = true,
    UIInstance = nil,
    Opened = false,
}

type Credit = {
    Render: string,
    DisplayName: string,
    Username: string,
    Description: string,
}
--[=[
    THE CREDITS MENU

    Sections render in order, and so do the people inside them.

    `Render` is a headshot image ID. Leave it as an empty string and the card falls back
    to Roblox's grey placeholder, which is fine until you have real art.

    Add yourself and anyone who helps you to the "This Game" section as you go.
]=]
local Credits: {{ Name: string, Credits: {Credit} }} = {
    {
        Name = "This Game",
        Credits = {
            {
                Render = "",
                DisplayName = "UNIOPAY",
                Username = "@UNIOPAY",
                Description = "Game owner. Designed the roster, built every character model and ran the whole project.",
            },
        },
    },
    {
        Name = "Characters",
        Credits = {
            {
                Render = "",
                DisplayName = "Original Killers",
                Username = "Hollowmark · Scrapheap · Ravel",
                Description = "Three killers written for this game specifically. Hollowmark gets stronger the more people are fighting, Scrapheap spends its armour as ammunition, and Ravel does no burst damage at all.",
            },
            {
                Render = "",
                DisplayName = "Guest Killers",
                Username = "Verity · Fog · Gubby · Nuker · Mini-Gunner · 1x1x1x1",
                Description = "Brought in from the wider Roblox horror and myth scene. All abilities and balance are original to this game.",
            },
            {
                Render = "",
                DisplayName = "The Crossover Roster",
                Username = "27 more, from everywhere",
                Description = "Characters people already know, given kits built for this game. Every ability, stat and number is original work — only the names and silhouettes are borrowed, and those belong to their respective owners.",
            },
            {
                Render = "",
                DisplayName = "Nullex Voyd",
                Username = "Project Terminus",
                Description = "The engine's example killer, kept in the roster and rebalanced for Free For All.",
            },
        },
    },
    --[=[
        The weather section.

        These two credits used to live as PROSE INSIDE A SCRIPT — a `Script` in the island
        model whose entire source was "Amura initially made this island for
        Stickmasterluke's disaster game. Props to him. ;D". That is not Luau, so it threw a
        syntax error on every server start, and nobody who played the game ever saw it.
        A credit that only appears in the developer console isn't a credit.

        Here it is where people can actually read it.
    ]=]
    {
        Name = "Weather",
        Credits = {
            {
                Render = "",
                DisplayName = "Stickmasterluke",
                Username = "@stickmasterluke",
                Description = "Made Natural Disaster Survival, which the weather system is a port of. The meteor showers, the tornado's orbital pull and the flood's rising waterline are all his design, rebuilt to run on this game's arenas.",
            },
            {
                Render = "",
                DisplayName = "Amura",
                Username = "Island builder",
                Description = "Built the original island Natural Disaster Survival was played on. Props to him. ;D",
            },
        },
    },
    {
        Name = "Dysymmetrical",
        Credits = {
            {
                Render = "rbxassetid://112215528635901",
                DisplayName = "Dyscarn",
                Username = "@LrgeAlvaro8882",
                Description = "Made the engine this game runs on: Dysymmetrical, an open-source asymmetrical horror framework.",
            },
            {
                Render = "",
                DisplayName = "heromax149807",
                Username = "@heromax149807",
                Description = "Made the original engine art — the sidebar icons, the buttons, and the rest of the UI kit.",
            },
            {
                Render = "",
                DisplayName = "Itred",
                Username = "Dysymmetrical contributor",
                Description = "Hitbox and combat system work on the base engine.",
            },
        },
    },
}

local UIParent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "Menus")
function CreditsMenu:Init()
    if CreditsMenu.UIInstance then
        CreditsMenu.UIInstance.Parent = UIParent
        CreditsMenu.UIInstance.Size = Utils.UDim.Zero
        CreditsMenu.UIInstance.Visible = false
        return
    end

    local UI = Utils.Instance.FindFirstChild(script, "CreditsMenu")
    UI.Size = Utils.UDim.Zero
    UI.Visible = false
    CreditsMenu.UIInstance = UI
    UI.Parent = UIParent

    local Prefabs = {
        Section = Utils.Instance.FindFirstChild(script, "SectionLabel"),
        Credit = Utils.Instance.FindFirstChild(script, "Credit"),
    }

    local LO = 0
    --using ipairs instead of nothing to make sure that it's ordered
    for _, CreditsSection: {Name: string, Credits: {Credit}} in ipairs(Credits) do
        LO += 1

        local SectionPrefab = Prefabs.Section:Clone()
        SectionPrefab.Name = CreditsSection.Name.."Section"
        SectionPrefab.SectionName.Text = CreditsSection.Name
        SectionPrefab.LayoutOrder = LO
        SectionPrefab.Parent = UI.Content

        for _, Credit: Credit in ipairs(CreditsSection.Credits) do
            LO += 1

            local CreditPrefab = Prefabs.Credit:Clone()
            CreditPrefab.Name = Credit.Username.."Credit"
            CreditPrefab.DisplayName.Text = Credit.DisplayName
            CreditPrefab.Username.Text = Credit.Username
            CreditPrefab.Portrait.Image = Credit.Render or "rbxasset://textures/ui/GuiImagePlaceholder.png"
            CreditPrefab.Description.Text = Credit.Description

            CreditPrefab.LayoutOrder = LO
            CreditPrefab.Parent = UI.Content
        end
    end

    Utils.Instance.ObserveProperty(CreditsMenu.UIInstance, "Size", function(value: UDim2)
        CreditsMenu.UIInstance.Visible = value ~= Utils.UDim.Zero
    end)
end

function CreditsMenu.Open(Time: number)
    --[[
        `Utils.Character.GetRole` rather than `LocalPlayer.Character.Role`.

        The old form THREW twice over: `LocalPlayer.Character` is nil between death and
        respawn, and indexing a Model for a `Role` child that hasn't replicated yet is an
        error in Roblox, not a nil. Either one killed the click — the menu button did
        nothing at all and the only trace was a line in the developer console.
    ]]
    if not CreditsMenu.Enabled or Utils.Character.GetRole(LocalPlayer.Character) ~= "Spectator" or not SideBar.Enabled then
        return "Prevented"
    end

    TweenService:Create(CreditsMenu.UIInstance, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.475, 0.599)}):Play()
    CreditsMenu.Opened = true

    return
end

function CreditsMenu.Close(Time: number)
    if Time > 0 then
        TweenService:Create(CreditsMenu.UIInstance, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        CreditsMenu.UIInstance.Size = Utils.UDim.Zero
    end
    CreditsMenu.Opened = false
end

function CreditsMenu.Toggle(toggle: boolean)
    --[[
        A menu whose `Init` never produced a UI has nothing to hide.

        `SideBar` calls this on every character spawn, and the teardown below used to
        dereference `UIInstance` unconditionally — so a menu that failed to build threw
        here once per spawn, forever. `SideBar` used to paper over it by skipping menus
        with no `UIInstance`, but that check also skipped menus that DESTROY their UI on
        teardown and rebuild it later, so it had to go.
    ]]
    if not CreditsMenu.Enabled and toggle then
        CreditsMenu:Init()
    end
    if not toggle and CreditsMenu.Enabled and CreditsMenu.UIInstance then
        CreditsMenu.UIInstance.Parent = script
        CreditsMenu.UIInstance.Size = Utils.UDim.Zero
    end
    CreditsMenu.Enabled = toggle
end

return CreditsMenu
