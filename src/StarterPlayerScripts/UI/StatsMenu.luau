local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SideBar = require(script.Parent.SideBar)
local Utils = require(ReplicatedStorage.Modules.Utils)

local LocalPlayer = Players.LocalPlayer

local StatsMenu = {
    Opened = false,
    Enabled = true,
    UIInstance = nil,
}

local Prefabs = {
    Section = script.Prefabs.Section,
    Stat = script.Prefabs.Stat,
}

local UIParent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "Menus")

function StatsMenu:Init()
    if StatsMenu.UIInstance then
        StatsMenu.UIInstance.Parent = UIParent
        StatsMenu.UIInstance.Size = Utils.UDim.Zero
        StatsMenu.UIInstance.Visible = false
        return
    end

    local UI = script.StatsMenu
    UI.Size = Utils.UDim.Zero
    UI.Visible = false
    UI.Parent = UIParent
    StatsMenu.UIInstance = UI
    local Content = UI.StatsContainer.Content

    local CurrentLayoutOrder = 0
    
    local Folders = Utils.Instance.FindFirstChild(LocalPlayer, "PlayerData.Stats"):GetChildren()

    table.sort(Folders, function(a, b)
        return a:GetAttribute("LayoutOrder") < b:GetAttribute("LayoutOrder")
    end)

    for _, StatFolder in ipairs(Folders) do
        CurrentLayoutOrder += 1

        local Section = Prefabs.Section:Clone()
        Section.Name = StatFolder.Name
        Section.TextLabel.Text = StatFolder:GetAttribute("DisplayTitle")
        Section.LayoutOrder = CurrentLayoutOrder

        local StatsInSection = StatFolder:GetChildren()

        table.sort(StatsInSection, function(a, b)
            return a:GetAttribute("LayoutOrder") < b:GetAttribute("LayoutOrder")
        end)

        for _, StatValue in StatsInSection do
            CurrentLayoutOrder += 1
            
            local Stat = Prefabs.Stat:Clone()
            Stat.Name = StatValue.Name

            local DisplayTitle = StatValue:GetAttribute("DisplayTitle")

            if StatValue:GetAttribute("PostDisplayTitle") ~= nil then
                DisplayTitle = DisplayTitle.." ("..StatValue:GetAttribute("PostDisplayTitle")..")"
            end

            Stat.Text = DisplayTitle..": "

            if StatValue:GetAttribute("FormatTime") == true then
                Stat.Text = Stat.Text..Utils.Math.ConvertToDHMS(StatValue.Value)
            else
                Stat.Text = Stat.Text..tostring(StatValue.Value)
            end

            Stat.LayoutOrder = CurrentLayoutOrder

            StatValue.Changed:Connect(function(value)
                Stat.Text = DisplayTitle..": "

                local RealValue = StatValue:GetAttribute("FormatTime") == true and Utils.Math.ConvertToDHMS(value) or tostring(value)
                Stat.Text = Stat.Text..RealValue
            end)

            Stat.Parent = Content
        end
        
        Section.Parent = Content
    end

    Utils.Instance.ObserveProperty(StatsMenu.UIInstance, "Size", function(value: UDim2)
        StatsMenu.UIInstance.Visible = value ~= Utils.UDim.Zero
    end)
end

function StatsMenu.Open(Time: number)
    --[[
        `Utils.Character.GetRole` rather than `LocalPlayer.Character.Role`.

        The old form THREW twice over: `LocalPlayer.Character` is nil between death and
        respawn, and indexing a Model for a `Role` child that hasn't replicated yet is an
        error in Roblox, not a nil. Either one killed the click — the menu button did
        nothing at all and the only trace was a line in the developer console.
    ]]
    if not StatsMenu.Enabled or Utils.Character.GetRole(LocalPlayer.Character) ~= "Spectator" or not SideBar.Enabled then
        return "Prevented"
    end

    TweenService:Create(StatsMenu.UIInstance, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Full20Offset}):Play()
    StatsMenu.Opened = true
    return
end

function StatsMenu.Close(Time: number)
    if Time > 0 then
        TweenService:Create(StatsMenu.UIInstance, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        StatsMenu.UIInstance.Size = Utils.UDim.Zero
    end
    StatsMenu.Opened = false
end

function StatsMenu.Toggle(toggle: boolean)
    --[[
        A menu whose `Init` never produced a UI has nothing to hide.

        `SideBar` calls this on every character spawn, and the teardown below used to
        dereference `UIInstance` unconditionally — so a menu that failed to build threw
        here once per spawn, forever. `SideBar` used to paper over it by skipping menus
        with no `UIInstance`, but that check also skipped menus that DESTROY their UI on
        teardown and rebuild it later, so it had to go.
    ]]
    if not StatsMenu.Enabled and toggle then
        StatsMenu:Init()
    end
    if not toggle and StatsMenu.Enabled and StatsMenu.UIInstance then
        StatsMenu.UIInstance.Parent = script
        StatsMenu.UIInstance.Size = Utils.UDim.Zero
    end
    StatsMenu.Enabled = toggle
end

return StatsMenu
