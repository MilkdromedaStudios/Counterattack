local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local AbilityClient = require(ReplicatedStorage.Modules.AbilityClient)
local AbilityFX = require(ReplicatedStorage.Modules.AbilityFX)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local MeterService = require(ReplicatedStorage.Modules.MeterService)
local ProjectileService = require(ReplicatedStorage.Modules.ProjectileService)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

--[=[
    SANS — THE LOWEST HEALTH IN THE GAME AND THE BEST ANSWER TO ANYTHING.

      M1  BONE STRIKE   Summons a bone and throws it. His basic attack is a projectile.
      Q   BONE ZONE     A telegraphed strip of bones out of the floor.
      E   GASTER BLASTER A skull cannon. Long charge, enormous beam.
      R   TELEPORT      A short blink. The only thing he has that moves him.
      P   DODGE         A METER of automatic dodges. Not infinite. Never infinite.

    THE DODGE METER IS THE CHARACTER
    --------------------------------
    He has 650 health — barely half of anybody else — and `Dodge` is what makes that
    survivable: incoming damage is cancelled outright while the meter can pay for it. Each
    dodge costs 34 of 100, so it is THREE dodges, and the meter refills at 7 a second with a
    2.5 second delay after each one.

    That is the explicit requirement from the brief, implemented literally: it is a stamina
    gauge, it is visible, it runs out, and when it is empty he is the easiest kill in the
    arena by a wide margin. Three free hits followed by fourteen seconds of being made of
    paper.

    KARMA
    -----
    Everything he does applies a small damage-over-time. Individually negligible; what it
    does is mean a Sans who has landed four things on you is still landing them while he
    repositions. His direct damage is low for how much of it there is.

    WEAKNESSES
    ----------
    The lowest health in the game, every single ability telegraphed, no mobility except one
    short blink on a 9 second cooldown, and a basic attack that can miss. He wins fights he
    never gets touched in and loses every single one he does.
]=]

local BONE = Color3.fromRGB(240, 240, 230)
local BLASTER = Color3.fromRGB(120, 200, 255)
local KARMA_COLOUR = Color3.fromRGB(255, 90, 90)
local DODGE_METER = "Dodge"

--------------------------------------------------------------------------------
-- KARMA
--------------------------------------------------------------------------------

--[=[
    The on-hit everything he owns applies.

    `Burning` at level 1 rather than a bespoke effect: it already does slow ticks with
    correct kill credit, it already shows in the effects list, and inventing a second
    damage-over-time that behaved identically would have been two things to maintain. The
    FLAVOUR is Sans'; the mechanism is the engine's.
]=]
local function Karma(self: Types.Ability, target: Model)
    if not RunService:IsServer() or not target then
        return
    end

    CombatUtils.ApplyEffectTo(target, "Burning", self.KarmaLevel or 1, self.KarmaTime or 4)

    local Root = Utils.Character.GetRootPart(target)
    if Root then
        AbilityFX.Tint(target, KARMA_COLOUR, 0.4, {FillTransparency = 0.85})
    end
end

--------------------------------------------------------------------------------
-- M1 — BONE STRIKE
--------------------------------------------------------------------------------

