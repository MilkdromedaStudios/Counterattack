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

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    KNUCKLES — THE BEST MELEE IN THE GAME AND NO RANGED AT ALL.

      M1  PUNCH COMBO    Three punches in sequence. The third one hits much harder.
      Q   CHARGED PUNCH  Hold-and-release. Breaks structures outright. Enormous.
      E   GLIDE          Forward and slightly down, under control, for as long as he likes.
      R   GROUND SLAM    Jumps and comes down. An area knockback, not a nuke.
      F   CLIMB          Goes straight up a wall he is touching.
      P   MOMENTUM       Punches build it. It makes him faster and his combo hit harder.

    HE HAS NO PROJECTILE, NO ZONE AND NO SUMMON
    -------------------------------------------
    Nothing in his kit reaches past about ten studs. In exchange he has the highest sustained
    melee damage on the roster, the only basic attack that is a real COMBO, and two
    traversal tools that mean "I am not where you can shoot me" is an option.

    THE COMBO IS WHY HIS BASIC ATTACK IS DIFFERENT
    ----------------------------------------------
    Three hits: 20, 20, then 42 with knockback. The counter advances on a HIT and decays if
    he stops swinging, so the big third punch has to be earned by landing the first two — and
    whoever he is fighting can see it coming, because his gloves light up on the third.

    CHARGED PUNCH IS THE ANSWER TO BUILDERMAN
    -----------------------------------------
    It does `StructureDamage` to every deployable in range, which is enough to one-shot most
    of them: a sentry, a trap, a camera, a vent, a sabotage marker. The roster has five
    characters who build things, and he is the designated reply to all of them.

    MOMENTUM is the glue: it only builds from connecting punches, so a Knuckles who is
    landing hits accelerates into landing more, and a Knuckles who is whiffing gets nothing.
]=]

local KNUX = Color3.fromRGB(220, 50, 60)
local KNUX_GLOVE = Color3.fromRGB(255, 240, 230)
local MOMENTUM_METER = "Momentum"

--------------------------------------------------------------------------------
-- M1 — PUNCH COMBO
--------------------------------------------------------------------------------

--[=[
    A three-hit combo.

    The step is stored on the per-player module cache, with a timestamp — if he stops
    punching for `ComboWindow` seconds the chain resets to the first punch. That is the whole
    tension of the attack: the payoff is two hits away and the window is short.
]=]
local function PunchBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.05, Duration = 0.2, Lock = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Cache = self.CharModule.GameplayConfig.Cache

    ----------------------------------------------------------------------------
    -- WHICH PUNCH
    ----------------------------------------------------------------------------

    -- Dropped if he has not connected recently. Checked against the last HIT, not the last
    -- swing, so missing does not advance the chain.
    if not Cache.ComboAt or os.clock() - Cache.ComboAt > self.ComboWindow then
        Cache.ComboStep = 0
    end

    Cache.ComboStep = (Cache.ComboStep or 0) % 3 + 1
    local Step = Cache.ComboStep
    local Finisher = Step == 3

    local Momentum = MeterService.Fraction(Char, MOMENTUM_METER)
    local Damage = (Finisher and self.FinisherDamage or self.Damage) * (1 + self.DamagePerMomentum * Momentum)

    AbilityFX.SoundOn(Root, self.UseSound, {
        Volume = Finisher and 0.95 or 0.6,
        MinPitch = Finisher and 0.8 or 1.05,
        MaxPitch = Finisher and 0.9 or 1.25,
    })

    -- The gloves light up on the third. The telegraph for the big one.
    if Finisher then
        AbilityFX.Tint(Char, KNUX_GLOVE, 0.3, {FillTransparency = 0.7, Outline = KNUX})
    end

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        local Impact = Root.Position + Root.CFrame.LookVector * 3.5 + Vector3.new(0, 1, 0)
        AbilityFX.Burst(Impact, Finisher and 6 or 3, Finisher and KNUX or KNUX_GLOVE, {
            Duration = 0.2,
            StartSize = 1.5,
        })

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = Finisher and self.FinisherHitbox or self.HitboxSize,
            Time = self.Duration,
            Damage = Damage,
            Reason = Finisher and "Knuckle Sandwich" or "Punch",
            ExecuteOnKill = true,
            Knockback = Finisher and self.FinisherKnockback or 2,
            HitMultiple = Finisher,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    -- Only a CONNECTING punch advances the combo and builds momentum.
                    Cache.ComboAt = os.clock()
                    MeterService.Add(Char, MOMENTUM_METER, Finisher and self.MomentumOnFinisher or self.MomentumOnHit)

                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if not VictimRoot then
                        return
                    end

                    AbilityFX.Sparks(VictimRoot.Position, Finisher and KNUX or KNUX_GLOVE, Finisher and 20 or 8, Finisher and 32 or 14)

                    if Finisher then
                        AbilityFX.Shockwave(VictimRoot.Position, 8, KNUX, 20)
                        AbilityFX.ShakeFor(Victim, 4, 0.5)
                    else
                        AbilityFX.ShakeFor(Victim, 1.5, 0.2)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — CHARGED PUNCH
