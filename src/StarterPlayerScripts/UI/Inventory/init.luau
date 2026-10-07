local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local EmoteEquipWindow = require(script.EmoteEquipWindow)
local SideBar = require(script.Parent.SideBar)
local Network = require(ReplicatedStorage.Modules.Network)
local Types = require(ReplicatedStorage.Classes.Types)
local Tooltip = require(ReplicatedStorage.Classes.Tooltip)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local LocalPlayer = Players.LocalPlayer

local UIParent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "Menus")

local Inventory = {
    Opened = false,
    Enabled = true,
    --- Killers is the only character section now; there are no survivors in this game.
    SelectedSection = "Killers",
    SkinMenu = {
        Open = false,
        ShowingCharacter = "",
    },
    InfoMenu = {
        Open = false,
        ShowingCharacter = "",
    },
    LoadedItems = {
        Killers = {},
        Survivors = {},
        Skins = {},
    },
    ItemModules = {},
    SelectedItem = {
        Name = "",
        Type = "",
    },
    UIInstance = nil,
    EmoteWindow = nil,

    --- Set when `Init` can't find its prefabs. `SideBar` hides the button on it.
    Failed = false,
    --- Guards `WatchPlayerData` against being wired up more than once across rebuilds.
    Watching = false,
}

local Sizes = {
    SideBar = UDim2.fromScale(0.3, 1),
    ClosedSideBar = Utils.UDim.FullY,
}

local UI
local InventoryContainer
local KillerContainer
local SurvivorContainer
local EmoteContainer

local SideContainer
local SkinContainer
local InfoContainer
local PreviewContainer
local ButtonsContainer

local Buttons = {
    Equip = nil,
    Info = nil,
    Skins = nil,
}

local Equipped = {
    EquippedKiller = nil,
    EquippedSurvivor = nil,
}

local PreviewInstances = {
    Render = nil,
    Title = nil,
}

local Templates = {
    CardTemplate = nil,
    Header = nil,
    Text = nil,
    Quote = nil,
    Separator = nil,
    InfoSection = nil,
}

local Sections = {}

function Inventory.ReorderSkins()
    local Ordered = {}
    local LO = 0

    for _, Skin in Inventory.LoadedItems.Skins do
        table.insert(Ordered, Skin)
    end

    table.sort(Ordered, function(a, b)
        local Modules = {
            A = require(Utils.Instance.GetCharacterModule(Inventory.SelectedItem.Type, Inventory.SelectedItem.Name, a.Name)),
            B = require(Utils.Instance.GetCharacterModule(Inventory.SelectedItem.Type, Inventory.SelectedItem.Name, b.Name)),
        }

        return
            Modules.A.Config.Price == Modules.B.Config.Price and a.Name < b.Name
            or Modules.A.Config.Price < Modules.B.Config.Price
    end)

    for _, Skin in Ordered do
        LO += 1
        Skin.LayoutOrder = LO
    end
end


function Inventory.CheckEquipLabels()
    local function RemoveEquippedLabel(card)
        if card.Container.Equipped.ImageTransparency ~= 1 then
            TweenService:Create(card.Container.Equipped, TweenInfo.new(0.2), {ImageTransparency = 1}):Play()
        end
    end

    local function ShowEquippedLabel(card)
        if card.Container.Equipped.ImageTransparency ~= 0 then
            TweenService:Create(card.Container.Equipped, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()
        end
    end

    for name, Type in Inventory.LoadedItems do
        if name == "Skins" then
            continue
        end
        for _, Item in Type do
            if Item.Name == Equipped["Equipped"..name:sub(1, #name - 1)].Value then
                ShowEquippedLabel(Item)
            else
                RemoveEquippedLabel(Item)
            end
        end
    end
end

function Inventory.EquipItem()
    Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})
    if not Inventory.Opened or Equipped["Equipped"..Inventory.SelectedItem.Type].Value == Inventory.SelectedItem.Name then
        return
    end

    local lastEquipped = Equipped["Equipped"..Inventory.SelectedItem.Type].Value
    Buttons.Equip.Title.Text = "Equipped"
    Network:FireServerConnection("EquipItem", "REMOTE_EVENT", Inventory.SelectedItem.Name, Inventory.SelectedItem.Type)
    if Equipped["Equipped"..Inventory.SelectedItem.Type].Value == lastEquipped then
        Equipped["Equipped"..Inventory.SelectedItem.Type].Changed:Wait()
    end
    Inventory.CheckEquipLabels()
end

local function SwitchSection(sectionName: string)
    if not Inventory.Opened or Inventory.SelectedSection == sectionName then return end

    TweenService:Create(SideContainer, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0, 1)}):Play()
    if Inventory.EmoteWindow then
        Inventory.EmoteWindow:Hide()
        Inventory.EmoteWindow = nil
    end

    for _, Section in Sections do
        Section.Visible = Section.Name == sectionName
    end

    Inventory.SelectedSection = sectionName
