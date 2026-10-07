local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Hitbox = require(ReplicatedStorage.Classes.Hitbox)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local AbilityClient = require(ReplicatedStorage.Modules.AbilityClient)
local AbilityFX = require(ReplicatedStorage.Modules.AbilityFX)
local DeployableService = require(ReplicatedStorage.Modules.DeployableService)
local ProjectileService = require(ReplicatedStorage.Modules.ProjectileService)

local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    BUILDERMAN — HE BUILDS. THAT IS THE FANTASY.

      M1  BAN HAMMER            Slow, enormous, and it sends people flying.
      Q   SENTRY                A classic Roblox turret. Finds people and shoots them.
      E   BUILD WALL            A brick wall. Blocks a route or splits a fight.
      R   ADMIN CONSTRUCTION    A station that makes him better while he stands near it.
      P   MASTER BUILDER        His structures go up instantly and are tougher than anyone
                                else's deployables.

    NOT A HACKER
    ------------
    He is the engineer, deliberately. 1x1x1x1 is the character who does things to the game
    itself; giving Builderman admin powers would have made two of those and left the roster
    without a builder. Everything he does is a physical object that exists in the world, can
    be seen, can be walked around, and can be smashed.

    STRONG SETUP, WEAK IMPROVISATION
    --------------------------------
    A Builderman who has had thirty seconds to prepare a corridor is the hardest killer in
    the game to approach. A Builderman caught in the open with his cooldowns down has a slow
    hammer and nothing else — his base speed is joint-lowest on the roster and he has no
    gap-closer and no escape.

    Every structure he places is a `DeployableService` deployable, which means every one of
    them is shaped so that ANY killer's normal basic attack damages it. That is the whole
    counterplay and it needs no special casing: walk up and hit the turret.
]=]

local BRICK = Color3.fromRGB(196, 112, 66)
local STEEL = Color3.fromRGB(150, 155, 165)
local ADMIN = Color3.fromRGB(90, 170, 255)

--------------------------------------------------------------------------------
-- M1 — BAN HAMMER
--------------------------------------------------------------------------------

--[=[
    The hammer.

    The slowest basic attack on the roster — 2.6 seconds — and the second hardest hitting,
    with real knockback. The knockback is the interesting half: it is how he creates the
    space he needs to build in, so his basic attack and his kit are the same plan.
]=]
local function HammerBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.95, Duration = 0.4, Lock = 0.8, Shake = 0.5, ShakeTime = 0.2})
        return
    end

    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.8, MinPitch = 0.8, MaxPitch = 0.9})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        local Impact = Root.Position + Root.CFrame.LookVector * 4

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Ban Hammer",
            ExecuteOnKill = true,
            Knockback = self.Knockback,
            -- Wide arc, and it carries through everybody in it. He is swinging a telephone
            -- pole; stopping at the first person would be strange.
            HitMultiple = true,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Burst(VictimRoot.Position, 6, ADMIN, {Duration = 0.3})
                        AbilityFX.ShakeFor(Victim, 2.2, 0.4)
                    end
                end,
            },
        })

        -- A heavy impact ring on the ground wherever the head lands.
        local Ground = AbilityFX.GroundAt(Impact, {self.OwnerProperties.Character})
        if Ground then
            AbilityFX.Ring(Ground, 8, ADMIN, {Duration = 0.4, Thickness = 0.8})
            AbilityFX.Smoke(Ground, Color3.fromRGB(170, 160, 140), 8, 3)
        end
    end)
end

--------------------------------------------------------------------------------
-- Q — SENTRY
--------------------------------------------------------------------------------

