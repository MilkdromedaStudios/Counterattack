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

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    FOG — the room gets quieter and you don't notice when.

    AN ORIGINAL CHARACTER. Its identity is unchanged from the version before this pass — an
    information killer that barely deals direct damage and wins by making the arena
    unreadable for everybody else while staying perfectly oriented inside its own mist.
    What changed is the presentation, a basic attack that belongs to it, a fourth ability it
    was always implied to have, and the passive being written down as a passive instead of
    hiding inside one ability's tick callback.

      M1  MIST CLAW      A wide, weak sweep. Much harder inside its own mist.
      Q   ROLLING BANK   A bank of mist. Blinds and slows anyone in it. Not Fog.
      E   DISSIPATE      Becomes vapour: near-invisible and fast, and cannot attack.
      R   SUFFOCATE      Only reaches people standing inside its mist. Decisive when it does.
      F   FOG STEP       Teleports from one of its own clouds to another.
      P   DENSE AIR      Sees everyone in its mist. Hard to pick out at range.

    THE SHAPE OF THE CHARACTER
    --------------------------
    Set up the terrain first, then collect. Every single thing it has is worth more inside a
    cloud and close to worthless outside one, which means its whole game is about where the
    fight happens rather than how it goes.

    `Suffocate` refunds itself if nobody was in the mist, and `Fog Step` needs two clouds, so
    both of them punish bad reads with lost tempo rather than lost cooldowns.

    WEAKNESSES
    ----------
    1050 health. 19 damage on a two second basic attack. It cannot kill anybody quickly and
    has no mobility at all outside its own clouds — chase it away from its mist and it is the
    weakest character in the arena until the cooldowns come back.
]=]

local MIST = Color3.fromRGB(190, 195, 205)
local MIST_DEEP = Color3.fromRGB(90, 95, 110)

--------------------------------------------------------------------------------
-- CLOUDS
--------------------------------------------------------------------------------

--- The clouds Fog currently has out, so everything else knows where its mist is.
local function GetActiveClouds(self: Types.Ability): {any}
    local Cache = self.CharModule.GameplayConfig.Cache
    Cache.FogClouds = Cache.FogClouds or {}
    return Cache.FogClouds
end

--- Is this character standing in any of Fog's mist?
local function InMist(self: Types.Ability, char: Model): boolean
    local Root = Utils.Character.GetRootPart(char)
    if not Root then
        return false
    end

    for _, Cloud in GetActiveClouds(self) do
        if (Cloud.Position - Root.Position).Magnitude <= Cloud.Radius then
            return true
        end
    end

    return false
end

--------------------------------------------------------------------------------
-- M1 — MIST CLAW
--------------------------------------------------------------------------------

--[=[
    A sweep of condensing air.

    THE DAMAGE IS CONDITIONAL, which is the point: 19 outside its mist, 31 inside it. That
    makes its basic attack obey the same rule as everything else it owns, so there is no part
    of the character that works equally well in the open.

    It is also very wide and hits everybody in the arc, because flailing in a cloud should
    not require precision — from inside the mist it genuinely cannot see well either.
]=]
local function MistClawBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.03, Duration = 0.3, Lock = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Inside = InMist(self, Char)
    local Damage = Inside and self.MistDamage or self.Damage

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.5, MinPitch = 0.8, MaxPitch = 0.95})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        -- A pale arc of condensation. Brighter when the bonus applies, so the player can
        -- see when their attack is the strong one.
        local Centre = Root.Position + Root.CFrame.LookVector * 3
        AbilityFX.Cone(
            Root.Position + Vector3.new(0, 1, 0),
            Root.CFrame.LookVector,
            7,
            120,
            Inside and Color3.new(1, 1, 1) or MIST,
            {Rays = 5, Duration = 0.22, Width = 0.6}
        )
        AbilityFX.Smoke(Centre, MIST, 6, 2.5)

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = Damage,
            Reason = Inside and "Mist Claw (in mist)" or "Mist Claw",
            ExecuteOnKill = true,
            -- Wide and piercing. It is a sweep, not a stab.
            HitMultiple = true,
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — ROLLING BANK
--------------------------------------------------------------------------------