--------------------------------------------------------------------------------

--[=[
    Wind up, then hit something extremely hard.

    A 0.8 second root with a widening ring under him, then a short-range cone for very large
    damage and knockback — and `StructureDamage` to every deployable in range, which is
    enough to delete most of them in one go.

    The root is the balance: 0.8 seconds standing still inside punching range is a long time,
    and a stun during it cancels the punch entirely.
]=]
local function ChargedBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Zoom(self, 0.86)
        self:AddConnection(task.delay(self.Windup, function()
            AbilityClient.ReleaseZoom(self)
            AbilityClient.Shake(4, 0.4)
        end))
        AbilityClient.LockHead(self, self.Windup + 0.3)
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.ChargeSound, Root.Position, {Volume = 0.8, MinPitch = 0.7, MaxPitch = 0.8})

    -- Rooted while winding up. `Snared` so it is visible and other systems understand it.
    CombatUtils.ApplyEffectTo(Char, "Snared", 5, self.Windup)
    AbilityFX.Telegraph(Root.Position, self.Range, KNUX, self.Windup)

    -- His fist glowing hotter as it charges.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Windup and Char and Char.Parent do
            Elapsed += task.wait(0.1)
            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                AbilityFX.Burst(
                    Live.Position + Live.CFrame.LookVector * 2 + Vector3.new(0, 1, 0),
                    1.5 + 3 * (Elapsed / self.Windup),
                    KNUX,
                    {Duration = 0.15, StartSize = 1, Transparency = 0.4}
                )
            end
        end
    end)

    task.delay(self.Windup, function()
        if not Char or not Char.Parent then
            return
        end

        local Live = Utils.Character.GetRootPart(Char)
        if not Live then
            return
        end

        -- Interrupted: no punch. Stunning a charging Knuckles is the hard counter.
        if Char.Effects and Char.Effects:FindFirstChild("Stunned") then
            AbilityFX.Text(Live.Position + Vector3.new(0, 5, 0), "...", KNUX, 0.8)
            return
        end

        local Origin = Live.Position + Vector3.new(0, 1, 0)
        local Direction = Live.CFrame.LookVector

        AbilityFX.Sound(self.UseSound, Origin, {Volume = 1, RollOffMaxDistance = 170})
        AbilityFX.Shockwave(Origin + Direction * 4, self.Range, KNUX, 34)
        AbilityFX.ShakeInRadius(Origin, self.Range * 2.5, 5, 0.6)

        ------------------------------------------------------------------------
        -- FIGHTERS
        ------------------------------------------------------------------------

        for _, Target: Model in AbilityFX.ConeTargets(Origin, Direction, self.Range, self.Angle, Char) do
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
                KnockbackDirection = Direction + Vector3.new(0, 0.3, 0),
                KnockbackMagnitude = self.Knockback,
            })

            CombatUtils.ApplyEffectTo(Target, "Fragile", 3, 6)
            AbilityFX.ShakeFor(Target, 6, 0.7)
        end

        ------------------------------------------------------------------------
        -- STRUCTURES
        ------------------------------------------------------------------------

        --[=[
            This is his answer to the builders.

            `DamageInRadius` with a number large enough to one-shot a sentry, a trap, a
            camera or a sabotage marker, and to take a serious bite out of a wall. Five
            characters on this roster put objects on the floor; he is the designated reply to
            all of them, and that is a role worth having on a character with no range.
        ]=]
        local Broken = DeployableService.DamageInRadius(Origin + Direction * 5, self.Range * 1.4, self.StructureDamage, self.Owner)

        if Broken > 0 then
            AbilityFX.Text(Origin + Vector3.new(0, 5.5, 0), "SMASH", KNUX, 1.2)
        end
    end)
