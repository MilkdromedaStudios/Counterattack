--[=[
    WEATHER HUD — CLIENT

    Everything the weather looks like from inside a player's head: the warning banner, the
    fog and tint, the rain and ash blowing past the camera, the screen shake and the
    lightning flash.

    WHY THE LIGHTING IS DONE HERE AND NOT ON THE SERVER
    ---------------------------------------------------
    NDS wrote fog straight onto `game.Lighting` from its server script. That works there
    because nothing else in that game touches lighting. Here `Modules.Lighting` gives every
    client its own copy of the map's lighting when they spawn and resets it between rounds
    — so a server writing `FogEnd` on top of that is two owners fighting over one property,
    and the one that loses is whichever ran last. In practice that meant somebody, somewhere,
    stayed permanently fogged in after a storm because their client reset happened to land
    before the server's clear.

    Instead the server sends weather as STATE and this module owns the properties end to
    end: it snapshots what lighting looked like before the first event, blends whatever is
    currently running on top, and puts the snapshot back when the last event clears. One
    owner, and it can always get back to where it started.

    Every visual is built in code. There are no Studio prefabs to copy, so this works on a
    fresh clone of the place with nothing but a sync.
]=]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Modules.Network)

local LocalPlayer = Players.LocalPlayer

local WeatherHUD = {
    --- Live state per event name. Several can run at once, so they're merged rather than
    --- overwriting each other.
    Active = {},
    --- Lighting as it was before the first event started.
    Snapshot = nil,
    Enabled = true,
}

local LIGHTING_KEYS = {"FogColor", "FogEnd", "FogStart", "Brightness"}

local Gui: ScreenGui
local Banner: Frame
local BannerTitle: TextLabel
local BannerHint: TextLabel
local Tint: Frame
local Vignette: ImageLabel
local Flash: Frame

local ParticleHolder: BasePart?
local Emitters: {[string]: ParticleEmitter} = {}

local ShakeAmount = 0
local BannerToken = 0
--- `"Cold"`, `"Dust"` or nil — which edge-darkening the running weather asked for.
local CurrentVignette: string? = nil

--------------------------------------------------------------------------------
-- BUILDING THE UI
--------------------------------------------------------------------------------

local function BuildGui()
    Gui = Instance.new("ScreenGui")
    Gui.Name = "WeatherHUD"
    Gui.ResetOnSpawn = false
    Gui.IgnoreGuiInset = true
    Gui.DisplayOrder = 5
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Full-screen colour wash. Kept low-alpha; this is atmosphere, not a blindfold.
    Tint = Instance.new("Frame")
    Tint.Name = "Tint"
    Tint.Size = UDim2.fromScale(1, 1)
    Tint.BackgroundColor3 = Color3.new(1, 1, 1)
    Tint.BackgroundTransparency = 1
    Tint.BorderSizePixel = 0
    Tint.ZIndex = 1
    Tint.Parent = Gui

    -- Darkened edges. See `Vignettes` below for who asks for one and how hard.
    Vignette = Instance.new("ImageLabel")
    Vignette.Name = "Vignette"
    Vignette.Size = UDim2.fromScale(1, 1)
    Vignette.BackgroundTransparency = 1
    Vignette.Image = "rbxassetid://5761695699"
    Vignette.ImageTransparency = 1
    Vignette.ScaleType = Enum.ScaleType.Stretch
    Vignette.ZIndex = 2
    Vignette.Parent = Gui

    Flash = Instance.new("Frame")
    Flash.Name = "Flash"
    Flash.Size = UDim2.fromScale(1, 1)
    Flash.BackgroundColor3 = Color3.new(1, 1, 1)
    Flash.BackgroundTransparency = 1
    Flash.BorderSizePixel = 0
    Flash.ZIndex = 3
    Flash.Parent = Gui

    Banner = Instance.new("Frame")
    Banner.Name = "Banner"
    Banner.AnchorPoint = Vector2.new(0.5, 0)
    Banner.Position = UDim2.new(0.5, 0, 0, -140)
    Banner.Size = UDim2.new(0, 620, 0, 96)
    Banner.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
    Banner.BackgroundTransparency = 0.15
    Banner.BorderSizePixel = 0
    Banner.ZIndex = 4
    Banner.Parent = Gui

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Banner

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(210, 60, 40)
    Stroke.Thickness = 2
    Stroke.Parent = Banner

    BannerTitle = Instance.new("TextLabel")
    BannerTitle.Name = "Title"
    BannerTitle.BackgroundTransparency = 1
    BannerTitle.Position = UDim2.new(0, 18, 0, 12)
    BannerTitle.Size = UDim2.new(1, -36, 0, 40)
    BannerTitle.Font = Enum.Font.GothamBlack
    BannerTitle.TextScaled = true
    BannerTitle.TextColor3 = Color3.fromRGB(255, 235, 230)
    BannerTitle.TextXAlignment = Enum.TextXAlignment.Center
    BannerTitle.ZIndex = 5
    BannerTitle.Text = ""
    BannerTitle.Parent = Banner

    BannerHint = Instance.new("TextLabel")
    BannerHint.Name = "Hint"
    BannerHint.BackgroundTransparency = 1
    BannerHint.Position = UDim2.new(0, 18, 0, 54)
    BannerHint.Size = UDim2.new(1, -36, 0, 28)
    BannerHint.Font = Enum.Font.Gotham
    BannerHint.TextScaled = true
    BannerHint.TextColor3 = Color3.fromRGB(190, 190, 195)
    BannerHint.TextXAlignment = Enum.TextXAlignment.Center
    BannerHint.ZIndex = 5
    BannerHint.Text = ""
    BannerHint.Parent = Banner