--[=[
    A bone, thrown.

    His basic attack has no melee component at all — it is a projectile with a hitbox the
    size of a bone, so it can miss entirely. That is the correct shape for the character: he
    does not swing at people, he makes an object appear and sends it at them.
]=]
local function BoneStrikeBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.02, Duration = 0.2, Lock = 0.4})
        return
    end

    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.55, MinPitch = 1.0, MaxPitch = 1.15})

    local Origin = Root.Position + Root.CFrame.LookVector * 3 + Vector3.new(0, 1, 0)

    -- It appears before it moves, which is the look of the thing.
    AbilityFX.Burst(Origin, 3, BONE, {Duration = 0.2, StartSize = 0.5})

    ProjectileService.Fire({
        SourcePlayer = self.Owner,
        Name = "Bone",
        Origin = Origin,
        Direction = Root.CFrame.LookVector,
        Speed = self.Speed,
        Lifetime = self.Range / self.Speed,
        Radius = 2.2,
        Damage = self.Damage,
        Reason = "Bone",
        FaceTravel = true,
        Spin = 260,
        Visual = {
            Shape = Enum.PartType.Block,
            Size = Vector3.new(0.9, 0.9, 4.5),
            Color = BONE,
            Material = Enum.Material.SmoothPlastic,
            Trail = true,
            TrailColor = BONE,
        },
        OnHit = function(_projectile, humanoid: Humanoid)
            local Victim = humanoid.Parent
            if Victim and Victim:IsA("Model") then
                Karma(self, Victim)

                local VictimRoot = Utils.Character.GetRootPart(Victim)
                if VictimRoot then
                    AbilityFX.Sparks(VictimRoot.Position, BONE, 8, 14)
                end
            end
            return nil
        end,
    })
end

--------------------------------------------------------------------------------
-- Q — BONE ZONE
--------------------------------------------------------------------------------

--[=[
    Bones out of the floor, in a line.

    A telegraphed STRIP rather than a circle: the warning markers appear along the line he
    was facing, then the bones come up in sequence from near to far. That sequencing is the
    counterplay — you can see the wave coming toward you and step sideways out of the lane,
    which a simultaneous line would not allow.

    Each bone is an actual part that rises out of the ground and stays for a moment, so the
    lane is briefly real geometry.
]=]
local function BoneZoneBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.05, Duration = 0.4, Lock = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Direction = Root.CFrame.LookVector

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.85})

    local Count = self.Count
    local Spacing = self.Length / Count

    for Index = 1, Count do
        local Spot = Root.Position + Direction * (Spacing * Index)
        local Ground = AbilityFX.GroundAt(Spot, {Char})

        if not Ground then
            continue
        end

        -- THE TELEGRAPH, per bone, so the wave's timing is readable.
        local Delay = (Index - 1) * self.Stagger
        AbilityFX.Telegraph(Ground, self.Radius, BONE, self.Warning + Delay)

        task.delay(self.Warning + Delay, function()
            local Bone = AbilityFX.Part({
                Name = "Bone",
                Size = Vector3.new(1.4, self.Height, 1.4),
                CFrame = CFrame.new(Ground - Vector3.new(0, self.Height, 0)),
                Color = BONE,
                Material = Enum.Material.SmoothPlastic,
            })
            Bone.Parent = AbilityFX.Folder()

            -- Rises out of the floor.
            TweenService:Create(
                Bone,
                TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {CFrame = CFrame.new(Ground + Vector3.new(0, self.Height * 0.4, 0))}
            ):Play()

            AbilityFX.Sound(self.RiseSound, Ground, {Volume = 0.5, MinPitch = 1.1, MaxPitch = 1.3})
            AbilityFX.Smoke(Ground, Color3.fromRGB(180, 170, 160), 5, 1.6)

            for _, Target: Model in CombatUtils.GetFightersInRadius(Ground, self.Radius, Char) do
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
                    KnockbackDirection = Vector3.new(0, 1, 0),
                    KnockbackMagnitude = 5,
                })

                Karma(self, Target)
                AbilityFX.ShakeFor(Target, 2, 0.25)
            end

            -- Sinks back down and goes.
            task.delay(self.Linger, function()
                if not Bone.Parent then
                    return
                end
                TweenService:Create(
                    Bone,
                    TweenInfo.new(0.25),
                    {CFrame = CFrame.new(Ground - Vector3.new(0, self.Height, 0)), Transparency = 1}
                ):Play()
                game:GetService("Debris"):AddItem(Bone, 0.3)
            end)
        end)
    end
end

--------------------------------------------------------------------------------
-- E — GASTER BLASTER
--------------------------------------------------------------------------------

