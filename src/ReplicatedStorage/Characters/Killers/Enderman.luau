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
    ENDERMAN — DON'T LOOK AT IT.

      M1  LONG-ARM SWIPE   The longest melee reach on the roster by a wide margin.
      Q   TELEPORT         A short hop to a validated spot. Purple particles, that noise.
      E   BLOCK CARRY      Picks up a block. Press again to put it down somewhere else.
      R   ENDER AMBUSH     Teleports on top of whoever it has marked, after a warning.
      P   DON'T LOOK AT ME Staring at it for long enough enrages it — at YOU specifically.

    THE PASSIVE, AND WHY IT READS BODY FACING
    ----------------------------------------
    "Keeps their camera centred on it" is the behaviour from the source material, and the
    camera is a CLIENT-OWNED value. Asking clients where they are looking would mean the
    strongest play against this character is to lie about it, which is not a mechanic, it is
    an exploit with extra steps.

    So it reads BODY FACING, which the server owns: `CombatUtils.IsFacing` on the victim's
    root, in a cone, with line of sight required. In this game the character turns toward
    where you are heading and fighting, so "facing Enderman" and "engaging Enderman" are
    nearly the same thing — which is the right behaviour anyway. Turn and run and it stops
    accruing; stand and fight it and it builds.

    It does NOT attack you for looking once. It takes two and a half CUMULATIVE seconds of
    facing it, inside 90 studs, with a clear line. Then you are marked, it sees you through
    walls, and it is faster than you for six seconds.

    WEAKNESSES
    ----------
    No ranged damage of any kind. Water slows it badly. Its teleport is a fixed short hop
    with no vertical reach, so high ground and open water are both genuinely safe from it.
]=]

local ENDER = Color3.fromRGB(170, 60, 230)
local ENDER_DARK = Color3.fromRGB(70, 20, 110)

--------------------------------------------------------------------------------
-- M1 — LONG-ARM SWIPE
--------------------------------------------------------------------------------

--[=[
    Reach is the whole attack.

    Twelve studs deep where most basic attacks are five or six. The trade is that it is slow
    (2.1 seconds), narrow, and arrives with a long telegraphed wind-up — so it loses to
    sidestepping and wins against anyone who thinks they are at a safe distance.
]=]
local function SwipeBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.35, Lock = 0.7})
        return
    end

    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.6, MinPitch = 0.75, MaxPitch = 0.85})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        -- The arm, drawn as a long thin beam so the absurd reach is visible before it lands.
        local From = Root.Position + Vector3.new(0, 1.5, 0)
        AbilityFX.Beam(From, From + Root.CFrame.LookVector * self.HitboxSize.Z, ENDER_DARK, {
            Width = 0.9,
            Duration = 0.2,
            Transparency = 0.3,
        })

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Long Arms",
            ExecuteOnKill = true,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, ENDER, 10, 18)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- SHARED — TELEPORTING
--------------------------------------------------------------------------------

--[=[
    Finds somewhere it is legal to appear.

    VALIDATION IS THE WHOLE FUNCTION. A teleport that does not check its destination puts
    people inside walls, under floors and off the map, and `CombatUtils.Blink` refuses hops
    over 400 studs because the anti-cheat kills anyone who moves further than that in one
    frame.

    The check is: cast down from above the candidate to find floor, then confirm there is
    actually headroom above that floor. Returns `nil` if there is nowhere to go, and every
    caller treats `nil` as "refund the cooldown" rather than teleporting anyway.
]=]
local function FindSpot(char: Model, candidate: Vector3): Vector3?
    local Ground = AbilityFX.GroundAt(candidate, {char}, 60)
    if not Ground then
        return nil
    end

    -- Headroom. Without this it will happily drop him into a crawlspace.
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {char, workspace.Players}

    local Above = workspace:Raycast(Ground + Vector3.new(0, 0.5, 0), Vector3.new(0, 7, 0), Params)
    if Above then
        return nil
    end

    return Ground + Vector3.new(0, 3, 0)
