local Players = game:GetService("Players")
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
local SummonService = require(ReplicatedStorage.Modules.SummonService)

-- Server-only. This module is required on the client too, for the ability UI, and
-- `ServerScriptService` isn't reachable from there.
local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

--[=[
    1x1x1x1 — CORRUPTED ROBLOX ITSELF.

    THIS MODULE USED TO THROW ON REQUIRE, AND IT BROKE THE SHOP.

    The old version opened with `Character.CreateKiller({ ... })` and never assigned the
    result, then referred to a local called `OneXOne` twelve times — a name that was never
    declared anywhere in the file. So `OneXOne` was a nil global, `OneXOne.Config.Name`
    threw, and requiring this character failed every single time.

    That alone emptied the killer shop. The old `Shop.ReloadContent` sorted the roster with
    `require` calls INSIDE a `table.sort` comparator, so one unloadable module threw out of
    the comparator, out of the sort, and out of the whole batch — no killer cards at all, and
    one confusing error in the console. The registry now requires each module in its own
    `pcall`, so this can't happen again; but this file is also just correct now.

    THE CHARACTER
    -------------
    Not a humanoid with a sword. A hacker inside the game, whose whole kit is about writing
    CORRUPTION onto people and then collecting on it.

      M1  VENOMSHANK SLASH   A corrupted blade. Every hit writes a stack of Corruption.
      Q   CORRUPT PROJECTILE A glitching orb. Scales with the target's existing Corruption.
      E   ENTANGLING CORRUPT Chains that haul a victim partway toward it.
      R   RAISE THE CORRUPTED Three corrupted players claw their way out of the floor.
      P   CORRUPTED REALITY  Heavily corrupted victims leave glitch trails only it can see.
                             At full charge, REALITY BREAK distorts the arena.

    WHY IT IS BALANCED DESPITE DOING EVERYTHING
    ------------------------------------------
    Its raw numbers are the worst on the roster — 1000 health, the joint-lowest, and a basic
    attack that hits for 14. Everything it does is weak ON A FRESH TARGET and strong on one
    it has already been working on, and Corruption expires in ten seconds. Break off and it
    has nothing; stay in its range and it converts that time into damage.

    REALITY BREAK is cosmetic. It makes the arena unreadable for six seconds and does not
    deal damage, destroy geometry, or move anybody. A killer whose ultimate deletes the map
    is not a killer, it is a bug.
]=]

--- Corruption green. One colour for the whole character, so every effect reads as its work.
local CORRUPT = Color3.fromRGB(40, 235, 120)
local CORRUPT_DARK = Color3.fromRGB(18, 120, 60)

--- The meter that gates REALITY BREAK. Filled by applying Corruption, never by waiting.
local BREAK_METER = "RealityBreak"

--------------------------------------------------------------------------------
-- CORRUPTION
--------------------------------------------------------------------------------

--- How corrupted somebody currently is, 0 to 5.
local function GetCorruption(char: Model): number
    local Effect = Utils.Instance.FindFirstChild(char, "Effects.Corrupted", 0)
    return Effect and Effect.Value or 0
end

--[=[
    Writes one or more stacks of Corruption onto a target.

    THE STACK IS THE CHARACTER. Everything else reads this number:

      * `Corrupt Projectile` does `+40%` of its damage per stack.
      * `Entangling Corruption` pulls further the more corrupted the target is.
      * `Corrupted Reality` reveals targets at 3 or more.
      * Applying stacks is the ONLY way to fill the Reality Break meter.

    Capped at 5 so it cannot run away. Re-applying extends the ten second window but the
    cap means the ceiling is reachable in about four hits and no faster however hard you
    mash, which is what keeps the scaling from being a burst combo.
]=]
local function Corrupt(self: Types.Ability, target: Model, amount: number)
    if not RunService:IsServer() or not target then
        return
    end

    local Current = GetCorruption(target)
    local New = math.clamp(Current + amount, 0, 5)

    CombatUtils.ApplyEffectTo(target, "Corrupted", New, 10)

    -- The visual scales with the stack, so you can read somebody's corruption off their
    -- body rather than having to check an effects list mid-chase.
    AbilityFX.Tint(target, CORRUPT, 0.5 + New * 0.1, {FillTransparency = 0.8 - New * 0.07})

    -- From 3, their screen starts to go. This is the "survivor UI briefly glitches" part of
    -- the brief, and it is on a short duration precisely because a permanently glitching
    -- screen is an unplayable one.
    if New >= 3 then
        AbilityFX.ScreenFor(target, "Glitch", 0.6 + (New - 3) * 0.4, 0.6 + (New - 3) * 0.3)
    end

    -- Only NEW corruption charges the meter, so topping somebody up at the cap is not a
    -- free ultimate.
    local Gained = New - Current
    if Gained > 0 then
        MeterService.Add(self.OwnerProperties.Character, BREAK_METER, Gained * 4)
    end