end

function Inventory.ReloadEquippedEmotes()
    for _, EmoteSlot in EmoteContainer.EmoteContainer:GetChildren() do
        local Value = Utils.PlayerData.GetPlayerEquipped(LocalPlayer, "Emotes."..EmoteSlot.Name)
        if #Value <= 0 then
            EmoteSlot.Render.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
            EmoteSlot.NameLabel.Text = ""
            continue
        end

        local EmoteInfo = require(Utils.Instance.GetEmoteModule(Value))
        EmoteSlot.Render.Image = EmoteInfo.Config.Render
        EmoteSlot.NameLabel.Text = EmoteInfo.Config.Name
    end
end

function Inventory.ToggleSkinsMenu(Open: boolean?)
    if Open == nil then
        Open = not Inventory.SkinMenu.Open
    end

    if Open then
        Inventory.ToggleInfoMenu(false)
    end
    
    if Open then
        for _, Skin in Inventory.LoadedItems.Skins do
            Skin:Destroy()
        end
        table.clear(Inventory.LoadedItems.Skins)
        Inventory.ItemModules.Skins = Inventory.ItemModules.Skins or {}
        table.clear(Inventory.ItemModules.Skins)

        local charName = Inventory.SelectedItem.Name
        local EquippedSkin = Utils.PlayerData.GetPlayerEquipped(LocalPlayer, "Skins."..charName, false)

        local function CheckSkinEquipLabels()
            for _, Skin in Inventory.LoadedItems.Skins do
                if #EquippedSkin.Value < 0 or EquippedSkin.Value ~= Skin.Name then
                    if Skin.Container.Equipped.ImageTransparency ~= 1 then
                        TweenService:Create(Skin.Container.Equipped, TweenInfo.new(0.2), {ImageTransparency = 1}):Play()
                    end
                else
                    if Skin.Container.Equipped.ImageTransparency ~= 0 then
                        TweenService:Create(Skin.Container.Equipped, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()
                    end
                end
            end
        end

        for _, Skin in (LocalPlayer.PlayerData.Purchased.Skins:FindFirstChild(Inventory.SelectedItem.Name) or Network:FireServerConnection("CreateMissingPurchasedSkinValue", "REMOTE_FUNCTION", Inventory.SelectedItem.Name)):GetChildren() do
            local Module = Utils.Instance.GetCharacterModule(Inventory.SelectedItem.Type, Inventory.SelectedItem.Name, Skin.Name)
            local Info = require(Module)
            local name = Module.Name

            local Card = Templates.CardTemplate:Clone()
            Card.Name = name
            local Container = Card.Container
            Card.Parent = SkinContainer.ScrollingFrame
            Container.Title.Text = Info.Config.Name
            Container.CharacterRender.Image = Info.Config.Render

            if Info.Config.CardFrame then
                Container.Outline.Image = Info.Config.CardFrame.Image or Container.Outline.Image
                Container.Outline.Size = Info.Config.CardFrame.Size or Container.Outline.Size
            end

            Inventory.LoadedItems.Skins[name] = Card
            Inventory.ItemModules.Skins[name] = Info

            Container.Interact.MouseEnter:Connect(function()
                TweenService:Create(Container, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                    Size = UDim2.fromScale(1.065, 1.065)
                }):Play()
                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
            end)
            Container.Interact.MouseLeave:Connect(function()
                TweenService:Create(Container, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                    Size = Utils.UDim.Full
                }):Play()
                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
            end)
            Container.Interact.MouseButton1Click:Connect(function()
                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})
                
                local valueBefore = EquippedSkin.Value
                if EquippedSkin.Value ~= name then
                    Network:FireServerConnection("EquipItem", "REMOTE_EVENT", name, "Skin", "Skins."..charName)
                else
                    Network:FireServerConnection("EquipItem", "REMOTE_EVENT", "", "Skin", "Skins."..charName)
                end

                if EquippedSkin.Value == valueBefore then
                    EquippedSkin.Changed:Wait()
                end

                CheckSkinEquipLabels()
            end)

            if Info.Config.Origin and Info.Config.Origin.Icon then
                Container.Origin.Visible = true
                Container.Origin.Image = Info.Config.Origin.Icon
                Container.Origin.MouseEnter:Connect(function()
                    Tooltip.New(Info.Config.Origin.TooltipText)
                    Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
                end)
                Container.Origin.MouseLeave:Connect(function()
                    Tooltip.New()
                    Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
                end)
            else
                Container.Origin.Visible = false
            end
        end

        CheckSkinEquipLabels()

        Inventory.ReorderSkins()

        TweenService:Create(InventoryContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.FullY}):Play()
        TweenService:Create(SkinContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.7, 1)}):Play()

        Inventory.SkinMenu.Open = true
    else
        TweenService:Create(InventoryContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.7, 1)}):Play()
        TweenService:Create(SkinContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.FullY}):Play()

        Inventory.SkinMenu.Open = false
    end

    TweenService:Create(InfoContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.FullY}):Play()
