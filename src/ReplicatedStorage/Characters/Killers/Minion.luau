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
    MINION — CHAOS, WITH A PLAN BEHIND IT.

      M1  BONK     He hits you with whatever he was holding. It is never the same thing.
      Q   BANANA   Drops a banana. Stepping on it is embarrassing.
      E   GADGET   One of three, in rotation. Fart gun, freeze ray, rocket boots.
      R   BANANA!  A short frenzy. Very fast, very loud, and he can barely steer.
      P   SILLY    Looks random. Is not. Everything he does is readable if you look.

    RANDOM-LOOKING IS NOT RANDOM
    ----------------------------
    The brief asked for "random but controlled" and that distinction is the whole design.
    Nothing here rolls dice on its EFFECT — the gadget cycles in a fixed order and announces
    what is next over his head, the banana always does the same thing, and the frenzy always
    lasts the same time.

    What IS randomised is cosmetic: which improvised weapon he swings, the pitch of every
    noise, the particle colours. So he reads as chaos and plays as something you can learn,
    which is the only version of a comedy character that is fair to fight.

    EVERYTHING IS `Slipping`, NEVER A STUN
    --------------------------------------
    Same rule as Fall Guy: `Slipping` is three quarters of a second of being slow and unable
    to sprint, while keeping your abilities and your attack. Three Minions chaining bananas
    cannot hold anybody still, because `OverwriteExistingEffect` resets the same short timer
    rather than adding to it.

    WEAKNESSES
    ----------
    The lowest damage ceiling in the game. His gadget is on a 9 second rotation so two
    thirds of the time it is not the one he wants, the frenzy actively takes away his
    steering, and bananas are visible objects anybody can walk around. He is an irritant who
    wins long fights, not short ones.
]=]

local MINION = Color3.fromRGB(255, 215, 80)
local DENIM = Color3.fromRGB(70, 100, 170)
local BANANA = Color3.fromRGB(250, 235, 110)

--------------------------------------------------------------------------------
-- M1 — BONK
--------------------------------------------------------------------------------

--- Cosmetic only. See the header: what he swings is random, what it does is not.
local WEAPONS = {"a plunger", "a crowbar", "a rubber duck", "a fire extinguisher", "a chair", "a baguette"}

local function BonkBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.22, Lock = 0.45})
        return
    end

    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {
        Volume = 0.6,
        -- Wildly variable pitch. Most of why he sounds unhinged.
        MinPitch = 0.7,
        MaxPitch = 1.6,
    })

    AbilityFX.Text(Root.Position + Vector3.new(0, 4.5, 0), WEAPONS[math.random(1, #WEAPONS)], MINION, 0.8)

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Bonk",
            ExecuteOnKill = true,
            Knockback = 5,
            EffectsToApply = {
                {Name = "Slipping", Level = 1, Duration = 0.5, OverwriteExisting = true},
            },
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Text(VictimRoot.Position + Vector3.new(0, 5, 0), "BONK", MINION, 0.8)
                        AbilityFX.Sparks(VictimRoot.Position, MINION, 7, 13)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — BANANA
--------------------------------------------------------------------------------

--[=[
    A banana on the floor.

    A `DeployableService` trap with a trigger radius: anybody who walks within four studs
    slips. Four at a time, they last a long time, and they are plainly visible — walking
    around one is free. What they do is take routes away, which is the whole point of a trap
    that cannot kill anybody.

    `TriggerOnce` is true, so a banana is spent when somebody steps on it. It also has health,
    so it can be destroyed from range by anybody who would rather not go near it.
]=]
local function BananaBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.02, Duration = 0.2, Lock = 0.25})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Ground = AbilityFX.GroundAt(Root.Position + Root.CFrame.LookVector * 4, {Char})
    if not Ground then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.UseSound, Ground, {Volume = 0.6, MinPitch = 1.2, MaxPitch = 1.5})
    AbilityFX.Text(Root.Position + Vector3.new(0, 4.5, 0), "banana", BANANA, 0.8)

    DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Banana",
        Name = "Banana",
        CFrame = CFrame.new(Ground + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0),
        Size = Vector3.new(2.6, 0.7, 1.1),
        Color = BANANA,
        Material = Enum.Material.SmoothPlastic,
        Solid = false,
        Health = self.BananaHealth,
        Lifetime = self.BananaLifetime,
        Limit = self.Limit,
        TriggerRadius = self.TriggerRadius,
        TriggerOnce = true,
        OutlineColor = BANANA,
        OnTrigger = function(handle, victim: Model)
            local Humanoid = victim:FindFirstChildWhichIsA("Humanoid")
            local VictimRoot = Utils.Character.GetRootPart(victim)
            if not Humanoid or not VictimRoot then
                return
            end

            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = self.Damage,
                Reason = "Banana",
            })

            -- `Slipping`, not a stun. See the header.
            CombatUtils.ApplyEffectTo(victim, "Slipping", 2, self.SlipTime)

            AbilityFX.ScreenFor(victim, "Woozy", 1.2, 1.3)
            AbilityFX.Sound(self.SlipSound, VictimRoot.Position, {Volume = 0.8, MinPitch = 1.1, MaxPitch = 1.4})
            AbilityFX.Text(VictimRoot.Position + Vector3.new(0, 5, 0), "WHOOPS", BANANA, 1.2)
            AbilityFX.Sparks(handle.Root.Position, BANANA, 10, 16)
        end,
    })