end

--------------------------------------------------------------------------------
-- M1 — VENOMSHANK SLASH
--------------------------------------------------------------------------------

--[=[
    The Venomshank's own swing.

    Written out rather than taking `Slash.New`'s default behaviour, because the hit has to
    apply a Corruption stack and the default has no hook for "do something to whoever this
    hit". The hitbox work is still `Classes.Hitbox`; only the on-hit callback is new.
]=]
local function VenomshankBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.3, Lock = 0.6})
        return
    end

    local Hitbox = require(ReplicatedStorage.Classes.Hitbox)
    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.7, MinPitch = 0.85, MaxPitch = 1.0})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        -- A corrupted arc left hanging in the air where the blade went.
        local Origin = Root.Position + Root.CFrame.LookVector * 3
        AbilityFX.Beam(
            Origin - Root.CFrame.RightVector * 3,
            Origin + Root.CFrame.RightVector * 3,
            CORRUPT,
            {Width = 0.8, Duration = 0.2, Transparency = 0.1}
        )

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Venomshank",
            ExecuteOnKill = true,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    if Victim and Victim:IsA("Model") then
                        Corrupt(self, Victim, self.CorruptionPerHit)
                        AbilityFX.Sparks(Utils.Character.GetRootPart(Victim).Position, CORRUPT, 10, 16)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — CORRUPT PROJECTILE
--------------------------------------------------------------------------------

--[=[
    A glitching orb of corrupted data.

    Scales HARD off the target's existing Corruption — 40% more damage per stack, so a fully
    corrupted target takes triple. That is the payoff for the melee work, and it is why this
    is a 26 damage projectile rather than a 60 one: on somebody it has never touched, it is
    the weakest ranged attack in the game.
]=]
local function CorruptProjectileBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.94, Duration = 0.35, Lock = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.8})

    ProjectileService.Fire({
        SourcePlayer = self.Owner,
        Name = "CorruptOrb",
        Origin = Root.Position + Root.CFrame.LookVector * 3 + Vector3.new(0, 1, 0),
        Direction = Root.CFrame.LookVector,
        Speed = self.Speed,
        Lifetime = self.Range / self.Speed,
        Radius = 2.6,
        -- Base damage only. The scaling is applied in `OnHit`, where the victim is known.
        Damage = self.Damage,
        Reason = self.Name,
        Spin = 220,
        Visual = {
            Shape = Enum.PartType.Block,
            Size = Vector3.new(2, 2, 2),
            Color = CORRUPT,
            Material = Enum.Material.Neon,
            Trail = true,
            TrailColor = CORRUPT_DARK,
            Light = true,
            LightRange = 12,
            Emitter = {
                Color = ColorSequence.new(CORRUPT),
                Rate = 35,
                Speed = NumberRange.new(0, 6),
                Size = NumberSequence.new(0.9),
            },
        },
        OnHit = function(_projectile, humanoid: Humanoid)
            local Victim = humanoid.Parent
            if not Victim or not Victim:IsA("Model") then
                return nil
            end

            local Stacks = GetCorruption(Victim)

            --[[
                The bonus is applied as a SECOND damage call rather than by changing the
                projectile's damage, because the hitbox has already resolved its own hit by
                the time this callback runs. Two calls also means the scaling shows up in the
                kill feed as its own entry, which makes the character legible to whoever just
                died to it.
            ]]
            if Stacks > 0 then
                CommonFunctions.DamagePlayer({
                    SourcePlayer = self.Owner,
                    TargetHumanoid = humanoid,
                    Damage = self.Damage * self.PerStack * Stacks,
                    Reason = "Corruption",
                })
            end

            Corrupt(self, Victim, 1)

            local VictimRoot = Utils.Character.GetRootPart(Victim)
            if VictimRoot then
                AbilityFX.Burst(VictimRoot.Position, 6, CORRUPT, {Duration = 0.3})
            end

            return nil
        end,
        OnImpact = function(_projectile, position: Vector3)
            AbilityFX.Burst(position, 4, CORRUPT, {Duration = 0.25})
            AbilityFX.Sparks(position, CORRUPT, 10, 22)
        end,
    })

    -- Glitch artefacts around the caster as it writes.
    AbilityFX.Sparks(Root.Position + Vector3.new(0, 2, 0), CORRUPT, 12, 10)
    AbilityFX.Tint(Char, CORRUPT, 0.3, {FillTransparency = 0.85})
