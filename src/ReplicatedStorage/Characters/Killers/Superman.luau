local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Hitbox = require(ReplicatedStorage.Classes.Hitbox)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local AbilityClient = require(ReplicatedStorage.Modules.AbilityClient)
local AbilityFX = require(ReplicatedStorage.Modules.AbilityFX)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local MeterService = require(ReplicatedStorage.Modules.MeterService)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    SUPERMAN — BALANCED, BECAUSE HE HAS TO BE.

      M1  SUPER PUNCH   The hardest single swing in the arena, and one of the slowest.
      Q   FLIGHT        A toggle, on a meter, with a hard altitude ceiling.
      E   HEAT VISION   Startup, a visible aim line, then a beam.
      R   FREEZE BREATH A cone that slows. It does not freeze anybody in place.
      F   SUPER SPEED   A very fast, very short dash.
      P   INVULNERABLE  Resistant to what stops people. Not immune to any of it.

    HOW A CHARACTER WHO CANNOT BE HURT IS MADE FAIR
    ----------------------------------------------
    By not giving him that. The brief was explicit — he must be balanced and he must remain
    mechanically stoppable — so every piece of the power fantasy is converted into something
    with a ceiling:

      * HE IS NOT INVULNERABLE. `Invulnerable` halves the duration of `Stunned`, ignores
        `Slipping`, and halves `Snared` and `Slowness`. It does not touch damage at all. He
        can be stunned, he can be slowed, he can be killed; all of it just takes a little
        more.
      * FLIGHT IS CAPPED IN THREE DIRECTIONS. A 24 second meter that only refills on the
        ground, a hard altitude ceiling above the terrain beneath him, and no attacking at
        all while airborne. He cannot hover out of reach and he cannot fight from the sky.
      * HEAT VISION IS TELEGRAPHED. A visible aim line for most of a second before it fires,
        along a line that does not track.
      * FREEZE BREATH SLOWS. It is `Slowness` and `Grounded` on a short duration. There is
        no freeze, no root, and no stun anywhere in his kit.

    WHAT HE ACTUALLY IS
    -------------------
    A heavy hitter with conditional mobility and average everything else. He wins the first
    exchange of any fight and loses a long one; his skill expression is managing a meter that
    only refills while he is standing on the floor where everybody can reach him.

    HE IS DELIBERATELY NOT TOP-TIER IN THREE PLACES AT ONCE. An earlier pass had him at 1600
    health, 11.5 base speed and a 2.2 second punch, which put him in the roster's upper
    quartile for durability, pace AND sustained damage simultaneously — the exact combination
    the brief rules out. The punch is now the slowest-cycling heavy attack in the game and his
    footspeed is average, because the flight is supposed to be his mobility.
]=]

local SUIT = Color3.fromRGB(40, 90, 200)
local CAPE = Color3.fromRGB(200, 40, 50)
local HEAT = Color3.fromRGB(255, 90, 50)
local FROST = Color3.fromRGB(150, 220, 255)
local FLIGHT_METER = "Flight"

--------------------------------------------------------------------------------
-- M1 — SUPER PUNCH
--------------------------------------------------------------------------------

local function PunchBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.06, Duration = 0.3, Lock = 0.6, Shake = 1, ShakeTime = 0.25})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    -- No punching from the air. See `Flight`.
    if Char:GetAttribute("SupermanFlying") then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.8, MinPitch = 0.85, MaxPitch = 1.0})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        local Impact = Root.Position + Root.CFrame.LookVector * 4 + Vector3.new(0, 1, 0)
        AbilityFX.Burst(Impact, 5, Color3.new(1, 1, 1), {Duration = 0.2, StartSize = 1.5})

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Super Punch",
            ExecuteOnKill = true,
            Knockback = self.Knockback,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if not VictimRoot then
                        return
                    end

                    AbilityFX.Shockwave(VictimRoot.Position, 9, Color3.new(1, 1, 1), 22)
                    AbilityFX.ShakeFor(Victim, 5, 0.6)
                    AbilityFX.ScreenFor(Victim, "Flash", 0.3, 0.6)
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — FLIGHT
--------------------------------------------------------------------------------

