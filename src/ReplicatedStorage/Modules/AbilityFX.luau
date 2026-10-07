--[=[
    ABILITY FX

    The presentation layer every killer draws from.

    `CombatUtils` answers "who is near me and how do I hurt them". This answers "what did
    that LOOK and SOUND like", and it exists because the roster had thirty-odd characters
    whose abilities were mechanically distinct and visually identical — one expanding white
    sphere each. You could not tell a Gaster Blaster from a Creeper detonation.

    Everything here is PROCEDURAL. No meshes, no uploaded assets, no texture packs: parts,
    tweens, the engine's own built-in particle textures under `rbxasset://`, and sounds the
    project already references. That is deliberate — a killer's look has to survive being
    checked out on a machine that has never opened the Studio place file.

    WHY IT RUNS ON THE SERVER
    ------------------------
    Because the rest of the game does. Hitboxes, zones and bursts are all server-created
    and replicate down, and splitting FX across the network boundary would mean every
    ability needing a client half just to draw itself. The cost of that choice is
    replication traffic, so every helper in here is bounded: small part counts, short
    Debris lifetimes, and particle emitters that fire a fixed number of particles once
    rather than streaming.

    Screen-space work is the exception and genuinely cannot be done here — see
    `AbilityFX.Screen`, which asks the client to do it.
]=]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)

local AbilityFX = {}

--[=[
    Built-in engine particle textures.

    `rbxasset://` paths ship inside the Roblox client itself, so they need no upload, cost
    no asset-permission headaches and cannot fail to load on somebody else's place.
]=]
AbilityFX.Textures = {
    Spark = "rbxasset://textures/particles/sparkles_main.dds",
    Smoke = "rbxasset://textures/particles/smoke_main.dds",
    Fire = "rbxasset://textures/particles/fire_main.dds",
    Explosion = "rbxasset://textures/particles/explosion01_implosion.dds",
}

--- Shorthand so callers don't all have to require `CombatUtils` as well.
function AbilityFX.Folder(): Instance
    return CombatUtils.GetInGameFolder()
end

--- Shorthand for an anchored, non-colliding decoration part.
function AbilityFX.Part(props: {[string]: any}?): Part
    return CombatUtils.MakePart(props)
end

--------------------------------------------------------------------------------
-- SHAPES
--------------------------------------------------------------------------------

--[=[
    An expanding sphere.

    `CombatUtils.Burst` already does this with fixed timing. This one takes the timing and
    the starting size, because a Creeper detonation and a Kirby inhale should not share a
    curve — one snaps out, the other swells.
]=]
function AbilityFX.Burst(position: Vector3, radius: number, colour: Color3?, settings: {
    Duration: number?,
    StartSize: number?,
    Transparency: number?,
    Material: Enum.Material?,
    EasingStyle: Enum.EasingStyle?,
}?)
    if not RunService:IsServer() then
        return
    end

    settings = settings or {}
    local Duration = settings.Duration or 0.45

    local Ball = AbilityFX.Part({
        Name = "AbilityBurst",
        Shape = Enum.PartType.Ball,
        Size = Vector3.one * (settings.StartSize or 3),
        CFrame = CFrame.new(position),
        Color = colour or Color3.fromRGB(255, 255, 255),
        Material = settings.Material or Enum.Material.Neon,
        Transparency = settings.Transparency or 0.25,
    })
    Ball.Parent = AbilityFX.Folder()

    TweenService:Create(
        Ball,
        TweenInfo.new(Duration, settings.EasingStyle or Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Size = Vector3.one * math.max(radius, 1) * 2, Transparency = 1}
    ):Play()

    Debris:AddItem(Ball, Duration + 0.15)

    return Ball
end

