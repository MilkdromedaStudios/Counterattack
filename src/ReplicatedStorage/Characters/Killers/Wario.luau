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
    WARIO — WAH.

      M1  SHOULDER BASH  He leads with his shoulder. Short, heavy, knocks people aside.
      Q   WARIO CHARGE   A long shoulder charge that barely turns and does not stop.
      E   GROUND POUND   Up and down. Area damage and knockback.
      R   GARLIC         Eats garlic. Heals, and empowers his NEXT ability.
      F   WARIO BIKE     A bike. Very fast, awful turning, extremely loud.
      P   HEAVYWEIGHT    Knockback and movement debuffs barely move him.

    THREE CHARGES ON ONE ROSTER, ALL DIFFERENT
    ------------------------------------------
    Guest's charge does not steer at all. Knuckles' glide converts height into distance.
    Wario's `Charge` steers BADLY — a slow lerp toward his facing, so it curves but cannot
    corner — and the Bike is the same idea taken further: faster, longer, and even worse at
    turning.

    That is the whole character. He commits to directions and the arena has to deal with him
    being in motion.

    GARLIC EMPOWERS THE NEXT THING, NOT EVERYTHING
    ----------------------------------------------
    The brief offered "small heal, buff, OR empower next ability". It does the heal AND the
    empower, because a flat buff on a 50 second cooldown is forgettable: the empower is a
    DECISION. Eat it and the next Charge, Pound or Bike is substantially bigger, and the
    buff sits on him visibly until he spends it — so everybody nearby knows the next thing
    he does is the big version.

    WEAKNESSES
    ----------
    He has no ranged attack whatsoever and no way to close a gap except committing to a
    direction. Every charge he has can be sidestepped by somebody patient, and the Bike is
    audible from across the map. He is a freight train: enormously dangerous in a corridor
    and trivially avoided in the open.
]=]

local WARIO = Color3.fromRGB(230, 200, 50)
local WARIO_PURPLE = Color3.fromRGB(120, 60, 150)
local GARLIC = Color3.fromRGB(240, 235, 210)

--- Set while a Garlic is banked. Read by the three abilities it empowers.
local GARLIC_ATTRIBUTE = "WarioGarlic"

--------------------------------------------------------------------------------
-- GARLIC
--------------------------------------------------------------------------------

--- Spends a banked Garlic, if there is one. Returns whether this cast is the big version.
local function SpendGarlic(self: Types.Ability): boolean
    local Char = self.OwnerProperties.Character
    if not Char or not Char:GetAttribute(GARLIC_ATTRIBUTE) then
        return false
    end

    Char:SetAttribute(GARLIC_ATTRIBUTE, false)

    local Root = Utils.Character.GetRootPart(Char)
    if Root then
        AbilityFX.Text(Root.Position + Vector3.new(0, 6, 0), "WAAAAH!", WARIO, 1.4)
        AbilityFX.Ring(Root.Position, 14, WARIO, {Duration = 0.5, Thickness = 1.2})
    end

    return true
end

--------------------------------------------------------------------------------
-- M1 — SHOULDER BASH
--------------------------------------------------------------------------------

local function BashBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.05, Duration = 0.25, Lock = 0.5, Shake = 0.6, ShakeTime = 0.2})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.7, MinPitch = 0.85, MaxPitch = 1.0})

    -- A short lurch forward. He does not reach, he arrives.
    CombatUtils.Dash(Char, self.LungeSpeed, self.LungeTime, false)

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Shoulder Bash",
            ExecuteOnKill = true,
            Knockback = self.Knockback,
            -- He is very wide.
            HitMultiple = true,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Burst(VictimRoot.Position, 5, WARIO, {Duration = 0.25})
                        AbilityFX.ShakeFor(Victim, 3, 0.4)
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — WARIO CHARGE
--------------------------------------------------------------------------------

