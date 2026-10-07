--[=[
    PROJECTILE SERVICE

    One projectile implementation for the whole roster.

    WHY NOT `Classes.Projectile`?
    ----------------------------
    That one is still here and still used by the item system, but it has three properties
    that made it unusable for this pass: it needs a pre-built `Model` to clone, it travels
    in a dead-straight tween, and it cannot report what it hit. Cuphead's peashooter, Steve's
    arrow, Yoshi's egg, Sans' bone, Gubby's bullet and Tails' gadget shot are all projectiles
    and NONE of them are "a prop moving in a straight line for a fixed time".

    This builds its own visual out of a part, integrates position itself, and so can offer
    gravity, homing, bouncing, piercing and impact callbacks. Each projectile picks its own
    speed, size, colour, arc, lifetime and collision behaviour, which is the whole point:
    shared infrastructure must not mean identical abilities.

    DAMAGE GOES THROUGH `Hitbox`
    ----------------------------
    Deliberately. `Hitbox` is where resistance, Fragile, kill credit, the character module's
    `OnHit` hook, execution animations, achievements and the anti-cheat all live. A projectile
    that rolled its own `DamagePlayer` call would silently skip every one of those, and there
    would then be two places in the codebase that decide what a hit means. So a projectile is
    a moving visual plus a `Hitbox` anchored to it — damage stays server-authoritative in
    exactly one place.

    BUDGET
    ------
    All live projectiles share ONE `Heartbeat` connection, which is disconnected the moment
    the last one dies. There is a hard per-player cap. Nothing here can leak a connection or
    an instance: the stepper owns the lifetime, and everything it creates is parented into the
    map's `InGame` folder so the end of a round takes it with it.
]=]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityFX = require(ReplicatedStorage.Modules.AbilityFX)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local Hitbox = require(ReplicatedStorage.Classes.Hitbox)
local Utils = require(ReplicatedStorage.Modules.Utils)

local ProjectileService = {
    --[=[
        How many projectiles one player may have in the air at once.

        Cooldowns should keep everyone well under this; it exists so that a bug in one
        ability's loop, or an exploiter spamming a remote, costs a few dozen parts rather
        than the server's frame budget.
    ]=]
    MaxPerPlayer = 28,

    --- Hard ceiling across everyone, for the same reason.
    MaxTotal = 160,
}

--- Every projectile currently in flight.
local Live: {any} = {}
--- Count per player, so the cap doesn't need a linear scan on every shot.
local CountByPlayer: {[Player]: number} = {}
--- The single shared stepper. Nil whenever nothing is in flight.
local StepConnection: RBXScriptConnection? = nil

--------------------------------------------------------------------------------
-- STEPPER
--------------------------------------------------------------------------------

local function Release(projectile)
    if projectile.Released then
        return
    end
    projectile.Released = true

    local Player = projectile.SourcePlayer
    if Player and CountByPlayer[Player] then
        CountByPlayer[Player] = math.max(CountByPlayer[Player] - 1, 0)
        if CountByPlayer[Player] <= 0 then
            CountByPlayer[Player] = nil
        end
    end
end