--[=[
    A flat ring racing outwards along the floor.

    This is the single most useful shape in the whole file, because it reads as "this area,
    right now" from any camera angle — which a sphere does not. Ground slams, explosions,
    roars and shockwaves all use it.

    Built from a thin cylinder rather than a real torus: a torus needs a mesh, and a disc
    that fades as it grows is indistinguishable from one in motion.
]=]
function AbilityFX.Ring(position: Vector3, radius: number, colour: Color3?, settings: {
    Duration: number?,
    Thickness: number?,
    Transparency: number?,
    StartRadius: number?,
}?)
    if not RunService:IsServer() then
        return
    end

    settings = settings or {}
    local Duration = settings.Duration or 0.5
    local Start = settings.StartRadius or 2
    local Thickness = settings.Thickness or 0.6

    local Disc = AbilityFX.Part({
        Name = "AbilityRing",
        Shape = Enum.PartType.Cylinder,
        -- Cylinders extend along X, so the flat face has to be rolled upright.
        Size = Vector3.new(Thickness, Start * 2, Start * 2),
        CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
        Color = colour or Color3.fromRGB(255, 255, 255),
        Material = Enum.Material.Neon,
        Transparency = settings.Transparency or 0.4,
    })
    Disc.Parent = AbilityFX.Folder()

    TweenService:Create(
        Disc,
        TweenInfo.new(Duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Size = Vector3.new(Thickness, radius * 2, radius * 2), Transparency = 1}
    ):Play()

    Debris:AddItem(Disc, Duration + 0.15)

    return Disc
end

--- A ring plus a burst plus sparks. The "something big happened here" preset.
function AbilityFX.Shockwave(position: Vector3, radius: number, colour: Color3?, sparkCount: number?)
    if not RunService:IsServer() then
        return
    end

    AbilityFX.Burst(position, radius * 0.7, colour, {Duration = 0.35})
    AbilityFX.Ring(position, radius, colour, {Duration = 0.55, Thickness = 1})
    AbilityFX.Sparks(position, colour, sparkCount or 24, 40)
end

--[=[
    A straight beam between two points.

    Sans' Gaster Blaster, Superman's heat vision, Luigi's vacuum cone and Tails' gadget
    shots are all this with different widths, colours and lifetimes.

    `Taper` shrinks the far end, which is what makes a vacuum read as a vacuum and a laser
    read as a laser.
]=]
function AbilityFX.Beam(from: Vector3, to: Vector3, colour: Color3?, settings: {
    Width: number?,
    Duration: number?,
    Transparency: number?,
    Taper: number?,
    Material: Enum.Material?,
}?)
    if not RunService:IsServer() then
        return
    end

    settings = settings or {}

    local Delta = to - from
    local Length = Delta.Magnitude
    if Length <= 0.05 then
        return
    end

    local Width = settings.Width or 1.2
    local Duration = settings.Duration or 0.25

    local Shaft = AbilityFX.Part({
        Name = "AbilityBeam",
        Size = Vector3.new(Width, Width, Length),
        CFrame = CFrame.lookAt(from + Delta * 0.5, to),
        Color = colour or Color3.fromRGB(255, 255, 255),
        Material = settings.Material or Enum.Material.Neon,
        Transparency = settings.Transparency or 0.15,
    })
    Shaft.Parent = AbilityFX.Folder()

    local Goal: {[string]: any} = {Transparency = 1}
    if settings.Taper then
        Goal.Size = Vector3.new(Width * settings.Taper, Width * settings.Taper, Length)
    end

    TweenService:Create(Shaft, TweenInfo.new(Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), Goal):Play()
    Debris:AddItem(Shaft, Duration + 0.15)

    return Shaft
end