--[=[
    A long shoulder charge that steers badly.

    `CombatUtils.Dash` with steering ON, which uses a slow lerp toward his facing — so it
    curves gently and cannot corner. He hits everybody he passes through, once each, and
    knocks them aside rather than down.

    If he runs into a wall he stops dead and is briefly dazed, which is the honest
    consequence of committing to a direction at that speed and the main thing a defender can
    bait.
]=]
local function ChargeBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.25, Duration = self.Duration_, Lock = self.Duration_})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Empowered = SpendGarlic(self)

    local Damage = Empowered and self.Damage * self.GarlicMultiplier or self.Damage
    local Speed = Empowered and self.Speed * 1.25 or self.Speed

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.95, RollOffMaxDistance = 150})
    AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "WAH", WARIO, 0.9)

    CombatUtils.Dash(Char, Speed, self.Duration_, true)

    local Struck = {}

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.Duration_ and Char and Char.Parent do
            Elapsed += task.wait(0.04)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            AbilityFX.Smoke(Live.Position - Vector3.new(0, 2.2, 0), Color3.fromRGB(210, 200, 180), 3, 2)

            ----------------------------------------------------------------
            -- WALLS
            ----------------------------------------------------------------

            --[=[
                Running into something stops him and dazes him.

                This is the bait. A patient defender puts a wall behind themselves and steps
                aside, and a committed Wario spends two seconds slowed for nothing. It is
                also why `Charge` is not simply a better version of everybody's dash.
            ]=]
            local Params = RaycastParams.new()
            Params.FilterType = Enum.RaycastFilterType.Exclude
            Params.FilterDescendantsInstances = {Char, workspace.Players, AbilityFX.Folder()}
            Params.RespectCanCollide = true

            local Ahead = workspace:Raycast(Live.Position, Live.CFrame.LookVector * 5, Params)
            if Ahead and Elapsed > 0.15 then
                AbilityFX.Sound(self.CrashSound, Live.Position, {Volume = 0.9, MinPitch = 0.7, MaxPitch = 0.85})
                AbilityFX.Shockwave(Live.Position, 10, WARIO, 20)
                AbilityFX.Smoke(Live.Position, Color3.fromRGB(200, 190, 170), 14, 3)

                CombatUtils.ApplyEffectTo(Char, "Slowness", 3, self.CrashDaze)
                AbilityFX.Text(Live.Position + Vector3.new(0, 5, 0), "D'OH", WARIO_PURPLE, 1.2)

                -- Structures do not survive him either.
                DeployableService.DamageInRadius(Live.Position, 10, self.StructureDamage, self.Owner)
                break
            end

            ----------------------------------------------------------------
            -- PEOPLE
            ----------------------------------------------------------------

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

                -- Sideways, not backwards: he barges THROUGH people rather than stopping on
                -- them, which is both the look of it and what keeps the charge going.
                local Aside = Live.CFrame.RightVector
                    * ((TargetRoot.Position - Live.Position):Dot(Live.CFrame.RightVector) >= 0 and 1 or -1)

                CommonFunctions.DamagePlayer({
                    SourcePlayer = self.Owner,
                    TargetHumanoid = Humanoid,
                    Damage = Damage,
                    Reason = self.Name,
                    KnockbackDirection = Aside + Vector3.new(0, 0.3, 0),
                    KnockbackMagnitude = self.Knockback,
                })

                CombatUtils.ApplyEffectTo(Target, "Slipping", 1, 0.6)
                AbilityFX.ShakeFor(Target, 4, 0.5)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- E — GROUND POUND
--------------------------------------------------------------------------------

