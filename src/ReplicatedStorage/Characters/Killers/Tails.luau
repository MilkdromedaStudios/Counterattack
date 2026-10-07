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
local DeployableService = require(ReplicatedStorage.Modules.DeployableService)
local MeterService = require(ReplicatedStorage.Modules.MeterService)
local ProjectileService = require(ReplicatedStorage.Modules.ProjectileService)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

--[=[
    TAILS — TECHNOLOGY AND ALTITUDE, NOT STRENGTH.

      M1  TAIL SPIN   A spin that hits all round him. Weak, fast, and it hits in the air.
      Q   FLY         A meter-limited hover. He can fight while flying, slowly.
      E   GADGET SHOT A small homing projectile. His only reliable damage.
      R   DRONE       A deployable that scans and shoots. The real output.
      F   WHIRLWIND   A short-range knockback. His only answer to being cornered.
      P   WORKSHOP    His drone comes back faster, and gadget shots recharge the meter.

    HOW HE IS DIFFERENT FROM SUPERMAN
    ---------------------------------
    They both fly, so the distinction is total:

      * Superman CANNOT ATTACK while flying and his flight is fast and committed. It is a
        delivery system.
      * Tails CAN attack while flying, but the flight is slow and he is a soft target up
        there. It is a FIRING POSITION.

    So Superman flies to arrive and Tails flies to shoot, and the two never feel the same
    despite both being "a flight toggle on a meter".

    HE IS A SUPPORT CHARACTER WITHOUT A TEAM
    ---------------------------------------
    Lowest basic-attack damage in the game and no burst anywhere. His damage comes from the
    DRONE, which means his power is in setup and position rather than in anything he does
    directly. A Tails who has a drone up, altitude, and a meter is dangerous; a Tails caught
    on the floor with a dead drone is the weakest thing in the arena.

    WEAKNESSES
    ----------
    1050 health. The drone is a destructible object that any attack kills. The flight is
    slow and makes him an easy target. `Whirldwind` is his only defensive tool and it does
    almost no damage.
]=]

local TAILS = Color3.fromRGB(235, 160, 60)
local TECH = Color3.fromRGB(120, 200, 255)
local FLIGHT_METER = "Flight"

--------------------------------------------------------------------------------
-- M1 — TAIL SPIN
--------------------------------------------------------------------------------