--[=[
    A turret.

    Low damage per shot, fires steadily, needs line of sight, and will not shoot its builder.
    Two at a time. It is area DENIAL rather than damage: a sentry covering a corridor does
    not kill anybody on its own, it makes going down that corridor cost you.

    The firing is `DeployableService.TurretTick`, shared with Tails' drone — both want "find
    the nearest fighter who isn't my owner and shoot if I can see them", and only the
    projectile differs. Shots are credited to Builderman through `ProjectileService`, so a
    sentry kill is his kill and goes through the same damage pipeline as everything else.
]=]
local function SentryBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.03, Duration = 0.3, Lock = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Spot = Root.Position + Root.CFrame.LookVector * 6
    local Ground = AbilityFX.GroundAt(Spot, {Char})

    if not Ground then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.UseSound, Ground, {Volume = 0.8})

    local Sentry = DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Sentry",
        Name = "Sentry",
        CFrame = CFrame.new(Ground + Vector3.new(0, 2.2, 0)),
        Size = Vector3.new(2.6, 4, 2.6),
        Color = STEEL,
        Material = Enum.Material.Metal,
        Solid = false,
        Health = self.SentryHealth,
        Lifetime = self.SentryLifetime,
        Limit = self.Limit,
        TickRate = 0.2,
        OutlineColor = ADMIN,
        OnTick = function(handle)
            DeployableService.TurretTick(handle, {
                Range = self.SentryRange,
                Interval = self.FireInterval,
                RequireLineOfSight = true,
                Fire = function(turret, _target, targetRoot)
                    local Muzzle = turret.Root.Position + Vector3.new(0, 1.2, 0)

                    ProjectileService.Fire({
                        SourcePlayer = self.Owner,
                        Name = "SentryShot",
                        Origin = Muzzle,
                        Direction = (targetRoot.Position - Muzzle),
                        Speed = 150,
                        Lifetime = self.SentryRange / 150,
                        Radius = 1.4,
                        Damage = self.ShotDamage,
                        Reason = "Sentry",
                        Visual = {
                            Shape = Enum.PartType.Ball,
                            Size = Vector3.new(0.7, 0.7, 0.7),
                            Color = ADMIN,
                            Material = Enum.Material.Neon,
                            Trail = true,
                            TrailColor = ADMIN,
                        },
                    })

                    AbilityFX.Sparks(Muzzle, ADMIN, 4, 10)
                    AbilityFX.Sound("rbxassetid://12222030", Muzzle, {Volume = 0.35, MinPitch = 1.1, MaxPitch = 1.3})
                end,
            })
        end,
        OnDestroyed = function(handle)
            AbilityFX.Shockwave(handle.Root.Position, 6, STEEL, 16)
        end,
    })

    if Sentry then
        -- A barrel, so it reads as a turret rather than a crate. Welded by position: the
        -- root is anchored, so a decoration parented to the model just needs to be put in
        -- the right place once.
        local Barrel = AbilityFX.Part({
            Name = "Barrel",
            Size = Vector3.new(0.7, 0.7, 3),
            CFrame = Sentry.Root.CFrame * CFrame.new(0, 1.2, -1.6),
            Color = ADMIN,
            Material = Enum.Material.Neon,
        })
        Barrel.Parent = Sentry.Model

        -- `TurretTick` rotates the root to face its target, and the barrel follows because
        -- this keeps it in the root's frame.
        task.spawn(function()
            while Sentry.Alive and Sentry.Root and Sentry.Root.Parent do
                task.wait(0.1)
                if Barrel.Parent then
                    Barrel.CFrame = Sentry.Root.CFrame * CFrame.new(0, 1.2, -1.6)
                end
            end
        end)

        self:BuildEffect(Sentry, Ground)
    end
end

--------------------------------------------------------------------------------
-- E — BUILD WALL
--------------------------------------------------------------------------------

