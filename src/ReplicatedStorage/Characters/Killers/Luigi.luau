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
local ProjectileService = require(ReplicatedStorage.Modules.ProjectileService)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    LUIGI — HE DOES NOT WANT TO BE HERE.

    The Luigi's Mansion one: a torch, a vacuum cleaner, and a great deal of reluctance.

      M1  FLASHLIGHT BASH  He hits you with the torch. It is not what the torch is for.
      Q   STROBULB         A flash in a cone. Anybody LOOKING AT IT is disoriented.
      E   POLTERGUST       A vacuum cone. Drags people in, and eats projectiles and traps.
      R   BURST            Fires the Poltergust downward. Launches him, throws everyone off.
      P   SCARED COURAGE   Being hurt or startled makes him faster for a moment.

    THE STROBULB CHECKS WHERE YOU ARE LOOKING
    -----------------------------------------
    Not a blanket cone effect. It uses `CombatUtils.IsFacing` on each target, so somebody
    with their back to the flash takes the damage and walks away, while somebody facing it is
    `Disoriented` and has their screen washed out.

    That is the right shape for a flash, and it is also the counterplay: the answer to a
    Luigi reaching for the torch is to not be looking at him. `Disoriented` is short on
    purpose — it inverts your controls, which is the harshest effect in the game, so it lasts
    1.4 seconds and never longer.

    THE POLTERGUST IS A VACUUM, NOT A GRAB
    --------------------------------------
    It drags everyone in the cone a few studs toward him every tick while held, which is
    pressure rather than capture: you can walk out of it, you can fight through it, and he is
    rooted while he holds it. What it is REALLY for is the second half — it swallows
    projectiles and small deployables, which makes him the only character who can clean a
    room of other people's equipment at range.

    WEAKNESSES
    ----------
    Below-average damage everywhere. The Poltergust roots him. The Strobulb does nothing to
    somebody who is not looking. His only mobility is a self-launch with no horizontal
    control, and he is the second-lowest health on the roster.
]=]

local LUIGI = Color3.fromRGB(70, 200, 90)
local TORCH = Color3.fromRGB(255, 250, 200)
local GUST = Color3.fromRGB(190, 200, 220)

--------------------------------------------------------------------------------
-- M1 — FLASHLIGHT BASH
--------------------------------------------------------------------------------

local function BashBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.03, Duration = 0.25, Lock = 0.5})
        return
    end

    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.55, MinPitch = 1.05, MaxPitch = 1.2})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        -- The torch beam swings through the arc. Cheap, and unmistakably him.
        local From = Root.Position + Vector3.new(0, 1.2, 0)
        AbilityFX.Beam(From, From + Root.CFrame.LookVector * 7, TORCH, {
            Width = 0.8,
            Duration = 0.2,
            Taper = 3,
            Transparency = 0.4,
        })

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Flashlight",
            ExecuteOnKill = true,
            Knockback = 3,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, TORCH, 6, 12)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — STROBULB
--------------------------------------------------------------------------------

local function StrobulbBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.12, Duration = 0.4, Lock = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position + Vector3.new(0, 1.2, 0)
    local Direction = Root.CFrame.LookVector

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 0.9})

    -- The flash itself: a white sphere and a bright cone.
    AbilityFX.Burst(Origin + Direction * 4, self.Range * 0.6, Color3.new(1, 1, 1), {
        Duration = 0.25,
        StartSize = 3,
        Transparency = 0.1,
    })
    AbilityFX.Cone(Origin, Direction, self.Range, self.Angle, TORCH, {Rays = 11, Duration = 0.3, Width = 1})

    local Blinded, Spared = 0, 0

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
        })

        --[=[
            THE CHECK THAT MAKES IT A FLASH.

            `IsFacing` against Luigi's position: looking at the light means it works on you,
            looking away means it does not. Anybody with their back turned takes the damage
            and keeps full control.
        ]=]
        if CombatUtils.IsFacing(Target, Origin, self.FacingTolerance) then
            Blinded += 1

            -- Short. `Disoriented` inverts the controls, which is the harshest effect in the
            -- game — 1.4 seconds and never longer.
            CombatUtils.ApplyEffectTo(Target, "Disoriented", 1, self.DisorientTime)
            CombatUtils.ApplyEffectTo(Target, "Slowness", self.SlowLevel, self.SlowTime)

            AbilityFX.ScreenFor(Target, "Flash", self.DisorientTime, 1.4)
            AbilityFX.Text(TargetRoot.Position + Vector3.new(0, 5.5, 0), "!!", TORCH, 1)
        else
            Spared += 1
            AbilityFX.Text(TargetRoot.Position + Vector3.new(0, 5, 0), "looked away", GUST, 0.9)
        end
    end

    if Blinded <= 0 and Spared <= 0 then
        self.OnCooldown = false
        self.CooldownTimer = 0
    end