end

--------------------------------------------------------------------------------
-- CAMERA PARTICLES
--------------------------------------------------------------------------------

--[=[
    A block of particles that rides just above the camera.

    Parented to `workspace.CurrentCamera`, which is the standard trick for client-only
    world objects: nothing under the camera replicates, nothing under it is saved, and it
    is cleaned up for free when the camera is rebuilt.
]=]
local function EnsureParticleHolder(): BasePart?
    local Camera = workspace.CurrentCamera
    if not Camera then
        return nil
    end

    if ParticleHolder and ParticleHolder.Parent == Camera then
        return ParticleHolder
    end

    local Holder = Instance.new("Part")
    Holder.Name = "WeatherParticles"
    Holder.Anchored = true
    Holder.CanCollide = false
    Holder.CanQuery = false
    Holder.CanTouch = false
    Holder.CastShadow = false
    Holder.Transparency = 1
    Holder.Size = Vector3.new(60, 1, 60)
    Holder.Parent = Camera

    ParticleHolder = Holder
    table.clear(Emitters)

    return Holder
end

local PARTICLE_PRESETS = {
    Rain = {
        Texture = "rbxassetid://241876428",
        Color = ColorSequence.new(Color3.fromRGB(170, 200, 225)),
        Rate = 400,
        Speed = NumberRange.new(70, 95),
        Size = NumberSequence.new(0.28),
        Lifetime = NumberRange.new(0.7, 1),
        Transparency = NumberSequence.new(0.4),
        Drag = 0,
    },
    Embers = {
        Texture = "rbxassetid://242201991",
        Color = ColorSequence.new(Color3.fromRGB(255, 170, 70), Color3.fromRGB(190, 50, 0)),
        Rate = 90,
        Speed = NumberRange.new(4, 12),
        Size = NumberSequence.new(0.55, 0),
        Lifetime = NumberRange.new(1.4, 3),
        Transparency = NumberSequence.new(0.2, 1),
        Drag = 0.5,
    },
    Dust = {
        Texture = "rbxassetid://241876428",
        Color = ColorSequence.new(Color3.fromRGB(150, 140, 125)),
        Rate = 130,
        Speed = NumberRange.new(3, 9),
        Size = NumberSequence.new(1.6, 0),
        Lifetime = NumberRange.new(2, 3.5),
        Transparency = NumberSequence.new(0.7, 1),
        Drag = 1.5,
    },
}