--[=[
    A brick wall, built out of actual bricks.

    Made of several parts rather than one slab purely so it reads as Roblox building — the
    bricks snap up in sequence. Only the root carries the hitbox and the health; the rest are
    decoration parented to the same model, so breaking the wall removes all of it at once.

    Three at a time, 110 health each, 20 seconds. The highest-health structure he has, and
    the one that most needs to be: a wall that dies to one swing would not be worth a
    cooldown.
]=]
local function WallBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.02, Duration = 0.3, Lock = 0.4, Shake = 0.4, ShakeTime = 0.2})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Spot = Root.Position + Root.CFrame.LookVector * self.Distance
    local Ground = AbilityFX.GroundAt(Spot, {Char})

    if not Ground then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.UseSound, Ground, {Volume = 0.85})

    local Facing = CFrame.lookAt(Ground + Vector3.new(0, self.Height * 0.5, 0), Ground + Root.CFrame.LookVector)

    local Wall = DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Wall",
        Name = "BrickWall",
        CFrame = Facing,
        Size = Vector3.new(self.Width, self.Height, 1.2),
        Color = BRICK,
        Material = Enum.Material.Brick,
        Solid = true,
        Health = self.WallHealth,
        Lifetime = self.WallLifetime,
        Limit = self.Limit,
        OutlineColor = BRICK,
        OnDestroyed = function(handle)
            AbilityFX.Smoke(handle.Root.Position, BRICK, 16, 4)
            AbilityFX.Sound("rbxassetid://9046319808", handle.Root.Position, {Volume = 0.7, MinPitch = 0.7, MaxPitch = 0.85})
        end,
    })

    if Wall then
        self:BuildEffect(Wall, Ground)

        --[[
            Classic Roblox building: the bricks arrive in sequence rather than the wall
            appearing.

            Three rows, four columns, snapping in over a quarter of a second. Twelve
            decoration parts on a structure that lasts twenty seconds is cheap, and the
            animation is most of what makes this feel like Builderman rather than a generic
            barrier.
        ]]
        local Rows, Columns = 3, 4
        for Row = 1, Rows do
            for Column = 1, Columns do
                local Offset = CFrame.new(
                    (Column - (Columns + 1) / 2) * (self.Width / Columns),
                    (Row - (Rows + 1) / 2) * (self.Height / Rows),
                    0
                )

                local Brick = AbilityFX.Part({
                    Name = "Brick",
                    Size = Vector3.new(self.Width / Columns - 0.15, self.Height / Rows - 0.15, 1.3),
                    CFrame = Facing * Offset,
                    -- Alternating shades, so the courses are visible.
                    Color = (Row + Column) % 2 == 0 and BRICK or Color3.fromRGB(170, 95, 55),
                    Material = Enum.Material.Brick,
                    Transparency = 1,
                })
                Brick.Parent = Wall.Model

                task.delay((Row - 1) * 0.06 + (Column - 1) * 0.02, function()
                    if not Brick.Parent then
                        return
                    end
                    Brick.Transparency = 0
                    TweenService:Create(
                        Brick,
                        TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                        {CFrame = Facing * Offset}
                    ):Play()
                end)
            end
        end

        -- The root itself is invisible: the bricks are what you see.
        Wall.Root.Transparency = 1
    end
end

--------------------------------------------------------------------------------
-- R — ADMIN CONSTRUCTION
--------------------------------------------------------------------------------