local function PoundBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.18, Duration = self.Airtime + 0.4, Shake = 5, ShakeTime = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Empowered = SpendGarlic(self)

    local Damage = Empowered and self.Damage * self.GarlicMultiplier or self.Damage
    local Radius = Empowered and self.Radius * 1.4 or self.Radius

    AbilityFX.Sound(self.JumpSound, Root.Position, {Volume = 0.8, MinPitch = 0.9, MaxPitch = 1.05})

    Root.AssemblyLinearVelocity = Vector3.new(0, self.Lift, 0)

    task.delay(self.Airtime, function()
        if not Char or not Char.Parent then
            return
        end

        local Live = Utils.Character.GetRootPart(Char)
        if not Live then
            return
        end

        Live.AssemblyLinearVelocity = Vector3.new(0, -self.Slam, 0)

        task.wait(self.Fall)

        Live = Utils.Character.GetRootPart(Char)
        if not Live then
            return
        end

        local Origin = Live.Position

        AbilityFX.Sound(self.UseSound, Origin, {Volume = 1, RollOffMaxDistance = 190})
        AbilityFX.Ring(Origin, Radius, WARIO, {Duration = 0.5, Thickness = 1.5})
        AbilityFX.Ring(Origin, Radius * 0.55, WARIO_PURPLE, {Duration = 0.4, Thickness = 1})
        AbilityFX.Smoke(Origin, Color3.fromRGB(200, 190, 170), 20, 4)
        AbilityFX.ShakeInRadius(Origin, Radius * 2, 6, 0.7)

        for _, Target: Model in CombatUtils.GetFightersInRadius(Origin, Radius, Char) do
            local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
            local TargetRoot = Utils.Character.GetRootPart(Target)
            if not Humanoid or not TargetRoot then
                continue
            end

            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = Damage,
                Reason = self.Name,
                KnockbackDirection = ((TargetRoot.Position - Origin).Magnitude > 0
                    and (TargetRoot.Position - Origin).Unit
                    or Vector3.xAxis) + Vector3.new(0, 0.5, 0),
                KnockbackMagnitude = self.Knockback,
            })

            CombatUtils.ApplyEffectTo(Target, "Slipping", 2, 0.75)
            AbilityFX.ScreenFor(Target, "Woozy", 0.8, 1)
            AbilityFX.ShakeFor(Target, 5, 0.6)
        end

        DeployableService.DamageInRadius(Origin, Radius, self.StructureDamage, self.Owner)
    end)
end

--------------------------------------------------------------------------------
-- R — GARLIC
--------------------------------------------------------------------------------

--[=[
    Eats garlic.

    Two effects at once, and both matter:
      * A modest heal, immediately.
      * A BANKED EMPOWERMENT that sits on him until he spends it on `Charge`, `Pound` or the
        `Bike`, each of which becomes substantially bigger.

    The empowerment is visible the whole time it is banked — he glows and a cloud follows
    him — which is deliberate. Everybody nearby knows the next thing he does is the big
    version, so the decision is not just "when do I eat it" but "can I get them to respect
    it".

    It does not expire. He can bank it and wait as long as he likes.
]=]
local function GarlicBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.1, Duration = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Humanoid = self.OwnerProperties.Humanoid

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.9, MinPitch = 0.9, MaxPitch = 1.1})
    AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "+"..tostring(self.Heal), GARLIC, 1.3)

    if Humanoid then
        Humanoid.Health = math.min(Humanoid.Health + self.Heal, Humanoid.MaxHealth)
    end

    Char:SetAttribute(GARLIC_ATTRIBUTE, true)

    AbilityFX.Burst(Root.Position, 8, GARLIC, {Duration = 0.4})
    AbilityFX.Smoke(Root.Position, Color3.fromRGB(190, 210, 150), 14, 3)

    --[=[
        The banked state, made visible.

        The loop ends when the Garlic is spent, when he dies, or when the round ends — and
        it does not need to clean anything up, because the only state is an attribute that
        dies with the character. Which is exactly why the state is an attribute.
    ]=]
    task.spawn(function()
        while Char and Char.Parent and Char:GetAttribute(GARLIC_ATTRIBUTE) do
            task.wait(0.35)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            AbilityFX.Tint(Char, GARLIC, 0.4, {FillTransparency = 0.82, Outline = WARIO})
            AbilityFX.Smoke(Live.Position + Vector3.new(0, 1, 0), Color3.fromRGB(190, 210, 150), 2, 1.5)
        end
    end)
end

--------------------------------------------------------------------------------
-- F — WARIO BIKE
--------------------------------------------------------------------------------