--[=[
    A jagged bolt, drawn as a chain of short beams with the joints kicked off-axis.

    Electricity drawn as one straight line looks like a laser. The displacement is what
    separates Pikachu from Superman, and it costs `Segments` parts for a fifth of a
    second — cheap enough to fire several per ability.
]=]
function AbilityFX.Bolt(from: Vector3, to: Vector3, colour: Color3?, settings: {
    Segments: number?,
    Spread: number?,
    Width: number?,
    Duration: number?,
}?)
    if not RunService:IsServer() then
        return
    end

    settings = settings or {}
    local Segments = math.clamp(settings.Segments or 5, 1, 12)
    local Spread = settings.Spread or 2.5
    local Width = settings.Width or 0.5
    local Duration = settings.Duration or 0.18

    local Previous = from

    for Index = 1, Segments do
        local Alpha = Index / Segments
        local Point = from:Lerp(to, Alpha)

        -- The last joint has to land exactly on the target, or the bolt visibly misses.
        if Index < Segments then
            Point += Vector3.new(
                (math.random() - 0.5) * 2 * Spread,
                (math.random() - 0.5) * 2 * Spread,
                (math.random() - 0.5) * 2 * Spread
            )
        end

        AbilityFX.Beam(Previous, Point, colour, {Width = Width, Duration = Duration, Transparency = 0})
        Previous = Point
    end
end

--[=[
    Draws a cone on the floor, as a fan of short beams.

    Used by everything with a cone: Kirby's inhale, Luigi's Strobulb and Poltergust,
    Superman's freeze breath, Fog's claw sweep. The caller still does its own hit detection
    with `AbilityFX.ConeTargets`; this is purely so the player can see where it pointed.
]=]
function AbilityFX.Cone(origin: Vector3, direction: Vector3, range: number, angleDegrees: number, colour: Color3?, settings: {
    Rays: number?,
    Duration: number?,
    Width: number?,
}?)
    if not RunService:IsServer() then
        return
    end

    settings = settings or {}
    local Rays = math.clamp(settings.Rays or 7, 1, 16)
    local Duration = settings.Duration or 0.3
    local Width = settings.Width or 0.5

    if direction.Magnitude <= 0 then
        return
    end
    direction = direction.Unit

    local Half = math.rad(angleDegrees) * 0.5

    for Index = 1, Rays do
        local Alpha = if Rays == 1 then 0.5 else (Index - 1) / (Rays - 1)
        local Angle = -Half + Half * 2 * Alpha
        local Rotated = CFrame.Angles(0, Angle, 0) * direction

        AbilityFX.Beam(origin, origin + Rotated * range, colour, {
            Width = Width,
            Duration = Duration,
            Taper = 2.5,
            Transparency = 0.35,
        })
    end
end

--------------------------------------------------------------------------------
-- TELEGRAPHS
--------------------------------------------------------------------------------

--[=[
    A ground marker that fills up, then goes off.

    This is the single most important balance tool on the roster. Several killers hit very
    hard in an area — Pikachu's Thunder, Superman's heat vision, Baldi's charge, the
    Gaster Blaster — and the design rule is that none of them may do it without warning.
    A telegraph is that warning, and it is deliberately readable from across the arena: a
    static outline showing exactly WHERE the danger is, and a disc filling it to show
    exactly WHEN.

    @return A handle. `:Destroy()` ends it early (the caster died, the cast was cancelled).
]=]
function AbilityFX.Telegraph(position: Vector3, radius: number, colour: Color3?, warnTime: number)
    local Handle = {Active = true, Parts = {}}

    function Handle:Destroy()
        Handle.Active = false
        for _, Part: Instance in Handle.Parts do
            if Part and Part.Parent then
                Part:Destroy()
            end
        end
        table.clear(Handle.Parts)
    end

    if not RunService:IsServer() then
        return Handle
    end

    colour = colour or Color3.fromRGB(255, 120, 60)
    local Folder = AbilityFX.Folder()

    -- The outline: WHERE. Appears instantly at full size and does not move.
    local Outline = AbilityFX.Part({
        Name = "TelegraphOutline",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.25, radius * 2, radius * 2),
        CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
        Color = colour,
        Material = Enum.Material.Neon,
        Transparency = 0.82,
    })
    Outline.Parent = Folder
    table.insert(Handle.Parts, Outline)

    -- The fill: WHEN. Grows from nothing to the outline over the warning window.
    local Fill = AbilityFX.Part({
        Name = "TelegraphFill",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.35, 0.5, 0.5),
        CFrame = CFrame.new(position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        Color = colour,
        Material = Enum.Material.Neon,
        Transparency = 0.5,
    })
    Fill.Parent = Folder
    table.insert(Handle.Parts, Fill)

    TweenService:Create(Fill, TweenInfo.new(warnTime, Enum.EasingStyle.Linear), {
        Size = Vector3.new(0.35, radius * 2, radius * 2),
    }):Play()

    -- Cleared slightly after it fires, so the payoff flash isn't drawn over bare floor.
    Debris:AddItem(Outline, warnTime + 0.3)
    Debris:AddItem(Fill, warnTime + 0.3)

    return Handle
