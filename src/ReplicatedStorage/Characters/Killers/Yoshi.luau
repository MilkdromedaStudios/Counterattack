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

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

--[=[
    YOSHI — CAPTURE AND CONTROL.

      M1  HEAD STRIKE   A headbutt, then a tail sweep. Alternates on every swing.
      Q   TONGUE        A long tongue. Drags whoever it catches toward him.
      E   EGG THROW     An arcing egg that bursts. His only ranged damage.
      R   FLUTTER JUMP  Up, and then a slow hover he steers.
      F   GROUND POUND  Drops out of the hover. Area damage and a slow.
      P   SURE FOOTED   Good movement and modest damage. He controls, he does not burst.

    HE DOES NOT SWALLOW ANYBODY
    ---------------------------
    The brief was explicit and it is the right call: `Tongue` DRAGS. It pulls the victim most
    of the way toward him and leaves them `Snared` briefly, and that is all. Removing
    somebody from the game for a few seconds is a stun with a costume on, and this game has
    `Stunned` for the honest version.

    FLUTTER AND POUND ARE ONE DECISION
    ----------------------------------
    `Flutter Jump` puts him in a slow steerable hover, and `Ground Pound` is only worth
    using FROM it — the damage scales with how far he falls. So the pair is a single play
    with a choice in the middle: where to come down, and whether to wait for somebody to walk
    under you.

    He can also just use the hover to cross a gap, which is why it is on its own key.

    WEAKNESSES
    ----------
    His damage is modest everywhere — the lowest ceiling on the roster for a melee character
    — and the tongue is a slow, visible projectile with a long cooldown. He wins by deciding
    where fights happen, not by winning them quickly.
]=]

local YOSHI = Color3.fromRGB(90, 200, 90)
local SHELL = Color3.fromRGB(230, 90, 60)
local EGG = Color3.fromRGB(240, 245, 235)

--------------------------------------------------------------------------------
-- M1 — HEAD STRIKE
--------------------------------------------------------------------------------

--[=[
    Alternates between a headbutt and a tail sweep.

    Two attacks on one button, swapping every swing — a narrow forward headbutt, then a wide
    tail sweep that hits everybody around him. It has no combo window and no reset: it simply
    alternates, so the player always knows which one is next and can time the wide one for
    when two people are on him.

    Simpler than Knuckles' three-hit chain on purpose. His basic attack is a rhythm, not a
    resource.
]=]
local function StrikeBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.25, Lock = 0.5})
        return
    end

    local Root = self.OwnerProperties.HRP
    local Cache = self.CharModule.GameplayConfig.Cache

    Cache.TailNext = not Cache.TailNext
    local Tail = Cache.TailNext

    AbilityFX.SoundOn(Root, self.UseSound, {
        Volume = 0.6,
        MinPitch = Tail and 0.9 or 1.15,
        MaxPitch = Tail and 1.0 or 1.3,
    })

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        if Tail then
            -- A sweep all the way round him.
            AbilityFX.Ring(Root.Position, 6, YOSHI, {Duration = 0.25, Thickness = 0.5})
        else
            AbilityFX.Burst(Root.Position + Root.CFrame.LookVector * 3.5, 3, YOSHI, {Duration = 0.2, StartSize = 1.5})
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = Tail and CFrame.new() or self.HitboxOffset,
            Size = Tail and self.TailHitbox or self.HitboxSize,
            Time = self.Duration,
            Damage = Tail and self.TailDamage or self.Damage,
            Reason = Tail and "Tail Sweep" or "Head Strike",
            ExecuteOnKill = true,
            Knockback = Tail and 8 or 3,
            -- The tail goes all the way round and catches everybody.
            HitMultiple = Tail,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, YOSHI, 7, 13)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — TONGUE
--------------------------------------------------------------------------------