--[=[
    A spin that hits everything around him.

    Weakest basic attack in the game, and the only one that works identically in the air —
    which matters, because he is the only character expected to be fighting from up there.
    It is omnidirectional, so it needs no aim while hovering.
]=]
local function SpinBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.2, Lock = 0.3})
        return
    end

    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.55, MinPitch = 1.2, MaxPitch = 1.4})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        AbilityFX.Ring(Root.Position, 6, TAILS, {Duration = 0.25, Thickness = 0.5})

        Hitbox.New(self.Owner, {
            -- No offset: it is centred on him, so it hits all round.
            CFrameOffset = CFrame.new(),
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Tail Spin",
            ExecuteOnKill = true,
            Knockback = 4,
            HitMultiple = true,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, TAILS, 6, 12)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — FLY
--------------------------------------------------------------------------------

--[=[
    A slow hover on a meter. He keeps everything.

    Three limits, same shape as Superman's but tuned the opposite way:
      * SLOW. Half Superman's airspeed, because it is a firing position rather than travel.
      * CAPPED ALTITUDE, measured from the ground beneath him so it follows terrain.
      * A METER that drains while airborne and refills on the ground — and, uniquely,
        REFILLS A LITTLE FROM EVERY GADGET SHOT THAT LANDS, which is the `Workshop` passive.
        That is what lets a Tails who is hitting his shots stay up almost indefinitely, and
        drops one who is missing straight back to the floor.
]=]
local function FlyBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        local Char = self.OwnerProperties.Character
        if Char and Char:GetAttribute("TailsFlying") then
            AbilityClient.ReleaseZoom(self)
        else
            AbilityClient.Zoom(self, 1.12)
        end
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    ----------------------------------------------------------------------------
    -- LAND
    ----------------------------------------------------------------------------

    if Char:GetAttribute("TailsFlying") then
        Char:SetAttribute("TailsFlying", false)
        return
    end

    ----------------------------------------------------------------------------
    -- TAKE OFF
    ----------------------------------------------------------------------------

    if MeterService.Get(Char, FLIGHT_METER) < self.MinimumToLaunch then
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "too tired", TAILS, 1)
        return
    end

    Char:SetAttribute("TailsFlying", true)

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.7, MinPitch = 1.1, MaxPitch = 1.25})

    task.spawn(function()
        local Spin = 0

        while Char and Char.Parent and Char:GetAttribute("TailsFlying") do
            local Step = task.wait(0.05)
            Spin += Step

            local Live = Utils.Character.GetRootPart(Char)
            local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
            if not Live or not Humanoid or Humanoid.Health <= 0 then
                break
            end

            -- Stunned in the air: he drops.
            if Char.Effects and Char.Effects:FindFirstChild("Stunned") then
                break
            end

            if not MeterService.Spend(Char, FLIGHT_METER, self.DrainPerTick) then
                AbilityFX.Text(Live.Position + Vector3.new(0, 5, 0), "out of lift", TAILS, 1.1)
                break
            end

            ----------------------------------------------------------------
            -- ALTITUDE
            ----------------------------------------------------------------

            local Ground = AbilityFX.GroundAt(Live.Position, {Char, workspace.Players}, self.Ceiling + 40)
            local Altitude = Ground and (Live.Position.Y - Ground.Y) or 0

            local Vertical
            if Altitude >= self.Ceiling then
                Vertical = math.min(Live.AssemblyLinearVelocity.Y, 0)
            elseif Altitude < self.CruiseHeight then
                Vertical = self.ClimbSpeed
            else
                Vertical = 0
            end

            local Forward = Live.CFrame.LookVector

            Live.AssemblyLinearVelocity = Vector3.new(
                Forward.X * self.Speed,
                Vertical,
                Forward.Z * self.Speed
            )

            -- The tails themselves, spinning.
            if Spin >= 0.1 then
                Spin = 0
                AbilityFX.Burst(Live.Position - Vector3.new(0, 1, 0), 3, TAILS, {
                    Duration = 0.2,
                    StartSize = 2.5,
                    Transparency = 0.75,
                })
                AbilityFX.Sound(self.LoopSound, Live.Position, {
                    Volume = 0.25,
                    MinPitch = 1.4,
                    MaxPitch = 1.6,
                    RollOffMaxDistance = 80,
                })
            end
        end

        if Char then
            Char:SetAttribute("TailsFlying", false)
        end
    end)
end

--------------------------------------------------------------------------------
-- E — GADGET SHOT
--------------------------------------------------------------------------------

--[=[
    A small homing device.

    It CURVES toward the nearest fighter rather than snapping onto them — `Homing.Strength`
    is low enough that out-running the turn or breaking the line works. It is his only
    reliable damage and it is modest, because what it is really for is the `Workshop`
    passive: a shot that lands puts lift back in the tank.

    So his gameplay loop is: get altitude, hit shots to stay up, and let the drone do the
    killing.
]=]
local function GadgetBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.98, Duration = 0.25, Lock = 0.3})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.7, MinPitch = 1.15, MaxPitch = 1.3})

    local Muzzle = Root.Position + Root.CFrame.LookVector * 2.5 + Vector3.new(0, 1, 0)
    local Target = CombatUtils.GetClosestFighter(Root.Position, self.Range, Char)

    ProjectileService.Fire({
        SourcePlayer = self.Owner,
        Name = "Gadget",
        Origin = Muzzle,
        Direction = Root.CFrame.LookVector,
        Speed = self.Speed,
        Lifetime = self.Range / self.Speed,
        Radius = 2,
        Damage = self.Damage,
        Reason = self.Name,
        FaceTravel = true,
        Spin = 180,
        --- Low strength: it curves, it does not lock on.
        Homing = Target and {Target = Target, Strength = self.HomingStrength} or nil,
        Visual = {
            Shape = Enum.PartType.Block,
            Size = Vector3.new(1.2, 1.2, 2.2),
            Color = TECH,
            Material = Enum.Material.Metal,
            Trail = true,
            TrailColor = TECH,
            Light = true,
            LightRange = 10,
        },
        OnHit = function(_projectile, humanoid: Humanoid)
            local Victim = humanoid.Parent
            local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
            if VictimRoot then
                AbilityFX.Burst(VictimRoot.Position, 5, TECH, {Duration = 0.3})
                AbilityFX.Sparks(VictimRoot.Position, TECH, 10, 18)
            end

            --[[
                WORKSHOP: a shot that lands puts lift back.

                It is here rather than in the passive's own loop because this is the only
                place that knows the shot connected, and tying the reward to a HIT is the
                whole mechanic. Missing pays nothing.
            ]]
            MeterService.Add(Char, FLIGHT_METER, self.LiftPerHit)

            return nil
        end,
        OnImpact = function(_projectile, position: Vector3)
            AbilityFX.Sparks(position, TECH, 8, 14)
        end,
    })