end

function Inventory.ToggleInfoMenu(Open: boolean?)
    if Open == nil then
        Open = not Inventory.InfoMenu.Open
    end

    if Open then
        Inventory.ToggleSkinsMenu(false)
    end

    if Open then
        for _, Child in InfoContainer:GetChildren() do
            if not Child:IsA("UIComponent") then
                Child:Destroy()
            end
        end

        local CharacterInfo = require(Utils.Instance.GetCharacterModule(Inventory.SelectedItem.Type, Inventory.SelectedItem.Name))

        if not CharacterInfo.Config.Description then
            return
        end

        Inventory.InfoMenu.Open = true

        local TextsToCheck = {}

        for SectionIndex: number, Section: {
            Type: "Text" | "Header" | "Separator" | "Quote",
            Text: string | {string},
            Image: string?,
        } in CharacterInfo.Config.Description do
            local SectionContainer = Templates.InfoSection:Clone()
            SectionContainer.LayoutOrder = SectionIndex
            SectionContainer.Parent = InfoContainer

            local Text = ""
            if typeof(Section.Text) == "table" then
                for index, paragraph in ipairs(Section.Text) do
                    if index > 1 then
                        Text = Text.."\n"
                    end
                    Text = Text..paragraph
                end
            else
                Text = Section.Text
            end

            local Pref = Templates[Section.Type]:Clone()
            if Section.Type ~= "Text" then
                (Section.Type == "Separator" and Pref.Title or Pref).Text = Section.Text
            else
                Pref.Title.Text = Text
                Pref.Title.MaxVisibleGraphemes = 0
                if Section.Image then
                    Pref.Image.Image = Section.Image
                    Pref.Image.Visible = true
                end
                table.insert(TextsToCheck, Pref)
                TweenService:Create(Pref.Title, TweenInfo.new(0.03 * #Text, Enum.EasingStyle.Linear), {MaxVisibleGraphemes = #Text}):Play()
            end
            Pref.Parent = SectionContainer
        end

        task.spawn(function()
            local PossibleEffects = {}

            local function AddEffectToList(Inst: ModuleScript | Folder)
                for _, Effect in Inst:GetChildren() do
                    if Effect:IsA("Folder") then
                        AddEffectToList(Effect)
                        continue
                    end

                    if not Effect:IsA("ModuleScript") then
                        continue
                    end

                    PossibleEffects[Effect.Name] = require(Effect).Description or "UNKNOWN"
                end
            end
        
            AddEffectToList(ReplicatedStorage.Effects)
        
            local LocalPlayer = Players.LocalPlayer
            local CurrentTooltip
        
            local function GetSpaceWidth(font, textSize, maxX)
                return TextService:GetTextSize(" ", textSize, font, Vector2.new(maxX, 1e5)).X
            end
        
            while task.wait() and Inventory.InfoMenu.Open do
                local ui = Inventory.UIInstance
                local char = LocalPlayer.Character
                local role = char and char:FindFirstChild("Role")
            
                if not (ui and ui.Visible and role and role.Value == "Spectator") then
                    if CurrentTooltip then
                        CurrentTooltip = Tooltip.New()
                    end
                    continue
                end
            
                local mousePos = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
                local foundEffect = false
            
                for _, textLabel in TextsToCheck do
                    if foundEffect then break end
                
                    local text = textLabel.Title
                    local absPos, absSize = text.AbsolutePosition, text.AbsoluteSize
                    local font, textSize = text.Font, text.TextSize
                    local maxWidth = absSize.X
                    local spaceWidth = GetSpaceWidth(font, textSize, maxWidth)
                
                    -- bound check
                    if not (mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and
                            mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y) then
                        continue
                    end
                
                    local lineHeight = TextService:GetTextSize("A", textSize, font, Vector2.new(maxWidth, 1e5)).Y
                    local totalY = 0
                
                    for _, rawLine in ipairs(text.Text:gsub("<.->", ""):split("\n")) do
                        local currentLine = {}
                        local currentWidth = 0
                    
                        local wrappedLines = {}
                        for _, word in ipairs(rawLine:split(" ")) do
                            local wordSize = TextService:GetTextSize(word, textSize, font, Vector2.new(maxWidth, 1e5)).X
                            if currentWidth + wordSize > maxWidth then
                                table.insert(wrappedLines, currentLine)
                                currentLine = {}
                                currentWidth = 0
                            end
                            table.insert(currentLine, word)
                            currentWidth += wordSize + spaceWidth
                        end
                        if #currentLine > 0 then
                            table.insert(wrappedLines, currentLine)
                        end
                    
                        for _, lineWords in ipairs(wrappedLines) do
                            if foundEffect then break end
                        
                            local minY = absPos.Y + totalY
                            local maxY = minY + lineHeight
                            if mousePos.Y >= minY and mousePos.Y <= maxY then
                                local lineX = absPos.X
                            
                                for _, word in ipairs(lineWords) do
                                    local wSize = TextService:GetTextSize(word, textSize, font, Vector2.new(maxWidth, 1e5)).X
                                    local minX, maxX = lineX, lineX + wSize
                                
                                    if mousePos.X >= minX and mousePos.X <= maxX then
                                        local desc = PossibleEffects[word]
                                        if desc then
                                            CurrentTooltip = Tooltip.New(desc)
                                            foundEffect = true
                                            break
                                        end
                                    end
                                    lineX += wSize + spaceWidth
                                end
                            end
                            totalY += lineHeight
                        end
                    end
                end
            
                if not foundEffect then
                    CurrentTooltip = Tooltip.New()
                end
            end
        end)

        TweenService:Create(InventoryContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.FullY}):Play()
        TweenService:Create(InfoContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.7, 1)}):Play()
    else
        TweenService:Create(InventoryContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.7, 1)}):Play()
        TweenService:Create(InfoContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.FullY}):Play()

        Inventory.InfoMenu.Open = false
    end
