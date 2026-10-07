local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Achievements = require(ReplicatedStorage.Assets.Achievements)
local Network = require(ReplicatedStorage.Modules.Network)
local InstanceUtils = require(script.Parent.InstanceUtils)
local TypeUtils = require(script.Parent.TypeUtils)

local PlayerDataUtils = {}

--[=[
    Cache of each player's resolved `PlayerData` folder.

    Every getter below starts by finding `Player.PlayerData.<something>`, and
    `InstanceUtils.FindFirstChild` falls back to `WaitForChild` with a five second timeout
    when it isn't there. That is correct for one call and disastrous for a loop: the shop
    asks "does this player own it?" once per character on the roster, so on a client whose
    save data hadn't replicated yet that was forty consecutive five-second waits — three
    minutes of a frozen menu build, which reads as the game hanging on the loading screen.

    Resolving the folder once per player and remembering it collapses that to a single
    wait. The entry is dropped when the folder leaves the player (they left, or the data
    was rebuilt), so a stale reference can't outlive what it points at.
]=]
local DataFolderCache: {[Player]: Folder} = {}
--- `os.clock()` of the last wait that timed out, per player. See `GetDataFolder`.
local LastFailedWait: {[Player]: number} = {}
--- Seconds to answer instantly with `nil` after a wait times out, before trying again.
local WAIT_COOLDOWN = 10

Players.PlayerRemoving:Connect(function(Player: Player)
    DataFolderCache[Player] = nil
    LastFailedWait[Player] = nil
end)

--[=[
    Resolves `Player.PlayerData`, waiting for it at most once every `WAIT_COOLDOWN`
    seconds.

    The cooldown is the part that matters, and caching alone would not have covered it:
    while the data is still in flight there is nothing to cache, so every call in a loop
    pays its own five second timeout and a forty-item loop takes over three minutes. The
    cooldown collapses a burst of calls to one wait and answers the rest instantly with
    `nil`.

    It is a cooldown rather than a one-shot flag because the SERVER also calls these
    getters, minutes into a session, for players whose data has since loaded — permanently
    refusing to wait after one early miss would have server code reading `nil` for
    somebody's equipped killer for the rest of the round.

    Returns `nil` rather than throwing when the data still isn't there. Callers are
    expected to cope: "the save hasn't arrived yet" is a normal state for the first few
    seconds of a session, not an error.
]=]
function PlayerDataUtils.GetDataFolder(Player: Player, Timeout: number?): Folder?
    if not Player then
        return nil
    end

    local Cached = DataFolderCache[Player]
    if Cached and Cached.Parent == Player then
        return Cached
    end

    DataFolderCache[Player] = nil

    local Folder = Player:FindFirstChild("PlayerData")

    if not Folder and (Timeout or 5) > 0 then
        local Last = LastFailedWait[Player]
        if not Last or os.clock() - Last >= WAIT_COOLDOWN then
            Folder = Player:WaitForChild("PlayerData", Timeout or 5)
            if not Folder then
                LastFailedWait[Player] = os.clock()
            end
        end
    end

    if Folder then
        DataFolderCache[Player] = Folder :: Folder
        LastFailedWait[Player] = nil
    end

    return Folder :: Folder?
end

--- Retrieves a player's equipped item of a type through a string path.
--- Also works for emotes.
--- If `value` is false, it'll return the `StringValue` object instead of the value itself.
function PlayerDataUtils.GetPlayerEquipped(Player: Player, path: string, value: boolean?): StringValue | string
    if value == nil then
        value = true
    end

    local splitPath = TypeUtils.SplitStringPath(path)
    local DataFolder = PlayerDataUtils.GetDataFolder(Player)
    local Equipped = DataFolder and DataFolder:FindFirstChild("Equipped")

    --[[
        No save data yet is a normal state, not an error.

        These getters used to walk straight into `Folder:FindFirstChild(...)` and then read
        `.Value` off the result, so a client whose `PlayerData` hadn't replicated got a
        throw out of every one of them. Anything that called one during startup — the
        sidebar's money label, the inventory's card list — died with it, and what the
        player saw was a menu that never appeared rather than a value that wasn't ready.
    ]]
    if not Equipped then
        return nil :: any
    end

    if #splitPath == 1 then
        local Child = Equipped:FindFirstChild(splitPath[1])
        return value and (Child and Child.Value or nil) or Child
    else
        local Child = Equipped
        for _, step in splitPath do
            if not Child then
                warn("[Utils:GetPlayerEquipped()] Child \""..step.."\" not found! Returning nil!")
                -- actually returning nil but preventing selene from crying
                return Child
            end

            if Child.Name == "Skins" then
                Child = Child:FindFirstChild(step)

                if not Child then
                    if RunService:IsServer() then
                        Child = PlayerDataUtils.CreateMissingSkinValue(Player, step)
                    else
                        Child = Network:FireServerConnection("CreateMissingSkinValue", "REMOTE_FUNCTION", step)
                    end
                end

                continue
            end
            
            Child = Child:FindFirstChild(step)
        end
        return value and Child.Value or Child
    end
end

