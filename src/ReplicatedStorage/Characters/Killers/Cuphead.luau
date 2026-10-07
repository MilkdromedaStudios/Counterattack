local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

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
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    CUPHEAD — THE ONLY KILLER WITH NO MELEE AT ALL.

      M1  FINGER GUN   Rapid peashooter. Nine damage a shot, three shots a second.
      Q   DASH         A hard horizontal dash with real invulnerability frames.
      E   EX SHOT      Spends meter for one big pink round.
      R   PARRY        A window. Take a hit inside it and it doesn't land — it pays.
      F   SUPER ART    Full meter only. A beam that crosses the arena.
      P   SUPER METER  Fills from landing shots and from parrying. Nothing else.

    HIS BASIC ATTACK IS A PROJECTILE
    --------------------------------
    He is the one character whose M1 has no hitbox on his own body. It still goes through
    `Slash` and still sits on the attack key, but it fires a bullet — so his entire damage
    output is at range and his close-quarters game is "leave".

    THE METER IS THE SKILL CEILING
    -----------------------------
    It does not regenerate. It fills from LANDING shots, which rewards accuracy, and it
    fills much faster from PARRYING, which rewards reading the other player. A Cuphead who
    only shoots gets a Super Art eventually; a Cuphead who parries gets one every fight.

    THE PARRY IS A REAL PARRY. It is a 0.45 second window with a 9 second cooldown. Mistime
    it and you have spent a cooldown standing still; time it and you take no damage, gain a
    third of a Super Art, and get a burst of speed to punish with.

    WEAKNESSES
    ----------
    1050 health, no melee, nothing that creates distance except the dash, and every piece of
    his damage is a dodgeable projectile. Walk him into a corner and he has one dash.
]=]

local CUP = Color3.fromRGB(240, 70, 60)
local PINK = Color3.fromRGB(255, 120, 200)
local SUPER_METER = "Super"

--- Attribute marking the parry window, so `OnDamage` and the client can both read it.
local PARRY_ATTRIBUTE = "CupheadParryUntil"

--------------------------------------------------------------------------------
-- M1 — FINGER GUN
--------------------------------------------------------------------------------

local function FingerGunBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.02, Duration = 0.12, Lock = 0.25})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.45, MinPitch = 1.15, MaxPitch = 1.35})

    local Muzzle = Root.Position + Root.CFrame.LookVector * 2.5 + Vector3.new(0, 1.2, 0)

    ProjectileService.Fire({
        SourcePlayer = self.Owner,
        Name = "Peashooter",
        Origin = Muzzle,
        Direction = Root.CFrame.LookVector,
        Speed = self.Speed,
        Lifetime = self.Range / self.Speed,
        Radius = 1.6,
        Damage = self.Damage,
        Reason = "Finger Gun",
        Visual = {
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(1.1, 1.1, 1.1),
            Color = PINK,
            Material = Enum.Material.Neon,
            Trail = true,
            TrailColor = CUP,
            Light = true,
            LightRange = 8,
        },
        OnHit = function(_projectile, humanoid: Humanoid)
            -- Landing shots is how the meter fills. Missing them costs nothing but the
            -- meter, which is exactly the pressure a shooting character should feel.
            MeterService.Add(Char, SUPER_METER, self.MeterPerHit)

            local Victim = humanoid.Parent
            local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
            if VictimRoot then
                AbilityFX.Sparks(VictimRoot.Position, PINK, 7, 16)
            end

            return nil
        end,
        OnImpact = function(_projectile, position: Vector3)
            AbilityFX.Burst(position, 2.5, PINK, {Duration = 0.18})
        end,
    })

    -- A cartoon muzzle pop. Exaggerated on purpose; it is the one thing on screen three
    -- times a second.
    AbilityFX.Burst(Muzzle, 3, PINK, {Duration = 0.14, StartSize = 1})
end

--------------------------------------------------------------------------------
-- Q — DASH
--------------------------------------------------------------------------------

--[=[
    The dash, with invulnerability frames.

    Short — a third of a second — and NOT steerable: it goes exactly where he was pointing,
    the way the real one does. The i-frames are `Resistance` at level 5 for the duration,
    which `CommonFunctions.DamagePlayer` reads as a very large damage reduction rather than
    true immunity. That is deliberate: a hard immunity window invites "dash through the
    explosion" play, and a very strong reduction rewards the same timing without making
    anything unhittable.

    Every dash on the roster is different, and this one is the shortest and the only one with
    defensive value — see Knuckles for momentum, Pikachu for a teleport-strike, Superman for
    sustained flight.
]=]
local function DashBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.2, Duration = self.DashTime + 0.1})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.7, MinPitch = 1.1, MaxPitch = 1.2})

    -- `false` for steerable: it is a committed line, not a curve.
    CombatUtils.Dash(Char, self.DashSpeed, self.DashTime, false)

    CombatUtils.ApplyEffectTo(Char, "Resistance", 5, self.DashTime)

    -- An afterimage trail of him, which is most of what sells it as a cartoon dash.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.DashTime and Char and Char.Parent do
            Elapsed += task.wait(0.05)
            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                AbilityFX.Burst(Live.Position, 3, PINK, {Duration = 0.25, StartSize = 2, Transparency = 0.7})
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- E — EX SHOT
--------------------------------------------------------------------------------