end

function Inventory:Init()
    --[=[
        PREFLIGHT.

        The UI itself does not live in this repository. `InventoryUI` and the `Templates`
        folder are Studio-authored instances that have to be copied out of the Dysymmetrical
        example place by hand — the engine's own changelog says so at every entry that
        touches a menu. Rojo's `ignoreUnknownInstances` PRESERVES them if they're there, but
        it can't create them.

        Without them this used to be `nil:Clone()`: a cryptic throw with no hint of what was
        actually wrong, from a module whose failure looks to the player like "the inventory
        is empty". Naming the missing instance turns a dead end into an instruction.
    ]=]
    --[[
        A REAL TIMEOUT, not zero.

        `Utils.Instance.FindFirstChild` with a timeout of `0` skips `WaitForChild`
        entirely, and this runs the moment `PlayerInitter` requires the module — while a
        joining client is still receiving `PlayerScripts`. Losing that race set the menu
        aside permanently. Same fix, same reason, as the Shop's preflight.
    ]]
    local Prefab = Utils.Instance.FindFirstChild(script, "InventoryUI", 10)
    local TemplateFolder = Utils.Instance.FindFirstChild(script, "Templates", 10)
    local CardPrefab = TemplateFolder and TemplateFolder:FindFirstChild("CardTemplate")

    if not Prefab or not TemplateFolder or not CardPrefab then
        local Missing = {}
        if not Prefab then table.insert(Missing, "InventoryUI") end
        if not TemplateFolder then table.insert(Missing, "Templates") end
        if TemplateFolder and not CardPrefab then table.insert(Missing, "Templates.CardTemplate") end

        warn(
            "[Inventory] Can't build the inventory — these instances are missing from "..
            "StarterPlayer.StarterPlayerScripts.UI.Inventory: "..table.concat(Missing, ", ")..".\n"..
            "     These are Studio assets, not code. Copy them from the Dysymmetrical EXAMPLE PLACE "..
            "into that folder in your own place, then re-sync.\n"..
            "     Nothing in this repository can create them — Rojo only preserves them once they exist."
        )

        --[[
            Flag the failure so `SideBar` hides the button.

            The Shop has always done this; the Inventory never did, so a place missing
            `InventoryUI` still got an inventory button — one that opened nothing and threw
            on a nil `UIInstance` when clicked.
        ]]
        Inventory.Failed = true
        if Inventory.Button then
            Inventory.Button.Visible = false
        end

        return
    end

    Inventory.Failed = false
    if Inventory.Button then
        Inventory.Button.Visible = true
    end

    UI = Prefab:Clone()
    UI.Size = Utils.UDim.Zero
    UI.Visible = false
    UI.Parent = UIParent
    Inventory.UIInstance = UI

    local Container = UI.Container
    InventoryContainer = Container.InventoryContainer.Content
    KillerContainer = InventoryContainer.Killers
    SurvivorContainer = InventoryContainer.Survivors
    SkinContainer = Container.SkinsContainer.Content
    EmoteContainer = InventoryContainer.Emotes
    InfoContainer = Container.InfoContainer.Contents

    --[[
        `SurvivorContainer` is deliberately NOT in this list.

        Everyone is a killer here, so the survivor tab would always be empty. Leaving it
        out of `Sections` means the tab-switching code never selects it, and hiding the
        container plus its topbar button below takes it off screen entirely.

        The container itself is left in the UI rather than destroyed, so switching
        `GameMode.Enabled` back to the original Killer-vs-Survivors game only needs this
        list changed back.
    ]]
    Sections = {
        KillerContainer,
        EmoteContainer,
    }

    SurvivorContainer.Visible = false

    --[=[
        Apply the starting section's visibility explicitly.

        Nothing here ever did. The `InventoryUI` prefab is authored in Studio with ONE
        container already visible — the survivor one, because that used to be the default
        section — and `SwitchSection` is the only thing that ever changes that.

        `SwitchSection` early-returns when the section is already selected:

            if not Inventory.Opened or Inventory.SelectedSection == sectionName then return end

        So with the default moved to Killers, clicking the Killers tab did NOTHING and the
        container stayed hidden. The cards were being built correctly and parented into an
        invisible frame the whole time.

        Setting it from `SelectedSection` here means the code decides what's on screen, not
        whatever state the prefab happened to be saved in.
    ]=]
    for _, Section in Sections do
        Section.Visible = Section.Name == Inventory.SelectedSection
    end

    local SurvivorTab = Container.InventoryContainer.Topbar:FindFirstChild("Survivors")
    if SurvivorTab then
        SurvivorTab.Visible = false
    end

    for _, button in Container.InventoryContainer.Topbar:GetChildren() do
        if button:IsA("ImageButton") and button.Visible then
            button.MouseEnter:Connect(function()
                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
            end)
            button.MouseLeave:Connect(function()
                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
            end)
            button.MouseButton1Click:Connect(function()
                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})
                SwitchSection(button.Name)
            end)
        end
    end

    local templates = Utils.Instance.FindFirstChild(script, "Templates")
    Templates.CardTemplate = Templates.CardTemplate or templates.CardTemplate
    Templates.Header = Templates.Header or templates.Header
    Templates.Text = Templates.Text or templates.TextContainer
    Templates.Quote = Templates.Quote or templates.Quote
    Templates.Separator = Templates.Separator or templates.Separator
    Templates.InfoSection = Templates.InfoSection or templates.InfoSection

    SideContainer = Container.SideContainer
    PreviewContainer = SideContainer.PreviewContainer

    PreviewInstances.Render = PreviewContainer.Render
    PreviewInstances.Render.Image = ""
    PreviewInstances.Title = PreviewContainer.Title

    ButtonsContainer = SideContainer.ButtonsContainer

    Buttons.Equip = ButtonsContainer.Equip
    Buttons.Skins = ButtonsContainer.Skins
    Buttons.Info = ButtonsContainer.MoreInfo

    Equipped.EquippedKiller = Utils.PlayerData.GetPlayerEquipped(LocalPlayer, "Killer", false)
    Equipped.EquippedSurvivor = Utils.PlayerData.GetPlayerEquipped(LocalPlayer, "Survivor", false)

    local JanitorInstance = Janitor.new()
    JanitorInstance:LinkToInstance(UI)

    local BoughtItems: Folder = LocalPlayer.PlayerData.Purchased
    JanitorInstance:Add(BoughtItems.DescendantAdded:Connect(function(_descendant: Instance)
        Inventory.ReloadContent()
    end))
    JanitorInstance:Add(BoughtItems.DescendantRemoving:Connect(function(_descendant: Instance)
        Inventory.ReloadContent()
    end))

    JanitorInstance:Add(Buttons.Equip.MouseEnter:Connect(function()
        Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
    end))
    JanitorInstance:Add(Buttons.Equip.MouseLeave:Connect(function()
        Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
    end))
    JanitorInstance:Add(Buttons.Equip.MouseButton1Click:Connect(function()
        Inventory.EquipItem()
    end))

    JanitorInstance:Add(Buttons.Skins.MouseEnter:Connect(function()
        Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
    end))
    JanitorInstance:Add(Buttons.Skins.MouseLeave:Connect(function()
        Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
    end))
    JanitorInstance:Add(Buttons.Skins.MouseButton1Click:Connect(function()
        Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})

        TweenService:Create(SideContainer, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Sizes.SideBar}):Play() --assuring the sidebar is open

        Inventory.ToggleSkinsMenu()
    end))

    JanitorInstance:Add(Buttons.Info.MouseEnter:Connect(function()
        Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
    end))
    JanitorInstance:Add(Buttons.Info.MouseLeave:Connect(function()
        Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
    end))
    JanitorInstance:Add(Buttons.Info.MouseButton1Click:Connect(function()
        Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})

        TweenService:Create(SideContainer, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Sizes.SideBar}):Play() --assuring the sidebar is open

        Inventory.ToggleInfoMenu()
    end))

    Utils.Instance.ObserveProperty(Inventory.UIInstance, "Size", function(value: UDim2)
        Inventory.UIInstance.Visible = value ~= Utils.UDim.Zero
    end)

    Utils.Instance.ObserveProperty(InfoContainer.Parent, "Size", function(value: UDim2)
        if not Inventory.InfoMenu.Open and value.X.Scale < 0.05 and #InfoContainer:GetChildren() > 0 then
            for _, Child in InfoContainer:GetChildren() do
                if not Child:IsA("UIComponent") then
                    Child:Destroy()
                end
            end
        end
    end)

    for _, EmoteSlot: Frame in EmoteContainer.EmoteContainer:GetChildren() do
        JanitorInstance:Add(EmoteSlot.Button.MouseEnter:Connect(function()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
        end))
        JanitorInstance:Add(EmoteSlot.Button.MouseLeave:Connect(function()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
        end))
        JanitorInstance:Add(EmoteSlot.Button.MouseButton1Click:Connect(function()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})

            if Inventory.EmoteWindow then
                return
            end

            local Slot = EmoteSlot.Name:gsub("Emote", "")
            Inventory.EmoteWindow = EmoteEquipWindow.New(tonumber(Slot), InventoryContainer)
            Inventory.EmoteWindow.Equipped:Connect(function()
                Inventory.ReloadEquippedEmotes()
            end)
            Inventory.EmoteWindow.Removed:Connect(function()
                Inventory.ReloadEquippedEmotes()
                Inventory.EmoteWindow = nil
            end)
        end))
    end

    Inventory.ReloadEquippedEmotes()
    Inventory.ReloadContent()
    Inventory.WatchPlayerData()
