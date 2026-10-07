local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local SideBar = require(script.Parent.SideBar)
local Types = require(ReplicatedStorage.Classes.Types)
local Tooltip = require(ReplicatedStorage.Classes.Tooltip)
local CharacterRegistry = require(ReplicatedStorage.Modules.CharacterRegistry)
local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local BuyWindow = require(script.BuyWindow)

local CharacterFolder = ReplicatedStorage.Assets.Characters

local Shop = {
    Opened = false,
    Enabled = true,
    --[=[
        Set when the menu could not be built at all.

        `SideBar` reads this to decide whether the shop gets a button, and `Shop.Toggle`
        reads it to avoid tearing down a UI that was never built. It used to be absent
        entirely, so `SideBar`'s `if Menu.Failed then return end` guard was always false for
        the shop and a place missing `ShopUI` got a button that threw when clicked.
    ]=]
    Failed = false,
    --- Guards against `Init` running twice and leaving two shop frames in the PlayerGui.
    Built = false,
    SelectedSection = "Survivors",
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
        Emotes = {},
        Skins = {},
    },
    ItemModules = {},
    SelectedItem = {
        Name = "",
        Type = "",
        Card = nil,
    },
    UIInstance = nil,
    BuyWindow = nil,

    PreviewsEnabled = true,
}

local LocalPlayer = Players.LocalPlayer

local UIParent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "Menus")

local Buttons = {
    Purchase = nil,
    Info = nil,
    Skins = nil,
    --- Built at runtime; the Studio prefab has no Equip button. See `Shop._BuildEquipButton`.
    Equip = nil,
}

local Sizes = {
    SideBar = UDim2.fromScale(0.3, 1),
    ClosedSideBar = Utils.UDim.FullY,
}

local PreviewInstances = {
    Render = nil,
    Title = nil,
    EmotePreview = nil,
}

local Templates = {
    CardTemplate = nil,
    Header = nil,
    Text = nil,
    Quote = nil,
    Separator = nil,
    InfoSection = nil,
}

local UI
local ShopContainer
local KillerContainer
local SurvivorContainer
local EmoteContainer

local SideContainer
local SkinContainer
local InfoContainer
local PreviewContainer
local ButtonsContainer

local EmoteRig

local Sections = {}

local LoadedEmoteTracks = {}

--[=[
    Orders the skin cards: unowned first, each group cheapest-first then alphabetical.

    THE PRICES ARE READ BEFORE THE SORT, NOT INSIDE IT.

    This used to `require` two skin modules inside the `table.sort` comparator, which is
    the same mistake the character list made and has the same two consequences: a skin
    whose module fails to load throws out of the sort and loses the whole ordering, and a
    skin that has been removed makes `GetCharacterModule` return `nil` so `require(nil)`
    throws. It also re-required both modules on every single comparison, which for twenty
    skins is several hundred requires to sort twenty cards.

    Reading each price once into a table first fixes all three.
]=]
function Shop.ReorderSkins()
    local Character = Shop.SelectedItem.Name
    local Kind = Shop.SelectedItem.Type

    if #Character <= 0 or #Kind <= 0 then
        return
    end

    local Prices: {[string]: number} = {}

    local function PriceOf(name: string): number
        if Prices[name] then
            return Prices[name]
        end

        local Price = math.huge

        local Module = Utils.Instance.GetCharacterModule(Kind, Character, name, false)
        if Module then
            local Ok, Loaded = pcall(require, Module)
            if Ok and type(Loaded) == "table" and Loaded.Config then
                Price = tonumber(Loaded.Config.Price) or 0
            end
        end

        Prices[name] = Price
        return Price
    end

    local Ordered = {
        Owned = {},
        Unowned = {},
    }

    for name, skin in Shop.LoadedItems.Skins do
        -- Warm the cache while we're already walking the list, so the comparator below
        -- only ever reads from `Prices`.
        PriceOf(name)

        if Utils.PlayerData.GetPlayerOwned(LocalPlayer, "Skins."..Character.."."..name) then
            table.insert(Ordered.Owned, skin)
        else
            table.insert(Ordered.Unowned, skin)
        end
    end

    local function ByPriceThenName(a, b): boolean
        local PriceA, PriceB = PriceOf(a.Name), PriceOf(b.Name)

        if PriceA == PriceB then
            return a.Name < b.Name
        end
        return PriceA < PriceB
    end

    table.sort(Ordered.Owned, ByPriceThenName)
    table.sort(Ordered.Unowned, ByPriceThenName)

    local LO = 0

    for _, skin in ipairs(Ordered.Unowned) do
        LO += 1
        skin.LayoutOrder = LO
    end
    for _, skin in ipairs(Ordered.Owned) do
        LO += 1
        skin.LayoutOrder = LO
    end
end

