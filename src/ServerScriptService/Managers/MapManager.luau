local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Lighting = require(ReplicatedStorage.Modules.Lighting)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)

local MapManager = {
    --- Allows the map to not be the same to the last one.
    CanRepeatMap = true, --might want to disable on release
    CurrentMap = nil,
    LastMap = nil,
}

local Rand = Random.new()

function MapManager:Init()
    MapManager.MapPrefabs = ServerStorage.Maps:GetChildren()

    -- iterating backwards to not have to do `table.find()` every single time i want to remove a map from the table
	for i = #MapManager.MapPrefabs, 1, -1 do
		local Map = MapManager.MapPrefabs[i]
		if not Map:IsA("Folder") and not Map:IsA("Model") then
			table.remove(MapManager.MapPrefabs, i)
		end
	end

    -- this was fucking useless -dys
    -- MapManager.CurrentMap = nil
    -- MapManager.LastMap = nil
end

--- Picks a random map from `ServerStorage.Assets.Maps` and inits everything related to it, setting it as `Map` in `workspace`.
--- If `MapManager.CanRepeatMap` is true, the map will never be the same to the one chosen the round before for variety.
function MapManager.GetRandomMap(): Model | Folder
    --[[
        Nothing to pick from. `Rand:NextInteger(1, 0)` throws, so without this guard an
        empty `ServerStorage.Maps` took down whatever was starting the round with a
        confusing error about integer ranges instead of the real problem.
    ]]
    if not MapManager.MapPrefabs or #MapManager.MapPrefabs <= 0 then
        warn("[MapManager.GetRandomMap()] There are no maps in `ServerStorage.Maps`! Add at least one Model or Folder containing a `Map` model with a `SpawnPoints` folder inside it. Preventing map spawn...")
        return
    end

    --chooses a random map
    local SelectedMap = MapManager.MapPrefabs[Rand:NextInteger(1, #MapManager.MapPrefabs)]
    --if it's the same as the one before it chooses a different one
    if not MapManager.CanRepeatMap and MapManager.LastMap and #MapManager.MapPrefabs > 1 then
        while SelectedMap == MapManager.LastMap do
            SelectedMap = MapManager.MapPrefabs[Rand:NextInteger(1, #MapManager.MapPrefabs)]
        end
    end
    --sets the "last map" as the current map for not repeating it next time
    MapManager.LastMap = SelectedMap

    --clones the map for usage
    local MapInstance = SelectedMap:Clone()

    --creates the InGame folder for ability instances
    if not MapInstance:FindFirstChild("InGame") then
        local InGameFolder = Instance.new("Folder")
        InGameFolder.Name = "InGame"
        InGameFolder.Parent = MapInstance
    end

    --creates the Items folder for spawned `PickableItem`s
    if not MapInstance:FindFirstChild("Items") then
        local ItemsFolder = Instance.new("Folder")
        ItemsFolder.Name = "Items"
        ItemsFolder.Parent = MapInstance
    end

    --TODO: make random PickableItem spawns

    --[[
        The geometry is expected to live in a `Map` model inside the map folder. If it
        doesn't, fall back to the folder itself rather than letting every `ActualMap:...`
        call below throw on a nil.
    ]]
    local ActualMap = MapInstance:FindFirstChild("Map")
    if not ActualMap then
        warn("[MapManager.GetRandomMap()] Map \""..SelectedMap.Name.."\" has no `Map` model inside it! Check the template map. Using the folder itself instead...")
        ActualMap = MapInstance
    end

    task.spawn(function()
        --checks if there are item spawn spots around
        local ItemSpawns = ActualMap:FindFirstChild("ItemSpawns")
        if not ItemSpawns then
            return
        end

        --every item should have its own folder with possible spawn spots
        for _, child in ItemSpawns:GetChildren() do
            if not child:IsA("Folder") then
                continue
            end

            --each folder should be named after its PickableItem
            local ItemEquivalent = ReplicatedStorage.Assets.PickableItems:FindFirstChild(child.Name)
            if not ItemEquivalent then
                return
            end
            ItemEquivalent = require(ItemEquivalent)

            for _, spawnPoint in child:GetChildren() do
                --every spawn point should be an anchored, invisible part
                if not spawnPoint:IsA("BasePart") then
                    continue
                end

                --you can add a Chance attribute to every spawn to have a 1 every X chance for the item to spawn there
                --by default it'll be a 1/10 chance
                local Chance = spawnPoint:GetAttribute("Chance") or 10
                local Result = Rand:NextInteger(1, Chance)
                if Result ~= 1 then
                    continue
                end

                --spawning the object
                local ItemInstance = Utils.Type.CopyTable(ItemEquivalent)
                ItemInstance:Init()

                --applies the exact same cframe as the spawn point
                local TargetCFrame = spawnPoint.CFrame

                --if the axis is supposed to be random then do so
                local RandomizedAxis = ItemEquivalent.RandomRotation
                if RandomizedAxis then
                    local RandomRotation = Vector3.new()
                    local AxisTable = RandomizedAxis == "All" and {"X", "Y", "Z"} or RandomizedAxis

                    for _, Axis in AxisTable do
                        RandomRotation[Axis] = Rand:NextInteger(0, 359)
                    end

                    TargetCFrame *= CFrame.fromEulerAnglesXYZ(math.rad(RandomRotation.X), math.rad(RandomRotation.Y), math.rad(RandomRotation.Z))
                end

                --if any offset is present, apply it
                if ItemEquivalent.CFrameOffset then
                    TargetCFrame *= ItemEquivalent.CFrameOffset
                end

                --place it where it's supposed to be
                ItemInstance.ModelInstance:PivotTo(TargetCFrame)
            end
        end
    end)

    --checks if there's more than 1 layout available
    local Spawnpoints = ActualMap:FindFirstChild("SpawnPoints")
    if not Spawnpoints then
        warn("[MapManager.GetRandomMap()] Map \""..SelectedMap.Name.."\" has no `SpawnPoints` folder! Nobody will be able to spawn in it. Check the template map.")
    end

    --[[
        Pick one layout and stick to it for the life of the map.

        This used to DESTROY the layouts it didn't pick — and to get the count wrong while
        doing it (`> 2`, so a map with exactly two layouts kept both and re-rolled per
        spawn). Destroying was the more dangerous half: the engine's template nests role
        folders inside a layout, but a map built as `SpawnPoints/Killers` +
        `SpawnPoints/Survivors` reads as "two layouts" and would have had one of its two
        real spawn folders deleted out from under it.

        Recording the choice as an attribute does the same job — one consistent layout —
        without touching anybody's map. `_GetSpawnLayout` reads it.
    ]]
    local AvailableLayouts = Spawnpoints and Spawnpoints:GetChildren() or {}
    if #AvailableLayouts > 1 then
        local ChosenLayout = AvailableLayouts[Rand:NextInteger(1, #AvailableLayouts)]
        Spawnpoints:SetAttribute("ChosenLayout", ChosenLayout.Name)
    end

    --i think this is used idk lol but it's useful
    MapManager.CurrentMap = MapInstance
    
    --tries to find the map's config module
    local ConfigModule = MapInstance:FindFirstChild("Config")
    if ConfigModule then
        local Config = require(ConfigModule)
        --will apply the ambience music if it's there
        if Config.Ambience then
            local Props = Config.AmbienceProperties or {}
            Props.Priority = Props.Priority or 0.5
            Props.Name = "MapAmbience"
            Sounds.PlayTheme(Config.Ambience, Props)
        end
    end

    --[[
        Clear out any map that's still standing before this one goes up.

        Everything downstream finds the arena with `workspace:FindFirstChild("Map")`, which
        returns ONE instance — so two maps both named "Map" in the world is a silent
        catastrophe: spawn points get read from one while the geometry players can see is
        the other, and people spawn in the void.

        `DestroyCurrentMap` is supposed to have run at the end of the previous round. This
        is here because "supposed to" wasn't good enough once: a bug in `EndRound` skipped
        the teardown and the duplicate went unnoticed because nothing errors, it just
        quietly stops making sense.
    ]]
    local Stale = workspace:FindFirstChild("Map")
    while Stale do
        warn("[MapManager.GetRandomMap()] A previous map was still in the workspace. Removing it before the new one goes up — the last round's teardown didn't finish.")
        Stale:Destroy()
        Stale = workspace:FindFirstChild("Map")
    end

    --renaming to generalize it
    MapInstance.Name = "Map"
    --creates PermAbilities folder if it isn't there
    if not MapInstance:FindFirstChild("PermAbilities") then
        local P = Instance.new("Folder")
        P.Name = "PermAbilities"
        P.Parent = MapInstance
    end
    --parented to workspace
    MapInstance.Parent = workspace
    --if it gets destroyed then the theme stops
    MapInstance.AncestryChanged:Connect(function()
        Sounds.StopTheme("MapAmbience")
    end)

    --will apply the lighting module if it's there
    local LightingModule = MapInstance:FindFirstChild("Lighting")
    if LightingModule then
        Lighting.SetCustomLighting(LightingModule)
    end

    --will execute a behaviour module if it exists for either custom map events or sfx that need to be initialized
    local BehaviourModule = MapInstance:FindFirstChild("Behaviour")
    if BehaviourModule then
        local Behaviour = require(MapInstance.Behaviour)
        if Behaviour.Init and typeof(Behaviour.Init) == "function" then
            Behaviour:Init()
        end
    end

    --returns the map instance for usage
    return MapInstance
end

function MapManager.DestroyCurrentMap()
    --[=[
        ABILITY STATE DIES WITH THE MAP.

        Projectiles, deployables and summons are all parented into `Map.InGame`, so
        destroying the map already removes their INSTANCES. What it does not remove is the
        bookkeeping: `ProjectileService`'s stepper is still holding handles and ticking their
        hitboxes, `DeployableService`'s registry still counts them against each player's
        placement limit, `SummonService`'s brain is still trying to path minions around a
        world that has gone, and `NPCService`'s shared stepper is still posing props whose
        parts have no parent.

        The symptoms of not doing this are quiet and confusing — a Builderman who can only
        place two sentries in the new round because three dead ones still count, a Creeper
        whose gunpowder from last round chains with this round's blast, warnings from
        steppers reaching for parts with no parent.

        It goes here rather than in `RoundManager.EndRound` because the map is torn down
        from THREE different places (the round ending, a start being aborted, and a stale
        map being cleared before a new one goes up), and this is the one function all three
        go through.

        Each service is cleared in its own `pcall`: a failure in one must not leave the
        other two holding a dead round, and none of them is important enough to stop a map
        teardown over.
    ]=]
    for _, Service in {"ProjectileService", "DeployableService", "SummonService", "NPCService"} do
        local Ok, Err = pcall(function()
            require(ReplicatedStorage.Modules[Service]).ClearAll()
        end)

        if not Ok then
            warn("[MapManager.DestroyCurrentMap()] Couldn't clear "..Service..": "..tostring(Err))
        end
    end

    if MapManager.CurrentMap then
        MapManager.CurrentMap:Destroy()
        MapManager.CurrentMap = nil
        Lighting.SetDefaultLighting()
    end
end

return MapManager