local function SetParticles(Kind: string, On: boolean)
    local Preset = PARTICLE_PRESETS[Kind]
    if not Preset then
        return
    end

    local Holder = EnsureParticleHolder()
    if not Holder then
        return
    end

    local Emitter = Emitters[Kind]
    if not Emitter then
        if not On then
            return
        end

        Emitter = Instance.new("ParticleEmitter")
        Emitter.Name = Kind
        Emitter.Texture = Preset.Texture
        Emitter.Color = Preset.Color
        Emitter.Speed = Preset.Speed
        Emitter.Size = Preset.Size
        Emitter.Lifetime = Preset.Lifetime
        Emitter.Transparency = Preset.Transparency
        Emitter.Drag = Preset.Drag
        Emitter.Rotation = NumberRange.new(0, 360)
        Emitter.RotSpeed = NumberRange.new(-90, 90)
        Emitter.SpreadAngle = Vector2.new(35, 35)
        Emitter.EmissionDirection = Kind == "Embers" and Enum.NormalId.Top or Enum.NormalId.Bottom
        Emitter.LightEmission = Kind == "Embers" and 1 or 0
        Emitter.Parent = Holder
        Emitters[Kind] = Emitter
    end

    Emitter.Rate = On and Preset.Rate or 0
end

--------------------------------------------------------------------------------
-- MERGING WHAT'S RUNNING
--------------------------------------------------------------------------------

--[=[
    Combines every running event's state into one set of values to apply.

    The rules are "whichever is worse wins": the shortest fog distance, the lowest
    brightness, the strongest tint, the biggest shake. Two events at once should feel like
    the sum of both rather than like whichever one happened to arrive second.
]=]
--[=[
    THE VIGNETTE VOCABULARY.

    An event asks for one by name through `Vignette` in its visuals table. Anything not
    listed here draws nothing, so a typo costs that one tint rather than erroring.

    ALPHA IS A FLOOR, NOT A BLINDFOLD. Every value here is deliberately high — 0.5 is the
    most opaque anything gets — because this is a FIGHTING arena. The two events that used
    to own this effect were the sandstorm and the blizzard, and both were removed for
    exactly that reason: they took the screen away and left the fight to whoever guessed
    right. A vignette here says "something is happening at the edges of the world", and
    the player can still see, aim and fight through all of it.
]=]
local Vignettes = {
    --- Flash Flood and Tsunami. Water creeping in at the edges of vision.
    Water = {Colour = Color3.fromRGB(120, 180, 225), Alpha = 0.5},
    --- Volcanic Eruption. Ash and heat haze.
    Ash = {Colour = Color3.fromRGB(235, 140, 80), Alpha = 0.45},
    --- Tornado. Grit torn off the arena and thrown past the camera.
    Dust = {Colour = Color3.fromRGB(230, 200, 140), Alpha = 0.42},
    --- Meteor Shower. The sky lit the wrong colour.
    Ember = {Colour = Color3.fromRGB(255, 170, 110), Alpha = 0.4},
}

--[=[
    Redraws the edge-darkening.

    Split out of `Apply` so an event can push a new tint without rebuilding every other
    visual, and so the respawn path can restore it in one call.
]=]
local function UpdateVignette(Time: number?)
    if not Vignette then
        return
    end

    local Preset = CurrentVignette and Vignettes[CurrentVignette]

    if not Preset then
        TweenService:Create(Vignette, TweenInfo.new(Time or 0.4), {ImageTransparency = 1}):Play()
        return
    end

    TweenService:Create(Vignette, TweenInfo.new(Time or 0.4), {
        ImageTransparency = Preset.Alpha,
        ImageColor3 = Preset.Colour,
    }):Play()
end