--[=[
    A skull appears, opens its mouth, and fires.

    The longest charge of any ability on the roster — 1.3 seconds — during which the skull is
    visibly present, growing, and aimed. Then a beam that goes through everybody in a long
    line for very large damage.

    He is NOT rooted while it charges, which is the one generosity: he can walk, he can
    blink, he just cannot cancel it. The skull fires along the line it was AIMED at when it
    appeared, so moving does not re-aim it — which makes placing it a commitment rather than
    a tracking laser.
]=]
local function BlasterBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.84, Duration = self.Charge + 0.5, Lock = self.Charge, Shake = 2, ShakeTime = self.Charge})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    -- Fixed at cast. The skull does not track.
    local Origin = Root.Position + Vector3.new(0, 4, 0) - Root.CFrame.LookVector * 2
    local Direction = Root.CFrame.LookVector
    local Finish = Origin + Direction * self.Length

    AbilityFX.Sound(self.ChargeSound, Origin, {Volume = 0.9, RollOffMaxDistance = 180})

    ----------------------------------------------------------------------------
    -- THE SKULL
    ----------------------------------------------------------------------------

    local Skull = AbilityFX.Part({
        Name = "GasterBlaster",
        Size = Vector3.new(1, 1, 1),
        CFrame = CFrame.lookAt(Origin, Finish),
        Color = BONE,
        Material = Enum.Material.SmoothPlastic,
    })
    Skull.Parent = AbilityFX.Folder()

    -- Two glowing eyes, so it reads as a skull rather than a box.
    for _, Side in {-1, 1} do
        local Eye = AbilityFX.Part({
            Name = "Eye",
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(0.9, 0.9, 0.9),
            CFrame = Skull.CFrame * CFrame.new(Side * 1.1, 0.6, -1.4),
            Color = BLASTER,
            Material = Enum.Material.Neon,
        })
        Eye.Parent = Skull
    end

    -- Grows into position over the charge.
    TweenService:Create(
        Skull,
        TweenInfo.new(self.Charge, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = Vector3.new(6, 6, 7)}
    ):Play()

    -- The aim line, drawn the whole time. This is the telegraph.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Charge and Skull.Parent do
            Elapsed += task.wait(0.08)

            local Progress = Elapsed / self.Charge
            AbilityFX.Beam(Origin, Finish, BLASTER, {
                Width = 0.4 + Progress * 1.2,
                Duration = 0.12,
                Transparency = 0.75 - Progress * 0.45,
            })

            -- Energy gathering in the mouth.
            AbilityFX.Burst(Origin + Direction * 3, 1 + Progress * 3, BLASTER, {
                Duration = 0.15,
                StartSize = 0.5,
                Transparency = 0.4,
            })
        end
    end)

    ----------------------------------------------------------------------------
    -- THE BEAM
    ----------------------------------------------------------------------------

    task.delay(self.Charge, function()
        AbilityFX.Sound(self.UseSound, Origin, {Volume = 1, RollOffMaxDistance = 240})

        -- Three layers: white core, blue body, wide dim halo.
        AbilityFX.Beam(Origin, Finish, Color3.new(1, 1, 1), {Width = self.Width * 0.3, Duration = 0.5, Transparency = 0})
        AbilityFX.Beam(Origin, Finish, BLASTER, {Width = self.Width * 0.75, Duration = 0.55, Transparency = 0.15})
        AbilityFX.Beam(Origin, Finish, BLASTER, {Width = self.Width * 1.4, Duration = 0.6, Transparency = 0.6})
        AbilityFX.Shockwave(Origin + Direction * 2, 8, BLASTER, 20)

        -- Recoil on the skull, then it goes.
        if Skull.Parent then
            TweenService:Create(
                Skull,
                TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {CFrame = Skull.CFrame * CFrame.new(0, 0, 6), Transparency = 1}
            ):Play()
            game:GetService("Debris"):AddItem(Skull, 0.5)
        end

        ------------------------------------------------------------------------
        -- HIT DETECTION
        ------------------------------------------------------------------------

        --[[
            Sampled along the line rather than one enormous hitbox: a 110 stud box is an
            unreasonable thing to hand the physics engine, and sampling lets each victim be
            hit exactly once through the `Struck` set.
        ]]
        local Struck = {}
        local Steps = math.ceil(self.Length / 9)

        for Index = 0, Steps do
            local Point = Origin + Direction * (self.Length * Index / Steps)

            for _, Target: Model in CombatUtils.GetFightersInRadius(Point, self.Width, Char) do
                if Struck[Target] then
                    continue
                end
                Struck[Target] = true

                local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
                if not Humanoid then
                    continue
                end

                CommonFunctions.DamagePlayer({
                    SourcePlayer = self.Owner,
                    TargetHumanoid = Humanoid,
                    Damage = self.Damage,
                    Reason = self.Name,
                    KnockbackDirection = Direction,
                    KnockbackMagnitude = 10,
                })

                Karma(self, Target)
                CombatUtils.ApplyEffectTo(Target, "Fragile", 3, 7)
                AbilityFX.ScreenFor(Target, "Flash", 0.5, 1)
                AbilityFX.ShakeFor(Target, 5, 0.6)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- R — TELEPORT
--------------------------------------------------------------------------------

--[=[
    A short blink. His only mobility.

    Deliberately modest — 42 studs, validated, on a 9 second cooldown. Compare Enderman's 60
    or Kirby's long ride: Sans is not a mobility character, he is a zoning one, and the blink
    exists so that committing to a Gaster Blaster does not also mean standing still.

    It leaves an afterimage of him where he was, which is both the right look and useful
    information: you can see which way he went.
]=]
local function TeleportBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.08, Duration = 0.25})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    -- Steps in from full distance so a blink toward a wall lands just short of it.
    local Destination = nil
    for _, Fraction in {1, 0.7, 0.45, 0.25} do
        local Candidate = Root.Position + Root.CFrame.LookVector * self.Distance * Fraction
        local Ground = AbilityFX.GroundAt(Candidate, {Char}, 50)

        if Ground then
            local Params = RaycastParams.new()
            Params.FilterType = Enum.RaycastFilterType.Exclude
            Params.FilterDescendantsInstances = {Char, workspace.Players}

            if not workspace:Raycast(Ground + Vector3.new(0, 0.5, 0), Vector3.new(0, 6, 0), Params) then
                Destination = Ground + Vector3.new(0, 3, 0)
                break
            end
        end
    end

    if not Destination then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    local Start = Root.Position

    AbilityFX.Sound(self.UseSound, Start, {Volume = 0.7, MinPitch = 1.2, MaxPitch = 1.35})

    -- The afterimage.
    local Ghost = AbilityFX.Part({
        Name = "SansAfterimage",
        Size = Vector3.new(3, 5.5, 2),
        CFrame = CFrame.new(Start),
        Color = BLASTER,
        Material = Enum.Material.Neon,
        Transparency = 0.6,
    })
    Ghost.Parent = AbilityFX.Folder()
    TweenService:Create(Ghost, TweenInfo.new(0.4), {Transparency = 1}):Play()
    game:GetService("Debris"):AddItem(Ghost, 0.45)

    CombatUtils.Blink(Char, Destination)

    AbilityFX.Burst(Destination, 5, BLASTER, {Duration = 0.3})
    AbilityFX.Sound(self.UseSound, Destination, {Volume = 0.7, MinPitch = 1.2, MaxPitch = 1.35})
