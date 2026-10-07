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
local ProjectileService = require(ReplicatedStorage.Modules.ProjectileService)
local SummonService = require(ReplicatedStorage.Modules.SummonService)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    GUBBY — small, delighted, extremely fast, absolutely a problem.

    AN ORIGINAL CHARACTER, and its identity is unchanged: the comic relief that is genuinely
    frightening in a free-for-all, with the highest base speed in the arena and one of the
    lowest health pools. Everyone else fights over the middle of the map; Gubby fights over
    the ceiling and the walls.

      M1  BITE          A ridiculous amount of teeth for something that size.
      Q   GUBBY BLAST   It produces a gun. Nobody knows where from. It fires once.
      E   GUBBY RAGE    Very fast, very weak attacks. Shreds the wounded, loses to the healthy.
      R   GUBBY SWARM   A FEW more of them. They are not better than it, there are just more.
      F   POUNCE        A leap with a damaging landing. Chainable.
      P   GUNK TRAIL    It leaves sticky mess behind it, and only it can cross it quickly.

    WHAT CHANGED THIS PASS
    ----------------------
    `Pounce`, `Gunk` and `Frenzy` were the original kit and all three survive. `Frenzy` is
    now called `Gubby Rage`, which is the same ability under the name the design brief uses.
    `Gunk` has become the PASSIVE — it was always an expression of what Gubby is rather than
    a thing it decides to do, and moving it frees a slot for the gun and the swarm.

    THE GUN HAS A TELL
    ------------------
    `Gubby Blast` is the hardest-hitting single projectile on the roster for its cooldown,
    which is exactly as absurd as it should be — so it gets a 0.55 second aim-up during which
    Gubby is rooted, a laser sight drawn on the floor showing precisely where it is pointing,
    and a sound. It is not a hitscan surprise; it is a cartoon rabbit visibly deciding to
    shoot you.
]=]

local GUBBY = Color3.fromRGB(255, 180, 200)
local GUNK = Color3.fromRGB(140, 220, 60)

--------------------------------------------------------------------------------
-- M1 — BITE
--------------------------------------------------------------------------------

local function BiteBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.06, Duration = 0.18, Lock = 0.35})
        return
    end

    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.6, MinPitch = 1.3, MaxPitch = 1.6})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Bite",
            ExecuteOnKill = true,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, GUBBY, 8, 12)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — GUBBY BLAST
--------------------------------------------------------------------------------