end

--------------------------------------------------------------------------------
-- E — ENTANGLING CORRUPTION
--------------------------------------------------------------------------------

--[=[
    Chains of corrupted geometry that haul somebody partway back.

    EXPLICITLY NOT A GUARANTEED KILL SETUP, which the brief was clear about. Three things
    stop it being one:

      * It pulls a FRACTION of the distance, not all of it. At zero Corruption that is 35%,
        rising to 65% at full — so it closes a gap, it doesn't delete one.
      * It leaves them Snared for 0.9 seconds, and `Snared` is deliberately not a stun: the
        victim keeps their abilities and their basic attack the whole time.
      * The chain is a slow, visible, audible projectile with a 65 stud reach. It is dodgeable
        on reaction.
]=]
local function EntanglingBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.08, Duration = 0.4, Lock = 0.5, Shake = 0.4, ShakeTime = 0.2})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position + Vector3.new(0, 1, 0)

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 0.85})

    ProjectileService.Fire({
        SourcePlayer = self.Owner,
        Name = "CorruptChain",
        Origin = Origin + Root.CFrame.LookVector * 3,
        Direction = Root.CFrame.LookVector,
        Speed = self.Speed,
        Lifetime = self.Range / self.Speed,
        Radius = 3,
        Damage = self.Damage,
        Reason = self.Name,
        FaceTravel = true,
        Visual = {
            Shape = Enum.PartType.Block,
            Size = Vector3.new(1, 1, 6),
            Color = CORRUPT_DARK,
            Material = Enum.Material.Neon,
            Trail = true,
            TrailColor = CORRUPT,
        },
        OnStep = function(projectile, _delta, position)
            -- The chain is drawn as a line back to its caster, which is what makes it read
            -- as a tether rather than a dart.
            if Root and Root.Parent and projectile.Age % 0.08 < 0.03 then
                AbilityFX.Beam(Root.Position, position, CORRUPT_DARK, {
                    Width = 0.35,
                    Duration = 0.12,
                    Transparency = 0.45,
                })
            end
        end,
        OnHit = function(_projectile, humanoid: Humanoid)
            local Victim = humanoid.Parent
            if not Victim or not Victim:IsA("Model") then
                return nil
            end

            local VictimRoot = Utils.Character.GetRootPart(Victim)
            if not VictimRoot or not Root or not Root.Parent then
                return nil
            end

            local Stacks = GetCorruption(Victim)
            -- 35% of the gap at no corruption, 65% at full.
            local Fraction = self.PullFraction + Stacks * 0.06

            local Delta = Root.Position - VictimRoot.Position
            -- Never pull them INTO the caster; stop a few studs short so they don't end up
            -- wedged inside its collision and flung by the solver.
            local Distance = math.max(Delta.Magnitude - 6, 0)
            local Destination = VictimRoot.Position + Delta.Unit * Distance * Fraction

            CombatUtils.Blink(Victim, Destination)
            CombatUtils.ApplyEffectTo(Victim, "Snared", 2, self.SnareTime)
            Corrupt(self, Victim, 1)

            AbilityFX.Beam(Root.Position, Destination, CORRUPT, {Width = 1.4, Duration = 0.35})
            AbilityFX.Ring(Destination, 8, CORRUPT, {Duration = 0.4})
            AbilityFX.ShakeFor(Victim, 1.2, 0.3)
            AbilityFX.ScreenFor(Victim, "Glitch", 0.5, 0.8)

            return nil
        end,
    })

    AbilityFX.Tint(Char, CORRUPT, 0.4, {FillTransparency = 0.8})
end

--------------------------------------------------------------------------------
-- R — RAISE THE CORRUPTED
--------------------------------------------------------------------------------