local function TongueBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.06, Duration = 0.4, Lock = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position + Vector3.new(0, 1, 0) + Root.CFrame.LookVector * 2

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 0.85, MinPitch = 1.05, MaxPitch = 1.2})

    ProjectileService.Fire({
        SourcePlayer = self.Owner,
        Name = "Tongue",
        Origin = Origin,
        Direction = Root.CFrame.LookVector,
        Speed = self.Speed,
        Lifetime = self.Range / self.Speed,
        Radius = 2.6,
        Damage = self.Damage,
        Reason = self.Name,
        FaceTravel = true,
        Visual = {
            Shape = Enum.PartType.Block,
            Size = Vector3.new(1.1, 0.7, 4),
            Color = Color3.fromRGB(230, 120, 150),
            Material = Enum.Material.SmoothPlastic,
        },
        OnStep = function(projectile, _delta, position)
            -- Drawn back to his mouth, which is what makes it a tongue and not a dart.
            if Root and Root.Parent and projectile.Age % 0.05 < 0.03 then
                AbilityFX.Beam(Root.Position + Vector3.new(0, 1, 0), position, Color3.fromRGB(230, 120, 150), {
                    Width = 0.9,
                    Duration = 0.08,
                    Transparency = 0.2,
                    Material = Enum.Material.SmoothPlastic,
                })
            end
        end,
        OnHit = function(_projectile, humanoid: Humanoid)
            local Victim = humanoid.Parent
            if not Victim or not Victim:IsA("Model") then
                return nil
            end

            local VictimRoot = Utils.Character.GetRootPart(Victim)
            local Live = Char and Utils.Character.GetRootPart(Char)
            if not VictimRoot or not Live then
                return nil
            end

            --[[
                DRAGGED, NOT SWALLOWED.

                `PullFraction` of the gap, stopping six studs short so nobody ends up inside
                his collision and gets flung by the solver. Plus a short `Snared`, which
                leaves them their abilities and their basic attack.
            ]]
            local Delta = Live.Position - VictimRoot.Position
            local Distance = math.max(Delta.Magnitude - 6, 0)

            CombatUtils.Blink(Victim, VictimRoot.Position + Delta.Unit * Distance * self.PullFraction)
            CombatUtils.ApplyEffectTo(Victim, "Snared", 2, self.SnareTime)

            AbilityFX.Ring(Live.Position, 8, YOSHI, {Duration = 0.4})
            AbilityFX.Sound(self.CatchSound, Live.Position, {Volume = 0.9, MinPitch = 1.1, MaxPitch = 1.25})
            AbilityFX.ShakeFor(Victim, 2, 0.3)

            return nil
        end,
    })
end

--------------------------------------------------------------------------------
-- E — EGG THROW
--------------------------------------------------------------------------------

--[=[
    An arcing egg.

    `ProjectileService.Lob` solves the launch velocity to land on a point, so the egg is
    actually aimed rather than thrown at a guessed angle. It bounces twice before bursting,
    which makes it genuinely different from every flat projectile on the roster: it threatens
    around corners and off floors, and where it ends up is a skill.

    It bursts for area damage and a slow on impact, or on its own after the bounces.
]=]
local function EggBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.03, Duration = 0.35, Lock = 0.45})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.75})

    --[[
        Aimed at the nearest fighter if there is one, otherwise at the ground ahead.

        Aiming at a target rather than a cursor keeps this server-authoritative: asking the
        client for its mouse position means yielding on a client call inside an ability,
        which a hostile client can stall indefinitely.
    ]]
    local Target = CombatUtils.GetClosestFighter(Root.Position, self.Range, Char)
    local Aim = Target and Utils.Character.GetRootPart(Target)
    local Landing = Aim and Aim.Position
        or (AbilityFX.GroundAt(Root.Position + Root.CFrame.LookVector * 30, {Char})
            or Root.Position + Root.CFrame.LookVector * 30)

    local function Burst(position: Vector3)
        AbilityFX.Burst(position, self.BurstRadius, EGG, {Duration = 0.35})
        AbilityFX.Ring(position, self.BurstRadius, YOSHI, {Duration = 0.4})
        AbilityFX.Sound(self.BurstSound, position, {Volume = 0.8, MinPitch = 1.0, MaxPitch = 1.2})
        AbilityFX.Sparks(position, EGG, 16, 24)

        for _, Victim: Model in CombatUtils.GetFightersInRadius(position, self.BurstRadius, Char) do
            local Humanoid = Victim:FindFirstChildWhichIsA("Humanoid")
            local VictimRoot = Utils.Character.GetRootPart(Victim)
            if not Humanoid or not VictimRoot then
                continue
            end

            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = self.BurstDamage,
                Reason = self.Name,
                KnockbackDirection = (VictimRoot.Position - position).Magnitude > 0
                    and (VictimRoot.Position - position).Unit
                    or Vector3.yAxis,
                KnockbackMagnitude = 6,
            })

            CombatUtils.ApplyEffectTo(Victim, "Slowness", self.SlowLevel, self.SlowTime)
        end
    end

    ProjectileService.Lob({
        SourcePlayer = self.Owner,
        Name = "YoshiEgg",
        Origin = Root.Position + Vector3.new(0, 2, 0) + Root.CFrame.LookVector * 2,
        -- Overwritten by `Lob`, which solves for the arc.
        Direction = Root.CFrame.LookVector,
        Gravity = self.Gravity,
        Radius = 2.4,
        Damage = self.Damage,
        Reason = self.Name,
        Bounces = self.Bounces,
        Restitution = 0.7,
        Spin = 300,
        Visual = {
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(2.6, 2.6, 2.6),
            Color = EGG,
            Material = Enum.Material.SmoothPlastic,
            Trail = true,
            TrailColor = YOSHI,
        },
        OnBounce = function(_projectile, position: Vector3)
            AbilityFX.Sound("rbxassetid://12222216", position, {Volume = 0.5, MinPitch = 1.2, MaxPitch = 1.4})
            AbilityFX.Sparks(position, EGG, 5, 10)
        end,
        -- A direct hit bursts it, as does running out of bounces or time.
        OnHit = function(projectile)
            Burst(projectile.Part and projectile.Part.Position or Landing)
            return "Stop"
        end,
        OnImpact = function(_projectile, position: Vector3)
            Burst(position)
        end,
        OnExpire = function(_projectile, position: Vector3)
            Burst(position)
        end,
    }, Landing)
