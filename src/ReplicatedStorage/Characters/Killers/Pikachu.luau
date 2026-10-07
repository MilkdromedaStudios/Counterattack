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
local MeterService = require(ReplicatedStorage.Modules.MeterService)
local ProjectileService = require(ReplicatedStorage.Modules.ProjectileService)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

--[=[
    PIKACHU — FAST, FRAGILE, AND ELECTRICAL.

      M1  QUICK ATTACK  A short dash that hits. It IS the movement and the attack.
      Q   THUNDER SHOCK A fast bolt. Cheap, spammable, and it leaves a charge behind.
      E   THUNDERBOLT   Chain lightning. Jumps between people, preferring the charged.
      R   THUNDER       A telegraphed column from the sky. The biggest hit in the kit.
      F   ELECTRO WEB   A field on the floor that slows and charges anybody standing in it.
      P   STATIC        Electrical hits build Charge. At full, the next one is much bigger.

    THE BASIC ATTACK IS A DASH
    --------------------------
    Quick Attack moves him eighteen studs and damages whatever he passes through, on a short
    cooldown. It is the only basic attack on the roster that is ALSO his mobility — which
    means every approach, every escape and every trade are the same button, and spending it
    to attack is spending it to move.

    That is why he has no other movement ability at all.

    STATIC IS THE PAYOFF LOOP
    -------------------------
    Every electrical hit adds Charge. At full, the next electrical attack costs the whole
    meter and does +60% damage with a wider effect. The meter decays, so it has to be spent
    rather than banked — and because `Thunder Shock` is the cheapest way to fill it and
    `Thunder` is the best way to spend it, his gameplay has a natural rhythm: poke, poke,
    poke, then drop the big one.

    `Electrified` is the condition the chain reads. Anybody carrying it takes a few fast
    ticks of damage and becomes the preferred next link in `Thunderbolt` — so spreading the
    charge around is what makes the chain reach.

    WEAKNESSES
    ----------
    1000 health, joint-lowest with 1x1x1x1. `Thunder` is a telegraphed circle anybody can
    walk out of. He has no melee to speak of beyond the dash, nothing that creates distance
    when the dash is down, and no defensive ability whatsoever.
]=]

local PIKA = Color3.fromRGB(255, 215, 60)
local PIKA_DEEP = Color3.fromRGB(255, 160, 20)
local CHARGE_METER = "Charge"

--------------------------------------------------------------------------------
-- STATIC
--------------------------------------------------------------------------------

--[=[
    Adds Charge, and reports whether the attack that just fired was the empowered one.

    Called at the TOP of every electrical ability: it consumes a full meter and returns
    `true`, or adds to the meter and returns `false`. One function so there is exactly one
    place that decides when Static spends itself, and no ability can forget to.
]=]
local function ConsumeCharge(self: Types.Ability, gain: number): boolean
    local Char = self.OwnerProperties.Character
    if not Char then
        return false
    end

    if MeterService.IsFull(Char, CHARGE_METER) then
        MeterService.Set(Char, CHARGE_METER, 0)

        local Root = Utils.Character.GetRootPart(Char)
        if Root then
            AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "CHARGED", PIKA, 1.1)
            AbilityFX.Ring(Root.Position, 10, PIKA, {Duration = 0.4})
        end

        return true
    end

    MeterService.Add(Char, CHARGE_METER, gain)
    return false
end

--------------------------------------------------------------------------------
-- M1 — QUICK ATTACK
--------------------------------------------------------------------------------

--[=[
    A dash that hits.

    `CombatUtils.Dash` carries him forward, and a hitbox follows him for the whole dash so
    everybody he passes through takes it — once each, tracked in a local set.

    It is a short cooldown because it is his only movement. The damage is low for a basic
    attack precisely because of that: he is paying for the mobility, not the hit.
]=]
local function QuickAttackBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.2, Duration = self.DashTime + 0.1})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.6, MinPitch = 1.3, MaxPitch = 1.5})

    -- Steerable, so it reads as darting rather than charging.
    CombatUtils.Dash(Char, self.DashSpeed, self.DashTime, true)

    local Struck = {}

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.DashTime and Char and Char.Parent do
            Elapsed += task.wait(0.04)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            -- A streak of yellow behind him. Most of what makes it read as Quick Attack.
            AbilityFX.Burst(Live.Position, 2.5, PIKA, {Duration = 0.2, StartSize = 2, Transparency = 0.6})

            for _, Target: Model in CombatUtils.GetFightersInRadius(Live.Position, self.Radius, Char) do
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
                    Reason = "Quick Attack",
                })

                AbilityFX.Sparks(TargetRoot.Position, PIKA, 8, 16)
                AbilityFX.ShakeFor(Target, 1.5, 0.2)

                -- Physical, not electrical: it does NOT build Charge. The dash is movement.
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Q — THUNDER SHOCK
--------------------------------------------------------------------------------

