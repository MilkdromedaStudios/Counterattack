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

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    FALL GUY — PHYSICS, NOT HORROR.

      M1  GRAB            A two-handed shove. Low damage, real knockback, trips people up.
      Q   DIVE            A full-body dive. Travels, lands hard, and he bounces afterwards.
      E   GRAB & SHOVE    Picks somebody up, carries them a short way, and throws them.
      R   OBSTACLE DROP   Drops one of three game-show obstacles. Cycles through them.
      P   BOUNCY          Shrugs off knockback and gets back up faster than he should.

    DELIBERATELY NO SUPERNATURAL ANYTHING
    -------------------------------------
    The brief was explicit and it is the right call: everything he does is a physical
    interaction. He pushes, he dives, he carries, he puts a spinning bar in your way. No
    marks, no auras, no reveals, no magic.

    That makes him the roster's DISRUPTOR — the character whose job is to make the fight
    happen somewhere other than where you wanted it. His raw damage is among the lowest in
    the game and his `Slipping` applications are among the most frequent.

    `Slipping`, NOT A STUN. Everything he inflicts uses the `Slipping` effect: three
    quarters of a second of being slow and unable to sprint, while keeping your abilities
    and your attack. Comedy that takes away your control is not funny — it is a window in
    which you watch yourself die. This is funny AND dangerous.

    THE GRAB CANNOT BE CHAINED
    --------------------------
    One second of carry, a hard cooldown, and he moves at 70% speed while holding somebody.
    The victim keeps every ability and can hit him the whole time. It repositions a fight;
    it does not remove a player from one.
]=]

local BEAN = Color3.fromRGB(255, 125, 170)
local BEAN_DARK = Color3.fromRGB(180, 70, 110)

--------------------------------------------------------------------------------
-- M1 — GRAB
--------------------------------------------------------------------------------

local function ShoveBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.2, Lock = 0.4})
        return
    end

    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.55, MinPitch = 1.1, MaxPitch = 1.3})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Shove",
            ExecuteOnKill = true,
            Knockback = self.Knockback,
            HitMultiple = true,
            EffectsToApply = {
                {Name = "Slipping", Level = 1, Duration = 0.5, OverwriteExisting = true},
            },
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Burst(VictimRoot.Position, 4, BEAN, {Duration = 0.2})
                        AbilityFX.ScreenFor(Victim, "Woozy", 0.5, 0.6)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — DIVE
--------------------------------------------------------------------------------

--[=[
    The dive.

    This is where his movement is DIFFERENT from every other dash on the roster, which was
    the explicit brief. It is not a horizontal shove along the ground:

      * It launches him UP as well as forward, so it is an arc with real air time.
      * It damages on LANDING, not on cast — so where he lands is the decision, and the
        flight is committed.
      * He is low to the ground for the whole thing, which on maps with low openings means
        he goes under things.
      * It leaves him `Slipping` HIMSELF for a moment on landing. He is a bean; he does not
        land gracefully. That self-inflicted recovery is the cost of the distance.

    The landing hits everyone around the impact and slips them, which is what makes it an
    engage rather than a dodge.
]=]
local function DiveBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.22, Duration = self.Airtime, Lock = self.Airtime + 0.3})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.8, MinPitch = 1.0, MaxPitch = 1.15})
    AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "whee", BEAN, 0.9)

    --[[
        Direct velocity rather than `CombatUtils.Dash`.

        `Dash` applies a horizontal `LinearVelocity`, which is right for a ground dash and
        wrong for a dive: there would be no arc at all. Setting the assembly velocity
        directly gives it the vertical kick, and the physics engine handles the rest — which
        also means it interacts properly with slopes and ledges.
    ]]
    Root.AssemblyLinearVelocity = Root.CFrame.LookVector * self.Power + Vector3.new(0, self.Lift, 0)

    -- A trail for the flight, so the arc is legible from outside.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Airtime and Char and Char.Parent do
            Elapsed += task.wait(0.06)
            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                AbilityFX.Burst(Live.Position, 2.5, BEAN, {Duration = 0.25, StartSize = 1.5, Transparency = 0.7})
            end
        end
    end)

    ----------------------------------------------------------------------------
    -- THE LANDING
    ----------------------------------------------------------------------------

    task.delay(self.Airtime, function()
        if not Char or not Char.Parent then
            return
        end

        local Live = Utils.Character.GetRootPart(Char)
        if not Live then
            return
        end

        local Origin = Live.Position

        AbilityFX.Sound(self.LandSound, Origin, {Volume = 0.9, MinPitch = 0.9, MaxPitch = 1.05})
        AbilityFX.Ring(Origin, self.Radius, BEAN, {Duration = 0.45, Thickness = 1})
        AbilityFX.Smoke(Origin, Color3.fromRGB(230, 220, 210), 12, 3)
        AbilityFX.ShakeInRadius(Origin, self.Radius * 2, 2.5, 0.4)

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
                KnockbackDirection = (TargetRoot.Position - Origin).Magnitude > 0
                    and (TargetRoot.Position - Origin).Unit
                    or Vector3.yAxis,
                KnockbackMagnitude = self.Knockback,
            })

            CombatUtils.ApplyEffectTo(Target, "Slipping", 2, 0.75)
            AbilityFX.ScreenFor(Target, "Woozy", 0.9, 1)
        end

        --[[
            And he slips too.

            Not a bug. The dive covers a lot of ground for a 10 second cooldown, and the
            half second of being slow on the other end is what stops it being a free
            disengage as well as a free engage.
        ]]
        CombatUtils.ApplyEffectTo(Char, "Slipping", 1, self.Recovery)
        AbilityFX.Text(Origin + Vector3.new(0, 4, 0), "oof", BEAN_DARK, 0.7)
    end)