--[=[
    Advances one projectile by `delta` seconds.

    Returns `false` when the projectile is finished, which is the stepper's cue to drop it.

    Movement is integrated by hand rather than tweened because a tween cannot be redirected
    mid-flight, and homing, bouncing and gravity all redirect.
]=]
local function Step(projectile, delta: number): boolean
    local Part: BasePart? = projectile.Part

    if not Part or not Part.Parent then
        return false
    end

    projectile.Age += delta

    if projectile.Age >= projectile.Lifetime then
        if projectile.OnExpire then
            projectile.OnExpire(projectile, Part.Position)
        end
        return false
    end

    -- HOMING: bend the velocity toward the target rather than snapping onto it, so a
    -- homing shot can still be dodged by breaking line of sight or out-running the turn.
    local Homing = projectile.Homing
    if Homing and Homing.Target and Homing.Target.Parent then
        local TargetRoot = Utils.Character.GetRootPart(Homing.Target)
        if TargetRoot then
            local Desired = TargetRoot.Position - Part.Position
            if Desired.Magnitude > 0.1 then
                local Speed = projectile.Velocity.Magnitude
                local Blend = math.clamp((Homing.Strength or 2) * delta, 0, 1)
                projectile.Velocity = projectile.Velocity.Unit:Lerp(Desired.Unit, Blend).Unit * Speed
            end
        end
    end

    -- GRAVITY. `0` is a flat shot; anything else arcs.
    if projectile.Gravity ~= 0 then
        projectile.Velocity -= Vector3.new(0, projectile.Gravity * delta, 0)
    end

    local Travel = projectile.Velocity * delta
    local From = Part.Position

    -- WORLD COLLISION, resolved by a ray along this frame's movement rather than by
    -- touching. A fast projectile moves further in one frame than it is wide, so a
    -- touch-based test tunnels straight through walls.
    if projectile.CollideWithWorld and Travel.Magnitude > 0 then
        local Cast = workspace:Raycast(From, Travel, projectile.RayParams)

        if Cast then
            local HitPosition = Cast.Position

            if projectile.BouncesLeft > 0 then
                projectile.BouncesLeft -= 1

                -- Reflect, losing some energy. This is what makes Yoshi's egg an egg
                -- rather than a dart.
                projectile.Velocity = (projectile.Velocity - 2 * projectile.Velocity:Dot(Cast.Normal) * Cast.Normal)
                    * projectile.Restitution

                Part.Position = HitPosition + Cast.Normal * 0.6

                if projectile.OnBounce then
                    projectile.OnBounce(projectile, HitPosition, Cast.Normal, Cast.Instance)
                end

                return true
            end

            Part.Position = HitPosition

            if projectile.OnImpact then
                projectile.OnImpact(projectile, HitPosition, Cast.Normal, Cast.Instance)
            end

            return false
        end
    end

    Part.Position = From + Travel

    -- Keep the visual pointing where it's going, which matters for arrows and bones, and
    -- spin it if it asked to be spun, which matters for eggs and sawblades.
    if projectile.FaceTravel and projectile.Velocity.Magnitude > 0.1 then
        Part.CFrame = CFrame.lookAt(Part.Position, Part.Position + projectile.Velocity.Unit)
    end
    if projectile.Spin ~= 0 then
        Part.CFrame *= CFrame.Angles(math.rad(projectile.Spin * delta), math.rad(projectile.Spin * delta * 0.6), 0)
    end

    if projectile.OnStep then
        projectile.OnStep(projectile, delta, Part.Position)
    end

    return true
end

--- Starts the shared stepper if it isn't already running.
local function EnsureStepper()
    if StepConnection then
        return
    end

    StepConnection = RunService.Heartbeat:Connect(function(delta: number)
        -- Backwards, so removing finished entries can't skip the one after them.
        for Index = #Live, 1, -1 do
            local Projectile = Live[Index]

            local Continuing = false
            local Ok, Err = pcall(function()
                Continuing = Step(Projectile, delta)
            end)

            --[[
                One projectile throwing must not stop every other projectile in the
                server. A thrown error here would break out of this loop, leaving every
                later entry un-stepped and frozen in mid-air forever.
            ]]
            if not Ok then
                warn("[ProjectileService] A projectile errored while stepping and was removed: "..tostring(Err))
                Continuing = false
            end

            if not Continuing then
                table.remove(Live, Index)
                Release(Projectile)
                Projectile:Destroy()
            end
        end

        if #Live <= 0 and StepConnection then
            StepConnection:Disconnect()
            StepConnection = nil
        end
    end)
end

--------------------------------------------------------------------------------
-- VISUALS
--------------------------------------------------------------------------------

--- Builds the part a projectile is seen as.
local function BuildVisual(settings): BasePart
    local Visual = settings.Visual or {}

    local Part = CombatUtils.MakePart({
        Name = settings.Name or "Projectile",
        Shape = Visual.Shape or Enum.PartType.Ball,
        Size = Visual.Size or Vector3.one * 1.6,
        Color = Visual.Color or Color3.fromRGB(255, 255, 255),
        Material = Visual.Material or Enum.Material.Neon,
        Transparency = Visual.Transparency or 0,
    })

    -- Anchored, so the hand-rolled integrator owns the position outright and physics can't
    -- argue with it.
    Part.Anchored = true

    if Visual.Light then
        local Light = Instance.new("PointLight")
        Light.Color = Visual.Color or Color3.fromRGB(255, 255, 255)
        Light.Range = Visual.LightRange or 10
        Light.Brightness = 2
        Light.Parent = Part
    end

    return Part
end

--------------------------------------------------------------------------------
-- FIRING
--------------------------------------------------------------------------------