local function ShockBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.96, Duration = 0.25, Lock = 0.35})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Empowered = ConsumeCharge(self, self.ChargeGain)

    local Damage = Empowered and self.Damage * self.ChargedMultiplier or self.Damage
    local Radius = Empowered and 4 or 2.4

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.8, MinPitch = 1.1, MaxPitch = 1.3})

    local Muzzle = Root.Position + Root.CFrame.LookVector * 2.5 + Vector3.new(0, 1, 0)

    -- A jagged bolt out of him rather than a straight tracer. This is what separates him
    -- visually from Superman's heat vision and Sans' beams.
    AbilityFX.Bolt(Muzzle, Muzzle + Root.CFrame.LookVector * 14, PIKA, {
        Segments = 5,
        Spread = 2,
        Width = Empowered and 0.8 or 0.45,
        Duration = 0.15,
    })

    ProjectileService.Fire({
        SourcePlayer = self.Owner,
        Name = "ThunderShock",
        Origin = Muzzle,
        Direction = Root.CFrame.LookVector,
        Speed = self.Speed,
        Lifetime = self.Range / self.Speed,
        Radius = Radius,
        Damage = Damage,
        Reason = self.Name,
        Pierce = Empowered and 2 or 1,
        Visual = {
            Shape = Enum.PartType.Ball,
            Size = Vector3.one * (Empowered and 2.6 or 1.6),
            Color = PIKA,
            Material = Enum.Material.Neon,
            Trail = true,
            TrailColor = PIKA_DEEP,
            Light = true,
            LightRange = Empowered and 16 or 10,
        },
        OnStep = function(projectile, _delta, position)
            -- Arcs crackling off it as it travels.
            if projectile.Age % 0.1 < 0.04 then
                AbilityFX.Bolt(position, position + Vector3.new(
                    (math.random() - 0.5) * 6,
                    (math.random() - 0.5) * 6,
                    (math.random() - 0.5) * 6
                ), PIKA, {Segments = 2, Spread = 1, Width = 0.2, Duration = 0.1})
            end
        end,
        OnHit = function(_projectile, humanoid: Humanoid)
            local Victim = humanoid.Parent
            if not Victim or not Victim:IsA("Model") then
                return nil
            end

            CombatUtils.ApplyEffectTo(Victim, "Electrified", Empowered and 2 or 1, self.ChargeTime)
            AbilityFX.ScreenFor(Victim, "Zap", 0.4, Empowered and 1.3 or 0.8)

            local VictimRoot = Utils.Character.GetRootPart(Victim)
            if VictimRoot then
                AbilityFX.Sparks(VictimRoot.Position, PIKA, 12, 22)
            end

            return nil
        end,
        OnImpact = function(_projectile, position: Vector3)
            AbilityFX.Sparks(position, PIKA, 10, 20)
        end,
    })
end

--------------------------------------------------------------------------------
-- E — THUNDERBOLT
--------------------------------------------------------------------------------