end

--[=[
    Keeps the killer list in step with the player's save data.

    Two jobs, and the first is the important one: `ReloadContent` is called from `Init`,
    which on a joining client usually runs BEFORE `SaveManager` has finished its DataStore
    round trip and parented `PlayerData` onto the player. That first call finds nothing and
    returns. Something has to go back and look once the data lands, or the inventory stays
    empty for the whole session — which is precisely what it was doing.

    The second job is keeping up afterwards: a killer bought in the shop should appear in
    the inventory without waiting for the menu to be torn down and rebuilt.

    Deliberately tolerant of being called when the data is already there — `ObserveChildren`
    fires for existing children too, so the same code covers "arrived late" and "was already
    here".
]=]
function Inventory.WatchPlayerData()
    if Inventory.Watching then
        return
    end
    Inventory.Watching = true

    task.spawn(function()
        local Purchased = Utils.Instance.FindFirstChild(LocalPlayer, "PlayerData.Purchased", 30)

        if not Purchased then
            warn("[Inventory] `PlayerData.Purchased` never replicated to this client. The inventory will stay empty — this is a SaveManager problem, not a UI one.")
            Inventory.Watching = false
            return
        end

        for _, Category in {"Killers", "Skins"} do
            local Folder = Purchased:FindFirstChild(Category)
            if not Folder then
                continue
            end

            Folder.ChildAdded:Connect(function()
                if Inventory.UIInstance then
                    Inventory.ReloadContent()
                end
            end)
            Folder.ChildRemoved:Connect(function()
                if Inventory.UIInstance then
                    Inventory.ReloadContent()
                end
            end)
        end

        -- The build that `Init` couldn't do.
        if Inventory.UIInstance then
            Inventory.ReloadContent()
        end
    end)