end

--------------------------------------------------------------------------------
-- E — POLTERGUST
--------------------------------------------------------------------------------

--[=[
    The vacuum. Held, not cast.

    For `Duration_` seconds he is rooted and sucking. Every tick:
      * everyone in the cone is dragged a few studs toward him and takes a small amount of
        damage;
      * projectiles in the cone are swallowed;
      * small deployables in the cone are destroyed.

    The ROOT is what balances it. Three seconds standing still with a loud cone of
    particles in front of him is an invitation, and whoever is being pulled can simply fight
    him while it happens — the drag is pressure, not control.
]=]
local function PoltergustBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Zoom(self, 0.9)
        self:AddConnection(task.delay(self.Duration_, function()
            AbilityClient.ReleaseZoom(self)
        end))
        AbilityClient.LockHead(self, self.Duration_)
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.9, RollOffMaxDistance = 120})

    -- Rooted while vacuuming. Keeps his basic attack, so standing next to him is still bad.
    CombatUtils.ApplyEffectTo(Char, "Snared", 5, self.Duration_)

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.Duration_ and Char and Char.Parent do
            Elapsed += task.wait(self.TickRate)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
            if not Humanoid or Humanoid.Health <= 0 then
                break
            end

            -- Interrupted: the vacuum stops. Another reason to stun him.
            if Char.Effects and Char.Effects:FindFirstChild("Stunned") then
                break
            end

            local Origin = Live.Position + Vector3.new(0, 1.2, 0)
            local Direction = Live.CFrame.LookVector
            local Centre = Origin + Direction * (self.Range * 0.5)

            ----------------------------------------------------------------
            -- THE CONE
            ----------------------------------------------------------------

            AbilityFX.Cone(Origin, Direction, self.Range, self.Angle, GUST, {
                Rays = 7,
                Duration = self.TickRate,
                Width = 0.5,
            })

            -- Debris being drawn IN, which is what makes it read as suction rather than a
            -- beam: particles accelerate back toward him.
            AbilityFX.Emit(Centre, 6, {
                Color = ColorSequence.new(GUST),
                Speed = NumberRange.new(10, 20),
                Size = NumberSequence.new(0.8),
                Lifetime = NumberRange.new(0.2, 0.4),
                Acceleration = (Origin - Centre).Unit * 60,
            })

            ----------------------------------------------------------------
            -- FIGHTERS
            ----------------------------------------------------------------

            for _, Target: Model in AbilityFX.ConeTargets(Origin, Direction, self.Range, self.Angle, Char) do
                local TargetHumanoid = Target:FindFirstChildWhichIsA("Humanoid")
                local TargetRoot = Utils.Character.GetRootPart(Target)
                if not TargetHumanoid or not TargetRoot then
                    continue
                end

                CommonFunctions.DamagePlayer({
                    SourcePlayer = self.Owner,
                    TargetHumanoid = TargetHumanoid,
                    Damage = self.TickDamage,
                    Reason = self.Name,
                })

                -- Dragged a little, never past him.
                local Delta = Live.Position - TargetRoot.Position
                local Travel = math.min(self.PullPerTick, math.max(Delta.Magnitude - 6, 0))

                if Travel > 0.3 then
                    CombatUtils.Blink(Target, TargetRoot.Position + Delta.Unit * Travel)
                end
            end

            ----------------------------------------------------------------
            -- EQUIPMENT
            ----------------------------------------------------------------

            --[=[
                The half nobody else on the roster has.

                Five characters build things and several more fire projectiles; Luigi is the
                only one who can clear both at range. That is a real role in a free-for-all
                full of turrets and traps, and it is why his direct damage is so low.
            ]=]
            local Eaten = ProjectileService.Consume(Centre, self.Range * 0.5, self.Owner)

            for _, Handle in DeployableService.GetInRadius(Centre, self.Range * 0.5, self.Owner) do
                if Handle.Root and Handle.Root.Size.Magnitude <= self.MaximumIntake then
                    Handle:Destroy()
                    Eaten += 1
                end
            end

            if Eaten > 0 then
                AbilityFX.Sound(self.IntakeSound, Live.Position, {Volume = 0.7, MinPitch = 1.2, MaxPitch = 1.4})
                AbilityFX.Burst(Live.Position, 4, GUST, {Duration = 0.25})
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- R — BURST
--------------------------------------------------------------------------------

