--[=[
    COMBAT UTILS

    Shared building blocks for killer abilities. Every one of the Free-For-All killers
    leans on these instead of re-implementing the same "find everyone near me" or
    "leave a damaging puddle on the floor" logic ten times over.

    Server-only work is guarded internally, so it's safe to call any of this from an
    ability `Behaviour` that runs on both sides.
]=]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Utils = require(ReplicatedStorage.Modules.Utils)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

local CombatUtils = {}

--------------------------------------------------------------------------------
-- LOOKUPS
--------------------------------------------------------------------------------

--[=[
    Where ability-spawned instances should live.

    `workspace.Map.InGame` is wiped when the map is torn down at the end of a match,
    so anything parented there cleans itself up for free. If there's no map (lobby,
    or a map missing its folders) it falls back to the temp folder.
]=]
function CombatUtils.GetInGameFolder(): Instance
    local Map = workspace:FindFirstChild("Map")
    local InGame = Map and Map:FindFirstChild("InGame")

    return InGame or workspace.TempObjectFolders
end

--[=[
    Every alive fighter character within `radius` studs of `origin`.

    `exclude` is normally the caster's own character. Results come back sorted
    nearest-first so callers can just take `[1]` for "the closest one".
]=]
function CombatUtils.GetFightersInRadius(origin: Vector3, radius: number, exclude: Model?): {Model}
    local Found = {}

    for _, Char: Model in workspace.Players:GetChildren() do
        if Char == exclude then
            continue
        end

        local Role = Char:FindFirstChild("Role")
        if not Role or Role.Value == "Spectator" then
            continue
        end

        if Char:GetAttribute("Dead") == true then
            continue
        end

        local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid or Humanoid.Health <= 0 then
            continue
        end

        local Root = Utils.Character.GetRootPart(Char)
        if not Root then
            continue
        end

        local Distance = (Root.Position - origin).Magnitude
        if Distance <= radius then
            table.insert(Found, {Character = Char, Distance = Distance})
        end
    end

    table.sort(Found, function(a, b)
        return a.Distance < b.Distance
    end)

    -- Flatten back down to plain characters now that the ordering is baked in.
    local Result = {}
    for _, Entry in Found do
        table.insert(Result, Entry.Character)
    end

    return Result
end

--- The single closest alive fighter to `origin`, or `nil`.
function CombatUtils.GetClosestFighter(origin: Vector3, radius: number, exclude: Model?): Model?
    return CombatUtils.GetFightersInRadius(origin, radius, exclude)[1]
end

--[=[
    Is `target` roughly facing `position`?

    Used by anything that should reward or punish looking at the caster. `tolerance`
    is the dot product cutoff — 0 is a 90° cone either side, 0.5 is about 60°.
]=]
function CombatUtils.IsFacing(target: Model, position: Vector3, tolerance: number?): boolean
    local Root = Utils.Character.GetRootPart(target)
    if not Root then
        return false
    end

    local ToTarget = (position - Root.Position)
    if ToTarget.Magnitude <= 0 then
        return true
    end

    return Root.CFrame.LookVector:Dot(ToTarget.Unit) >= (tolerance or 0.35)
end

--- Is there a clear line of sight between two positions?
function CombatUtils.HasLineOfSight(from: Vector3, to: Vector3, ignore: {Instance}?): boolean
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = ignore or {}

    local Cast = workspace:Raycast(from, to - from, Params)

    -- Nothing in the way, or the only thing in the way is see-through.
    return Cast == nil or Cast.Instance.Transparency >= 1
end

--------------------------------------------------------------------------------
-- INSTANCES
--------------------------------------------------------------------------------

--[=[
    A quick anchored, non-colliding, non-querying part.

    Everything ability-spawned in this game is decoration or a trigger volume; none of
    it should ever get in the way of movement or of a hitbox raycast, so those flags
    are baked in rather than left to each caller to remember.
]=]
function CombatUtils.MakePart(props: {[string]: any}?): Part
    local Part = Instance.new("Part")
    Part.Anchored = true
    Part.CanCollide = false
    Part.CanQuery = false
    Part.CanTouch = false
    Part.CastShadow = false
    Part.Size = Vector3.one
    Part.TopSurface = Enum.SurfaceType.Smooth
    Part.BottomSurface = Enum.SurfaceType.Smooth

    if props then
        Utils.Type.DeepTableOverwrite(Part, props)
    end

    return Part
end