function Shop.ToggleSkinsMenu(Open: boolean?)
    if Open == nil then
        Open = not Shop.SkinMenu.Open
    end
    
    if Open then
        Shop.ToggleInfoMenu(false)

        local Skins = ReplicatedStorage.Characters.Skins[Shop.SelectedItem.Type.."s"]:FindFirstChild(Shop.SelectedItem.Name)
        if not Skins then
            return
        end

        --if there are no visible skins, return
        local VisibleSkins = Skins:GetChildren()
        for skinIndex = #VisibleSkins, 1, -1 do
            local skin = VisibleSkins[skinIndex]
            if not (skin:HasTag("Dev") or skin:HasTag("Milestone")) then
                continue
            end

            --[[
                This read `table.remove(VisibleSkins[skinIndex])`, which passes the
                INSTANCE as `table.remove`'s first argument and throws
                "table expected, got Instance".

                So opening the Skins menu for any character that has even one Dev or
                Milestone skin errored outright, and because the throw happened before the
                menu was shown, the Skins button simply did nothing for those characters.
            ]]
            table.remove(VisibleSkins, skinIndex)
        end

        if #VisibleSkins <= 0 then
            return
        end

        for _, skin in Shop.LoadedItems.Skins do
            if SkinContainer.SkinPreviewCache:FindFirstChild(skin.Name) then
                SkinContainer.SkinPreviewCache[skin.Name]:Destroy()
            end

            skin:Destroy()
        end

        table.clear(Shop.LoadedItems.Skins)
        Shop.ItemModules.Skins = Shop.ItemModules.Skins or {}
        table.clear(Shop.ItemModules.Skins)

        local function CheckSkinOwnLabels()
            for name, skin in Shop.LoadedItems.Skins do
                if Utils.PlayerData.GetPlayerOwned(LocalPlayer, "Skins."..Shop.SelectedItem.Name.."."..name) then
                    skin.Container.Owned.BackgroundTransparency = 0.55
                    skin.Container.Owned.TextLabel.TextTransparency = 0
                end
            end
        end

        -- Through the registry, which has already required the module once and will
        -- return the folder name rather than throwing if the character has gone away.
        SkinContainer.Parent.Label.TextLabel.Text =
            CharacterRegistry.GetDisplayName(Shop.SelectedItem.Type, Shop.SelectedItem.Name).." Skins"

        local CanMakePreviews = Shop.PreviewsEnabled and Utils.PlayerData.GetPlayerSetting(LocalPlayer, "Performance.SkinPreviews")
        for _, Skin in VisibleSkins do
            local Module = Utils.Instance.GetCharacterModule(Shop.SelectedItem.Type, Shop.SelectedItem.Name, Skin.Name)

            if Module:HasTag("Dev") or Module:HasTag("Milestone") then
                continue
            end

            local Info = require(Module)
            local name = Module.Name

            local Card = Templates.CardTemplate:Clone()
            Card.Name = name
            local Container = Card.Container
            Card.Parent = SkinContainer.ScrollingFrame
            Container.Title.Text = Info.Config.Name
            Container.CharacterRender.Image = Info.Config.Render
            Container.Price.Text = Info.Config.Price > 0 and tostring(Info.Config.Price).."$" or "FREE"

            if Info.Config.CardFrame then
                Container.Outline.Image = Info.Config.CardFrame.Image or Container.Outline.Image
                Container.Outline.Size = Info.Config.CardFrame.Size or Container.Outline.Size
            end

            local SkinPreview = Container.Preview.ViewportFrame
            if CanMakePreviews then
                task.defer(function()
                    local SkinModel = Utils.Instance.FindFirstChild(CharacterFolder, "Skins."..Shop.SelectedItem.Type.."."..Shop.SelectedItem.Name.."."..name, 0)
                    if not SkinModel then
                        warn("[Shop.ToggleSkinsMenu]: Item preview model can't be found! Make sure it's located in ReplicatedStorage/Characters/Skins/"..Shop.SelectedItem.Type.."/"..Shop.SelectedItem.Name.."s! ("..name..")")
                        return
                    end

                    -- i'm going fucking insane. -dys
                    local Camera = Instance.new("Camera")
                    Camera.FieldOfView = 10
                    Camera.Parent = SkinPreview
                    local WorldModel = Instance.new("WorldModel")
                    WorldModel.Parent = Camera
                    SkinPreview.CurrentCamera = Camera

                    SkinModel = SkinModel:Clone()
                    if not SkinModel.Humanoid:FindFirstChildWhichIsA("Animator") then
                        Instance.new("Animator").Parent = SkinModel.Humanoid
                    end
                    Utils.Character.GetRootPart(SkinModel).Anchored = true
                    SkinModel:PivotTo(CFrame.new(0, 10000, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(180), 0))

                    Camera.CFrame = CFrame.new(0, 10000, 6 * SkinModel:GetExtentsSize().Y)

                    SkinModel.Parent = SkinContainer.SkinPreviewCache

                    Utils.Character.LoadAnimationFromID(SkinModel, Info.Config.AnimationIDs.PreviewAnimation or Info.Config.AnimationIDs.IdleAnimation, false):Play(0)

                    Utils.Instance.ObserveProperty(SkinPreview, "ImageTransparency", function(value: number)
                        if value < 1 then
                            if SkinModel.Parent ~= WorldModel then
                                SkinModel.Parent = WorldModel
                            end
                        elseif SkinModel.Parent ~= SkinContainer.SkinPreviewCache then
                            SkinModel.Parent = SkinContainer.SkinPreviewCache
                        end
                    end)
                end)
            end

            --create tables if not there
            Shop.ItemModules.Skins = Shop.ItemModules.Skins or {}
            Shop.ItemModules.Skins[Shop.SelectedItem.Name] = Shop.ItemModules.Skins[Shop.SelectedItem.Name] or {}

            Shop.LoadedItems.Skins[name] = Card
            Shop.ItemModules.Skins[Shop.SelectedItem.Name][name] = Info

            -- reminder that these connections disconnect automatically when the parent is destroyed! -dys
            Container.Interact.MouseEnter:Connect(function()
                if CanMakePreviews then
                    TweenService:Create(SkinPreview, TweenInfo.new(0.25), {
                        ImageTransparency = 0
                    }):Play()
                    TweenService:Create(SkinPreview.Parent, TweenInfo.new(0.25), {
                        BackgroundTransparency = 0
                    }):Play()
                end
                TweenService:Create(Container, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                    Size = UDim2.fromScale(1.065, 1.065)
                }):Play()
                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
            end)
            Container.Interact.MouseLeave:Connect(function()
                if CanMakePreviews then
                    TweenService:Create(SkinPreview, TweenInfo.new(0.25), {
                        ImageTransparency = 1
                    }):Play()
                    TweenService:Create(SkinPreview.Parent, TweenInfo.new(0.25), {
                        BackgroundTransparency = 1
                    }):Play()
                end
                TweenService:Create(Container, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                    Size = Utils.UDim.Full
                }):Play()
                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
            end)
            Container.Interact.MouseButton1Click:Connect(function()
                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})
                if Container.Owned.BackgroundTransparency >= 1 then
                    Shop.CreateBuyWindow(Skin, true, UI, Card)
                end

                CheckSkinOwnLabels()
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

        CheckSkinOwnLabels()

        Shop.ReorderSkins()

        TweenService:Create(ShopContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.FullY}):Play()
        TweenService:Create(SkinContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.7, 1)}):Play()

        Shop.SkinMenu.Open = true
    else
        TweenService:Create(ShopContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.7, 1)}):Play()
        TweenService:Create(SkinContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.FullY}):Play()

        Shop.SkinMenu.Open = false
    end

    TweenService:Create(InfoContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.FullY}):Play()
end