end

--------------------------------------------------------------------------------
-- R — DRONE
--------------------------------------------------------------------------------

--[=[
    A drone. His real damage.

    It hovers where it was placed and does two things on a slow tick:
      * REVEALS everybody within its scan radius to Tails, which is the information half.
      * SHOOTS the nearest fighter it can see, through `DeployableService.TurretTick` —
        the same helper Builderman's sentry uses, because both want "find the nearest
        fighter who isn't my owner and shoot if I can see them" and only the projectile
        differs.

    It is destructible and it is the single most important thing in his kit, which is the
    whole counterplay: break the drone and he is a 1050 health character with a spin attack.
]=]
local function DroneBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.05, Duration = 0.4, Lock = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Spot = Root.Position + Root.CFrame.LookVector * 6 + Vector3.new(0, 7, 0)

    AbilityFX.Sound(self.UseSound, Spot, {Volume = 0.8, MinPitch = 1.1, MaxPitch = 1.25})

    local Drone = DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Drone",
        Name = "Drone",
        CFrame = CFrame.new(Spot),
        Size = Vector3.new(3, 1.6, 3),
        Color = TECH,
        Material = Enum.Material.Metal,
        Solid = false,
        Health = self.DroneHealth,
        Lifetime = self.DroneLifetime,
        Limit = 1,
        TickRate = 0.25,
        OutlineColor = TECH,
        OnTick = function(handle)
            ----------------------------------------------------------------
            -- SCAN
            ----------------------------------------------------------------

            if not handle.State.NextScan or os.clock() >= handle.State.NextScan then
                handle.State.NextScan = os.clock() + self.ScanInterval

                local Spotted = false
                for _, Target: Model in CombatUtils.GetFightersInRadius(handle.Root.Position, self.ScanRadius, Char) do
                    Spotted = true
                    Utils.Player.RevealPlayerAuraTo(self.Owner, Target, self.RevealTime, TECH)
                end

                if Spotted then
                    AbilityFX.Ring(handle.Root.Position, self.ScanRadius, TECH, {
                        Duration = 0.6,
                        Transparency = 0.86,
                    })
                end
            end

            ----------------------------------------------------------------
            -- SHOOT
            ----------------------------------------------------------------

            DeployableService.TurretTick(handle, {
                Range = self.ShootRange,
                Interval = self.FireInterval,
                RequireLineOfSight = true,
                Fire = function(turret, _target, targetRoot)
                    local Muzzle = turret.Root.Position - Vector3.new(0, 0.8, 0)

                    ProjectileService.Fire({
                        SourcePlayer = self.Owner,
                        Name = "DroneShot",
                        Origin = Muzzle,
                        Direction = (targetRoot.Position - Muzzle),
                        Speed = 140,
                        Lifetime = self.ShootRange / 140,
                        Radius = 1.4,
                        Damage = self.ShotDamage,
                        Reason = "Drone",
                        Visual = {
                            Shape = Enum.PartType.Ball,
                            Size = Vector3.new(0.7, 0.7, 0.7),
                            Color = TECH,
                            Material = Enum.Material.Neon,
                            Trail = true,
                            TrailColor = TECH,
                        },
                    })

                    AbilityFX.Sparks(Muzzle, TECH, 4, 10)
                    AbilityFX.Sound("rbxassetid://12222030", Muzzle, {Volume = 0.3, MinPitch = 1.3, MaxPitch = 1.5})
                end,
            })
        end,
        OnDestroyed = function(handle)
            AbilityFX.Shockwave(handle.Root.Position, 6, TECH, 16)
            AbilityFX.Smoke(handle.Root.Position, Color3.fromRGB(60, 60, 60), 12, 3)
        end,
    })

    if Drone then
        -- A bobbing hover, and rotors.
        local Base = Drone.Root.Position

        task.spawn(function()
            local Elapsed = 0
            while Drone.Alive and Drone.Root and Drone.Root.Parent do
                Elapsed += task.wait(0.06)
                -- `TurretTick` rotates the root to face its target, so only the height is
                -- animated here — overwriting the whole CFrame would fight it.
                Drone.Root.Position = Base + Vector3.new(0, math.sin(Elapsed * 3) * 0.8, 0)
            end
        end)

        AbilityFX.Attach(Drone.Root, {
            Color = ColorSequence.new(TECH),
            Rate = 12,
            Speed = NumberRange.new(1, 3),
            Size = NumberSequence.new(0.5),
            Lifetime = NumberRange.new(0.2, 0.4),
        })
    end