export type ZoneSettings = {
    --- Who owns this zone. Used for kill credit.
    SourcePlayer: Player,
    --- Centre of the zone.
    Position: Vector3,
    --- Radius in studs.
    Radius: number,
    --- How long the zone lasts, in seconds.
    Lifetime: number,
    --- Seconds between applications.
    TickRate: number?,
    --- Damage dealt per tick. Optional.
    Damage: number?,
    --- Effects applied to anyone inside on each tick.
    Effects: {{Name: string, Level: number?, Duration: number?, Subfolder: string?}}?,
    --- If `false`, the owner is affected by their own zone too. Defaults to `true`.
    IgnoreOwner: boolean?,
    --- Visuals. A flat translucent disc is drawn by default.
    Color: Color3?,
    Material: Enum.Material?,
    Transparency: number?,
    --- Called once per tick with the list of characters standing in the zone.
    OnTick: ((fighters: {Model}) -> ())?,
}

--[=[
    Drops a persistent area of effect on the floor.

    This is the backbone of Nuker's fallout, Fog's mist and Scrapheap's shrapnel field.
    It ticks on a fixed interval, applies damage and/or effects to everyone standing
    inside, and cleans itself up when its lifetime runs out or the map goes away.

    @return A handle with a `Destroy()` method so the caller can end it early.
]=]
function CombatUtils.CreateZone(settings: ZoneSettings)
    local Handle = {
        Part = nil :: Part?,
        Active = true,
    }

    function Handle:Destroy()
        Handle.Active = false
        if Handle.Part and Handle.Part.Parent then
            Handle.Part:Destroy()
        end
        Handle.Part = nil
    end

    -- Only the server decides who's standing in what.
    if not RunService:IsServer() then
        return Handle
    end

    if settings.IgnoreOwner == nil then
        settings.IgnoreOwner = true
    end

    local TickRate = settings.TickRate or 0.5

    local Visual = CombatUtils.MakePart({
        Name = "AbilityZone",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.6, settings.Radius * 2, settings.Radius * 2),
        -- Cylinders point down their X axis, so it has to be rolled flat.
        CFrame = CFrame.new(settings.Position) * CFrame.Angles(0, 0, math.rad(90)),
        Color = settings.Color or Color3.fromRGB(120, 200, 90),
        Material = settings.Material or Enum.Material.Neon,
        Transparency = settings.Transparency or 0.75,
    })
    Visual.Parent = CombatUtils.GetInGameFolder()
    Handle.Part = Visual

    Debris:AddItem(Visual, settings.Lifetime)

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < settings.Lifetime and Handle.Active do
            Elapsed += task.wait(TickRate)

            -- Map torn down mid-zone (match ended).
            if not Visual.Parent then
                break
            end

            --[[
                Re-read the owner's character every tick rather than capturing it once.
                Zones outlive their caster: die on top of your own fallout, press PLAY,
                and you can be back in the arena while it's still ticking. A captured
                reference would still be excluding the corpse, so the owner's NEW body
                would start taking damage from their own zone.
            ]]
            local OwnerChar = settings.SourcePlayer and settings.SourcePlayer.Character

            local Inside = CombatUtils.GetFightersInRadius(
                settings.Position,
                settings.Radius,
                settings.IgnoreOwner and OwnerChar or nil
            )

            for _, Char: Model in Inside do
                local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
                if not Humanoid then
                    continue
                end

                if settings.Damage and settings.Damage > 0 then
                    CommonFunctions.DamagePlayer({
                        SourcePlayer = settings.SourcePlayer,
                        TargetHumanoid = Humanoid,
                        Damage = settings.Damage,
                        Reason = "Zone",
                    })
                end

                for _, Effect in settings.Effects or {} do
                    CommonFunctions.ApplyEffect({
                        TargetHumanoid = Humanoid,
                        EffectSettings = {
                            Name = Effect.Name,
                            Level = Effect.Level,
                            Duration = Effect.Duration,
                            Subfolder = Effect.Subfolder,
                        },
                        OverwriteExistingEffect = true,
                    })
                end
            end

            if settings.OnTick then
                settings.OnTick(Inside)
            end
        end

        Handle:Destroy()
    end)

    return Handle
end