function Shop.ToggleInfoMenu(Open: boolean?)
    if Open == nil then
        Open = not Shop.InfoMenu.Open
    end

    if Open then
        Shop.ToggleSkinsMenu(false)
    end

    if Open then
        for _, Child in InfoContainer:GetChildren() do
            if not Child:IsA("UIComponent") then
                Child:Destroy()
            end
        end

        --[[
            From the registry's already-loaded copy, so a character whose module fails to
            load — or one selected and then removed — leaves the page empty instead of
            throwing inside the menu transition.
        ]]
        local Entry = CharacterRegistry.Get(Shop.SelectedItem.Type, Shop.SelectedItem.Name)
        local CharacterInfo = Entry and Entry.Character or nil

        if not CharacterInfo or not CharacterInfo.Config or not CharacterInfo.Config.Description then
            return
        end

        Shop.InfoMenu.Open = true

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
                --[[
                    `Text`, not `Section.Text`.

                    `Section.Text` may be a TABLE of paragraphs — the `Text` local a few
                    lines above is the joined version, and that is what the `Text` branch
                    below already uses. This branch used the raw field, so a Header, Quote
                    or Separator written as a list assigned a table to a `TextLabel.Text`
                    and threw, taking the whole More Info page with it.
                ]]
                (Section.Type == "Separator" and Pref.Title or Pref).Text = Text
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
        
            while task.wait() and Shop.InfoMenu.Open do
                local ui = Shop.UIInstance
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

        TweenService:Create(ShopContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.FullY}):Play()
        TweenService:Create(InfoContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.7, 1)}):Play()
    else
        TweenService:Create(ShopContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.7, 1)}):Play()
        TweenService:Create(InfoContainer.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.FullY}):Play()

        Shop.InfoMenu.Open = false
    end
end

local function SwitchSection(sectionName: string)
    if not Shop.Opened or Shop.SelectedSection == sectionName then return end

    TweenService:Create(SideContainer, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0, 1)}):Play()

    if workspace.Sounds:FindFirstChild("EmotePreview") then
        workspace.Sounds.EmotePreview:Destroy()
    end

    for _, section in Sections do
        section.Visible = section.Name == sectionName
    end

    Shop.SelectedSection = sectionName
end

--------------------------------------------------------------------------------
-- OWNERSHIP, EQUIPPING AND CARD STATE
--------------------------------------------------------------------------------

--[=[
    Builds the Equip button by cloning the Purchase button.

    The `ShopUI` prefab has Purchase, Skins and MoreInfo and no Equip. Cloning rather than
    constructing means it inherits the panel's exact styling, layout order and size
    constraints from whatever that place's Purchase button looks like — so this cannot end
    up as an obviously bolted-on rectangle in somebody's restyled menu.

    @return The button, or `nil` if there was no Purchase button to copy.
]=]
function Shop._BuildEquipButton(container: Instance): Instance?
    local Existing = container:FindFirstChild("Equip")
    if Existing then
        return Existing
    end

    local Source = container:FindFirstChild("Purchase")
    if not Source then
        warn("[Shop] No Purchase button to model the Equip button on, so the shop gets no Equip button. Equipping still works from the inventory.")
        return nil
    end

    local Button = Source:Clone()
    Button.Name = "Equip"
    -- Immediately after Purchase in the panel's list layout.
    if Button:IsA("GuiObject") then
        Button.LayoutOrder = Source.LayoutOrder + 1
    end

    local Title = Button:FindFirstChild("Title")
    if Title then
        Title.Text = "Equip"
    end

    Button.Parent = container

    return Button
end

--- The module name currently equipped in a slot, or `""`.
function Shop.GetEquipped(kind: string): string
    if kind ~= "Killer" and kind ~= "Survivor" then
        return ""
    end

    return Utils.PlayerData.GetPlayerEquipped(LocalPlayer, kind) or ""
end

--[=[
    Paints one card with its current ownership and equipped state.

    All three states in one place, because they were previously spread across `SetupCard`
    (owned, on creation only), `BuyWindow` (owned, on purchase) and nowhere at all
    (equipped) — so the card you were looking at could disagree with your save data in
    three different directions.
]=]
function Shop._PaintCard(card: Instance?, kind: string, name: string)
    if not card then
        return
    end

    local Container = card:FindFirstChild("Container")
    local Owned = Container and Container:FindFirstChild("Owned")
    if not Owned then
        return
    end

    local Label = Owned:FindFirstChild("TextLabel")

    -- Free characters belong to everybody; the data has no entry for them.
    local IsOwned = CharacterRegistry.IsFree(kind, name)
        or Utils.PlayerData.GetPlayerOwned(LocalPlayer, (CharacterRegistry.Kinds[kind] and CharacterRegistry.Kinds[kind].Plural or kind.."s").."."..name) and true
        or false

    local IsEquipped = IsOwned and Shop.GetEquipped(kind) == name

    if IsEquipped then
        Owned.BackgroundTransparency = 0.35
        Owned.BackgroundColor3 = Color3.fromRGB(60, 150, 85)
        if Label then
            Label.Text = "EQUIPPED"
            Label.TextTransparency = 0
        end
    elseif IsOwned then
        Owned.BackgroundTransparency = 0.55
        Owned.BackgroundColor3 = Shop._OwnedColour or Owned.BackgroundColor3
        if Label then
            Label.Text = Shop._OwnedText or "OWNED"
            Label.TextTransparency = 0
        end
    else
        Owned.BackgroundTransparency = 1
        Owned.BackgroundColor3 = Shop._OwnedColour or Owned.BackgroundColor3
        if Label then
            Label.Text = Shop._OwnedText or "OWNED"
            Label.TextTransparency = 1
        end
    end

    --[[
        LOCKED, VISIBLY.

        A greyed render is the clearest "you don't have this" there is, and it reads at a
        glance across a grid of forty cards in a way a small corner badge does not.
    ]]
    local Render = Container:FindFirstChild("CharacterRender")
    if Render then
        Render.ImageColor3 = IsOwned and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(125, 125, 130)
    end
end

--- Repaints every card and refreshes the side panel's buttons.
function Shop.RefreshOwnership()
    if Shop.Failed or not Shop.UIInstance then
        return
    end

    for Kind in CharacterRegistry.Kinds do
        local Loaded = Shop.LoadedItems[Kind.."s"]
        if not Loaded then
            continue
        end

        for Name, Card in Loaded do
            Shop._PaintCard(Card, Kind, Name)
        end
    end

    Shop.UpdateSideButtons()
end

--[=[
    Sets the Purchase and Equip buttons to match whatever is selected.

    Purchase says "Purchased" once you own it, Equip says "Equipped" once it's your
    loadout, and both are hidden when they would do nothing — an Equip button next to an
    emote has no meaning, since emotes go in numbered slots and that lives in the
    inventory's emote window.
]=]
function Shop.UpdateSideButtons()
    local Name = Shop.SelectedItem.Name
    local Kind = Shop.SelectedItem.Type

    if not Buttons.Purchase or #Name <= 0 or #Kind <= 0 then
        return
    end

    local Plural = CharacterRegistry.Kinds[Kind] and CharacterRegistry.Kinds[Kind].Plural or (Kind.."s")
    local IsOwned = CharacterRegistry.IsFree(Kind, Name)
        or Utils.PlayerData.GetPlayerOwned(LocalPlayer, Plural.."."..Name) and true
        or false

    Buttons.Purchase.Title.Text = IsOwned and "Purchased" or "Purchase"

    if not Buttons.Equip then
        return
    end

    if Kind == "Emote" then
        Buttons.Equip.Visible = false
        return
    end

    Buttons.Equip.Visible = IsOwned
    Buttons.Equip.Title.Text = Shop.GetEquipped(Kind) == Name and "Equipped" or "Equip"
