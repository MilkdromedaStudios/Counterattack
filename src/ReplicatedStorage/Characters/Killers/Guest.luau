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
local SummonService = require(ReplicatedStorage.Modules.SummonService)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    GUEST — LOGGED OUT, NEVER LEFT.

      M1  CLASSIC SWORD   The 2008 linked sword. Wide, slow, and it hits everybody in the arc.
      Q   GUEST RUSH      A straight-line charge. No steering, no stopping.
      E   GUEST ARMY      Three translucent Guests go looking for people.
      R   ACCOUNT DELETED Takes somebody's ABILITIES away for three seconds. Not their fight.
      P   2017            The emptier the server gets, the stronger he is.

    NOT A HACKER, NOT A DEFAULT
    ---------------------------
    Three characters on this roster could have ended up as "the Roblox one". They are kept
    distinct on purpose: 1x1x1x1 is corruption and does things to the GAME, Bacon Hair is
    the default player and does things with FUNDAMENTALS, and Guest is NOSTALGIA — a crowd
    of identical grey figures and a server slowly emptying out.

    ACCOUNT DELETED DOES NOT KICK ANYBODY
    -------------------------------------
    It locks their Q, E and R for three seconds through the engine's `AbilitiesLocked`
    attribute, which `Ability:CanUse` already honours — and `CanUse` deliberately exempts the
    basic attack, so a target can always still fight back. Taking away somebody's abilities
    is a strong play; taking away their ability to defend themselves is a stun, and this game
    already has `Stunned` for that.

    It also, obviously, does not touch anybody's account, session, or connection.

    PASSIVE: THE SERVER EMPTIES
    ---------------------------
    He gets 6% faster and 4% harder hitting for every fighter who has died this round, to a
    cap of five. In a seven-player free-for-all that means he ends the round noticeably
    stronger than he started it — which is the only character on the roster whose power curve
    is driven by the round's progress rather than his own actions.
]=]

local GUEST = Color3.fromRGB(165, 170, 180)
local GUEST_BLUE = Color3.fromRGB(80, 140, 220)

--------------------------------------------------------------------------------
-- PASSIVE STATE
--------------------------------------------------------------------------------

--- How many stacks of `2017` he currently has. Read by the sword and the rush.
local function Nostalgia(char: Model?): number
    return char and char:GetAttribute("GuestNostalgia") or 0
end

--------------------------------------------------------------------------------
-- M1 — CLASSIC SWORD
--------------------------------------------------------------------------------

local function SwordBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.05, Duration = 0.28, Lock = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Damage = self.Damage * (1 + self.DamagePerStack * Nostalgia(Char))

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.7, MinPitch = 0.95, MaxPitch = 1.05})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        -- A flat grey arc. No glow, no particles — it is a 2008 sword.
        local Centre = Root.Position + Root.CFrame.LookVector * 3.5
        AbilityFX.Beam(
            Centre - Root.CFrame.RightVector * 4,
            Centre + Root.CFrame.RightVector * 4,
            GUEST,
            {Width = 0.7, Duration = 0.18, Transparency = 0.25, Material = Enum.Material.SmoothPlastic}
        )

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = Damage,
            Reason = "Classic Sword",
            ExecuteOnKill = true,
            -- Wide arc that carries through. It is a big sword and he swings it badly.
            HitMultiple = true,
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — GUEST RUSH
--------------------------------------------------------------------------------

--[=[
    A charge with no brakes.

    Deliberately the crudest movement ability on the roster: `CombatUtils.Dash` with
    steering explicitly OFF, so it goes exactly where he was pointing for its whole duration.
    Everyone he passes through gets hit once.

    That lack of control IS the character. Every other charge on the roster curves — Knuckles
    steers, Cuphead cancels, Wario turns badly but turns. This one does not turn at all, and
    running it into a wall is entirely possible.
]=]
local function RushBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.22, Duration = self.Duration_, Lock = self.Duration_})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.9, RollOffMaxDistance = 130})
    AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "!!!", GUEST_BLUE, 0.9)

    -- `false` for steerable: committed line, no curve.
    CombatUtils.Dash(Char, self.Speed * (1 + self.SpeedPerStack * Nostalgia(Char)), self.Duration_, false)

    local Struck = {}

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.Duration_ and Char and Char.Parent do
            Elapsed += task.wait(0.05)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            AbilityFX.Burst(Live.Position, 3, GUEST_BLUE, {Duration = 0.22, StartSize = 2, Transparency = 0.7})

            for _, Target: Model in CombatUtils.GetFightersInRadius(Live.Position, self.Radius, Char) do
                -- Once each. A charge that hits every tick is a blender.
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
                    KnockbackMagnitude = 10,
                })

                AbilityFX.ShakeFor(Target, 2, 0.3)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- E — GUEST ARMY
--------------------------------------------------------------------------------

