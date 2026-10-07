local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SideBar = require(script.Parent.SideBar)
local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)
local TopbarPlus = require(ReplicatedStorage.Packages.TopbarPlus)

local LocalPlayer = Players.LocalPlayer

local ModPanel = {
    Rank = 9999,
    Enabled = true,
    CloseOnOtherOpen = true,
    CloseOthersOnOpen = true,
    UIInstance = nil,
    Opened = false,
    Initted = false,
}

local CommandOrder = {
    "ToggleFreezeTime",
    "ToggleAbilityCooldowns",
    "ToggleAbilityCharges",
}

local Prefabs = {
    Bool = require(Utils.Instance.FindFirstChild(script, "Bool")),
}

function ModPanel:Init()
    if ModPanel.Initted then
        return
    end

    --[=[
        OWNER ONLY.

        This used to ask `HasPermRank("ServerOwner")`, which resolves to `Rank < 20` — and
        Moderator is 15 and Developer is 18, so every moderator and developer got this
        panel. The three things on it are FREEZE TIME, ABILITY COOLDOWNS and ABILITY
        CHARGES: those are game-control toggles that change the round for everybody, not
        moderation tools, and they belong with the round controls.

        The commands behind them are owner-gated on the server too — each one now sets
        `RankRequired = Utils.Ranks.Owner` — so hiding the panel and refusing the action
        agree instead of only the first one being true.

        Moderation proper (`KillPlayer`, `TurnPlayerInto`, `ChangeKillersAllowed`) is
        untouched: those modules set no `RankRequired`, so they still run at the old
        default through `ExecuteCommand`.
    ]=]
    local Allowed = Network:FireServerConnection("CanUseControlPanels", "REMOTE_FUNCTION")
    if Allowed ~= true then
        return
    end

    --[=[
        Past the owner gate, so the per-command filter below is told `Owner`.

        `SetupCmd` skips any command whose `RankRequired` beats `ModPanel.Rank`, and the
        three commands on this panel now require `Utils.Ranks.Owner` (1). Reading the real
        admin rank here would report `DefaultPlayer` (30) for an owner who is not also in
        `CommonFunctions.AdminPerms` — which is the normal case — and every command would
        be filtered out, leaving the owner an empty panel.
    ]=]
    ModPanel.Rank = Utils.Ranks.Owner

    ModPanel.Start()
    ModPanel.Initted = true
end

function ModPanel.Start()
    local UI = Utils.Instance.FindFirstChild(script, "ModPanel")
    UI.Parent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "Menus")
    UI.Size = Utils.UDim.Zero
    UI.Visible = false
    ModPanel.UIInstance = UI

    local TopbarButton = TopbarPlus.new()
    TopbarButton:setOrder(0)
    TopbarButton:oneClick(true)
    TopbarButton:setLabel("Command Panel")
    TopbarButton:setTextFont(Enum.Font.Bodoni)
    TopbarButton:bindEvent("deselected", function()
        Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})
        if ModPanel.Opened then
            ModPanel.Close(SideBar.ToggleDuration)
        else
            ModPanel.Open(SideBar.ToggleDuration)
        end
    end)

    SideBar.MenuModules["ModPanel"] = ModPanel

    Utils.Instance.ObserveProperty(UI, "Size", function(value: UDim2)
        UI.Visible = value ~= Utils.UDim.Zero
    end)

    local LO = 0
    local function SetupCmd(Cmd)
        if not Cmd or not Cmd:IsA("ModuleScript") then
            return
        end

        local Command = require(Cmd)
        Command.RankRequired = Command.RankRequired or Utils.Ranks.ServerOwner

        if ModPanel.Rank > Command.RankRequired or not Command.Type or not Prefabs[Command.Type] then
            return
        end

        LO += 1

        local Content = Prefabs[Command.Type].New(Cmd, UI)
        Content.LayoutOrder = LO
    end

    for _, Command in CommandOrder do
        SetupCmd(ReplicatedStorage.Security.ModeratorCommands:FindFirstChild(Command))
    end

    for _, Command in ReplicatedStorage.Security.ModeratorCommands:GetChildren() do
        if table.find(CommandOrder, Command.Name) then
            continue
        end

        SetupCmd(Command)
    end
end

function ModPanel.Open(Time: number)
    if not ModPanel.Enabled then
        return "Prevented"
    end

    SideBar.CloseAll(ModPanel)

    if Time > 0 then
        TweenService:Create(ModPanel.UIInstance, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.542, 0.741)}):Play()
    else
        ModPanel.UIInstance.Size = UDim2.fromScale(0.4, 0.7)
    end
    ModPanel.Opened = true

    return
end

function ModPanel.Close(Time: number)
    if Time > 0 then
        TweenService:Create(ModPanel.UIInstance, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        ModPanel.UIInstance.Size = Utils.UDim.Zero
    end
    ModPanel.Opened = false
end

function ModPanel:Toggle()
end

return ModPanel
