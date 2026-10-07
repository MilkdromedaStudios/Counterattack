--[=[
    BUY ITEM — the server side of a purchase.

    WHAT WAS WRONG WITH THE OLD ONE
    -------------------------------
    It trusted the client completely. The client sent a `ModuleScript`, and the handler:

      * worked out WHAT was being bought by walking `Module.Parent.Parent.Parent.Name`,
        with no check that the module lived in a content folder at all — any ModuleScript
        anywhere in `ReplicatedStorage` was accepted;
      * read the PRICE out of `require(Module).Config.Price`, i.e. out of the thing the
        client chose, with no sign check, so a module with a negative price would have
        *paid* the buyer and a module with no `Config` threw;
      * never asked whether the player ALREADY OWNED IT, so buying the same killer twice
        charged twice and added a second ownership entry;
      * indexed `Money.Value` without checking `Money` existed, so a purchase attempted
        before the player's save data arrived threw instead of failing politely.

    HOW IT WORKS NOW
    ---------------
    The client's message is treated as a REQUEST NAMING A THING, nothing more. Every fact
    that matters — is this a real purchasable, what does it cost, is it already owned, can
    they afford it — is looked up server-side through `CharacterRegistry`, which validates
    the instance structurally before it will say what it is.

    The client still sends an instance rather than a name, because that is what the shop and
    the inventory already send and changing the wire format would have meant touching both
    of them for no security benefit: an instance reference is validated here just as a name
    would be.

    @return `true` on success, or `false, reason` so the UI can say something useful. The
            old one returned a bare `false` for everything, which is why the buy window said
            "you're too poor." when the real problem was that you already owned it.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterRegistry = require(ReplicatedStorage.Modules.CharacterRegistry)
local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)

--[=[
    Adds the ownership entry.

    An `IntValue` named after the module, which is the shape `SaveManager`, the shop, the
    inventory and `DevItemGrantingManager` all already read. The value is the character's
    level, which nothing uses yet; `0` is the correct starting point.
]=]
local function GrantOwnership(parent: Instance, name: string)
    local Product = Instance.new("IntValue")
    -- Name BEFORE parenting. The other way round replicates a child called "Value" first
    -- and then renames it, and anything watching `ChildAdded` sees the wrong name.
    Product.Name = name
    Product.Value = 0
    Product.Parent = parent
end

return function()
    Network:SetConnection("BuyItem", "REMOTE_FUNCTION", function(SourcePlayer: Player, Module: Instance)
        if not SourcePlayer or not SourcePlayer.Parent then
            return false, "NoPlayer"
        end

        ------------------------------------------------------------------------
        -- WHAT IS IT?
        ------------------------------------------------------------------------

        -- Try a top-level character or emote first, then a skin. Both are validated by
        -- their position in the content tree, not by anything the client said about them.
        local Kind, Entry = CharacterRegistry.Resolve(Module)
        local SkinKind, SkinCharacter, SkinModule = nil, nil, nil

        if not Kind then
            SkinKind, SkinCharacter, SkinModule = CharacterRegistry.ResolveSkin(Module)
        end

        if not Kind and not SkinKind then
            warn("[BuyItem] "..SourcePlayer.Name.." tried to buy something that isn't a purchasable item: "..tostring(Module and Module:GetFullName() or Module))
            return false, "InvalidItem"
        end

        ------------------------------------------------------------------------
        -- PRICE AND DESTINATION
        ------------------------------------------------------------------------

        local Price: number
        -- `OwnedPath` is the dotted path under `PlayerData.Purchased`.
        local OwnedPath: string
        local Destination: Instance?
        -- What the reward notification calls it.
        local Label: string

        if Kind then
            Price = Entry.Price
            OwnedPath = CharacterRegistry.Kinds[Kind].Plural.."."..Entry.ModuleName
            Destination = Utils.Instance.FindFirstChild(SourcePlayer, "PlayerData.Purchased."..CharacterRegistry.Kinds[Kind].Plural, 0)
            --[[
                `RewardNotifications` builds its sentence out of this string: "bought"
                selects the verb, and "character"/"emote"/"skin" selects the noun. The old
                handler sent "QuotedKiller", which matched neither, so a purchase announced
                itself as `Received "Creeper"` — passive, and missing the noun. These say
                `Bought "Creeper" character`.
            ]]
            Label = Kind == "Emote" and "BoughtQuotedEmote" or "BoughtQuotedCharacter"
        else
            --[[
                Skins aren't in the registry's own lists — they're per-character, and
                indexing every skin of every character on every read would be a lot of
                requires for a menu most players never open. `ResolveSkin` has already
                proved this module lives at
                `Characters.Skins.<Role>s.<Character>.<Skin>`, so requiring it here is
                requiring a module we have structurally verified, not one the client chose.
            ]]
            local Ok, Loaded = pcall(require, SkinModule)
            if not Ok or type(Loaded) ~= "table" or not Loaded.Config then
                warn("[BuyItem] The skin \""..tostring(SkinModule and SkinModule.Name).."\" could not be loaded, so it cannot be sold: "..tostring(Loaded))
                return false, "InvalidItem"
            end

            Price = tonumber(Loaded.Config.Price) or 0
            OwnedPath = "Skins."..SkinCharacter.."."..SkinModule.Name
            Destination = Utils.PlayerData.CreateMissingPurchasedSkinValue(SourcePlayer, SkinCharacter)
            Label = "BoughtQuotedSkin"
        end

        --[[
            A negative price would be a payout. Nothing in the project sets one, but the old
            handler would have honoured it, and the whole point of this rewrite is that the
            server stops taking the content's word for anything that moves currency.
        ]]
        if Price < 0 then
            warn("[BuyItem] \""..tostring(Module.Name).."\" has a negative price ("..tostring(Price).."). Treating it as free rather than paying the buyer.")
            Price = 0
        end

        if not Destination then
            -- Their save data hasn't arrived, or arrived malformed. Not their fault and not
            -- an exploit: fail without charging them.
            return false, "NoData"
        end

        ------------------------------------------------------------------------
        -- ALREADY OWNED?
        ------------------------------------------------------------------------

        if Utils.PlayerData.GetPlayerOwned(SourcePlayer, OwnedPath, false) then
            -- Not a warning. Double-clicking the buy button is a completely normal thing to
            -- do, and the first click having succeeded is exactly why the second one fails.
            return false, "AlreadyOwned"
        end

        ------------------------------------------------------------------------
        -- FUNDS
        ------------------------------------------------------------------------

        local Money = Utils.Instance.FindFirstChild(SourcePlayer, "PlayerData.Stats.Currency.Money", 0)
        local NetWorth = Utils.Instance.FindFirstChild(SourcePlayer, "PlayerData.Stats.Currency.NetWorth", 0)

        if not Money then
            return false, "NoData"
        end

        if Price > Money.Value then
            return false, "TooPoor"
        end

        ------------------------------------------------------------------------
        -- DO IT
        ------------------------------------------------------------------------

        Money.Value -= Price

        -- `NetWorth` is lifetime spend, used by achievements. Missing it shouldn't block a
        -- purchase that is otherwise valid.
        if NetWorth then
            NetWorth.Value += Price
        end

        GrantOwnership(Destination, Kind and Entry.ModuleName or SkinModule.Name)

        Network:FireClientConnection(SourcePlayer, "ShowRewardNotification", "REMOTE_EVENT", Module, Label)

        return true
    end)
end