end

--- The purple particle burst, at both ends. One function so every teleport looks the same.
local function TeleportFX(position: Vector3)
    AbilityFX.Burst(position, 7, ENDER, {Duration = 0.4})
    AbilityFX.Emit(position, 26, {
        Texture = AbilityFX.Textures.Spark,
        Color = ColorSequence.new(ENDER, ENDER_DARK),
        Speed = NumberRange.new(4, 16),
        Size = NumberSequence.new(1.1),
        Lifetime = NumberRange.new(0.4, 0.9),
        -- Drifting UP, which is the thing that makes ender particles read as ender particles.
        Acceleration = Vector3.new(0, 6, 0),
    })
end

--------------------------------------------------------------------------------
-- Q — TELEPORT
--------------------------------------------------------------------------------

local function TeleportBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.1, Duration = 0.3})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    ----------------------------------------------------------------------------
    -- WHERE
    ----------------------------------------------------------------------------

    --[[
        Tries the full distance first, then pulls in.

        Teleporting into a wall is the obvious failure; refusing to teleport because there
        happened to be a wall at exactly 60 studs is the annoying one. Stepping back in
        thirds means a hop toward a wall lands just short of it instead of failing.
    ]]
    local Destination = nil
    for _, Fraction in {1, 0.7, 0.45, 0.25} do
        local Candidate = Root.Position + Root.CFrame.LookVector * self.Distance * Fraction
        Destination = FindSpot(Char, Candidate)
        if Destination then
            break
        end
    end

    if not Destination then
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "nowhere to go", ENDER, 0.8)
        return
    end

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.85, MinPitch = 0.9, MaxPitch = 1.1})
    TeleportFX(Root.Position)

    if not CombatUtils.Blink(Char, Destination) then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    TeleportFX(Destination)
    AbilityFX.Sound(self.UseSound, Destination, {Volume = 0.85, MinPitch = 0.9, MaxPitch = 1.1})
end

--------------------------------------------------------------------------------
-- E — BLOCK CARRY
--------------------------------------------------------------------------------