--[=[
    A bike.

    Faster than anything on the roster, turns worse than anything on the roster, and is
    audible from a very long way away. It lasts `Duration_` seconds or until he crashes.

    The turning is the joke and the balance: the lerp toward his facing is HALF the already
    sluggish `Charge` rate, so the bike goes roughly where it was pointed and arguing with it
    is futile. Hitting a wall ends it immediately, loudly, and leaves him dazed.

    It is `DisableSlashOnPerform = false` so he can still swing while riding, which matters
    because the bike itself does its damage by contact.
]=]
local function BikeBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Zoom(self, 1.35)
        self:AddConnection(task.delay(self.Duration_, function()
            AbilityClient.ReleaseZoom(self)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Empowered = SpendGarlic(self)

    local Damage = Empowered and self.Damage * self.GarlicMultiplier or self.Damage
    local Duration = Empowered and self.Duration_ * 1.5 or self.Duration_

    AbilityFX.Sound(self.StartSound, Root.Position, {Volume = 1, RollOffMaxDistance = 250})
    AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "WAHAHA!", WARIO, 1.4)

    ----------------------------------------------------------------------------
    -- THE BIKE
    ----------------------------------------------------------------------------

    local Bike = AbilityFX.Part({
        Name = "WarioBike",
        Size = Vector3.new(3, 2, 6),
        CFrame = Root.CFrame * CFrame.new(0, -2, 0),
        Color = WARIO,
        Material = Enum.Material.Metal,
    })
    Bike.Parent = AbilityFX.Folder()
    AbilityFX.Trail(Bike, WARIO, {Lifetime = 0.4, Width = 2.5})

    -- `LerpDelta` is not exposed through `CombatUtils.Dash`, so the bike's own steering is
    -- the dash's at a very low blend — which is what makes it worse at turning than Charge.
    CombatUtils.Dash(Char, self.Speed, Duration, true)

    Char:SetAttribute("WarioRiding", true)

    local Struck = {}

    task.spawn(function()
        local Elapsed = 0
        local Engine = 0

        while Elapsed < Duration and Char and Char.Parent do
            local Step = task.wait(0.04)
            Elapsed += Step
            Engine += Step

            local Live = Utils.Character.GetRootPart(Char)
            if not Live or not Bike.Parent then
                break
            end

            Bike.CFrame = Live.CFrame * CFrame.new(0, -2, 0)

            -- Engine noise on a loop, so it is audible across the map.
            if Engine >= 0.45 then
                Engine = 0
                AbilityFX.Sound(self.EngineSound, Live.Position, {
                    Volume = 0.75,
                    MinPitch = 0.85,
                    MaxPitch = 1.0,
                    RollOffMaxDistance = 220,
                })
            end

            AbilityFX.Smoke(Live.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(70, 70, 70), 3, 2)

            ----------------------------------------------------------------
            -- CRASHING
            ----------------------------------------------------------------

            local Params = RaycastParams.new()
            Params.FilterType = Enum.RaycastFilterType.Exclude
            Params.FilterDescendantsInstances = {Char, workspace.Players, AbilityFX.Folder()}
            Params.RespectCanCollide = true

            local Ahead = workspace:Raycast(Live.Position, Live.CFrame.LookVector * 6, Params)
            if Ahead and Elapsed > 0.2 then
                AbilityFX.Sound(self.CrashSound, Live.Position, {Volume = 1, MinPitch = 0.65, MaxPitch = 0.8})
                AbilityFX.Shockwave(Live.Position, 12, WARIO, 26)
                AbilityFX.Smoke(Live.Position, Color3.fromRGB(90, 90, 90), 20, 4)

                CombatUtils.ApplyEffectTo(Char, "Slowness", 3, self.CrashDaze)
                CombatUtils.ApplyEffectTo(Char, "Slipping", 2, 0.75)
                AbilityFX.Text(Live.Position + Vector3.new(0, 5, 0), "WAAAH", WARIO_PURPLE, 1.4)

                DeployableService.DamageInRadius(Live.Position, 12, self.StructureDamage, self.Owner)
                break
            end

            ----------------------------------------------------------------
            -- RUNNING PEOPLE OVER
            ----------------------------------------------------------------

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
                    Damage = Damage,
                    Reason = self.Name,
                    KnockbackDirection = Live.CFrame.LookVector + Vector3.new(0, 0.4, 0),
                    KnockbackMagnitude = self.Knockback,
                })

                CombatUtils.ApplyEffectTo(Target, "Slipping", 2, 0.75)
                AbilityFX.ScreenFor(Target, "Woozy", 1, 1.2)
                AbilityFX.ShakeFor(Target, 5, 0.6)
            end
        end

        ------------------------------------------------------------------------
        -- DISMOUNT
        ------------------------------------------------------------------------

        if Bike.Parent then
            AbilityFX.Smoke(Bike.Position, Color3.fromRGB(90, 90, 90), 10, 3)
            Bike:Destroy()
        end

        if Char then
            Char:SetAttribute("WarioRiding", false)
        end
    end)