end

--------------------------------------------------------------------------------
-- E — GRAB & SHOVE
--------------------------------------------------------------------------------

--[=[
    Picks somebody up and throws them.

    THE LIMITS ARE THE DESIGN:
      * 1 second of carry, maximum, and the cooldown is 16 seconds. There is no chaining.
      * He moves at 70% speed while carrying, so the grab costs him tempo as well.
      * The victim keeps EVERY ability and their basic attack for the whole second. Being
        carried is embarrassing, not disabling — and a Fall Guy who grabs somebody dangerous
        is holding a live grenade.
      * The throw is the payoff: real knockback, `Slipping`, and modest damage.

    The carry is implemented by moving the victim to a point in front of him each tick. That
    is deliberately NOT a weld: a weld would fight their own movement physics and could fling
    them when it broke. Re-positioning leaves their character intact and means the carry
    simply stops when either of them dies.
]=]
local function GrabBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.08, Duration = 0.4, Lock = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Target = CombatUtils.GetClosestFighter(Root.Position + Root.CFrame.LookVector * 3, self.Reach, Char)
    if not Target then
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "missed", BEAN_DARK, 0.7)
        return
    end

    local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
    if not Humanoid then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.85})
    AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "GOTCHA", BEAN, 1)

    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.CarrySpeedMultiplier)

    ----------------------------------------------------------------------------
    -- THE CARRY
    ----------------------------------------------------------------------------

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.CarryTime do
            Elapsed += task.wait(0.05)

            if not Char or not Char.Parent or not Target.Parent then
                break
            end

            local Mine = Utils.Character.GetRootPart(Char)
            local Theirs = Utils.Character.GetRootPart(Target)
            if not Mine or not Theirs or Humanoid.Health <= 0 then
                break
            end

            -- Dropped if he is stunned. A grab you can be interrupted out of is a grab
            -- with an answer.
            if Char.Effects and Char.Effects:FindFirstChild("Stunned") then
                break
            end

            -- Held overhead, in front. Rotated so they are visibly being carried.
            Target:PivotTo(Mine.CFrame * CFrame.new(0, 3.5, -3) * CFrame.Angles(0, 0, math.rad(90)))

            if Elapsed % 0.2 < 0.06 then
                AbilityFX.Sparks(Theirs.Position, BEAN, 3, 6)
            end
        end

        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)

        ------------------------------------------------------------------------
        -- THE THROW
        ------------------------------------------------------------------------

        if not Char or not Char.Parent or not Target.Parent or Humanoid.Health <= 0 then
            return
        end

        local Mine = Utils.Character.GetRootPart(Char)
        local Theirs = Utils.Character.GetRootPart(Target)
        if not Mine or not Theirs then
            return
        end

        local Direction = Mine.CFrame.LookVector

        -- Set them upright again before throwing, or they are launched lying down and the
        -- physics gets strange.
        Target:PivotTo(CFrame.new(Theirs.Position, Theirs.Position + Direction))

        CommonFunctions.DamagePlayer({
            SourcePlayer = self.Owner,
            TargetHumanoid = Humanoid,
            Damage = self.Damage,
            Reason = self.Name,
            KnockbackDirection = Direction + Vector3.new(0, 0.4, 0),
            KnockbackMagnitude = self.ThrowForce,
        })

        CombatUtils.ApplyEffectTo(Target, "Slipping", 2, 0.75)
        AbilityFX.ScreenFor(Target, "Woozy", 1.1, 1.2)
        AbilityFX.Sound(self.ThrowSound, Theirs.Position, {Volume = 0.9})
        AbilityFX.Ring(Theirs.Position, 7, BEAN, {Duration = 0.4})
        AbilityFX.Text(Theirs.Position + Vector3.new(0, 5, 0), "YEET", BEAN, 1.1)
    end)