--[=[
    Two presses: pick up, then put down.

    THE SAME KEY DOES BOTH, which is the point — carrying a block is a STATE, and the
    interesting decision is where to put it down rather than whether to make one. While
    carrying he moves 8% slower and the block floats visibly in front of him, so opponents
    can see a block coming.

    Placed blocks are solid, destructible and capped at four. They are not a wall: one block
    does not close a corridor, it narrows one, or makes a step onto something, or blocks a
    doorway at an angle. Used well they reshape a chase; used badly they are scenery.
]=]
local function BlockBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.02, Duration = 0.25})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Cache = self.CharModule.GameplayConfig.Cache

    ----------------------------------------------------------------------------
    -- PUT IT DOWN
    ----------------------------------------------------------------------------

    if Cache.CarriedBlock and Cache.CarriedBlock.Parent then
        local Spot = Root.Position + Root.CFrame.LookVector * self.PlaceDistance
        local Ground = AbilityFX.GroundAt(Spot, {Char})

        if not Ground then
            -- Keep hold of it rather than dropping it into the void, and refund.
            self.OnCooldown = false
            self.CooldownTimer = 0
            return
        end

        Cache.CarriedBlock:Destroy()
        Cache.CarriedBlock = nil
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
        Char:SetAttribute("CarryingBlock", false)

        AbilityFX.Sound(self.PlaceSound, Ground, {Volume = 0.75, MinPitch = 0.85, MaxPitch = 1.0})

        local Block = DeployableService.Place({
            SourcePlayer = self.Owner,
            Kind = "EnderBlock",
            Name = "EnderBlock",
            CFrame = CFrame.new(Ground + Vector3.new(0, self.BlockSize * 0.5, 0)),
            Size = Vector3.one * self.BlockSize,
            Color = Color3.fromRGB(90, 110, 80),
            Material = Enum.Material.Grass,
            Solid = true,
            Health = self.BlockHealth,
            Lifetime = self.BlockLifetime,
            Limit = self.Limit,
            OutlineColor = ENDER,
        })

        if Block then
            AbilityFX.Ring(Ground, 5, ENDER, {Duration = 0.3})
            AbilityFX.Smoke(Ground, Color3.fromRGB(120, 140, 100), 8, 2)
        end

        return
    end

    ----------------------------------------------------------------------------
    -- PICK ONE UP
    ----------------------------------------------------------------------------

    AbilityFX.Sound(self.PickupSound, Root.Position, {Volume = 0.6, MinPitch = 1.05, MaxPitch = 1.2})

    -- A floating block in front of him. Not a deployable — it is held, not placed, so it
    -- should not be damageable, blocking, or counted against his placement limit.
    local Held = AbilityFX.Part({
        Name = "CarriedBlock",
        Size = Vector3.one * self.BlockSize,
        CFrame = Root.CFrame * CFrame.new(0, 2, -4),
        Color = Color3.fromRGB(90, 110, 80),
        Material = Enum.Material.Grass,
    })
    Held.Parent = AbilityFX.Folder()

    Cache.CarriedBlock = Held
    Char:SetAttribute("CarryingBlock", true)

    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.CarrySpeedMultiplier)

    --[=[
        The block follows him until he puts it down, dies, or the round ends.

        The loop owns the cleanup for every one of those endings, which is why the exit
        conditions are checked on the character and the part rather than being driven from
        outside: a held block has no other owner.
    ]=]
    task.spawn(function()
        while Cache.CarriedBlock == Held and Held.Parent and Char and Char.Parent do
            task.wait(0.05)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            Held.CFrame = Live.CFrame * CFrame.new(0, 2, -4)
        end

        -- Dropped because he died or the round ended, not because he placed it.
        if Cache.CarriedBlock == Held then
            Cache.CarriedBlock = nil
            PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
            if Char then
                Char:SetAttribute("CarryingBlock", false)
            end
        end

        if Held.Parent then
            Held:Destroy()
        end
    end)
end

--------------------------------------------------------------------------------
-- R — ENDER AMBUSH
--------------------------------------------------------------------------------