--[=[
    It produces a gun.

    THE AIM-UP IS THE BALANCE. 72 damage from one round on a 15 second cooldown is a lot for
    a character this fast, so the cost is 0.55 seconds of being rooted in the open with a
    laser sight on the floor announcing the line. Gubby is a 980 health character; standing
    still for half a second in a free-for-all is a real price.

    It is NOT hitscan. The round travels, fast but visible, and the laser sight shows where
    it will go before it goes there — so it is dodged by not being on the line when the
    timer runs out.
]=]
local function BlastBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        -- Narrows hard. The only ability of its own that makes it hold still.
        AbilityClient.Zoom(self, 0.82)
        self:AddConnection(task.delay(self.Aim, function()
            AbilityClient.ReleaseZoom(self)
            AbilityClient.Shake(2.5, 0.3)
        end))
        AbilityClient.LockHead(self, self.Aim + 0.2)
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.AimSound, Root.Position, {Volume = 0.7, MinPitch = 1.2, MaxPitch = 1.35})
    AbilityFX.Text(Root.Position + Vector3.new(0, 4.5, 0), "hehe", GUBBY, self.Aim)

    -- Rooted while aiming. `Snared` so it is visible in its own effects list, and so it
    -- keeps its basic attack — it is holding still, not helpless.
    CombatUtils.ApplyEffectTo(Char, "Snared", 5, self.Aim)

    ----------------------------------------------------------------------------
    -- THE LASER SIGHT
    ----------------------------------------------------------------------------

    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Aim and Char and Char.Parent do
            Elapsed += task.wait(0.06)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            local From = Live.Position + Vector3.new(0, 1, 0)
            AbilityFX.Beam(From, From + Live.CFrame.LookVector * self.Range, Color3.fromRGB(255, 50, 50), {
                Width = 0.15,
                Duration = 0.1,
                -- Gets brighter as the shot gets closer.
                Transparency = 0.75 - 0.5 * (Elapsed / self.Aim),
            })
        end
    end)

    ----------------------------------------------------------------------------
    -- THE SHOT
    ----------------------------------------------------------------------------

    task.delay(self.Aim, function()
        if not Char or not Char.Parent then
            return
        end

        local Live = Utils.Character.GetRootPart(Char)
        if not Live then
            return
        end

        -- Interrupted while aiming: no shot. Stunning an aiming Gubby is the hard counter.
        if Char.Effects and Char.Effects:FindFirstChild("Stunned") then
            AbilityFX.Text(Live.Position + Vector3.new(0, 4.5, 0), "aw", GUBBY, 0.8)
            return
        end

        local Muzzle = Live.Position + Live.CFrame.LookVector * 2.5 + Vector3.new(0, 1, 0)

        AbilityFX.Sound(self.UseSound, Muzzle, {Volume = 1, RollOffMaxDistance = 180})
        AbilityFX.Burst(Muzzle, 5, Color3.fromRGB(255, 240, 180), {Duration = 0.2})
        AbilityFX.Sparks(Muzzle, Color3.fromRGB(255, 220, 120), 14, 30)

        -- Visible recoil: it is too small for this gun.
        Live.AssemblyLinearVelocity = -Live.CFrame.LookVector * 22 + Vector3.new(0, 8, 0)

        ProjectileService.Fire({
            SourcePlayer = self.Owner,
            Name = "GubbyRound",
            Origin = Muzzle,
            Direction = Live.CFrame.LookVector,
            Speed = self.Speed,
            Lifetime = self.Range / self.Speed,
            Radius = 2,
            Damage = self.Damage,
            Reason = self.Name,
            Knockback = 6,
            FaceTravel = true,
            Visual = {
                Shape = Enum.PartType.Block,
                Size = Vector3.new(0.5, 0.5, 2.5),
                Color = Color3.fromRGB(255, 230, 140),
                Material = Enum.Material.Neon,
                Trail = true,
                TrailColor = Color3.fromRGB(255, 180, 60),
                Light = true,
                LightRange = 10,
            },
            OnHit = function(_projectile, humanoid: Humanoid)
                local Victim = humanoid.Parent
                local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                if VictimRoot then
                    AbilityFX.Shockwave(VictimRoot.Position, 7, Color3.fromRGB(255, 220, 120), 16)
                    AbilityFX.ShakeFor(Victim, 3, 0.4)
                end
                return nil
            end,
            OnImpact = function(_projectile, position: Vector3)
                AbilityFX.Sparks(position, Color3.fromRGB(255, 220, 120), 12, 28)
            end,
        })
    end)
end

--------------------------------------------------------------------------------
-- E — GUBBY RAGE
--------------------------------------------------------------------------------

