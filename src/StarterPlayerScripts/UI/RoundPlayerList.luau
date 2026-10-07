local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(ReplicatedStorage.Modules.Utils)
local GameMode = require(ReplicatedStorage.Modules.GameMode)

local LocalPlayer = Players.LocalPlayer
local RoundState: StringValue = ReplicatedStorage.RoundInfo.CurrentState

local RoundPlayerList = {
    UI = nil,
    Conns = {},
}

local TemplateFolder = Utils.Instance.FindFirstChild(script, "Templates")
local Prefabs = {
    UI = Utils.Instance.FindFirstChild(script, "RoundPlayerListUI"),
    Card = Utils.Instance.FindFirstChild(TemplateFolder, "Card"),
}
local UIParent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "RoundPlayerList")

function RoundPlayerList:Init()
    Utils.Character.ObserveCharacter(LocalPlayer, function(Char: Model)
        if RoundPlayerList.UI then
            RoundPlayerList.UI:Destroy()
        end
        for _, ConnectionList in RoundPlayerList.Conns do
            for _, Connection in ConnectionList do
                Connection:Disconnect()
            end
        end
        RoundPlayerList.Conns = {}
        RoundPlayerList._InitUI(Char)
    end)
end

function RoundPlayerList._InitUI(Char: Model)
    -- Nil means `Role` hasn't replicated yet. Bail rather than throwing — the lobby body
    -- is the common case here and it wants the same answer.
    if Utils.Character.GetRole(Char) ~= "Killer" and Utils.Character.GetRole(Char) ~= "Survivor" then
        return
    end

    local UI = Prefabs.UI:Clone()
    UI.Parent = UIParent
    RoundPlayerList.UI = UI

    while RoundState.Value ~= "InRound" do
        task.wait()
    end

    local Conns: {[string]: RBXScriptConnection} = {}

    --- Which role the people being listed have. Everyone is a Killer in Counterattack;
    --- in the classic game the list is of Survivors.
    local FighterRole = GameMode.Enabled and "Killer" or "Survivor"

    for _, Character in workspace.Players:GetChildren() do
        --[[
            This used to be hardcoded to `"Survivor"`, so in Counterattack — where every
            player is a Killer — the round list was permanently empty. It now tracks
            whichever role the fighters actually have, which keeps it correct in the
            original Killer-vs-Survivors game too.
        ]]
        local Role = Utils.Character.GetRole(Character)
        if Role ~= FighterRole then
            continue
        end

        --[[
            Both lookups can return nil — a character whose model was removed, or whose
            `CharacterName` attribute hasn't replicated yet — and `require(nil)` throws.

            This loop walks EVERY character in the world, so one bad entry used to take the
            whole list down rather than costing one card.
        ]]
        local SkinModule = Utils.Instance.GetCharacterModule(Role, Character:GetAttribute("CharacterName"), Character:GetAttribute("CharacterSkinName"), false)
        local BaseModule = Utils.Instance.GetCharacterModule(Role, Character:GetAttribute("CharacterName"), nil, false)

        if not BaseModule then
            warn("[RoundPlayerList]: no module for \""..tostring(Character:GetAttribute("CharacterName")).."\" — skipping their card.")
            continue
        end

        local Card = Prefabs.Card:Clone()
        Card.Name = Character.Name

        --should show the skin portrait if equipped
        Card.Portrait.Image = require(SkinModule or BaseModule).Config.Render
        --should show the root character's name without caring about the skin
        Card.CharacterName.Text = require(BaseModule).Config.Name

        local Humanoid: Humanoid = Character:FindFirstChildWhichIsA("Humanoid")

        if Character == LocalPlayer.Character then
            Card.PlayerHealth.TextTransparency = 1
            Card.CharacterName.TextColor3 = Color3.fromRGB(255, 255, 127)
            Card.PortraitOutline.ImageColor3 = Color3.fromRGB(255, 255, 127)
            Card.PlayerName.Text = Character.Name.." (You)"
        else
            Card.PlayerName.Text = Character.Name

            local PlayerConns = {}

            local function HealthUpdate(Health)
                --stop checking when they die
                if Humanoid.Health <= 0 and Card then
                    Card.Portrait.ImageColor3 = Color3.fromRGB(161, 0, 0)
                    Card.PortraitOutline.ImageColor3 = Color3.fromRGB(255, 0, 0)

                    Card.PlayerState.TextColor3 = Color3.fromRGB(255, 0, 0)
                    Card.PlayerState.Text = "DEAD"
                    Card.PlayerState.TextTransparency = 1

                    Card.PlayerHealth.TextTransparency = 1

                    for _, Connection in PlayerConns do
                        Connection:Disconnect()
                    end
                    return
                end

                local HealthPercentageMagnitude = Humanoid.Health / Humanoid.MaxHealth
                Card.PlayerHealth.TextColor3 = Color3.fromRGB(
                    Utils.Math.MapToRange(HealthPercentageMagnitude, 0, 1, 1, 0) * 180 + 75,
                    HealthPercentageMagnitude * 180 + 75,
                    75
                )
                Card.PlayerHealth.Text = tostring(HealthPercentageMagnitude * 100).."%"
            end

            table.insert(PlayerConns, Humanoid.HealthChanged:Connect(HealthUpdate))
            table.insert(PlayerConns, Players.PlayerRemoving:Connect(function(Player: Player)
                if not Character then
                    return
                end

                --stop checking when they leave and are still alive
                if Player.Name == Character.Name then
                    for _, c in PlayerConns do
                        c:Disconnect()
                    end

                    Card.Portrait.ImageColor3 = Color3.fromRGB(200, 200, 200)
                    Card.PortraitOutline.ImageColor3 = Color3.fromRGB(150, 150, 150)

                    Card.PlayerState.TextColor3 = Color3.fromRGB(170, 170, 170)
                    Card.PlayerState.Text = "LOST"
                    Card.PlayerState.TextTransparency = 0

                    Card.PlayerHealth.TextTransparency = 1
                end
            end))

            HealthUpdate(Humanoid.Health)

            Conns[Character.Name] = PlayerConns
        end

        Card.Parent = UI
    end

    RoundPlayerList.Conns = Conns
end

return RoundPlayerList
