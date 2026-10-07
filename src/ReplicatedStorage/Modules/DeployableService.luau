--[=[
    DEPLOYABLE SERVICE

    Things a killer puts on the floor and leaves there: Builderman's sentries and brick
    walls, Piggy's bear traps, Steve's blocks, Enderman's carried block, Fall Guy's
    obstacles, Tails' drone, Minion's bananas, Freddy's relocation points.

    THE PROBLEM THIS SOLVES
    ----------------------
    Every one of those wants the same five things — sit in the world, last a while, be
    destructible, be capped so the arena doesn't fill up with junk, and vanish cleanly at
    the end of a round — and not one of them wants the same *behaviour*. Writing that five
    times produced five slightly different lifetime bugs. Writing it once, with the
    behaviour passed in, does not.

    WHY A DEPLOYABLE IS SHAPED LIKE A CHARACTER
    ------------------------------------------
    Each one is a `Model` with a `Humanoid`, a root part carrying `HitboxPriority`, and a
    `Role` of `"Deployable"`. That looks odd until you see what it buys: `Classes.Hitbox`
    already knows how to find a humanoid, respect its health, apply resistance and award
    kill credit, and it rejects anything whose `Role` matches the attacker's. So shaping a
    deployable this way makes it destructible BY ANY KILLER'S NORMAL ATTACK with no change
    to the hitbox code at all, and survivor counterplay — "hit the turret" — comes for
    free.

    `ExecutionsDisabled` is set for the obvious reason: the basic attack executes what it
    kills, and nobody needs a cutscene of Wario performing a finisher on a brick.

    CLEANUP
    -------
    Deployables are parented into the map's `InGame` folder, so the map coming down takes
    them with it. The registry additionally drops its references when the instance leaves
    the world, so a torn-down round cannot leave this module holding a few hundred dead
    models.
]=]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AbilityFX = require(ReplicatedStorage.Modules.AbilityFX)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local Utils = require(ReplicatedStorage.Modules.Utils)

local DeployableService = {
    --- Ceiling across every player, so no combination of abilities can flood the arena.
    MaxTotal = 120,
}

--[=[
    Everything currently placed, keyed by player and then by kind.

    Keyed by kind as well as by player because the caps are per-kind: eight Steve blocks
    and two Builderman sentries are different budgets, and a player who is somehow both
    should not have them compete.
]=]
local Registry: {[Player]: {[string]: {any}}} = {}
local TotalCount = 0

Players.PlayerRemoving:Connect(function(player: Player)
    DeployableService.ClearFor(player)
    Registry[player] = nil
end)

--------------------------------------------------------------------------------
-- REGISTRY
--------------------------------------------------------------------------------

local function ListFor(player: Player, kind: string): {any}
    Registry[player] = Registry[player] or {}
    Registry[player][kind] = Registry[player][kind] or {}
    return Registry[player][kind]
end

local function Unregister(handle)
    local List = Registry[handle.Owner] and Registry[handle.Owner][handle.Kind]
    if not List then
        return
    end

    local Index = table.find(List, handle)
    if Index then
        table.remove(List, Index)
        TotalCount = math.max(TotalCount - 1, 0)
    end
end

--------------------------------------------------------------------------------
-- PLACING
--------------------------------------------------------------------------------

export type DeployableSettings = {
    --- Who owns it. Used for caps, kill credit, and for not shooting its own builder.
    SourcePlayer: Player,
    --- Category, used for the per-player cap. "Wall", "Turret", "Trap", "Block"…
    Kind: string,
    --- Where the root part goes.
    CFrame: CFrame,

    --- Instance name in the world.
    Name: string?,
    --- Size of the root part.
    Size: Vector3?,
    Color: Color3?,
    Material: Enum.Material?,
    Transparency: number?,
    Shape: Enum.PartType?,
    --- Whether it physically blocks movement. `true` for walls, `false` for traps.
    Solid: boolean?,

    --- How much damage it takes to break. `0` makes it indestructible, which almost
    --- nothing should be.
    Health: number?,
    --- Seconds before it removes itself.
    Lifetime: number?,
    --- How many of this kind this player may have out. Oldest is removed to make room.
    Limit: number?,

    --- Seconds between `OnTick` calls. Defaults to 0.5. Never per-frame.
    TickRate: number?,
    --- Periodic behaviour: a turret looking for targets, a station buffing its owner.
    OnTick: ((handle: any) -> ())?,

    --- Radius a fighter has to enter to set it off. Omit for things that don't trigger.
    TriggerRadius: number?,
    --- Called when somebody walks into the trigger radius.
    OnTrigger: ((handle: any, char: Model) -> ())?,
    --- Whether triggering removes it. Defaults to `true` — a trap is spent once sprung.
    TriggerOnce: boolean?,
    --- Whether the owner can set off their own trap. Defaults to `false`.
    TriggerOnOwner: boolean?,

    --- Called when its health runs out.
    OnDestroyed: ((handle: any) -> ())?,
    --- Called when it times out instead.
    OnExpire: ((handle: any) -> ())?,
    --- Called once however it ends. Cleanup goes here.
    OnEnd: ((handle: any) -> ())?,

    --- An outline in this colour, so everybody can see whose it is.
    OutlineColor: Color3?,
}