--[=[
    Teleports onto whoever it has enraged at, after warning them.

    THE WARNING IS NOT OPTIONAL. A long-range teleport straight onto somebody with no notice
    is an unavoidable engagement, so the victim gets 0.9 seconds of ender particles swirling
    around their own position, a sound at both ends, and the `Rage` screen tint. In that time
    they can move — and the teleport resolves to where they ARE, not where they were, so
    moving does not dodge it, but it does mean choosing the ground you fight on.

    It also requires a target the passive has already marked. He cannot open with it.
]=]
local function AmbushBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.15, Duration = 0.5, Shake = 1.2, ShakeTime = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    ----------------------------------------------------------------------------
    -- WHO
    ----------------------------------------------------------------------------

    -- Prefer whoever the passive enraged it at; otherwise anybody Marked; otherwise refuse.
    local Cache = self.CharModule.GameplayConfig.Cache
    local Target = Cache.EnragedAt

    local function Valid(candidate: Model?): boolean
        if not candidate or not candidate.Parent then
            return false
        end
        local Humanoid = candidate:FindFirstChildWhichIsA("Humanoid")
        return Humanoid ~= nil and Humanoid.Health > 0 and candidate:GetAttribute("Dead") ~= true
    end

    if not Valid(Target) then
        Target = nil
        for _, Candidate: Model in CombatUtils.GetFightersInRadius(Root.Position, self.Range, Char) do
            if Utils.Instance.FindFirstChild(Candidate, "Effects.Marked", 0) then
                Target = Candidate
                break
            end
        end
    end

    if not Target then
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "no one marked", ENDER, 1)
        return
    end

    ----------------------------------------------------------------------------
    -- THE WARNING
    ----------------------------------------------------------------------------

    local TargetRoot = Utils.Character.GetRootPart(Target)
    if not TargetRoot then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.WarnSound, TargetRoot.Position, {Volume = 0.95, RollOffMaxDistance = 120})
    AbilityFX.ScreenFor(Target, "Rage", self.Warning + 0.3, 1)
    AbilityFX.Telegraph(TargetRoot.Position, 10, ENDER, self.Warning)

    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Warning and Target and Target.Parent do
            Elapsed += task.wait(0.12)
            local Live = Utils.Character.GetRootPart(Target)
            if Live then
                AbilityFX.Emit(Live.Position, 8, {
                    Color = ColorSequence.new(ENDER),
                    Speed = NumberRange.new(2, 8),
                    Acceleration = Vector3.new(0, 8, 0),
                    Size = NumberSequence.new(0.9),
                })
            end
        end
    end)

    ----------------------------------------------------------------------------
    -- THE ARRIVAL
    ----------------------------------------------------------------------------

    task.delay(self.Warning, function()
        if not Char or not Char.Parent or not Valid(Target) then
            return
        end

        local Live = Utils.Character.GetRootPart(Target)
        local Mine = Utils.Character.GetRootPart(Char)
        if not Live or not Mine then
            return
        end

        -- Behind them, and validated like any other teleport.
        local Behind = Live.Position - Live.CFrame.LookVector * 6
        local Destination = FindSpot(Char, Behind) or FindSpot(Char, Live.Position + Live.CFrame.LookVector * 6)

        if not Destination then
            -- Nowhere legal next to them. Refund rather than teleport into geometry.
            self.OnCooldown = false
            self.CooldownTimer = 0
            return
        end

        TeleportFX(Mine.Position)
        CombatUtils.Blink(Char, Destination)
        TeleportFX(Destination)

        AbilityFX.Sound(self.UseSound, Destination, {Volume = 1})
        AbilityFX.ShakeFor(Target, 2.5, 0.4)

        -- A hit on arrival, so it is an ambush rather than a taxi.
        local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
        if Humanoid then
            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = self.Damage,
                Reason = self.Name,
            })
            CombatUtils.ApplyEffectTo(Target, "Fragile", 2, 5)
        end
    end)
end

--------------------------------------------------------------------------------
-- PASSIVE — DON'T LOOK AT ME
--------------------------------------------------------------------------------