--[=[
    Three translucent Guests.

    Weak — 35 health, 8 damage — and slower than everybody, because their job is to SEARCH.
    The reveal on their attacks is the real output: a Guest Army walking into a room tells the
    real Guest who is in it.

    They are `PlaceholderRig` bodies in grey, which is exactly right: a Guest is a default
    body with the colour turned off, and three of them look like the lobby of an old game.
]=]
local function ArmyBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.08, Duration = 0.5})
        return
    end

    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 0.85})
    AbilityFX.Ring(Origin, 12, GUEST_BLUE, {Duration = 0.5})
    AbilityFX.Text(Origin + Vector3.new(0, 6, 0), "Guest "..tostring(math.random(1000, 9999)), GUEST, 1.3)

    SummonService.Summon({
        SourcePlayer = self.Owner,
        Position = Origin,
        Count = self.Count,
        Name = "Guest",
        Lifetime = self.MinionLifetime,
        Health = self.MinionHealth,
        Speed = self.MinionSpeed,
        Damage = self.MinionDamage,
        AttackRange = 6,
        AttackInterval = 1.6,
        Reason = "Guest",
        --- Wide, because searching is what they are for.
        SeekRadius = 90,
        Appearance = {
            Color = GUEST,
            HeadColor = GUEST,
            Material = Enum.Material.SmoothPlastic,
            -- Translucent. They are not really here.
            Transparency = 0.35,
            Glow = GUEST_BLUE,
        },
        OnAttack = function(_minion, target: Model)
            --[[
                The real payoff: anything an army Guest touches is revealed to the real one.

                It is why they are built for searching rather than fighting, and it means
                three cheap bodies converted into map information rather than damage.
            ]]
            Utils.Player.RevealPlayerAuraTo(self.Owner, target, self.RevealTime, GUEST_BLUE)
        end,
    })
end

--------------------------------------------------------------------------------
-- R — ACCOUNT DELETED
--------------------------------------------------------------------------------

--[=[
    Takes somebody's abilities away for three seconds.

    A short-range cone, so it has to be used in a fight rather than across the map. Everyone
    it catches has `AbilitiesLocked` set, which `Ability:CanUse` reads — their Q, E and R stop
    working and their basic attack does not. See the header for why that distinction matters.

    The lock is cleared by a RAW delay rather than through the ability's Janitor, because a
    lock that outlives its caster would be permanent for its victim.
]=]
local function DeletedBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.9, Duration = 0.5, Lock = 0.6, Shake = 1.5, ShakeTime = 0.3})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position + Vector3.new(0, 1, 0)

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 1, RollOffMaxDistance = 150})
    AbilityFX.Cone(Origin, Root.CFrame.LookVector, self.Range, self.Angle, GUEST_BLUE, {Rays = 9, Duration = 0.4})

    local Caught = 0

    for _, Target: Model in AbilityFX.ConeTargets(Origin, Root.CFrame.LookVector, self.Range, self.Angle, Char) do
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

        Target:SetAttribute("AbilitiesLocked", true)

        AbilityFX.Text(TargetRoot.Position + Vector3.new(0, 6, 0), "DELETED", Color3.fromRGB(255, 70, 70), 1.4)
        AbilityFX.Burst(TargetRoot.Position, 7, GUEST_BLUE, {Duration = 0.4})
        AbilityFX.ScreenFor(Target, "Glitch", self.LockTime, 0.7)

        -- Raw delay: this must clear even if Guest dies the same frame.
        task.delay(self.LockTime, function()
            if Target and Target.Parent then
                Target:SetAttribute("AbilitiesLocked", nil)
            end
        end)
    end

    if Caught <= 0 then
        -- Nothing in the cone. A read that was wrong about where people were standing
        -- should cost tempo, not forty seconds.
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "nobody there", GUEST, 0.9)
    end
end

--------------------------------------------------------------------------------
-- PASSIVE — 2017
--------------------------------------------------------------------------------