--[=[
    Fires the Poltergust straight down.

    Two effects at once, which is what makes it worth a slot rather than being a worse
    Ground Slam:
      * HE GOES UP. A straight vertical launch with no horizontal control at all — his only
        mobility, and it is as clumsy as he is.
      * EVERYBODY NEARBY IS BLOWN BACK. Knockback and `Slipping`, no real damage.

    It is an escape and a disengage, not a kill. The lack of horizontal control is deliberate:
    he cannot burst TOWARD anybody, only away from the floor.
]=]
local function BurstBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.25, Duration = 0.6, Shake = 3, ShakeTime = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 1, RollOffMaxDistance = 150})
    AbilityFX.Ring(Origin, self.Radius, GUST, {Duration = 0.5, Thickness = 1.2})
    AbilityFX.Smoke(Origin - Vector3.new(0, 2, 0), GUST, 16, 3.5)
    AbilityFX.ShakeInRadius(Origin, self.Radius * 2, 3, 0.4)

    -- Straight up. No horizontal component at all, on purpose.
    Root.AssemblyLinearVelocity = Vector3.new(0, self.Lift, 0)

    AbilityFX.Text(Origin + Vector3.new(0, 5, 0), "WAAH", LUIGI, 1.1)

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
                or Vector3.xAxis) + Vector3.new(0, 0.6, 0),
            KnockbackMagnitude = self.Knockback,
        })

        CombatUtils.ApplyEffectTo(Target, "Slipping", 1, 0.7)
        AbilityFX.ScreenFor(Target, "Woozy", 0.8, 0.9)
    end

    -- It also blows loose equipment apart, at a fraction of the Poltergust's reach.
    DeployableService.DamageInRadius(Origin, self.Radius, self.StructureDamage, self.Owner)
end

--------------------------------------------------------------------------------
-- PASSIVE — SCARED COURAGE
--------------------------------------------------------------------------------

--[=[
    Being hurt makes him run.

    Implemented through `OnHit`, which fires whenever a hitbox connects with him — so every
    source of damage triggers it, with no per-ability plumbing. He gets `Boost` seconds of
    speed, and the timer refreshes rather than stacking.

    WHY IT IS A DEFENSIVE PASSIVE: his whole kit roots him. The Poltergust pins him in place
    for three seconds and the Strobulb wants him facing a crowd, so the one thing he
    genuinely cannot afford is to be caught mid-cast. This is the apology for that.

    It also fires when he is startled by `Slipping` or `Snared`, which is the comedy version
    of the same idea.
]=]
local function ScaredCourage(self, _hitbox, _damage)
    if not RunService:IsServer() then
        return
    end

    local Char = self.Owner and self.Owner.Character
    if not Char then
        return
    end

    local Passive = self.GameplayConfig.Abilities.Courage

    --[[
        Refresh, don't stack.

        `AddSpeedFactor` is keyed by name, so calling it again replaces the factor rather
        than compounding it — but the REMOVAL has to be re-timed too, or the first hit's
        delay would cancel the boost granted by the fourth. The timestamp is the guard: only
        the most recent application is allowed to clear it.
    ]]
    local Stamp = os.clock()
    Char:SetAttribute("LuigiCourageAt", Stamp)

    PlayerSpeedManager.AddSpeedFactor(self.Owner, "Courage", Passive.SpeedMultiplier)

    local Root = Utils.Character.GetRootPart(Char)
    if Root then
        AbilityFX.Burst(Root.Position, 4, LUIGI, {Duration = 0.3, StartSize = 3, Transparency = 0.7})
    end

    task.delay(Passive.Boost, function()
        if Char and Char:GetAttribute("LuigiCourageAt") == Stamp then
            PlayerSpeedManager.RemoveSpeedFactor(self.Owner, "Courage")
        end
    end)
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Luigi: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Luigi",
        Quote = "Mario? MARIO?!",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 5600,

        Role = "Controller",
        Difficulty = 3,

        Origin = {
            TooltipText = "He won the mansion in a contest he never entered.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            Low health and low damage. He is a utility character: his job is to take away
            other people's equipment and other people's aim.
        ]]
        Health = 1100,
        BaseSpeed = 11,
        SprintSpeedMultiplier = 25.5 / 11,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 105,
            StaminaDrain = 11,
            StaminaGain = 21,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 20,
                Cooldown = 1.7,
                Duration = 0.3,
                Delay = 0.1,
                HitboxSize = Vector3.new(5, 6, 6),
                HitboxOffset = CFrame.new(0, 0, -3),

                Behaviour = BashBehaviour,
            }),

            Strobulb = Ability.New({
                Name = "Strobulb",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 15,
                Duration = 0.5,

                Range = 28,
                Angle = 85,
                Damage = 14,
                --- Dot product cutoff. 0.3 is roughly a 72 degree cone either side.
                FacingTolerance = 0.3,
                --- Short, because `Disoriented` inverts controls.
                DisorientTime = 1.4,
                SlowLevel = 2,
                SlowTime = 2.5,

                UseSound = "rbxassetid://9118823103",
                Behaviour = StrobulbBehaviour,
            }),

            Poltergust = Ability.New({
                Name = "Poltergust",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 18,
                Duration = 3,

                Duration_ = 3,
                TickRate = 0.25,
                Range = 26,
                Angle = 55,
                TickDamage = 5,
                PullPerTick = 2.5,
                --- A deployable bigger than this is bolted down. Keeps walls out of it.
                MaximumIntake = 16,

                UseSound = "rbxassetid://9046319808",
                IntakeSound = "rbxassetid://12222216",
                Behaviour = PoltergustBehaviour,
            }),

            Burst = Ability.New({
                Name = "Burst",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 16,
                Duration = 0.5,

                Lift = 72,
                Radius = 16,
                --- Almost nothing. The knockback is the ability.
                Damage = 16,
                Knockback = 20,
                StructureDamage = 35,

                UseSound = "rbxassetid://9125402735",
                Behaviour = BurstBehaviour,
            }),

            Courage = Ability.New({
                Name = "Scared Courage",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                Boost = 2.2,
                SpeedMultiplier = 1.3,
            }),
        },
    },

    OnHit = ScaredCourage,
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(70, 200, 90)\">"..Luigi.Config.Name.."</font>"
local Abilities = Luigi.GameplayConfig.Abilities