local function ExShotBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.92, Duration = 0.35, Lock = 0.5, Shake = 1, ShakeTime = 0.2})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    --[[
        `MeterService.Spend` is the check AND the deduction in one call, so the two cannot
        drift apart. Refunding the cooldown on failure matters here: without it, pressing E
        with an empty meter would cost 7 seconds for nothing.
    ]]
    if not MeterService.Spend(Char, SUPER_METER, self.MeterCost) then
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "no meter", PINK, 0.8)
        return
    end

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.9})

    local Muzzle = Root.Position + Root.CFrame.LookVector * 3 + Vector3.new(0, 1.2, 0)

    ProjectileService.Fire({
        SourcePlayer = self.Owner,
        Name = "ExShot",
        Origin = Muzzle,
        Direction = Root.CFrame.LookVector,
        Speed = self.Speed,
        Lifetime = self.Range / self.Speed,
        Radius = 4,
        Damage = self.Damage,
        Reason = self.Name,
        Knockback = 8,
        -- Goes through two people. It is a big pink cannonball.
        Pierce = 2,
        Spin = 400,
        Visual = {
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(3.5, 3.5, 3.5),
            Color = PINK,
            Material = Enum.Material.Neon,
            Trail = true,
            TrailColor = CUP,
            Light = true,
            LightRange = 18,
            Emitter = {
                Color = ColorSequence.new(PINK, CUP),
                Rate = 55,
                Size = NumberSequence.new(1.6),
                Speed = NumberRange.new(0, 4),
            },
        },
        OnHit = function(_projectile, humanoid: Humanoid)
            local Victim = humanoid.Parent
            local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
            if VictimRoot then
                AbilityFX.Shockwave(VictimRoot.Position, 8, PINK, 18)
                AbilityFX.ShakeFor(Victim, 2, 0.3)
            end
            return nil
        end,
        OnImpact = function(_projectile, position: Vector3)
            AbilityFX.Shockwave(position, 7, PINK, 14)
        end,
    })
end

--------------------------------------------------------------------------------
-- R — PARRY
--------------------------------------------------------------------------------

--[=[
    Opens the parry window.

    The window itself is just a timestamp on the character. The actual parrying happens in
    `Cuphead.OnDamage` below, which is the engine's hook for "this character is about to take
    damage" — returning `"Ignored"` from it cancels the hit entirely.

    Putting it there rather than in a loop is what makes it a real parry: it catches ANY
    source of damage, from any character, on the exact frame it would have landed. A
    polling implementation would have been a few frames out either way, which for a 0.45
    second window is the difference between a mechanic and a lottery.
]=]
local function ParryBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.88, Duration = self.Window, Lock = self.Window})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    Char:SetAttribute(PARRY_ATTRIBUTE, os.clock() + self.Window)

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.6, MinPitch = 1.2, MaxPitch = 1.3})

    -- A pink flash around him for exactly the window, so both players can see it.
    AbilityFX.Tint(Char, PINK, self.Window, {FillTransparency = 0.6})
    AbilityFX.Ring(Root.Position, 6, PINK, {Duration = self.Window, Thickness = 0.4})
end

--------------------------------------------------------------------------------
-- F — SUPER ART
--------------------------------------------------------------------------------