end

--------------------------------------------------------------------------------
-- E — GLIDE
--------------------------------------------------------------------------------

--[=[
    Forward and slightly down, under control, with no time limit.

    DIFFERENT FROM EVERY OTHER MOVEMENT ABILITY ON THE ROSTER, which was the explicit brief:

      * It is a TOGGLE with no duration, so it is a travel mode rather than a burst.
      * He cannot gain height. The glide holds his vertical velocity at a slow descent, so
        it converts height into distance and nothing else.
      * He keeps his punches the whole time, which makes it an approach as well as a
        traversal — a gliding Knuckles arriving on your head is a real threat.

    It ends when he touches the ground, when he presses it again, or when he is stunned.
]=]
local function GlideBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        local Char = self.OwnerProperties.Character
        if Char and Char:GetAttribute("KnucklesGliding") then
            AbilityClient.ReleaseZoom(self)
        else
            AbilityClient.Zoom(self, 1.18)
        end
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Humanoid = self.OwnerProperties.Humanoid

    ----------------------------------------------------------------------------
    -- STOP
    ----------------------------------------------------------------------------

    if Char:GetAttribute("KnucklesGliding") then
        Char:SetAttribute("KnucklesGliding", false)
        return
    end

    ----------------------------------------------------------------------------
    -- START
    ----------------------------------------------------------------------------

    Char:SetAttribute("KnucklesGliding", true)

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.7, MinPitch = 1.0, MaxPitch = 1.15})

    task.spawn(function()
        local Elapsed = 0

        while Char and Char.Parent and Char:GetAttribute("KnucklesGliding") do
            Elapsed += task.wait(0.05)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live or not Humanoid then
                break
            end

            if Humanoid.Health <= 0 then
                break
            end

            -- Stunned mid-glide: he drops.
            if Char.Effects and Char.Effects:FindFirstChild("Stunned") then
                break
            end

            local State = Humanoid:GetState()

            --[[
                Landing ends it.

                Checked on the humanoid state rather than a ground raycast so it agrees with
                whatever the engine thinks — a glide that continued while standing on the
                floor would be a flat speed buff.
            ]]
            if State ~= Enum.HumanoidStateType.Freefall and State ~= Enum.HumanoidStateType.Jumping then
                if Elapsed > 0.2 then
                    break
                end
                continue
            end

            local Velocity = Live.AssemblyLinearVelocity

            -- Slow, controlled descent, and forward push along his facing. He never gains
            -- height: the vertical component is CLAMPED, not added to.
            Live.AssemblyLinearVelocity = Vector3.new(
                Live.CFrame.LookVector.X * self.Speed,
                math.max(Velocity.Y, -self.Descent),
                Live.CFrame.LookVector.Z * self.Speed
            )

            if math.random() < 0.4 then
                AbilityFX.Burst(Live.Position, 2.5, KNUX, {Duration = 0.3, StartSize = 2, Transparency = 0.8})
            end
        end

        if Char then
            Char:SetAttribute("KnucklesGliding", false)

            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                AbilityFX.Smoke(Live.Position, Color3.fromRGB(210, 200, 190), 6, 2)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- R — GROUND SLAM
--------------------------------------------------------------------------------

--[=[
    Jumps and comes down.

    An AREA KNOCKBACK with modest damage, deliberately: he already has the biggest single hit
    in his charged punch, and a second nuke would make him a burst character rather than a
    brawler. What this does is CREATE SPACE — everyone around him is thrown clear and
    `Grounded`, so the ability that follows it lands.

    It also cracks structures, at half the charged punch's rate.
]=]
local function SlamBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.15, Duration = self.Airtime + 0.3, Shake = 5, ShakeTime = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.JumpSound, Root.Position, {Volume = 0.8})

    Root.AssemblyLinearVelocity = Vector3.new(0, self.Lift, 0)

    task.delay(self.Airtime, function()
        if not Char or not Char.Parent then
            return
        end

        local Live = Utils.Character.GetRootPart(Char)
        if not Live then
            return
        end

        -- Comes down hard rather than floating back.
        Live.AssemblyLinearVelocity = Vector3.new(0, -self.Slam, 0)

        task.wait(self.Fall)

        Live = Utils.Character.GetRootPart(Char)
        if not Live then
            return
        end

        local Origin = Live.Position

        AbilityFX.Sound(self.UseSound, Origin, {Volume = 1, RollOffMaxDistance = 190})
        AbilityFX.Ring(Origin, self.Radius, KNUX, {Duration = 0.5, Thickness = 1.5})
        AbilityFX.Ring(Origin, self.Radius * 0.6, KNUX_GLOVE, {Duration = 0.4, Thickness = 1})
        AbilityFX.Smoke(Origin, Color3.fromRGB(190, 170, 150), 20, 4)
        AbilityFX.ShakeInRadius(Origin, self.Radius * 2, 6, 0.7)

        -- Cracks radiating out along the floor.
        for Index = 1, 8 do
            local Angle = (Index / 8) * math.pi * 2
            AbilityFX.Beam(
                Origin,
                Origin + Vector3.new(math.cos(Angle) * self.Radius, 0.2, math.sin(Angle) * self.Radius),
                Color3.fromRGB(120, 90, 70),
                {Width = 0.8, Duration = 0.7, Transparency = 0.3}
            )
        end

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

            -- `Grounded`, not a stun: they keep everything, they just cannot sprint away
            -- from the punch that is coming.
            CombatUtils.ApplyEffectTo(Target, "Grounded", 1, self.GroundTime)
            AbilityFX.ShakeFor(Target, 5, 0.6)
        end

        DeployableService.DamageInRadius(Origin, self.Radius, self.StructureDamage, self.Owner)
    end)