--[=[
    A one-off expanding sphere, purely so an ability reads on screen.

    Almost every ability on the roster wants "something happened HERE, this big" and
    nothing else. Doing it once here means each character isn't carrying its own copy of
    the same eight lines, and the whole game's hits look like they belong to one game.

    Parented to the map's `InGame` folder and on a Debris timer, so it cleans itself up
    even if whoever cast it dies in the same frame.
]=]
function CombatUtils.Burst(position: Vector3, radius: number, colour: Color3?)
    if not RunService:IsServer() then
        return
    end

    local Ball = CombatUtils.MakePart({
        Name = "AbilityBurst",
        Shape = Enum.PartType.Ball,
        Size = Vector3.one * 3,
        CFrame = CFrame.new(position),
        Color = colour or Color3.fromRGB(255, 255, 255),
        Material = Enum.Material.Neon,
        Transparency = 0.25,
    })
    Ball.Parent = CombatUtils.GetInGameFolder()

    game:GetService("TweenService"):Create(
        Ball,
        TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Size = Vector3.one * math.max(radius, 1) * 2, Transparency = 1}
    ):Play()

    Debris:AddItem(Ball, 0.6)
end

--------------------------------------------------------------------------------
-- MOVEMENT
--------------------------------------------------------------------------------

--[=[
    Shoves a character along their look vector for `duration` seconds.

    Used for every dash and charge on the roster. `LerpTowardsLookVector` lets the dash
    steer with the camera, which feels far better than a locked straight line.

    Kept well under the anti-cheat's 500-stud-per-frame teleport threshold and its
    10-second airborne allowance, so it never trips a false positive.
]=]
function CombatUtils.Dash(char: Model, speed: number, duration: number, steerable: boolean?)
    if not RunService:IsServer() or not char then
        return
    end

    local Velocity, JanitorInstance = CommonFunctions.ApplyVelocity(char, {
        InitialVelocity = speed,
        LerpTowardsLookVector = steerable ~= false,
        LerpDelta = 0.25,
    })

    if not Velocity then
        return
    end

    task.delay(duration, function()
        if JanitorInstance then
            JanitorInstance:Destroy()
        end
        if Velocity and Velocity.Parent then
            Velocity:Destroy()
        end
    end)

    return Velocity
end

--[=[
    Teleports a character to a position, keeping their facing.

    Refuses hops over 400 studs: `AntiTP` kills anyone who moves more than 500 studs in
    a single frame, so a blink that overshoots would execute its own caster.
]=]
function CombatUtils.Blink(char: Model, position: Vector3): boolean
    if not char then
        return false
    end

    local Root = Utils.Character.GetRootPart(char)
    if not Root then
        return false
    end

    if (position - Root.Position).Magnitude > 400 then
        warn("[CombatUtils.Blink()] Refused a blink longer than 400 studs — AntiTP would kill the player. Shorten the ability's range.")
        return false
    end

    char:PivotTo(CFrame.new(position, position + Root.CFrame.LookVector))
    return true
end

--[=[
    Swaps two characters' positions.

    Both get moved in the same frame so neither one ends up standing inside the other.
]=]
function CombatUtils.SwapPositions(a: Model, b: Model): boolean
    local RootA = Utils.Character.GetRootPart(a)
    local RootB = Utils.Character.GetRootPart(b)

    if not RootA or not RootB then
        return false
    end

    local PositionA = RootA.Position
    local PositionB = RootB.Position

    if (PositionA - PositionB).Magnitude > 400 then
        return false
    end

    a:PivotTo(CFrame.new(PositionB, PositionB + RootA.CFrame.LookVector))
    b:PivotTo(CFrame.new(PositionA, PositionA + RootB.CFrame.LookVector))

    return true
end

--------------------------------------------------------------------------------
-- CONVENIENCE
--------------------------------------------------------------------------------

--- Applies an effect to a character without the caller having to dig out the humanoid.
function CombatUtils.ApplyEffectTo(char: Model, name: string, level: number?, duration: number?, subfolder: string?)
    if not RunService:IsServer() or not char then
        return
    end

    local Humanoid = char:FindFirstChildWhichIsA("Humanoid")
    if not Humanoid then
        return
    end

    CommonFunctions.ApplyEffect({
        TargetHumanoid = Humanoid,
        EffectSettings = {
            Name = name,
            Level = level,
            Duration = duration,
            Subfolder = subfolder,
        },
        OverwriteExistingEffect = true,
    })
end

--- Shows `revealed`'s aura to every fighter except `revealed` themselves.
function CombatUtils.RevealToEveryone(revealed: Model, duration: number, color: Color3?)
    if not RunService:IsServer() then
        return
    end

    for _, Char: Model in workspace.Players:GetChildren() do
        if Char == revealed then
            continue
        end

        local Player = Players:GetPlayerFromCharacter(Char)
        if Player then
            Utils.Player.RevealPlayerAuraTo(Player, revealed, duration, color)
        end
    end
end

return CombatUtils