--[=[
    A workbench that makes him better while he is near it.

    An AURA, not a buff: the effect applies while he is inside its radius and stops the
    moment he leaves. That is what stops it being a free thirty-second power spike — it
    anchors him to a spot, and anchoring the slowest killer in the game to a spot is a real
    cost.

    It is also the most fragile thing he builds (70 health) and it glows, so opponents know
    exactly where he wants to fight and exactly what to break.
]=]
local function AdminBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.06, Duration = 0.4, Lock = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Ground = AbilityFX.GroundAt(Root.Position + Root.CFrame.LookVector * 5, {Char})
    if not Ground then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.UseSound, Ground, {Volume = 0.9})

    local Station = DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Station",
        Name = "AdminConstruction",
        CFrame = CFrame.new(Ground + Vector3.new(0, 1.5, 0)),
        Size = Vector3.new(4, 3, 4),
        Color = ADMIN,
        Material = Enum.Material.Neon,
        Transparency = 0.25,
        Solid = false,
        Health = self.StationHealth,
        Lifetime = self.StationLifetime,
        Limit = 1,
        TickRate = 0.25,
        OutlineColor = ADMIN,
        OnTick = function(handle)
            local Live = self.Owner and self.Owner.Character
            local LiveRoot = Live and Utils.Character.GetRootPart(Live)

            local Inside = LiveRoot
                and (LiveRoot.Position - handle.Root.Position).Magnitude <= self.AuraRadius

            --[[
                Idempotent apply and remove, tracked on the handle.

                Writing the speed factor every tick would be harmless but the cooldown
                attribute would not: it is multiplicative, so re-applying it four times a
                second would compound into cooldowns of effectively zero. The flag means it
                is applied exactly once on entry and removed exactly once on exit.
            ]]
            if Inside and not handle.State.Buffed then
                handle.State.Buffed = true
                handle.State.PreviousCooldown = Live:GetAttribute("CooldownMultiplier") or 1

                Live:SetAttribute("CooldownMultiplier", handle.State.PreviousCooldown * self.CooldownMultiplier)
                PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.SpeedMultiplier)

                AbilityFX.Ring(handle.Root.Position, self.AuraRadius, ADMIN, {Duration = 0.4})

            elseif not Inside and handle.State.Buffed then
                handle.State.Buffed = false

                if Live then
                    Live:SetAttribute("CooldownMultiplier", handle.State.PreviousCooldown or 1)
                end
                PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
            end
        end,
        OnEnd = function(handle)
            --[[
                The station going away MUST undo its own buff.

                It is removed by three different paths — timing out, being destroyed, and
                being replaced by a newer one — and `OnEnd` is the only one all three go
                through. Doing this in `OnExpire` alone would have left a permanent cooldown
                reduction on anyone whose station was smashed.
            ]]
            local Live = self.Owner and self.Owner.Character
            if handle.State.Buffed and Live then
                Live:SetAttribute("CooldownMultiplier", handle.State.PreviousCooldown or 1)
            end
            PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
        end,
    })

    if Station then
        self:BuildEffect(Station, Ground)

        -- A visible footprint for the aura, so the radius is not a guess.
        local Marker = AbilityFX.Part({
            Name = "AuraFootprint",
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(0.2, self.AuraRadius * 2, self.AuraRadius * 2),
            CFrame = CFrame.new(Ground + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
            Color = ADMIN,
            Material = Enum.Material.Neon,
            Transparency = 0.88,
        })
        Marker.Parent = Station.Model
    end
end

--------------------------------------------------------------------------------
-- PASSIVE — MASTER BUILDER
--------------------------------------------------------------------------------

--[=[
    What `BuildEffect` is, and what the passive actually does.

    The passive is not a hidden stat. It is two concrete things:

      1. HIS STRUCTURES ARE TOUGHER. Every health number in this file already includes it;
         they are roughly 50% above what `DeployableService` gives by default, which is the
         difference between a wall that survives being noticed and one that does not.
      2. THEY GO UP INSTANTLY, WITH THE CLASSIC EFFECT. No cast time, no delay. Everything
         else that places objects on this roster has a wind-up; he does not, because the
         whole character is that building is the thing he is fastest at.

    `BuildEffect` is the shared presentation for all three: a snap, a grid flash on the
    ground and a puff of brick dust, so his three structures visibly belong to the same
    builder.
]=]
local function BuildEffect(self: Types.Ability, handle, ground: Vector3)
    if not RunService:IsServer() or not handle then
        return
    end

    AbilityFX.Ring(ground, 6, ADMIN, {Duration = 0.35, Thickness = 0.5})
    AbilityFX.Smoke(ground, Color3.fromRGB(190, 170, 150), 8, 2.5)
    AbilityFX.Sound("rbxassetid://12222216", ground, {Volume = 0.45, MinPitch = 1.2, MaxPitch = 1.45})

    -- The classic studs-snapping-in pop: it arrives slightly oversized and settles.
    local Final = handle.Root.Size
    handle.Root.Size = Final * 0.6
    TweenService:Create(
        handle.Root,
        TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = Final}
    ):Play()
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Builderman: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Builderman",
        Quote = "Keep building.",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 40000,

        Role = "Trapper",
        Difficulty = 4,

        Origin = {
            TooltipText = "He was here before any of this.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            --- Heavy boots. He is carrying a hammer the size of a door.
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            Joint-slowest on the roster with Freddy, and no mobility of any kind. Everything
            he has is worth more the longer he has had to set it up, so being hard to
            disengage from would have made him oppressive.
        ]]
        Health = 1300,
        BaseSpeed = 10.4,
        SprintSpeedMultiplier = 24.5 / 10.4,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 100,
            StaminaDrain = 12,
            StaminaGain = 18,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://9046319808",
                UseAnimation = "rbxassetid://133504250023139",

                --- Slowest and second hardest-hitting basic attack in the game.
                Damage = 36,
                Cooldown = 2.6,
                Duration = 0.45,
                Delay = 0.22,
                HitboxSize = Vector3.new(8, 7, 6),
                HitboxOffset = CFrame.new(0, 0, -3.2),
                Knockback = 9,

                Behaviour = HammerBehaviour,
            }),

            Sentry = Ability.New({
                Name = "Sentry",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 22,
                Duration = 0.35,

                SentryHealth = 75,
                SentryLifetime = 28,
                SentryRange = 55,
                FireInterval = 0.9,
                ShotDamage = 8,
                Limit = 2,

                UseSound = "rbxassetid://12222216",
                Behaviour = SentryBehaviour,
                BuildEffect = BuildEffect,
            }),

            Wall = Ability.New({
                Name = "Wall",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 12,
                Duration = 0.3,

                Distance = 9,
                Width = 18,
                Height = 12,
                WallHealth = 110,
                WallLifetime = 20,
                Limit = 3,

                UseSound = "rbxassetid://9046319808",
                Behaviour = WallBehaviour,
                BuildEffect = BuildEffect,
            }),

            Admin = Ability.New({
                Name = "Admin",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 50,
                Duration = 0.4,

                StationHealth = 70,
                StationLifetime = 35,
                AuraRadius = 22,
                --- 0.7 means cooldowns run 30% faster while he stands in it.
                CooldownMultiplier = 0.7,
                SpeedMultiplier = 1.12,

                UseSound = "rbxassetid://9125402735",
                Behaviour = AdminBehaviour,
                BuildEffect = BuildEffect,
            }),

            MasterBuilder = Ability.New({
                Name = "Master Builder",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(90, 170, 255)\">"..Builderman.Config.Name.."</font>"
local Abilities = Builderman.GameplayConfig.Abilities

Builderman.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Builderman.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Builderman.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." does not chase. He builds a place where chasing is unnecessary.",
            "A turret covering a corridor, a brick wall across the only other way in, and a workbench in the middle that makes his cooldowns come back faster. Given thirty seconds he is the hardest killer in the arena to approach.",
            "Caught away from all of it he has a slow hammer, no gap-closer and no escape. Everything he owns can be smashed by anybody's basic attack.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Builderman.Config.Role,
            "Difficulty: "..string.rep("★", Builderman.Config.Difficulty)..string.rep("☆", 5 - Builderman.Config.Difficulty),
            "Price: "..tostring(Builderman.Config.Price).."$",
            "Health: "..tostring(Builderman.GameplayConfig.Health),
            "Base Speed: "..tostring(Builderman.GameplayConfig.BaseSpeed).."  (joint lowest)",
            "Sprint Speed: "..tostring(math.round(Builderman.GameplayConfig.BaseSpeed * Builderman.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "BAN HAMMER"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds — the slowest swing in the game, and nearly the hardest.",
            "Wide enough to catch several people at once, and the knockback throws them clear. That space is how he gets room to build.",
        },
    },

    {Type = "Header", Text = "SENTRY  (Q)"},
    {
        Type = "Text",
        Text = {
            "Builds a turret. "..tostring(Abilities.Sentry.SentryHealth).." health, "..tostring(Abilities.Sentry.SentryLifetime).." seconds, "..tostring(Abilities.Sentry.Limit).." at a time.",
            "Fires "..tostring(Abilities.Sentry.ShotDamage).." damage shots every "..tostring(Abilities.Sentry.FireInterval).." seconds at anything within "..tostring(Abilities.Sentry.SentryRange).." studs that it can see. It will not shoot him.",
            "It needs line of sight, so cover beats it — and it dies to a few swings.",
            "Cooldown: "..tostring(Abilities.Sentry.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "WALL  (E)"},
    {
        Type = "Text",
        Text = {
            "A brick wall, "..tostring(Abilities.Wall.Width).." studs across. "..tostring(Abilities.Wall.WallHealth).." health, "..tostring(Abilities.Wall.WallLifetime).." seconds, "..tostring(Abilities.Wall.Limit).." at a time.",
            "Blocks a route, splits a fight, or cuts a chase in half. Solid — nobody walks through it, including him.",
            "Cooldown: "..tostring(Abilities.Wall.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "ADMIN  (R)"},
    {
        Type = "Text",
        Text = {
            "A workbench. While he is within "..tostring(Abilities.Admin.AuraRadius).." studs of it, his cooldowns run 30% faster and he moves 12% faster.",
            "The buff stops the instant he leaves the radius, so it anchors him — and he is already the slowest killer here.",
            "Only "..tostring(Abilities.Admin.StationHealth).." health. It glows. Breaking it is the counterplay.",
            "Cooldown: "..tostring(Abilities.Admin.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "MASTER BUILDER  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "His structures go up <b>instantly</b> — no wind-up, unlike every other deployable on the roster — and they are around 50% tougher than anybody else's.",
            "The bricks snap in one course at a time, the way they always have.",
        },
    },
}

return Builderman