--[=[
    Seven seconds of very fast, very weak attacks. Previously called `Frenzy`.

    It replaces the bite's cooldown and damage with 0.45 seconds and 8 damage — about 18
    damage per second against a normal 11, so it is a 60% damage increase that CANNOT finish
    a healthy opponent before they finish Gubby. It shreds the wounded and loses a straight
    trade with anybody at full health, every single time.

    The restore is the fiddly part and it is handled carefully: the numbers are captured
    before they are changed and put back by a RAW delay, so dying mid-rage cannot leave a
    Gubby permanently stuck with an 8 damage bite.
]=]
local function RageBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Zoom(self, 1.2)
        self:AddConnection(task.delay(self.Duration_, function()
            AbilityClient.ReleaseZoom(self)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Bite = self.CharModule.GameplayConfig.Abilities.Slash

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 1, RollOffMaxDistance = 140})
    AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "HEHEHE", GUBBY, 1.4)
    AbilityFX.Ring(Root.Position, 9, GUBBY, {Duration = 0.5})

    local OriginalCooldown = Bite.Cooldown
    local OriginalDamage = Bite.Damage

    Bite.Cooldown = self.RageCooldown
    Bite.Damage = self.RageDamage

    CommonFunctions.ApplyEffect({
        TargetHumanoid = self.OwnerProperties.Humanoid,
        EffectSettings = {Name = "Speed", Level = self.SpeedLevel, Duration = self.Duration_},
    })

    -- Pink mist off it for the duration, so everybody can see it is raging.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Duration_ and Char and Char.Parent do
            Elapsed += task.wait(0.2)
            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                AbilityFX.Sparks(Live.Position + Vector3.new(0, 1, 0), GUBBY, 4, 8)
            end
        end
    end)

    --[[
        Raw delay. `AddConnection` would hand this to the character's Janitor, and dying
        during the rage would cancel the restore — leaving the ability table (which is a
        per-player copy, so it persists for this player's next body) with the rage numbers
        baked in permanently.
    ]]
    task.delay(self.Duration_, function()
        Bite.Cooldown = OriginalCooldown
        Bite.Damage = OriginalDamage
    end)
end

--------------------------------------------------------------------------------
-- R — GUBBY SWARM
--------------------------------------------------------------------------------

--[=[
    A FEW more Gubbies. Four, capped.

    Half scale, 30 health, 7 damage, and they walk at 10 — slower than every killer in the
    game. The brief was explicit that this must not be dozens and must not destroy
    performance, and `SummonService` enforces both: a hard per-player cap of six across all
    summons, one shared 4 Hz think loop for every minion in the server, and no pathfinding at
    all.

    What they are FOR is not damage. Four tiny Gubbies converging on somebody is a
    distraction that costs swings to clear, and every swing spent on a minion is a swing not
    spent on Gubby.
]=]
local function SwarmBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.1, Duration = 0.5})
        return
    end

    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 0.95, MinPitch = 1.3, MaxPitch = 1.5})
    AbilityFX.Text(Origin + Vector3.new(0, 5.5, 0), "friends!", GUBBY, 1.2)
    AbilityFX.Ring(Origin, 12, GUBBY, {Duration = 0.5})

    SummonService.Summon({
        SourcePlayer = self.Owner,
        Position = Origin,
        Count = self.Count,
        Name = "Gubby",
        Lifetime = self.MinionLifetime,
        Health = self.MinionHealth,
        Speed = self.MinionSpeed,
        --- Half size. They are small even for Gubbies.
        Scale = 0.5,
        Damage = self.MinionDamage,
        AttackRange = 5,
        AttackInterval = 1.2,
        Reason = "Gubby Swarm",
        SeekRadius = 60,
        Appearance = {
            Color = GUBBY,
            HeadColor = Color3.fromRGB(255, 220, 230),
            Material = Enum.Material.SmoothPlastic,
            Glow = GUBBY,
        },
        OnSpawn = function(minion)
            if minion.Model and minion.Model.PrimaryPart then
                AbilityFX.Sound("rbxassetid://9125402735", minion.Model.PrimaryPart.Position, {
                    Volume = 0.4,
                    MinPitch = 1.6,
                    MaxPitch = 1.9,
                })
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- F — POUNCE
--------------------------------------------------------------------------------

--[=[
    A leap with a damaging landing. Unchanged from the original kit.

    Chainable on a short cooldown — the intended play is bouncing around a fight rather than
    committing to a line, which is what makes its movement feel different from every dash on
    the roster.
]=]
local function PounceBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.15, Duration = self.Duration})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.8, MinPitch = 1.3, MaxPitch = 1.6})

    -- Up and forward. The vertical kick is what makes it a hop rather than a dash.
    Root.AssemblyLinearVelocity = Root.CFrame.LookVector * self.LeapPower + Vector3.new(0, self.LeapHeight, 0)

    task.delay(self.Duration, function()
        if not Char or not Char.Parent then
            return
        end

        local Live = Utils.Character.GetRootPart(Char)
        if not Live then
            return
        end

        local Origin = Live.Position

        AbilityFX.Sound(self.LandSound, Origin, {Volume = 0.85})
        AbilityFX.Ring(Origin, self.LandRadius, GUBBY, {Duration = 0.4})
        AbilityFX.ShakeInRadius(Origin, self.LandRadius * 1.5, 2, 0.3)

        for _, Target: Model in CombatUtils.GetFightersInRadius(Origin, self.LandRadius, Char) do
            local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
            local TargetRoot = Utils.Character.GetRootPart(Target)
            if not Humanoid or not TargetRoot then
                continue
            end

            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = self.LandDamage,
                Reason = self.Name,
                KnockbackDirection = (TargetRoot.Position - Origin).Magnitude > 0
                    and (TargetRoot.Position - Origin).Unit
                    or Vector3.yAxis,
                KnockbackMagnitude = 8,
            })
        end
    end)
end

--------------------------------------------------------------------------------
-- PASSIVE — GUNK TRAIL
--------------------------------------------------------------------------------