--[=[
    A bank of mist. Anyone standing inside is blinded and slowed; Fog isn't.

    Unchanged in numbers from the original. What is new is that the reveal of who is inside
    has moved out of this ability's tick callback and into the passive, where it belongs —
    it was never a property of ROLLING BANK, it was a property of FOG, and putting it here
    meant `Fog Step` and `Suffocate` could reach clouds the character could not see into.
]=]
local function RollingBankBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.05, Duration = 0.5, Lock = 0.5})
        return
    end

    local Root = self.OwnerProperties.HRP
    local Centre = (Root.CFrame * CFrame.new(0, -2, -self.Distance)).Position

    AbilityFX.Sound(self.UseSound, Centre, {Volume = 0.7, RollOffMaxDistance = 90})

    -- A rolling front rather than a sphere appearing: several puffs expanding outward.
    for Index = 1, 5 do
        task.delay(Index * 0.06, function()
            AbilityFX.Smoke(
                Centre + Vector3.new((math.random() - 0.5) * self.Radius, 0, (math.random() - 0.5) * self.Radius),
                MIST,
                10,
                self.Radius * 0.5
            )
        end)
    end

    local Clouds = GetActiveClouds(self)

    local Zone = CombatUtils.CreateZone({
        SourcePlayer = self.Owner,
        Position = Centre,
        Radius = self.Radius,
        Lifetime = self.CloudDuration,
        TickRate = 0.6,
        Damage = 0,
        IgnoreOwner = true,
        Color = MIST,
        Material = Enum.Material.Glass,
        Transparency = 0.55,
        Effects = {
            {Name = "Blindness", Level = 1, Duration = 1.4},
            {Name = "Slowness", Level = self.SlowLevel, Duration = 1.4},
        },
        OnTick = function(fighters: {Model})
            -- The screen effect that sells it. Topped up each tick, so stepping out clears
            -- within a second.
            for _, Target: Model in fighters do
                AbilityFX.ScreenFor(Target, "Mist", 1.2, 1.1)
            end
        end,
    })

    table.insert(Clouds, {Zone = Zone, Position = Centre, Radius = self.Radius})

    -- Drop it from the tracking list once it expires, so nothing can use a dead cloud.
    self:AddConnection(task.delay(self.CloudDuration, function()
        for index = #Clouds, 1, -1 do
            if Clouds[index].Zone == Zone then
                table.remove(Clouds, index)
            end
        end
    end))
end

--------------------------------------------------------------------------------
-- E — DISSIPATE
--------------------------------------------------------------------------------

--[=[
    Becomes vapour: near-invisible, faster, unreadable by auras — and unable to attack.

    `Invincible` is deliberately NOT used. Untargetable AND untouchable would make this a
    free escape from any situation; being hard to see is enough, and the attack lockout is
    what stops it being a stealth opener as well as an escape.
]=]
local function DissipateBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        -- The view widens and stays wide for the whole duration — the one ability on the
        -- roster whose punch is a sustained state rather than a hit.
        AbilityClient.Zoom(self, 1.15)
        self:AddConnection(task.delay(self.Duration, function()
            AbilityClient.ReleaseZoom(self)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.6})

    -- Can't swing while you're a cloud. `Ability:CanUse` reads this attribute.
    Char:SetAttribute("PreventSlash", true)

    CommonFunctions.ApplyEffect({
        TargetHumanoid = self.OwnerProperties.Humanoid,
        EffectSettings = {Name = "Invisibility", Level = self.InvisibilityLevel, Duration = self.Duration},
    })
    CommonFunctions.ApplyEffect({
        TargetHumanoid = self.OwnerProperties.Humanoid,
        EffectSettings = {Name = "Undetectable", Duration = self.Duration},
    })

    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.SpeedFactor)

    -- A thin trail of vapour, so it is not literally invisible — there is something to
    -- track if you are paying attention.
    task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.Duration and Char and Char.Parent do
            Elapsed += task.wait(0.15)
            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                AbilityFX.Smoke(Live.Position, MIST, 2, 2)
            end
        end
    end)

    --[[
        Raw `task.delay`, not `self:AddConnection`.

        The original used `AddConnection`, which hands the thread to the Janitor linked to
        the character — so dying mid-Dissipate cancelled the cleanup and left both a speed
        factor and `PreventSlash` set. `PreventSlash` surviving onto the next body would
        mean a Fog who could never swing again.
    ]]
    task.delay(self.Duration, function()
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)

        if Char then
            Char:SetAttribute("PreventSlash", nil)
        end
    end)