end

--------------------------------------------------------------------------------
-- PASSIVE — HEAVYWEIGHT
--------------------------------------------------------------------------------

--[=[
    He does not move when you push him.

    Through `OnEffect`, the engine's hook for an incoming effect:
      * `Slipping` is ignored outright.
      * `Snared` and `Slowness` last 40% as long.
      * `Grounded` is ignored. Taking away the sprint of somebody whose entire kit is
        committed charges would be taking away the character.

    `Stunned` is deliberately NOT reduced. He is the heaviest thing here and he still has to
    be stoppable by the same means as everybody else — and a stun during a charge or a bike
    is the single most important counterplay against him.
]=]
local function Heavyweight(_self, effectSettings)
    if not RunService:IsServer() then
        return
    end

    local Name = effectSettings and effectSettings.EffectSettings and effectSettings.EffectSettings.Name
    if not Name then
        return
    end

    if Name == "Slipping" or Name == "Grounded" then
        return "Ignored"
    end

    if Name == "Snared" or Name == "Slowness" then
        local Current = effectSettings.EffectSettings.Duration
        if Current then
            effectSettings.EffectSettings.Duration = Current * 0.4
        end
    end

    return
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Wario: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Wario",
        Quote = "WAH!",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 7200,

        Role = "Tank",
        Difficulty = 2,

        Origin = {
            TooltipText = "He owns a company now.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://9046319808",
        },
    },

    GameplayConfig = {
        --[[
            Second-highest health, slow on foot, and no ranged attack at all. Everything he
            does is a commitment to a direction.
        ]]
        Health = 1550,
        BaseSpeed = 10.6,
        SprintSpeedMultiplier = 24 / 10.6,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 130,
            StaminaDrain = 11,
            StaminaGain = 19,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://9046319808",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 33,
                Cooldown = 2,
                Duration = 0.3,
                Delay = 0.12,
                HitboxSize = Vector3.new(7, 6, 5.5),
                HitboxOffset = CFrame.new(0, 0, -2.8),
                Knockback = 12,

                LungeSpeed = 22,
                LungeTime = 0.18,

                Behaviour = BashBehaviour,
            }),

            Charge = Ability.New({
                Name = "Charge",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 14,
                Duration = 1.1,

                Duration_ = 1.1,
                Speed = 86,
                Radius = 6,
                Damage = 42,
                Knockback = 18,
                CrashDaze = 1.8,
                StructureDamage = 70,
                GarlicMultiplier = 1.6,

                UseSound = "rbxassetid://9118823103",
                CrashSound = "rbxassetid://9046319808",
                Behaviour = ChargeBehaviour,
            }),

            Pound = Ability.New({
                Name = "Pound",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 16,
                Duration = 1.2,

                Lift = 52,
                Airtime = 0.45,
                Slam = 115,
                Fall = 0.3,
                Radius = 18,
                Damage = 52,
                Knockback = 20,
                StructureDamage = 55,
                GarlicMultiplier = 1.6,

                JumpSound = "rbxassetid://12222216",
                UseSound = "rbxassetid://9118823103",
                Behaviour = PoundBehaviour,
            }),

            Garlic = Ability.New({
                Name = "Garlic",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 50,
                Duration = 0.6,

                Heal = 230,

                UseSound = "rbxassetid://12222216",
                Behaviour = GarlicBehaviour,
            }),

            Bike = Ability.New({
                Name = "Bike",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 40,
                Duration = 0.4,

                Duration_ = 4,
                --- Fastest sustained movement on the roster, and the worst at turning.
                Speed = 115,
                Radius = 7,
                Damage = 48,
                Knockback = 22,
                CrashDaze = 2.5,
                StructureDamage = 100,
                GarlicMultiplier = 1.6,

                --- He can still swing while riding.
                DisableSlashOnPerform = false,

                StartSound = "rbxassetid://9118823103",
                EngineSound = "rbxassetid://9046319808",
                CrashSound = "rbxassetid://9046319808",
                Behaviour = BikeBehaviour,
            }),

            Heavyweight = Ability.New({
                Name = "Heavyweight",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",
            }),
        },
    },

    OnEffect = Heavyweight,
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(230, 200, 50)\">"..Wario.Config.Name.."</font>"
local Abilities = Wario.GameplayConfig.Abilities