--[=[
    Three corrupted Roblox players claw out of the floor.

    They are literal classic noob rigs — `Modules.PlaceholderRig`, recoloured corruption
    green and scaled slightly down — because that is exactly what the brief asked for:
    defeated-player figures, raised by the thing that deleted them.

    THEY ARE PRESSURE, NOT DAMAGE. 40 health each (one or two swings from anybody), 11 walk
    speed so every killer on the roster outruns them, and 9 damage a swing. What they
    actually do is apply a stack of Corruption per hit — so they are an extension of
    1x1x1x1's real win condition rather than a second health bar.

    Hard capped at three by `SummonService.MaxPerPlayer`, which also means spamming the
    ability cannot flood the arena.
]=]
local function RaiseBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.15, Duration = 0.6, Lock = 0.9, Shake = 0.8, ShakeTime = 0.5})
        return
    end

    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position

    AbilityFX.Sound(self.UseSound, Origin, {Volume = 0.9})
    AbilityFX.Ring(Origin, 14, CORRUPT, {Duration = 0.6, Thickness = 1.2})
    AbilityFX.Smoke(Origin, CORRUPT_DARK, 18, 5)

    SummonService.Summon({
        SourcePlayer = self.Owner,
        Position = Origin,
        Count = self.Count,
        Name = "Corrupted",
        Lifetime = self.MinionLifetime,
        Health = self.MinionHealth,
        Speed = self.MinionSpeed,
        Scale = 0.9,
        Damage = self.MinionDamage,
        AttackRange = 7,
        AttackInterval = 1.5,
        Reason = "Corrupted Player",
        SeekRadius = 70,
        Appearance = {
            Color = CORRUPT_DARK,
            HeadColor = CORRUPT,
            Material = Enum.Material.Neon,
            Glow = CORRUPT,
        },
        OnAttack = function(minion, target: Model)
            -- Their hits corrupt too, which is the real reason to summon them.
            Corrupt(self, target, 1)
            if minion.Model and minion.Model.PrimaryPart then
                AbilityFX.Sparks(minion.Model.PrimaryPart.Position, CORRUPT, 6, 12)
            end
        end,
        OnEnd = function(minion)
            -- Dissolve rather than vanish.
            if minion.Model and minion.Model.PrimaryPart then
                AbilityFX.Burst(minion.Model.PrimaryPart.Position, 5, CORRUPT, {Duration = 0.3})
            end
        end,
    })

    AbilityFX.Text(Origin + Vector3.new(0, 6, 0), "RISE", CORRUPT, 1.2)
end

--------------------------------------------------------------------------------
-- PASSIVE — CORRUPTED REALITY
--------------------------------------------------------------------------------

