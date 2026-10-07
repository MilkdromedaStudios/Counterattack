local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Utils = require(ReplicatedStorage.Modules.Utils)
local Network = require(ReplicatedStorage.Modules.Network)

local RewardNotifications = {}

function RewardNotifications:Init()
    local Container = Utils.Instance.FindFirstChild(script, "RewardNotificationContainer")
    Container.Parent = Utils.Instance.FindFirstChild(Players.LocalPlayer.PlayerGui, "RewardNotifications")

    local Prefab = Utils.Instance.FindFirstChild(script, "RewardNotification")
    local AchievementPrefab = Utils.Instance.FindFirstChild(script, "AchievementNotification")

    Network:SetConnection("ShowRewardNotification", "REMOTE_EVENT", function(Module: ModuleScript | string, Type: string)
        Type = Type or "QuotedGrantedSkin"

        local TypeLower = Type:lower()

        local IsAchievement = TypeLower:find("achievement") ~= nil

        local Card = (IsAchievement and AchievementPrefab or Prefab):Clone()
        local Info = IsAchievement and Utils.Instance.GetAchievementData(Module) or require(Module)

        --[[
            Emote modules put their fields at the TOP LEVEL; characters put theirs under
            `Config`. Every read below went straight to `Info.Config.<something>`, so
            notifying somebody about an emote threw on the first line and they simply never
            saw the notification for anything they bought from the Emotes tab.
        ]]
        local Config = (not IsAchievement) and (Info.Config or Info) or nil

        Card.ImageContainer.Render.Image = IsAchievement and (Info.Icon or "rbxasset://textures/ui/GuiImagePlaceholder.png") or (Config.Render or "rbxasset://textures/ui/GuiImagePlaceholder.png")

        local Text

        if IsAchievement then
            Text = `"{Info.Title}" achievement obtained!`
        else
            Text = (TypeLower:find("bought") and "Bought" or "Received").." \""..tostring(Config.Name or Module.Name).."\""

            if TypeLower:find("emote") then
                Text = Text.." emote"
            elseif TypeLower:find("skin") then
                Text = Text.." skin"
            elseif TypeLower:find("character") then
                Text = Text.." character"
            end
        end

        Card.TextContainer.RewardLabel.Text = Text
        
        -- `or ""` so a character with no quote shows an empty line rather than throwing on
        -- the concatenation below.
        local Quote = (not IsAchievement and (Config.Quote or "") or Info.Description) or ""
        if TypeLower:find("quoted") and #Quote > 0 then
            Quote = "\""..Quote.."\""
        end

        Card.TextContainer.RewardQuote.Text = Quote

        Card.Size = Utils.UDim.Zero
        Card.Parent = Container
        TweenService:Create(Card, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1, 0.2)}):Play()
        task.wait(5)
        TweenService:Create(Card, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Size = Utils.UDim.Zero}):Play()
        task.wait(1)
        Card:Destroy()
    end)
end

return RewardNotifications
