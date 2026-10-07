local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerSprintManager = require(ServerScriptService.Managers.PlayerManager.PlayerSprintManager)
local Utils = require(ReplicatedStorage.Modules.Utils)
local GameMode = require(ReplicatedStorage.Modules.GameMode)
local PlayerManager = require(script.Parent.PlayerManager)
local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Rand = Random.new()

local ServerCharacterManager = {}

local PlayersRemainingFolder = ReplicatedStorage.RoundInfo.PlayersRemaining

function ServerCharacterManager:Init()
end

--[=[
    Finds the map's `SpawnPoints` folder, wherever it is.

    This used to be `(workspace.Map:FindFirstChild("Map") or workspace.Map):FindFirstChild("SpawnPoints")`
    — a non-recursive lookup at exactly one depth, guessed by a two-level dance over
    whether the map has an inner `Map` model.

    That is why a map worked in Workspace but not in ServerStorage. `MapManager` clones the
    ServerStorage prefab and renames the CLONE to "Map", so the nesting depth of everything
    inside shifts by one relative to a map dragged into Workspace by hand. `SpawnPoints`
    then sat one level off from where this looked, and the map reported no spawn points
    despite having plenty.

    Searching recursively removes the guess entirely. There is only ever one `SpawnPoints`
    folder in a map, so there is nothing to be ambiguous about.
]=]
function ServerCharacterManager.FindSpawnPointsFolder(): Instance?
    local Map = workspace:FindFirstChild("Map")
    if not Map then
        return nil
    end

    return Map:FindFirstChild("SpawnPoints", true)
end