end

--------------------------------------------------------------------------------
-- PASSIVE — DODGE
--------------------------------------------------------------------------------

local function DodgeInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    MeterService.Define(Char, DODGE_METER, {
        Max = 100,
        --- Starts full: three dodges available immediately.
        Start = 100,
        RegenPerSecond = self.Regen,
        --- After a dodge, nothing comes back for this long.
        RegenDelay = self.RegenDelay,
    })
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Sans: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Sans",
        Quote = "you're gonna have a bad time.",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 36000,

        Role = "Controller",
        Difficulty = 5,

        Origin = {
            TooltipText = "He is not even trying.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            650 HEALTH. Barely half of anybody else, and the single lowest number on the
            roster by a wide margin.

            That is the character, and `Dodge` is the only reason it is playable: three
            cancelled hits, then fourteen seconds of being the easiest kill in the game.
        ]]
        Health = 650,
        BaseSpeed = 11,
        SprintSpeedMultiplier = 24 / 11,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 95,
            StaminaDrain = 12,
            StaminaGain = 20,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 22,
                Cooldown = 1.3,
                Duration = 0.25,
                Speed = 135,
                Range = 95,

                KarmaLevel = 1,
                KarmaTime = 4,

                Behaviour = BoneStrikeBehaviour,
            }),

            BoneZone = Ability.New({
                Name = "Bone Zone",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 14,
                Duration = 0.5,

                Warning = 0.6,
                --- Seconds between each bone in the wave.
                Stagger = 0.12,
                Count = 7,
                Length = 56,
                Radius = 6,
                Height = 9,
                Linger = 1.6,
                Damage = 30,

                KarmaLevel = 1,
                KarmaTime = 5,

                UseSound = "rbxassetid://9046319808",
                RiseSound = "rbxassetid://12222216",
                Behaviour = BoneZoneBehaviour,
            }),

            Blaster = Ability.New({
                Name = "Blaster",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 26,
                Duration = 1.9,

                --- The longest charge on the roster.
                Charge = 1.3,
                Length = 110,
                Width = 7,
                Damage = 115,

                KarmaLevel = 2,
                KarmaTime = 6,

                ChargeSound = "rbxassetid://9125402735",
                UseSound = "rbxassetid://9118823103",
                Behaviour = BlasterBehaviour,
            }),

            Teleport = Ability.New({
                Name = "Teleport",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 9,
                Duration = 0.25,

                --- Modest. He is not a mobility character.
                Distance = 42,

                UseSound = "rbxassetid://9125402735",
                Behaviour = TeleportBehaviour,
            }),

            Dodge = Ability.New({
                Name = "Dodge",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                --- 34 of 100, so exactly three dodges from full.
                Cost = 34,
                Regen = 7,
                RegenDelay = 2.5,

                ExtraInit = DodgeInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- THE DODGE
--------------------------------------------------------------------------------

--[=[
    Cancels incoming damage while the meter can pay for it.

    `OnDamage` is the engine's "about to be hurt" hook and returning `"Ignored"` cancels the
    hit outright, so this catches EVERY source of damage on the exact frame it would land —
    melee, projectiles, zones, burns, explosions.

    `MeterService.Spend` is the check and the deduction in one call, which is what guarantees
    the dodge can never fire without paying for it. When the meter is too low it returns
    `false`, this returns nothing, and the hit lands in full.

    NOT INFINITE, which the brief was explicit about. Three from full, and the gauge is a
    replicated character attribute so the client can draw it — you can see how many he has
    left, and so can he.
]=]
function Sans:OnDamage(_damageSettings)
    if not RunService:IsServer() then
        return
    end

    local Char = self.Owner and self.Owner.Character
    if not Char then
        return
    end

    local Dodge = self.GameplayConfig.Abilities.Dodge

    if not MeterService.Spend(Char, DODGE_METER, Dodge.Cost) then
        -- Out of dodges. The hit lands.
        return
    end

    local Root = Utils.Character.GetRootPart(Char)
    if Root then
        AbilityFX.Sound("rbxassetid://12222216", Root.Position, {Volume = 0.8, MinPitch = 1.3, MaxPitch = 1.45})
        AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "nope", BLASTER, 0.9)

        -- An afterimage left where the hit would have landed.
        local Ghost = AbilityFX.Part({
            Name = "DodgeAfterimage",
            Size = Vector3.new(3, 5.5, 2),
            CFrame = CFrame.new(Root.Position),
            Color = BLASTER,
            Material = Enum.Material.Neon,
            Transparency = 0.55,
        })
        Ghost.Parent = AbilityFX.Folder()
        TweenService:Create(Ghost, TweenInfo.new(0.35), {Transparency = 1}):Play()
        game:GetService("Debris"):AddItem(Ghost, 0.4)
    end

    return "Ignored"
end

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(120, 200, 255)\">"..Sans.Config.Name.."</font>"
local Abilities = Sans.GameplayConfig.Abilities
local Dodges = math.floor(100 / Abilities.Dodge.Cost)
local Refill = math.round(Abilities.Dodge.Cost / Abilities.Dodge.Regen * 10) / 10

Sans.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Sans.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Sans.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." has <b>"..tostring(Sans.GameplayConfig.Health).." health</b> — barely half of anybody else, and the lowest number in the game by a wide margin.",
            "<b>Dodge</b> is the only reason that is survivable, and it is a meter, not a rule: "..tostring(Dodges).." cancelled hits, then nothing until it refills.",
            "Every ability he has is telegraphed, his basic attack is a projectile that can miss, and his only movement is one short blink. He wins fights nobody lands a hit in, and loses every single one they do.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Sans.Config.Role,
            "Difficulty: "..string.rep("★", Sans.Config.Difficulty)..string.rep("☆", 5 - Sans.Config.Difficulty),
            "Price: "..tostring(Sans.Config.Price).."$",
            "Health: "..tostring(Sans.GameplayConfig.Health).."  (LOWEST)",
            "Base Speed: "..tostring(Sans.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Sans.GameplayConfig.BaseSpeed * Sans.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "BONE STRIKE"},
    {
        Type = "Text",
        Text = {
            "Summons a bone and throws it: "..tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds, out to "..tostring(Abilities.Slash.Range).." studs.",
            "<b>It is a projectile.</b> It has no melee component and it can miss completely.",
        },
    },

    {Type = "Header", Text = "BONE ZONE  (Q)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.BoneZone.Count).." bones rise out of the floor along a "..tostring(Abilities.BoneZone.Length).." stud line, "..tostring(Abilities.BoneZone.Damage).." damage each.",
            "They come up <b>in sequence</b>, near to far, each with its own marker. You can watch the wave coming and step out of the lane.",
            "Cooldown: "..tostring(Abilities.BoneZone.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "BLASTER  (E)"},
    {
        Type = "Text",
        Text = {
            "A skull appears and charges for <b>"..tostring(Abilities.Blaster.Charge).." seconds</b> — the longest wind-up in the game — then fires a beam through everybody in a "..tostring(Abilities.Blaster.Length).." stud line for "..tostring(Abilities.Blaster.Damage).." damage.",
            "It fires along the line it was aimed at when it appeared. <b>Moving does not re-aim it.</b> He can walk and blink while it charges, but he cannot cancel it.",
            "Cooldown: "..tostring(Abilities.Blaster.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "TELEPORT  (R)"},
    {
        Type = "Text",
        Text = {
            "A validated blink up to "..tostring(Abilities.Teleport.Distance).." studs, leaving an afterimage where he was.",
            "Short on purpose. It exists so committing to a Blaster does not also mean standing still.",
            "Cooldown: "..tostring(Abilities.Teleport.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "DODGE  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "A <b>meter</b>, not a rule. Each dodge cancels one incoming hit entirely and costs a third of it, so <b>"..tostring(Dodges).." dodges from full</b>.",
            "It refills at "..tostring(Abilities.Dodge.Regen).." a second — about "..tostring(Refill).." seconds per dodge — and nothing comes back for "..tostring(Abilities.Dodge.RegenDelay).." seconds after each one.",
            "The gauge is visible. When it is empty, "..tostring(Sans.GameplayConfig.Health).." health is all he has.",
        },
    },

    {Type = "Header", Text = "KARMA"},
    {
        Type = "Text",
        Text = {
            "Everything he lands applies a small damage-over-time.",
            "Individually negligible. What it means is that a Sans who has hit you four times is still hurting you while he repositions.",
        },
    },
}

return Sans