end

function Inventory.Open(Time: number)
    --[[
        `Utils.Character.GetRole` rather than `LocalPlayer.Character.Role`.

        The old form THREW twice over: `LocalPlayer.Character` is nil between death and
        respawn, and indexing a Model for a `Role` child that hasn't replicated yet is an
        error in Roblox, not a nil. Either one killed the click — the menu button did
        nothing at all and the only trace was a line in the developer console.
    ]]
    if not Inventory.Enabled or Utils.Character.GetRole(LocalPlayer.Character) ~= "Spectator" or not SideBar.Enabled then
        return "Prevented"
    end

    Inventory.ToggleSkinsMenu(false)
    Inventory.ToggleInfoMenu(false)
    PreviewInstances.Render.Image = ""
    SkinContainer.Parent.Size = Utils.UDim.FullY
    SideContainer.Size = Utils.UDim.FullY
    InfoContainer.Parent.Size = Utils.UDim.FullY
    InventoryContainer.Parent.Size = UDim2.fromScale(0.7, 1)
    Inventory.SkinMenu.Open = false
    if Inventory.EmoteWindow then
        Inventory.EmoteWindow:Hide(true)
        Inventory.EmoteWindow = nil
    end

    TweenService:Create(UI, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Full20Offset}):Play()
    Inventory.Opened = true

    return
end