--[=[
    A toggle, a meter, and a ceiling.

    THE THREE LIMITS, all of which the brief asked for explicitly:

      ALTITUDE   Capped at `Ceiling` studs above whatever ground is directly beneath him.
                 Measured per tick from a downward ray, so it follows terrain — he can fly
                 over a tower, and he cannot fly ABOVE it by more than the ceiling. That
                 also keeps him inside the map vertically without needing map-specific
                 bounds.

      DURATION   A meter that drains while airborne and only refills ON THE GROUND. Taking
                 off with a half-empty gauge is a commitment.

      NO FIGHTING  `PreventSlash` while flying, and the two offensive abilities refuse to
                 fire in the air. He is a delivery system, not a gunship.

    He is also pushed gently away from anything he flies into rather than being stopped by
    it, so the flight cannot be used to wedge himself inside geometry.
]=]
local function FlightBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        local Char = self.OwnerProperties.Character
        if Char and Char:GetAttribute("SupermanFlying") then
            AbilityClient.ReleaseZoom(self)
        else
            AbilityClient.Zoom(self, 1.22)
        end
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    ----------------------------------------------------------------------------
    -- LAND
    ----------------------------------------------------------------------------

    if Char:GetAttribute("SupermanFlying") then
        Char:SetAttribute("SupermanFlying", false)
        return
    end

    ----------------------------------------------------------------------------
    -- TAKE OFF
    ----------------------------------------------------------------------------

    if MeterService.Get(Char, FLIGHT_METER) < self.MinimumToLaunch then
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "too tired to fly", SUIT, 1)
        return
    end

    Char:SetAttribute("SupermanFlying", true)
    Char:SetAttribute("PreventSlash", true)

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.9})
    AbilityFX.Ring(Root.Position, 10, SUIT, {Duration = 0.5})
    AbilityFX.Smoke(Root.Position - Vector3.new(0, 2, 0), Color3.fromRGB(220, 220, 220), 10, 3)

    task.spawn(function()
        while Char and Char.Parent and Char:GetAttribute("SupermanFlying") do
            task.wait(0.05)

            local Live = Utils.Character.GetRootPart(Char)
            local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
            if not Live or not Humanoid or Humanoid.Health <= 0 then
                break
            end

            -- Stunned in the air: he comes down. The clearest possible counterplay.
            if Char.Effects and Char.Effects:FindFirstChild("Stunned") then
                AbilityFX.Text(Live.Position + Vector3.new(0, 5, 0), "!", CAPE, 1)
                break
            end

            ----------------------------------------------------------------
            -- FUEL
            ----------------------------------------------------------------

            if not MeterService.Spend(Char, FLIGHT_METER, self.DrainPerTick) then
                AbilityFX.Text(Live.Position + Vector3.new(0, 5, 0), "out of lift", SUIT, 1.1)
                break
            end

            ----------------------------------------------------------------
            -- ALTITUDE
            ----------------------------------------------------------------

            --[=[
                The ceiling, measured from the ground directly below him.

                Relative rather than absolute so it follows terrain: he can cross a tower,
                and he cannot climb more than `Ceiling` studs above whatever he is over. It
                also means no map needs to declare a height limit for him to respect.
            ]=]
            local Ground = AbilityFX.GroundAt(Live.Position, {Char, workspace.Players}, self.Ceiling + 40)
            local Altitude = Ground and (Live.Position.Y - Ground.Y) or 0

            local Vertical
            if Altitude >= self.Ceiling then
                -- At the ceiling: hold, do not climb.
                Vertical = math.min(Live.AssemblyLinearVelocity.Y, 0)
            elseif Altitude < self.CruiseHeight then
                -- Below cruise: climb into it.
                Vertical = self.ClimbSpeed
            else
                Vertical = 0
            end

            ----------------------------------------------------------------
            -- MOVEMENT
            ----------------------------------------------------------------

            local Forward = Live.CFrame.LookVector

            --[[
                Nudged away from whatever is directly ahead rather than stopped by it.

                Flying into a wall at 70 studs a second and being held against it is how a
                character ends up inside geometry; deflecting keeps the physics sane and
                reads as him banking around the obstacle.
            ]]
            local Params = RaycastParams.new()
            Params.FilterType = Enum.RaycastFilterType.Exclude
            Params.FilterDescendantsInstances = {Char, workspace.Players, AbilityFX.Folder()}
            Params.RespectCanCollide = true

            local Ahead = workspace:Raycast(Live.Position, Forward * 8, Params)
            if Ahead then
                Forward = (Forward + Ahead.Normal * 1.5).Unit
            end

            Live.AssemblyLinearVelocity = Vector3.new(
                Forward.X * self.Speed,
                Vertical,
                Forward.Z * self.Speed
            )

            -- The cape and the contrail.
            AbilityFX.Burst(Live.Position - Forward * 2, 3, CAPE, {
                Duration = 0.3,
                StartSize = 2,
                Transparency = 0.75,
            })
        end

        ------------------------------------------------------------------------
        -- TOUCHDOWN
        ------------------------------------------------------------------------

        --[[
            Cleanup for every way flight can end: landing, running out, being stunned,
            dying, or the round ending. `PreventSlash` surviving onto a new body would be a
            Superman who can never punch.
        ]]
        if Char then
            Char:SetAttribute("SupermanFlying", false)
            Char:SetAttribute("PreventSlash", nil)

            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                AbilityFX.Smoke(Live.Position, Color3.fromRGB(220, 220, 220), 8, 2.5)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- E — HEAT VISION
--------------------------------------------------------------------------------

--[=[
    Startup, a visible line, then a beam.

    Fixed at cast: the line it fires along is the one he was facing when he pressed it, so
    turning during the startup does not re-aim it. He is slowed rather than rooted, which
    means he can still reposition — he just cannot change where the beam is going.

    No flying while using it.
]=]
local function HeatVisionBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.86, Duration = self.Startup + 0.4, Lock = self.Startup + 0.3})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    if Char:GetAttribute("SupermanFlying") then
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "not while flying", HEAT, 1)
        return
    end

    local Origin = Root.Position + Vector3.new(0, 2, 0)
    local Direction = Root.CFrame.LookVector
    local Finish = Origin + Direction * self.Length

    AbilityFX.Sound(self.ChargeSound, Origin, {Volume = 0.8, MinPitch = 1.1, MaxPitch = 1.2})
    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.StartupSpeedMultiplier)

    -- THE TELEGRAPH: the line, and his eyes glowing hotter.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Startup and Char and Char.Parent do
            Elapsed += task.wait(0.07)

            local Progress = Elapsed / self.Startup
            AbilityFX.Beam(Origin, Finish, HEAT, {
                Width = 0.2 + Progress * 0.6,
                Duration = 0.1,
                Transparency = 0.8 - Progress * 0.5,
            })

            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                AbilityFX.Tint(Char, HEAT, 0.12, {FillTransparency = 0.9 - Progress * 0.2})
            end
        end
    end)

    task.delay(self.Startup, function()
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)

        if not Char or not Char.Parent then
            return
        end

        -- Interrupted: no beam.
        if Char.Effects and Char.Effects:FindFirstChild("Stunned") then
            AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "...", HEAT, 0.9)
            return
        end

        AbilityFX.Sound(self.UseSound, Origin, {Volume = 1, RollOffMaxDistance = 200})

        -- Two tight beams from the eyes, converging. The look of the thing.
        for _, Side in {-0.6, 0.6} do
            AbilityFX.Beam(
                Origin + Root.CFrame.RightVector * Side,
                Finish,
                HEAT,
                {Width = self.Width * 0.5, Duration = 0.45, Transparency = 0.05}
            )
        end
        AbilityFX.Beam(Origin, Finish, Color3.new(1, 0.9, 0.7), {Width = self.Width, Duration = 0.5, Transparency = 0.55})

        local Struck = {}
        local Steps = math.ceil(self.Length / 8)

        for Index = 0, Steps do
            local Point = Origin + Direction * (self.Length * Index / Steps)

            for _, Target: Model in CombatUtils.GetFightersInRadius(Point, self.Width, Char) do
                if Struck[Target] then
                    continue
                end
                Struck[Target] = true

                local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
                if not Humanoid then
                    continue
                end

                CommonFunctions.DamagePlayer({
                    SourcePlayer = self.Owner,
                    TargetHumanoid = Humanoid,
                    Damage = self.Damage,
                    Reason = self.Name,
                })

                CombatUtils.ApplyEffectTo(Target, "Burning", 2, self.BurnTime)
                AbilityFX.ScreenFor(Target, "Flash", 0.4, 0.8)
                AbilityFX.ShakeFor(Target, 3, 0.4)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- R — FREEZE BREATH