local function Merge()
    local Result = {
        FogColor = nil :: Color3?,
        FogEnd = nil :: number?,
        FogStart = nil :: number?,
        Brightness = nil :: number?,
        Tint = nil :: Color3?,
        TintAlpha = 0,
        Vignette = nil :: string?,
        Shake = 0,
        Particles = {},
    }

    local Count = 0

    for _, State in WeatherHUD.Active do
        Count += 1

        if State.FogEnd and (not Result.FogEnd or State.FogEnd < Result.FogEnd) then
            Result.FogEnd = State.FogEnd
            Result.FogColor = State.FogColor or Result.FogColor
        end
        if State.FogColor and not Result.FogColor then
            Result.FogColor = State.FogColor
        end
        if State.FogStart and (not Result.FogStart or State.FogStart < Result.FogStart) then
            Result.FogStart = State.FogStart
        end
        if State.Brightness and (not Result.Brightness or State.Brightness < Result.Brightness) then
            Result.Brightness = State.Brightness
        end
        if State.Tint and (State.TintAlpha or 0) > Result.TintAlpha then
            Result.Tint = State.Tint
            Result.TintAlpha = State.TintAlpha or 0
        end
        if State.Vignette then
            Result.Vignette = State.Vignette
        end
        if State.Shake and State.Shake > Result.Shake then
            Result.Shake = State.Shake
        end

        -- Every preset in `PARTICLE_PRESETS`. "Snow" and "Sand" were here until the
        -- blizzard and the sandstorm were removed; nothing requests them now.
        for _, Kind in {"Rain", "Embers", "Dust"} do
            if State[Kind] then
                Result.Particles[Kind] = true
            end
        end
    end

    Result.Any = Count > 0
    return Result
end

local function Apply(FadeTime: number?)
    local Merged = Merge()
    local Time = FadeTime or 2

    if Merged.Any then
        --[[
            Snapshot on the way IN, not at startup.

            Lighting at startup is the lobby's; by the time weather runs the map has
            replaced it, and restoring a startup snapshot would drop the player back into
            lobby lighting in the middle of a round. Taking it as the first event begins
            means the restore always matches whatever the map asked for.
        ]]
        if not WeatherHUD.Snapshot then
            local Snapshot = {}
            for _, Key in LIGHTING_KEYS do
                Snapshot[Key] = (Lighting :: any)[Key]
            end
            WeatherHUD.Snapshot = Snapshot
        end

        local Goal = {}
        for _, Key in LIGHTING_KEYS do
            if Merged[Key] ~= nil then
                Goal[Key] = Merged[Key]
            end
        end

        if next(Goal) then
            TweenService:Create(Lighting, TweenInfo.new(Time, Enum.EasingStyle.Sine), Goal):Play()
        end

        TweenService:Create(Tint, TweenInfo.new(Time), {
            BackgroundColor3 = Merged.Tint or Color3.new(1, 1, 1),
            BackgroundTransparency = 1 - Merged.TintAlpha,
        }):Play()

        CurrentVignette = Merged.Vignette
        UpdateVignette(Time)

        ShakeAmount = Merged.Shake
    else
        if WeatherHUD.Snapshot then
            TweenService:Create(Lighting, TweenInfo.new(Time, Enum.EasingStyle.Sine), WeatherHUD.Snapshot):Play()
            WeatherHUD.Snapshot = nil
        end

        TweenService:Create(Tint, TweenInfo.new(Time), {BackgroundTransparency = 1}):Play()

        CurrentVignette = nil
        UpdateVignette(Time)

        ShakeAmount = 0
    end

    for Kind in PARTICLE_PRESETS do
        SetParticles(Kind, Merged.Particles[Kind] == true)
    end
end

--------------------------------------------------------------------------------
-- THE BANNER
--------------------------------------------------------------------------------

local function ShowBanner(Title: string, Hint: string?)
    BannerToken += 1
    local Token = BannerToken

    BannerTitle.Text = Title or ""
    BannerHint.Text = Hint or ""

    TweenService:Create(Banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 40),
    }):Play()

    task.delay(6, function()
        -- A second warning arriving inside the six seconds takes over the banner; this
        -- older timer must not then yank it off screen mid-announcement.
        if Token ~= BannerToken then
            return
        end

        TweenService:Create(Banner, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 0, -140),
        }):Play()
    end)
