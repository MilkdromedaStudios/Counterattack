--[=[
    WEATHER — RUN CONTEXT

    One of these is handed to an event when it starts and thrown away when it ends. It is
    the ONLY thing an event is allowed to touch: every event reads the arena from it,
    spawns through it, damages through it and waits on it.

    That indirection is what stops the port from becoming eleven copies of the same bugs.
    NDS's disasters each reached straight into the world — `game.Workspace.Structure`,
    `game.Lighting`, `game.Players:GetPlayers()` — so a disaster that ended badly left its
    parts, its fog and its damage loop behind, and the next round inherited them. Here an
    event cannot spawn anything the context doesn't know about, and `Stop` takes the lot
    down whether the event exited cleanly or errored halfway through.
]=]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(ReplicatedStorage.Modules.Utils)
local Network = require(ReplicatedStorage.Modules.Network)

local Config = require(script.Parent.Config)
local Arena = require(script.Parent.Arena)

local Context = {}
Context.__index = Context

export type Context = typeof(setmetatable({} :: {
    Region: Arena.Region,
    Effects: Folder,
    Rand: Random,
    Running: boolean,
    EventName: string,
    DamageScale: number,
    _Tracked: {Instance},
    _Connections: {RBXScriptConnection},
}, Context))

--------------------------------------------------------------------------------
-- LIFECYCLE
--------------------------------------------------------------------------------

--[=[
    Builds a context for one event on one arena.

    The `WeatherEffects` folder is parented INSIDE the map on purpose. When the round ends
    `MapManager.DestroyCurrentMap` destroys the map, and everything the weather made goes
    with it — so even a crashed event cannot leave meteors floating over the lobby.
]=]
function Context.new(Region: Arena.Region, EventName: string, Seed: number?): Context
    local Effects = Region.Map:FindFirstChild("WeatherEffects")
    if not Effects then
        Effects = Instance.new("Folder")
        Effects.Name = "WeatherEffects"
        Effects.Parent = Region.Map
    end

    return setmetatable({
        Region = Region,
        Effects = Effects,
        Rand = Random.new(Seed or os.clock() * 1e6),
        Running = true,
        EventName = EventName,
        --[[
            Escalation multiplier for this event, set by `Runner` when it starts it.

            `1` unless the round has been dragging. Defaulted here rather than left nil so
            an event started outside the runner — a test, a mod command — still damages
            normally instead of multiplying by nothing and silently doing nothing.
        ]]
        DamageScale = 1,
        _Tracked = {},
        _Connections = {},
    }, Context)
end

--[=[
    Winds the event down and removes everything it made.

    `Running` is cleared FIRST so every loop still in flight sees it on its next iteration
    and stops adding to the pile this function is trying to empty.
]=]
function Context:Stop()
    self.Running = false

    for _, Connection in self._Connections do
        pcall(function()
            Connection:Disconnect()
        end)
    end
    table.clear(self._Connections)

    for _, Object in self._Tracked do
        if Object and Object.Parent then
            pcall(function()
                Object:Destroy()
            end)
        end
    end
    table.clear(self._Tracked)
end

--------------------------------------------------------------------------------
-- TRACKING
--------------------------------------------------------------------------------

--- Registers an instance so `Stop` will destroy it. Returns the instance for chaining.
function Context:Track<T>(Object: T & Instance, Lifetime: number?): T
    table.insert(self._Tracked, Object)
    if Lifetime then
        Debris:AddItem(Object, Lifetime)
    end
    return Object
end

--- Registers a connection so `Stop` will disconnect it.
function Context:TrackConnection(Connection: RBXScriptConnection): RBXScriptConnection
    table.insert(self._Connections, Connection)
    return Connection
end

--[=[
    `task.wait` that reports whether the event is still allowed to run.

    Every event loop is written as `while ctx:Wait(dt) do`, which means an event can never
    outlive its own cleanup — the round ending stops the loop on its next tick instead of
    letting it run to its natural end over a torn-down map.
]=]
function Context:Wait(Seconds: number?): boolean
    task.wait(Seconds)
    return self.Running and self.Region.Map.Parent ~= nil
end

--------------------------------------------------------------------------------
-- SPAWNING
--------------------------------------------------------------------------------