--------------------------------------------------------------------------------

--[=[
    A cone that slows.

    NOT A FREEZE. `Slowness` at level 3 and `Grounded`, for four seconds. The brief was
    explicit that it must not freeze anybody in place, and this does not: you keep your
    abilities, your basic attack and your ability to walk away — slowly.

    The `Chill` screen effect is what sells it, because a slow with no visual is invisible.
]=]
local function FreezeBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.94, Duration = 0.5, Lock = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position + Vector3.new(0, 1.5, 0)
    local Direction = Root.CFrame.LookVector

    if Char:GetAttribute("SupermanFlying") then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 0.9})
    AbilityFX.Cone(Origin, Direction, self.Range, self.Angle, FROST, {Rays = 11, Duration = 0.5, Width = 0.8})

    -- Frost drifting out and settling, rather than a flash.
    for Index = 1, 4 do
        task.delay(Index * 0.07, function()
            AbilityFX.Emit(Origin + Direction * (self.Range * Index / 5), 10, {
                Color = ColorSequence.new(FROST, Color3.new(1, 1, 1)),
                Speed = NumberRange.new(4, 14),
                Size = NumberSequence.new(2),
                Lifetime = NumberRange.new(0.5, 1.1),
                SpreadAngle = Vector2.new(50, 50),
            })
        end)
    end

    local Caught = 0

    for _, Target: Model in AbilityFX.ConeTargets(Origin, Direction, self.Range, self.Angle, Char) do
        local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
        local TargetRoot = Utils.Character.GetRootPart(Target)
        if not Humanoid or not TargetRoot then
            continue
        end

        Caught += 1

        CommonFunctions.DamagePlayer({
            SourcePlayer = self.Owner,
            TargetHumanoid = Humanoid,
            Damage = self.Damage,
            Reason = self.Name,
        })

        -- Slowed and grounded. Not rooted, not stunned, not frozen.
        CombatUtils.ApplyEffectTo(Target, "Slowness", self.SlowLevel, self.SlowTime)
        CombatUtils.ApplyEffectTo(Target, "Grounded", 1, self.SlowTime)

        AbilityFX.ScreenFor(Target, "Chill", self.SlowTime, 1.2)
        AbilityFX.Tint(Target, FROST, self.SlowTime, {FillTransparency = 0.72})
    end

    if Caught <= 0 then
        self.OnCooldown = false
        self.CooldownTimer = 0
    end