end

--------------------------------------------------------------------------------
-- R — FLUTTER JUMP
--------------------------------------------------------------------------------

--[=[
    Up, then a slow steerable hover.

    The hover is the ability — the jump is just how it starts. For `Hover` seconds he falls
    at a crawl and steers freely, which is both a way to cross a gap and a way to pick where
    `Ground Pound` lands.

    He keeps his basic attack the whole time, so hovering over a fight is a real threat
    rather than a time-out.
]=]
local function FlutterBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.15, Duration = self.Hover + 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.8, MinPitch = 1.1, MaxPitch = 1.25})

    Root.AssemblyLinearVelocity = Vector3.new(0, self.Lift, 0)
    Char:SetAttribute("YoshiHovering", true)

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.Hover and Char and Char.Parent do
            Elapsed += task.wait(0.05)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            -- Stunned mid-hover: he drops.
            if Char.Effects and Char.Effects:FindFirstChild("Stunned") then
                break
            end

            local Velocity = Live.AssemblyLinearVelocity

            -- Slow descent plus steering. He never gains height after the initial jump.
            Live.AssemblyLinearVelocity = Vector3.new(
                Live.CFrame.LookVector.X * self.Drift,
                math.max(Velocity.Y, -self.Descent),
                Live.CFrame.LookVector.Z * self.Drift
            )

            -- Flapping.
            if Elapsed % 0.2 < 0.06 then
                AbilityFX.Burst(Live.Position - Vector3.new(0, 1.5, 0), 3, YOSHI, {
                    Duration = 0.25,
                    StartSize = 2,
                    Transparency = 0.8,
                })
                AbilityFX.Sound(self.FlapSound, Live.Position, {Volume = 0.3, MinPitch = 1.3, MaxPitch = 1.5})
            end
        end

        if Char then
            Char:SetAttribute("YoshiHovering", false)
        end
    end)
end

--------------------------------------------------------------------------------
-- F — GROUND POUND
--------------------------------------------------------------------------------