end

--------------------------------------------------------------------------------
-- F — WHIRLWIND
--------------------------------------------------------------------------------

--[=[
    A short-range knockback. His only defensive tool.

    Almost no damage. What it does is throw everybody around him clear and leave them
    `Slipping`, which buys the two seconds he needs to get airborne or get the drone back up.

    It also clears projectiles out of the air around him, which is a real defensive option
    against the roster's four shooting characters and costs them a cooldown.
]=]
local function WhirlwindBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.15, Duration = 0.5, Shake = 1.5, ShakeTime = 0.3})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 0.9, MinPitch = 1.0, MaxPitch = 1.15})
    AbilityFX.Ring(Origin, self.Radius, TAILS, {Duration = 0.5, Thickness = 1.2})
    AbilityFX.Smoke(Origin, Color3.fromRGB(230, 220, 200), 14, 3)

    -- Spiralling debris, so it reads as a vortex rather than a shockwave.
    for Index = 1, 10 do
        local Angle = (Index / 10) * math.pi * 2
        AbilityFX.Beam(
            Origin + Vector3.new(math.cos(Angle) * 2, 1, math.sin(Angle) * 2),
            Origin + Vector3.new(math.cos(Angle + 1.2) * self.Radius, 2, math.sin(Angle + 1.2) * self.Radius),
            TAILS,
            {Width = 0.4, Duration = 0.35, Transparency = 0.5}
        )
    end

    ----------------------------------------------------------------------------
    -- PEOPLE
    ----------------------------------------------------------------------------

    for _, Target: Model in CombatUtils.GetFightersInRadius(Origin, self.Radius, Char) do
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
            KnockbackDirection = ((TargetRoot.Position - Origin).Magnitude > 0
                and (TargetRoot.Position - Origin).Unit
                or Vector3.xAxis) + Vector3.new(0, 0.5, 0),
            KnockbackMagnitude = self.Knockback,
        })

        CombatUtils.ApplyEffectTo(Target, "Slipping", 1, 0.6)
        AbilityFX.ScreenFor(Target, "Woozy", 0.7, 0.8)
    end

    ----------------------------------------------------------------------------
    -- PROJECTILES
    ----------------------------------------------------------------------------

    local Scattered = ProjectileService.Consume(Origin, self.Radius, self.Owner)
    if Scattered > 0 then
        AbilityFX.Text(Origin + Vector3.new(0, 5, 0), "scattered "..tostring(Scattered), TECH, 1)
    end
end

--------------------------------------------------------------------------------
-- PASSIVE — WORKSHOP
--------------------------------------------------------------------------------

