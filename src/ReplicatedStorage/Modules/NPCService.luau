--[=[
    NPC SERVICE — NPCs WITHOUT A HUMANOID

    Every NPC in this project used to be a `Humanoid` rig: the placeholder noob bodies, the
    summoned minions, the Events Panel's cinematic dummy. A `Humanoid` is the obvious way to
    build one and it is the wrong way, because it drags in four engine systems an NPC that
    only ever has to STAND THERE AND LOOK RIGHT does not want:

      1. THE PHYSICS ASSEMBLY. A `Humanoid` rig is held together by `Motor6D` joints over
         unanchored parts. Anchor the root and leave the limbs loose and the limbs sag, or
         detach, or fall through the floor and keep going. That is the "assets dropping"
         failure: parts of an NPC arriving on the ground separately from the NPC.
      2. THE STATE MACHINE. `Humanoid` decides every frame whether it is Running, Freefall,
         FallingDown, Ragdoll or Dead, and acts on that decision. An NPC standing on a
         platform that gets deleted mid-animation becomes Freefall and leaves.
      3. `Humanoid:LoadAnimation`. Needs a real, public, correctly-typed animation asset.
         A moderated or mistyped id fails silently and the NPC T-poses forever.
      4. `Humanoid.Health`. Something somewhere always decides a model with a `Humanoid` is
         a character: `GetPlayerFromCharacter`, camera subjects, a kill feed, a hitbox.

    An NPC built here has NONE of that. It is a model of ANCHORED parts, posed by writing
    `CFrame` directly, animated by a function of time, with health in an attribute. It
    cannot fall, cannot ragdoll, cannot T-pose, cannot be mistaken for a player's body, and
    cannot leave anything behind: `Destroy` is idempotent and there is exactly one path to
    it.

    WHAT YOU GIVE UP, HONESTLY
    --------------------------
    Roblox animation assets. There is no `Animator`, so a `.rbxm` animation cannot drive one
    of these. Poses come from `Poses` below and motion comes from `Animate` callbacks, which
    is strictly less expressive than a hand-authored animation and strictly more reliable.

    PLAYER CHARACTERS STILL NEED A HUMANOID. Roblox requires `Player.Character` to contain
    one; that is not negotiable from here, so `PlaceholderRig` keeps its `Humanoid` for the
    bodies that real players wear. This module is for everything that is NOT a player.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local NPCService = {
    --- Hard ceiling across the whole server. Nothing may spawn past this.
    MaxTotal = 60,

    --- How often `Animate` and `OnTick` run, in seconds. Deliberately not per-frame.
    TickRate = 1 / 20,
}

--------------------------------------------------------------------------------
-- THE BODY
--------------------------------------------------------------------------------

--[=[
    R6 proportions, as offsets from the root rather than as joints.

    A joint-free rig has to know where each part SITS, because nothing is going to work it
    out from a skeleton. These offsets reproduce a standing R6 character exactly, measured
    from the centre of the root part.
]=]
local LIMBS = {
    {Name = "Torso", Size = Vector3.new(2, 2, 1), Offset = Vector3.new(0, 0, 0)},
    {Name = "Head", Size = Vector3.new(2, 1, 1), Offset = Vector3.new(0, 1.5, 0)},
    {Name = "Left Arm", Size = Vector3.new(1, 2, 1), Offset = Vector3.new(-1.5, 0, 0)},
    {Name = "Right Arm", Size = Vector3.new(1, 2, 1), Offset = Vector3.new(1.5, 0, 0)},
    {Name = "Left Leg", Size = Vector3.new(1, 2, 1), Offset = Vector3.new(-0.5, -2, 0)},
    {Name = "Right Leg", Size = Vector3.new(1, 2, 1), Offset = Vector3.new(0.5, -2, 0)},
}

--- Which limbs an `Animate` callback is allowed to move, and in what order.
local MOVABLE = {"Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

--[=[
    Named static poses, as per-limb rotations in degrees.

    `Animate` is for motion; this is for an NPC that needs to look like something other than
    a mannequin and then hold still. Both can be used together — the pose is the base and
    `Animate` adds to it.
]=]
local Poses = {
    --- Arms down, legs together. The default.
    Stand = {},

    --- Arms straight out front. What a broken `LoadAnimation` leaves you with, except on
    --- purpose and therefore not a bug.
    TPose = {
        ["Left Arm"] = Vector3.new(0, 0, 90),
        ["Right Arm"] = Vector3.new(0, 0, -90),
    },

    --- Both arms raised. For the cinematic dummy.
    Raised = {
        ["Left Arm"] = Vector3.new(0, 0, 155),
        ["Right Arm"] = Vector3.new(0, 0, -155),
    },

    --- One arm forward, as though reaching.
    Reach = {
        ["Right Arm"] = Vector3.new(-80, 0, 0),
        ["Left Arm"] = Vector3.new(-12, 0, 0),
    },

    --- Arms out, head down. A looming idle.
    Loom = {
        Head = Vector3.new(16, 0, 0),
        ["Left Arm"] = Vector3.new(-62, 0, 18),
        ["Right Arm"] = Vector3.new(-62, 0, -18),
    },
}

NPCService.Poses = Poses

--------------------------------------------------------------------------------
-- REGISTRY AND THE SINGLE TICKER
--------------------------------------------------------------------------------

--- Everything alive, newest last.
local Live: {any} = {}

--- Per-owner counts, for `Limit`. Keyed by player, or by the string "Server".
local Counts: {[any]: number} = {}

--[=[
    One `Heartbeat` for every NPC in the game, connected on the first spawn and
    DISCONNECTED when the last one dies.

    Each NPC owning its own connection was how the old rigs leaked: a connection that
    outlives the thing it was animating holds a reference to it, which keeps the model
    alive, which keeps the connection relevant. One shared stepper that stops when `Live`
    empties cannot do that.
]=]
local Stepper: RBXScriptConnection? = nil
local Accumulator = 0

local function OwnerKey(owner: Player?): any
    return owner or "Server"
end

--- Forward declaration: `Step` needs to call it, `Spawn` defines it per handle.
local StopStepper

local function Step(dt: number)
    Accumulator += dt
    if Accumulator < NPCService.TickRate then
        return
    end

    local Elapsed = Accumulator
    Accumulator = 0

    -- Backwards, so removing the current entry mid-loop is safe.
    for Index = #Live, 1, -1 do
        local Handle = Live[Index]

        if not Handle.Alive or not Handle.Model.Parent then
            Handle:Destroy()
            continue
        end

        if Handle.Lifetime and os.clock() - Handle.SpawnedAt >= Handle.Lifetime then
            Handle:Destroy()
            continue
        end

        Handle.Age += Elapsed

        --[[
            Every callback is in its own `pcall`.

            An `Animate` that errors must not stop the other NPCs from being animated, and
            must not kill the shared stepper — which, before this was one shared loop, is
            exactly what used to happen: one bad NPC froze every NPC.
        ]]
        if Handle.Animate then
            local Ok, Err = pcall(Handle.Animate, Handle, Handle.Age, Elapsed)
            if not Ok then
                warn("[NPCService] An NPC's `Animate` errored and has been removed: "..tostring(Err))
                Handle.Animate = nil
            end
        end

        if Handle.OnTick then
            local Ok, Err = pcall(Handle.OnTick, Handle, Elapsed)
            if not Ok then
                warn("[NPCService] An NPC's `OnTick` errored and has been removed: "..tostring(Err))
                Handle.OnTick = nil
            end
        end
    end

    if #Live <= 0 then
        StopStepper()
    end
end

local function StartStepper()
    if Stepper then
        return
    end
    Accumulator = 0
    Stepper = RunService.Heartbeat:Connect(Step)
end

function StopStepper()
    if not Stepper then
        return
    end
    Stepper:Disconnect()
    Stepper = nil
end

--------------------------------------------------------------------------------
-- BUILDING
--------------------------------------------------------------------------------

local function MakePart(name: string, size: Vector3, colour: Color3, material: Enum.Material, transparency: number): Part
    local Part = Instance.new("Part")
    Part.Name = name
    Part.Size = size
    Part.Color = colour
    Part.Material = material
    Part.Transparency = transparency

    --[=[
        THE THREE PROPERTIES THAT MAKE THIS NOT FALL OVER.

        `Anchored` so no physics touches it — this is the whole fix for parts of an NPC
        dropping through the floor and arriving separately from the NPC.

        `CanCollide` off so the NPC never pushes a player through a wall, never blocks a
        doorway it was only ever meant to decorate, and never gets shoved itself. A
        deployable that is SUPPOSED to be solid belongs in `DeployableService`.

        `Massless` because an anchored part has no business contributing mass to anything
        that might weld to it later.
    ]=]
    Part.Anchored = true
    Part.CanCollide = false
    Part.CanTouch = false
    Part.CanQuery = false
    Part.Massless = true

    Part.TopSurface = Enum.SurfaceType.Smooth
    Part.BottomSurface = Enum.SurfaceType.Smooth

    return Part
end

export type NPCSettings = {
    --- Where it stands. The root's centre, so the feet are about 3 studs below this.
    CFrame: CFrame,

    --- Instance name. Defaults to "NPC".
    Name: string?,
    --- Who it belongs to, for `Limit` and for `ClearFor`. Omit for a server-owned prop.
    Owner: Player?,
    --- Category, for `ClearKind`.
    Kind: string?,

    --- Body colour. A single colour, or a per-limb table keyed by limb name.
    Color: (Color3 | {[string]: Color3})?,
    Material: Enum.Material?,
    Transparency: number?,
    --- Uniform scale. `1` is a normal R6 character.
    Scale: number?,

    --- A key from `NPCService.Poses`, or a table in the same shape.
    Pose: (string | {[string]: Vector3})?,

    --- Floats above its head. Omit for no tag.
    Label: string?,
    LabelColor: Color3?,
    --- Second line, smaller and dimmer.
    SubLabel: string?,

    --- An outline, so it reads as a thing rather than as scenery.
    OutlineColor: Color3?,
    --- A light at the torso.
    GlowColor: Color3?,

    --- Seconds before it removes itself. Omit for "until something destroys it".
    Lifetime: number?,
    --- How many this owner may have of this `Kind`. Oldest goes to make room.
    Limit: number?,

    --- Where to parent it. Defaults to the in-game folder, so a map teardown takes it.
    Parent: Instance?,

    --[=[
        Called every tick with `(handle, age, delta)`. Pose the body here.

        `handle:SetLimb(name, rotationDegrees, offsetStuds)` is the one call you need. Use
        `age` rather than counting your own frames — it is wall-clock seconds since spawn
        and it survives a tick that ran late.
    ]=]
    Animate: ((handle: any, age: number, delta: number) -> ())?,

    --- Called every tick for behaviour that is not posing.
    OnTick: ((handle: any, delta: number) -> ())?,

    --- Called once, however it ends.
    OnEnd: ((handle: any) -> ())?,

    --- Health pool, held in an attribute. Omit for something that cannot be damaged.
    Health: number?,
    --- Called when `Damage` takes it to zero.
    OnDestroyed: ((handle: any) -> ())?,

    --- Fade in over this many seconds rather than appearing instantly.
    FadeIn: number?,
}

--[=[
    Spawns one NPC.

    @return A handle, or `nil` if it was refused. The handle carries `Model`, `Root`,
            `Parts`, `SetLimb`, `MoveTo`, `Damage` and `Destroy`.
]=]
function NPCService.Spawn(settings: NPCSettings)
    if #Live >= NPCService.MaxTotal then
        warn("[NPCService.Spawn()] Refused: already at MaxTotal ("..NPCService.MaxTotal..").")
        return nil
    end

    if typeof(settings.CFrame) ~= "CFrame" then
        warn("[NPCService.Spawn()] Refused: `CFrame` is required and must be a CFrame.")
        return nil
    end

    local Key = OwnerKey(settings.Owner)
    local Kind = settings.Kind or "NPC"
    local Scale = math.clamp(settings.Scale or 1, 0.1, 12)

    ----------------------------------------------------------------------------
    -- THE CAP
    ----------------------------------------------------------------------------

    if settings.Limit then
        local Matching = {}
        for _, Handle in Live do
            if OwnerKey(Handle.Owner) == Key and Handle.Kind == Kind then
                table.insert(Matching, Handle)
            end
        end

        -- Oldest first, same as `DeployableService`: "my newest one silently didn't
        -- appear" is more confusing than "my oldest one went away", which is visible.
        while #Matching >= settings.Limit do
            local Oldest = table.remove(Matching, 1)
            if not Oldest then
                break
            end
            Oldest:Destroy()
        end
    end

    ----------------------------------------------------------------------------
    -- THE MODEL
    ----------------------------------------------------------------------------

    local Model = Instance.new("Model")
    Model.Name = settings.Name or "NPC"

    local Material = settings.Material or Enum.Material.SmoothPlastic
    local BaseTransparency = settings.Transparency or 0
    local StartTransparency = settings.FadeIn and 1 or BaseTransparency

    --- Per-limb or single colour.
    local function ColourFor(name: string): Color3
        if typeof(settings.Color) == "Color3" then
            return settings.Color :: Color3
        end
        if type(settings.Color) == "table" then
            return (settings.Color :: any)[name] or Color3.fromRGB(190, 190, 195)
        end
        return Color3.fromRGB(190, 190, 195)
    end

    --[=[
        The root.

        Named `NPCRoot`, NOT `HumanoidRootPart`. That name is load-bearing elsewhere in this
        project — `Utils.Character.GetRootPart` looks for it, `Hitbox` reads
        `HitboxPriority` off it, `DeployableService` uses it on purpose to be hittable —
        and an NPC that answers to it would start being treated as somebody's body by code
        that has no idea this module exists. Keeping the name distinct is what guarantees
        that cannot happen.
    ]=]
    local Root = MakePart("NPCRoot", Vector3.new(2, 2, 1) * Scale, ColourFor("Torso"), Material, 1)
    Root.CFrame = settings.CFrame
    Root.Parent = Model
    Model.PrimaryPart = Root

    local Parts: {[string]: BasePart} = {}
    local Offsets: {[string]: Vector3} = {}

    for _, Limb in LIMBS do
        local Part = MakePart(Limb.Name, Limb.Size * Scale, ColourFor(Limb.Name), Material, StartTransparency)
        Part.CFrame = settings.CFrame * CFrame.new(Limb.Offset * Scale)
        Part.Parent = Model

        Parts[Limb.Name] = Part
        Offsets[Limb.Name] = Limb.Offset * Scale
    end

    -- The classic head, since the proportions are R6's anyway.
    local HeadMesh = Instance.new("SpecialMesh")
    HeadMesh.MeshType = Enum.MeshType.Head
    HeadMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
    HeadMesh.Parent = Parts.Head

    local Face = Instance.new("Decal")
    Face.Name = "face"
    Face.Texture = "rbxasset://textures/face.png"
    Face.Face = Enum.NormalId.Front
    Face.Transparency = StartTransparency
    Face.Parent = Parts.Head

    ----------------------------------------------------------------------------
    -- TRIMMINGS
    ----------------------------------------------------------------------------

    if settings.OutlineColor then
        local Outline = Instance.new("Highlight")
        Outline.FillTransparency = 1
        Outline.OutlineColor = settings.OutlineColor
        Outline.OutlineTransparency = 0.3
        Outline.DepthMode = Enum.HighlightDepthMode.Occluded
        Outline.Adornee = Model
        Outline.Parent = Model
    end

    if settings.GlowColor then
        local Light = Instance.new("PointLight")
        Light.Color = settings.GlowColor
        Light.Brightness = 2
        Light.Range = 18 * Scale
        Light.Parent = Parts.Torso
    end

    if settings.Label then
        local Billboard = Instance.new("BillboardGui")
        Billboard.Name = "NPCLabel"
        Billboard.Size = UDim2.new(0, 200, 0, settings.SubLabel and 44 or 26)
        Billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.6 * Scale, 0)
        Billboard.AlwaysOnTop = true
        Billboard.MaxDistance = 220
        Billboard.Parent = Parts.Head

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.fromScale(1, settings.SubLabel and 0.6 or 1)
        Label.BackgroundTransparency = 1
        Label.Font = Enum.Font.GothamBold
        Label.Text = settings.Label
        Label.TextColor3 = settings.LabelColor or Color3.fromRGB(255, 255, 255)
        Label.TextScaled = true
        Label.Parent = Billboard

        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Color3.fromRGB(0, 0, 0)
        Stroke.Thickness = 2
        Stroke.Parent = Label

        if settings.SubLabel then
            local Sub = Instance.new("TextLabel")
            Sub.Position = UDim2.fromScale(0, 0.6)
            Sub.Size = UDim2.fromScale(1, 0.4)
            Sub.BackgroundTransparency = 1
            Sub.Font = Enum.Font.Gotham
            Sub.Text = settings.SubLabel
            Sub.TextColor3 = Color3.fromRGB(200, 200, 210)
            Sub.TextScaled = true
            Sub.Parent = Billboard

            local SubStroke = Instance.new("UIStroke")
            SubStroke.Color = Color3.fromRGB(0, 0, 0)
            SubStroke.Thickness = 2
            SubStroke.Parent = Sub
        end
    end

    --- Marks it for anything that walks the workspace and wants to skip props.
    Model:SetAttribute("NPC", true)
    Model:SetAttribute("NPCKind", Kind)
    --- No executions, no finishers, no kill feed. It is not a fighter.
    Model:SetAttribute("ExecutionsDisabled", true)

    if settings.Health then
        Model:SetAttribute("NPCHealth", settings.Health)
        Model:SetAttribute("NPCMaxHealth", settings.Health)
    end

    ----------------------------------------------------------------------------
    -- PARENTING
    ----------------------------------------------------------------------------

    local Parent = settings.Parent
    if not Parent then
        local Ok, Folder = pcall(function()
            return require(ReplicatedStorage.Modules.CombatUtils).GetInGameFolder()
        end)
        Parent = (Ok and Folder) or workspace
    end
    Model.Parent = Parent

    ----------------------------------------------------------------------------
    -- THE HANDLE
    ----------------------------------------------------------------------------

    local Handle
    Handle = {
        Model = Model,
        Root = Root,
        Parts = Parts,
        Owner = settings.Owner,
        Kind = Kind,
        Scale = Scale,
        Alive = true,
        SpawnedAt = os.clock(),
        Age = 0,
        Lifetime = settings.Lifetime,
        Animate = settings.Animate,
        OnTick = settings.OnTick,
        --- Free-form storage for whatever spawned it.
        State = {},
    }

    --[=[
        Poses one limb.

        @param name     One of `MOVABLE`.
        @param rotation Degrees, as a Vector3 of (X, Y, Z). Applied about the limb's own
                        resting centre, so zero is the standing pose.
        @param offset   Studs away from the resting position, in the NPC's local space.

        This is the ONLY way the body moves, and it is a direct `CFrame` write to an
        anchored part. There is no joint to solve, no physics step to wait for and nothing
        that can decide the limb should be somewhere else.
    ]=]
    function Handle:SetLimb(name: string, rotation: Vector3?, offset: Vector3?)
        local Part = Parts[name]
        if not Part or not Part.Parent then
            return
        end

        local Rest = Offsets[name] or Vector3.zero
        local Rotation = rotation or Vector3.zero

        Part.CFrame = Root.CFrame
            * CFrame.new(Rest + (offset or Vector3.zero))
            * CFrame.Angles(math.rad(Rotation.X), math.rad(Rotation.Y), math.rad(Rotation.Z))
    end

    --- Puts every limb back where it rests. The base an `Animate` callback builds on.
    function Handle:ResetPose()
        for Name in Parts do
            Handle:SetLimb(Name, nil, nil)
        end
    end

    --- Applies a named pose, or a table in the same shape.
    function Handle:SetPose(pose: (string | {[string]: Vector3})?)
        local Table = type(pose) == "string" and Poses[pose] or pose
        if type(Table) ~= "table" then
            Handle:ResetPose()
            return
        end

        for _, Name in MOVABLE do
            Handle:SetLimb(Name, (Table :: any)[Name], nil)
        end
        Handle:SetLimb("Torso", (Table :: any).Torso, nil)
    end

    --[=[
        Moves the whole NPC.

        Writes the root and then re-poses every limb from it, because the limbs are
        anchored and therefore do not follow anything. That is the trade for never falling
        over: position is something this module applies, not something physics maintains.
    ]=]
    function Handle:MoveTo(cframe: CFrame)
        if not Handle.Alive or not Root.Parent then
            return
        end

        Root.CFrame = cframe
        Handle:ResetPose()
    end

    --- Turns to face a world position, keeping upright.
    function Handle:LookAt(position: Vector3)
        local Here = Root.Position
        local Flat = Vector3.new(position.X, Here.Y, position.Z)
        if (Flat - Here).Magnitude < 0.05 then
            return
        end
        Handle:MoveTo(CFrame.lookAt(Here, Flat))
    end

    --[=[
        Takes health off it.

        Health lives in an attribute rather than a `Humanoid`, so nothing in the engine
        reads this NPC as a character with a health bar. Returns whether it died.
    ]=]
    function Handle:Damage(amount: number): boolean
        if not Handle.Alive or not settings.Health then
            return false
        end

        local Current = Model:GetAttribute("NPCHealth")
        if typeof(Current) ~= "number" then
            return false
        end

        local Left = math.max(Current - math.max(amount, 0), 0)
        Model:SetAttribute("NPCHealth", Left)

        if Left > 0 then
            return false
        end

        if settings.OnDestroyed then
            local Ok, Err = pcall(settings.OnDestroyed, Handle)
            if not Ok then
                warn("[NPCService] An NPC's `OnDestroyed` errored: "..tostring(Err))
            end
        end

        Handle:Destroy()
        return true
    end

    --[=[
        Removes it. Idempotent, and the ONLY way an NPC leaves.

        Every early return in the old cinematic dummy left a rig in the workspace because
        teardown was spread across five code paths and some of them were skipped. There is
        one path here, it cannot run twice, and the stepper calls it for anything whose
        model has gone from the world regardless of who else was supposed to.
    ]=]
    function Handle:Destroy()
        if not Handle.Alive then
            return
        end
        Handle.Alive = false

        local Index = table.find(Live, Handle)
        if Index then
            table.remove(Live, Index)
        end

        Counts[Key] = math.max((Counts[Key] or 1) - 1, 0)
        if Counts[Key] <= 0 then
            Counts[Key] = nil
        end

        if settings.OnEnd then
            local Ok, Err = pcall(settings.OnEnd, Handle)
            if not Ok then
                warn("[NPCService] An NPC's `OnEnd` errored: "..tostring(Err))
            end
        end

        if Model.Parent then
            Model:Destroy()
        end

        if #Live <= 0 then
            StopStepper()
        end
    end

    ----------------------------------------------------------------------------
    -- GO
    ----------------------------------------------------------------------------

    Handle:SetPose(settings.Pose)

    if settings.FadeIn then
        local Info = TweenInfo.new(settings.FadeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        for _, Part in Parts do
            TweenService:Create(Part, Info, {Transparency = BaseTransparency}):Play()
        end
        TweenService:Create(Face, Info, {Transparency = BaseTransparency}):Play()
    end

    table.insert(Live, Handle)
    Counts[Key] = (Counts[Key] or 0) + 1
    StartStepper()

    return Handle
end

--------------------------------------------------------------------------------
-- READY-MADE MOTION
--------------------------------------------------------------------------------

--[=[
    `Animate` callbacks that cover what NPCs here actually need to do.

    Pass one straight into `Spawn`:

        NPCService.Spawn({CFrame = ..., Animate = NPCService.Motion.Breathe()})

    Each is a factory rather than a bare function so the amplitude and speed can be set per
    NPC without a table of magic numbers at every call site.
]=]
NPCService.Motion = {}

--- A slow idle sway. Enough that it does not read as a statue.
function NPCService.Motion.Breathe(amplitude: number?, speed: number?)
    local A = amplitude or 1
    local S = speed or 1.1

    return function(handle, age: number)
        local Swing = math.sin(age * S) * 5 * A
        handle:SetLimb("Left Arm", Vector3.new(Swing, 0, 4 * A))
        handle:SetLimb("Right Arm", Vector3.new(-Swing, 0, -4 * A))
        handle:SetLimb("Head", Vector3.new(math.sin(age * S * 0.6) * 3 * A, 0, 0))
        handle:SetLimb("Torso", nil, Vector3.new(0, math.sin(age * S) * 0.04 * A, 0))
    end
end

--- Arms up, held, with a tremor. The cinematic "about to do something" pose.
function NPCService.Motion.Channel(amplitude: number?, speed: number?)
    local A = amplitude or 1
    local S = speed or 9

    return function(handle, age: number)
        local Shake = math.sin(age * S) * 3 * A
        handle:SetLimb("Left Arm", Vector3.new(Shake, 0, 150 + Shake))
        handle:SetLimb("Right Arm", Vector3.new(Shake, 0, -150 - Shake))
        handle:SetLimb("Head", Vector3.new(-18 + Shake * 0.4, 0, 0))
    end
end

--- A walk cycle. Legs and arms only; `MoveTo` still has to do the travelling.
function NPCService.Motion.Walk(speed: number?)
    local S = speed or 6

    return function(handle, age: number)
        local Phase = math.sin(age * S) * 32
        handle:SetLimb("Left Leg", Vector3.new(Phase, 0, 0))
        handle:SetLimb("Right Leg", Vector3.new(-Phase, 0, 0))
        handle:SetLimb("Left Arm", Vector3.new(-Phase * 0.7, 0, 0))
        handle:SetLimb("Right Arm", Vector3.new(Phase * 0.7, 0, 0))
    end
end

--- Hovers and spins slowly in place. For things that are not pretending to be people.
function NPCService.Motion.Hover(height: number?, speed: number?)
    local H = height or 1
    local S = speed or 1

    return function(handle, age: number)
        local Bob = math.sin(age * S * 1.6) * 0.5 * H
        local Base = handle.Root.CFrame

        handle.Root.CFrame = CFrame.new(Base.Position) * CFrame.Angles(0, age * S * 0.7, 0)
        for Name in handle.Parts do
            handle:SetLimb(Name, nil, Vector3.new(0, Bob, 0))
        end
    end
end

--------------------------------------------------------------------------------
-- LOOKUP AND TEARDOWN
--------------------------------------------------------------------------------

--- How many are alive, in total or for one owner.
function NPCService.Count(owner: Player?): number
    if owner == nil then
        return #Live
    end
    return Counts[OwnerKey(owner)] or 0
end

--- Every live NPC belonging to one owner.
function NPCService.GetFor(owner: Player?): {any}
    local Found = {}
    for _, Handle in Live do
        if Handle.Owner == owner then
            table.insert(Found, Handle)
        end
    end
    return Found
end

--- Every live NPC within `radius` studs of a point.
function NPCService.GetInRadius(position: Vector3, radius: number): {any}
    local Found = {}
    for _, Handle in Live do
        if Handle.Root.Parent and (Handle.Root.Position - position).Magnitude <= radius then
            table.insert(Found, Handle)
        end
    end
    return Found
end

--- Removes everything belonging to one owner.
function NPCService.ClearFor(owner: Player?)
    for Index = #Live, 1, -1 do
        local Handle = Live[Index]
        if Handle.Owner == owner then
            Handle:Destroy()
        end
    end
end

--- Removes everything of one `Kind`, whoever owns it.
function NPCService.ClearKind(kind: string)
    for Index = #Live, 1, -1 do
        local Handle = Live[Index]
        if Handle.Kind == kind then
            Handle:Destroy()
        end
    end
end

--[=[
    Removes everything.

    Called from `MapManager.DestroyCurrentMap` alongside the other spawning services, so a
    round ending cannot leave a single NPC standing in an empty world.
]=]
function NPCService.ClearAll()
    for Index = #Live, 1, -1 do
        local Handle = Live[Index]
        if Handle then
            Handle:Destroy()
        end
    end

    table.clear(Live)
    table.clear(Counts)
    StopStepper()
end

if RunService:IsServer() then
    Players.PlayerRemoving:Connect(function(player: Player)
        NPCService.ClearFor(player)
    end)
end

return NPCService