end

--[=[
    Asks the server to equip whatever is selected.

    The client does the two checks it can honestly do — do we own it, is it already equipped
    — purely to avoid a pointless round trip. `RemoteHandler.EquipItem` repeats both and
    adds an existence check, and its answer is the one that counts.
]=]
function Shop.EquipSelected()
    if not Shop.Opened then
        return
    end

    local Name = Shop.SelectedItem.Name
    local Kind = Shop.SelectedItem.Type

    if #Name <= 0 or (Kind ~= "Killer" and Kind ~= "Survivor") then
        return
    end

    if Shop.GetEquipped(Kind) == Name then
        return
    end

    local Plural = CharacterRegistry.Kinds[Kind].Plural
    if not CharacterRegistry.IsFree(Kind, Name) and not Utils.PlayerData.GetPlayerOwned(LocalPlayer, Plural.."."..Name) then
        return
    end

    Network:FireServerConnection("EquipItem", "REMOTE_EVENT", Name, Kind)

    --[[
        Show it immediately, then let the real value correct it.

        The slot's `Changed` listener set up in `Init` calls `RefreshOwnership`, so if the
        server refuses the optimistic label is replaced within a frame or two by the truth.
        Waiting for the round trip before showing anything made the button feel broken on a
        bad connection.
    ]]
    if Buttons.Equip then
        Buttons.Equip.Title.Text = "Equipped"
    end
end

function Shop:Init()
    --[=[
        REFUSE TO BUILD RATHER THAN THROW HALFWAY THROUGH BUILDING.

        This opened with `Utils.Instance.FindFirstChild(script, "ShopUI"):Clone()`. When the
        prefab isn't there — and it is a Studio asset, so "isn't there" is a normal state for
        a fresh checkout — that indexed `nil` and threw, from inside `PlayerInitter`'s loop.
        The shop then had no UI, no `Failed` flag to say so, and `SideBar` gave it a button
        anyway.

        Checking first turns "the menu is broken in a way nobody can diagnose" into one
        actionable warning and a missing button. `Inventory` already did exactly this; the
        shop is now consistent with it.
    ]=]
    if Shop.Built and Shop.UIInstance and Shop.UIInstance.Parent then
        -- `PlayerInitter` calls `Init` on every UI module at startup and `Shop.Toggle`
        -- calls it again on every spectator spawn. Building twice would leave two shop
        -- frames stacked in the PlayerGui, with the clicks landing on the invisible one.
        return
    end

    local Prefab = Utils.Instance.FindFirstChild(script, "ShopUI", 10)
    local TemplateFolder = Utils.Instance.FindFirstChild(script, "Templates", 10)
    local CardPrefab = TemplateFolder and TemplateFolder:FindFirstChild("CardTemplate")

    if not Prefab or not TemplateFolder or not CardPrefab then
        local Missing = {}
        if not Prefab then table.insert(Missing, "ShopUI") end
        if not TemplateFolder then table.insert(Missing, "Templates") end
        if TemplateFolder and not CardPrefab then table.insert(Missing, "Templates.CardTemplate") end

        warn(
            "[Shop] Can't build the shop — these instances are missing from "..
            "StarterPlayer.StarterPlayerScripts.UI.Shop: "..table.concat(Missing, ", ")..".\n"..
            "     These are Studio assets. `ShopUI.rbxmx` and `Templates.rbxmx` live next to this "..
            "script in the repository; if they're missing here, re-sync Rojo.\n"..
            "     The buy confirmation window does NOT need an asset — it builds itself."
        )

        Shop.Failed = true
        if Shop.Button then
            Shop.Button.Visible = false
        end

        return
    end

    Shop.Failed = false
    if Shop.Button then
        Shop.Button.Visible = true
    end

    UI = Prefab:Clone()
    UI.Size = Utils.UDim.Zero
    UI.Visible = false
    UI.Parent = UIParent
    Shop.UIInstance = UI
    Shop.Built = true

    local Container = UI.Container
    ShopContainer = Container.ShopContainer.Content
    KillerContainer = ShopContainer.Killers
    SurvivorContainer = ShopContainer.Survivors
    EmoteContainer = ShopContainer.Emotes
    SkinContainer = Container.SkinsContainer.Content
    InfoContainer = Container.InfoContainer.Contents

    Sections = {
        KillerContainer,
        SurvivorContainer,
        EmoteContainer,
    }

    for _, button in Container.ShopContainer.Topbar:GetChildren() do
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

    local templates = TemplateFolder
    Templates.CardTemplate = Templates.CardTemplate or templates.CardTemplate
    Templates.Header = Templates.Header or templates.Header
    Templates.Text = Templates.Text or templates.TextContainer
    Templates.Quote = Templates.Quote or templates.Quote
    Templates.Separator = Templates.Separator or templates.Separator
    Templates.InfoSection = Templates.InfoSection or templates.InfoSection

    --[[
        Remember what the OWNED badge looks like before anything repaints it.

        `Shop._PaintCard` rewrites that badge to say EQUIPPED, and it needs somewhere to
        restore from when a card stops being the equipped one. Reading it off the untouched
        template rather than hardcoding "OWNED" means a place that renamed or recoloured the
        badge keeps its own wording.
    ]]
    do
        local Badge = Templates.CardTemplate
            and Templates.CardTemplate:FindFirstChild("Container")
            and Templates.CardTemplate.Container:FindFirstChild("Owned")

        if Badge then
            Shop._OwnedColour = Badge.BackgroundColor3
            local Label = Badge:FindFirstChild("TextLabel")
            Shop._OwnedText = Label and Label.Text or "OWNED"
        end
    end

    SideContainer = Container.SideContainer
    PreviewContainer = SideContainer.PreviewContainer

    PreviewInstances.Render = PreviewContainer.Render
    PreviewInstances.Render.Image = ""
    PreviewInstances.Title = PreviewContainer.Title
    PreviewInstances.EmotePreview = PreviewContainer.Emote
    EmoteRig = PreviewContainer.Emote.EmotePreview.Rig

    ButtonsContainer = SideContainer.ButtonsContainer

    Buttons.Purchase = ButtonsContainer.Purchase
    Buttons.Skins = ButtonsContainer.Skins
    Buttons.Info = ButtonsContainer.MoreInfo
    Buttons.Equip = Shop._BuildEquipButton(ButtonsContainer)

    local JanitorInstance = Janitor.new()
    JanitorInstance:LinkToInstance(UI)

    --[=[
        EQUIP, FROM THE SHOP.

        Buying a killer and then having to close the shop, open the inventory and find it
        again to actually use it is a strange way to end a purchase. There is no Equip button
        in the `ShopUI` prefab, so it's cloned from the Purchase button — which guarantees it
        matches whatever styling that one has, in anybody's place, without shipping another
        asset.

        The equip itself goes through the same `EquipItem` remote the inventory uses, so the
        server validates it exactly the same way. The client is asking, not deciding.
    ]=]
    if Buttons.Equip then
        JanitorInstance:Add(Buttons.Equip.MouseEnter:Connect(function()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
        end))
        JanitorInstance:Add(Buttons.Equip.MouseLeave:Connect(function()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
        end))
        JanitorInstance:Add(Buttons.Equip.MouseButton1Click:Connect(function()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})
            Shop.EquipSelected()
        end))
    end

    --[=[
        Rebuild the cards whenever the player's data changes underneath us.

        Previously the only thing that refreshed ownership was the buy window firing
        `Purchased`. That left three ways to show stale state: a dev grant landing after the
        shop was built, an item bought on another device in the same session, and the save
        data arriving AFTER `Init` ran — which is the common one, because `Init` happens at
        startup and `PlayerData` is parented on a DataStore round trip. The player opened the
        shop and owned nothing.
    ]=]
    task.spawn(function()
        local DataFolder = Utils.PlayerData.GetDataFolder(LocalPlayer, 30)
        if not DataFolder then
            return
        end

        local Purchased = DataFolder:FindFirstChild("Purchased")
        local Equipped = DataFolder:FindFirstChild("Equipped")

        if Purchased then
            -- `DescendantAdded`, not `ChildAdded`: ownership entries live one level down,
            -- inside `Purchased.Killers`, and skins two levels down.
            JanitorInstance:Add(Purchased.DescendantAdded:Connect(function()
                Shop.RefreshOwnership()
            end))
        end

        if Equipped then
            for _, Slot: Instance in Equipped:GetChildren() do
                if Slot:IsA("StringValue") then
                    JanitorInstance:Add(Slot.Changed:Connect(function()
                        Shop.RefreshOwnership()
                    end))
                end
            end
        end

        -- And once now, in case any of it was already there.
        Shop.RefreshOwnership()
    end)

    JanitorInstance:Add(Buttons.Purchase.MouseEnter:Connect(function()
        Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
    end))
    JanitorInstance:Add(Buttons.Purchase.MouseLeave:Connect(function()
        Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
    end))
    JanitorInstance:Add(Buttons.Purchase.MouseButton1Click:Connect(function()
        Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})
        if not Utils.PlayerData.GetPlayerOwned(LocalPlayer, Shop.SelectedItem.Type.."s."..Shop.SelectedItem.Name) then
            if Shop.SelectedItem.Type == "Emote" then
                Shop.CreateBuyWindow(Utils.Instance.GetEmoteModule(Shop.SelectedItem.Name), false, UI, Shop.SelectedItem.Card)
                return
            end

            Shop.CreateBuyWindow(Utils.Instance.GetCharacterModule(Shop.SelectedItem.Type, Shop.SelectedItem.Name), false, UI, Shop.SelectedItem.Card)
        end
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

        Shop.ToggleSkinsMenu()
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

        Shop.ToggleInfoMenu()
    end))

    Utils.Instance.ObserveProperty(Shop.UIInstance, "Size", function(value: UDim2)
        Shop.UIInstance.Visible = value ~= Utils.UDim.Zero
    end)

    Utils.Instance.ObserveProperty(InfoContainer.Parent, "Size", function(value: UDim2)
        if not Shop.InfoMenu.Open and value.X.Scale < 0.05 and #InfoContainer:GetChildren() > 0 then
            for _, Child in InfoContainer:GetChildren() do
                if not Child:IsA("UIComponent") then
                    Child:Destroy()
                end
            end
        end
    end)
    
    Utils.Instance.ObserveProperty(SkinContainer.Parent, "Size", function(value: UDim2)
        SkinContainer.Parent.Label.TextLabel.Visible = value.X.Scale >= 0.05
    end)

    Shop.ReloadContent(true)