function Inventory.Close(Time: number)
    if Inventory.EmoteWindow then
        Inventory.EmoteWindow:Hide()
    end
    if Time > 0 then
        TweenService:Create(UI, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        UI.Size = Utils.UDim.Zero
        UI.Visible = false
    end
    Inventory.Opened = false
end

function Inventory.Toggle(toggle: boolean)
    --[[
        Nothing to toggle if the menu never built. Without this, the teardown below ran
        `nil:Destroy()` on the first character spawn and threw before reaching
        `Inventory.Enabled = toggle` at the end — leaving `Enabled` stuck on `true`, which
        then stopped the rebuild branch from ever firing again.
    ]]
    if Inventory.Failed then
        Inventory.Enabled = toggle
        return
    end

    if not Inventory.Enabled and toggle then
        Inventory:Init()
    end
    if not toggle and Inventory.Enabled then
        table.clear(Inventory.ItemModules)
        Inventory.LoadedItems = {
            Killers = {},
            Survivors = {},
            Skins = {},
        }
        Inventory.SelectedItem = {
            Name = "",
            Type = "",
        }
        Inventory.SelectedSection = "Killers"

        if Inventory.UIInstance then
            Inventory.UIInstance:Destroy()
            Inventory.UIInstance = nil
        end

        Inventory.SkinMenu = {
            Open = false,
        }
        if Inventory.EmoteWindow then
            Inventory.EmoteWindow:Hide(true)
            Inventory.EmoteWindow = nil
        end
    end
    Inventory.Enabled = toggle
end

function Inventory.OnCharButtonPress(codeName: string, info: Types.Killer | Types.Survivor, Type: string)
    if not Inventory.Opened then return end

    PreviewInstances.Render.Image = info.Config.Render
    PreviewInstances.Title.Text = info.Config.Name

    if Equipped["Equipped"..Type].Value == codeName then
        Buttons.Equip.Title.Text = "Equipped"
    else
        Buttons.Equip.Title.Text = "Equip"
    end

    Inventory.SelectedItem.Name = codeName
    Inventory.SelectedItem.Type = Type

    TweenService:Create(SideContainer, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Sizes.SideBar}):Play()
end