export type ProjectileSettings = {
    --- Who gets kill credit. Required.
    SourcePlayer: Player,
    --- Where it starts.
    Origin: Vector3,
    --- Which way it goes. Normalised internally; magnitude is ignored.
    Direction: Vector3,

    --- Studs per second.
    Speed: number?,
    --- Studs per second squared, pulling down. `0` is a flat shot.
    Gravity: number?,
    --- Seconds before it gives up.
    Lifetime: number?,
    --- Hit radius in studs. Independent of the visual's size.
    Radius: number?,

    --- Damage per fighter hit.
    Damage: number?,
    --- Shows in the kill feed.
    Reason: string?,
    --- Statuses applied on hit, in `Types.HitboxSettings.EffectsToApply` format.
    Effects: {{Name: string, Level: number?, Duration: number?, Subfolder: string?, OverwriteExisting: boolean?}}?,
    --- Knockback force on hit.
    Knockback: number?,
    --- How many fighters it can hit before stopping. Defaults to 1.
    Pierce: number?,
    --- Whether killing with it plays an execution. Off by default: being sniped from
    --- across the arena shouldn't lock both players into a cutscene.
    ExecuteOnKill: boolean?,

    --- Wall bounces allowed before it stops. Defaults to 0.
    Bounces: number?,
    --- Fraction of speed kept per bounce. Defaults to 0.6.
    Restitution: number?,
    --- Whether walls stop it at all. Defaults to `true`.
    CollideWithWorld: boolean?,

    --- Curve toward a character. `Strength` is how fast it turns, in radians-ish per second.
    Homing: {Target: Model?, Strength: number?}?,

    --- Appearance.
    Visual: {
        Shape: Enum.PartType?,
        Size: Vector3?,
        Color: Color3?,
        Material: Enum.Material?,
        Transparency: number?,
        Trail: boolean?,
        TrailColor: Color3?,
        Emitter: {[string]: any}?,
        Light: boolean?,
        LightRange: number?,
    }?,
    --- Point the visual along its travel. Good for arrows and bones, wrong for spheres.
    FaceTravel: boolean?,
    --- Degrees per second of tumble, for eggs and thrown junk.
    Spin: number?,

    --- Name for the instance in the world, for debugging.
    Name: string?,

    --- Fired for every fighter hit. Return `"Stop"` to end the projectile immediately.
    OnHit: ((projectile: any, humanoid: Humanoid, first: boolean) -> string?)?,
    --- Fired when it hits the world and will not bounce again.
    OnImpact: ((projectile: any, position: Vector3, normal: Vector3, instance: Instance?) -> ())?,
    --- Fired on each bounce.
    OnBounce: ((projectile: any, position: Vector3, normal: Vector3, instance: Instance?) -> ())?,
    --- Fired every frame while in flight.
    OnStep: ((projectile: any, delta: number, position: Vector3) -> ())?,
    --- Fired when it times out without hitting anything.
    OnExpire: ((projectile: any, position: Vector3) -> ())?,
    --- Fired exactly once, however it ends. The place to put cleanup.
    OnEnd: ((projectile: any, position: Vector3) -> ())?,
}