--[=[
    Puts one deployable in the world.

    @return A handle, or `nil` if it was refused. The handle carries `Model`, `Root`,
            `Humanoid`, and a `Destroy()`.
]=]
function DeployableService.Place(settings: DeployableSettings)
    if not RunService:IsServer() then
        return nil
    end

    local Player = settings.SourcePlayer
    if not Player then
        warn("[DeployableService.Place()] No `SourcePlayer`. Refused — a deployable with no owner can never be capped or cleaned up by owner.")
        return nil
    end

    if TotalCount >= DeployableService.MaxTotal then
        return nil
    end

    local Kind = settings.Kind or "Deployable"
    local List = ListFor(Player, Kind)

    --[=[
        Enforce the cap by removing the OLDEST, not by refusing the newest.

        This is the opposite of the choice `ProjectileService` makes, and on purpose: a
        projectile is a one-off that you can simply fire again, but a wall is a placement
        decision. "My newest wall silently didn't appear" is far more confusing mid-chase
        than "my oldest wall came down", which is both visible and the behaviour players
        expect from every build-limit in every game.
    ]=]
    local Limit = settings.Limit or 4
    while #List >= Limit do
        local Oldest = List[1]
        if not Oldest then
            break
        end
        Oldest:Destroy()
        -- `Destroy` unregisters, but guard against a handle that somehow didn't so this
        -- cannot spin forever.
        if List[1] == Oldest then
            table.remove(List, 1)
            TotalCount = math.max(TotalCount - 1, 0)
        end
    end

    local Health = settings.Health or 60
    local Lifetime = settings.Lifetime or 20

    ----------------------------------------------------------------------------
    -- THE INSTANCE
    ----------------------------------------------------------------------------

    local Model = Instance.new("Model")
    Model.Name = settings.Name or Kind

    -- Named `HumanoidRootPart` so `Utils.Character.GetRootPart` finds it, which is what
    -- `CommonFunctions.DamagePlayer` uses to work out where the hit landed.
    local Root = Instance.new("Part")
    Root.Name = "HumanoidRootPart"
    Root.Size = settings.Size or Vector3.new(4, 6, 1)
    Root.Shape = settings.Shape or Enum.PartType.Block
    Root.CFrame = settings.CFrame
    Root.Color = settings.Color or Color3.fromRGB(190, 120, 70)
    Root.Material = settings.Material or Enum.Material.Concrete
    Root.Transparency = settings.Transparency or 0
    Root.Anchored = true
    Root.CanCollide = settings.Solid == true
    Root.CanTouch = false
    Root.TopSurface = Enum.SurfaceType.Smooth
    Root.BottomSurface = Enum.SurfaceType.Smooth
    -- What makes it a legal hitbox target. Without this the hitbox filters it straight out.
    Root:SetAttribute("HitboxPriority", 1)
    Root.Parent = Model

    Model.PrimaryPart = Root

    local Humanoid = Instance.new("Humanoid")
    Humanoid.MaxHealth = Health
    Humanoid.Health = Health
    -- Nothing about this is a walking creature, and leaving the states on makes the
    -- engine run physics controllers for a brick.
    Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    Humanoid.Parent = Model

    -- `Role` is how `Hitbox` decides the attacker and the target are on different sides.
    -- Anything that isn't a player's own role reads as hostile, which is what we want:
    -- everyone can break everyone's deployables, including their own builder's rivals.
    local Role = Instance.new("StringValue")
    Role.Name = "Role"
    Role.Value = "Deployable"
    Role.Parent = Model

    -- So a basic attack that kills it doesn't try to play an execution animation on it.
    Model:SetAttribute("ExecutionsDisabled", true)
    Model:SetAttribute("Deployable", true)
    Model:SetAttribute("OwnerUserId", Player.UserId)
    Model:SetAttribute("Kind", Kind)

    if settings.OutlineColor then
        local Outline = Instance.new("Highlight")
        Outline.FillTransparency = 1
        Outline.OutlineColor = settings.OutlineColor
        Outline.OutlineTransparency = 0.35
        Outline.DepthMode = Enum.HighlightDepthMode.Occluded
        Outline.Adornee = Model
        Outline.Parent = Model
    end

    Model.Parent = AbilityFX.Folder()

    ----------------------------------------------------------------------------
    -- THE HANDLE
    ----------------------------------------------------------------------------

    local Handle
    Handle = {
        Model = Model,
        Root = Root,
        Humanoid = Humanoid,
        Owner = Player,
        Kind = Kind,
        Alive = true,
        PlacedAt = os.clock(),
        Lifetime = Lifetime,
        --- Free-form storage for the ability that placed it — ammo, charge, state.
        State = {},
    }

    function Handle:Destroy()
        if not Handle.Alive then
            return
        end
        Handle.Alive = false

        Unregister(Handle)

        if settings.OnEnd then
            local Ok, Err = pcall(settings.OnEnd, Handle)
            if not Ok then
                warn("[DeployableService] A deployable's `OnEnd` errored: "..tostring(Err))
            end
        end

        if Model and Model.Parent then
            -- Sink and fade rather than blink out, so it reads as being removed.
            TweenService:Create(Root, TweenInfo.new(0.25), {Transparency = 1}):Play()
            Debris:AddItem(Model, 0.3)
        end
    end

    --- Hurts it from a source other than a hitbox. Used by abilities that break structures.
    function Handle:Damage(amount: number, _byPlayer: Player?)
        if not Handle.Alive or not Humanoid or Humanoid.Health <= 0 then
            return
        end

        Humanoid:TakeDamage(amount)
        AbilityFX.Sparks(Root.Position, Root.Color, 8, 18)
    end

    table.insert(List, Handle)
    TotalCount += 1

    ----------------------------------------------------------------------------
    -- LIFETIME
    ----------------------------------------------------------------------------

    --[=[
        One `task.spawn` per deployable rather than a shared stepper.

        Unlike projectiles, deployables tick slowly (twice a second by default) and there
        are at most a hundred and twenty of them, so a shared per-frame stepper would be
        doing more work to schedule than the ticks themselves cost. The loop exits on any
        of: health gone, lifetime up, instance removed from the world, or `Alive` cleared.
        There is no path that leaves it running.
    ]=]
    task.spawn(function()
        local TickRate = settings.TickRate or 0.5
        local Elapsed = 0
        local Triggered = false

        while Handle.Alive do
            Elapsed += task.wait(TickRate)

            -- The map came down, or something else destroyed the model outright.
            if not Model.Parent then
                Handle.Alive = false
                Unregister(Handle)
                break
            end

            if Humanoid.Health <= 0 then
                if settings.OnDestroyed then
                    local Ok, Err = pcall(settings.OnDestroyed, Handle)
                    if not Ok then
                        warn("[DeployableService] A deployable's `OnDestroyed` errored: "..tostring(Err))
                    end
                end
                AbilityFX.Sparks(Root.Position, Root.Color, 20, 30)
                AbilityFX.Smoke(Root.Position, Color3.fromRGB(80, 80, 80), 10, 4)
                Handle:Destroy()
                break
            end

            if Lifetime > 0 and Elapsed >= Lifetime then
                if settings.OnExpire then
                    local Ok, Err = pcall(settings.OnExpire, Handle)
                    if not Ok then
                        warn("[DeployableService] A deployable's `OnExpire` errored: "..tostring(Err))
                    end
                end
                Handle:Destroy()
                break
            end

            -- PROXIMITY TRIGGER.
            if settings.TriggerRadius and settings.OnTrigger and not Triggered then
                local Exclude = (settings.TriggerOnOwner ~= true) and Player.Character or nil

                for _, Char: Model in CombatUtils.GetFightersInRadius(Root.Position, settings.TriggerRadius, Exclude) do
                    Triggered = true

                    local Ok, Err = pcall(settings.OnTrigger, Handle, Char)
                    if not Ok then
                        warn("[DeployableService] A deployable's `OnTrigger` errored: "..tostring(Err))
                    end

                    if settings.TriggerOnce ~= false then
                        Handle:Destroy()
                    else
                        -- Re-armable: let it fire again on a later tick.
                        Triggered = false
                    end
                    break
                end

                if not Handle.Alive then
                    break
                end
            end

            -- PERIODIC BEHAVIOUR.
            if settings.OnTick then
                local Ok, Err = pcall(settings.OnTick, Handle)
                if not Ok then
                    warn("[DeployableService] A deployable's `OnTick` errored: "..tostring(Err))
                end
            end
        end
    end)

    return Handle