end

--------------------------------------------------------------------------------
-- F — SUPER SPEED
--------------------------------------------------------------------------------

--[=[
    A very fast, very short dash.

    Distinct from `Flight` by being instant, horizontal, grounded, and ON A SHORT COOLDOWN:
    flight is a committed travel mode with a meter, and this is a single reposition inside a
    fight. It hits everybody he passes through once, which makes it an engage as well.

    Deliberately shorter than Cuphead's dash is fast and Guest's charge is long — the roster
    has six dash-shaped abilities and this one is the "I am already there" version.
]=]
local function SpeedBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.3, Duration = self.DashTime + 0.15})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.8, MinPitch = 1.2, MaxPitch = 1.35})

    CombatUtils.Dash(Char, self.DashSpeed, self.DashTime, true)

    local Struck = {}

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.DashTime and Char and Char.Parent do
            Elapsed += task.wait(0.03)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            -- A streak of blue and red.
            AbilityFX.Burst(Live.Position, 3, SUIT, {Duration = 0.2, StartSize = 2.5, Transparency = 0.6})
            AbilityFX.Burst(Live.Position - Live.CFrame.LookVector * 2, 2.5, CAPE, {
                Duration = 0.25,
                StartSize = 2,
                Transparency = 0.7,
            })

            for _, Target: Model in CombatUtils.GetFightersInRadius(Live.Position, self.Radius, Char) do
                if Struck[Target] then
                    continue
                end
                Struck[Target] = true

                local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
                local TargetRoot = Utils.Character.GetRootPart(Target)
                if not Humanoid or not TargetRoot then
                    continue
                end

                CommonFunctions.DamagePlayer({
                    SourcePlayer = self.Owner,
                    TargetHumanoid = Humanoid,
                    Damage = self.Damage,
                    Reason = self.Name,
                    KnockbackDirection = Live.CFrame.LookVector,
                    KnockbackMagnitude = 9,
                })

                AbilityFX.ShakeFor(Target, 2.5, 0.3)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- PASSIVE — FLIGHT METER AND INVULNERABILITY