--[=[
    Chain lightning.

    Starts on the nearest fighter and jumps outward, up to `Jumps` links, losing `Falloff` of
    its damage each time. The jump PREFERS targets already carrying `Electrified`, which is
    the whole reason to spread charge around with `Thunder Shock` and `Electro Web` first —
    a well-prepared Thunderbolt reaches across a four-way fight, and an unprepared one hits
    whoever happens to be standing nearby.

    Each link is drawn as a real bolt between the two bodies, so the path it took is visible
    afterwards.
]=]
local function ThunderboltBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.1, Duration = 0.5, Lock = 0.5, Shake = 1.5, ShakeTime = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Empowered = ConsumeCharge(self, self.ChargeGain)

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.95, RollOffMaxDistance = 160})

    local Struck = {}
    local From = Root.Position + Vector3.new(0, 1, 0)
    local Damage = Empowered and self.Damage * self.ChargedMultiplier or self.Damage
    local Jumps = Empowered and self.Jumps + self.ChargedJumps or self.Jumps
    local Range = Empowered and self.Range * 1.3 or self.Range

    for _ = 1, Jumps do
        ------------------------------------------------------------------------
        -- PICK THE NEXT LINK
        ------------------------------------------------------------------------

        --[[
            Charged targets first.

            Two passes rather than a sort: the candidate list is already distance-ordered by
            `GetFightersInRadius`, so one pass for charged targets and a second for anybody
            keeps "nearest" as the tiebreak without re-sorting.
        ]]
        local Next = nil

        for _, Candidate: Model in CombatUtils.GetFightersInRadius(From, Range, Char) do
            if Struck[Candidate] then
                continue
            end
            if Utils.Instance.FindFirstChild(Candidate, "Effects.Electrified", 0) then
                Next = Candidate
                break
            end
        end

        if not Next then
            for _, Candidate: Model in CombatUtils.GetFightersInRadius(From, Range, Char) do
                if not Struck[Candidate] then
                    Next = Candidate
                    break
                end
            end
        end

        if not Next then
            break
        end

        Struck[Next] = true

        ------------------------------------------------------------------------
        -- STRIKE IT
        ------------------------------------------------------------------------

        local NextRoot = Utils.Character.GetRootPart(Next)
        if NextRoot then
            local To = NextRoot.Position + Vector3.new(0, 1, 0)

            AbilityFX.Bolt(From, To, PIKA, {
                Segments = 7,
                Spread = 3,
                Width = Empowered and 0.9 or 0.55,
                Duration = 0.25,
            })
            AbilityFX.Burst(To, Empowered and 9 or 6, PIKA, {Duration = 0.3})
            AbilityFX.Sparks(To, PIKA, 16, 26)

            From = To
        end

        local Humanoid = Next:FindFirstChildWhichIsA("Humanoid")
        if Humanoid then
            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = Damage,
                Reason = self.Name,
            })

            CombatUtils.ApplyEffectTo(Next, "Electrified", Empowered and 3 or 2, self.ChargeTime)
            CombatUtils.ApplyEffectTo(Next, "Disoriented", 1, self.DisorientTime)
            AbilityFX.ScreenFor(Next, "Zap", 0.6, 1.1)
            AbilityFX.ShakeFor(Next, 2.5, 0.3)
        end

        -- Each link is weaker than the last.
        Damage *= self.Falloff
        task.wait(0.08)
    end

    if not next(Struck) then
        -- Nothing in range at all. Refund.
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "nothing to chain", PIKA, 0.9)
    end
end

--------------------------------------------------------------------------------
-- R — THUNDER
--------------------------------------------------------------------------------

