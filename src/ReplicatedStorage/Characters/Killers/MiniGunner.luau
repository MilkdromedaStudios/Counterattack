local Debris = game:GetService("Debris")
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
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    MINI-GUNNER — the only killer in the arena with real range.

    Design idea: a spin-up. Nothing he does is instant, and everything he does gets
    better the longer he's already been doing it.

    Spin Up is a state, not a burst: while it's running he can't sprint and moves at a
    crawl, but he's throwing out continuous damage at 70 studs. Suppress is his answer
    to being rushed. Reload is the drawback made explicit — he runs dry and has to stand
    still to fix it.

    He is the strongest killer in an open arena and the weakest one in a corridor.
]=]

--[=[
    WHAT THIS PASS ADDED, AND WHY

    The character's identity is unchanged — spin-up, suppression, reload, strongest in the
    open and weakest in a corridor. What it was missing were the three things that make a
    sustained-fire weapon feel like one rather than a long thin hitbox:

      * HEAT. Firing builds it; running out of heat forces a cooling period he cannot skip.
        Without it the only limit on firing was the drum, which made `Reload` the entire
        drawback and meant the right play was always to hold the trigger until empty.
      * ACCURACY FALLOFF. The barrel wanders the longer he holds it. Early shots are a
        precise line; late ones spray. That turns "when do I stop firing" into a real
        decision.
      * SUPPRESSION. Rounds that pass NEAR somebody build the `Suppressed` effect even when
        they miss. A suppression weapon that only matters when it connects is just a gun.

    And `Overdrive` (F), which trades the cooling period for a burst of performance, plus a
    basic attack that is his own rather than the shared default.
]=]

--- Replicated so the client can mirror the spin state without tracking it itself.
local SPINNING_ATTRIBUTE = "MinigunSpinning"

--- Heat, 0 to 100. Fills while firing, cools when not.
local HEAT_METER = "Heat"

--- The gun's colour, for every effect it produces.
local GUNMETAL = Color3.fromRGB(255, 226, 130)

--[=[
    PISTOL WHIP (M1)

    His own basic attack rather than the shared default. Deliberately poor: 20 damage on a
    2.3 second cooldown with no reach at all. He is carrying a weapon with both hands and
    hitting you with it is a last resort.

    It also VENTS HEAT, which is the interesting part — swinging is how he cools the gun
    without standing still, so the worst attack on the roster has a real reason to be used.
]=]
local function WhipBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.02, Duration = 0.3, Lock = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    Sounds.PlaySound(self.UseSound, {Parent = Root, Volume = 0.6, MinPitch = 0.8, MaxPitch = 0.95})

    -- Venting. See the note above.
    MeterService.Add(Char, HEAT_METER, -self.HeatVented)
    AbilityFX.Smoke(Root.Position + Vector3.new(0, 1.5, 0), Color3.fromRGB(120, 120, 120), 5, 1.8)

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Pistol Whip",
            ExecuteOnKill = true,
            Knockback = self.Knockback,
        })
    end)
end

--[=[
    HEAVY WEAPON (PASSIVE)

    He is carrying something that weighs more than he does.

    Implemented through `OnEffect`, the engine's hook for "an effect is about to be applied
    to this character". He IGNORES `Slipping` outright — you cannot trip somebody braced
    against a minigun — and takes `Snared` and `Slowness` at reduced duration.

    That is the honest reading of "reduced knockback": the engine applies knockback as an
    impulse inside `CommonFunctions.DamagePlayer` with no hook to scale it, so the thing
    that can actually be resisted is the movement DEBUFFS, which is what knockback is for in
    this game anyway.

    It is a defensive passive because his whole kit roots him. He cannot be allowed to also
    be the easiest person in the arena to shove out of position.
]=]
local function HeavyWeapon(_self, effectSettings)
    if not RunService:IsServer() then
        return
    end

    local Name = effectSettings and effectSettings.EffectSettings and effectSettings.EffectSettings.Name
    if not Name then
        return
    end

    if Name == "Slipping" then
        return "Ignored"
    end

    if Name == "Snared" or Name == "Slowness" then
        -- Halved. `ApplyEffect` re-reads `Duration` after `OnEffect` returns, which is the
        -- supported way to shorten an incoming effect.
        local Current = effectSettings.EffectSettings.Duration
        if Current then
            effectSettings.EffectSettings.Duration = Current * 0.5
        end
    end

    return