--[=[
    Comes down hard, and the damage scales with the fall.

    `HeightBonus` damage per stud of altitude when he presses it, capped — so it is worth
    almost nothing from standing and a great deal from the top of a `Flutter Jump`. That is
    what ties the two abilities into one play instead of leaving them as two unrelated
    buttons.

    It can be used from the ground, and it is deliberately weak there.
]=]
local function PoundBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.2, Duration = 0.6, Shake = 4, ShakeTime = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    -- Height at the moment of pressing. Measured from the ground beneath him.
    local Ground = AbilityFX.GroundAt(Root.Position, {Char, workspace.Players}, 120)
    local Altitude = Ground and math.max(Root.Position.Y - Ground.Y, 0) or 0

    AbilityFX.Sound(self.DropSound, Root.Position, {Volume = 0.8, MinPitch = 0.85, MaxPitch = 1})

    -- Straight down, fast. Ends the hover.
    Char:SetAttribute("YoshiHovering", false)
    Root.AssemblyLinearVelocity = Vector3.new(0, -self.DropSpeed, 0)

    task.spawn(function()
        local Elapsed = 0

        -- Falls until it lands or the timeout expires, whichever is first.
        while Elapsed < self.MaximumFall do
            Elapsed += task.wait(0.04)

            local Live = Char and Utils.Character.GetRootPart(Char)
            local Humanoid = Char and Char:FindFirstChildWhichIsA("Humanoid")
            if not Live or not Humanoid then
                return
            end

            local State = Humanoid:GetState()
            if State ~= Enum.HumanoidStateType.Freefall and State ~= Enum.HumanoidStateType.Jumping and Elapsed > 0.1 then
                break
            end
        end

        local Live = Char and Utils.Character.GetRootPart(Char)
        if not Live then
            return
        end

        local Origin = Live.Position
        local Bonus = math.min(Altitude * self.HeightBonus, self.MaximumBonus)
        local Damage = self.Damage + Bonus
        local Radius = self.Radius + math.min(Altitude * 0.15, 8)

        AbilityFX.Sound(self.UseSound, Origin, {Volume = 1, RollOffMaxDistance = 170})
        AbilityFX.Ring(Origin, Radius, SHELL, {Duration = 0.5, Thickness = 1.3})
        AbilityFX.Ring(Origin, Radius * 0.6, YOSHI, {Duration = 0.4, Thickness = 0.8})
        AbilityFX.Smoke(Origin, Color3.fromRGB(200, 190, 170), 16, 3.5)
        AbilityFX.ShakeInRadius(Origin, Radius * 2, 4, 0.6)

        if Bonus > 0 then
            AbilityFX.Text(Origin + Vector3.new(0, 5, 0), "+"..tostring(math.round(Bonus)), SHELL, 1.1)
        end

        for _, Victim: Model in CombatUtils.GetFightersInRadius(Origin, Radius, Char) do
            local Humanoid = Victim:FindFirstChildWhichIsA("Humanoid")
            local VictimRoot = Utils.Character.GetRootPart(Victim)
            if not Humanoid or not VictimRoot then
                continue
            end

            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = Damage,
                Reason = self.Name,
                KnockbackDirection = ((VictimRoot.Position - Origin).Magnitude > 0
                    and (VictimRoot.Position - Origin).Unit
                    or Vector3.xAxis) + Vector3.new(0, 0.4, 0),
                KnockbackMagnitude = 12,
            })

            CombatUtils.ApplyEffectTo(Victim, "Slowness", 2, 3)
            CombatUtils.ApplyEffectTo(Victim, "Grounded", 1, 2)
            AbilityFX.ShakeFor(Victim, 4, 0.5)
        end
    end)
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Yoshi: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Yoshi",
        Quote = "",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 5200,

        Role = "Controller",
        Difficulty = 2,

        Origin = {
            TooltipText = "He has been carrying somebody for thirty years.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            Good movement, modest damage. The lowest damage ceiling of any melee character
            here — he wins by deciding where fights happen, not by winning them quickly.
        ]]
        Health = 1300,
        BaseSpeed = 11.4,
        SprintSpeedMultiplier = 26 / 11.4,
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

                --- Headbutt: narrow, forward.
                Damage = 24,
                --- Tail sweep: all the way round, hits everybody, more knockback.
                TailDamage = 19,
                Cooldown = 1.5,
                Duration = 0.28,
                Delay = 0.1,
                HitboxSize = Vector3.new(5, 6, 5.5),
                TailHitbox = Vector3.new(11, 5, 11),
                HitboxOffset = CFrame.new(0, 0, -2.8),

                Behaviour = StrikeBehaviour,
            }),

            Tongue = Ability.New({
                Name = "Tongue",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 13,
                Duration = 0.45,

                Damage = 20,
                Speed = 85,
                Range = 60,
                PullFraction = 0.7,
                SnareTime = 1,

                UseSound = "rbxassetid://12222216",
                CatchSound = "rbxassetid://9046319808",
                Behaviour = TongueBehaviour,
            }),

            Egg = Ability.New({
                Name = "Egg",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 8,
                Duration = 0.4,

                Damage = 22,
                BurstDamage = 34,
                BurstRadius = 12,
                Range = 110,
                Gravity = 110,
                Bounces = 2,
                SlowLevel = 2,
                SlowTime = 2.5,

                UseSound = "rbxassetid://12222030",
                BurstSound = "rbxassetid://9046319808",
                Behaviour = EggBehaviour,
            }),

            Flutter = Ability.New({
                Name = "Flutter",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 12,
                Duration = 0.4,

                Lift = 62,
                Hover = 2.4,
                Drift = 38,
                Descent = 7,

                UseSound = "rbxassetid://12222216",
                FlapSound = "rbxassetid://12222030",
                Behaviour = FlutterBehaviour,
            }),

            Pound = Ability.New({
                Name = "Pound",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 10,
                Duration = 0.6,

                DropSpeed = 130,
                MaximumFall = 2.5,
                --- Weak from standing.
                Damage = 26,
                --- Per stud of altitude, capped.
                HeightBonus = 1.1,
                MaximumBonus = 55,
                Radius = 15,

                DropSound = "rbxassetid://12222216",
                UseSound = "rbxassetid://9118823103",
                Behaviour = PoundBehaviour,
            }),

            SureFooted = Ability.New({
                Name = "Sure Footed",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(90, 200, 90)\">"..Yoshi.Config.Name.."</font>"
local Abilities = Yoshi.GameplayConfig.Abilities

Yoshi.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Yoshi.Config.Name:upper()},
    {
        Type = "Text",
        Text = {
            NameLabel.." has the lowest damage ceiling of any melee character in the arena and the best control of where a fight happens.",
            "The tongue drags people to him, the egg bounces around corners, and <b>Flutter</b> and <b>Pound</b> are one play with a decision in the middle: where to come down.",
            "<b>He does not swallow anybody.</b> The tongue pulls and lets go.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Yoshi.Config.Role,
            "Difficulty: "..string.rep("★", Yoshi.Config.Difficulty)..string.rep("☆", 5 - Yoshi.Config.Difficulty),
            "Price: "..tostring(Yoshi.Config.Price).."$",
            "Health: "..tostring(Yoshi.GameplayConfig.Health),
            "Base Speed: "..tostring(Yoshi.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Yoshi.GameplayConfig.BaseSpeed * Yoshi.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "HEAD STRIKE"},
    {
        Type = "Text",
        Text = {
            "<b>Alternates every swing</b>, every "..tostring(Abilities.Slash.Cooldown).." seconds:",
            "<b>Headbutt</b> — "..tostring(Abilities.Slash.Damage).." damage, narrow and forward.",
            "<b>Tail sweep</b> — "..tostring(Abilities.Slash.TailDamage).." damage all the way round him, hitting everybody, with real knockback.",
            "No combo window and no reset. You always know which one is next.",
        },
    },

    {Type = "Header", Text = "TONGUE  (Q)"},
    {
        Type = "Text",
        Text = {
            "Reaches "..tostring(Abilities.Tongue.Range).." studs. On a hit it drags the victim 70% of the way to him for "..tostring(Abilities.Tongue.Damage).." damage and a "..tostring(Abilities.Tongue.SnareTime).." second <b>Snare</b>.",
            "Slow enough to sidestep, and walls stop it. Snared leaves you your abilities and your attack.",
            "Cooldown: "..tostring(Abilities.Tongue.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "EGG  (E)"},
    {
        Type = "Text",
        Text = {
            "An arcing egg that <b>bounces "..tostring(Abilities.Egg.Bounces).." times</b> before bursting for "..tostring(Abilities.Egg.BurstDamage).." damage across "..tostring(Abilities.Egg.BurstRadius).." studs, plus a slow.",
            "The bounces are the point. It threatens around corners and off floors, which no flat projectile here does.",
            "Cooldown: "..tostring(Abilities.Egg.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "FLUTTER  (R)"},
    {
        Type = "Text",
        Text = {
            "Jumps, then hovers for "..tostring(Abilities.Flutter.Hover).." seconds — slow descent, free steering, and <b>he keeps his basic attack</b>.",
            "It crosses gaps, and it sets up Pound.",
            "Cooldown: "..tostring(Abilities.Flutter.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "POUND  (F)"},
    {
        Type = "Text",
        Text = {
            "Drops straight down. "..tostring(Abilities.Pound.Damage).." damage from standing, up to <b>"..tostring(Abilities.Pound.Damage + Abilities.Pound.MaximumBonus).."</b> from height, across "..tostring(Abilities.Pound.Radius).."+ studs.",
            "It is deliberately weak on the ground. It is worth using from the top of a Flutter.",
            "Cooldown: "..tostring(Abilities.Pound.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "SURE FOOTED  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Good speed, good stamina, and the most forgiving aerial control in the game.",
            "He has no damage spike anywhere. Everything he has is about position.",
        },
    },
}

return Yoshi