--[=[
    It leaves a mess, and only it can cross the mess quickly.

    This was the `Gunk` ability. It is a passive now because it was always a description of
    what Gubby IS rather than a decision it makes — and as a passive it rewards movement
    continuously instead of once every twenty seconds, which suits the fastest character in
    the game far better.

    While SPRINTING, it drops a patch of gunk behind it every second. Anyone else standing in
    one is `Snared` lightly and `Grounded`; Gubby is 30% faster inside its own.

    THE CONDITION ON SPRINTING IS THE BALANCE. It cannot stand in a doorway manufacturing
    gunk; it has to be running, which means the trail marks where it has BEEN — useful to
    chase into, and useful to Gubby on the way back through.
]=]
local function GunkInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    self:AddConnection(task.spawn(function()
        local Boosted = false

        -- Each entry is {Position, Radius, ExpiresAt}. A plain list rather than zones,
        -- because these are tiny and numerous and `CreateZone` spawns a thread each.
        local Patches = {}

        while Char and Char.Parent do
            task.wait(self.Interval)

            local Root = Utils.Character.GetRootPart(Char)
            if not Root then
                continue
            end

            ----------------------------------------------------------------
            -- DROP
            ----------------------------------------------------------------

            --[[
                Only while actually moving at speed.

                Read from the root's velocity rather than from a sprint flag, so it covers
                being moved fast by anything — its own Pounce included — and cannot be
                faked by holding a key while standing still.
            ]]
            if Root.AssemblyLinearVelocity.Magnitude >= self.MinimumSpeed then
                local Ground = AbilityFX.GroundAt(Root.Position, {Char})

                if Ground and #Patches < self.MaximumPatches then
                    local Splat = AbilityFX.Part({
                        Name = "Gunk",
                        Shape = Enum.PartType.Cylinder,
                        Size = Vector3.new(0.3, self.Radius * 2, self.Radius * 2),
                        CFrame = CFrame.new(Ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
                        Color = GUNK,
                        Material = Enum.Material.Slate,
                        Transparency = 0.35,
                    })
                    Splat.Parent = AbilityFX.Folder()
                    game:GetService("Debris"):AddItem(Splat, self.PatchDuration)

                    table.insert(Patches, {
                        Position = Ground,
                        Radius = self.Radius,
                        ExpiresAt = os.clock() + self.PatchDuration,
                    })
                end
            end

            ----------------------------------------------------------------
            -- TICK
            ----------------------------------------------------------------

            local InOwn = false

            for Index = #Patches, 1, -1 do
                local Patch = Patches[Index]

                if os.clock() >= Patch.ExpiresAt then
                    table.remove(Patches, Index)
                    continue
                end

                if (Root.Position - Patch.Position).Magnitude <= Patch.Radius then
                    InOwn = true
                end

                for _, Target: Model in CombatUtils.GetFightersInRadius(Patch.Position, Patch.Radius, Char) do
                    CombatUtils.ApplyEffectTo(Target, "Snared", 1, self.Interval + 0.3)
                    CombatUtils.ApplyEffectTo(Target, "Grounded", 1, self.Interval + 0.5)
                end
            end

            ----------------------------------------------------------------
            -- ITS OWN BOOST
            ----------------------------------------------------------------

            if InOwn and not Boosted then
                Boosted = true
                PlayerSpeedManager.AddSpeedFactor(self.Owner, "GubbyGunk", self.OwnerBoost)
            elseif not InOwn and Boosted then
                Boosted = false
                PlayerSpeedManager.RemoveSpeedFactor(self.Owner, "GubbyGunk")
            end
        end

        -- The loop ending is the only cleanup this needs, and it covers every way it can
        -- end: death, round end, character removal.
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, "GubbyGunk")
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Gubby: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Gubby",
        Quote = "hehe. hehehe. HEHEHE.",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 1250,

        Role = "Chaser",
        Difficulty = 3,

        Origin = {
            TooltipText = "Nobody let it in. It was just there.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            --- Tiny, quick, far too many of them.
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        -- Unchanged: fastest thing in the arena, and one of the easiest to kill.
        Health = 980,
        BaseSpeed = 12.2,
        SprintSpeedMultiplier = 30 / 12.2,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 95,
            StaminaDrain = 12,
            StaminaGain = 26,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 16,
                Cooldown = 1.5,
                Duration = 0.28,
                Delay = 0.06,
                HitboxSize = Vector3.new(4.5, 5, 4),
                HitboxOffset = CFrame.new(0, 0, -2.2),

                Behaviour = BiteBehaviour,
            }),

            Blast = Ability.New({
                Name = "Blast",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 15,
                Duration = 0.75,

                --- Rooted for this long with a laser sight on the floor. The whole cost.
                Aim = 0.55,
                Damage = 72,
                Speed = 180,
                Range = 140,

                AimSound = "rbxassetid://12222030",
                UseSound = "rbxassetid://9046319808",
                Behaviour = BlastBehaviour,
            }),

            Rage = Ability.New({
                Name = "Rage",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 45,
                Duration = 0.5,

                Duration_ = 7,
                RageCooldown = 0.45,
                RageDamage = 8,
                SpeedLevel = 2,
                DisableSlashOnPerform = false,

                UseSound = "rbxassetid://9118823103",
                Behaviour = RageBehaviour,
            }),

            Swarm = Ability.New({
                Name = "Swarm",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 38,
                Duration = 0.5,

                Count = 4,
                MinionHealth = 30,
                MinionDamage = 7,
                MinionSpeed = 10,
                MinionLifetime = 14,

                UseSound = "rbxassetid://9125402735",
                Behaviour = SwarmBehaviour,
            }),

            Pounce = Ability.New({
                Name = "Pounce",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 9,
                Duration = 0.9,

                LeapPower = 62,
                LeapHeight = 44,
                LandDamage = 20,
                LandRadius = 14,

                UseSound = "rbxassetid://9125402735",
                LandSound = "rbxassetid://9083889906",
                DisableSlashOnPerform = false,

                Behaviour = PounceBehaviour,
            }),

            Gunk = Ability.New({
                Name = "Gunk Trail",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                Interval = 1,
                Radius = 7,
                PatchDuration = 8,
                MaximumPatches = 8,
                --- Studs per second it has to be moving to leave a trail.
                MinimumSpeed = 18,
                OwnerBoost = 1.3,

                ExtraInit = GunkInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(255, 180, 200)\">"..Gubby.Config.Name.."</font>"
local Abilities = Gubby.GameplayConfig.Abilities

Gubby.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Gubby.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Gubby.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." is the fastest thing in the arena and one of the easiest to kill.",
            "It bounces around a fight rather than committing to one, leaves sticky gunk everywhere it runs, and occasionally produces a gun from somewhere.",
            "It loses a straight trade with a healthy opponent every single time. What it does instead is never be where you swung.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Gubby.Config.Role,
            "Difficulty: "..string.rep("★", Gubby.Config.Difficulty)..string.rep("☆", 5 - Gubby.Config.Difficulty),
            "Price: "..tostring(Gubby.Config.Price).."$",
            "Health: "..tostring(Gubby.GameplayConfig.Health),
            "Base Speed: "..tostring(Gubby.GameplayConfig.BaseSpeed).."  (highest)",
            "Sprint Speed: "..tostring(math.round(Gubby.GameplayConfig.BaseSpeed * Gubby.GameplayConfig.SprintSpeedMultiplier * 10) / 10).."  (highest)",
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "BITE"},
    {
        Type = "Text",
        Text = tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds. Short reach — it is very small.",
    },

    {Type = "Header", Text = "BLAST  (Q)"},
    {
        Type = "Text",
        Text = {
            "It produces a gun and fires one round for <b>"..tostring(Abilities.Blast.Damage).." damage</b>.",
            "It is rooted for "..tostring(Abilities.Blast.Aim).." seconds first, with a red laser sight drawn along the exact line of the shot. The round travels — it is not hitscan.",
            "<b>Stunning it while it aims cancels the shot entirely.</b>",
            "Cooldown: "..tostring(Abilities.Blast.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "RAGE  (E)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Rage.Duration_).." seconds where its bite drops to "..tostring(Abilities.Rage.RageDamage).." damage but fires every "..tostring(Abilities.Rage.RageCooldown).." seconds, plus <b>Speed II</b>.",
            "Roughly 60% more damage per second — enough to shred somebody already hurt, and never enough to beat somebody healthy.",
            "Cooldown: "..tostring(Abilities.Rage.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "SWARM  (R)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Swarm.Count).." tiny Gubbies. "..tostring(Abilities.Swarm.MinionHealth).." health, "..tostring(Abilities.Swarm.MinionDamage).." damage, gone after "..tostring(Abilities.Swarm.MinionLifetime).." seconds.",
            "They walk slower than every killer in the game and die to one hit. Every swing spent clearing them is a swing not spent on Gubby.",
            "Cooldown: "..tostring(Abilities.Swarm.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "POUNCE  (F)"},
    {
        Type = "Text",
        Text = {
            "A leap that lands for "..tostring(Abilities.Pounce.LandDamage).." damage across "..tostring(Abilities.Pounce.LandRadius).." studs.",
            "Short enough a cooldown to chain. It can keep its bite while pouncing.",
            "Cooldown: "..tostring(Abilities.Pounce.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "GUNK TRAIL  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "While it is <b>moving fast</b> it drops gunk behind it. Anyone else standing in a patch is lightly <b>Snared</b> and <b>Grounded</b>; Gubby is 30% faster in its own.",
            "It cannot manufacture gunk standing still, so the trail marks where it has been — which is information for you as much as an advantage for it.",
        },
    },
}

return Gubby