--[=[
    Creates a part already parented into the effects folder and already tracked.

    Every part the weather makes goes through here, which is what guarantees the cleanup
    is complete rather than mostly complete.
]=]
function Context:Part(Properties: {[string]: any}?, Lifetime: number?): BasePart
    local Part = Instance.new("Part")
    Part.Anchored = true
    Part.CanCollide = false
    Part.CanQuery = false
    Part.CanTouch = false
    Part.CastShadow = false
    Part.TopSurface = Enum.SurfaceType.Smooth
    Part.BottomSurface = Enum.SurfaceType.Smooth

    for Name, Value in Properties or {} do
        (Part :: any)[Name] = Value
    end

    Part.Parent = self.Effects
    return self:Track(Part, Lifetime)
end

--- Plays a one-shot sound. Positional when `At` is given, ambient otherwise.
function Context:Sound(SoundId: string, Volume: number?, At: (Vector3 | BasePart)?, Pitch: number?)
    local Holder: BasePart

    if typeof(At) == "Instance" then
        Holder = At
    else
        Holder = self:Part({
            Transparency = 1,
            Size = Vector3.one,
            Position = typeof(At) == "Vector3" and At or self.Region.Center,
        }, 12)
    end

    local Sound = Instance.new("Sound")
    Sound.SoundId = SoundId
    Sound.Volume = Volume or 0.5
    Sound.PlaybackSpeed = Pitch or 1
    Sound.RollOffMode = Enum.RollOffMode.InverseTapered
    Sound.RollOffMaxDistance = math.max(400, self.Region.Radius * 3)
    Sound.Parent = Holder
    Sound:Play()

    Debris:AddItem(Sound, 12)
end

--------------------------------------------------------------------------------
-- THE ARENA
--------------------------------------------------------------------------------

--- A random point on the arena floor.
function Context:RandomPoint(RadiusScale: number?): Vector3
    return Arena.RandomPoint(self.Region, self.Rand, RadiusScale)
end

--- A random point in the sky above the arena, ready to drop something from.
function Context:RandomSkyPoint(RadiusScale: number?): Vector3
    local Ground = self:RandomPoint(RadiusScale)
    return Vector3.new(Ground.X, self.Region.SkyY, Ground.Z)
end

--[=[
    Raycast that ignores the weather's own effect parts.

    NDS's `castray` re-cast recursively past anything intangible, walking a hand-written
    list of part names. `RaycastParams` does the same job in one call and — critically —
    excludes the fog, dust and rain slivers this system spawns, which would otherwise
    block every ray the moment a storm started.
]=]
function Context:Raycast(Origin: Vector3, Direction: Vector3, Length: number, Ignore: {Instance}?): RaycastResult?
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude

    local Filter = {self.Effects}
    for _, Extra in Ignore or {} do
        table.insert(Filter, Extra)
    end
    Params.FilterDescendantsInstances = Filter
    Params.IgnoreWater = true

    return workspace:Raycast(Origin, Direction.Unit * Length, Params)
end

--- Drops a ray onto the arena floor from above and returns where it landed.
function Context:GroundAt(Position: Vector3): Vector3
    local Result = self:Raycast(
        Vector3.new(Position.X, self.Region.SkyY, Position.Z),
        Vector3.new(0, -1, 0),
        self.Region.SkyY - self.Region.GroundY + 200
    )

    return Result and Result.Position or Vector3.new(Position.X, self.Region.GroundY, Position.Z)
end

--------------------------------------------------------------------------------
-- FIGHTERS
--------------------------------------------------------------------------------

--[=[
    Every character the weather is allowed to affect.

    Spectators in the lobby are excluded by `GetAliveFighters`, and anyone standing outside
    the arena footprint is excluded here — a storm on the map should not be killing people
    queued in the lobby just because the lobby happens to be nearby.
]=]
function Context:Fighters(): {Model}
    local Result = {}

    local PlayersFolder = workspace:FindFirstChild("Players")
    if not PlayersFolder then
        return Result
    end

    for _, Character in PlayersFolder:GetChildren() do
        if not Character:IsA("Model") then
            continue
        end

        local Role = Character:FindFirstChild("Role")
        if not Role or (Role :: StringValue).Value == "Spectator" then
            continue
        end

        if Character:GetAttribute("Dead") == true then
            continue
        end

        local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid or Humanoid.Health <= 0 then
            continue
        end

        local Root = Character:FindFirstChild("HumanoidRootPart")
        if not Root or not Arena.Contains(self.Region, (Root :: BasePart).Position, 150) then
            continue
        end

        table.insert(Result, Character)
    end

    return Result