end

--------------------------------------------------------------------------------
-- R — OBSTACLE DROP
--------------------------------------------------------------------------------

--[=[
    The three obstacles, in rotation.

    Like Bacon Hair's gear, one slot that cycles — and for the same reason: three separate
    obstacle abilities would have been three keys doing nearly the same thing.

    They are genuinely different in what they do, though:
      * SPINNING BAR sweeps a circle on a timer. Area denial you can learn the rhythm of.
      * BUMPER is a solid wall that throws anyone who touches it. A route changer.
      * ROLLING LOG travels in a straight line, shoving everyone it passes. A one-shot push.
]=]
local OBSTACLES = {"SpinningBar", "Bumper", "RollingLog"}

local function ObstacleBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.05, Duration = 0.35, Lock = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Cache = self.CharModule.GameplayConfig.Cache

    Cache.ObstacleIndex = Cache.ObstacleIndex or 1
    local Kind = OBSTACLES[Cache.ObstacleIndex]

    local Spot = Root.Position + Root.CFrame.LookVector * 8
    local Ground = AbilityFX.GroundAt(Spot, {Char})

    if not Ground then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.UseSound, Ground, {Volume = 0.8})
    AbilityFX.Ring(Ground, 8, BEAN, {Duration = 0.4})

    local Facing = Root.CFrame.LookVector

    ----------------------------------------------------------------------------
    -- SPINNING BAR
    ----------------------------------------------------------------------------

    if Kind == "SpinningBar" then
        local Bar = DeployableService.Place({
            SourcePlayer = self.Owner,
            Kind = "Obstacle",
            Name = "SpinningBar",
            CFrame = CFrame.new(Ground + Vector3.new(0, 2, 0)),
            Size = Vector3.new(2, 2, 2),
            Color = BEAN_DARK,
            Material = Enum.Material.Plastic,
            Solid = false,
            Health = self.ObstacleHealth,
            Lifetime = self.ObstacleLifetime,
            Limit = self.Limit,
            TickRate = self.SweepInterval,
            OutlineColor = BEAN,
            OnTick = function(handle)
                --[[
                    One sweep per tick, with a visible arc first.

                    A continuously rotating physical bar would need per-frame physics and
                    would be unreliable at the speeds that make it threatening. A telegraphed
                    sweep on a fixed rhythm is both cheaper and more readable — you can learn
                    the timing, which is the whole appeal of a game-show obstacle.
                ]]
                local Centre = handle.Root.Position
                AbilityFX.Ring(Centre, self.SweepRadius, BEAN, {Duration = 0.3, Thickness = 0.8})

                for _, Target: Model in CombatUtils.GetFightersInRadius(Centre, self.SweepRadius, nil) do
                    local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
                    local TargetRoot = Utils.Character.GetRootPart(Target)
                    if not Humanoid or not TargetRoot then
                        continue
                    end

                    CommonFunctions.DamagePlayer({
                        SourcePlayer = self.Owner,
                        TargetHumanoid = Humanoid,
                        Damage = self.SweepDamage,
                        Reason = "Spinning Bar",
                        KnockbackDirection = (TargetRoot.Position - Centre).Magnitude > 0
                            and (TargetRoot.Position - Centre).Unit
                            or Vector3.yAxis,
                        KnockbackMagnitude = 8,
                    })

                    CombatUtils.ApplyEffectTo(Target, "Slipping", 1, 0.6)
                end
            end,
        })

        if Bar then
            -- The visible bar: a long arm across the sweep.
            local Arm = AbilityFX.Part({
                Name = "Arm",
                Size = Vector3.new(self.SweepRadius * 2, 1.2, 1.2),
                CFrame = Bar.Root.CFrame,
                Color = BEAN,
                Material = Enum.Material.Plastic,
            })
            Arm.Parent = Bar.Model

            -- Spun by the same slow tick that sweeps, so what you see matches what hits.
            task.spawn(function()
                local Angle = 0
                while Bar.Alive and Arm.Parent and Bar.Root and Bar.Root.Parent do
                    task.wait(0.05)
                    Angle += 14
                    Arm.CFrame = CFrame.new(Bar.Root.Position) * CFrame.Angles(0, math.rad(Angle), 0)
                end
            end)
        end

    ----------------------------------------------------------------------------
    -- BUMPER
    ----------------------------------------------------------------------------

    elseif Kind == "Bumper" then
        local Bumper = DeployableService.Place({
            SourcePlayer = self.Owner,
            Kind = "Obstacle",
            Name = "Bumper",
            CFrame = CFrame.lookAt(Ground + Vector3.new(0, 3, 0), Ground + Facing),
            Size = Vector3.new(14, 6, 2),
            Color = BEAN,
            Material = Enum.Material.SmoothPlastic,
            Solid = true,
            Health = self.ObstacleHealth,
            Lifetime = self.ObstacleLifetime,
            Limit = self.Limit,
            TickRate = 0.25,
            OutlineColor = BEAN_DARK,
            OnTick = function(handle)
                -- Anyone pressed against it gets thrown off it.
                for _, Target: Model in CombatUtils.GetFightersInRadius(handle.Root.Position, 6, nil) do
                    local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
                    local TargetRoot = Utils.Character.GetRootPart(Target)
                    if not Humanoid or not TargetRoot then
                        continue
                    end

                    local Away = TargetRoot.Position - handle.Root.Position
                    CommonFunctions.DamagePlayer({
                        SourcePlayer = self.Owner,
                        TargetHumanoid = Humanoid,
                        Damage = self.BumpDamage,
                        Reason = "Bumper",
                        KnockbackDirection = Away.Magnitude > 0 and Away.Unit or Vector3.yAxis,
                        KnockbackMagnitude = 14,
                    })

                    CombatUtils.ApplyEffectTo(Target, "Slipping", 1, 0.6)
                    AbilityFX.Sound("rbxassetid://12222216", TargetRoot.Position, {Volume = 0.6, MinPitch = 1.3, MaxPitch = 1.5})
                end
            end,
        })

        if Bumper then
            AbilityFX.Smoke(Ground, BEAN, 10, 3)
        end

    ----------------------------------------------------------------------------
    -- ROLLING LOG
    ----------------------------------------------------------------------------

    else
        --[=[
            A log that rolls away from him in a straight line.

            Not a deployable: it is a moving hazard with a four second life, so it has no
            placement limit, no health and nothing to destroy — it is gone before breaking it
            would be worth the swing. Its own loop owns it completely.
        ]=]
        local Log = AbilityFX.Part({
            Name = "RollingLog",
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(12, 5, 5),
            CFrame = CFrame.lookAt(Ground + Vector3.new(0, 2.5, 0), Ground + Facing) * CFrame.Angles(0, math.rad(90), 0),
            Color = Color3.fromRGB(150, 100, 60),
            Material = Enum.Material.Wood,
        })
        Log.Parent = AbilityFX.Folder()

        AbilityFX.Sound("rbxassetid://9046319808", Ground, {Volume = 0.7, MinPitch = 0.7, MaxPitch = 0.85})

        task.spawn(function()
            local Elapsed = 0
            local Struck = {}
            local Spin = 0

            while Elapsed < self.LogLifetime and Log.Parent do
                local Step = task.wait(0.05)
                Elapsed += Step
                Spin += 30

                local Next = Log.Position + Facing * self.LogSpeed * Step

                -- Stops at a wall rather than rolling through it.
                local Params = RaycastParams.new()
                Params.FilterType = Enum.RaycastFilterType.Exclude
                Params.FilterDescendantsInstances = {Char, workspace.Players, AbilityFX.Folder()}

                if workspace:Raycast(Log.Position, Facing * self.LogSpeed * Step, Params) then
                    AbilityFX.Smoke(Log.Position, Color3.fromRGB(150, 100, 60), 10, 3)
                    break
                end

                Log.CFrame = CFrame.lookAt(Next, Next + Facing)
                    * CFrame.Angles(0, math.rad(90), 0)
                    * CFrame.Angles(math.rad(Spin), 0, 0)

                for _, Target: Model in CombatUtils.GetFightersInRadius(Log.Position, 7, Char) do
                    -- Once each. A log that hits you every tick is a wall that kills you.
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
                        Damage = self.LogDamage,
                        Reason = "Rolling Log",
                        KnockbackDirection = Facing + Vector3.new(0, 0.3, 0),
                        KnockbackMagnitude = 16,
                    })

                    CombatUtils.ApplyEffectTo(Target, "Slipping", 2, 0.75)
                    AbilityFX.ScreenFor(Target, "Woozy", 1, 1.1)
                end
            end

            if Log.Parent then
                Log:Destroy()
            end
        end)
    end

    ----------------------------------------------------------------------------
    -- CYCLE
    ----------------------------------------------------------------------------

    Cache.ObstacleIndex = (Cache.ObstacleIndex % #OBSTACLES) + 1
    local Next = OBSTACLES[Cache.ObstacleIndex]

    AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), Next, BEAN, 1)
    if Char then
        Char:SetAttribute("NextObstacle", Next)
    end