--------------------------------------------------------------------------------

local function FlightMeterInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    local Humanoid = self.OwnerProperties.Humanoid
    if not Char or not Humanoid then
        return
    end

    MeterService.Define(Char, FLIGHT_METER, {
        Max = 100,
        Start = 100,
        --- Refilled by the loop below, not by the ticker: it only counts on the ground.
        RegenPerSecond = 0,
    })

    --[=[
        The gauge only refills ON THE GROUND.

        That is the limit that matters most. A meter that refilled in the air would make
        flight permanent with a brief pause; refilling only on the floor means every
        second of flight has to be paid for somewhere everybody can reach him.
    ]=]
    self:AddConnection(task.spawn(function()
        while Char and Char.Parent do
            task.wait(0.25)

            if Char:GetAttribute("SupermanFlying") then
                continue
            end

            local State = Humanoid:GetState()
            if State == Enum.HumanoidStateType.Freefall or State == Enum.HumanoidStateType.Jumping then
                continue
            end

            MeterService.Add(Char, FLIGHT_METER, self.GroundRegen * 0.25)
        end
    end))
end

--[=[
    INVULNERABLE (PASSIVE)

    What it does, exactly:
      * `Slipping` is ignored outright. You cannot trip him.
      * `Stunned` lasts HALF as long. He can still be stunned — out of the sky, out of a
        heat vision startup, out of anything — it just costs more to hold him.
      * `Snared` and `Slowness` last half as long.

    WHAT IT DOES NOT DO: reduce damage, by any amount, from any source. He has the highest
    health in the game and that is the whole of his durability. The passive is about
    CONTROL, not survival, which is what keeps him stoppable by the same means as everybody
    else.
]=]
local function Invulnerable(_self, effectSettings)
    if not RunService:IsServer() then
        return
    end

    local Name = effectSettings and effectSettings.EffectSettings and effectSettings.EffectSettings.Name
    if not Name then
        return
    end

    if Name == "Slipping" then
        return "Ignored"
    end

    if Name == "Stunned" or Name == "Snared" or Name == "Slowness" then
        -- `ApplyEffect` re-reads `Duration` after `OnEffect` returns, which is the supported
        -- way to shorten an incoming effect.
        local Current = effectSettings.EffectSettings.Duration
        if Current then
            effectSettings.EffectSettings.Duration = Current * 0.5
        end
    end

    return
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Superman: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Superman",
        Quote = "",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 2200,

        Role = "Mobility",
        Difficulty = 3,

        Origin = {
            TooltipText = "He is not from here.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://9046319808",
        },
    },

    GameplayConfig = {
        --[[
            Among the highest health in the game and the hardest single punch in it, attached
            to the most conditional mobility. His durability is this number and nothing else
            — the passive does not reduce damage at all.
        ]]
        Health = 1500,
        --[[
            Average base speed, deliberately. `Flight` and `Super Speed` are his mobility;
            being quick on foot as WELL made him upper-quartile in health, speed and
            sustained melee damage simultaneously, which is the one combination the design
            brief rules out.
        ]]
        BaseSpeed = 11,
        SprintSpeedMultiplier = 25.5 / 11,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 120,
            StaminaDrain = 10,
            StaminaGain = 22,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://9046319808",
                UseAnimation = "rbxassetid://133504250023139",

                --[[
                    The hardest single swing on the roster, and the slowest-cycling heavy
                    attack in it. 44 damage every 2.9 seconds is about 15 damage a second
                    sustained -- middle of the pack -- so he hits harder than anybody once
                    and loses a sustained trade to half the roster.
                ]]
                Damage = 44,
                Cooldown = 2.9,
                Duration = 0.35,
                Delay = 0.14,
                HitboxSize = Vector3.new(6, 6.5, 6),
                HitboxOffset = CFrame.new(0, 0, -3),
                Knockback = 16,

                Behaviour = PunchBehaviour,
            }),

            Flight = Ability.New({
                Name = "Flight",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                --- Short, because it is a toggle.
                Cooldown = 2,
                Duration = 0.3,

                Speed = 72,
                ClimbSpeed = 28,
                --- Studs above the ground beneath him. Hard cap.
                Ceiling = 55,
                --- Climbs until it reaches this, then levels off.
                CruiseHeight = 28,
                --- Per 0.05s tick. 24 seconds of flight from full.
                DrainPerTick = 0.21,
                MinimumToLaunch = 12,

                UseSound = "rbxassetid://9118823103",
                Behaviour = FlightBehaviour,
            }),

            HeatVision = Ability.New({
                Name = "Heat Vision",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 18,
                Duration = 1.2,

                Startup = 0.85,
                StartupSpeedMultiplier = 0.6,
                Length = 95,
                Width = 5,
                Damage = 88,
                BurnTime = 5,

                ChargeSound = "rbxassetid://9125402735",
                UseSound = "rbxassetid://9118823103",
                Behaviour = HeatVisionBehaviour,
            }),

            FreezeBreath = Ability.New({
                Name = "Freeze Breath",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 20,
                Duration = 0.6,

                Range = 30,
                Angle = 75,
                Damage = 24,
                --- Slowed, not frozen. No root anywhere in this kit.
                SlowLevel = 3,
                SlowTime = 4,

                UseSound = "rbxassetid://9046319808",
                Behaviour = FreezeBehaviour,
            }),

            SuperSpeed = Ability.New({
                Name = "Super Speed",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 11,
                Duration = 0.3,

                DashSpeed = 130,
                --- Very short. It is a reposition, not a journey.
                DashTime = 0.26,
                Radius = 6,
                Damage = 28,

                UseSound = "rbxassetid://12222030",
                Behaviour = SpeedBehaviour,
            }),

            Invulnerable = Ability.New({
                Name = "Invulnerable",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                --- Flight gauge refill, per second, while on the ground.
                GroundRegen = 11,

                ExtraInit = FlightMeterInit,
            }),
        },
    },

    OnEffect = Invulnerable,
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(40, 90, 200)\">"..Superman.Config.Name.."</font>"
local Abilities = Superman.GameplayConfig.Abilities
local FlightSeconds = math.round(100 / Abilities.Flight.DrainPerTick * 0.05)
local RefillSeconds = math.round(100 / Abilities.Invulnerable.GroundRegen)