--[=[
    Puts one projectile in the air.

    @return A handle, or `nil` if the shot was refused (no player, no direction, over the
            budget). Callers can ignore the return; nothing has to be cleaned up by hand.
]=]
function ProjectileService.Fire(settings: ProjectileSettings)
    if not RunService:IsServer() then
        return nil
    end

    local Player = settings.SourcePlayer
    if not Player then
        warn("[ProjectileService.Fire()] No `SourcePlayer`, so nothing could be given kill credit. Shot refused.")
        return nil
    end

    local Char = Player.Character
    if not Char then
        return nil
    end

    if settings.Direction.Magnitude <= 0 then
        warn("[ProjectileService.Fire()] `Direction` has no magnitude, so there is no way to know where to send it. Shot refused.")
        return nil
    end

    -- BUDGET. Refuse rather than evict: silently deleting somebody's older shot to make
    -- room for a newer one is a much stranger bug to chase than a shot that didn't fire.
    if #Live >= ProjectileService.MaxTotal then
        return nil
    end
    if (CountByPlayer[Player] or 0) >= ProjectileService.MaxPerPlayer then
        return nil
    end

    local Speed = settings.Speed or 90
    local Lifetime = settings.Lifetime or 4
    local Radius = settings.Radius or 2.2
    local Pierce = math.max(settings.Pierce or 1, 1)

    local Part = BuildVisual(settings)
    Part.CFrame = CFrame.lookAt(settings.Origin, settings.Origin + settings.Direction.Unit)
    Part.Parent = AbilityFX.Folder()

    local Visual = settings.Visual or {}
    if Visual.Trail then
        AbilityFX.Trail(Part, Visual.TrailColor or Visual.Color, {Lifetime = 0.3, Width = Radius})
    end
    if Visual.Emitter then
        AbilityFX.Attach(Part, Visual.Emitter)
    end

    -- Walls stop it; the shooter and other projectiles do not. Characters are handled by
    -- the hitbox, not by this ray, so they are excluded here too — otherwise a projectile
    -- would stop dead on a target it is not yet allowed to damage.
    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    RayParams.FilterDescendantsInstances = {Char, workspace.Players, AbilityFX.Folder(), workspace.TempObjectFolders}
    RayParams.IgnoreWater = true
    RayParams.RespectCanCollide = true

    local Projectile
    Projectile = {
        Part = Part,
        SourcePlayer = Player,
        Velocity = settings.Direction.Unit * Speed,
        Gravity = settings.Gravity or 0,
        Lifetime = Lifetime,
        Age = 0,
        BouncesLeft = settings.Bounces or 0,
        Restitution = settings.Restitution or 0.6,
        CollideWithWorld = settings.CollideWithWorld ~= false,
        Homing = settings.Homing,
        FaceTravel = settings.FaceTravel == true,
        Spin = settings.Spin or 0,
        RayParams = RayParams,
        HitsLeft = Pierce,
        Released = false,
        Finished = false,

        OnImpact = settings.OnImpact,
        OnBounce = settings.OnBounce,
        OnStep = settings.OnStep,
        OnExpire = settings.OnExpire,
    }

    --[=[
        The damage half: a `Hitbox` whose CFrame function reads the projectile's part every
        tick, so it follows the visual exactly.

        `Time` is the full lifetime — the hitbox is cancelled explicitly when the projectile
        ends, rather than being left to time out on its own.
    ]=]
    Projectile.Hitbox = Hitbox.New(Player, {
        CFrame = function(): CFrame
            return (Part and Part.Parent and Part.CFrame) or CFrame.new(0, -5000, 0)
        end,
        Shape = Enum.PartType.Ball,
        Size = Vector3.one * Radius * 2,
        Time = Lifetime,
        Damage = settings.Damage or 0,
        Reason = settings.Reason or (settings.Name or "Projectile"),
        Knockback = settings.Knockback or 0,
        EffectsToApply = settings.Effects,
        -- Piercing shots have to be allowed to hit more than one body, and the hitbox's
        -- own `HumanoidsHit` list stops the same victim being hit twice by one shot.
        HitMultiple = Pierce > 1,
        IsProjectile = true,
        PredictVelocity = false,
        ExecuteOnKill = settings.ExecuteOnKill == true,
        -- Projectiles are not melee: a wall between the shot and the target is already
        -- handled by the travel ray, and the melee wall check would reject legitimate
        -- hits taken while standing next to cover.
        IgnoreWalls = true,
        Connections = {
            Hit = function(_config, humanoid: Humanoid, first: boolean)
                Projectile.HitsLeft -= 1

                local Result = settings.OnHit and settings.OnHit(Projectile, humanoid, first) or nil

                if Result == "Stop" or Projectile.HitsLeft <= 0 then
                    Projectile:Finish()
                end
            end,
        },
    })

    --[=[
        Ends the projectile.

        Split out from `Destroy` so a hit can request the end from inside the hitbox
        callback without tearing instances down underneath the stepper mid-frame. This sets
        `Age` past the lifetime; the stepper notices next frame and does the real cleanup.
    ]=]
    function Projectile:Finish()
        Projectile.Age = Projectile.Lifetime + 1
    end

    function Projectile:Destroy()
        if Projectile.Finished then
            return
        end
        Projectile.Finished = true

        local Position = (Part and Part.Parent and Part.Position) or settings.Origin

        if settings.OnEnd then
            -- Cleanup must never be skipped because the cleanup itself threw.
            local Ok, Err = pcall(settings.OnEnd, Projectile, Position)
            if not Ok then
                warn("[ProjectileService] A projectile's `OnEnd` errored: "..tostring(Err))
            end
        end

        if Projectile.Hitbox then
            Projectile.Hitbox:Cancel()
        end

        if Part and Part.Parent then
            -- A short delay rather than an instant destroy, so trails and attached
            -- emitters get to finish instead of vanishing with the part.
            Part.Transparency = 1
            Debris:AddItem(Part, 0.4)
        end

        Projectile.Part = nil
    end

    CountByPlayer[Player] = (CountByPlayer[Player] or 0) + 1
    table.insert(Live, Projectile)
    EnsureStepper()

    return Projectile
end