--- Returns the chosen spawn layout folder of the current map, or `nil` if the map
--- isn't set up with spawn points.
function ServerCharacterManager._GetSpawnLayout(): Folder?
    local SpawnPoints = ServerCharacterManager.FindSpawnPointsFolder()
    if not SpawnPoints then
        return
    end

    local Layouts = SpawnPoints:GetChildren()
    if #Layouts <= 0 then
        return
    end

    -- `MapManager.GetRandomMap()` picks one layout when the map ships several and records
    -- it here, so every fighter is drawn from the same set. It used to enforce that by
    -- deleting the other layouts, which was a destructive way to make a choice.
    local Chosen = SpawnPoints:GetAttribute("ChosenLayout")
    if Chosen then
        local Layout = SpawnPoints:FindFirstChild(Chosen)
        if Layout then
            return Layout
        end
    end

    return Layouts[#Layouts > 1 and Rand:NextInteger(1, #Layouts) or 1]
end

--[=[
    FREE FOR ALL SPAWNING

    Everyone shares the `Killer` role in this mode, so the original "grab a random part
    out of the `Killers` folder" logic would stack the whole lobby on top of each other
    (and would ignore every survivor spawn the map already has).

    Instead: pool every spawn part across every role folder in the layout, score each
    one by how far it is from the nearest living fighter, then take a random pick from
    the most isolated ones. Dropping into a live match therefore never puts you inside
    somebody's slash range.
]=]
function ServerCharacterManager._GetFreeForAllSpawn(Char: Model): CFrame?
    --[=[
        Find somewhere — anywhere — to stand.

        Free For All doesn't care which role folder a spawn part sits in, so there's no
        reason to be strict about the folder structure either. The engine's template is
        `SpawnPoints/<Layout>/Killers/<part>`, but a map built without reading the template
        is far more likely to be `SpawnPoints/Killers/<part>` or just a pile of parts in
        `SpawnPoints`, and every one of those is a perfectly clear statement of intent.

        So: try the layout, then the whole `SpawnPoints` folder however it's nested, then
        any `SpawnLocation` in the map. Only give up when the map genuinely says nothing
        about where people go.
    ]=]
    local Candidates = {}

    local function Collect(Root: Instance?, Filter: ((Instance) -> boolean)?)
        if not Root or #Candidates > 0 then
            return
        end

        for _, Descendant in Root:GetDescendants() do
            if Descendant:IsA("BasePart") and (not Filter or Filter(Descendant)) then
                table.insert(Candidates, Descendant)
            end
        end
    end

    -- 1. The chosen layout, as the template intends.
    Collect(ServerCharacterManager._GetSpawnLayout())

    -- 2. Anything under `SpawnPoints`, however the map nests it.
    Collect(ServerCharacterManager.FindSpawnPointsFolder())

    -- 3. Plain Roblox `SpawnLocation`s dropped anywhere in the map.
    Collect(workspace:FindFirstChild("Map"), function(Part)
        return Part:IsA("SpawnLocation")
    end)

    if #Candidates <= 0 then
        return
    end

    -- Positions of everyone already fighting, so we can spawn away from them.
    local OccupiedPositions = {}
    for _, Fighter: Model in GameMode.GetAliveFighters() do
        if Fighter == Char then
            continue
        end

        local Root = Utils.Character.GetRootPart(Fighter)
        if Root then
            table.insert(OccupiedPositions, Root.Position)
        end
    end

    -- Nobody around yet (match start): any spawn is as good as another.
    if #OccupiedPositions <= 0 then
        return Candidates[Rand:NextInteger(1, #Candidates)].CFrame
    end

    -- Score every spawn by its distance to the closest fighter.
    local Scored = {}
    for _, SpawnPart: BasePart in Candidates do
        local Closest = math.huge
        for _, Position in OccupiedPositions do
            local Distance = (SpawnPart.Position - Position).Magnitude
            if Distance < Closest then
                Closest = Distance
            end
        end

        table.insert(Scored, {Part = SpawnPart, Score = Closest})
    end

    table.sort(Scored, function(a, b)
        return a.Score > b.Score
    end)

    -- Anything at or past the safe distance is fair game — pick randomly among those so
    -- spawns don't become predictable. If nothing qualifies, take the furthest one there is.
    local Safe = {}
    for _, Entry in Scored do
        if Entry.Score >= GameMode.Config.SafeSpawnDistance then
            table.insert(Safe, Entry.Part)
        end
    end

    if #Safe > 0 then
        return Safe[Rand:NextInteger(1, #Safe)].CFrame
    end

    return Scored[1].Part.CFrame
end

--[=[
    Moves a freshly built character onto a spawn point.

    @return `true` if the character was actually moved somewhere.

    That return value matters more than it looks. Every failure path in here used to
    return nothing, so the caller couldn't tell a successful spawn from a failed one and
    carried on regardless — leaving the character wherever `_RespawnPlayer` had parked it,
    which is `CFrame.new(0, 10, 0)`. On a map with no baseplate at the origin that means
    the player falls out of the world the instant they spawn, with no error anywhere.

    From the player's seat that is indistinguishable from a broken camera: you press PLAY,
    your body vanishes, and the view doesn't go anywhere. Now the caller can tell, and
    can put you back in the lobby with an explanation instead.
]=]
function ServerCharacterManager._PositionCharacter(Char: Model, charType: "Survivor" | "Killer", cf: CFrame?): boolean
    if cf then
        Char:PivotTo(cf)
        return true
    end

    --if it's neither of the roles it won't position the character
    if not charType then
        return false
    end

    --free for all pools every spawn point in the map instead of using the role's folder
    if GameMode.Enabled then
        local FFASpawn = ServerCharacterManager._GetFreeForAllSpawn(Char)
        if FFASpawn then
            Char:PivotTo(FFASpawn)
            return true
        end

        warn("[ServerCharacterManager._PositionCharacter()] No usable spawn points found for Free For All! Make sure your arena has a \"SpawnPoints\" folder with at least one layout folder full of anchored, invisible, non-collidable parts. Falling back to the role folder...")
    end

    --will try to get the current map
    local Map = workspace:FindFirstChild("Map")
    if not Map then
        return false
    end

    --will try to get the map itself (because the map itself is parented to a folder named `Map` where `Config` and `Behaviour` reside)
    Map = Map:FindFirstChild("Map")
    if not Map then
        warn("[ServerCharacterManager._PositionCharacter()] The map should be in a whole model inside of the map's folder! Check the template map! Using the folder itself instead...")
        
        Map = workspace:FindFirstChild("Map")
    end

    --will try to get the spawn points of the map
    local SpawnPoints = Map:FindFirstChild("SpawnPoints")
    if not SpawnPoints then
        --i am so lazy to split this string
        warn("[ServerCharacterManager._PositionCharacter()] Spawn points aren't set for this map! Inside of the map there should be a folder called \"SpawnPoints\" containing a folder for every possible spawn layout also containing a folder for every role (\"Killers\" and \"Survivors\" by default)! Preventing character positioning...")

        return false
    end

    --will check if the map has any spawn point layouts
    SpawnPoints = SpawnPoints:GetChildren()
    if #SpawnPoints <= 0 then
        warn("[ServerCharacterManager._PositionCharacter()] The map's spawn point folder is empty! Make sure to make some spawn point layouts! Preventing character positioning...")
        
        return false
    end

    --will get a random layout if there's more than 1 available (which there shouldn't)
    SpawnPoints = SpawnPoints[#SpawnPoints > 1 and Rand:NextInteger(1, #SpawnPoints) or 1]
    local LayoutName = SpawnPoints.Name
    --will try to get the spawn points for the character's specific role
    SpawnPoints = SpawnPoints:FindFirstChild(charType.."s")

    if not SpawnPoints then
        --i am so lazy to split this string
        warn("[ServerCharacterManager._PositionCharacter()] There are no spawn points for the \""..charType.."\" role! Make sure the folder named \""..LayoutName.."\" in this map's layouts contains a folder for this role named \""..charType.."s\"! Preventing character positioning...")
        
        return false
    end

    --will try to get any spawn points in the folder
    SpawnPoints = SpawnPoints:GetChildren()
    if #SpawnPoints <= 0 then
        --i am so lazy to split this string
        warn("[ServerCharacterManager._PositionCharacter()] Spawn Points aren't set for the \""..charType.."\" role in this map! Preventing character positioning...")

        return false
    end

    --will try to choose a BasePart spawnpoint from the children of the folder
    local ChosenSpawnPoint = SpawnPoints[Rand:NextInteger(1, #SpawnPoints)]
    if not ChosenSpawnPoint:IsA("BasePart") then
        --i could make this cycle to another spawn but meh the rest would probably be badly set up the same way so yeah
        warn("[ServerCharacterManager._PositionCharacter()] Chosen spawn point is not a BasePart! Make sure all of your spawn points are invisible, anchored, non-collidable baseparts which anchor point is touching the ground! Check the template map! Preventing character positioning...")

        return false
    end

    --will move the character to that spawn point
    Char:PivotTo(ChosenSpawnPoint.CFrame)

    return true
end

--- Sets up a player's character specified by its name, its type, and a possible skin.
--- Can also take a `CFrame` parameter to pivot the character there.
function ServerCharacterManager.SetupCharacter(player: Player, charName: string, charType: "Survivor" | "Killer", skinName: string?, cf: CFrame?)
    local Char: Model = PlayerManager._RespawnPlayer(player, charName, charType, skinName)
    --setting the character's position
    local Positioned = ServerCharacterManager._PositionCharacter(Char, charType, cf)

    --[[
        Record whether this body ever reached a spawn point. Without a spawn point
        `_RespawnPlayer` leaves it at `CFrame.new(0, 10, 0)`, which on most maps means
        falling out of the world immediately.

        The attribute rather than just the return value, because `SetupCharacter` has
        several callers and the ones that don't check it can at least be debugged from
        the explorer.
    ]]
    if Char then
        Char:SetAttribute("SpawnedProperly", Positioned == true)
    end

    -- Everyone in a Free For All is a fighter, so everyone belongs on the remaining list.
    -- In classic mode this stays survivor-only, since the killer isn't "remaining" there.
    if charType == "Survivor" or (GameMode.Enabled and charType == "Killer") then
        local Existing = PlayersRemainingFolder:FindFirstChild(tostring(player.UserId))
        if Existing then
            Existing:Destroy()
        end

	    local Remaining = Instance.new("ObjectValue")
	    Remaining.Name = player.UserId
	    Remaining.Value = player
	    Remaining.Parent = PlayersRemainingFolder
    end

    if not charName or not charType then
        return Char
    end

    ServerCharacterManager._InitCharacter(player, Char, Utils.Instance.GetCharacterModule(charType, charName, skinName))

    return Char
end

--- Inits a character's abilities and sets its properties accordingly as specified in its `GameplayConfig`.
function ServerCharacterManager._InitCharacter(player: Player, Char: Model, charModule: ModuleScript)
    local module = Utils.Type.CopyTable(require(charModule))
    module.Owner = player

    --Abilities
    local CharacterAbilities = require(Char.PlayerAbilities.CharacterAbilities)
    CharacterAbilities.CharacterModule = module

    local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
    Humanoid.MaxHealth = module.GameplayConfig.Health
    Humanoid.Health = module.GameplayConfig.Health
    Humanoid.JumpPower = 0
    Humanoid.JumpHeight = 0

    task.defer(function()
        if not PlayerSprintManager.ManagedPlayers[player] then
            local Timeout = 0
            repeat
                task.wait()
                Timeout += 1
            until PlayerSprintManager.ManagedPlayers[player] or Timeout >= 50
            if Timeout >= 50 then
                return
            end
        end

        PlayerSprintManager.ManagedPlayers[player].SprintMultiplier = module.GameplayConfig.SprintSpeedMultiplier
    end)

    Utils.Misc.PreloadAssets(module.Config)

    for name, value in module.GameplayConfig.StaminaProperties do
        local Property = Char.PlayerAttributes:FindFirstChild(name)
        if not Property then
            continue
        end

        Property.Value = value
    end

    for _, Ability in module.GameplayConfig.Abilities do
        Ability:Init(module, player)
        CharacterAbilities.Abilities[Ability] = Ability
    end

    task.defer(function()
        -- loading all execution animations
        task.defer(function()
            for rootName, _ in module.Config.AnimationIDs do
                if not rootName:lower():find("execution") then
                    continue
                end

                module.GameplayConfig.Cache.Animations[rootName] = {}

                for name, anims in module.Config.AnimationIDs[rootName] do
                    module.GameplayConfig.Cache.Animations[rootName][name] = {}
                    for animName, anim in anims do
                        if animName:lower() ~= "killer" then
                            continue
                        end

                        module.GameplayConfig.Cache.Animations[rootName][name][animName] = Utils.Character.LoadAnimationFromID(Char, anim)
                    end
                end
            end
        end)

        if not module.Config.Voicelines then
            return
        end

        local Primary = Utils.Character.GetRootPart(Char)
        if not Primary then
            return
        end

        local VoicelineJanitor = Janitor.new()
        VoicelineJanitor:LinkToInstance(Char)

        if module.Config.Voicelines.Stunned then
            Char.Effects.ChildAdded:Connect(function(newChild)
                if newChild.Name == "Stunned" then
                    Sounds.PlayVoiceline(Char, module.Config.Voicelines.Stunned)
                end
            end)
        end

        task.defer(function()
            if not module.Config.Voicelines.Idle then
                return
            end

            task.wait(math.random(10, 25))
            while player.Character and Char and player.Character == Char and Primary do
                if module.Config.Voicelines.Idle then
                    Sounds.PlayVoiceline(Char, module.Config.Voicelines.Idle, {
                        Priority = 0,
                    })
                end
                task.wait(math.random(10, 25))
            end
        end)

        if not module.Config.Voicelines.LMS then
            return
        end

        VoicelineJanitor:Add(Network:SetConnection("LMSVoiceline", "BINDABLE_EVENT", function(LastMan: Player)
            local Voiceline =
                module.Config.Voicelines.LMS[LastMan:GetAttribute("CharacterSkinName") and LastMan:GetAttribute("CharacterSkinName")..LastMan:GetAttribute("CharacterName") or LastMan:GetAttribute("CharacterName")]
                or module.Config.Voicelines.LMS["Default"]
                or module.Config.Voicelines.LMS

            Sounds.PlayVoiceline(Char, Voiceline, {
                Priority = 999,
            })
        end))
    end)

    if module.OnInit then
        module:OnInit(Char)
    end
end

return ServerCharacterManager