--[=[
    The server empties, and he gets stronger.

    One stack per fighter who has left the round, capped at five: +6% speed and +4% sword
    damage each. Watching `workspace.Players` for children leaving is the cheapest honest
    signal for "a fighter is out" and needs no hook into the round manager.

    It is the only power curve on the roster driven by the ROUND rather than by its owner,
    which makes him the character who is weakest in the opening scramble and strongest in the
    last two minutes — and it is thematically the entire point of him.
]=]
local function NostalgiaInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    Char:SetAttribute("GuestNostalgia", 0)

    local function Apply()
        local Stacks = Nostalgia(Char)
        PlayerSpeedManager.AddSpeedFactor(self.Owner, "Nostalgia", 1 + self.SpeedPerStack * Stacks)
    end

    Apply()

    self:AddConnection(workspace.Players.ChildRemoved:Connect(function(Removed: Instance)
        if Removed == Char or not Char.Parent then
            return
        end

        local Stacks = math.min(Nostalgia(Char) + 1, self.MaximumStacks)
        Char:SetAttribute("GuestNostalgia", Stacks)
        Apply()

        local Root = Utils.Character.GetRootPart(Char)
        if Root then
            AbilityFX.Sound(self.StackSound, Root.Position, {Volume = 0.5, MinPitch = 1.1, MaxPitch = 1.2})
            AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "one less", GUEST_BLUE, 1)
            AbilityFX.Tint(Char, GUEST_BLUE, 0.6, {FillTransparency = 0.8})
        end
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Guest: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Guest",
        Quote = "Guest 666 has joined the game.",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 2900,

        Role = "Summoner",
        Difficulty = 2,

        Origin = {
            TooltipText = "Guests were removed in 2017.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        Health = 1250,
        BaseSpeed = 11.3,
        SprintSpeedMultiplier = 26 / 11.3,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 110,
            StaminaDrain = 10,
            StaminaGain = 21,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222200",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 23,
                --- +4% per stack of 2017.
                DamagePerStack = 0.04,
                Cooldown = 2,
                Duration = 0.34,
                Delay = 0.12,
                --- Very wide and piercing. He swings it like somebody who just found it.
                HitboxSize = Vector3.new(9, 6, 5),
                HitboxOffset = CFrame.new(0, 0, -2.6),

                Behaviour = SwordBehaviour,
            }),

            Rush = Ability.New({
                Name = "Rush",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 12,
                Duration = 0.7,

                Duration_ = 0.7,
                Speed = 78,
                SpeedPerStack = 0.05,
                Radius = 6,
                Damage = 30,

                UseSound = "rbxassetid://5153734423",
                Behaviour = RushBehaviour,
            }),

            Army = Ability.New({
                Name = "Army",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 34,
                Duration = 0.5,

                Count = 3,
                MinionHealth = 35,
                MinionDamage = 8,
                MinionSpeed = 10.5,
                MinionLifetime = 20,
                RevealTime = 4,

                UseSound = "rbxassetid://9125402735",
                Behaviour = ArmyBehaviour,
            }),

            Deleted = Ability.New({
                Name = "Deleted",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 40,
                Duration = 0.6,

                Range = 20,
                Angle = 90,
                Damage = 25,
                --- Short, on purpose. See the header.
                LockTime = 3,

                UseSound = "rbxassetid://9118823103",
                Behaviour = DeletedBehaviour,
            }),

            Nostalgia = Ability.New({
                Name = "2017",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                SpeedPerStack = 0.06,
                MaximumStacks = 5,
                StackSound = "rbxassetid://5153734423",

                ExtraInit = NostalgiaInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(80, 140, 220)\">"..Guest.Config.Name.."</font>"
local Abilities = Guest.GameplayConfig.Abilities

Guest.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Guest.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Guest.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." is the weakest character in the opening scramble and one of the strongest in the last two minutes.",
            "<b>2017</b> gives him a stack for every fighter who leaves the round, and he is the only killer whose power curve is driven by the round's progress rather than his own.",
            "Three translucent Guests go out looking for people, and anything they touch is revealed to him.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Guest.Config.Role,
            "Difficulty: "..string.rep("★", Guest.Config.Difficulty)..string.rep("☆", 5 - Guest.Config.Difficulty),
            "Price: "..tostring(Guest.Config.Price).."$",
            "Health: "..tostring(Guest.GameplayConfig.Health),
            "Base Speed: "..tostring(Guest.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Guest.GameplayConfig.BaseSpeed * Guest.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "CLASSIC SWORD"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds, in a very wide arc that carries through everybody in it.",
            "Gains 4% damage per stack of <b>2017</b>.",
        },
    },

    {Type = "Header", Text = "RUSH  (Q)"},
    {
        Type = "Text",
        Text = {
            "A charge in a dead straight line for "..tostring(Abilities.Rush.Damage).." damage to everybody he passes through, once each.",
            "<b>It does not steer at all.</b> It goes exactly where he was pointing, including into walls.",
            "Cooldown: "..tostring(Abilities.Rush.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "ARMY  (E)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Army.Count).." translucent Guests. "..tostring(Abilities.Army.MinionHealth).." health, "..tostring(Abilities.Army.MinionDamage).." damage, "..tostring(Abilities.Army.MinionLifetime).." seconds.",
            "They are built to SEARCH, not to fight — anything they hit is revealed to the real Guest for "..tostring(Abilities.Army.RevealTime).." seconds.",
            "Cooldown: "..tostring(Abilities.Army.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "DELETED  (R)"},
    {
        Type = "Text",
        Text = {
            "A short cone. Everybody in it takes "..tostring(Abilities.Deleted.Damage).." damage and <b>loses their abilities for "..tostring(Abilities.Deleted.LockTime).." seconds</b>.",
            "Their basic attack keeps working the whole time — this takes away your options, not your ability to fight.",
            "Only "..tostring(Abilities.Deleted.Range).." studs. He has to be in your face to use it, and it refunds itself if it catches nobody.",
            "Cooldown: "..tostring(Abilities.Deleted.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "2017  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "One stack for every fighter who leaves the round, up to "..tostring(Abilities.Nostalgia.MaximumStacks)..".",
            "Each is +6% speed and +4% sword damage. The emptier the server, the more of him there is.",
        },
    },
}

return Guest