--[=[
    Fires several projectiles at once with angular scatter.

    Shotguns, Cuphead's spread shot, the Mini-Gunner's accuracy falling off as the barrel
    heats. `spreadDegrees` is the full cone the shots are jittered inside.
]=]
function ProjectileService.Spray(settings: ProjectileSettings, count: number, spreadDegrees: number)
    if not RunService:IsServer() then
        return {}
    end

    local Fired = {}
    local Base = settings.Direction.Unit
    local Half = math.rad(spreadDegrees) * 0.5

    for _ = 1, math.clamp(count, 1, 16) do
        local Yaw = (math.random() - 0.5) * 2 * Half
        local Pitch = (math.random() - 0.5) * 2 * Half * 0.5

        -- A shallow copy per shot: they share settings but must not share a direction
        -- vector, and `Fire` reads `Direction` after the loop has moved on.
        local Shot = table.clone(settings) :: ProjectileSettings
        Shot.Direction = (CFrame.Angles(Pitch, Yaw, 0) * Base).Unit

        local Projectile = ProjectileService.Fire(Shot)
        if Projectile then
            table.insert(Fired, Projectile)
        end
    end

    return Fired
end

--[=[
    Lobs a projectile so it lands on a point.

    Solves for the launch velocity that reaches `target` in `flightTime` seconds under
    `gravity`, which is the only sane way to aim an arc — picking an angle and hoping is
    how you get grenades that sail over everyone's heads.

    Used by Yoshi's eggs, Minion's bananas, Creeper's TNT and Steve's arrows at range.
]=]
function ProjectileService.Lob(settings: ProjectileSettings, target: Vector3, flightTime: number?)
    if not RunService:IsServer() then
        return nil
    end

    local Gravity = settings.Gravity or 110
    local Origin = settings.Origin
    local Delta = target - Origin

    -- Fast enough that a slow lob can't be strolled out of, slow enough to read as an arc.
    local Time = flightTime or math.clamp(Delta.Magnitude / 55, 0.35, 1.8)

    -- Standard projectile solve: constant velocity to cover the gap, plus the half-g t²
    -- that gravity will steal back on the way.
    local Velocity = Delta / Time + Vector3.new(0, 0.5 * Gravity * Time, 0)

    local Shot = table.clone(settings) :: ProjectileSettings
    Shot.Gravity = Gravity
    Shot.Direction = Velocity.Unit
    Shot.Speed = Velocity.Magnitude
    -- A touch of slack so it isn't deleted a frame before it lands.
    Shot.Lifetime = settings.Lifetime or (Time + 0.6)

    return ProjectileService.Fire(Shot)
end

--- How many projectiles are in the air right now. For diagnostics.
function ProjectileService.ActiveCount(): number
    return #Live
end

--[=[
    Projectiles in the air within `radius` of a point, nearest first.

    For abilities that interact with other people's shots rather than making their own:
    Kirby's inhale eats them, Luigi's Poltergust sucks them up, Cuphead's parry reads them.
    `exclude` is normally the caller's own player, so nothing is rewarded for eating its own
    bullets.
]=]
function ProjectileService.GetInRadius(position: Vector3, radius: number, exclude: Player?): {any}
    local Found = {}

    for _, Projectile in Live do
        if Projectile.Finished or not Projectile.Part or not Projectile.Part.Parent then
            continue
        end
        if exclude and Projectile.SourcePlayer == exclude then
            continue
        end

        local Distance = (Projectile.Part.Position - position).Magnitude
        if Distance <= radius then
            table.insert(Found, {Projectile = Projectile, Distance = Distance})
        end
    end

    table.sort(Found, function(a, b)
        return a.Distance < b.Distance
    end)

    local Result = {}
    for _, Entry in Found do
        table.insert(Result, Entry.Projectile)
    end
    return Result
end

--[=[
    Destroys projectiles in a radius, as if they had been swallowed.

    @return How many were removed, so a caller can tell whether it caught anything.

    `Finish` rather than `Destroy`: the stepper owns the real teardown, and tearing an entry
    down from outside it mid-frame would leave the loop holding a dead handle.
]=]
function ProjectileService.Consume(position: Vector3, radius: number, exclude: Player?): number
    local Count = 0

    for _, Projectile in ProjectileService.GetInRadius(position, radius, exclude) do
        Projectile:Finish()
        Count += 1
    end

    return Count
end

--[=[
    Drops everything in flight.

    Called at the end of a round. Projectiles are parented into the map, so the map coming
    down already removes the visuals — but the stepper is holding references to them, and
    their hitboxes are still ticking against a world that has moved on.
]=]
function ProjectileService.ClearAll()
    for Index = #Live, 1, -1 do
        local Projectile = Live[Index]
        table.remove(Live, Index)
        Release(Projectile)
        Projectile:Destroy()
    end

    table.clear(CountByPlayer)

    if StepConnection then
        StepConnection:Disconnect()
        StepConnection = nil
    end
end

return ProjectileService