function Inventory.ReloadContent()
    --[=[
        WHY THE KILLER LIST CAME UP EMPTY.

        This line used to be `LocalPlayer.PlayerData.Purchased`, and that is a THROW rather
        than a nil whenever `PlayerData` isn't there yet — indexing an Instance for a child
        that doesn't exist is an error in Roblox.

        And it usually isn't there yet. `SaveManager` builds `PlayerData` from a DataStore
        call and only then parents it onto the player; `Inventory:Init` runs the instant
        `PlayerInitter` reaches it, which on a joining client is long before any of that
        has come back. So `ReloadContent` threw on its first line, `PlayerInitter`'s pcall
        swallowed it into a console warning, and the player was left with an inventory that
        had built its whole UI and then filled in nothing.

        That's the exact symptom: the menu opens, the tabs work, and there are no killers
        in it. The UI was never broken — the data simply hadn't arrived and nothing ever
        went back to look again.

        `Utils.PlayerData` waits, and `Inventory.WatchPlayerData` (called from `Init`)
        rebuilds the list whenever a purchase lands, so the cards also appear the moment
        somebody buys something instead of only on the next rebuild.
    ]=]
    --[[
        A timeout of `0` here, so this NEVER yields.

        `ReloadContent` is called from `Init`, which runs inside `PlayerInitter`'s
        sequential loop with the loading screen up — blocking it to wait on a DataStore
        round trip would hold up every module after it. The waiting is `WatchPlayerData`'s
        job, on its own thread, and it calls back here when the data lands.
    ]]
    local BoughtItems = Utils.Instance.FindFirstChild(LocalPlayer, "PlayerData.Purchased", 0)

    if not BoughtItems or not BoughtItems:FindFirstChild("Killers") then
        print("[Inventory] `PlayerData.Purchased` hasn't replicated yet — the killer list will build itself as soon as it does.")
        return
    end

    --Killer frame reloading

    local Ordered = {}
    local LO = 0

    local function SetupCard(module, Type: "Killer" | "Survivor")
        local name = module.Name

        --[[
            `LO` is the sort key and nothing was ever incrementing it, so every card in the
            list was built with `LayoutOrder = 0` and the sort done just above — cheapest
            first, by name inside a price tie — was thrown away by the layout.
        ]]
        LO += 1

        if Inventory.LoadedItems[Type.."s"][name] then
            Inventory.LoadedItems[Type.."s"][name].LayoutOrder = LO
            return
        end
        
        local Module = Utils.Instance.GetCharacterModule(Type, name)
        if not Module then
            warn(`[Inventory.ReloadContent()]: Couldn't display card for {Type:lower()} "{name}", as their module doesn't exist! Ignoring for now...`)
            return
        end

        local Info = require(Module)

		local Card = Templates.CardTemplate:Clone()
		local Container = Card.Container
		Card.Name = name
		Card.LayoutOrder = LO
		Card.Parent = Type == "Killer" and KillerContainer or SurvivorContainer
		Container.Title.Text = Info.Config.Name
		Container.CharacterRender.Image = Info.Config.Render

        if Info.Config.CardFrame then
            Container.Outline.Image = Info.Config.CardFrame.Image or Container.Outline.Image
            Container.Outline.Size = Info.Config.CardFrame.Size or Container.Outline.Size
        end

        Inventory.ItemModules[Type.."s"] = Inventory.ItemModules[Type.."s"] or {}

		Inventory.LoadedItems[Type.."s"][name] = Card
		Inventory.ItemModules[Type.."s"][name] = Info

		Container.Interact.MouseEnter:Connect(function()
            TweenService:Create(Container, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Size = UDim2.fromScale(1.065, 1.065)
            }):Play()
			Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, { Volume = 0.2 })
		end)

		Container.Interact.MouseLeave:Connect(function()
            TweenService:Create(Container, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Size = Utils.UDim.Full
            }):Play()
			Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, { Volume = 0.2 })
		end)

        Container.Interact.MouseButton1Click:Connect(function()
			if Inventory.SkinMenu.Open then
				return
			end
			Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, { Volume = 0.8 })
			Inventory.OnCharButtonPress(name, Info, Type)
        end)

        if Info.Config.Origin and Info.Config.Origin.Icon then
            Container.Origin.Visible = true
            Container.Origin.Image = Info.Config.Origin.Icon

            local TooltipAvailable = Info.Config.Origin.TooltipText ~= nil

            Container.Origin.MouseEnter:Connect(function()
                if TooltipAvailable then
                    Tooltip.New(Info.Config.Origin.TooltipText)
                end

                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
            end)
            Container.Origin.MouseLeave:Connect(function()
                if TooltipAvailable then
                    Tooltip.New()
                end

                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
            end)
        else
            Container.Origin.Visible = false
        end
    end

    local function SortTableByPriceAndName(TableToSort)
        table.sort(TableToSort, function(a, b)
            local Modules = {
                A = require(a),
                B = require(b),
            }

            return
                Modules.A.Config.Price == Modules.B.Config.Price and a.Name < b.Name
                or Modules.A.Config.Price < Modules.B.Config.Price
        end)
    end

    local function SetupBatch(Type: "Killer" | "Survivor")
        Ordered = {}
        LO = 0

        for _, module in BoughtItems[Type.."s"]:GetChildren() do
            local CharacterModule = Utils.Instance.GetCharacterModule(Type, module.Name, nil, false)

            --[[
                `GetCharacterModule` returns nil for a character that no longer exists, and
                `table.insert(t, nil)` THROWS in Luau.

                So one stale entry in `Purchased` — a character that was removed, renamed,
                or never existed — took down the whole of `ReloadContent`. And because the
                Survivor batch used to run first, a bad survivor meant the KILLER list
                never rendered at all: the inventory just came up empty with no error the
                player could see.
            ]]
            if CharacterModule then
                table.insert(Ordered, CharacterModule)
            else
                warn("[Inventory.ReloadContent()]: \""..module.Name.."\" is in Purchased."..Type.."s but has no module. Skipping it.")
            end
        end

        SortTableByPriceAndName(Ordered)

        for _, module in ipairs(Ordered) do
            SetupCard(module, Type)
        end
    end

    --[[
        Killers only. There are no survivors in Counterattack — everyone is a killer — so
        the survivor list has nothing to show and every entry in it is dead weight.

        Each batch is its own `pcall` so that a future second category can never take the
        killer list down with it again.
    ]]
    local Success, Err = pcall(SetupBatch, "Killer")
    if not Success then
        warn("[Inventory.ReloadContent()]: the killer list failed to build: "..tostring(Err))
    end

    --[[
        Deliberately a plain `print`, and deliberately noisy.

        An empty killer tab has several possible causes that look identical on screen —
        nothing purchased, modules missing, the batch erroring, or the container being
        invisible. This line separates them at a glance: it says how many cards exist, how
        many entries were in `Purchased`, and whether the frame they live in is actually
        being shown.
    ]]
    local CardCount = 0
    for _ in Inventory.LoadedItems.Killers do
        CardCount += 1
    end

    print(("[Inventory] %d killer card(s) built from %d purchased entr(ies). Container visible: %s. Section: %s.")
        :format(
            CardCount,
            #BoughtItems.Killers:GetChildren(),
            tostring(KillerContainer.Visible),
            tostring(Inventory.SelectedSection)
        ))

    Inventory.CheckEquipLabels()
end

return Inventory