end

--------------------------------------------------------------------------------
-- ABILITY BEHAVIOURS
--------------------------------------------------------------------------------

--[=[
    SPIN UP (Q)

    Toggles the minigun on. While it's running:
      * he can't sprint and moves at `SpinSpeedFactor` of normal
      * a bullet is fired at whatever he's aiming at, on an interval
      * every shot costs a round from `UsesLeft`

    Firing stops on its own when the ammo runs out, which is what makes Reload matter.
]=]
local function SpinUpBehaviour(self: Types.Ability)
    --[[
        The client doesn't track the toggle itself.

        It used to flip its own `Spinning` boolean, which desynced the moment the drum
        ran dry: the server's firing loop stops on its own, but the client never hears
        about it and stays zoomed in until the next press. Driving the zoom off a
        replicated attribute instead means the client always reflects the real state —
        see `SpinUpExtraInit` below, which watches it.
    ]]
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character

    -- Toggling off.
    if self.Spinning then
        self.Spinning = false
        Char:SetAttribute(SPINNING_ATTRIBUTE, false)
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
        PlayerSpeedManager.RemoveSprintLock(self.Owner, "Minigun")
        return
    end

    -- Out of ammo — nothing to spin.
    if self.UsesLeft <= 0 then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    self.Spinning = true
    Char:SetAttribute(SPINNING_ATTRIBUTE, true)

    -- Rooted to a walk, and no sprinting. This is the cost of the range.
    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.SpinSpeedFactor)
    PlayerSpeedManager.AddSprintLock(self.Owner, "Minigun")

    Sounds.PlaySound(self.SpinSound, {Parent = self.OwnerProperties.HRP, Volume = 0.7})

    self:AddStunnableConnection(task.spawn(function()
        -- Wind-up before the first round leaves the barrel.
        task.wait(self.SpinUpTime)

        --- Seconds of CONTINUOUS fire, which is what the spread is read from.
        local Sustained = 0

        while self.Spinning and self.UsesLeft > 0 do
            local Root = Utils.Character.GetRootPart(Char)
            if not (Char and Char.Parent and Root) then
                break
            end

            --[=[
                OVERHEATED. Firing stops until it cools.

                Checked at the top of the loop rather than at the moment heat is added, so
                the gun always finishes the round that filled the gauge -- cutting a shot
                off halfway because a number crossed a threshold reads as a bug.

                `HoldDecay` keeps it hot for a moment after the trigger comes off, so the
                cooling period cannot be skipped by tapping the toggle.
            ]=]
            if MeterService.IsFull(Char, HEAT_METER) then
                MeterService.HoldDecay(Char, HEAT_METER, self.OverheatHold)
                Sounds.PlaySound(self.OverheatSound, {
                    Position = Root.Position,
                    Volume = 0.8,
                    MinPitch = 0.75,
                    MaxPitch = 0.85,
                })
                AbilityFX.Smoke(Root.Position + Vector3.new(0, 1.5, 0), Color3.fromRGB(160, 160, 160), 18, 3)
                AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "OVERHEAT", Color3.fromRGB(255, 90, 60), 1.4)
                break
            end

            ----------------------------------------------------------------
            -- ACCURACY
            ----------------------------------------------------------------

            --[=[
                The barrel wanders.

                Spread is a yaw offset applied to the hitbox, growing with sustained fire up
                to `MaximumSpread` degrees and capping there. Early shots are a precise
                line; late ones are a cone.

                Implemented as a rotation of the whole hitbox rather than as a random miss
                chance, because the tracer is drawn down the SAME rotated axis -- so what
                the player sees is where the round actually went, and a wide shot that still
                connects is honest rather than lucky.
            ]=]
            local Spread = math.min(Sustained / self.SpreadRampTime, 1) * self.MaximumSpread
            local Yaw = math.rad((math.random() - 0.5) * 2 * Spread)
            local Aim = Root.CFrame * CFrame.Angles(0, Yaw, 0)

            -- A long, thin hitbox along the barrel. Walls stop it, so cover works.
            Hitbox.New(self.Owner, {
                CFrame = Aim * CFrame.new(0, 0.5, -self.Range / 2),
                Size = Vector3.new(2.5, 3, self.Range),
                Time = 0.05,
                Damage = self.ShotDamage,
                HitMultiple = false,
                PredictVelocity = false,
                Reason = "Minigun",
            })

            -- Tracer, down the same rotated axis the hitbox used.
            local Tracer = CombatUtils.MakePart({
                Name = "Tracer",
                Size = Vector3.new(0.2, 0.2, self.Range),
                Color = GUNMETAL,
                Material = Enum.Material.Neon,
                Transparency = 0.4,
                CFrame = Aim * CFrame.new(0.8, 0.5, -self.Range / 2),
            })
            Tracer.Parent = CombatUtils.GetInGameFolder()
            Debris:AddItem(Tracer, 0.06)

            ----------------------------------------------------------------
            -- SUPPRESSION
            ----------------------------------------------------------------

            --[=[
                Rounds that pass NEAR somebody still count.

                Sampled along the line of fire, applying `Suppressed` to anyone within
                `SuppressRadius` of it. The level is clamped HERE rather than inside the
                effect, so the ceiling lives in exactly one place.

                A suppression weapon that only matters when it connects is just a gun. This
                is what makes crossing open ground in front of him expensive even while he
                is missing.
            ]=]
            do
                local Line = Aim.LookVector
                local Steps = 4

                for Index = 1, Steps do
                    local Point = Root.Position + Line * (self.Range * Index / Steps)

                    for _, Target: Model in CombatUtils.GetFightersInRadius(Point, self.SuppressRadius, Char) do
                        local Existing = Utils.Instance.FindFirstChild(Target, "Effects.Suppressed", 0)
                        local Level = math.min((Existing and Existing.Value or 0) + 1, self.MaximumSuppression)

                        CombatUtils.ApplyEffectTo(Target, "Suppressed", Level, self.SuppressTime)
                    end
                end
            end

            Sounds.PlaySound(self.ShotSound, {
                Position = Root.Position,
                Volume = 0.35,
                MinPitch = 0.95,
                MaxPitch = 1.05,
                RollOffMaxDistance = 120,
            })

            self:ChangeAbilityCharges("Set", self.UsesLeft - 1)

            MeterService.Add(Char, HEAT_METER, self.HeatPerShot)
            -- Held hot while the trigger is down, so it only cools once he stops.
            MeterService.HoldDecay(Char, HEAT_METER, self.FireRate * 3)

            Sustained += self.FireRate
            task.wait(self.FireRate)
        end

        -- Whether it ran dry or was toggled off, clean the movement penalty up.
        self.Spinning = false
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
        PlayerSpeedManager.RemoveSprintLock(self.Owner, "Minigun")

        if Char and Char.Parent then
            Char:SetAttribute(SPINNING_ATTRIBUTE, false)
        end
    end))