end

--------------------------------------------------------------------------------
-- PASSIVE — BOUNCY
--------------------------------------------------------------------------------

--[=[
    He is full of air.

    Implemented through `OnHit`, which fires whenever a hitbox connects with him. Returning
    nothing lets the hit land normally; what this does is immediately shorten the
    consequences — `Slipping` and `Snared` on him are cut down, because a bean bounces back
    upright faster than a person gets up.

    It also means his OWN dive recovery is shorter than it looks on paper, which is intended:
    the passive is there so that the character whose whole kit is physical contact is not the
    one most punished by physical contact.
]=]
local function Bouncy(self, _hitbox, _damage)
    if not RunService:IsServer() then
        return
    end

    local Char = self.Owner and self.Owner.Character
    if not Char then
        return
    end

    local Root = Utils.Character.GetRootPart(Char)
    if Root then
        -- A visible squash-and-stretch pop, so the passive reads on every hit.
        AbilityFX.Burst(Root.Position, 3.5, BEAN, {Duration = 0.2, StartSize = 2, Transparency = 0.6})
    end

    --[[
        Cut the duration of the two effects that take away his movement.

        `CommonFunctions.RemoveEffect` is the honest way to do this: there is no API for
        shortening a running effect, and re-applying it at a shorter duration would be
        overwritten by whatever applied it in the first place.
    ]]
    for _, Name in {"Slipping", "Snared"} do
        local Effect = Utils.Instance.FindFirstChild(Char, "Effects."..Name, 0)
        if Effect then
            CommonFunctions.RemoveEffect(Char, Name)
        end
    end
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local FallGuy: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Fall Guy",
        Quote = "",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 3100,

        Role = "Disruptor",
        Difficulty = 2,

        Origin = {
            TooltipText = "He thinks this is a round.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            --- Rubbery. He is not wearing shoes.
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            High health, low damage, and the most frequent crowd control in the game. He wins
            by making fights happen where he wants them, not by out-damaging anybody.
        ]]
        Health = 1350,
        BaseSpeed = 11,
        SprintSpeedMultiplier = 25.5 / 11,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 120,
            StaminaDrain = 10,
            StaminaGain = 23,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                --- Very low. The knockback and the slip are the attack.
                Damage = 17,
                Cooldown = 1.5,
                Duration = 0.26,
                Delay = 0.08,
                HitboxSize = Vector3.new(6, 6, 5),
                HitboxOffset = CFrame.new(0, 0, -2.6),
                Knockback = 7,

                Behaviour = ShoveBehaviour,
            }),

            Dive = Ability.New({
                Name = "Dive",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 10,
                Duration = 0.9,

                Power = 68,
                Lift = 34,
                Airtime = 0.75,
                Radius = 13,
                Damage = 34,
                Knockback = 12,
                Recovery = 0.5,

                UseSound = "rbxassetid://12222216",
                LandSound = "rbxassetid://9046319808",
                Behaviour = DiveBehaviour,
            }),

            Grab = Ability.New({
                Name = "Grab",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 16,
                Duration = 0.5,

                Reach = 9,
                CarryTime = 1,
                CarrySpeedMultiplier = 0.7,
                Damage = 26,
                ThrowForce = 22,

                UseSound = "rbxassetid://12222216",
                ThrowSound = "rbxassetid://9046319808",
                Behaviour = GrabBehaviour,
            }),

            Obstacle = Ability.New({
                Name = "Obstacle",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 18,
                Duration = 0.4,

                ObstacleHealth = 65,
                ObstacleLifetime = 20,
                Limit = 2,

                SweepRadius = 11,
                SweepInterval = 1.4,
                SweepDamage = 18,

                BumpDamage = 14,

                LogSpeed = 42,
                LogLifetime = 4,
                LogDamage = 30,

                UseSound = "rbxassetid://9046319808",
                Behaviour = ObstacleBehaviour,
            }),

            Bouncy = Ability.New({
                Name = "Bouncy",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",
            }),
        },
    },

    OnHit = Bouncy,
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(255, 125, 170)\">"..FallGuy.Config.Name.."</font>"
local Abilities = FallGuy.GameplayConfig.Abilities