end

--------------------------------------------------------------------------------
-- QUERIES
--------------------------------------------------------------------------------

--- Every live deployable of `kind` owned by `player`. Pass no kind for all of them.
function DeployableService.GetFor(player: Player, kind: string?): {any}
    local Owned = Registry[player]
    if not Owned then
        return {}
    end

    if kind then
        return table.clone(Owned[kind] or {})
    end

    local All = {}
    for _, List in Owned do
        for _, Handle in List do
            table.insert(All, Handle)
        end
    end
    return All
end

--[=[
    Every live deployable within `radius` of a point, nearest first.

    This is how abilities interact with the furniture: Knuckles' charged punch breaks
    structures, Kirby's inhale and Luigi's Poltergust eat small ones, Scrapheap's magnet
    drags metal, Impostor's sabotage disables them. `exclude` is normally the caller's own
    player, so nothing is rewarded for eating its own equipment.
]=]
function DeployableService.GetInRadius(position: Vector3, radius: number, exclude: Player?): {any}
    local Found = {}

    for Owner, Kinds in Registry do
        if Owner == exclude then
            continue
        end

        for _, List in Kinds do
            for _, Handle in List do
                if not Handle.Alive or not Handle.Root or not Handle.Root.Parent then
                    continue
                end

                local Distance = (Handle.Root.Position - position).Magnitude
                if Distance <= radius then
                    table.insert(Found, {Handle = Handle, Distance = Distance})
                end
            end
        end
    end

    table.sort(Found, function(a, b)
        return a.Distance < b.Distance
    end)

    local Result = {}
    for _, Entry in Found do
        table.insert(Result, Entry.Handle)
    end
    return Result
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