end

--- CLIENT: keeps the zoom tied to the real spin state, however it ended.
local function SpinUpExtraInit(self: Types.Ability)
    if RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character

    local function Sync()
        if Char:GetAttribute(SPINNING_ATTRIBUTE) then
            self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 0.82)
        else
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end
    end

    -- A raw signal connection rather than `Utils.Instance.ObserveAttribute`, because
    -- that returns a Janitor and `Ability:AddConnection` cleans its entries up by
    -- calling `:Disconnect()`, which a Janitor doesn't have.
    self:AddConnection(Char:GetAttributeChangedSignal(SPINNING_ATTRIBUTE):Connect(Sync))
    Sync()
end

--[=[
    SUPPRESS (E)

    A wide, short cone of fire. Low damage, but it Grounds everybody it touches — the
    answer to somebody closing the distance on a killer who can't run away.
]=]
local function SuppressBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Root = self.OwnerProperties.HRP

    Sounds.PlaySound(self.UseSound, {Parent = Root, Volume = 0.85})

    -- Fired as a short burst of overlapping hitboxes so walking through it costs more
    -- than clipping the edge.
    self:AddStunnableConnection(task.spawn(function()
        for _ = 1, self.Bursts do
            local CurrentRoot = Utils.Character.GetRootPart(self.OwnerProperties.Character)
            if not CurrentRoot then
                return
            end

            Hitbox.New(self.Owner, {
                CFrame = CurrentRoot.CFrame * CFrame.new(0, 0.5, -self.Range / 2),
                Size = Vector3.new(self.ConeWidth, 6, self.Range),
                Time = 0.05,
                Damage = self.BurstDamage,
                HitMultiple = true,
                PredictVelocity = false,
                Reason = "Suppressing Fire",
                EffectsToApply = {
                    {Name = "Grounded", Level = 1, Duration = self.GroundDuration},
                    {Name = "Slowness", Level = 1, Duration = 2},
                },
            })

            local Flash = CombatUtils.MakePart({
                Name = "SuppressVFX",
                Size = Vector3.new(self.ConeWidth, 5, self.Range),
                Color = Color3.fromRGB(255, 200, 90),
                Material = Enum.Material.Neon,
                Transparency = 0.85,
                CFrame = CurrentRoot.CFrame * CFrame.new(0, 0.5, -self.Range / 2),
            })
            Flash.Parent = CombatUtils.GetInGameFolder()
            Debris:AddItem(Flash, 0.12)

            task.wait(self.BurstInterval)
        end
    end))