--[=[
    A column out of the sky, on a telegraph.

    The biggest single hit in the kit, and the most avoidable: a filling circle appears on
    the ground where he was aiming, 1.1 seconds before the bolt lands. He does not have to
    stand still — but the circle does not follow anybody, so it hits where it was CALLED,
    not where you are.

    That is the fair version of a sky-strike: enormous damage, perfect information, and the
    only decision is whether you believe the person you are fighting will still be there.
]=]
local function ThunderBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.9, Duration = 0.5, Lock = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Empowered = ConsumeCharge(self, self.ChargeGain)

    local Radius = Empowered and self.Radius * 1.4 or self.Radius
    local Damage = Empowered and self.Damage * self.ChargedMultiplier or self.Damage

    --[[
        Aimed at the nearest fighter if there is one, otherwise straight ahead.

        Aiming at a target rather than at a cursor keeps this server-authoritative: asking
        the client where its mouse is would mean yielding on a client call inside an ability,
        which a hostile client can stall indefinitely.
    ]]
    local Target = CombatUtils.GetClosestFighter(Root.Position, self.Range, Char)
    local Aim = Target and Utils.Character.GetRootPart(Target)
    local Spot = Aim and Aim.Position or (Root.Position + Root.CFrame.LookVector * 20)

    local Ground = AbilityFX.GroundAt(Spot, {Char}, 60) or Spot

    AbilityFX.Sound(self.CallSound, Ground, {Volume = 0.9, RollOffMaxDistance = 190})

    -- THE TELEGRAPH. This is the counterplay and it is deliberately generous.
    AbilityFX.Telegraph(Ground, Radius, PIKA, self.Warning)
    AbilityFX.ScreenInRadius(Ground, Radius, "Rage", self.Warning, 0.8, Char)

    -- Clouds gathering overhead while it charges.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Warning do
            Elapsed += task.wait(0.15)
            AbilityFX.Bolt(
                Ground + Vector3.new((math.random() - 0.5) * Radius, 60, (math.random() - 0.5) * Radius),
                Ground + Vector3.new((math.random() - 0.5) * Radius, 45, (math.random() - 0.5) * Radius),
                PIKA,
                {Segments = 3, Spread = 4, Width = 0.3, Duration = 0.12}
            )
        end
    end)

    task.delay(self.Warning, function()
        ------------------------------------------------------------------------
        -- THE STRIKE
        ------------------------------------------------------------------------

        AbilityFX.Sound(self.UseSound, Ground, {Volume = 1, RollOffMaxDistance = 250})

        -- The column itself: a thick bolt out of the sky plus a pillar of light.
        AbilityFX.Bolt(Ground + Vector3.new(0, 120, 0), Ground, PIKA, {
            Segments = 11,
            Spread = 5,
            Width = Empowered and 2.5 or 1.6,
            Duration = 0.45,
        })
        AbilityFX.Beam(Ground + Vector3.new(0, 60, 0), Ground, Color3.new(1, 1, 1), {
            Width = Radius * 0.35,
            Duration = 0.4,
            Transparency = 0.45,
        })
        AbilityFX.Shockwave(Ground, Radius, PIKA, 40)
        AbilityFX.ShakeInRadius(Ground, Radius * 2.5, 6, 0.7)

        for _, Victim: Model in CombatUtils.GetFightersInRadius(Ground, Radius, Char) do
            local Humanoid = Victim:FindFirstChildWhichIsA("Humanoid")
            local VictimRoot = Utils.Character.GetRootPart(Victim)
            if not Humanoid or not VictimRoot then
                continue
            end

            -- Full damage in the middle, 40% at the rim.
            local Falloff = 1 - 0.6 * math.clamp((VictimRoot.Position - Ground).Magnitude / Radius, 0, 1)

            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = Damage * Falloff,
                Reason = self.Name,
                KnockbackDirection = Vector3.new(0, 1, 0),
                KnockbackMagnitude = 8 * Falloff,
            })

            CombatUtils.ApplyEffectTo(Victim, "Electrified", 3, self.ChargeTime)
            CombatUtils.ApplyEffectTo(Victim, "Fragile", 2, 6)
            AbilityFX.ScreenFor(Victim, "Zap", 1, 1.6)
            AbilityFX.ShakeFor(Victim, 6, 0.7)
        end
    end)
end

--------------------------------------------------------------------------------
-- F — ELECTRO WEB
--------------------------------------------------------------------------------

--[=[
    A field on the floor.

    Slows and charges everybody standing in it, and does almost no damage. Its real job is
    SETUP: anybody in the web is `Electrified`, which makes them the preferred link for
    `Thunderbolt` — so a web dropped in a doorway turns a one-target chain into a four-target
    one.

    It is a `CombatUtils.CreateZone`, which handles its own lifetime and ticking and cleans
    up with the map.
]=]
local function WebBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.35, Lock = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Centre = AbilityFX.GroundAt(Root.Position + Root.CFrame.LookVector * self.Distance, {Char})
        or (Root.Position + Root.CFrame.LookVector * self.Distance)

    AbilityFX.Sound(self.UseSound, Centre, {Volume = 0.85})

    -- A lattice of bolts across the floor, drawn once at placement.
    for _ = 1, 10 do
        local A = (math.random() * math.pi * 2)
        local B = (math.random() * math.pi * 2)
        AbilityFX.Beam(
            Centre + Vector3.new(math.cos(A) * self.Radius, 0.3, math.sin(A) * self.Radius),
            Centre + Vector3.new(math.cos(B) * self.Radius, 0.3, math.sin(B) * self.Radius),
            PIKA,
            {Width = 0.3, Duration = self.Lifetime, Transparency = 0.55}
        )
    end

    CombatUtils.CreateZone({
        SourcePlayer = self.Owner,
        Position = Centre,
        Radius = self.Radius,
        Lifetime = self.Lifetime,
        TickRate = self.TickRate,
        Damage = self.TickDamage,
        IgnoreOwner = true,
        Color = PIKA,
        Material = Enum.Material.Neon,
        Transparency = 0.6,
        Effects = {
            {Name = "Slowness", Level = self.SlowLevel, Duration = self.TickRate + 0.5},
            --[[
                The charge is the point. Level 1 so the damage-over-time is negligible —
                this is here to make people into chain targets, not to kill them.
            ]]
            {Name = "Electrified", Level = 1, Duration = self.TickRate + 0.5},
        },
        OnTick = function(fighters: {Model})
            for _, Target: Model in fighters do
                local TargetRoot = Utils.Character.GetRootPart(Target)
                if TargetRoot then
                    AbilityFX.Bolt(
                        TargetRoot.Position + Vector3.new(0, 2, 0),
                        TargetRoot.Position - Vector3.new(0, 2, 0),
                        PIKA,
                        {Segments = 3, Spread = 1, Width = 0.25, Duration = 0.15}
                    )
                end
            end
        end,
    })