end

--------------------------------------------------------------------------------
-- PARTICLES
--------------------------------------------------------------------------------

--[=[
    A one-shot particle puff at a point in the world.

    `:Emit(n)` then throw the holder away, rather than an emitter left running with
    `Enabled = true` — a streaming emitter that outlives its ability is exactly how a
    round ends up with four hundred live emitters in it.
]=]
function AbilityFX.Emit(position: Vector3, count: number, props: {[string]: any}?): Part?
    if not RunService:IsServer() then
        return
    end

    local Holder = AbilityFX.Part({
        Name = "FXEmitter",
        Size = Vector3.one * 0.2,
        CFrame = CFrame.new(position),
        Transparency = 1,
    })
    Holder.Parent = AbilityFX.Folder()

    local Emitter = Instance.new("ParticleEmitter")
    Emitter.Texture = AbilityFX.Textures.Spark
    Emitter.Rate = 0
    Emitter.Enabled = false
    Emitter.Lifetime = NumberRange.new(0.3, 0.7)
    Emitter.Speed = NumberRange.new(10, 20)
    Emitter.SpreadAngle = Vector2.new(180, 180)
    Emitter.Size = NumberSequence.new(0.8)
    Emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    Emitter.LightEmission = 0.8

    if props then
        Utils.Type.DeepTableOverwrite(Emitter, props)
    end

    Emitter.Parent = Holder
    Emitter:Emit(math.clamp(count, 1, 80))

    -- Long enough for the last particle to finish, short enough to never pile up.
    Debris:AddItem(Holder, 2)

    return Holder
end

--- Sparks. Hits, impacts, electricity, metal on metal.
function AbilityFX.Sparks(position: Vector3, colour: Color3?, count: number?, speed: number?)
    return AbilityFX.Emit(position, count or 18, {
        Texture = AbilityFX.Textures.Spark,
        Color = ColorSequence.new(colour or Color3.fromRGB(255, 240, 180)),
        Speed = NumberRange.new((speed or 25) * 0.5, speed or 25),
        Size = NumberSequence.new(0.7),
        Lifetime = NumberRange.new(0.25, 0.55),
    })
end

--- Smoke. Vents, teleports, machinery, explosions settling.
function AbilityFX.Smoke(position: Vector3, colour: Color3?, count: number?, size: number?)
    return AbilityFX.Emit(position, count or 14, {
        Texture = AbilityFX.Textures.Smoke,
        Color = ColorSequence.new(colour or Color3.fromRGB(90, 90, 90)),
        Speed = NumberRange.new(2, 7),
        Size = NumberSequence.new(size or 4),
        Lifetime = NumberRange.new(0.8, 1.6),
        LightEmission = 0,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.35),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })
end