end

--[=[
    RELOAD (R)

    Refills the drum. He is rooted for the whole animation and cannot attack during it,
    so reloading in the open is a genuine decision rather than a formality.
]=]
local function ReloadBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    local SpinUp = self.CharModule.GameplayConfig.Abilities.SpinUp

    -- Can't reload while the barrel is still turning.
    if SpinUp then
        SpinUp.Spinning = false
    end

    Sounds.PlaySound(self.UseSound, {Parent = self.OwnerProperties.HRP, Volume = 0.8})

    -- Completely rooted and disarmed while reloading.
    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, 0)
    Char:SetAttribute("PreventSlash", true)

    self:AddStunnableConnection(task.delay(self.Duration, function()
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)

        if Char and Char.Parent then
            Char:SetAttribute("PreventSlash", false)
        end

        if SpinUp then
            SpinUp:ChangeAbilityCharges("Set", SpinUp.UseSettings.InitialUses)
        end
    end))
end

--[=[
    OVERDRIVE (F)

    Spends the cooling period up front for a window of much better performance.

    For `Window` seconds: no spin-up delay at all, a much faster fire rate, and tighter
    spread. When it ends the gun is forced to maximum heat, so the overheat is GUARANTEED
    and cannot be avoided -- he is buying twelve seconds of output with a cooling period he
    has agreed to in advance.

    That is a cleaner trade than a plain buff: the strongest window in his kit is also the
    thing that creates his longest period of being unable to shoot, and both halves are
    visible to everybody.
]=]
local function OverdriveBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.1, Duration = 0.5, Shake = 1.5, ShakeTime = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local SpinUp = self.CharModule.GameplayConfig.Abilities.SpinUp

    if not SpinUp then
        return
    end

    Sounds.PlaySound(self.UseSound, {Position = Root.Position, Volume = 1, RollOffMaxDistance = 170})
    AbilityFX.Text(Root.Position + Vector3.new(0, 6, 0), "OVERDRIVE", GUNMETAL, 1.6)
    AbilityFX.Ring(Root.Position, 12, GUNMETAL, {Duration = 0.6, Thickness = 1.2})

    --[[
        The original values are captured and restored by a RAW delay.

        `AddConnection` would hand the thread to the character's Janitor, so dying inside
        Overdrive would cancel the restore -- and because the ability table is a per-player
        COPY that persists across bodies, his next life would keep the boosted fire rate
        permanently.
    ]]
    local OriginalFireRate = SpinUp.FireRate
    local OriginalSpinUp = SpinUp.SpinUpTime
    local OriginalSpread = SpinUp.MaximumSpread

    SpinUp.FireRate = self.FireRate
    SpinUp.SpinUpTime = 0
    SpinUp.MaximumSpread = OriginalSpread * self.SpreadMultiplier

    -- Visible for the whole window: the barrel glowing and venting.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Window and Char and Char.Parent do
            Elapsed += task.wait(0.2)
            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                AbilityFX.Tint(Char, GUNMETAL, 0.3, {FillTransparency = 0.78})
                AbilityFX.Sparks(Live.Position + Vector3.new(0, 1.5, 0), GUNMETAL, 4, 10)
            end
        end
    end)

    task.delay(self.Window, function()
        SpinUp.FireRate = OriginalFireRate
        SpinUp.SpinUpTime = OriginalSpinUp
        SpinUp.MaximumSpread = OriginalSpread

        if not Char or not Char.Parent then
            return
        end

        -- The agreed price: straight to maximum heat, and held there.
        MeterService.Set(Char, HEAT_METER, MeterService.GetMax(Char, HEAT_METER))
        MeterService.HoldDecay(Char, HEAT_METER, self.ForcedCooling)

        SpinUp.Spinning = false

        local Live = Utils.Character.GetRootPart(Char)
        if Live then
            Sounds.PlaySound(self.EndSound, {Position = Live.Position, Volume = 0.9, MinPitch = 0.7, MaxPitch = 0.8})
            AbilityFX.Smoke(Live.Position + Vector3.new(0, 1.5, 0), Color3.fromRGB(170, 170, 170), 24, 4)
            AbilityFX.Text(Live.Position + Vector3.new(0, 5.5, 0), "cooling", Color3.fromRGB(255, 120, 90), 1.4)
        end
    end)