--- Removes everything one player has placed. Used when they die or leave.
function DeployableService.ClearFor(player: Player, kind: string?)
    local Owned = Registry[player]
    if not Owned then
        return
    end

    for ThisKind, List in Owned do
        if kind and ThisKind ~= kind then
            continue
        end

        for Index = #List, 1, -1 do
            local Handle = List[Index]
            if Handle then
                Handle:Destroy()
            end
        end

        table.clear(List)
    end
end

--- Removes everything, everywhere. Called at the end of a round.
function DeployableService.ClearAll()
    for Player in Registry do
        DeployableService.ClearFor(Player)
    end

    table.clear(Registry)
    TotalCount = 0
end

--------------------------------------------------------------------------------
-- TURRET HELPER
--------------------------------------------------------------------------------

--[=[
    The firing half of a turret, shared by Builderman's sentry and Tails' drone.

    Both of them want "find the nearest fighter who isn't my owner, and if I can see them,
    shoot". Only the projectile differs, which is why the projectile is passed in.

    Damage is credited to the OWNER, through `ProjectileService`, so a sentry kill counts
    as the builder's kill and goes through the same damage pipeline as everything else.
]=]
function DeployableService.TurretTick(handle, settings: {
    Range: number,
    Interval: number,
    Fire: (handle: any, target: Model, targetRoot: BasePart) -> (),
    RequireLineOfSight: boolean?,
})
    if not RunService:IsServer() or not handle.Alive then
        return
    end

    local Now = os.clock()
    if handle.State.NextShot and Now < handle.State.NextShot then
        return
    end

    local Root = handle.Root
    if not Root or not Root.Parent then
        return
    end

    local OwnerChar = handle.Owner and handle.Owner.Character

    for _, Target: Model in CombatUtils.GetFightersInRadius(Root.Position, settings.Range, OwnerChar) do
        local TargetRoot = Utils.Character.GetRootPart(Target)
        if not TargetRoot then
            continue
        end

        if settings.RequireLineOfSight ~= false then
            if not CombatUtils.HasLineOfSight(Root.Position, TargetRoot.Position, {handle.Model, Target}) then
                continue
            end
        end

        handle.State.NextShot = Now + settings.Interval

        -- Point at what it's shooting, so players can read what it's tracking.
        Root.CFrame = CFrame.lookAt(Root.Position, Vector3.new(TargetRoot.Position.X, Root.Position.Y, TargetRoot.Position.Z))

        settings.Fire(handle, Target, TargetRoot)
        return
    end
end

--------------------------------------------------------------------------------
-- UTILITIES
--------------------------------------------------------------------------------

--[=[
    Damages every deployable in a radius. For abilities that break structures.

    Separate from `GetInRadius` because the common case really is just "break the things
    near here", and making each caller write the loop invites each caller to forget the
    `Alive` check.
]=]
function DeployableService.DamageInRadius(position: Vector3, radius: number, damage: number, byPlayer: Player?): number
    local Count = 0

    for _, Handle in DeployableService.GetInRadius(position, radius, nil) do
        Handle:Damage(damage, byPlayer)
        Count += 1
    end

    return Count
end

return DeployableService