--- A dense upward column. Fire, flame, a fuse burning, a bucket of lava.
function AbilityFX.Flame(position: Vector3, colour: Color3?, count: number?)
    return AbilityFX.Emit(position, count or 20, {
        Texture = AbilityFX.Textures.Fire,
        Color = ColorSequence.new(colour or Color3.fromRGB(255, 150, 40)),
        Speed = NumberRange.new(4, 11),
        SpreadAngle = Vector2.new(25, 25),
        Size = NumberSequence.new(2.4),
        Lifetime = NumberRange.new(0.4, 0.9),
        Acceleration = Vector3.new(0, 14, 0),
    })
end

--[=[
    Attaches a running emitter to a part for as long as that part lives.

    The one place a streaming emitter is correct: projectiles and charge-up tells need a
    continuous effect, and the part they're attached to has its own short lifetime, so the
    emitter cannot outlive it.
]=]
function AbilityFX.Attach(part: BasePart?, props: {[string]: any}?): ParticleEmitter?
    if not RunService:IsServer() or not part then
        return
    end

    local Emitter = Instance.new("ParticleEmitter")
    Emitter.Texture = AbilityFX.Textures.Spark
    Emitter.Rate = 25
    Emitter.Lifetime = NumberRange.new(0.2, 0.45)
    Emitter.Speed = NumberRange.new(0, 3)
    Emitter.SpreadAngle = Vector2.new(180, 180)
    Emitter.Size = NumberSequence.new(0.8)
    Emitter.LightEmission = 0.7
    Emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })

    if props then
        Utils.Type.DeepTableOverwrite(Emitter, props)
    end

    Emitter.Parent = part
    return Emitter
end

--- A motion trail on a part. Dashes, thrown objects, flying.
function AbilityFX.Trail(part: BasePart?, colour: Color3?, settings: {Lifetime: number?, Width: number?}?): Trail?
    if not RunService:IsServer() or not part then
        return
    end

    settings = settings or {}
    local Width = settings.Width or 1.5

    local Top = Instance.new("Attachment")
    Top.Name = "TrailTop"
    Top.Position = Vector3.new(0, Width * 0.5, 0)
    Top.Parent = part

    local Bottom = Instance.new("Attachment")
    Bottom.Name = "TrailBottom"
    Bottom.Position = Vector3.new(0, -Width * 0.5, 0)
    Bottom.Parent = part

    local TrailInstance = Instance.new("Trail")
    TrailInstance.Attachment0 = Top
    TrailInstance.Attachment1 = Bottom
    TrailInstance.Color = ColorSequence.new(colour or Color3.fromRGB(255, 255, 255))
    TrailInstance.Lifetime = settings.Lifetime or 0.35
    TrailInstance.LightEmission = 0.7
    TrailInstance.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    TrailInstance.Parent = part

    return TrailInstance
end

--------------------------------------------------------------------------------
-- CHARACTERS
--------------------------------------------------------------------------------

--[=[
    Flashes a character a colour for a moment.

    How every on-hit status reads at a glance: corrupted green, frozen blue, electrified
    yellow, enraged red. A `Highlight` rather than tinting the parts, because tinting
    parts means remembering and restoring whatever they were before — and if the ability
    errors in between, the victim is permanently the wrong colour.
]=]
function AbilityFX.Tint(char: Model?, colour: Color3, duration: number?, settings: {
    Outline: Color3?,
    FillTransparency: number?,
}?): Highlight?
    if not RunService:IsServer() or not char then
        return
    end

    settings = settings or {}

    local Glow = Instance.new("Highlight")
    Glow.Name = "AbilityTint"
    Glow.FillColor = colour
    Glow.OutlineColor = settings.Outline or colour
    Glow.FillTransparency = settings.FillTransparency or 0.55
    Glow.OutlineTransparency = 0.2
    Glow.DepthMode = Enum.HighlightDepthMode.Occluded
    Glow.Adornee = char
    Glow.Parent = char

    Debris:AddItem(Glow, duration or 0.6)

    return Glow
end