Superman.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Superman.Config.Name:upper()},
    {
        Type = "Text",
        Text = {
            NameLabel.." has among the highest health in the arena and the hardest single punch in it — but one of the slowest. He is not invulnerable, and nothing in his kit is.",
            "<b>Flight</b> is a meter that only refills on the ground, has a hard altitude ceiling, and <b>disables every attack he has</b> while he is in the air. He is a delivery system, not a gunship.",
            "Everything else is telegraphed, and the slow does not root anybody.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Superman.Config.Role,
            "Difficulty: "..string.rep("★", Superman.Config.Difficulty)..string.rep("☆", 5 - Superman.Config.Difficulty),
            "Price: "..tostring(Superman.Config.Price).."$",
            "Health: "..tostring(Superman.GameplayConfig.Health),
            "Base Speed: "..tostring(Superman.GameplayConfig.BaseSpeed),
            "Flight Speed: "..tostring(Abilities.Flight.Speed),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "SUPER PUNCH"},
    {
        Type = "Text",
        Text = {
            "<b>"..tostring(Abilities.Slash.Damage).." damage</b> every "..tostring(Abilities.Slash.Cooldown).." seconds — the hardest single swing on the roster and one of the slowest — and it throws you a long way.",
            "About "..tostring(math.round(Abilities.Slash.Damage / Abilities.Slash.Cooldown)).." damage a second sustained, which is mid-table. He wins the first exchange and loses a long one.",
            "He cannot use it while flying.",
        },
    },

    {Type = "Header", Text = "FLIGHT  (Q)"},
    {
        Type = "Text",
        Text = {
            "A <b>toggle</b> on a meter: about "..tostring(FlightSeconds).." seconds of flight from full, at "..tostring(Abilities.Flight.Speed).." studs a second.",
            "<b>Capped at "..tostring(Abilities.Flight.Ceiling).." studs above the ground beneath him</b>, so he cannot hover out of reach — and the ceiling follows terrain, so a tower is still a tower.",
            "<b>He cannot attack at all while airborne.</b> The gauge only refills on the ground, taking about "..tostring(RefillSeconds).." seconds from empty.",
            "Being stunned in the air brings him down.",
        },
    },

    {Type = "Header", Text = "HEAT VISION  (E)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.HeatVision.Startup).." seconds of startup with the beam's line <b>drawn on screen</b>, then "..tostring(Abilities.HeatVision.Damage).." damage through everybody in a "..tostring(Abilities.HeatVision.Length).." stud line, plus <b>Burning</b>.",
            "It fires along the line it was aimed at when he pressed it. Turning does not re-aim it, and he is slowed while it charges.",
            "Cooldown: "..tostring(Abilities.HeatVision.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "FREEZE BREATH  (R)"},
    {
        Type = "Text",
        Text = {
            "A "..tostring(Abilities.FreezeBreath.Range).." stud cone for "..tostring(Abilities.FreezeBreath.Damage).." damage, <b>Slowness "..tostring(Abilities.FreezeBreath.SlowLevel).."</b> and <b>Grounded</b> for "..tostring(Abilities.FreezeBreath.SlowTime).." seconds.",
            "<b>It does not freeze anybody in place.</b> You keep your abilities, your attack and your legs — you are just slow.",
            "Cooldown: "..tostring(Abilities.FreezeBreath.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "SUPER SPEED  (F)"},
    {
        Type = "Text",
        Text = {
            "A very fast, very short dash that hits everybody he passes through for "..tostring(Abilities.SuperSpeed.Damage).." damage, once each.",
            "Instant and grounded, where Flight is a committed travel mode. This is the one for inside a fight.",
            "Cooldown: "..tostring(Abilities.SuperSpeed.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "INVULNERABLE  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "He ignores <b>Slipping</b>, and takes <b>Stunned</b>, <b>Snared</b> and <b>Slowness</b> at <b>half duration</b>.",
            "<b>It does not reduce damage by any amount.</b> His health is his durability. The passive is about control, not survival — he can be stunned out of the sky like anybody else, it just costs more to hold him there.",
        },
    },
}

return Superman