--- Retrieves a player's purchased item of a type through a string path.
--- 
--- Also works for emotes.
--- 
--- If `value` is false, it'll return the `StringValue` object instead of the value itself.
function PlayerDataUtils.GetPlayerOwned(Player: Player, path: string, value: boolean?): StringValue | string
    if value == nil then
        value = true
    end

    local DataFolder = PlayerDataUtils.GetDataFolder(Player)
    local PurchasedFolder = DataFolder and DataFolder:FindFirstChild("Purchased")
    if not PurchasedFolder then
        -- Nothing is owned until we know what's owned. `false` is the honest answer and it
        -- is what every caller already handles; `nil` would read as "unknown" to nobody.
        return value and false or nil :: any
    end

    local Child = InstanceUtils.FindFirstChild(PurchasedFolder, path, 0)
    return value and (Child and Child.Value or false) or Child
end

--- Retrieves a player's stat through a string path.
--- 
--- If `value` is false, it'll return the `ValueBase` object instead of the value itself to modify it or to get a property from it (e.g. attributes).
function PlayerDataUtils.GetPlayerStat(Player: Player, path: string, value: boolean?): ValueBase | any
    if value == nil then
        value = true
    end

    local DataFolder = PlayerDataUtils.GetDataFolder(Player)
    local Stats = DataFolder and DataFolder:FindFirstChild("Stats")
    local Stat = Stats and InstanceUtils.FindFirstChild(Stats, path, 0)
    if not Stat then
        return nil :: any
    end

    return value and Stat.Value or Stat
end

--- Retrieves a player's setting value through a string path.
function PlayerDataUtils.GetPlayerSetting(Player: Player, path: string): any
    local splitPath = TypeUtils.SplitStringPath(path)
    local DataFolder = PlayerDataUtils.GetDataFolder(Player)
    local PlayerSettings = DataFolder and DataFolder:FindFirstChild("Settings")
    if not PlayerSettings then
        return nil
    end

    if #splitPath == 1 then
        local Setting = PlayerSettings:FindFirstChild(splitPath[1])
        return Setting and Setting.Value or nil
    else
        local Setting = PlayerSettings
        for _, step in splitPath do
            if not Setting then
                warn("[Utils:GetPlayerSetting()] Child \""..step.."\" not found! Returning nil!")
                return
            end
            Setting = Setting:FindFirstChild(step)
        end
        return Setting and Setting.Value or nil
    end
end

--- INTERNAL | SERVER FUNCTION: Used to create a character's equipped skin value for a player if it's missing.
function PlayerDataUtils.CreateMissingSkinValue(SourcePlayer: Player, name: string): StringValue
    if not RunService:IsServer() then
        return InstanceUtils.FindFirstChild(PlayerDataUtils.GetDataFolder(SourcePlayer), "Equipped.Skins."..name, 0) :: StringValue | any
    end

    local EquippedSkins = InstanceUtils.FindFirstChild(PlayerDataUtils.GetDataFolder(SourcePlayer), "Equipped.Skins", 0)
    local SkinValue = EquippedSkins:FindFirstChild(name)
    if SkinValue then
        return SkinValue
    end

    SkinValue = Instance.new("StringValue")
    SkinValue.Name = name
    SkinValue.Value = ""
    SkinValue.Parent = EquippedSkins

    return SkinValue
end

--- INTERNAL | SERVER FUNCTION: Used to create a character's purchased skins folder for a player if it's missing.
function PlayerDataUtils.CreateMissingPurchasedSkinValue(SourcePlayer: Player, name: string): Folder
    if not RunService:IsServer() then
        return InstanceUtils.FindFirstChild(PlayerDataUtils.GetDataFolder(SourcePlayer), "Purchased.Skins."..name, 0) :: Folder | any
    end

    local PurchasedSkins = InstanceUtils.FindFirstChild(PlayerDataUtils.GetDataFolder(SourcePlayer), "Purchased.Skins", 0)
    local SkinFolder = InstanceUtils.FindFirstChild(PurchasedSkins, name, 0)
    if SkinFolder then
        return SkinFolder
    end

    SkinFolder = Instance.new("Folder")
    SkinFolder.Name = name
    SkinFolder.Parent = PurchasedSkins

    return SkinFolder
end

function PlayerDataUtils.GetAchievementObject(SourcePlayer: Player, path: string): NumberValue | BoolValue
    local AchievementFolder = InstanceUtils.FindFirstChild(PlayerDataUtils.GetDataFolder(SourcePlayer), "Achievements", 0)
    local AchievementObject = InstanceUtils.FindFirstChild(AchievementFolder, path, 5)
    
    if not AchievementObject then
        local steps = TypeUtils.SplitStringPath(path)
        local Achievement = Achievements[steps[1]].Achievements[steps[2]]
        if not Achievement then
            return nil :: any
        end

        if Achievement.Requirement then
            AchievementObject = Instance.new("NumberValue")
            AchievementObject.Value = 0
        else
            AchievementObject = Instance.new("BoolValue")
            -- This read `AchievementObject = false`, replacing the freshly created
            -- BoolValue with a plain boolean. The next two lines then index a boolean and
            -- throw, so creating any boolean achievement that wasn't already in the
            -- player's data errored outright.
            AchievementObject.Value = false
        end
        AchievementObject.Name = steps[2]
        AchievementObject.Parent = AchievementFolder:FindFirstChild(steps[1])
    end

    return AchievementObject
end

return PlayerDataUtils
