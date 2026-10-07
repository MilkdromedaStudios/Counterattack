--[=[
    OWNER PERKS

    Gives named accounts unlimited money AND every unlockable in the game, so the owner
    and anyone testing with them never has to grind for anything.

    WHAT THEY GET
    -------------
      * Every killer, every survivor, every skin and every emote — including the owner-only
        Overseer. Read from the real content folders on join, so a character added tomorrow
        is owned the next time they log in with nothing to remember.
      * A balance that never goes down.

    All of it is tagged `PreventSave`, so it is re-granted each session rather than written
    into the DataStore. Take somebody off the list and they actually lose it, instead of it
    staying baked into their save file forever.

    HOW THE MONEY WORKS
    -------------------
    It isn't faked or hidden — the real `Currency.Money` stat is set to a large number
    and then re-asserted whenever anything spends it. Shops, prices and the leaderstat all
    keep working exactly as they do for everyone else; the balance just never goes down.

    A large number rather than `math.huge`: infinity doesn't survive a round trip through
    a DataStore, and it renders as "inf" in the leaderstat. Ten billion is plenty and it
    still displays and saves like a normal number.

    ADDING PEOPLE
    -------------
    Put them in `OwnerPerks.Owners` below. `UserId` is the reliable way to do it —
    usernames can be changed, and then the perk silently follows whoever took the old
    name. Look up an ID at https://users.roblox.com/v1/users/search?keyword=NAME , or run
    `print(game.Players.SOMEONE.UserId)` in the command bar while they're in the server.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Utils = require(ReplicatedStorage.Modules.Utils)

local OwnerPerks = {
    --[=[
        Who gets the perks.

        Match on `UserId` when you can — it never changes. `Username` is a fallback for
        when you don't have the ID to hand, and it's matched case-insensitively.
    ]=]
    Owners = {
        -- Matched on UserId, which never changes. The username is kept alongside it purely
        -- so this list is readable — the ID is what actually grants the perks.
        {Username = "UNIOPAY5", UserId = 5321643116},
    },

    --- The balance owners are held at.
    Money = 10_000_000_000,

    --[=[
        Give owners EVERYTHING.

        Rather than a list to keep in sync, this walks the actual content folders and
        grants whatever is in them — every killer, every survivor, every skin and every
        emote. Add a new character tomorrow and the owner owns it the next time they join,
        with nothing to remember.

        Everything is added with the engine's `PreventSave` tag, exactly as
        `DevItemGrantingManager` does it, so the grant is re-applied each session rather
        than written into saved data. Take someone off the owner list and they genuinely
        lose access instead of it staying baked into their save file.

        Set to `false` to fall back to `Killers` below.
    ]=]
    GrantEverything = true,

    --- Only used when `GrantEverything` is off.
    Killers = {"Overseer"},

    --- Set to `false` to switch the whole thing off without deleting anything.
    Enabled = true,
}

--- Is this player on the list?
function OwnerPerks.IsOwner(Player: Player): boolean
    if not OwnerPerks.Enabled then
        return false
    end

    return OwnerPerks._IsListed(Player)
end

--[=[
    The owner check, WITHOUT the `Enabled` switch.

    `Enabled` exists so the money and the unlocks can be turned off without editing the
    list. Turning those off must not hand the round controls to everybody, so the panel
    gate reads this instead.
]=]
function OwnerPerks._IsListed(Player: Player): boolean
    if not Player then
        return false
    end

    for _, Entry in OwnerPerks.Owners do
        if Entry.UserId and Player.UserId == Entry.UserId then
            return true
        end

        -- Usernames are case-insensitive in Roblox, so the comparison has to be too.
        if Entry.Username and Player.Name:lower() == Entry.Username:lower() then
            return true
        end
    end

    return false
end

--[=[
    MAY THIS PLAYER SEE AND USE A CONTROL PANEL?

    The round controls, the Events Panel, and anything else that can reach into a live
    round. This is the ONE answer to that question in the whole game, and it is the owner
    list and nothing else.

    WHAT THIS DELIBERATELY DOES NOT ACCEPT, and why each one was a real leak:

      * ADMIN RANK. The round panel used to ask
        `CommonFunctions.PlayerHasPermissionRank(Player, Utils.Ranks.ServerOwner)`, which
        resolves to `Rank < 20`. Moderator is 15 and Developer is 18, so every moderator
        and every developer passed it — and `CommonFunctions.AdminPerms` ships with a
        Developer in it. Moderation powers and "can end everybody's round" are not the
        same authority and should never have shared a check.

      * A SAVED ADMIN LIST. The Events Panel kept its own `extraAdmins` in a DataStore.
        Anyone added once kept the panel in every future session, and nothing in the
        repository said who was on that list. It is still read for the panel's own admin
        MANAGEMENT display, but it no longer grants the panel.

      * STUDIO. `RunService:IsStudio()` returned true for every player in a Studio
        session, which on a team test is everybody present. Testing alone in Studio you
        are usually the owner anyway; if you need to test the panel as a different
        account, add that account to `Owners` for as long as you need it, and the grant is
        then written down instead of implicit.

    @return Whether the panel may be shown AND whether its actions may run. Both callers
            use this same answer, so the UI and the authority can never disagree.
]=]
function OwnerPerks.CanUseControlPanels(Player: Player): boolean
    return OwnerPerks._IsListed(Player)
end

--[=[
    Pins one player's money at `OwnerPerks.Money` for as long as they're in the server.

    The `Changed` connection is what makes it "infinite" rather than just "a lot": buying
    something subtracts from the stat as normal, this notices and puts it straight back.
]=]
function OwnerPerks._Apply(Player: Player)
    -- `PlayerData` is built by `SaveManager` a moment after the player joins, so this has
    -- to wait for it rather than assume it's there.
    local Money = Utils.Instance.FindFirstChild(Player, "PlayerData.Stats.Currency.Money", 30)
    if not Money then
        warn("[OwnerPerks] Couldn't find `PlayerData.Stats.Currency.Money` for "..Player.Name.." after 30s. Their data may not have loaded.")
        return
    end

    Money.Value = OwnerPerks.Money

    Money.Changed:Connect(function(value: number)
        if value < OwnerPerks.Money then
            Money.Value = OwnerPerks.Money
        end
    end)

    print("[OwnerPerks] "..Player.Name.." has unlimited money.")

    OwnerPerks._GrantKillers(Player)
end

--[=[
    Adds one purchase entry, if it isn't already there.

    A `NumberValue` named after the item, tagged `PreventSave` — the same shape
    `DevItemGrantingManager` uses, so the shop, the inventory and the equip flow all treat
    it exactly like something that was bought normally.
]=]
function OwnerPerks._Grant(Folder: Instance, Name: string): boolean
    if not Folder or Folder:FindFirstChild(Name) then
        return false
    end

    local Value = Instance.new("NumberValue")
    Value.Name = Name
    Value.Value = 0
    Value:AddTag("PreventSave")
    Value.Parent = Folder

    return true
end

--[=[
    Unlocks everything this player could ever own.

    Walks the real content folders rather than a hardcoded list, so it can't fall behind
    the roster. Each section is wrapped in its own `pcall`: a malformed skin folder should
    cost that one skin, not every grant after it.
]=]
function OwnerPerks._GrantAll(Player: Player)
    local Purchased = Utils.Instance.FindFirstChild(Player, "PlayerData.Purchased", 30)
    if not Purchased then
        warn("[OwnerPerks] Couldn't find `PlayerData.Purchased` for "..Player.Name.." after 30s. Nothing granted.")
        return
    end

    local Granted = {Killers = 0, Survivors = 0, Skins = 0, Emotes = 0}

    -- Characters, both roles.
    for _, Role in {"Killer", "Survivor"} do
        pcall(function()
            local Source = ReplicatedStorage.Characters:FindFirstChild(Role.."s")
            local Target = Purchased:FindFirstChild(Role.."s")
            if not Source or not Target then
                return
            end

            for _, Module in Source:GetChildren() do
                if Module:IsA("ModuleScript") and OwnerPerks._Grant(Target, Module.Name) then
                    Granted[Role.."s"] += 1
                end
            end
        end)
    end

    -- Skins, which are nested one folder deeper per character.
    pcall(function()
        local SkinRoot = ReplicatedStorage.Characters:FindFirstChild("Skins")
        if not SkinRoot then
            return
        end

        for _, RoleFolder in SkinRoot:GetChildren() do
            for _, CharacterFolder in RoleFolder:GetChildren() do
                -- `Purchased.Skins` has a folder per character, created on demand.
                local Target = Utils.PlayerData.CreateMissingPurchasedSkinValue(Player, CharacterFolder.Name)

                for _, Skin in CharacterFolder:GetChildren() do
                    if Skin:IsA("ModuleScript") and OwnerPerks._Grant(Target, Skin.Name) then
                        Granted.Skins += 1
                    end
                end
            end
        end
    end)

    -- Emotes.
    pcall(function()
        local Source = ReplicatedStorage.Assets:FindFirstChild("Emotes")
        local Target = Purchased:FindFirstChild("Emotes")
        if not Source or not Target then
            return
        end

        for _, Emote in Source:GetChildren() do
            if Emote:IsA("ModuleScript") and OwnerPerks._Grant(Target, Emote.Name) then
                Granted.Emotes += 1
            end
        end
    end)

    print(("[OwnerPerks] %s now owns everything — %d killer(s), %d survivor(s), %d skin(s), %d emote(s) unlocked this session.")
        :format(Player.Name, Granted.Killers, Granted.Survivors, Granted.Skins, Granted.Emotes))
end

--- The narrower path, for when `GrantEverything` is off: just the listed killers.
function OwnerPerks._GrantKillers(Player: Player)
    if OwnerPerks.GrantEverything then
        OwnerPerks._GrantAll(Player)
        return
    end

    if #OwnerPerks.Killers <= 0 then
        return
    end

    local Purchased = Utils.Instance.FindFirstChild(Player, "PlayerData.Purchased.Killers", 30)
    if not Purchased then
        warn("[OwnerPerks] Couldn't find `PlayerData.Purchased.Killers` for "..Player.Name..". No killers granted.")
        return
    end

    for _, Name in OwnerPerks.Killers do
        if not Utils.Instance.FindFirstChild(ReplicatedStorage, "Characters.Killers."..Name, 0) then
            warn("[OwnerPerks] No killer module named \""..Name.."\" — skipping the grant.")
            continue
        end

        if OwnerPerks._Grant(Purchased, Name) then
            print("[OwnerPerks] Unlocked \""..Name.."\" for "..Player.Name..".")
        end
    end
end

function OwnerPerks:Init()
    if not RunService:IsServer() or not OwnerPerks.Enabled then
        return
    end

    Utils.Player.ObservePlayers(function(Player: Player)
        if not OwnerPerks.IsOwner(Player) then
            return
        end

        -- Spawned rather than called directly: `_Apply` waits for the player's data to
        -- load, and `ObservePlayers` shouldn't be blocked while that happens.
        task.spawn(OwnerPerks._Apply, Player)
    end)
end

return OwnerPerks