end

function Shop.Open(Time: number)
    --[[
        `Utils.Character.GetRole` rather than `LocalPlayer.Character.Role.Value`.

        The old line indexed `.Role` with a dot, which THROWS when the child isn't there
        rather than returning nil — so `not LocalPlayer.Character.Role` could never guard
        anything, and opening the shop during the window where the lobby body exists but
        `Role` hasn't replicated yet errored instead of being refused. It also indexed
        `LocalPlayer.Character` with no check at all.

        `Shop.Failed` is checked too: a shop with no UI must refuse to open rather than
        reach for `PreviewInstances.Render` a few lines down.
    ]]
    if Shop.Failed or not Shop.Enabled or not Shop.UIInstance or not SideBar.Enabled then
        return "Prevented"
    end

    if Utils.Character.GetRole(LocalPlayer.Character) ~= "Spectator" then
        return "Prevented"
    end

    Shop.ToggleSkinsMenu(false)
    Shop.ToggleInfoMenu(false)
    PreviewInstances.Render.Image = ""
    PreviewInstances.Render.ImageTransparency = 0
    PreviewInstances.EmotePreview.Visible = false
    ButtonsContainer.Skins.Visible = true
    ButtonsContainer.MoreInfo.Visible = true

    -- Hidden until something is selected, since it is cloned from the Purchase button and
    -- would otherwise inherit its visibility and sit there doing nothing.
    if Buttons.Equip then
        Buttons.Equip.Visible = false
    end

    for _, emoteTrack in LoadedEmoteTracks do
        if emoteTrack.Animation ~= nil then
            emoteTrack.Animation:Stop(0)
        else
            for _, EmoteTrack in emoteTrack do
                EmoteTrack.Animation:Stop(0)
            end
        end
    end
    if workspace.Sounds:FindFirstChild("EmotePreview") then
        workspace.Sounds.EmotePreview:Destroy()
    end
    SkinContainer.Parent.Size = Utils.UDim.FullY
    InfoContainer.Parent.Size = Utils.UDim.FullY
    SideContainer.Size = Utils.UDim.FullY
    ShopContainer.Parent.Size = UDim2.fromScale(0.7, 1)
    Shop.SkinMenu.Open = false

    TweenService:Create(UI, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Full20Offset}):Play()
    Shop.Opened = true

    return