end

--[=[
    Applies weather damage to a character.

    Deliberately NOT routed through `CommonFunctions.DamagePlayer`: that function exists to
    resolve one PLAYER hurting another — it needs a `SourcePlayer`, it assigns kill credit
    and it feeds killstreaks. A blizzard is not a player and must not hand anybody a kill.
    Weather damage is unattributed by design, which also means a fighter who freezes to
    death simply dies rather than crediting whoever hit them last.

    Spawn protection is still honoured, because being dropped into a round already on fire
    is not a fight anybody agreed to.
]=]
function Context:Damage(Character: Model, Amount: number, _Reason: string?)
    if Amount <= 0 then
        return
    end

    local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
    if not Humanoid or Humanoid.Health <= 0 then
        return
    end

    if Config.RespectSpawnProtection and Utils.Instance.FindFirstChild(Character, "Effects.StunSpawnProtection", 0) then
        return
    end

    Humanoid:TakeDamage(Amount * Config.DamageMultiplier * (self.DamageScale or 1))
end

--- Shoves a character. Used by the tornado and the shockwaves; never lethal on its own.
function Context:Shove(Character: Model, Velocity: Vector3)
    local Root = Character:FindFirstChild("HumanoidRootPart")
    if not Root or not Root:IsA("BasePart") then
        return
    end

    Root.AssemblyLinearVelocity += Velocity
end

--------------------------------------------------------------------------------
-- THE MAP'S OWN PARTS
--------------------------------------------------------------------------------

--[=[
    The map parts an event is permitted to fling around.

    Returns nothing at all unless `Config.DestroyMapParts` is on — see the comment on that
    setting for why the default is "the arena survives the weather".
]=]
function Context:LooseParts(): {BasePart}
    local Result = {}

    if not Config.DestroyMapParts then
        return Result
    end

    for _, Descendant in self.Region.Map:GetDescendants() do
        if #Result >= Config.MaxLoosePartsPerPass then
            break
        end

        if not Descendant:IsA("BasePart") or Descendant.Anchored then
            continue
        end

        if Descendant:IsDescendantOf(self.Effects) then
            continue
        end

        -- Never touch anything living. Characters are parented under `workspace.Players`,
        -- not the map, but ragdolls and dropped items do end up inside it.
        if Descendant.Parent and Descendant.Parent:FindFirstChildWhichIsA("Humanoid") then
            continue
        end

        if Descendant:FindFirstChild(Config.KeepAnchoredMarker) or Descendant:GetAttribute(Config.KeepAnchoredMarker) then
            continue
        end

        table.insert(Result, Descendant)
    end

    return Result
end

--------------------------------------------------------------------------------
-- TALKING TO CLIENTS
--------------------------------------------------------------------------------

--- Puts the warning banner on everyone's screen.
function Context:Announce(Title: string, Subtitle: string?)
    Network:FireAllClientConnection("WeatherWarning", "REMOTE_EVENT", Title, Subtitle)
end

--[=[
    Pushes a visual state to every client — fog, tint, and the full-screen overlay.

    The lighting is driven from the CLIENT rather than written onto `Lighting` from here.
    `Modules.Lighting` hands each client its own copy of the map's lighting on spawn and
    resets it between rounds; a server writing fog on top of that fights the client for the
    same properties and loses at the worst possible moment — the round transition, leaving
    somebody permanently snowed in. Sending the weather as state the client applies and
    unwinds itself keeps one owner per property.
]=]
function Context:SetVisuals(State: {[string]: any}?)
    Network:FireAllClientConnection("WeatherVisuals", "REMOTE_EVENT", self.EventName, State)
end

--- Clears whatever `SetVisuals` last set, over `FadeTime` seconds.
function Context:ClearVisuals(FadeTime: number?)
    Network:FireAllClientConnection("WeatherVisuals", "REMOTE_EVENT", self.EventName, nil, FadeTime)
end

--------------------------------------------------------------------------------
-- LOCAL PLAYER LOOKUP
--------------------------------------------------------------------------------

--- The `Player` behind a character, or nil for anything that isn't one.
function Context:PlayerFor(Character: Model): Player?
    return Players:GetPlayerFromCharacter(Character)
end

return Context