end

--------------------------------------------------------------------------------
-- F — CLIMB
--------------------------------------------------------------------------------

--[=[
    Straight up a wall he is touching.

    A SHORT raycast forward to find a wall, then a controlled vertical lift for a fixed
    duration. He has to actually be against something — pressing it in the open does nothing
    and refunds.

    With `Glide`, this is his whole traversal kit: climb to get height, glide to convert it
    into distance. Neither one is fast; together they go places nobody else can.
]=]
local function ClimbBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.92, Duration = self.Duration_})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    ----------------------------------------------------------------------------
    -- IS THERE A WALL?
    ----------------------------------------------------------------------------

    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {Char, workspace.Players}
    Params.RespectCanCollide = true

    local Cast = workspace:Raycast(Root.Position, Root.CFrame.LookVector * self.Reach, Params)

    if not Cast then
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "no wall", KNUX, 0.8)
        return
    end

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.7, MinPitch = 0.95, MaxPitch = 1.1})

    local Surface = Cast.Normal

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.Duration_ and Char and Char.Parent do
            Elapsed += task.wait(0.05)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            --[[
                Re-checked every tick that the wall is STILL THERE.

                Climbing past the top of a wall should stop the climb, not carry him into the
                sky — and a wall that gets destroyed mid-climb should drop him.
            ]]
            local Still = workspace:Raycast(Live.Position, -Surface * self.Reach, Params)
            if not Still then
                break
            end

            -- Up, and pressed gently into the wall so he does not drift off it.
            Live.AssemblyLinearVelocity = Vector3.new(0, self.ClimbSpeed, 0) - Surface * 4

            AbilityFX.Sparks(Live.Position + Surface * -1.5, Color3.fromRGB(190, 170, 150), 3, 6)
        end

        local Live = Char and Utils.Character.GetRootPart(Char)
        if Live then
            AbilityFX.Smoke(Live.Position, Color3.fromRGB(200, 190, 180), 5, 1.5)
        end
    end)