FallGuy.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = FallGuy.Config.Name:upper()},
    {
        Type = "Text",
        Text = {
            NameLabel.." has nothing supernatural at all. He pushes, he dives, he picks people up, and he puts game-show obstacles in the way.",
            "His damage is among the lowest in the arena. What he does instead is make the fight happen somewhere other than where you wanted it.",
            "Everything he inflicts is <b>Slipping</b> — slow and no sprinting for three quarters of a second, while you keep every ability and your attack. He is funny and he is dangerous; he is never a stun.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..FallGuy.Config.Role,
            "Difficulty: "..string.rep("★", FallGuy.Config.Difficulty)..string.rep("☆", 5 - FallGuy.Config.Difficulty),
            "Price: "..tostring(FallGuy.Config.Price).."$",
            "Health: "..tostring(FallGuy.GameplayConfig.Health),
            "Base Speed: "..tostring(FallGuy.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(FallGuy.GameplayConfig.BaseSpeed * FallGuy.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "GRAB"},
    {
        Type = "Text",
        Text = {
            "A two-handed shove for "..tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds. Hits everybody in front of him.",
            "Low damage, heavy knockback, and it leaves them <b>Slipping</b>.",
        },
    },

    {Type = "Header", Text = "DIVE  (Q)"},
    {
        Type = "Text",
        Text = {
            "A full-body dive — up and forward, with real air time. Lands for "..tostring(Abilities.Dive.Damage).." damage across "..tostring(Abilities.Dive.Radius).." studs and slips everybody in it.",
            "The damage is on the LANDING, so where he lands is the decision and the flight is committed.",
            "He slips himself for half a second on the way down. He is a bean.",
            "Cooldown: "..tostring(Abilities.Dive.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "GRAB  (E)"},
    {
        Type = "Text",
        Text = {
            "Picks up the nearest fighter within "..tostring(Abilities.Grab.Reach).." studs and carries them for "..tostring(Abilities.Grab.CarryTime).." second, then throws them for "..tostring(Abilities.Grab.Damage).." damage.",
            "He moves at 70% speed while carrying. <b>They keep every ability and their basic attack the whole time</b> — grabbing somebody dangerous is holding a live grenade.",
            "Stunning him drops them immediately.",
            "Cooldown: "..tostring(Abilities.Grab.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "OBSTACLE  (R)"},
    {
        Type = "Text",
        Text = {
            "Drops one of three, then cycles to the next. What is coming floats over his head.",
            "<b>Spinning Bar</b>: sweeps "..tostring(Abilities.Obstacle.SweepRadius).." studs every "..tostring(Abilities.Obstacle.SweepInterval).." seconds, on a rhythm you can learn.",
            "<b>Bumper</b>: a solid wall that throws anyone who touches it.",
            "<b>Rolling Log</b>: rolls away from him in a straight line, shoving everyone it passes once.",
            "Cooldown: "..tostring(Abilities.Obstacle.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "BOUNCY  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Being hit clears <b>Slipping</b> and <b>Snared</b> off him immediately — he bounces back upright faster than a person gets up.",
            "The character whose whole kit is physical contact is not the one most punished by it.",
        },
    },
}

return FallGuy