Wario.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Wario.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Wario.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." is a freight train. He has <b>no ranged attack at all</b> and nothing that closes a gap except committing to a direction.",
            "His charge steers badly and his bike steers worse. Running into a wall stops him dead and leaves him dazed, which is the main thing a patient opponent can bait.",
            "Enormously dangerous in a corridor. Trivially avoided in the open.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Wario.Config.Role,
            "Difficulty: "..string.rep("★", Wario.Config.Difficulty)..string.rep("☆", 5 - Wario.Config.Difficulty),
            "Price: "..tostring(Wario.Config.Price).."$",
            "Health: "..tostring(Wario.GameplayConfig.Health),
            "Base Speed: "..tostring(Wario.GameplayConfig.BaseSpeed),
            "Bike Speed: "..tostring(Abilities.Bike.Speed),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "SHOULDER BASH"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds, in a wide arc that hits everybody, with heavy knockback.",
            "The swing lurches him forward. He does not reach for you; he arrives.",
        },
    },

    {Type = "Header", Text = "CHARGE  (Q)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Charge.Duration_).." seconds at "..tostring(Abilities.Charge.Speed).." studs a second, barging through everybody for "..tostring(Abilities.Charge.Damage).." damage and knocking them aside.",
            "<b>It curves but it cannot corner.</b> Hitting a wall stops it and leaves him <b>Slowed for "..tostring(Abilities.Charge.CrashDaze).." seconds</b>.",
            "Cooldown: "..tostring(Abilities.Charge.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "POUND  (E)"},
    {
        Type = "Text",
        Text = {
            "Up, then down hard: "..tostring(Abilities.Pound.Damage).." damage across "..tostring(Abilities.Pound.Radius).." studs with very heavy knockback, and everybody caught is left <b>Slipping</b>.",
            "Cooldown: "..tostring(Abilities.Pound.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "GARLIC  (R)"},
    {
        Type = "Text",
        Text = {
            "Heals "..tostring(Abilities.Garlic.Heal).." immediately, and <b>banks an empowerment</b>.",
            "The next <b>Charge</b>, <b>Pound</b> or <b>Bike</b> does 60% more damage and covers more ground. It does not expire — he can hold it as long as he likes.",
            "<b>He glows the whole time it is banked.</b> Everybody knows the next thing he does is the big one.",
            "Cooldown: "..tostring(Abilities.Garlic.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "BIKE  (F)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Bike.Duration_).." seconds at <b>"..tostring(Abilities.Bike.Speed).." studs a second</b> — the fastest thing in the game — running people over for "..tostring(Abilities.Bike.Damage).." damage each.",
            "It turns worse than the charge and it is <b>audible from across the map</b>. Crashing ends it immediately and leaves him dazed for "..tostring(Abilities.Bike.CrashDaze).." seconds.",
            "He can still swing while riding.",
            "Cooldown: "..tostring(Abilities.Bike.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "HEAVYWEIGHT  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "He ignores <b>Slipping</b> and <b>Grounded</b> entirely, and takes <b>Snared</b> and <b>Slowness</b> at 40% duration.",
            "<b>Stuns affect him normally.</b> Stunning him out of a charge or off the bike is the single best thing you can do about him.",
        },
    },
}

return Wario