end

function Shop.Close(Time: number)
    if Shop.BuyWindow then
        Shop.BuyWindow:Hide(Time <= 0)
    end
    if workspace.Sounds:FindFirstChild("EmotePreview") then
        workspace.Sounds.EmotePreview:Destroy()
    end
    if Time > 0 then
        TweenService:Create(UI, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        UI.Size = Utils.UDim.Zero
        UI.Visible = false
    end
    Shop.Opened = false
end

function Shop.Toggle(toggle: boolean)
    --[[
        A shop that never built has nothing to toggle.

        Without this the teardown below ran `nil:Destroy()` on the first character spawn in
        a place missing `ShopUI`, and threw BEFORE reaching `Shop.Enabled = toggle` at the
        bottom — which left `Enabled` stuck on `true`, so the rebuild branch at the top
        could never fire again either. One missing asset became a permanently dead menu.
        `Inventory.Toggle` already guards this way.
    ]]
    if Shop.Failed then
        Shop.Enabled = toggle
        return
    end

    if not Shop.Enabled and toggle then
        Shop:Init()
    end

    if not toggle and Shop.Enabled then
        if Shop.BuyWindow then
            Shop.BuyWindow:Hide(true)
        end
        if workspace.Sounds:FindFirstChild("EmotePreview") then
            workspace.Sounds.EmotePreview:Destroy()
        end
        table.clear(Shop.ItemModules)
        Shop.LoadedItems = {
            Killers = {},
            Survivors = {},
            Emotes = {},
            Skins = {},
        }
        Shop.SelectedItem = {
            Name = "",
            Type = "",
            Card = nil,
        }
        Shop.SelectedSection = "Survivors"

        if Shop.UIInstance then
            Shop.UIInstance:Destroy()
        end

        --[[
            CLEAR THE REFERENCES, NOT JUST THE INSTANCE.

            `Shop.UIInstance` was left pointing at a destroyed frame. `SideBar` used to
            test `if not Menu.UIInstance then return end` to decide whether a menu could be
            toggled, and a destroyed instance is still truthy — so the Shop happened to
            keep working by accident while the Inventory, which cleared its reference
            properly, was skipped forever after its first teardown. That was fixed in
            `SideBar` by testing `Failed` instead; this clears the dangling reference so
            nothing else can come to depend on it.

            `Built` has to be cleared too, or `Init`'s double-build guard would refuse the
            rebuild that `Toggle(true)` is supposed to perform.
        ]]
        Shop.UIInstance = nil
        Shop.Built = false
        Shop.BuyWindow = nil
        Shop.SkinMenu = {
            Open = false,
            ShowingCharacter = "",
        }
        Shop.InfoMenu = {
            Open = false,
            ShowingCharacter = "",
        }

        -- These all pointed into the destroyed clone. Buttons especially: `Buttons.Equip`
        -- is rebuilt per `Init`, and a stale one would be written to instead of the live
        -- one.
        Buttons.Purchase, Buttons.Skins, Buttons.Info, Buttons.Equip = nil, nil, nil, nil
        table.clear(LoadedEmoteTracks)
    end

    Shop.Enabled = toggle
end

function Shop.OnCharButtonPress(codeName: string, info: Types.Killer | Types.Survivor | Types.Emote, Module: ModuleScript, Type: string, Card: Frame)
    if not Shop.Opened then
        return
    end

    -- Emote modules keep their fields at the top level rather than under `Config`, and
    -- this function is called for emotes too.
    local Config = info.Config or info

    PreviewInstances.Render.Image = Config.Render or ""
    PreviewInstances.Title.Text = Config.Name or codeName

    ButtonsContainer.CurrentItemPrice.Text = (tonumber(Config.Price) or 0) > 0 and tostring(Config.Price).."$" or "FREE"

    Shop.SelectedItem.Name = codeName
    Shop.SelectedItem.Type = Type
    Shop.SelectedItem.Card = Card

    -- Selection changed, so the Purchase and Equip labels have to follow it. This also
    -- replaces the inline ownership check that used to live here, so there is now one
    -- place that decides what those two buttons say.
    Shop.UpdateSideButtons()

    TweenService:Create(SideContainer, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Sizes.SideBar}):Play()

    if Type == "Emote" then
        PreviewInstances.EmotePreview.Visible = true
        PreviewInstances.Render.ImageTransparency = 1
        ButtonsContainer.Skins.Visible = false
        ButtonsContainer.MoreInfo.Visible = false
        
        if workspace.Sounds:FindFirstChild("EmotePreview") then
            workspace.Sounds.EmotePreview:Destroy()
        end
        for _, emoteTrack in LoadedEmoteTracks do
            if emoteTrack.Animation ~= nil then
                emoteTrack.Animation:Stop(0)
            else
                for _, EmoteTrack in emoteTrack do
                    EmoteTrack.Animation:Stop(0)
                end
            end
        end

        local AnimTrack = LoadedEmoteTracks[Module.Name]
        if not AnimTrack then
            local AnimIDs = info.AnimationIds
            if typeof(AnimIDs) == "string" then
                LoadedEmoteTracks[Module.Name] = {
                    Animation = Utils.Character.LoadAnimationFromID(EmoteRig, AnimIDs),
                    Sound = nil,
                }
            else
                LoadedEmoteTracks[Module.Name] = {}

                for _, ID: string in AnimIDs do
                    LoadedEmoteTracks[Module.Name][ID] = {
                        Animation = Utils.Character.LoadAnimationFromID(EmoteRig, ID),
                        Sound = nil,
                    }
                end
            end

            if info.SoundIds then
                if typeof(info.SoundIds) == "string" then
                    if typeof(AnimIDs) == "string" then
                        LoadedEmoteTracks[Module.Name].Sound = info.SoundIds
                    else
                        for _, id in AnimIDs do
                            LoadedEmoteTracks[Module.Name][id].Sound = info.SoundIds
                        end
                    end
                else
                    for animId, id in info.SoundIds do
                        LoadedEmoteTracks[Module.Name][animId].Sound = id
                    end
                end
            end

            AnimTrack = LoadedEmoteTracks[Module.Name]
        end

        if not AnimTrack.Animation then
            local Selected = AnimTrack[math.random(1, #AnimTrack)]
            Selected.Animation:Play(0)
            Sounds.PlaySound(Selected.Sound, {Name = "EmotePreview"})
        else
            AnimTrack.Animation:Play(0)
            Sounds.PlaySound(AnimTrack.Sound, {Name = "EmotePreview"})
        end
    else
        PreviewInstances.EmotePreview.Visible = false
        PreviewInstances.Render.ImageTransparency = 0
        ButtonsContainer.Skins.Visible = true
        ButtonsContainer.MoreInfo.Visible = true
    end
end

--[=[
    Builds, or re-orders, the character and emote cards.

    WHAT WAS WRONG WITH THE OLD ONE
    -------------------------------
    1. IT SORTED BY REQUIRING MODULES INSIDE THE COMPARATOR.

       `table.sort(t, function(a, b) local A = require(a) ... end)`. One character module
       that errors on load therefore threw out of the comparator, out of `table.sort`, out
       of `SetupBatch`, and out of `ReloadContent` — and the whole killer list silently
       failed to build. An empty shop, with a single unrelated-looking error in the console.
       This is the most likely reason the shop appeared "broken": any one bad killer took
       all of them down.

       Now the roster comes from `CharacterRegistry`, which requires each module exactly
       once inside its own `pcall`. A broken character costs that one card.

    2. THE RE-ORDER PATH INDEXED A CARD IT HADN'T CHECKED FOR.

       `Parent:FindFirstChild(module.Name).LayoutOrder = LO`. Any module without a card —
       a killer added to the folder after the shop was built, or one whose card creation
       failed — made that a nil index, and the re-order after every purchase threw.
       Missing cards are now CREATED instead, which is also what makes a newly added killer
       appear without a rejoin.

    3. OWNERSHIP WAS PAINTED ONCE, AT CREATION.

       So a card built before the player's save data replicated said "not owned" forever.
       Painting is now `Shop._PaintCard`, called from here and from `Shop.RefreshOwnership`
       whenever the data changes.
]=]
function Shop.ReloadContent(CreateCards: boolean?)
    if Shop.Failed or not Shop.UIInstance then
        return
    end

    if CreateCards == nil then
        CreateCards = false
    end

    -- `GetPlayerSetting` returns `nil` when the save data hasn't arrived, which is not the
    -- same as `false`; comparing to `true` keeps "not loaded yet" out of the truthy branch.
    local CanMakePreviews = Shop.PreviewsEnabled
        and Utils.PlayerData.GetPlayerSetting(LocalPlayer, "Performance.SkinPreviews") == true

    ----------------------------------------------------------------------------
    -- A SINGLE CARD
    ----------------------------------------------------------------------------

    --[=[
        Spins up the rotating 3D preview behind a card.

        Split out of `SetupCard` only so the `task.defer` body isn't nested four levels
        deep inside it. The behaviour is the original's, plus a check that the model has a
        `Humanoid` before reaching into it — a malformed preview model used to throw inside
        the deferred thread, where nothing was watching.
    ]=]
    local function BuildPreview(entry, Type: string, Preview: Instance)
        task.defer(function()
            local Model = Utils.Instance.FindFirstChild(CharacterFolder, Type.."."..entry.ModuleName, 0)
            if not Model then
                -- Expected for most of the roster: the rigs are Studio assets and the
                -- placeholder system covers their absence in-game. Not worth a warning per
                -- card every time the shop opens.
                return
            end

            if not Model:FindFirstChildWhichIsA("Humanoid") then
                warn("[Shop] The preview model for \""..entry.ModuleName.."\" has no Humanoid, so it can't be previewed.")
                return
            end

            local Camera = Instance.new("Camera")
            Camera.FieldOfView = 10
            Camera.Parent = Preview
            local WorldModel = Instance.new("WorldModel")
            WorldModel.Parent = Camera
            Preview.CurrentCamera = Camera

            Model = Model:Clone()

            local Humanoid = Model:FindFirstChildWhichIsA("Humanoid")
            if not Humanoid:FindFirstChildWhichIsA("Animator") then
                Instance.new("Animator").Parent = Humanoid
            end

            local Root = Utils.Character.GetRootPart(Model)
            if not Root then
                Model:Destroy()
                return
            end
            Root.Anchored = true

            Model:PivotTo(CFrame.new(0, 10000, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(180), 0))
            Camera.CFrame = CFrame.new(0, 10000, 6 * Model:GetExtentsSize().Y)
            Model.Parent = ShopContainer.PreviewCache

            local AnimationIDs = entry.Character.Config and entry.Character.Config.AnimationIDs or nil
            local AnimationID = AnimationIDs and (AnimationIDs.PreviewAnimation or AnimationIDs.IdleAnimation)
            if AnimationID then
                local Track = Utils.Character.LoadAnimationFromID(Model, AnimationID, false)
                if Track then
                    Track:Play(0)
                end
            end

            Utils.Instance.ObserveProperty(Preview, "ImageTransparency", function(value: number)
                if value < 1 then
                    if Model.Parent ~= WorldModel then
                        Model.Parent = WorldModel
                    end
                elseif Model.Parent ~= ShopContainer.PreviewCache then
                    Model.Parent = ShopContainer.PreviewCache
                end
            end)
        end)
    end

    --[=[
        One line summarising how a character plays.

        The registry carries `Role` and `Difficulty` now, and this is where they surface:
        a hover tooltip, so the information is available without adding a label to a card
        template this code can't see the design of.
    ]=]
    local function SummaryFor(entry): string
        local Parts = {entry.DisplayName}

        if entry.Role then
            table.insert(Parts, entry.Role)
        end
        if entry.Difficulty then
            table.insert(Parts, string.rep("★", math.clamp(entry.Difficulty, 1, 5))
                ..string.rep("☆", 5 - math.clamp(entry.Difficulty, 1, 5)))
        end

        return table.concat(Parts, "  ·  ")
    end

    local function SetupCard(entry, Type: string, layoutOrder: number)
        local Parent = if Type == "Killer" then KillerContainer elseif Type == "Survivor" then SurvivorContainer else EmoteContainer
        local Name = entry.ModuleName

        local Existing = Shop.LoadedItems[Type.."s"][Name]

        --[[
            An existing card only needs re-ordering and repainting.

            This is the path the old code crashed on. Note it also re-reads ownership —
            re-ordering happens right after a purchase, which is exactly when the badge
            needs to change.
        ]]
        if Existing then
            if Existing.Parent then
                Existing.LayoutOrder = layoutOrder
                Shop._PaintCard(Existing, Type, Name)
                return
            end

            -- The card was destroyed from under us (the UI was torn down and rebuilt).
            -- Fall through and make a new one rather than holding a dead reference.
            Shop.LoadedItems[Type.."s"][Name] = nil
        end

        --[[
            `CreateCards` is false on a plain refresh — but a character with NO card yet
            still gets one, because the alternative is that a killer added since `Init` is
            invisible until the player rejoins. "Where possible" is here.
        ]]
        if not CreateCards and not Shop.Opened then
            -- Building cards while the menu is closed is wasted work; the next open calls
            -- this again with `CreateCards` set.
            return
        end

        local Card = Templates.CardTemplate:Clone()
        local Container = Card.Container
        Card.Name = Name
        Card.LayoutOrder = layoutOrder
        Card.Parent = Parent

        Container.Title.Text = entry.DisplayName
        Container.CharacterRender.Image = entry.Render
        Container.Price.Text = entry.Price > 0 and tostring(entry.Price).."$" or "FREE"

        local CardFrame = entry.Character.Config and entry.Character.Config.CardFrame or nil
        if CardFrame then
            Container.Outline.Image = CardFrame.Image or Container.Outline.Image
            Container.Outline.Size = CardFrame.Size or Container.Outline.Size
        end

        local Preview = Container.Preview.ViewportFrame
        if CanMakePreviews and Type ~= "Emote" then
            BuildPreview(entry, Type, Preview)
        end

        Shop.ItemModules[Type.."s"] = Shop.ItemModules[Type.."s"] or {}
        Shop.LoadedItems[Type.."s"][Name] = Card
        Shop.ItemModules[Type.."s"][Name] = entry.Character

        Shop._PaintCard(Card, Type, Name)

        local Summary = SummaryFor(entry)

        -- These connections die with the card, which dies with the UI. -dys
        Container.Interact.MouseEnter:Connect(function()
            if CanMakePreviews and Type ~= "Emote" then
                TweenService:Create(Preview, TweenInfo.new(0.25), {
                    ImageTransparency = 0
                }):Play()
                TweenService:Create(Preview.Parent, TweenInfo.new(0.25), {
                    BackgroundTransparency = 0
                }):Play()
            end
            TweenService:Create(Container, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Size = UDim2.fromScale(1.065, 1.065)
            }):Play()
            Tooltip.New(Summary)
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
        end)
        Container.Interact.MouseLeave:Connect(function()
            if CanMakePreviews and Type ~= "Emote" then
                TweenService:Create(Preview, TweenInfo.new(0.25), {
                    ImageTransparency = 1
                }):Play()
                TweenService:Create(Preview.Parent, TweenInfo.new(0.25), {
                    BackgroundTransparency = 1
                }):Play()
            end
            TweenService:Create(Container, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Size = Utils.UDim.Full
            }):Play()
            Tooltip.New()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
        end)
        Container.Interact.MouseButton1Click:Connect(function()
            if Shop.SkinMenu.Open then
                return
            end
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})
            Shop.OnCharButtonPress(Name, entry.Character, entry.Module, Type, Card)
        end)

        if entry.Icon then
            Container.Origin.Visible = true
            Container.Origin.Image = entry.Icon

            Container.Origin.MouseEnter:Connect(function()
                -- Superset of the card's own tooltip, so moving onto the badge adds
                -- information rather than replacing it.
                Tooltip.New(entry.OriginTooltip and (Summary.."\n"..entry.OriginTooltip) or Summary)
                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
            end)
            Container.Origin.MouseLeave:Connect(function()
                -- Back to the card's tooltip: the mouse is still over the card.
                Tooltip.New(Summary)
                Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
            end)
        else
            Container.Origin.Visible = false
        end
    end

    ----------------------------------------------------------------------------
    -- ONE SECTION
    ----------------------------------------------------------------------------

    --[=[
        Lays out one tab.

        Unowned first, then owned, each group in the registry's own cheapest-first order.
        That ordering is unchanged from the original; what's changed is that it no longer
        needs a comparator that can throw, because the registry has already sorted by price
        and name.
    ]=]
    local function SetupBatch(Type: string)
        Shop.LoadedItems[Type.."s"] = Shop.LoadedItems[Type.."s"] or {}

        local Unowned, Owned = {}, {}
        local Plural = CharacterRegistry.Kinds[Type].Plural

        for _, Entry in CharacterRegistry.List(Type, false) do
            local IsOwned = Entry.Price <= 0
                or Utils.PlayerData.GetPlayerOwned(LocalPlayer, Plural.."."..Entry.ModuleName) and true
                or false

            table.insert(IsOwned and Owned or Unowned, Entry)
        end

        local LayoutOrder = 0

        for _, Entry in ipairs(Unowned) do
            LayoutOrder += 1
            SetupCard(Entry, Type, LayoutOrder)
        end
        for _, Entry in ipairs(Owned) do
            LayoutOrder += 1
            SetupCard(Entry, Type, LayoutOrder)
        end

        --[=[
            Remove cards for characters that are no longer in the roster.

            Without this, a killer deleted or renamed mid-session left a card behind that
            opened a More Info page for a module that no longer exists. Rare, but it is the
            other half of "newly added killers appear automatically".
        ]=]
        for Name, Card in Shop.LoadedItems[Type.."s"] do
            if not CharacterRegistry.Exists(Type, Name) then
                if Card and Card.Parent then
                    Card:Destroy()
                end
                Shop.LoadedItems[Type.."s"][Name] = nil
                if Shop.ItemModules[Type.."s"] then
                    Shop.ItemModules[Type.."s"][Name] = nil
                end
            end
        end
    end

    ----------------------------------------------------------------------------

    --[[
        Each tab in its own `pcall`.

        Killers are the section players actually use, and they are built first — but an
        exception while building Emotes used to prevent nothing, because it came last. Now
        a problem in any one tab leaves the other two intact, and says which it was.
    ]]
    for _, Type in {"Killer", "Survivor", "Emote"} do
        local Ok, Err = pcall(SetupBatch, Type)
        if not Ok then
            warn("[Shop] The "..Type.." tab failed to build: "..tostring(Err))
        end
    end

    Shop.UpdateSideButtons()
end

function Shop.CreateBuyWindow(Module: ModuleScript, skin: boolean?, Parent: Frame, Card: Frame)
    if Shop.BuyWindow then
        return
    end

    local Window = BuyWindow.New(Shop, Module, skin, Parent, Card)
    Window.Purchased:Connect(function()
        --[[
            Re-read ownership from the real save data rather than assuming the purchase
            landed. `RefreshOwnership` repaints every card's owned/equipped badge and
            refreshes the side panel, and `ReloadContent` re-sorts so the newly owned card
            moves into the owned group.
        ]]
        Shop.RefreshOwnership()
        Shop.ReloadContent()
        Shop.ReorderSkins()
    end)
    Window.Removed:Connect(function()
        Shop.BuyWindow = nil
    end)

    Shop.BuyWindow = Window
end

return Shop