--[=[
    Floating text above a point.

    Kept for the handful of characters whose whole identity is a noise — Bacon Hair's OOF,
    the Minion's BANANA!, Wario's WAH. It is a readability tool as much as a joke: a short
    word above someone's head tells you which ability just went off even when the visual
    itself is off the side of your screen.
]=]
function AbilityFX.Text(position: Vector3, text: string, colour: Color3?, duration: number?)
    if not RunService:IsServer() then
        return
    end

    duration = duration or 1.1

    local Anchor = AbilityFX.Part({
        Name = "FXText",
        Size = Vector3.one * 0.2,
        CFrame = CFrame.new(position),
        Transparency = 1,
    })
    Anchor.Parent = AbilityFX.Folder()

    local Billboard = Instance.new("BillboardGui")
    Billboard.Size = UDim2.fromScale(8, 2)
    Billboard.AlwaysOnTop = false
    Billboard.MaxDistance = 140
    Billboard.Parent = Anchor

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.fromScale(1, 1)
    Label.BackgroundTransparency = 1
    Label.Font = Enum.Font.LuckiestGuy
    Label.Text = text
    Label.TextColor3 = colour or Color3.fromRGB(255, 255, 255)
    Label.TextStrokeTransparency = 0.2
    Label.TextScaled = true
    Label.Parent = Billboard

    TweenService:Create(Anchor, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        CFrame = CFrame.new(position + Vector3.new(0, 6, 0)),
    }):Play()
    TweenService:Create(Label, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()

    Debris:AddItem(Anchor, duration + 0.2)
end

--------------------------------------------------------------------------------
-- GEOMETRY HELPERS
--------------------------------------------------------------------------------

--[=[
    Everyone inside a cone in front of `origin`.

    Cone abilities were previously written as "radius, then `IsFacing` the target", which
    is a different shape entirely — that asks where the TARGET is looking. This asks where
    the CASTER is pointing, which is what a cone actually is.

    `angleDegrees` is the full width of the cone, not the half-angle.
]=]
function AbilityFX.ConeTargets(origin: Vector3, direction: Vector3, range: number, angleDegrees: number, exclude: Model?): {Model}
    if direction.Magnitude <= 0 then
        return {}
    end

    local Unit = direction.Unit
    local Cosine = math.cos(math.rad(angleDegrees) * 0.5)
    local Found = {}

    for _, Char: Model in CombatUtils.GetFightersInRadius(origin, range, exclude) do
        local Root = Utils.Character.GetRootPart(Char)
        if not Root then
            continue
        end

        local ToTarget = Root.Position - origin
        if ToTarget.Magnitude <= 0.01 then
            table.insert(Found, Char)
            continue
        end

        if Unit:Dot(ToTarget.Unit) >= Cosine then
            table.insert(Found, Char)
        end
    end

    return Found
end

--[=[
    A point on the floor beneath `position`, or `nil` if there's nothing under it.

    Ground markers, traps, blocks and placed walls all need to sit ON something. Dropping
    them at the caster's own Y put them half-buried on a slope and floating in mid-air off
    a ledge.
]=]
function AbilityFX.GroundAt(position: Vector3, ignore: {Instance}?, depth: number?): Vector3?
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = ignore or {}
    Params.IgnoreWater = true

    local Cast = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -(depth or 40), 0), Params)

    return Cast and Cast.Position or nil
end

--------------------------------------------------------------------------------
-- SOUND
--------------------------------------------------------------------------------

--[=[
    A positional one-shot.

    Thin, but it means a killer writes one line instead of five, and it gives every sound
    on the roster the same sane rolloff defaults — which is what stops a Creeper fuse forty
    studs away from being as loud as the one next to you.
]=]
function AbilityFX.Sound(id: (string | {string})?, position: Vector3?, props: {[string]: any}?): Sound?
    if not id then
        return
    end

    local Settings: {[string]: any} = {
        Volume = 0.8,
        RollOffMinDistance = 12,
        RollOffMaxDistance = 90,
    }

    if position then
        Settings.Position = position
    end

    if props then
        for Key, Value in props do
            Settings[Key] = Value
        end
    end

    return Sounds.PlaySound(id, Settings)