end

--------------------------------------------------------------------------------
-- PASSIVE — STATIC
--------------------------------------------------------------------------------

local function StaticInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    MeterService.Define(Char, CHARGE_METER, {
        Max = 100,
        Start = 0,
        RegenPerSecond = 0,
        --[[
            It decays, so Charge has to be SPENT rather than banked.

            A meter that sat at full indefinitely would mean every fight opened with the
            empowered version of whatever he wanted, which is a burst character rather than
            a rhythm one.
        ]]
        DecayPerSecond = self.Decay,
    })

    -- Arcs off him while charged, so opponents know the next one is the big one.
    self:AddConnection(task.spawn(function()
        while Char and Char.Parent do
            task.wait(0.3)

            if not MeterService.IsFull(Char, CHARGE_METER) then
                continue
            end

            local Root = Utils.Character.GetRootPart(Char)
            if not Root then
                continue
            end

            AbilityFX.Bolt(
                Root.Position + Vector3.new(0, 2, 0),
                Root.Position + Vector3.new((math.random() - 0.5) * 7, math.random() * 3, (math.random() - 0.5) * 7),
                PIKA,
                {Segments = 3, Spread = 1.5, Width = 0.3, Duration = 0.18}
            )
            AbilityFX.Tint(Char, PIKA, 0.35, {FillTransparency = 0.8})
        end
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Pikachu: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Pikachu",
        Quote = "Pika.",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 14000,

        Role = "Ranged",
        Difficulty = 4,

        Origin = {
            TooltipText = "It refused the ball.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            Joint-lowest health with 1x1x1x1, and no defensive ability at all. Everything he
            has is damage or setup, and his only escape is the same button as his attack.
        ]]
        Health = 1000,
        BaseSpeed = 11.7,
        SprintSpeedMultiplier = 27 / 11.7,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 100,
            StaminaDrain = 11,
            StaminaGain = 23,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222030",
                UseAnimation = "rbxassetid://133504250023139",

                --- Low, because it is also his movement.
                Damage = 18,
                Cooldown = 2.2,
                Duration = 0.3,

                DashSpeed = 95,
                DashTime = 0.22,
                Radius = 6,

                Behaviour = QuickAttackBehaviour,
            }),

            Shock = Ability.New({
                Name = "Shock",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                --- Cheap and spammable. The way the meter gets filled.
                Cooldown = 3.5,
                Duration = 0.3,

                Damage = 24,
                Speed = 150,
                Range = 110,
                ChargeTime = 1.5,
                ChargeGain = 18,
                ChargedMultiplier = 1.6,

                UseSound = "rbxassetid://9125402735",
                Behaviour = ShockBehaviour,
            }),

            Thunderbolt = Ability.New({
                Name = "Thunderbolt",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 16,
                Duration = 0.6,

                Damage = 38,
                Jumps = 4,
                ChargedJumps = 2,
                --- Each link does 78% of the last.
                Falloff = 0.78,
                Range = 40,
                ChargeTime = 1.5,
                ChargeGain = 22,
                ChargedMultiplier = 1.6,
                DisorientTime = 1.2,

                UseSound = "rbxassetid://9118823103",
                Behaviour = ThunderboltBehaviour,
            }),

            Thunder = Ability.New({
                Name = "Thunder",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 28,
                Duration = 0.6,

                Warning = 1.1,
                Radius = 18,
                Damage = 120,
                Range = 90,
                ChargeTime = 1.5,
                ChargeGain = 25,
                ChargedMultiplier = 1.6,

                CallSound = "rbxassetid://9125402735",
                UseSound = "rbxassetid://9118823103",
                Behaviour = ThunderBehaviour,
            }),

            Web = Ability.New({
                Name = "Web",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 22,
                Duration = 0.4,

                Distance = 14,
                Radius = 17,
                Lifetime = 12,
                TickRate = 0.6,
                --- Almost nothing. It is a setup tool.
                TickDamage = 3,
                SlowLevel = 2,

                UseSound = "rbxassetid://9046319808",
                Behaviour = WebBehaviour,
            }),

            Static = Ability.New({
                Name = "Static",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                --- Units a second. It has to be spent, not banked.
                Decay = 4,

                ExtraInit = StaticInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(255, 215, 60)\">"..Pikachu.Config.Name.."</font>"
local Abilities = Pikachu.GameplayConfig.Abilities

Pikachu.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Pikachu.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Pikachu.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." is joint-lowest health in the arena and has no defensive ability at all.",
            "His basic attack <b>is</b> his movement — Quick Attack dashes and damages on the same button — so every approach, trade and escape spends the same cooldown.",
            "<b>Static</b> builds from electrical hits and makes the next one much bigger. It decays, so it has to be spent rather than saved.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Pikachu.Config.Role,
            "Difficulty: "..string.rep("★", Pikachu.Config.Difficulty)..string.rep("☆", 5 - Pikachu.Config.Difficulty),
            "Price: "..tostring(Pikachu.Config.Price).."$",
            "Health: "..tostring(Pikachu.GameplayConfig.Health).."  (joint lowest)",
            "Base Speed: "..tostring(Pikachu.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Pikachu.GameplayConfig.BaseSpeed * Pikachu.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "QUICK ATTACK"},
    {
        Type = "Text",
        Text = {
            "A steerable dash that deals "..tostring(Abilities.Slash.Damage).." damage to everybody he passes through, once each. Every "..tostring(Abilities.Slash.Cooldown).." seconds.",
            "It is his <b>only movement ability</b>. Attacking and escaping are the same button.",
            "Physical, not electrical — it does not build Static.",
        },
    },

    {Type = "Header", Text = "SHOCK  (Q)"},
    {
        Type = "Text",
        Text = {
            "A bolt for "..tostring(Abilities.Shock.Damage).." damage that leaves the target <b>Electrified</b>.",
            "Cheap and frequent. This is how Static gets filled.",
            "Cooldown: "..tostring(Abilities.Shock.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "THUNDERBOLT  (E)"},
    {
        Type = "Text",
        Text = {
            "Chain lightning: "..tostring(Abilities.Thunderbolt.Jumps).." jumps starting at "..tostring(Abilities.Thunderbolt.Damage).." damage, each link doing 78% of the last.",
            "<b>It jumps to Electrified targets first.</b> Spreading charge with Shock and Web is what makes it reach across a crowd — unprepared, it hits whoever is standing nearby.",
            "Refunds itself if there is nobody in range.",
            "Cooldown: "..tostring(Abilities.Thunderbolt.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "THUNDER  (R)"},
    {
        Type = "Text",
        Text = {
            "A column from the sky for <b>"..tostring(Abilities.Thunder.Damage).." damage</b> across "..tostring(Abilities.Thunder.Radius).." studs, falling off to 40% at the edge.",
            "A circle appears on the ground <b>"..tostring(Abilities.Thunder.Warning).." seconds before it lands</b>, and it does not follow you. It hits where it was called.",
            "Cooldown: "..tostring(Abilities.Thunder.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "WEB  (F)"},
    {
        Type = "Text",
        Text = {
            "A field "..tostring(Abilities.Web.Radius).." studs across for "..tostring(Abilities.Web.Lifetime).." seconds. <b>Slows</b> and <b>Electrifies</b> anybody in it, for only "..tostring(Abilities.Web.TickDamage).." damage a tick.",
            "It is a setup tool. A web in a doorway turns a one-target Thunderbolt into a four-target one.",
            "Cooldown: "..tostring(Abilities.Web.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "STATIC  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Every electrical ability builds Charge. At full, the next one spends the whole meter for <b>+60% damage</b> and a wider effect — more chain jumps, a bigger column, a piercing bolt.",
            "It bleeds away at "..tostring(Abilities.Static.Decay).." a second, and he visibly crackles while it is full. You can see the big one coming.",
        },
    },
}

return Pikachu