Luigi.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Luigi.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Luigi.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." has below-average damage everywhere and does not want to fight anybody.",
            "What he has instead is the only ability in the arena that <b>cleans up other people's equipment at range</b> — the Poltergust eats projectiles in flight and swallows traps, turrets and markers whole.",
            "The <b>Strobulb</b> only works on people who are looking at it. The answer to Luigi reaching for the torch is to look away.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Luigi.Config.Role,
            "Difficulty: "..string.rep("★", Luigi.Config.Difficulty)..string.rep("☆", 5 - Luigi.Config.Difficulty),
            "Price: "..tostring(Luigi.Config.Price).."$",
            "Health: "..tostring(Luigi.GameplayConfig.Health),
            "Base Speed: "..tostring(Luigi.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Luigi.GameplayConfig.BaseSpeed * Luigi.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "FLASHLIGHT BASH"},
    {
        Type = "Text",
        Text = tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds. He hits you with the torch, which is not what the torch is for.",
    },

    {Type = "Header", Text = "STROBULB  (Q)"},
    {
        Type = "Text",
        Text = {
            "A flash in a "..tostring(Abilities.Strobulb.Range).." stud cone for "..tostring(Abilities.Strobulb.Damage).." damage.",
            "<b>Only people facing the flash</b> are affected: <b>Disoriented</b> for "..tostring(Abilities.Strobulb.DisorientTime).." seconds and <b>Slowed</b> for "..tostring(Abilities.Strobulb.SlowTime)..".",
            "Your back to him means you take the damage and keep full control. Disoriented inverts your controls, which is why it is so short.",
            "Cooldown: "..tostring(Abilities.Strobulb.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "POLTERGUST  (E)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Poltergust.Duration_).." seconds of suction in a "..tostring(Abilities.Poltergust.Range).." stud cone. He is <b>rooted the whole time</b>.",
            "Everyone in it is dragged toward him and chipped for "..tostring(Abilities.Poltergust.TickDamage).." a tick, and <b>projectiles and small structures are swallowed outright</b>.",
            "The drag is pressure, not capture — you can walk out of it and you can fight him while he holds it. Stunning him stops it.",
            "Cooldown: "..tostring(Abilities.Poltergust.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "BURST  (R)"},
    {
        Type = "Text",
        Text = {
            "Fires the Poltergust at the floor. He goes <b>straight up</b> — no horizontal control at all — and everybody within "..tostring(Abilities.Burst.Radius).." studs is thrown clear and left <b>Slipping</b>.",
            "Only "..tostring(Abilities.Burst.Damage).." damage. It is an escape, not a kill.",
            "Cooldown: "..tostring(Abilities.Burst.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "SCARED COURAGE  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Being hit by anything gives him "..tostring(Abilities.Courage.Boost).." seconds at 30% more speed.",
            "His whole kit roots him in place, so the one thing he cannot afford is being caught mid-cast. This is the apology for that.",
        },
    },
}

return Luigi