end

--[=[
    THE HEAT GAUGE

    Declared on the character so `MeterService` replicates it as an attribute and the client
    can read it for a UI bar without any networking of its own.

    It cools on its own at `Cooling` a second, but only once `HoldDecay` lets it -- the
    firing loop re-holds it on every shot, so it genuinely only cools when he stops.
]=]
local function HeatInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    MeterService.Define(Char, HEAT_METER, {
        Max = 100,
        Start = 0,
        RegenPerSecond = 0,
        DecayPerSecond = self.Cooling,
    })
end

--------------------------------------------------------------------------------
-- CHARACTER DEFINITION
--------------------------------------------------------------------------------

local MiniGunner: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Mini-Gunner",
        Quote = "Stand still. It's faster for both of us.",

        Role = "Ranged",
        Difficulty = 4,
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 1850,

        Origin = {
            TooltipText = "Brought more than it could carry.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },
    },

    GameplayConfig = {
        Health = 1250,
        BaseSpeed = 9.6,
        SprintSpeedMultiplier = 23 / 9.6,
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

                --- Deliberately poor. He is holding a minigun with both hands.
                Damage = 20,
                Cooldown = 2.3,
                Duration = 0.4,
                Delay = 0.16,
                HitboxSize = Vector3.new(5, 6, 4.5),
                HitboxOffset = CFrame.new(0, 0, -2.4),
                Knockback = 4,

                --- Swinging vents the gun. The reason to ever use it.
                HeatVented = 25,

                Behaviour = WhipBehaviour,
            }),

            SpinUp = Ability.New({
                Name = "Spin Up",
                InputName = "FirstAbility",
                --- Short cooldown because this is a toggle, not a burst.
                Cooldown = 2,
                Duration = 0.4,

                --- Rounds in the drum. Each shot spends one.
                UseSettings = {
                    Limited = true,
                    InitialUses = 90,
                },

                SpinUpTime = 0.8,
                FireRate = 0.12,
                ShotDamage = 4,
                Range = 70,
                SpinSpeedFactor = 0.45,

                --[[
                    HEAT. About four and a half seconds of continuous fire fills the gauge,
                    against the drum's eleven seconds of ammunition -- so heat is the real
                    limit and `Reload` is the second one.
                ]]
                HeatPerShot = 2.6,
                OverheatHold = 2.5,

                --[[
                    ACCURACY. Two seconds of held fire reaches the maximum 9 degree spread,
                    which at 70 studs is roughly eleven studs of wander either side. Tapping
                    stays accurate; holding does not.
                ]]
                SpreadRampTime = 2,
                MaximumSpread = 9,

                --- SUPPRESSION. Near-misses count, capped at level 4 of the effect.
                SuppressRadius = 9,
                SuppressTime = 2,
                MaximumSuppression = 4,

                OverheatSound = "rbxassetid://9046319808",

                --- Internal toggle state.
                Spinning = false,

                SpinSound = "rbxassetid://9118823103",
                ShotSound = "rbxassetid://9125402735",
                DisableSlashOnPerform = false,
                DisableOtherAbilitiesOnPerform = false,

                ExtraInit = SpinUpExtraInit,
                Behaviour = SpinUpBehaviour,
            }),

            Suppress = Ability.New({
                Name = "Suppressing Fire",
                InputName = "SecondAbility",
                Cooldown = 18,
                Duration = 1.2,

                Range = 34,
                ConeWidth = 20,
                Bursts = 5,
                BurstInterval = 0.12,
                BurstDamage = 5,
                GroundDuration = 4,

                UseSound = "rbxassetid://9046319808",
                Behaviour = SuppressBehaviour,
            }),

            Reload = Ability.New({
                Name = "Reload",
                InputName = "ThirdAbility",
                Cooldown = 12,
                Duration = 2.8,

                UseSound = "rbxassetid://9083889906",
                Behaviour = ReloadBehaviour,
            }),

            Overdrive = Ability.New({
                Name = "Overdrive",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 55,
                Duration = 0.5,

                Window = 12,
                --- Nearly double the rate.
                FireRate = 0.07,
                --- Tighter, not perfect.
                SpreadMultiplier = 0.45,
                --- Seconds of forced cooling when the window closes.
                ForcedCooling = 5,

                UseSound = "rbxassetid://9118823103",
                EndSound = "rbxassetid://9046319808",
                Behaviour = OverdriveBehaviour,
            }),

            Heat = Ability.New({
                Name = "Heat",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                --- Units a second, once `HoldDecay` allows it.
                Cooling = 16,

                ExtraInit = HeatInit,
            }),

            HeavyWeapon = Ability.New({
                Name = "Heavy Weapon",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",
            }),
        },
    },

    OnEffect = HeavyWeapon,
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(232, 188, 92)\">"..MiniGunner.Config.Name.."</font>"
local Abilities = MiniGunner.GameplayConfig.Abilities