end

--------------------------------------------------------------------------------
-- R — SUFFOCATE
--------------------------------------------------------------------------------

--[=[
    The payoff. Only reaches fighters standing inside Fog's own mist.

    Anywhere else in the arena this does nothing at all — and refunds itself, because a read
    that was simply wrong about where people were standing should cost tempo rather than
    thirty seconds.
]=]
local function SuffocateBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.88, Duration = 0.6, Lock = 0.7, Shake = 1, ShakeTime = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Clouds = GetActiveClouds(self)

    if #Clouds <= 0 then
        self.CooldownTimer = 0
        self.OnCooldown = false
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "no mist", MIST, 0.9)
        return
    end

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.9})

    -- Everyone in any active cloud, without double-hitting anyone unlucky enough to be in
    -- two of them.
    local Caught = {}
    for _, Cloud in Clouds do
        for _, Target: Model in CombatUtils.GetFightersInRadius(Cloud.Position, Cloud.Radius, Char) do
            Caught[Target] = true
        end
    end

    local Count = 0
    for Target: Model in Caught do
        local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid then
            continue
        end

        CommonFunctions.DamagePlayer({
            SourcePlayer = self.Owner,
            TargetHumanoid = Humanoid,
            Damage = self.Damage,
            Reason = "Suffocate",
        })

        CombatUtils.ApplyEffectTo(Target, "Snared", 3, self.SnareDuration)

        local TargetRoot = Utils.Character.GetRootPart(Target)
        if TargetRoot then
            -- The mist closing in around one person: a sphere collapsing onto them.
            local Choke = AbilityFX.Part({
                Name = "SuffocateVFX",
                Shape = Enum.PartType.Ball,
                Size = Vector3.one * 10,
                Color = MIST_DEEP,
                Material = Enum.Material.Glass,
                Transparency = 0.35,
                CFrame = TargetRoot.CFrame,
            })
            Choke.Parent = AbilityFX.Folder()

            game:GetService("TweenService"):Create(
                Choke,
                TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Size = Vector3.one * 2, Transparency = 1}
            ):Play()
            game:GetService("Debris"):AddItem(Choke, 0.7)

            AbilityFX.ScreenFor(Target, "Mist", 1.6, 2)
            AbilityFX.ShakeFor(Target, 2, 0.5)
        end

        Count += 1
    end

    if Count <= 0 then
        self.CooldownTimer = 0
        self.OnCooldown = false
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "empty", MIST, 0.9)
    end
end

--------------------------------------------------------------------------------
-- F — FOG STEP
--------------------------------------------------------------------------------

--[=[
    Teleports from one of its own clouds to another.

    Its ONLY mobility, and it is entirely conditional on its own setup: two clouds, and it
    has to be standing in one of them. That is the character — it does not move around the
    arena, it moves around the terrain it made.

    Cheap on cooldown because it cannot be used offensively on its own: the destination is a
    cloud it placed, which the people in that cloud can see it arrive in.
]=]
local function FogStepBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.12, Duration = 0.3})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Clouds = GetActiveClouds(self)

    if #Clouds < 2 then
        self.CooldownTimer = 0
        self.OnCooldown = false
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "needs two banks", MIST, 1)
        return
    end

    -- Which cloud is it in now?
    local Current = nil
    for Index, Cloud in Clouds do
        if (Cloud.Position - Root.Position).Magnitude <= Cloud.Radius then
            Current = Index
            break
        end
    end

    if not Current then
        self.CooldownTimer = 0
        self.OnCooldown = false
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "not in mist", MIST, 1)
        return
    end

    -- The furthest other cloud, so stepping is always the biggest available reposition
    -- rather than an arbitrary one.
    local Best, BestDistance = nil, -1
    for Index, Cloud in Clouds do
        if Index == Current then
            continue
        end

        local Distance = (Cloud.Position - Root.Position).Magnitude
        if Distance > BestDistance then
            Best, BestDistance = Cloud, Distance
        end
    end

    if not Best then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    local Destination = AbilityFX.GroundAt(Best.Position, {Char}, 50)
    if not Destination then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.7})
    AbilityFX.Smoke(Root.Position, MIST, 18, 4)

    if not CombatUtils.Blink(Char, Destination + Vector3.new(0, 3, 0)) then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    AbilityFX.Smoke(Destination, MIST, 18, 4)
    AbilityFX.Sound(self.UseSound, Destination, {Volume = 0.7})
