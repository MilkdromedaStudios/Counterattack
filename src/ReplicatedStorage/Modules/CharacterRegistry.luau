--[=[
    CHARACTER REGISTRY

    The one place that answers "what characters exist, what do they cost, and is this
    thing somebody just sent me actually one of them".

    WHY THIS EXISTS
    --------------
    It is NOT a second list of characters. That was the bug. The shop walked
    `ReplicatedStorage.Characters.Killers` and required every module to sort them; the
    inventory did its own version of the same walk; `BuyItem` trusted whatever ModuleScript
    the client handed it; `SaveManager` did a third walk to validate saved names. Four
    readers, four different sets of assumptions, and no shared idea of what a valid
    character was.

    So the authoritative definition stays exactly where it was — inside each character's own
    module, in `Config` — and this normalises the read. One cache, one failure policy, one
    validator.

    THE FAILURE POLICY IS THE IMPORTANT PART
    ---------------------------------------
    A character module that throws while loading costs THAT CHARACTER and nothing else.

    The shop's sort did `require(a)` and `require(b)` inside a `table.sort` comparator, so a
    single broken module threw out of the comparator, out of the sort, out of the batch, and
    the entire killer list silently failed to build — an empty shop with one error in the
    console. Every require in here is wrapped, a broken module is reported once and skipped,
    and the other forty characters still appear.

    NEWLY ADDED CHARACTERS
    ---------------------
    The cache invalidates on `ChildAdded`/`ChildRemoved` on the content folders, so dropping
    a new killer module in — in Studio, or over a Rojo sync — makes it appear everywhere
    with nothing to register by hand.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Utils = require(ReplicatedStorage.Modules.Utils)

local CharacterRegistry = {}

--[=[
    Where each kind of content lives.

    `Folder` is the path under `ReplicatedStorage`; `Plural` is how the folder and the
    player's save data name it. Both are needed because they genuinely differ — the module
    folder is `Characters.Killers`, the ownership folder is `Purchased.Killers`, and the
    equipped value is the SINGULAR `Equipped.Killer`.
]=]
CharacterRegistry.Kinds = {
    Killer = {Folder = {"Characters", "Killers"}, Plural = "Killers"},
    Survivor = {Folder = {"Characters", "Survivors"}, Plural = "Survivors"},
    Emote = {Folder = {"Assets", "Emotes"}, Plural = "Emotes"},
}

--- Resolved entries per kind. Cleared wholesale when a content folder changes.
local Cache: {[string]: {any}?} = {}
--- Fast name lookup per kind, built alongside `Cache`.
local ByName: {[string]: {[string]: any}?} = {}
--- Modules already reported as broken, so the warning is printed once rather than per read.
local Reported: {[Instance]: boolean} = {}
--- Which folders we've attached invalidation listeners to.
local Watched: {[Instance]: boolean} = {}

--------------------------------------------------------------------------------
-- FOLDERS
--------------------------------------------------------------------------------

--- The content folder for a kind, or `nil` if the place is missing it.
function CharacterRegistry.GetFolder(kind: string): Instance?
    local Definition = CharacterRegistry.Kinds[kind]
    if not Definition then
        return nil
    end

    local Current: Instance? = ReplicatedStorage
    for _, Step in Definition.Folder do
        Current = Current and Current:FindFirstChild(Step)
        if not Current then
            return nil
        end
    end

    return Current
end

--[=[
    Watches a content folder so the cache can't go stale.

    Attached lazily on the first read rather than at require time, because on the client
    this module may well be required before `Characters` has finished replicating.
]=]
local function Watch(kind: string, folder: Instance)
    if Watched[folder] then
        return
    end
    Watched[folder] = true

    local function Invalidate()
        Cache[kind] = nil
        ByName[kind] = nil
    end

    folder.ChildAdded:Connect(Invalidate)
    folder.ChildRemoved:Connect(Invalidate)
end

--------------------------------------------------------------------------------
-- BUILDING ENTRIES
--------------------------------------------------------------------------------

--[=[
    Reads one module into a normalised entry.

    @return The entry, or `nil` if the module couldn't be loaded or isn't shaped like a
            character. Never throws.
]=]
local function BuildEntry(module: Instance, kind: string): any?
    if not module:IsA("ModuleScript") then
        return nil
    end

    --[[
        `pcall` around the require is the single most important line in this file.

        Everything that reads the roster goes through here, so an unloadable module has to
        degrade to one missing card rather than an empty menu. See the header.
    ]]
    local Ok, Loaded = pcall(require, module)

    if not Ok then
        if not Reported[module] then
            Reported[module] = true
            warn("[CharacterRegistry] \""..module.Name.."\" could not be loaded, so it has been left out of the roster: "..tostring(Loaded))
        end
        return nil
    end

    if type(Loaded) ~= "table" then
        if not Reported[module] then
            Reported[module] = true
            warn("[CharacterRegistry] \""..module.Name.."\" returned a "..typeof(Loaded)..", not a character table. Left out of the roster.")
        end
        return nil
    end

    --[[
        Emotes are shaped differently from characters: their fields sit at the top level
        rather than under `Config`. Normalising here is why every caller downstream can stop
        caring which it is holding.
    ]]
    local Config = Loaded.Config or Loaded

    --[[
        A price has to be a finite, non-negative number.

        `Overseer` is priced at `math.huge` to mark it as unbuyable, which is a reasonable
        thing to do and renders as "inf$" on a shop card. It is `Dev`-tagged so it never
        reaches the shop — but relying on a tag to keep a bad number off screen is relying
        on two things being right instead of one, and a negative price would be a payout
        (see `RemoteHandler.BuyItem`).

        Non-finite becomes a very large finite number: still effectively unbuyable, still
        renders as digits.
    ]]
    local Price = tonumber(Config.Price) or 0
    if Price ~= Price or Price == math.huge then
        Price = 999999999
    elseif Price < 0 then
        warn("[CharacterRegistry] \""..module.Name.."\" has a negative price ("..tostring(Price).."). Treated as free.")
        Price = 0
    end

    return {
        --- Folder name. The identity used in save data and over the network.
        ModuleName = module.Name,
        --- What a player sees. May contain spaces and hyphens, unlike `ModuleName`.
        DisplayName = tostring(Config.Name or module.Name),
        Kind = kind,
        Price = Price,
        --- Card art.
        Render = tostring(Config.Render or ""),
        --- Origin badge, when the character has one.
        Icon = Config.Origin and Config.Origin.Icon or nil,
        OriginTooltip = Config.Origin and Config.Origin.TooltipText or nil,
        --- One-word archetype, when declared.
        Role = Config.Role,
        --- 1 to 5, when declared.
        Difficulty = tonumber(Config.Difficulty) or nil,
        Quote = Config.Quote,
        Description = Config.Description,
        --- Dev-only content, hidden from the shop. Driven by the module's Rojo tag.
        Dev = module:HasTag("Dev"),
        --- Granted per session rather than saved. Also a module tag.
        PreventSave = module:HasTag("PreventSave"),
        --- The module itself, for callers that need to require it properly.
        Module = module,
        --- The loaded table, so nothing requires it twice.
        Character = Loaded,
    }
end

--[=[
    Everything of one kind, cheapest first then alphabetical.

    That ordering is the shop's ordering, and keeping it here rather than in the shop means
    the inventory shows the same roster in the same order.

    @param includeDev Pass `true` to include modules tagged `Dev`. The shop must not.
]=]
function CharacterRegistry.List(kind: string, includeDev: boolean?): {any}
    local Cached = Cache[kind]

    if not Cached then
        local Folder = CharacterRegistry.GetFolder(kind)
        if not Folder then
            -- Not an error on the client during startup: the folder simply hasn't
            -- replicated yet. An empty list now and a populated one in a moment.
            return {}
        end

        Watch(kind, Folder)

        local Entries = {}
        local Lookup = {}

        for _, Module: Instance in Folder:GetChildren() do
            local Entry = BuildEntry(Module, kind)
            if Entry then
                table.insert(Entries, Entry)
                Lookup[Entry.ModuleName] = Entry
            end
        end

        table.sort(Entries, function(a, b)
            if a.Price == b.Price then
                return a.ModuleName < b.ModuleName
            end
            return a.Price < b.Price
        end)

        Cache[kind] = Entries
        ByName[kind] = Lookup
        Cached = Entries
    end

    if includeDev then
        return Cached
    end

    local Public = {}
    for _, Entry in Cached do
        if not Entry.Dev then
            table.insert(Public, Entry)
        end
    end
    return Public
end

--- One entry by module name, or `nil`. Dev content is included — this is a lookup, not a menu.
function CharacterRegistry.Get(kind: string, moduleName: string): any?
    -- Populates `ByName` as a side effect if the cache is cold.
    CharacterRegistry.List(kind, true)

    local Lookup = ByName[kind]
    return Lookup and Lookup[moduleName] or nil
end

--- Does this character exist and load?
function CharacterRegistry.Exists(kind: string, moduleName: string): boolean
    return CharacterRegistry.Get(kind, moduleName) ~= nil
end

--- Price, or `nil` if there's no such character. `nil` and `0` mean very different things.
function CharacterRegistry.GetPrice(kind: string, moduleName: string): number?
    local Entry = CharacterRegistry.Get(kind, moduleName)
    return Entry and Entry.Price or nil
end

--- Display name, falling back to the module name so UI never shows an empty label.
function CharacterRegistry.GetDisplayName(kind: string, moduleName: string): string
    local Entry = CharacterRegistry.Get(kind, moduleName)
    return Entry and Entry.DisplayName or moduleName
end

--------------------------------------------------------------------------------
-- VALIDATION
--------------------------------------------------------------------------------

--[=[
    Works out what a client-supplied ModuleScript actually IS.

    This is the security half of the module, and `RemoteHandler.BuyItem` is why it exists.
    That handler took a ModuleScript straight off the wire and derived the item's type by
    walking `Module.Parent.Parent.Parent.Name`, then read `require(Module).Config.Price` and
    subtracted it from the player's balance. Every part of that trusted the client: a
    ModuleScript from anywhere in `ReplicatedStorage` would do, and a `Config.Price` of a
    negative number would have PAID the buyer.

    So the only question worth asking is "is this exact instance a child of a content folder
    I recognise", and that is what this answers. The price then comes from the registry's
    own read, never from the caller.

    @return kind, entry — or `nil` for anything that isn't a legitimate purchasable.
]=]
function CharacterRegistry.Resolve(module: Instance?): (string?, any?)
    if not module or typeof(module) ~= "Instance" or not module:IsA("ModuleScript") then
        return nil, nil
    end

    local Parent = module.Parent
    if not Parent then
        return nil, nil
    end

    -- A top-level character or emote: its parent must be one of the content folders.
    for Kind in CharacterRegistry.Kinds do
        if Parent == CharacterRegistry.GetFolder(Kind) then
            local Entry = CharacterRegistry.Get(Kind, module.Name)
            -- Identity, not name: two modules could share a name across folders, and only
            -- the one the registry actually loaded is the one we may sell.
            if Entry and Entry.Module == module then
                return Kind, Entry
            end
            return nil, nil
        end
    end

    return nil, nil
end

--[=[
    The same question for a skin, which is nested one folder deeper.

    `Characters.Skins.<Killers|Survivors>.<Character>.<Skin>`. Validated structurally for
    exactly the same reason as above.

    @return kind, characterName, skinModule — or `nil`.
]=]
function CharacterRegistry.ResolveSkin(module: Instance?): (string?, string?, Instance?)
    if not module or typeof(module) ~= "Instance" or not module:IsA("ModuleScript") then
        return nil, nil, nil
    end

    local CharacterFolder = module.Parent
    local RoleFolder = CharacterFolder and CharacterFolder.Parent
    local SkinRoot = RoleFolder and RoleFolder.Parent

    if not SkinRoot or SkinRoot.Name ~= "Skins" then
        return nil, nil, nil
    end

    local Characters = ReplicatedStorage:FindFirstChild("Characters")
    if not Characters or SkinRoot.Parent ~= Characters then
        return nil, nil, nil
    end

    -- `RoleFolder` is "Killers"/"Survivors"; the rest of the game wants the singular.
    local Kind = RoleFolder.Name:sub(1, -2)
    if not CharacterRegistry.Kinds[Kind] then
        return nil, nil, nil
    end

    -- The skin has to belong to a character that actually exists.
    if not CharacterRegistry.Exists(Kind, CharacterFolder.Name) then
        return nil, nil, nil
    end

    return Kind, CharacterFolder.Name, module
end

--[=[
    A character of this kind that definitely exists, for use as a fallback.

    `SaveManager` needs this when somebody's saved killer has been renamed or removed: the
    alternative is leaving them equipped as `""`, which is what it used to do, and an empty
    equipped killer is a player who cannot spawn.

    Prefers the free ones, then the cheapest, and never offers Dev content.
]=]
function CharacterRegistry.GetFallback(kind: string): string?
    local Entries = CharacterRegistry.List(kind, false)
    local First = Entries[1]

    return First and First.ModuleName or nil
end

--------------------------------------------------------------------------------
-- OWNERSHIP
--------------------------------------------------------------------------------

--[=[
    Does this player own it?

    A thin wrapper over `Utils.PlayerData.GetPlayerOwned`, but it builds the path from the
    registry's own `Plural` rather than from `kind.."s"` spelled out at each call site —
    which is how you end up with one caller asking about `"Emotes"` and another about
    `"Emotes"`-with-a-typo and nobody noticing because the answer is just `false`.
]=]
function CharacterRegistry.IsOwnedBy(player: Player, kind: string, moduleName: string): boolean
    local Definition = CharacterRegistry.Kinds[kind]
    if not Definition then
        return false
    end

    return Utils.PlayerData.GetPlayerOwned(player, Definition.Plural.."."..moduleName) and true or false
end

--[=[
    Is this free?

    Free characters are owned by everybody implicitly, which matters because the shop should
    not ask somebody to buy something that costs nothing.
]=]
function CharacterRegistry.IsFree(kind: string, moduleName: string): boolean
    return (CharacterRegistry.GetPrice(kind, moduleName) or math.huge) <= 0
end

--------------------------------------------------------------------------------
-- DIAGNOSTICS
--------------------------------------------------------------------------------

--[=[
    Prints the roster, including anything that failed to load.

    Run from the command bar when the shop looks wrong. It is far quicker than reading the
    console for the one warning that scrolled past.
]=]
function CharacterRegistry.Dump()
    for Kind in CharacterRegistry.Kinds do
        local Folder = CharacterRegistry.GetFolder(Kind)
        local Modules = Folder and Folder:GetChildren() or {}
        local Entries = CharacterRegistry.List(Kind, true)

        local ModuleCount = 0
        for _, Module in Modules do
            if Module:IsA("ModuleScript") then
                ModuleCount += 1
            end
        end

        print(("[CharacterRegistry] %s: %d of %d module(s) loaded."):format(Kind, #Entries, ModuleCount))

        for _, Entry in Entries do
            print(("    %-16s %-18s %8d$  %s%s"):format(
                Entry.ModuleName,
                Entry.DisplayName,
                Entry.Price,
                Entry.Role or "-",
                Entry.Dev and "  [DEV]" or ""
            ))
        end

        if #Entries < ModuleCount then
            warn(("[CharacterRegistry] %d %s module(s) failed to load. Look for [CharacterRegistry] warnings above."):format(ModuleCount - #Entries, Kind))
        end
    end
end

--- Drops the cache. Only needed if a module's contents changed without the folder changing.
function CharacterRegistry.Invalidate(kind: string?)
    if kind then
        Cache[kind] = nil
        ByName[kind] = nil
        return
    end

    table.clear(Cache)
    table.clear(ByName)
    table.clear(Reported)
end

if RunService:IsStudio() then
    -- Handy in the command bar: `require(game.ReplicatedStorage.Modules.CharacterRegistry).Dump()`
    -- is a mouthful, and the global makes the diagnostic one word.
    _G.DumpRoster = CharacterRegistry.Dump
end

return CharacterRegistry