--[=[
    What corruption does when 1x1x1x1 isn't pressing anything.

    Two jobs, both on one slow loop:

      1. GLITCH TRAILS. Anyone at 3+ Corruption drops a faint green artefact where they
         stand, visible to everybody. It is a tracking tool that the victim can SEE working,
         which is the fair way to do information — they know they're leaking position and
         they know breaking off stops it.

      2. REALITY BREAK. When the meter fills — only from applying Corruption, never from
         time — the arena distorts for six seconds: every fighter within 90 studs gets the
         `Glitch` screen effect, the lighting goes wrong, and corrupted geometry flickers
         through the floor.

         IT DEALS NO DAMAGE AND MOVES NOBODY. It is six seconds of a harder-to-read arena on
         a meter that takes most of a fight to fill. The map is not touched: the "corrupted
         textures" are temporary parts in the map's own `InGame` folder, which the end of a
         round removes for free.

    One loop at 2 Hz for the whole passive. Nothing here runs per frame.
]=]
local function CorruptedRealityInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    MeterService.Define(Char, BREAK_METER, {
        Max = 100,
        Start = 0,
        -- No passive regeneration whatsoever. The ultimate is earned by doing the
        -- character's job, not by surviving long enough.
        RegenPerSecond = 0,
    })

    self:AddConnection(task.spawn(function()
        local LastBreak = 0

        while Char and Char.Parent do
            task.wait(0.5)

            local Root = Utils.Character.GetRootPart(Char)
            if not Root then
                continue
            end

            ----------------------------------------------------------------
            -- GLITCH TRAILS
            ----------------------------------------------------------------

            for _, Target: Model in CombatUtils.GetFightersInRadius(Root.Position, self.TrailRange, Char) do
                if GetCorruption(Target) < 3 then
                    continue
                end

                local TargetRoot = Utils.Character.GetRootPart(Target)
                if not TargetRoot then
                    continue
                end

                -- A small flickering cube left in their footprints.
                local Ground = AbilityFX.GroundAt(TargetRoot.Position, {Target, Char}) or TargetRoot.Position
                local Artefact = AbilityFX.Part({
                    Name = "GlitchTrail",
                    Size = Vector3.new(1.2, 0.2, 1.2),
                    CFrame = CFrame.new(Ground + Vector3.new(0, 0.15, 0)),
                    Color = CORRUPT,
                    Material = Enum.Material.Neon,
                    Transparency = 0.5,
                })
                Artefact.Parent = AbilityFX.Folder()
                game:GetService("Debris"):AddItem(Artefact, 2.5)
            end

            ----------------------------------------------------------------
            -- REALITY BREAK
            ----------------------------------------------------------------

            if MeterService.IsFull(Char, BREAK_METER) and os.clock() - LastBreak >= self.BreakCooldown then
                LastBreak = os.clock()
                MeterService.Set(Char, BREAK_METER, 0)

                AbilityFX.Sound(self.BreakSound, Root.Position, {Volume = 1, RollOffMaxDistance = 200})
                AbilityFX.Text(Root.Position + Vector3.new(0, 7, 0), "REALITY BREAK", CORRUPT, 2)

                -- Everybody nearby, including 1x1x1x1 itself. It is breaking reality; it
                -- does not get to stand outside the result.
                for _, Target: Model in CombatUtils.GetFightersInRadius(Root.Position, self.BreakRadius, nil) do
                    AbilityFX.ScreenFor(Target, "Glitch", self.BreakDuration, 1.4)
                end

                --[[
                    "Corrupted textures": a scatter of flickering green panels around the
                    arena, on a Debris timer, parented into the map's own `InGame` folder.

                    Twenty-four parts, not two hundred. It has to be noticeable without
                    being a frame-rate attack on everybody in the server, and a handful of
                    large flickering panels reads as corruption far better than a cloud of
                    small ones.
                ]]
                for _ = 1, 24 do
                    local Angle = math.random() * math.pi * 2
                    local Distance = 10 + math.random() * self.BreakRadius
                    local Spot = Root.Position + Vector3.new(math.cos(Angle) * Distance, 0, math.sin(Angle) * Distance)
                    local Ground = AbilityFX.GroundAt(Spot, {Char})

                    if not Ground then
                        continue
                    end

                    local Panel = AbilityFX.Part({
                        Name = "CorruptedTexture",
                        Size = Vector3.new(6 + math.random() * 8, 0.2, 6 + math.random() * 8),
                        CFrame = CFrame.new(Ground + Vector3.new(0, 0.2, 0)),
                        Color = math.random() < 0.5 and CORRUPT or CORRUPT_DARK,
                        Material = Enum.Material.Neon,
                        Transparency = 0.45,
                    })
                    Panel.Parent = AbilityFX.Folder()

                    -- Flicker, then go. One thread per panel for six seconds is fine; they
                    -- all end on their own.
                    task.spawn(function()
                        local Elapsed = 0
                        while Elapsed < self.BreakDuration and Panel.Parent do
                            Elapsed += task.wait(0.1 + math.random() * 0.2)
                            Panel.Transparency = math.random() < 0.5 and 0.35 or 0.9
                        end
                        if Panel.Parent then
                            Panel:Destroy()
                        end
                    end)
                end
            end
        end
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local OneXOne: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "1x1x1x1",
        Quote = "you were never supposed to see this",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 1900,

        Role = "Summoner",
        Difficulty = 5,

        Origin = {
            TooltipText = "An account that does not exist.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {},
    },

    GameplayConfig = {
        --[[
            The lowest health on the roster, joint with Gubby.

            It is a ranged controller with a summon, a pull and scaling damage. The price of
            all of that is that it loses any straight fight it is actually caught in.
        ]]
        Health = 1000,
        BaseSpeed = 11,
        SprintSpeedMultiplier = 26 / 11,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 100,
            StaminaDrain = 11,
            StaminaGain = 19,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                --[[
                    14 damage. The weakest basic attack in the game, on purpose: the swing
                    is here to write Corruption, and the damage comes later from the orb.
                ]]
                Damage = 14,
                Cooldown = 1.5,
                Duration = 0.3,
                Delay = 0.1,
                HitboxSize = Vector3.new(5.5, 6, 5),
                HitboxOffset = CFrame.new(0, 0, -2.75),

                CorruptionPerHit = 1,

                Behaviour = VenomshankBehaviour,
            }),

            Corrupt = Ability.New({
                Name = "Corrupt",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 6,
                Duration = 0.4,

                Damage = 26,
                Speed = 95,
                Range = 130,
                --- Extra damage per existing stack, as a fraction of the base.
                PerStack = 0.4,

                UseSound = "rbxassetid://9118823103",
                Behaviour = CorruptProjectileBehaviour,
            }),

            Entangle = Ability.New({
                Name = "Entangle",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 15,
                Duration = 0.5,

                Damage = 18,
                Speed = 70,
                Range = 65,
                --- Fraction of the gap closed at zero Corruption.
                PullFraction = 0.35,
                SnareTime = 0.9,

                UseSound = "rbxassetid://9046319808",
                Behaviour = EntanglingBehaviour,
            }),

            Raise = Ability.New({
                Name = "Raise",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 42,
                Duration = 0.8,

                Count = 3,
                MinionHealth = 40,
                MinionDamage = 9,
                MinionSpeed = 11,
                MinionLifetime = 16,

                UseSound = "rbxassetid://9125402735",
                Behaviour = RaiseBehaviour,
            }),

            CorruptedReality = Ability.New({
                Name = "Corrupted Reality",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                TrailRange = 110,
                BreakRadius = 90,
                BreakDuration = 6,
                --- Floor between Reality Breaks even if the meter refills sooner.
                BreakCooldown = 60,
                BreakSound = "rbxassetid://9118823103",

                ExtraInit = CorruptedRealityInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(40, 235, 120)\">"..OneXOne.Config.Name.."</font>"
local Abilities = OneXOne.GameplayConfig.Abilities

OneXOne.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = OneXOne.Config.Name:upper()},
    {Type = "Quote", Text = "\""..OneXOne.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." is not a player. It is something wearing the shape of one.",
            "Every attack it lands writes <b>Corrupted</b> onto you, and everything it does afterwards hits a corrupted target harder. Its raw numbers are the worst in the arena; what it has instead is memory.",
            "Break off and the corruption fades in ten seconds. Stay in its range and it spends that time building the thing that kills you.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..OneXOne.Config.Role,
            "Difficulty: "..string.rep("★", OneXOne.Config.Difficulty)..string.rep("☆", 5 - OneXOne.Config.Difficulty),
            "Price: "..tostring(OneXOne.Config.Price).."$",
            "Health: "..tostring(OneXOne.GameplayConfig.Health).."  (joint lowest)",
            "Base Speed: "..tostring(OneXOne.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(OneXOne.GameplayConfig.BaseSpeed * OneXOne.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "VENOMSHANK SLASH"},
    {
        Type = "Text",
        Text = {
            "A corrupted blade. "..tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds — the weakest swing on the roster.",
            "Every hit writes one stack of <b>Corrupted</b>. That is what it is for.",
        },
    },

    {Type = "Header", Text = "CORRUPT  (Q)"},
    {
        Type = "Text",
        Text = {
            "Fires a glitching block of corrupted data for "..tostring(Abilities.Corrupt.Damage).." damage, and corrupts whatever it hits.",
            "Deals <b>40% more per stack of Corrupted</b> the target is already carrying. On somebody fresh it is the weakest ranged attack in the game. On somebody at full corruption it is close to triple.",
            "Cooldown: "..tostring(Abilities.Corrupt.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "ENTANGLE  (E)"},
    {
        Type = "Text",
        Text = {
            "Throws corrupted chains up to "..tostring(Abilities.Entangle.Range).." studs. On a hit they haul the victim part of the way back and leave them <b>Snared</b> for "..tostring(Abilities.Entangle.SnareTime).." seconds.",
            "It closes 35% of the gap on a clean target and 65% on a fully corrupted one — never all of it, and never into a guaranteed kill. Snared does not take your abilities or your attack away.",
            "The chain is slow enough to dodge on reaction.",
            "Cooldown: "..tostring(Abilities.Entangle.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "RAISE  (R)"},
    {
        Type = "Text",
        Text = {
            "Three corrupted players claw out of the floor and go hunting. "..tostring(Abilities.Raise.MinionHealth).." health each, "..tostring(Abilities.Raise.MinionDamage).." damage a swing, gone after "..tostring(Abilities.Raise.MinionLifetime).." seconds.",
            "They walk slower than every killer in the game and die to one or two hits. What makes them dangerous is that their swings corrupt you too.",
            "Cooldown: "..tostring(Abilities.Raise.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "CORRUPTED REALITY  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Anyone at three or more stacks of <b>Corrupted</b> leaves glitch artefacts on the floor behind them, and their screen begins to come apart.",
            "Applying corruption fills a hidden meter. When it is full, "..NameLabel.." breaks reality for six seconds: the arena distorts and everybody inside 90 studs — itself included — fights through a glitching screen.",
            "It deals no damage, moves nobody and destroys nothing. It only makes the room hard to read.",
        },
    },
}

return OneXOne