end

local function DoFlash()
    Flash.BackgroundTransparency = 0.35
    TweenService:Create(Flash, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
end

--------------------------------------------------------------------------------
-- SHAKE
--------------------------------------------------------------------------------

local function BindShake()
    RunService:BindToRenderStep("WeatherShake", Enum.RenderPriority.Camera.Value + 1, function()
        local Camera = workspace.CurrentCamera
        if not Camera then
            return
        end

        --[[
            Carry the particle block along with the camera.

            Parenting it to the Camera makes it client-only; it does NOT make it follow the
            camera — a `Part` under a Camera still lives at whatever world position you put
            it. Without this the snow falls in a 60-stud column at the world origin, which
            on most maps is somewhere nobody will ever stand, and the weather appears to
            have no particles at all.

            Emitted from above and slightly ahead so the flakes fall through frame rather
            than materialising in the middle of it.
        ]]
        if ParticleHolder and ParticleHolder.Parent == Camera then
            ParticleHolder.CFrame = CFrame.new(
                Camera.CFrame.Position
                + Vector3.new(0, 22, 0)
                + Camera.CFrame.LookVector * 12
            )
        end

        if ShakeAmount <= 0 then
            return
        end

        local Magnitude = ShakeAmount * 0.35
        Camera.CFrame *= CFrame.new(
            (math.random() - 0.5) * Magnitude,
            (math.random() - 0.5) * Magnitude,
            0
        ) * CFrame.Angles(
            (math.random() - 0.5) * Magnitude * 0.01,
            (math.random() - 0.5) * Magnitude * 0.01,
            (math.random() - 0.5) * Magnitude * 0.01
        )
    end)
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------

function WeatherHUD:Init()
    if RunService:IsServer() then
        return
    end

    BuildGui()
    BindShake()

    Network:SetConnection("WeatherWarning", "REMOTE_EVENT", function(Title: string, Hint: string?)
        ShowBanner(Title, Hint)
    end)

    Network:SetConnection("WeatherVisuals", "REMOTE_EVENT", function(EventName: string, State: {[string]: any}?, FadeTime: number?)
        --[[
            A flash is an EVENT, not a state — the lightning strike sends `{Flash = true}`
            and nothing else. Storing that in `Active` would leave the event permanently
            "running" with no visuals attached, which then blocks the restore when the real
            storm state clears. So it is played and dropped.
        ]]
        if State and State.Flash then
            DoFlash()

            local Keys = 0
            for _ in State do
                Keys += 1
            end
            if Keys == 1 then
                return
            end
        end

        if EventName == "All" then
            table.clear(WeatherHUD.Active)
        else
            WeatherHUD.Active[EventName] = State
        end

        Apply(FadeTime)
    end)

    --[[
        A fresh body starts with the tint the current weather asks for.

        This used to also watch a `WeatherExposure` attribute that the blizzard wrote
        several times a second. The blizzard is gone and nothing writes that attribute any
        more, so the listener is gone with it rather than left watching a value that can
        never change — a dead `GetAttributeChangedSignal` connection per respawn is a slow
        leak and a confusing thing to read a year from now.
    ]]
    local function BindCharacter(_Character: Model)
        UpdateVignette(0.2)
    end

    if LocalPlayer.Character then
        BindCharacter(LocalPlayer.Character)
    end

    -- The camera is rebuilt on respawn, taking the particle holder with it. Rebuilding it
    -- lazily on the next state change would leave a respawning player with no rain or ash
    -- until the weather next changed, which in an 85 second flood is the whole flood.
    LocalPlayer.CharacterAdded:Connect(function(Character: Model)
        task.defer(function()
            ParticleHolder = nil
            table.clear(Emitters)
            Apply(0.2)
            BindCharacter(Character)
        end)
    end)
end

return WeatherHUD