local function WorkshopInit(self: Types.Ability)
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
        RegenPerSecond = 0,
    })

    --[=[
        Refills on the ground, and much faster than Superman's.

        He is expected to be taking off and landing constantly rather than making one long
        committed flight, so the gauge is designed to be topped up in short visits to the
        floor — and the `Gadget Shot` bonus means a Tails who is hitting his shots barely
        needs the floor at all.
    ]=]
    self:AddConnection(task.spawn(function()
        while Char and Char.Parent do
            task.wait(0.25)

            if Char:GetAttribute("TailsFlying") then
                continue
            end

            local State = Humanoid:GetState()
            if State == Enum.HumanoidStateType.Freefall or State == Enum.HumanoidStateType.Jumping then
                continue
            end

            MeterService.Add(Char, FLIGHT_METER, self.GroundRegen * 0.25)
        end
    end))

    --[=[
        The drone's cooldown is shortened while he has no drone out.

        A `CooldownMultiplier` would affect everything, so instead this watches the drone
        ability directly and knocks its remaining timer down — which gets a Tails whose drone
        has just been destroyed back into the fight, without making a Tails whose drone is
        alive able to spam them.
    ]=]
    self:AddConnection(task.spawn(function()
        local Drone = self.CharModule.GameplayConfig.Abilities.Drone

        while Char and Char.Parent do
            task.wait(1)

            if not Drone or not Drone.OnCooldown then
                continue
            end

            if #DeployableService.GetFor(self.Owner, "Drone") > 0 then
                continue
            end

            -- One extra second off per second, so a destroyed drone comes back twice as
            -- fast as a timed-out one.
            Drone.CooldownTimer = math.max(Drone.CooldownTimer - 1, 0)
            if Drone.CooldownTimer <= 0 then
                Drone.OnCooldown = false
            end
        end
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Tails: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Tails",
        Quote = "I can do this!",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 6200,

        Role = "Ranged",
        Difficulty = 4,

        Origin = {
            TooltipText = "He built most of it himself.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            Low health, the weakest basic attack in the game, and no burst anywhere. His
            damage comes from the drone, which means his power is in setup and position.
        ]]
        Health = 1050,
        BaseSpeed = 11.6,
        SprintSpeedMultiplier = 26.5 / 11.6,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 105,
            StaminaDrain = 10,
            StaminaGain = 23,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222030",
                UseAnimation = "rbxassetid://133504250023139",

                --- Weakest basic attack on the roster.
                Damage = 15,
                Cooldown = 1.2,
                Duration = 0.24,
                Delay = 0.06,
                --- Centred on him, so it needs no aim in the air.
                HitboxSize = Vector3.new(9, 6, 9),

                Behaviour = SpinBehaviour,
            }),

            Fly = Ability.New({
                Name = "Fly",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 2,
                Duration = 0.3,

                --- Half Superman's airspeed. It is a firing position, not travel.
                Speed = 36,
                ClimbSpeed = 22,
                Ceiling = 45,
                CruiseHeight = 22,
                --- Per 0.05s tick. About 20 seconds from full.
                DrainPerTick = 0.25,
                MinimumToLaunch = 10,

                UseSound = "rbxassetid://12222030",
                LoopSound = "rbxassetid://12222030",
                Behaviour = FlyBehaviour,
            }),

            Gadget = Ability.New({
                Name = "Gadget",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 4,
                Duration = 0.3,

                Damage = 26,
                Speed = 115,
                Range = 110,
                --- Low: it curves, it does not lock on.
                HomingStrength = 1.6,
                --- Lift returned per shot that LANDS. The Workshop passive.
                LiftPerHit = 9,

                UseSound = "rbxassetid://12222030",
                Behaviour = GadgetBehaviour,
            }),

            Drone = Ability.New({
                Name = "Drone",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 26,
                Duration = 0.4,

                DroneHealth = 55,
                DroneLifetime = 32,
                ScanRadius = 60,
                ScanInterval = 2,
                RevealTime = 3,
                ShootRange = 50,
                FireInterval = 1.1,
                ShotDamage = 11,

                UseSound = "rbxassetid://12222216",
                Behaviour = DroneBehaviour,
            }),

            Whirlwind = Ability.New({
                Name = "Whirlwind",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 14,
                Duration = 0.5,

                Radius = 16,
                --- Almost nothing. The knockback is the ability.
                Damage = 14,
                Knockback = 20,

                UseSound = "rbxassetid://9046319808",
                Behaviour = WhirlwindBehaviour,
            }),

            Workshop = Ability.New({
                Name = "Workshop",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                GroundRegen = 16,

                ExtraInit = WorkshopInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(235, 160, 60)\">"..Tails.Config.Name.."</font>"
local Abilities = Tails.GameplayConfig.Abilities
local FlightSeconds = math.round(100 / Abilities.Fly.DrainPerTick * 0.05)

Tails.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Tails.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Tails.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." has the weakest basic attack in the arena and no burst anywhere. <b>His damage comes from the drone.</b>",
            "He can fight while flying, unlike Superman — but the flight is slow and he is a soft target up there. It is a firing position, not a way of getting around.",
            "A Tails with a drone up, altitude and a full gauge is dangerous. One caught on the floor with a dead drone is the weakest thing here.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Tails.Config.Role,
            "Difficulty: "..string.rep("★", Tails.Config.Difficulty)..string.rep("☆", 5 - Tails.Config.Difficulty),
            "Price: "..tostring(Tails.Config.Price).."$",
            "Health: "..tostring(Tails.GameplayConfig.Health),
            "Base Speed: "..tostring(Tails.GameplayConfig.BaseSpeed),
            "Flight Speed: "..tostring(Abilities.Fly.Speed),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "TAIL SPIN"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds, <b>all the way around him</b>.",
            "The weakest attack in the game, and the only one that works identically in the air — it needs no aim while hovering.",
        },
    },

    {Type = "Header", Text = "FLY  (Q)"},
    {
        Type = "Text",
        Text = {
            "A <b>toggle</b>: about "..tostring(FlightSeconds).." seconds of slow hovering from full, capped at "..tostring(Abilities.Fly.Ceiling).." studs above the ground beneath him.",
            "<b>He keeps every ability while flying</b>, which Superman does not — but at "..tostring(Abilities.Fly.Speed).." studs a second he is a slow, obvious target.",
            "Being stunned brings him down.",
        },
    },

    {Type = "Header", Text = "GADGET  (E)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Gadget.Damage).." damage, and it <b>curves</b> toward the nearest fighter rather than locking on. Out-running the turn or breaking the line works.",
            "<b>Every shot that lands puts "..tostring(Abilities.Gadget.LiftPerHit).." back in the flight gauge.</b> Missing pays nothing. A Tails who is hitting his shots barely needs the ground.",
            "Cooldown: "..tostring(Abilities.Gadget.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "DRONE  (R)"},
    {
        Type = "Text",
        Text = {
            "A hovering drone with "..tostring(Abilities.Drone.DroneHealth).." health, lasting "..tostring(Abilities.Drone.DroneLifetime).." seconds. One at a time.",
            "It <b>reveals</b> everybody within "..tostring(Abilities.Drone.ScanRadius).." studs to him every "..tostring(Abilities.Drone.ScanInterval).." seconds, and <b>shoots</b> whoever it can see for "..tostring(Abilities.Drone.ShotDamage).." damage every "..tostring(Abilities.Drone.FireInterval)..".",
            "<b>It is his real damage, and it dies to almost anything.</b> Breaking it is the counterplay.",
            "Cooldown: "..tostring(Abilities.Drone.Cooldown).." seconds — halved while he has no drone out.",
        },
    },

    {Type = "Header", Text = "WHIRLWIND  (F)"},
    {
        Type = "Text",
        Text = {
            "Only "..tostring(Abilities.Whirlwind.Damage).." damage, but it throws everybody within "..tostring(Abilities.Whirlwind.Radius).." studs clear and leaves them <b>Slipping</b>.",
            "<b>It also scatters every projectile in the air around him</b>, which is a real answer to the roster's shooters.",
            "His only defensive tool.",
            "Cooldown: "..tostring(Abilities.Whirlwind.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "WORKSHOP  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "The flight gauge refills quickly on the ground, and <b>gadget shots that land refill it in the air</b>.",
            "His drone also comes back twice as fast when he does not have one out, so losing it is a setback rather than a write-off.",
        },
    },
}

return Tails