end

--------------------------------------------------------------------------------
-- PASSIVE — DENSE AIR
--------------------------------------------------------------------------------

--[=[
    Two things, and the first is what makes the whole character function.

      1. IT ALWAYS SEES WHO IS IN ITS OWN MIST. Without this, blinding an area it also
         cannot see into is exactly as bad for it as for everybody else. It used to live
         inside `Rolling Bank`'s tick callback, which meant it was a property of that
         ability rather than of the character — this is the same effect in the right place.

      2. IT IS HARD TO PICK OUT AT RANGE. A light permanent `Invisibility` while nobody is
         close. It is not stealth: anybody within 30 studs sees it perfectly normally, and
         the effect drops the moment somebody is. What it does is make reading the arena from
         across the map harder, which is thematically exactly right and mechanically small.
]=]
local function DenseAirInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    self:AddConnection(task.spawn(function()
        local Faded = false

        while Char and Char.Parent do
            task.wait(0.5)

            local Root = Utils.Character.GetRootPart(Char)
            if not Root then
                continue
            end

            ----------------------------------------------------------------
            -- SEEING ITS OWN MIST
            ----------------------------------------------------------------

            for _, Cloud in GetActiveClouds(self) do
                for _, Target: Model in CombatUtils.GetFightersInRadius(Cloud.Position, Cloud.Radius, Char) do
                    Utils.Player.RevealPlayerAuraTo(self.Owner, Target, 1.2, Color3.fromRGB(180, 200, 255))
                end
            end

            ----------------------------------------------------------------
            -- INDISTINCT AT RANGE
            ----------------------------------------------------------------

            local Close = CombatUtils.GetClosestFighter(Root.Position, self.ClearRange, Char) ~= nil

            if not Close and not Faded then
                Faded = true
                CommonFunctions.ApplyEffect({
                    TargetHumanoid = self.OwnerProperties.Humanoid,
                    EffectSettings = {Name = "Invisibility", Level = self.FadeLevel, Duration = 600},
                    OverwriteExistingEffect = true,
                })

            elseif Close and Faded then
                Faded = false
                --[[
                    Only cleared if NOTHING ELSE is granting invisibility.

                    `Dissipate` applies a much stronger `Invisibility`, and clearing it here
                    because somebody walked within 30 studs would cancel the escape it was
                    being used for.
                ]]
                local Current = Utils.Instance.FindFirstChild(Char, "Effects.Invisibility", 0)
                if Current and Current.Value <= self.FadeLevel then
                    CommonFunctions.RemoveEffect(Char, "Invisibility")
                end
            end
        end
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Fog: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Fog",
        Quote = "You were already inside me.",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 1600,

        Role = "Stealth",
        Difficulty = 4,

        Origin = {
            TooltipText = "It was just weather, once.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            --- Barely there. It does not really have feet.
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        -- Unchanged from the original. It was correctly tuned: fragile, slow, and winning
        -- through information rather than numbers.
        Health = 1050,
        BaseSpeed = 10.6,
        SprintSpeedMultiplier = 25.5 / 10.6,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 115,
            StaminaDrain = 9,
            StaminaGain = 22,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 19,
                --- Inside its own mist. Everything it owns obeys this rule.
                MistDamage = 31,
                Cooldown = 2,
                Duration = 0.35,
                Delay = 0.12,
                --- Very wide, because inside a cloud it can't see properly either.
                HitboxSize = Vector3.new(9, 6, 5),
                HitboxOffset = CFrame.new(0, 0, -2.5),

                Behaviour = MistClawBehaviour,
            }),

            RollingBank = Ability.New({
                Name = "Rolling Bank",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 16,
                Duration = 0.8,

                Distance = 14,
                Radius = 20,
                CloudDuration = 14,
                SlowLevel = 2,

                UseSound = "rbxassetid://9046319808",
                Behaviour = RollingBankBehaviour,
            }),

            Dissipate = Ability.New({
                Name = "Dissipate",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 28,
                Duration = 5,

                InvisibilityLevel = 4,
                SpeedFactor = 1.3,
                DisableSlashOnPerform = true,

                UseSound = "rbxassetid://9118823103",
                Behaviour = DissipateBehaviour,
            }),

            Suffocate = Ability.New({
                Name = "Suffocate",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 30,
                Duration = 1,

                Damage = 42,
                SnareDuration = 2,

                UseSound = "rbxassetid://9125402735",
                Behaviour = SuffocateBehaviour,
            }),

            FogStep = Ability.New({
                Name = "Fog Step",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 10,
                Duration = 0.3,

                UseSound = "rbxassetid://9046319808",
                Behaviour = FogStepBehaviour,
            }),

            DenseAir = Ability.New({
                Name = "Dense Air",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                --- Inside this, it is perfectly visible.
                ClearRange = 30,
                --- Light. Level 1 of 5.
                FadeLevel = 1,

                ExtraInit = DenseAirInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(178, 190, 210)\">"..Fog.Config.Name.."</font>"
local Abilities = Fog.GameplayConfig.Abilities

Fog.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Fog.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Fog.Config.Quote.."\""},
    {
        Type = "Text",
        Text = {
            NameLabel.." barely deals damage. It wins by making the arena unreadable for everybody else while staying perfectly oriented inside its own mist.",
            "Every single thing it has is stronger inside a cloud it placed and close to worthless outside one — including its basic attack. Its whole game is deciding where the fight happens.",
            "Chase it away from its mist and it is the weakest character in the arena until the cooldowns come back.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Fog.Config.Role,
            "Difficulty: "..string.rep("★", Fog.Config.Difficulty)..string.rep("☆", 5 - Fog.Config.Difficulty),
            "Price: "..tostring(Fog.Config.Price).."$",
            "Health: "..tostring(Fog.GameplayConfig.Health),
            "Base Speed: "..tostring(Fog.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Fog.GameplayConfig.BaseSpeed * Fog.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "MIST CLAW"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds — <b>"..tostring(Abilities.Slash.MistDamage).." inside its own mist</b>.",
            "Very wide, and it hits everybody in the arc. Precision is not available to either side in a cloud.",
        },
    },

    {Type = "Header", Text = "ROLLING BANK  (Q)"},
    {
        Type = "Text",
        Text = {
            "A bank of mist "..tostring(Abilities.RollingBank.Radius).." studs across, lasting "..tostring(Abilities.RollingBank.CloudDuration).." seconds.",
            "Anyone inside is <b>Blinded</b> and <b>Slowed</b>, and their screen fogs over. "..NameLabel.." is not affected by its own.",
            "Cooldown: "..tostring(Abilities.RollingBank.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "DISSIPATE  (E)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Dissipate.Duration).." seconds as vapour: near-invisible, unreadable by auras, and 30% faster.",
            "<b>It cannot attack at all while dissipated</b>, and it is not invulnerable — it can still be hit by anybody who can work out where it is. There is a faint trail.",
            "Cooldown: "..tostring(Abilities.Dissipate.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "SUFFOCATE  (R)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Suffocate.Damage).." damage and a "..tostring(Abilities.Suffocate.SnareDuration).." second <b>Snare</b> to everybody standing in its mist — anywhere.",
            "It reaches nobody outside a cloud, and refunds itself if the clouds were empty.",
            "Cooldown: "..tostring(Abilities.Suffocate.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "FOG STEP  (F)"},
    {
        Type = "Text",
        Text = {
            "Steps from the cloud it is standing in to its furthest other cloud.",
            "Its only mobility, and it needs two banks out and to be inside one of them. It does not move around the arena; it moves around the terrain it made.",
            "Cooldown: "..tostring(Abilities.FogStep.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "DENSE AIR  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "It always sees everybody standing in its own mist, through the fog, through walls. Without this, blinding an area would be as bad for it as for you.",
            "It is also faintly indistinct at range — but perfectly visible to anybody within "..tostring(Abilities.DenseAir.ClearRange).." studs.",
        },
    },
}

return Fog