--- Derived so retuning the fire rate can't leave the page quoting a stale number.
local MinigunDPS = math.round(Abilities.SpinUp.ShotDamage / Abilities.SpinUp.FireRate)
local DrumSeconds = math.round(Abilities.SpinUp.UseSettings.InitialUses * Abilities.SpinUp.FireRate * 10) / 10
--- How long he can hold the trigger before the gauge fills.
local HeatSeconds = math.round(100 / Abilities.SpinUp.HeatPerShot * Abilities.SpinUp.FireRate * 10) / 10

MiniGunner.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = MiniGunner.Config.Name:upper()},
    {Type = "Quote", Text = "\""..MiniGunner.Config.Quote.."\""},
    {
        Type = "Text",
        Text = "Everyone else in this arena has to reach you. "..NameLabel.." doesn't. "..
            "He holds a firing line at seventy studs and pins anything that tries to close, "..
            "and in exchange he gives up the ability to run — from anyone, ever. "..
            "Catch him in a corridor with an empty drum and he is the easiest kill in the game.",
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..MiniGunner.Config.Role,
            "Difficulty: "..string.rep("★", MiniGunner.Config.Difficulty)..string.rep("☆", 5 - MiniGunner.Config.Difficulty),
            "Health: "..tostring(MiniGunner.GameplayConfig.Health),
            "Base Speed: "..tostring(MiniGunner.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(MiniGunner.GameplayConfig.BaseSpeed * MiniGunner.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
            "Max Stamina: "..tostring(MiniGunner.GameplayConfig.StaminaProperties.MaxStamina),
            "Stamina Loss per second: "..tostring(MiniGunner.GameplayConfig.StaminaProperties.StaminaDrain),
            "Stamina Gain per second: "..tostring(MiniGunner.GameplayConfig.StaminaProperties.StaminaGain),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "PISTOL WHIP"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds, with almost no reach. He is holding a minigun with both hands.",
            "Swinging it <b>vents "..tostring(Abilities.Slash.HeatVented).." heat</b>, which is the only way to cool the gun without standing still — and the only reason to ever use this.",
        },
    },

    {Type = "Header", Text = Abilities.SpinUp.Name:upper()},
    {
        Type = "Text",
        Text = {
            "A <b>toggle</b>. Press once to start firing, again to stop.",
            "After a "..tostring(Abilities.SpinUp.SpinUpTime).." second wind-up it fires every "..tostring(Abilities.SpinUp.FireRate)..
                " seconds for "..tostring(Abilities.SpinUp.ShotDamage).." damage, up to "..tostring(Abilities.SpinUp.Range).." studs — about "..tostring(MinigunDPS).." damage per second.",
            "While spun up he moves at "..tostring(math.round(Abilities.SpinUp.SpinSpeedFactor * 100)).."% speed and <b>cannot sprint at all</b>.",
            "The drum holds "..tostring(Abilities.SpinUp.UseSettings.InitialUses).." rounds — roughly "..tostring(DrumSeconds).." seconds of continuous fire.",
            "Walls stop the bullets. Cover works.",
        },
    },
    {
        Type = "Text",
        Text = {
            "<b>HEAT.</b> About "..tostring(HeatSeconds).." seconds of held fire fills the gauge, and then the gun stops until it cools — well before the drum runs out. Heat is the real limit; the drum is the second one.",
            "<b>ACCURACY.</b> The barrel wanders the longer he holds it, up to "..tostring(Abilities.SpinUp.MaximumSpread).." degrees after "..tostring(Abilities.SpinUp.SpreadRampTime).." seconds. Short bursts are precise; sustained fire sprays.",
            "<b>SUPPRESSION.</b> Rounds passing within "..tostring(Abilities.SpinUp.SuppressRadius).." studs of you apply <b>Suppressed</b> even when they miss — a small slow, stacking to "..tostring(Abilities.SpinUp.MaximumSuppression)..". Crossing open ground in front of him costs something even while he is missing.",
        },
    },

    {Type = "Header", Text = Abilities.Suppress.Name:upper()},
    {
        Type = "Text",
        Text = {
            "A wide burst across "..tostring(Abilities.Suppress.Range).." studs directly ahead.",
            "Low damage, but everyone caught is <b>Grounded</b> for "..tostring(Abilities.Suppress.GroundDuration).." seconds and slowed.",
            "This is what he uses when somebody has already closed the distance.",
        },
    },

    {Type = "Header", Text = Abilities.Reload.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Refills the drum to "..tostring(Abilities.SpinUp.UseSettings.InitialUses).." rounds over "..tostring(Abilities.Reload.Duration).." seconds.",
            NameLabel.." <b>cannot move and cannot attack</b> for the entire reload.",
            "Reloading in the open is how he dies.",
        },
    },

    {Type = "Header", Text = "OVERDRIVE  (F)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Overdrive.Window).." seconds with <b>no spin-up at all</b>, a fire rate of "..tostring(Abilities.Overdrive.FireRate).." seconds, and less than half the usual spread.",
            "When the window closes the gun goes <b>straight to maximum heat</b> and is held there for "..tostring(Abilities.Overdrive.ForcedCooling).." seconds. The overheat is guaranteed — he is buying output with a cooling period he agreed to in advance.",
            "Cooldown: "..tostring(Abilities.Overdrive.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "HEAT  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "The gauge cools at "..tostring(Abilities.Heat.Cooling).." a second, but <b>only once he stops firing</b> — holding the trigger keeps it hot.",
            "Pistol-whipping vents it. So does simply waiting.",
        },
    },

    {Type = "Header", Text = "HEAVY WEAPON  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "He <b>ignores Slipping entirely</b>, and takes <b>Snared</b> and <b>Slowness</b> at half duration. You cannot trip somebody braced against a minigun.",
            "His whole kit roots him. He is not also allowed to be the easiest person here to shove out of position.",
        },
    },
}

return MiniGunner