--[=[
    Accrues stare time, then enrages.

    One loop at 5 Hz. For every fighter inside 90 studs with a clear line of sight who is
    facing it, add the tick to their counter; for everybody else, bleed it away at half
    speed. Cross the threshold and:

      * they are `Marked` — Enderman sees them through walls, and so does everybody else,
        which in a free-for-all is its own punishment;
      * Enderman gets a speed bonus FOR SIX SECONDS, not permanently;
      * `Ender Ambush` unlocks against them.

    The decay is what makes it fair: look away and the counter falls. It is a "stop staring"
    mechanic, not a "you looked once" one.
]=]
local function StareInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    local Cache = self.CharModule.GameplayConfig.Cache
    Cache.StareTime = {}

    self:AddConnection(task.spawn(function()
        while Char and Char.Parent do
            local Step = task.wait(0.2)

            local Root = Utils.Character.GetRootPart(Char)
            if not Root then
                continue
            end

            ----------------------------------------------------------------
            -- WATER
            ----------------------------------------------------------------

            --[=[
                Water slows it badly, as in the source material.

                Checked by a downward raycast that does NOT ignore water, so standing in
                terrain water is detectable server-side with no new systems. If the map has
                no water this simply never fires — which is the correct behaviour for a map
                that has none, rather than something that needs configuring per map.
            ]=]
            local WaterParams = RaycastParams.new()
            WaterParams.FilterType = Enum.RaycastFilterType.Exclude
            WaterParams.FilterDescendantsInstances = {Char, workspace.Players}
            WaterParams.IgnoreWater = false

            local Below = workspace:Raycast(Root.Position, Vector3.new(0, -5, 0), WaterParams)
            local InWater = Below ~= nil and Below.Material == Enum.Material.Water

            if InWater and not Cache.InWater then
                Cache.InWater = true
                PlayerSpeedManager.AddSpeedFactor(self.Owner, "EnderWater", self.WaterSpeedMultiplier)
                AbilityFX.Smoke(Root.Position, ENDER, 10, 2.5)
            elseif not InWater and Cache.InWater then
                Cache.InWater = false
                PlayerSpeedManager.RemoveSpeedFactor(self.Owner, "EnderWater")
            end

            ----------------------------------------------------------------
            -- STARING
            ----------------------------------------------------------------

            local Watching = {}

            for _, Target: Model in CombatUtils.GetFightersInRadius(Root.Position, self.Range, Char) do
                local TargetRoot = Utils.Character.GetRootPart(Target)
                if not TargetRoot then
                    continue
                end

                -- Facing it, and able to actually see it.
                if not CombatUtils.IsFacing(Target, Root.Position, self.Tolerance) then
                    continue
                end
                if not CombatUtils.HasLineOfSight(TargetRoot.Position, Root.Position, {Target, Char}) then
                    continue
                end

                Watching[Target] = true
                Cache.StareTime[Target] = (Cache.StareTime[Target] or 0) + Step

                if Cache.StareTime[Target] >= self.Threshold then
                    Cache.StareTime[Target] = 0
                    Cache.EnragedAt = Target

                    CombatUtils.ApplyEffectTo(Target, "Marked", 1, self.MarkTime)

                    AbilityFX.Sound(self.RageSound, Root.Position, {Volume = 1, RollOffMaxDistance = 140})
                    AbilityFX.Tint(Char, ENDER, 1.2, {FillTransparency = 0.5})
                    AbilityFX.ScreenFor(Target, "Rage", 1.5, 1.2)
                    AbilityFX.Text(TargetRoot.Position + Vector3.new(0, 6, 0), "SEEN", ENDER, 1.3)

                    -- Six seconds, not forever. It is a punish window, not a stat.
                    PlayerSpeedManager.AddSpeedFactor(self.Owner, "Enraged", self.RageSpeedMultiplier)
                    task.delay(self.RageTime, function()
                        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, "Enraged")
                    end)
                end
            end

            -- Everyone not currently looking bleeds their counter away at half rate.
            for Target, Accrued in Cache.StareTime do
                if Watching[Target] then
                    continue
                end

                local Remaining = Accrued - Step * 0.5
                Cache.StareTime[Target] = Remaining > 0 and Remaining or nil
            end
        end
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Enderman: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Enderman",
        Quote = "",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 15000,

        Role = "Ambusher",
        Difficulty = 3,

        Origin = {
            TooltipText = "It was carrying a block. It is still carrying a block.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        Health = 1200,
        BaseSpeed = 11.8,
        SprintSpeedMultiplier = 27 / 11.8,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 110,
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

                Damage = 28,
                Cooldown = 2.1,
                Duration = 0.38,
                Delay = 0.18,
                --- Twelve studs deep. Narrow, so it loses to sidestepping.
                HitboxSize = Vector3.new(4, 7, 12),
                HitboxOffset = CFrame.new(0, 0, -6),

                Behaviour = SwipeBehaviour,
            }),

            Teleport = Ability.New({
                Name = "Teleport",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 8,
                Duration = 0.3,

                Distance = 60,

                UseSound = "rbxassetid://9125402735",
                Behaviour = TeleportBehaviour,
            }),

            Block = Ability.New({
                Name = "Block",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 5,
                Duration = 0.25,

                BlockSize = 6,
                BlockHealth = 70,
                BlockLifetime = 25,
                PlaceDistance = 8,
                CarrySpeedMultiplier = 0.92,
                Limit = 4,

                PickupSound = "rbxassetid://12222216",
                PlaceSound = "rbxassetid://9046319808",
                Behaviour = BlockBehaviour,
            }),

            Ambush = Ability.New({
                Name = "Ambush",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 28,
                Duration = 0.5,

                Range = 200,
                Warning = 0.9,
                Damage = 40,

                WarnSound = "rbxassetid://9125402735",
                UseSound = "rbxassetid://9118823103",
                Behaviour = AmbushBehaviour,
            }),

            Stare = Ability.New({
                Name = "Don't Look At Me",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                Range = 90,
                --- Cumulative seconds of facing it before it snaps.
                Threshold = 2.5,
                --- Dot product cutoff. 0.6 is about a 53 degree cone either side.
                Tolerance = 0.6,
                MarkTime = 10,
                RageTime = 6,
                RageSpeedMultiplier = 1.3,
                WaterSpeedMultiplier = 0.62,

                RageSound = "rbxassetid://9118823103",
                ExtraInit = StareInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(170, 60, 230)\">"..Enderman.Config.Name.."</font>"
local Abilities = Enderman.GameplayConfig.Abilities

Enderman.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Enderman.Config.Name:upper()},
    {
        Type = "Text",
        Text = {
            NameLabel.." has the longest melee reach in the arena and no ranged attack whatsoever.",
            "Face it for long enough and it takes it personally: you get <b>Marked</b>, it gets faster, and it can teleport on top of you.",
            "It is slowed badly by water, and its teleport is a short ground-level hop — so high ground and deep water are both genuinely safe.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Enderman.Config.Role,
            "Difficulty: "..string.rep("★", Enderman.Config.Difficulty)..string.rep("☆", 5 - Enderman.Config.Difficulty),
            "Price: "..tostring(Enderman.Config.Price).."$",
            "Health: "..tostring(Enderman.GameplayConfig.Health),
            "Base Speed: "..tostring(Enderman.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Enderman.GameplayConfig.BaseSpeed * Enderman.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "LONG-ARM SWIPE"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds, reaching "..tostring(Abilities.Slash.HitboxSize.Z).." studs — roughly double anybody else's.",
            "Slow, narrow and heavily telegraphed. Step sideways, not backwards.",
        },
    },

    {Type = "Header", Text = "TELEPORT  (Q)"},
    {
        Type = "Text",
        Text = {
            "Up to "..tostring(Abilities.Teleport.Distance).." studs along its facing. The destination is validated — it will not put itself inside geometry, and it refuses rather than teleporting somewhere illegal.",
            "Ground level only. It cannot follow you up.",
            "Cooldown: "..tostring(Abilities.Teleport.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "BLOCK  (E)"},
    {
        Type = "Text",
        Text = {
            "Press once to pick up a block, again to put it down. While carrying, it moves 8% slower and the block is plainly visible.",
            "Placed blocks are solid, have "..tostring(Abilities.Block.BlockHealth).." health, last "..tostring(Abilities.Block.BlockLifetime).." seconds, and "..tostring(Abilities.Block.Limit).." can be out at once.",
            "Cooldown: "..tostring(Abilities.Block.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "AMBUSH  (R)"},
    {
        Type = "Text",
        Text = {
            "Teleports behind whoever it has enraged at — or anybody <b>Marked</b> — and hits them for "..tostring(Abilities.Ambush.Damage).." damage.",
            "You get "..tostring(Abilities.Ambush.Warning).." seconds of warning: particles around your feet, a sound, and a red screen. It arrives where you ARE, so you cannot dodge it — but you can choose where you are standing when it does.",
            "Needs a marked target. It cannot open with this.",
            "Cooldown: "..tostring(Abilities.Ambush.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "DON'T LOOK AT ME  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Facing it, within "..tostring(Abilities.Stare.Range).." studs, with a clear line of sight, builds up. At "..tostring(Abilities.Stare.Threshold).." cumulative seconds it snaps.",
            "You are <b>Marked</b> for "..tostring(Abilities.Stare.MarkTime).." seconds and it moves 30% faster for "..tostring(Abilities.Stare.RageTime).." of them.",
            "Looking away bleeds the counter back down. One glance costs nothing.",
        },
    },
}

return Enderman