end

--------------------------------------------------------------------------------
-- PASSIVE — MOMENTUM
--------------------------------------------------------------------------------

--[=[
    Punches build it; standing still loses it.

    It decays at 6 a second and only fills from connecting hits, so it is genuinely a measure
    of whether he is winning the fight he is in. At full it is +22% speed and +25% punch
    damage — a large bonus that cannot be opened with, only earned.

    `MeterService` handles the decay and the replication, so this passive is six lines and a
    speed factor rather than its own loop.
]=]
local function MomentumInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    MeterService.Define(Char, MOMENTUM_METER, {
        Max = 100,
        Start = 0,
        RegenPerSecond = 0,
        --- Bleeds away whenever he is not landing punches.
        DecayPerSecond = self.Decay,
        OnChanged = function(value: number)
            PlayerSpeedManager.AddSpeedFactor(self.Owner, "Momentum", 1 + self.SpeedPerMomentum * (value / 100))
        end,
    })
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Knuckles: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Knuckles",
        Quote = "Oh no.",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 6800,

        Role = "Chaser",
        Difficulty = 3,

        Origin = {
            TooltipText = "He knows where the emerald is.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            High health, average speed, and the best melee numbers in the game. No range at
            all, which is the entire trade.
        ]]
        Health = 1400,
        BaseSpeed = 11.1,
        SprintSpeedMultiplier = 26 / 11.1,
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
                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                --- First and second punch.
                Damage = 20,
                --- Third. Earned by landing the first two.
                FinisherDamage = 42,
                --- Fast, because it is a combo rather than a swing.
                Cooldown = 0.85,
                Duration = 0.2,
                Delay = 0.06,
                HitboxSize = Vector3.new(4.5, 5.5, 5),
                FinisherHitbox = Vector3.new(7, 6, 6.5),
                HitboxOffset = CFrame.new(0, 0, -2.6),
                FinisherKnockback = 15,

                --- Seconds after a CONNECTING punch before the chain resets.
                ComboWindow = 2,
                MomentumOnHit = 9,
                MomentumOnFinisher = 20,
                DamagePerMomentum = 0.25,

                Behaviour = PunchBehaviour,
            }),

            Charged = Ability.New({
                Name = "Charged",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 20,
                Duration = 1.1,

                Windup = 0.8,
                Range = 12,
                Angle = 110,
                Damage = 95,
                Knockback = 24,
                --- Enough to one-shot most deployables on the roster.
                StructureDamage = 120,

                ChargeSound = "rbxassetid://9125402735",
                UseSound = "rbxassetid://9046319808",
                Behaviour = ChargedBehaviour,
            }),

            Glide = Ability.New({
                Name = "Glide",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 3,
                Duration = 0.2,

                Speed = 46,
                --- Studs per second of descent. He can never gain height.
                Descent = 10,

                UseSound = "rbxassetid://12222216",
                Behaviour = GlideBehaviour,
            }),

            Slam = Ability.New({
                Name = "Slam",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 24,
                Duration = 1.4,

                Lift = 55,
                Airtime = 0.5,
                Slam = 110,
                Fall = 0.3,
                Radius = 20,
                --- Modest. The knockback is the ability.
                Damage = 40,
                Knockback = 20,
                GroundTime = 2.5,
                StructureDamage = 60,

                JumpSound = "rbxassetid://12222216",
                UseSound = "rbxassetid://9118823103",
                Behaviour = SlamBehaviour,
            }),

            Climb = Ability.New({
                Name = "Climb",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 8,
                Duration = 1.2,

                Duration_ = 1.2,
                Reach = 4,
                ClimbSpeed = 30,

                UseSound = "rbxassetid://12222216",
                Behaviour = ClimbBehaviour,
            }),

            Momentum = Ability.New({
                Name = "Momentum",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                Decay = 6,
                SpeedPerMomentum = 0.22,

                ExtraInit = MomentumInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(220, 50, 60)\">"..Knuckles.Config.Name.."</font>"
local Abilities = Knuckles.GameplayConfig.Abilities

Knuckles.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Knuckles.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Knuckles.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." has the best melee in the arena and <b>nothing that reaches past ten studs</b>. No projectile, no zone, no summon.",
            "His basic attack is a real three-hit combo, and <b>Momentum</b> only builds from punches that land — so a Knuckles who is winning accelerates, and one who is whiffing gets nothing.",
            "He is also the designated answer to everybody who builds: <b>Charged</b> deletes most structures outright.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Knuckles.Config.Role,
            "Difficulty: "..string.rep("★", Knuckles.Config.Difficulty)..string.rep("☆", 5 - Knuckles.Config.Difficulty),
            "Price: "..tostring(Knuckles.Config.Price).."$",
            "Health: "..tostring(Knuckles.GameplayConfig.Health),
            "Base Speed: "..tostring(Knuckles.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Knuckles.GameplayConfig.BaseSpeed * Knuckles.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "PUNCH COMBO"},
    {
        Type = "Text",
        Text = {
            "Three hits every "..tostring(Abilities.Slash.Cooldown).." seconds: "..tostring(Abilities.Slash.Damage)..", "..tostring(Abilities.Slash.Damage)..", then <b>"..tostring(Abilities.Slash.FinisherDamage).."</b> with heavy knockback.",
            "The chain only advances on a punch that <b>lands</b>, and resets if he stops connecting for "..tostring(Abilities.Slash.ComboWindow).." seconds.",
            "His gloves light up on the third. You can see it coming.",
            "At full Momentum every punch does 25% more.",
        },
    },

    {Type = "Header", Text = "CHARGED  (Q)"},
    {
        Type = "Text",
        Text = {
            "Roots himself for "..tostring(Abilities.Charged.Windup).." seconds, then hits everything in front of him for <b>"..tostring(Abilities.Charged.Damage).." damage</b> and throws it a long way.",
            "Also does "..tostring(Abilities.Charged.StructureDamage).." damage to every structure in range — enough to <b>one-shot most of them</b>.",
            "<b>Stunning him during the wind-up cancels it.</b>",
            "Cooldown: "..tostring(Abilities.Charged.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "GLIDE  (E)"},
    {
        Type = "Text",
        Text = {
            "A <b>toggle</b> with no time limit. Forward at "..tostring(Abilities.Glide.Speed).." studs a second while descending slowly.",
            "He cannot gain height — it converts altitude into distance and nothing else. He keeps his punches the whole time.",
            "Landing, pressing again, or being stunned ends it.",
        },
    },

    {Type = "Header", Text = "SLAM  (R)"},
    {
        Type = "Text",
        Text = {
            "Jumps and comes down. "..tostring(Abilities.Slam.Damage).." damage across "..tostring(Abilities.Slam.Radius).." studs, heavy knockback, and <b>Grounded</b> for "..tostring(Abilities.Slam.GroundTime).." seconds.",
            "The damage is modest on purpose. This is here to make space for the punch that follows it.",
            "Cooldown: "..tostring(Abilities.Slam.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "CLIMB  (F)"},
    {
        Type = "Text",
        Text = {
            "Goes straight up a wall he is touching, for "..tostring(Abilities.Climb.Duration_).." seconds.",
            "He has to actually be against something. Reaching the top ends the climb.",
            "Cooldown: "..tostring(Abilities.Climb.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "MOMENTUM  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Builds only from punches that connect, and bleeds away at "..tostring(Abilities.Momentum.Decay).." a second otherwise.",
            "At full: +22% speed and +25% punch damage. It cannot be opened with, only earned.",
        },
    },
}

return Knuckles