end

--- A one-shot parented to a moving part, so it follows whatever made it.
function AbilityFX.SoundOn(part: Instance?, id: (string | {string})?, props: {[string]: any}?): Sound?
    if not id or not part then
        return
    end

    local Settings: {[string]: any} = {
        Parent = part,
        Volume = 0.8,
        RollOffMinDistance = 10,
        RollOffMaxDistance = 85,
    }

    if props then
        for Key, Value in props do
            Settings[Key] = Value
        end
    end

    return Sounds.PlaySound(id, Settings)
end

--------------------------------------------------------------------------------
-- SCREEN SPACE
--------------------------------------------------------------------------------

--[=[
    Asks one client to run a screen effect on itself.

    The only thing in this file that genuinely cannot be done on the server: post-process
    effects and the camera live on the client. The server names a KIND and a strength; the
    client decides what that looks like — see
    `StarterPlayerScripts.RemoteHandler.AbilityScreenFX`.

    Kinds are a fixed vocabulary rather than a payload of properties, precisely so a
    compromised server-side caller cannot ask a client for something arbitrary.
]=]
function AbilityFX.Screen(player: Player?, kind: string, duration: number?, intensity: number?)
    if not RunService:IsServer() or not player then
        return
    end

    Network:FireClientConnection(player, "AbilityScreenFX", "REMOTE_EVENT", kind, duration or 1, intensity or 1)
end

--- The same, for the player who owns a character.
function AbilityFX.ScreenFor(char: Model?, kind: string, duration: number?, intensity: number?)
    if not RunService:IsServer() or not char then
        return
    end

    AbilityFX.Screen(Players:GetPlayerFromCharacter(char), kind, duration, intensity)
end

--- The same, for every fighter within a radius. Roars, outages, reality breaks.
function AbilityFX.ScreenInRadius(position: Vector3, radius: number, kind: string, duration: number?, intensity: number?, exclude: Model?)
    if not RunService:IsServer() then
        return
    end

    for _, Char: Model in CombatUtils.GetFightersInRadius(position, radius, exclude) do
        AbilityFX.ScreenFor(Char, kind, duration, intensity)
    end
end

--[=[
    Shakes one victim's camera from the server.

    The counterpart to `AbilityClient.Shake`, which only ever shakes the CASTER. Being hit
    by something heavy should be felt by the person hit, and before this nothing on the
    roster did that — every impact shook the attacker's screen and nobody else's.
]=]
function AbilityFX.ShakeFor(char: Model?, magnitude: number, duration: number?)
    if not RunService:IsServer() or not char then
        return
    end

    local Player = Players:GetPlayerFromCharacter(char)
    if Player then
        Utils.Player.ShakeCameraOf(Player, magnitude, duration or 0.35)
    end
end

--[=[
    Shakes everyone nearby, scaled by how close they are.

    Explosions and ground slams. The falloff matters: a uniform shake across a 60 stud
    radius tells you something happened but not where, and a shake that fades with distance
    tells you which way to run.
]=]
function AbilityFX.ShakeInRadius(position: Vector3, radius: number, magnitude: number, duration: number?, exclude: Model?)
    if not RunService:IsServer() then
        return
    end

    for _, Char: Model in CombatUtils.GetFightersInRadius(position, radius, exclude) do
        local Root = Utils.Character.GetRootPart(Char)
        if not Root then
            continue
        end

        local Falloff = 1 - math.clamp((Root.Position - position).Magnitude / radius, 0, 1)
        if Falloff > 0.05 then
            AbilityFX.ShakeFor(Char, magnitude * Falloff, duration)
        end
    end
end

return AbilityFX