end

--------------------------------------------------------------------------------
-- E — GADGET
--------------------------------------------------------------------------------

--[=[
    Three gadgets, in a fixed rotation.

    FIXED, not random. Which one is next is shown over his head on every use, so the
    interesting part is planning around the cycle rather than hoping. Each is genuinely
    different in what it does:

      FART GUN     A cone of knockback. No damage worth mentioning; it moves people.
      FREEZE RAY   A projectile that slows hard. His only real control.
      ROCKET BOOTS A launch straight up plus a landing shockwave. His only mobility.

    One slot, three uses, and the order is public.
]=]
local GADGETS = {"Fart Gun", "Freeze Ray", "Rocket Boots"}

local function GadgetBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.08, Duration = 0.4, Lock = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Cache = self.CharModule.GameplayConfig.Cache

    Cache.GadgetIndex = Cache.GadgetIndex or 1
    local Gadget = GADGETS[Cache.GadgetIndex]

    ----------------------------------------------------------------------------

    if Gadget == "Fart Gun" then
        local Origin = Root.Position + Vector3.new(0, 1, 0)
        local Direction = Root.CFrame.LookVector

        AbilityFX.Sound(self.FartSound, Origin, {Volume = 1, MinPitch = 0.6, MaxPitch = 1.4, RollOffMaxDistance = 160})
        AbilityFX.Cone(Origin, Direction, self.FartRange, self.FartAngle, Color3.fromRGB(150, 200, 90), {
            Rays = 9,
            Duration = 0.5,
            Width = 1.2,
        })
        AbilityFX.Smoke(Origin + Direction * 6, Color3.fromRGB(150, 200, 90), 18, 4)

        for _, Target: Model in AbilityFX.ConeTargets(Origin, Direction, self.FartRange, self.FartAngle, Char) do
            local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
            local TargetRoot = Utils.Character.GetRootPart(Target)
            if not Humanoid or not TargetRoot then
                continue
            end

            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = self.FartDamage,
                Reason = "Fart Gun",
                KnockbackDirection = Direction + Vector3.new(0, 0.5, 0),
                KnockbackMagnitude = self.FartKnockback,
            })

            CombatUtils.ApplyEffectTo(Target, "Slipping", 1, 0.6)
            AbilityFX.ScreenFor(Target, "Woozy", 0.9, 1)
        end

    ----------------------------------------------------------------------------

    elseif Gadget == "Freeze Ray" then
        local Muzzle = Root.Position + Root.CFrame.LookVector * 2.5 + Vector3.new(0, 1, 0)

        AbilityFX.Sound(self.FreezeSound, Muzzle, {Volume = 0.85, MinPitch = 1.1, MaxPitch = 1.3})

        ProjectileService.Fire({
            SourcePlayer = self.Owner,
            Name = "FreezeRay",
            Origin = Muzzle,
            Direction = Root.CFrame.LookVector,
            Speed = self.FreezeSpeed,
            Lifetime = self.FreezeRange / self.FreezeSpeed,
            Radius = 2.4,
            Damage = self.FreezeDamage,
            Reason = "Freeze Ray",
            Visual = {
                Shape = Enum.PartType.Ball,
                Size = Vector3.new(2, 2, 2),
                Color = Color3.fromRGB(150, 220, 255),
                Material = Enum.Material.Neon,
                Trail = true,
                TrailColor = Color3.fromRGB(200, 240, 255),
                Light = true,
                LightRange = 12,
            },
            OnHit = function(_projectile, humanoid: Humanoid)
                local Victim = humanoid.Parent
                if not Victim or not Victim:IsA("Model") then
                    return nil
                end

                -- Slowed hard, for a while. His only real control, and still not a root.
                CombatUtils.ApplyEffectTo(Victim, "Slowness", self.FreezeLevel, self.FreezeTime)
                CombatUtils.ApplyEffectTo(Victim, "Grounded", 1, self.FreezeTime)

                AbilityFX.ScreenFor(Victim, "Chill", self.FreezeTime, 1.3)
                AbilityFX.Tint(Victim, Color3.fromRGB(150, 220, 255), self.FreezeTime, {FillTransparency = 0.7})

                local VictimRoot = Utils.Character.GetRootPart(Victim)
                if VictimRoot then
                    AbilityFX.Burst(VictimRoot.Position, 6, Color3.fromRGB(150, 220, 255), {Duration = 0.4})
                end

                return nil
            end,
            OnImpact = function(_projectile, position: Vector3)
                AbilityFX.Burst(position, 4, Color3.fromRGB(150, 220, 255), {Duration = 0.3})
            end,
        })

    ----------------------------------------------------------------------------

    else
        AbilityFX.Sound(self.BootsSound, Root.Position, {Volume = 0.95, RollOffMaxDistance = 150})
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "WHEEE", MINION, 1.2)

        Root.AssemblyLinearVelocity = Root.CFrame.LookVector * self.BootsForward + Vector3.new(0, self.BootsLift, 0)

        AbilityFX.Flame(Root.Position - Vector3.new(0, 2, 0), Color3.fromRGB(255, 160, 60), 20)

        -- Trail going up, then a shockwave on the way down.
        task.spawn(function()
            local Elapsed = 0
            while Elapsed < self.BootsAirtime and Char and Char.Parent do
                Elapsed += task.wait(0.08)
                local Live = Utils.Character.GetRootPart(Char)
                if Live then
                    AbilityFX.Flame(Live.Position - Vector3.new(0, 2, 0), Color3.fromRGB(255, 160, 60), 5)
                end
            end

            local Live = Char and Utils.Character.GetRootPart(Char)
            if not Live then
                return
            end

            AbilityFX.Ring(Live.Position, self.BootsRadius, MINION, {Duration = 0.45})
            AbilityFX.Sound(self.LandSound, Live.Position, {Volume = 0.8})

            for _, Target: Model in CombatUtils.GetFightersInRadius(Live.Position, self.BootsRadius, Char) do
                local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
                local TargetRoot = Utils.Character.GetRootPart(Target)
                if not Humanoid or not TargetRoot then
                    continue
                end

                CommonFunctions.DamagePlayer({
                    SourcePlayer = self.Owner,
                    TargetHumanoid = Humanoid,
                    Damage = self.BootsDamage,
                    Reason = "Rocket Boots",
                    KnockbackDirection = ((TargetRoot.Position - Live.Position).Magnitude > 0
                        and (TargetRoot.Position - Live.Position).Unit
                        or Vector3.xAxis) + Vector3.new(0, 0.4, 0),
                    KnockbackMagnitude = 12,
                })

                CombatUtils.ApplyEffectTo(Target, "Slipping", 1, 0.6)
            end
        end)
    end

    ----------------------------------------------------------------------------
    -- CYCLE
    ----------------------------------------------------------------------------

    Cache.GadgetIndex = (Cache.GadgetIndex % #GADGETS) + 1
    local Next = GADGETS[Cache.GadgetIndex]

    AbilityFX.Text(Root.Position + Vector3.new(0, 6, 0), "next: "..Next, DENIM, 1.2)
    if Char then
        Char:SetAttribute("NextGadget", Next)
    end
end

--------------------------------------------------------------------------------
-- R — BANANA!
--------------------------------------------------------------------------------

--[=[
    A frenzy that costs him his steering.

    For `Duration_` seconds: much faster, much quicker attacks, and `Slipping` applied TO
    HIMSELF on a loop so he skids through every turn. That self-inflicted debuff is the whole
    balance — he is genuinely hard to control while it runs, so it is a commitment to a
    straight line rather than a free power window.

    The noise is continuous and extremely loud. Everybody knows.
]=]
local function FrenzyBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Zoom(self, 1.3)
        self:AddConnection(task.delay(self.Duration_, function()
            AbilityClient.ReleaseZoom(self)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Bonk = self.CharModule.GameplayConfig.Abilities.Slash

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 1, RollOffMaxDistance = 220})
    AbilityFX.Text(Root.Position + Vector3.new(0, 6, 0), "BANANAAAA!", BANANA, 1.6)
    AbilityFX.Ring(Root.Position, 12, BANANA, {Duration = 0.5})

    local OriginalCooldown = Bonk.Cooldown
    local OriginalDamage = Bonk.Damage

    Bonk.Cooldown = self.FrenzyCooldown
    Bonk.Damage = self.FrenzyDamage

    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.SpeedMultiplier)

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.Duration_ and Char and Char.Parent do
            Elapsed += task.wait(0.4)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            --[=[
                HE SLIPS TOO.

                Not a bug — this is the cost. `Slipping` takes his sprint and some speed,
                which fights the frenzy's own speed bonus and makes him skid rather than
                turn. He is fast and nearly uncontrollable, which is the character.

                His own `Slipping` is kept to level 1 so the net effect is still faster than
                normal; the point is the loss of control, not the loss of pace.
            ]=]
            CombatUtils.ApplyEffectTo(Char, "Slipping", 1, 0.5)

            AbilityFX.Sound(self.LoopSound, Live.Position, {
                Volume = 0.6,
                MinPitch = 1.3,
                MaxPitch = 1.8,
                RollOffMaxDistance = 180,
            })
            AbilityFX.Sparks(Live.Position + Vector3.new(0, 1.5, 0), BANANA, 5, 10)
        end

        --[[
            Raw path, not a Janitor thread: the ability table is a per-player copy that
            survives onto his next body, so a cancelled restore would leave him permanently
            frenzied.
        ]]
        Bonk.Cooldown = OriginalCooldown
        Bonk.Damage = OriginalDamage
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
    end)
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Minion: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Minion",
        Quote = "Bello!",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 3300,

        Role = "Disruptor",
        Difficulty = 2,

        Origin = {
            TooltipText = "There are more of them.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            The lowest damage ceiling in the game. He is an irritant who wins long fights,
            and he loses every short one.
        ]]
        Health = 1200,
        BaseSpeed = 11.5,
        SprintSpeedMultiplier = 26 / 11.5,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 110,
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

                Damage = 19,
                Cooldown = 1.5,
                Duration = 0.26,
                Delay = 0.08,
                HitboxSize = Vector3.new(5, 5.5, 4.5),
                HitboxOffset = CFrame.new(0, 0, -2.4),

                Behaviour = BonkBehaviour,
            }),

            Banana = Ability.New({
                Name = "Banana",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 6,
                Duration = 0.2,

                Damage = 14,
                SlipTime = 0.75,
                TriggerRadius = 4,
                BananaHealth = 15,
                BananaLifetime = 45,
                Limit = 4,

                UseSound = "rbxassetid://12222216",
                SlipSound = "rbxassetid://12222030",
                Behaviour = BananaBehaviour,
            }),

            Gadget = Ability.New({
                Name = "Gadget",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 9,
                Duration = 0.5,

                --- Fart gun: knockback, basically no damage.
                FartRange = 24,
                FartAngle = 80,
                FartDamage = 10,
                FartKnockback = 22,

                --- Freeze ray: his only real control.
                FreezeSpeed = 120,
                FreezeRange = 90,
                FreezeDamage = 18,
                FreezeLevel = 3,
                FreezeTime = 3.5,

                --- Rocket boots: his only mobility.
                BootsLift = 70,
                BootsForward = 35,
                BootsAirtime = 1,
                BootsRadius = 13,
                BootsDamage = 24,

                FartSound = "rbxassetid://9046319808",
                FreezeSound = "rbxassetid://12222030",
                BootsSound = "rbxassetid://9118823103",
                LandSound = "rbxassetid://9046319808",
                Behaviour = GadgetBehaviour,
            }),

            Frenzy = Ability.New({
                Name = "Frenzy",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 42,
                Duration = 0.5,

                Duration_ = 7,
                FrenzyCooldown = 0.6,
                FrenzyDamage = 12,
                SpeedMultiplier = 1.5,
                DisableSlashOnPerform = false,

                UseSound = "rbxassetid://9125402735",
                LoopSound = "rbxassetid://12222030",
                Behaviour = FrenzyBehaviour,
            }),

            Silly = Ability.New({
                Name = "Silly",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(255, 215, 80)\">"..Minion.Config.Name.."</font>"
local Abilities = Minion.GameplayConfig.Abilities

Minion.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Minion.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Minion.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." has the lowest damage ceiling in the arena. He wins long fights by being impossible to ignore and loses every short one.",
            "He looks random and he is not: the gadget cycles in a <b>fixed order</b> and tells you what is next, the banana always does the same thing, and the frenzy always lasts the same time.",
            "Everything he inflicts is <b>Slipping</b> — slow and no sprinting for three quarters of a second, with your abilities and your attack intact. Never a stun.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Minion.Config.Role,
            "Difficulty: "..string.rep("★", Minion.Config.Difficulty)..string.rep("☆", 5 - Minion.Config.Difficulty),
            "Price: "..tostring(Minion.Config.Price).."$",
            "Health: "..tostring(Minion.GameplayConfig.Health),
            "Base Speed: "..tostring(Minion.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Minion.GameplayConfig.BaseSpeed * Minion.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "BONK"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds, and it leaves you <b>Slipping</b>.",
            "What he is holding is different every swing. It makes no difference to the damage.",
        },
    },

    {Type = "Header", Text = "BANANA  (Q)"},
    {
        Type = "Text",
        Text = {
            "Drops a banana. Stepping within "..tostring(Abilities.Banana.TriggerRadius).." studs of it costs "..tostring(Abilities.Banana.Damage).." damage and "..tostring(Abilities.Banana.SlipTime).." seconds of <b>Slipping</b>.",
            tostring(Abilities.Banana.Limit).." at a time, lasting "..tostring(Abilities.Banana.BananaLifetime).." seconds. They are plainly visible, walking around one is free, and they can be destroyed from range.",
            "Cooldown: "..tostring(Abilities.Banana.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "GADGET  (E)"},
    {
        Type = "Text",
        Text = {
            "<b>A fixed rotation of three.</b> What is next floats over his head.",
            "<b>Fart Gun</b> — a "..tostring(Abilities.Gadget.FartRange).." stud cone of heavy knockback for only "..tostring(Abilities.Gadget.FartDamage).." damage. It moves people.",
            "<b>Freeze Ray</b> — <b>Slowness "..tostring(Abilities.Gadget.FreezeLevel).."</b> and <b>Grounded</b> for "..tostring(Abilities.Gadget.FreezeTime).." seconds. His only real control.",
            "<b>Rocket Boots</b> — launches him up and forward, landing for "..tostring(Abilities.Gadget.BootsDamage).." damage across "..tostring(Abilities.Gadget.BootsRadius).." studs. His only mobility.",
            "Cooldown: "..tostring(Abilities.Gadget.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "FRENZY  (R)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Frenzy.Duration_).." seconds at 50% more speed, with his bonk dropping to "..tostring(Abilities.Frenzy.FrenzyDamage).." damage every "..tostring(Abilities.Frenzy.FrenzyCooldown).." seconds.",
            "<b>He applies Slipping to himself the whole time</b>, so he skids through every turn. It is a commitment to a straight line, not a free power window.",
            "It is also extremely loud.",
            "Cooldown: "..tostring(Abilities.Frenzy.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "SILLY  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "The animations, the noises and the improvised weapons are all randomised. <b>None of his mechanics are.</b>",
            "He reads as chaos and plays as something you can learn, which is the only version of this that is fair to fight.",
        },
    },
}

return Minion