--[=[
    The payoff. Full meter only.

    A beam along his facing: 14 studs wide, the length of most sightlines, and it goes
    through everybody in it. It takes a short wind-up during which he is rooted, with the
    beam's path drawn on the ground first — so from the other side it is the clearest
    telegraph in the game, and from his side it is a commitment.
]=]
local function SuperArtBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.8, Duration = self.Windup + 0.4, Lock = self.Windup + 0.4, Shake = 3, ShakeTime = self.Windup})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    if not MeterService.IsFull(Char, SUPER_METER) then
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "not ready", PINK, 0.9)
        return
    end

    MeterService.Set(Char, SUPER_METER, 0)

    local Direction = Root.CFrame.LookVector
    local Origin = Root.Position + Vector3.new(0, 1.5, 0)
    local Finish = Origin + Direction * self.Length

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 1, RollOffMaxDistance = 200})
    AbilityFX.Text(Origin + Vector3.new(0, 6, 0), "SUPER!", PINK, 1.6)

    -- Rooted while charging. `Snared` rather than anchoring, so it is visible and other
    -- systems understand it.
    CombatUtils.ApplyEffectTo(Char, "Snared", 5, self.Windup)

    -- THE TELEGRAPH: the beam's path, drawn thin, for the whole wind-up.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Windup do
            Elapsed += task.wait(0.1)
            AbilityFX.Beam(Origin, Finish, PINK, {Width = 0.6, Duration = 0.15, Transparency = 0.5})
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

        local Start = Live.Position + Vector3.new(0, 1.5, 0)
        local End = Start + Direction * self.Length

        -- The beam. Three stacked layers so it reads as a cartoon energy blast rather than
        -- a laser pointer.
        AbilityFX.Beam(Start, End, Color3.new(1, 1, 1), {Width = self.Width * 0.3, Duration = 0.5, Transparency = 0})
        AbilityFX.Beam(Start, End, PINK, {Width = self.Width * 0.7, Duration = 0.55, Transparency = 0.2})
        AbilityFX.Beam(Start, End, CUP, {Width = self.Width, Duration = 0.6, Transparency = 0.55})
        AbilityFX.Shockwave(Start, 10, PINK, 26)

        --[[
            Hit detection along the beam.

            Sampled in steps rather than with one long hitbox, because a 120 stud box would
            be an unreasonable thing to hand the physics engine and because sampling lets
            each victim be hit exactly once — the `Struck` set.
        ]]
        local Struck = {}
        local Steps = math.ceil(self.Length / 10)

        for Index = 0, Steps do
            local Point = Start + Direction * (self.Length * Index / Steps)

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

                CombatUtils.ApplyEffectTo(Target, "Fragile", 3, 6)
                AbilityFX.ShakeFor(Target, 4, 0.5)
                AbilityFX.ScreenFor(Target, "Flash", 0.5, 0.8)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- PASSIVE — SUPER METER
--------------------------------------------------------------------------------

local function SuperMeterInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    MeterService.Define(Char, SUPER_METER, {
        Max = 100,
        Start = 0,
        --[[
            No regeneration at all.

            A meter that fills by waiting would make the Super Art a long cooldown with
            extra steps. Making it fill only from landing shots and parrying is what ties the
            payoff to playing him well.
        ]]
        RegenPerSecond = 0,
    })
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Cuphead: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Cuphead",
        Quote = "Don't deal with the devil!",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 8600,

        Role = "Ranged",
        Difficulty = 4,

        Origin = {
            TooltipText = "He lost a bet.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        Health = 1050,
        BaseSpeed = 11.6,
        SprintSpeedMultiplier = 26.5 / 11.6,
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
                UseSound = "rbxassetid://12222030",
                UseAnimation = "rbxassetid://133504250023139",

                --[[
                    Nine damage, three times a second — about 27 damage per second sustained,
                    against a melee character's 15 to 20. The trade is that every one of
                    those shots can miss, and he has nothing at all if you close the gap.
                ]]
                Damage = 9,
                Cooldown = 0.34,
                Duration = 0.12,
                Speed = 190,
                Range = 150,
                MeterPerHit = 3,

                Behaviour = FingerGunBehaviour,
            }),

            Dash = Ability.New({
                Name = "Dash",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 5,
                Duration = 0.34,

                DashSpeed = 92,
                DashTime = 0.32,

                UseSound = "rbxassetid://12222216",
                Behaviour = DashBehaviour,
            }),

            ExShot = Ability.New({
                Name = "EX Shot",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 7,
                Duration = 0.4,

                Damage = 52,
                Speed = 115,
                Range = 140,
                MeterCost = 25,

                UseSound = "rbxassetid://9046319808",
                Behaviour = ExShotBehaviour,
            }),

            Parry = Ability.New({
                Name = "Parry",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 9,
                Duration = 0.45,

                Window = 0.45,
                MeterOnParry = 35,
                SpeedBoost = 1.35,
                SpeedTime = 2,

                UseSound = "rbxassetid://12222216",
                Behaviour = ParryBehaviour,
            }),

            SuperArt = Ability.New({
                Name = "Super Art",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 20,
                Duration = 1.1,

                Windup = 0.7,
                Length = 120,
                Width = 14,
                Damage = 130,

                UseSound = "rbxassetid://9118823103",
                Behaviour = SuperArtBehaviour,
            }),

            SuperMeter = Ability.New({
                Name = "Super Meter",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",
                ExtraInit = SuperMeterInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- THE PARRY ITSELF
--------------------------------------------------------------------------------

--[=[
    `OnDamage` is the engine's "about to be hurt" hook, and returning `"Ignored"` cancels
    the hit. That makes it the only correct place for a parry: it fires on the exact frame
    the damage would have applied, whatever the source, so the window is honest.

    A successful parry:
      * cancels the damage outright;
      * pays a third of a Super Art, which is far more than shooting ever gives;
      * grants two seconds of speed, so there is something to do with the opening.

    It consumes the window — one hit per parry. Otherwise a single press would blank
    everything thrown at him for half a second, which against three opponents at once would
    be worth far more than its cooldown.
]=]
function Cuphead:OnDamage(_damageSettings)
    if not RunService:IsServer() then
        return
    end

    local Char = self.Owner and self.Owner.Character
    if not Char then
        return
    end

    local Until = Char:GetAttribute(PARRY_ATTRIBUTE)
    if not Until or os.clock() > Until then
        return
    end

    -- Spent.
    Char:SetAttribute(PARRY_ATTRIBUTE, nil)

    local Parry = self.GameplayConfig.Abilities.Parry
    local Root = Utils.Character.GetRootPart(Char)

    MeterService.Add(Char, SUPER_METER, Parry.MeterOnParry)

    PlayerSpeedManager.AddSpeedFactor(self.Owner, "Parry", Parry.SpeedBoost)
    task.delay(Parry.SpeedTime, function()
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, "Parry")
    end)

    if Root then
        AbilityFX.Sound("rbxassetid://12222216", Root.Position, {Volume = 0.9, MinPitch = 1.4, MaxPitch = 1.5})
        AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "PARRY!", PINK, 1.2)
        AbilityFX.Shockwave(Root.Position, 10, PINK, 22)
    end

    return "Ignored"
end

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(255, 120, 200)\">"..Cuphead.Config.Name.."</font>"
local Abilities = Cuphead.GameplayConfig.Abilities

Cuphead.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Cuphead.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Cuphead.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." is the only killer in the arena with <b>no melee attack at all</b>. His basic attack is a bullet.",
            "Everything he has is a dodgeable projectile, and his <b>Super Meter</b> fills only from landing shots and from parrying — never from waiting.",
            "A Cuphead who shoots well is dangerous. A Cuphead who parries well is a problem.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Cuphead.Config.Role,
            "Difficulty: "..string.rep("★", Cuphead.Config.Difficulty)..string.rep("☆", 5 - Cuphead.Config.Difficulty),
            "Price: "..tostring(Cuphead.Config.Price).."$",
            "Health: "..tostring(Cuphead.GameplayConfig.Health),
            "Base Speed: "..tostring(Cuphead.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Cuphead.GameplayConfig.BaseSpeed * Cuphead.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "FINGER GUN"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage a shot, every "..tostring(Abilities.Slash.Cooldown).." seconds, out to "..tostring(Abilities.Slash.Range).." studs.",
            "Each shot that LANDS adds "..tostring(Abilities.Slash.MeterPerHit).." to the Super Meter. Misses pay nothing.",
        },
    },

    {Type = "Header", Text = "DASH  (Q)"},
    {
        Type = "Text",
        Text = {
            "A committed horizontal dash — it goes where he was pointing and cannot be steered.",
            "He has <b>Resistance V</b> for the whole dash, so dashing through an attack is the right answer to one.",
            "Cooldown: "..tostring(Abilities.Dash.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "EX SHOT  (E)"},
    {
        Type = "Text",
        Text = {
            "Spends "..tostring(Abilities.ExShot.MeterCost).." meter for a pink round that does "..tostring(Abilities.ExShot.Damage).." damage and goes through two people.",
            "Cooldown: "..tostring(Abilities.ExShot.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "PARRY  (R)"},
    {
        Type = "Text",
        Text = {
            "A "..tostring(Abilities.Parry.Window).." second window. One hit taken inside it does <b>no damage at all</b>, pays "..tostring(Abilities.Parry.MeterOnParry).." meter, and gives him "..tostring(Abilities.Parry.SpeedTime).." seconds of speed.",
            "One hit per press. Mistime it and you have stood still for nothing.",
            "Cooldown: "..tostring(Abilities.Parry.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "SUPER ART  (F)"},
    {
        Type = "Text",
        Text = {
            "Full meter only. He roots himself for "..tostring(Abilities.SuperArt.Windup).." seconds with the beam's path drawn on the floor, then fires it: "..tostring(Abilities.SuperArt.Damage).." damage to everybody in a "..tostring(Abilities.SuperArt.Width).." stud wide line, "..tostring(Abilities.SuperArt.Length).." studs long.",
            "The telegraph is the counterplay, and it is deliberately generous.",
            "Cooldown: "..tostring(Abilities.SuperArt.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "SUPER METER  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Fills from landing shots and from parrying. It does not regenerate on its own, ever.",
            "EX Shot spends a quarter of it. Super Art needs all of it.",
        },
    },
}

return Cuphead
