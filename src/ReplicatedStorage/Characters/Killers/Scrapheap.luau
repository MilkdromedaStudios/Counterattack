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
local DeployableService = require(ReplicatedStorage.Modules.DeployableService)
local ProjectileService = require(ReplicatedStorage.Modules.ProjectileService)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    SCRAPHEAP — an original killer. A resource you spend, not a cooldown you wait on.

    Design idea: a stacking meter that is simultaneously his defence and his ammunition.

    Plates make him tougher and slower. Shrapnel spends a plate to fire debris. Collapse
    dumps every plate at once for damage proportional to how many he'd been hoarding.

    That creates a real decision every few seconds: keep the armour and survive, or spend
    it and threaten. A Scrapheap sitting on eight plates is nearly unkillable and nearly
    harmless, and everyone in the arena can see exactly how many he has.
]=]

--- Attribute name the plate count lives under, so the client can read it too.
local PLATE_ATTRIBUTE = "ScrapPlates"

--------------------------------------------------------------------------------
-- SHARED
--------------------------------------------------------------------------------

--- Re-applies the Resistance and speed penalty that match the current plate count.
local function ApplyPlateEffects(self: Types.Ability, char: Model, plates: number)
    if not RunService:IsServer() then
        return
    end

    local Player = self.Owner
    local Humanoid = char:FindFirstChildWhichIsA("Humanoid")
    if not Humanoid then
        return
    end

    char:SetAttribute(PLATE_ATTRIBUTE, plates)

    if plates <= 0 then
        CommonFunctions.RemoveEffect(char, "Resistance")
        PlayerSpeedManager.RemoveSpeedFactor(Player, "ScrapPlates")
        return
    end

    -- Resistance is read by `CommonFunctions.DamagePlayer` as `damage / (1 + 0.1 * level)`.
    CommonFunctions.ApplyEffect({
        TargetHumanoid = Humanoid,
        EffectSettings = {
            Name = "Resistance",
            Level = plates,
            -- Long duration; the plate count is what actually governs this, not a timer.
            Duration = 3600,
        },
        OverwriteExistingEffect = true,
    })

    -- Every plate costs mobility. Eight plates is a walking wall.
    PlayerSpeedManager.AddSpeedFactor(Player, "ScrapPlates", math.max(0.5, 1 - 0.05 * plates))
end

--------------------------------------------------------------------------------
-- ABILITY BEHAVIOURS
--------------------------------------------------------------------------------

--[=[
    PLATE UP (Q)

    Adds a plate, up to `MaxPlates`. Each one is Resistance and a movement penalty.
]=]
--- Rust. One colour for everything this character does.
local SCRAP = Color3.fromRGB(150, 110, 80)
local METAL = Color3.fromRGB(170, 175, 185)

--[=[
    SCRAP SLAM (M1)

    Its own basic attack rather than the shared default, and it reads the plate count like
    everything else it owns: a flat base plus a bonus per plate.

    That closes the character's loop. The plate economy already governed its defence
    (`Plate Up`), its ranged poke (`Shrapnel`) and its payoff (`Collapse`) -- but not the
    thing it does constantly, so hoarding plates made it tougher and no more threatening
    moment to moment. Now a Scrapheap sitting on eight plates hits hard with every swing, and
    the decision to spend them is a real one.

    It is slow and short-ranged, because its arms are made of other people's wreckage.
]=]
local function SlamBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.35, Lock = 0.7, Shake = 0.6, ShakeTime = 0.25})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Plates = Char:GetAttribute(PLATE_ATTRIBUTE) or 0
    local Damage = self.Damage + self.DamagePerPlate * Plates

    Sounds.PlaySound(self.UseSound, {Parent = Root, Volume = 0.7, MinPitch = 0.7, MaxPitch = 0.85})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        local Impact = Root.Position + Root.CFrame.LookVector * 3.5
        AbilityFX.Sparks(Impact, METAL, 8 + Plates * 2, 18)

        local Ground = AbilityFX.GroundAt(Impact, {Char})
        if Ground then
            AbilityFX.Ring(Ground, 5 + Plates * 0.5, SCRAP, {Duration = 0.35, Thickness = 0.6})
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = Damage,
            Reason = "Scrap Slam",
            ExecuteOnKill = true,
            Knockback = self.Knockback,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, METAL, 10, 16)
                        AbilityFX.ShakeFor(Victim, 2.5 + Plates * 0.2, 0.35)
                    end
                end,
            },
        })
    end)
end

--[=[
    MAGNET PULL (F)

    Drags loose metal -- and people -- toward it.

    Three things at once, in priority order, which is what makes it a scavenger's ability
    rather than just another pull:

      1. DEPLOYABLES in range are destroyed, and each one becomes A PLATE. This is the
         `Salvage` loop: Builderman's sentry, Piggy's trap, Steve's blocks and Huggy's vent
         are all raw material. It is the only way in the game to convert somebody else's
         setup directly into your own defence.
      2. PROJECTILES in range are pulled out of the air and destroyed, which is a real
         answer to the roster's shooters.
      3. FIGHTERS are dragged a short distance toward it. Modest, and never past it.

    The plate conversion is capped by `MaxPlates` like everything else, so a field full of
    somebody's equipment is worth a lot and not unlimited.
]=]
local function MagnetBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.9, Duration = 0.5, Lock = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Origin = Root.Position

    local PlateUp = self.CharModule.GameplayConfig.Abilities.PlateUp

    Sounds.PlaySound(self.UseSound, {Position = Origin, Volume = 0.9, RollOffMaxDistance = 160})
    AbilityFX.Ring(Origin, self.Radius, METAL, {Duration = 0.6, Thickness = 1.2, Transparency = 0.5})

    -- Filings streaming inward, which is what makes it read as magnetism.
    for Index = 1, 8 do
        local Angle = (Index / 8) * math.pi * 2
        local Edge = Origin + Vector3.new(math.cos(Angle) * self.Radius, 1, math.sin(Angle) * self.Radius)
        AbilityFX.Beam(Edge, Origin + Vector3.new(0, 1, 0), METAL, {
            Width = 0.3,
            Duration = 0.4,
            Transparency = 0.4,
        })
    end

    local Salvaged = 0

    ----------------------------------------------------------------------------
    -- 1. STRUCTURES BECOME PLATES
    ----------------------------------------------------------------------------

    for _, Handle in DeployableService.GetInRadius(Origin, self.Radius, self.Owner) do
        if not Handle.Alive or not Handle.Root then
            continue
        end

        AbilityFX.Beam(Handle.Root.Position, Origin + Vector3.new(0, 1, 0), SCRAP, {
            Width = 0.8,
            Duration = 0.35,
            Transparency = 0.2,
        })
        AbilityFX.Sparks(Handle.Root.Position, METAL, 12, 20)

        Handle:Destroy()
        Salvaged += 1
    end

    if Salvaged > 0 and PlateUp then
        local Current = Char:GetAttribute(PLATE_ATTRIBUTE) or 0
        local Plates = math.min(Current + Salvaged, PlateUp.MaxPlates)

        -- Reuses the character's own plate function, so the Resistance, the speed penalty
        -- and the visible plate parts are all applied exactly as `Plate Up` does them.
        ApplyPlateEffects(PlateUp, Char, Plates)

        AbilityFX.Text(Origin + Vector3.new(0, 6, 0), "SALVAGED +"..tostring(Plates - Current), SCRAP, 1.4)
    end

    ----------------------------------------------------------------------------
    -- 2. PROJECTILES OUT OF THE AIR
    ----------------------------------------------------------------------------

    local Caught = ProjectileService.Consume(Origin, self.Radius, self.Owner)
    if Caught > 0 then
        AbilityFX.Sparks(Origin, METAL, 16, 24)
        AbilityFX.Text(Origin + Vector3.new(0, 5, 0), "caught "..tostring(Caught), METAL, 1.1)
    end

    ----------------------------------------------------------------------------
    -- 3. PEOPLE
    ----------------------------------------------------------------------------

    for _, Target: Model in CombatUtils.GetFightersInRadius(Origin, self.Radius, Char) do
        local TargetHumanoid = Target:FindFirstChildWhichIsA("Humanoid")
        local TargetRoot = Utils.Character.GetRootPart(Target)
        if not TargetHumanoid or not TargetRoot then
            continue
        end

        CommonFunctions.DamagePlayer({
            SourcePlayer = self.Owner,
            TargetHumanoid = TargetHumanoid,
            Damage = self.Damage,
            Reason = self.Name,
        })

        -- A short drag, stopping well short of it.
        local Delta = Origin - TargetRoot.Position
        local Travel = math.min(self.Pull, math.max(Delta.Magnitude - 8, 0))

        if Travel > 0.5 then
            CombatUtils.Blink(Target, TargetRoot.Position + Delta.Unit * Travel)
        end

        AbilityFX.ShakeFor(Target, 1.5, 0.3)
    end

    if Salvaged <= 0 and Caught <= 0 then
        -- Nothing to scavenge. Refund most of it rather than charging full price for a
        -- short pull.
        self.OnCooldown = false
        self.CooldownTimer = 0
        self:SetOnCooldown(self.EmptyCooldown)
    end
end

--[=[
    SALVAGE (PASSIVE)

    Anything that breaks near it becomes material.

    One loop at 2 Hz watching for deployables inside `SalvageRange` that have fallen below a
    sliver of health, and converting them into plates when they go. It is the passive half
    of `Magnet Pull`: the magnet is how it takes equipment deliberately, and this is how it
    profits from equipment that somebody ELSE broke.

    In a free-for-all full of turrets, traps and walls, being the character who eats the
    wreckage is a genuine role -- and it is the reason this character wants to fight in the
    middle of other people's arguments.
]=]
local function SalvageInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    local PlateUp = self.CharModule.GameplayConfig.Abilities.PlateUp

    self:AddConnection(task.spawn(function()
        --- Deployables already counted, so one wreck cannot be salvaged twice.
        local Counted = {}

        while Char and Char.Parent do
            task.wait(0.5)

            local Root = Utils.Character.GetRootPart(Char)
            if not Root or not PlateUp then
                continue
            end

            for _, Handle in DeployableService.GetInRadius(Root.Position, self.SalvageRange, nil) do
                if Counted[Handle] then
                    continue
                end

                --[[
                    Counted when it is ABOUT to break rather than after.

                    A destroyed deployable is unregistered immediately, so by the time it is
                    gone there is nothing left to see. Watching for "nearly dead" catches it
                    while it still exists, and the `Counted` set stops the same wreck paying
                    out on every tick while it lingers.
                ]]
                if not Handle.Humanoid or Handle.Humanoid.Health > Handle.Humanoid.MaxHealth * 0.1 then
                    continue
                end

                Counted[Handle] = true

                local Current = Char:GetAttribute(PLATE_ATTRIBUTE) or 0
                if Current >= PlateUp.MaxPlates then
                    continue
                end

                ApplyPlateEffects(PlateUp, Char, Current + 1)

                if Handle.Root and Handle.Root.Parent then
                    AbilityFX.Beam(Handle.Root.Position, Root.Position + Vector3.new(0, 1, 0), SCRAP, {
                        Width = 0.6,
                        Duration = 0.4,
                        Transparency = 0.3,
                    })
                end
                AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "scrap", SCRAP, 0.9)
            end
        end
    end))
end

local function PlateUpBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    local Plates = math.min((Char:GetAttribute(PLATE_ATTRIBUTE) or 0) + 1, self.MaxPlates)

    Sounds.PlaySound(self.UseSound, {Parent = self.OwnerProperties.HRP, Volume = 0.75, MinPitch = 0.9, MaxPitch = 1.1})

    ApplyPlateEffects(self, Char, Plates)

    -- A visible chunk of junk bolted on, so opponents can count the plates by looking.
    local Root = self.OwnerProperties.HRP
    local Plate = CombatUtils.MakePart({
        Name = "ScrapPlate"..tostring(Plates),
        Size = Vector3.new(1.6, 1.2, 0.5),
        Color = Color3.fromRGB(120, 110, 96),
        Material = Enum.Material.CorrodedMetal,
        Transparency = 0,
    })

    -- Ring them around the torso so the count reads at a glance.
    local Angle = (Plates / self.MaxPlates) * math.pi * 2
    Plate.CFrame = Root.CFrame * CFrame.Angles(0, Angle, 0) * CFrame.new(0, 0, -2)
    Plate.Parent = Root

    local Weld = Instance.new("WeldConstraint")
    Weld.Part0 = Root
    Weld.Part1 = Plate
    Weld.Parent = Plate
    Plate.Anchored = false
    Plate.Massless = true
end

--[=[
    SHRAPNEL (E)

    Spends one plate to fire a spread of debris. With no plates it does nothing —
    the ammunition and the armour are the same resource.
]=]
local function ShrapnelBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Plates = Char:GetAttribute(PLATE_ATTRIBUTE) or 0

    if Plates <= 0 then
        -- No plates, no ammo. Refund so it isn't a trap button.
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    Sounds.PlaySound(self.UseSound, {Parent = Root, Volume = 0.9})

    -- Spend the plate before firing, so a plate can never be double-spent by a fast
    -- second press landing while this is still running.
    ApplyPlateEffects(self, Char, Plates - 1)

    local Shed = Root:FindFirstChild("ScrapPlate"..tostring(Plates))
    if Shed then
        Shed:Destroy()
    end

    Hitbox.New(self.Owner, {
        CFrame = Root.CFrame * CFrame.new(0, 0.5, -self.Range / 2),
        Size = Vector3.new(self.ConeWidth, 6, self.Range),
        Time = 0.3,
        Damage = self.Damage,
        Knockback = 5,
        HitMultiple = true,
        PredictVelocity = false,
        Reason = "Shrapnel",
        EffectsToApply = {
            {Name = "Fragile", Level = self.FragileLevel, Duration = self.FragileDuration},
        },
    })

    -- Debris cloud.
    for index = 1, 6 do
        local Fragment = CombatUtils.MakePart({
            Name = "ShrapnelVFX",
            Size = Vector3.new(0.4, 0.4, 0.8),
            Color = Color3.fromRGB(150, 140, 120),
            Material = Enum.Material.CorrodedMetal,
            CFrame = Root.CFrame * CFrame.new((index - 3.5) * 1.4, 0.5, -self.Range / 2),
        })
        Fragment.Parent = CombatUtils.GetInGameFolder()
        Debris:AddItem(Fragment, 0.25)
    end
end

--[=[
    COLLAPSE (R)

    Dumps every plate at once. Damage scales with how many were being carried, and he
    ends the ability with nothing — no armour, full speed, all of it spent.
]=]
local function CollapseBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 1.15)
        self:AddConnection(task.delay(1, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Plates = Char:GetAttribute(PLATE_ATTRIBUTE) or 0

    if Plates <= 0 then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    Sounds.PlaySound(self.UseSound, {Position = Root.Position, Volume = 1, RollOffMaxDistance = 120})

    local Damage = self.DamagePerPlate * Plates
    local Radius = self.BaseRadius + self.RadiusPerPlate * Plates

    Hitbox.New(self.Owner, {
        CFrame = Root.CFrame,
        Size = Vector3.one * (Radius * 2),
        Shape = Enum.PartType.Ball,
        Time = 0.3,
        Damage = Damage,
        Knockback = 20,
        HitMultiple = true,
        PredictVelocity = false,
        Reason = "Collapse",
        EffectsToApply = {
            {Name = "Fragile", Level = 3, Duration = 8},
        },
    })

    local Burst = CombatUtils.MakePart({
        Name = "CollapseVFX",
        Shape = Enum.PartType.Ball,
        Size = Vector3.one * (Radius * 2),
        Color = Color3.fromRGB(160, 145, 120),
        Material = Enum.Material.CorrodedMetal,
        Transparency = 0.5,
        CFrame = Root.CFrame,
    })
    Burst.Parent = CombatUtils.GetInGameFolder()
    Debris:AddItem(Burst, 0.45)

    -- Strip the armour, physically and mechanically.
    for _, Child in Root:GetChildren() do
        if Child.Name:find("ScrapPlate") then
            Child:Destroy()
        end
    end
    ApplyPlateEffects(self, Char, 0)

    Utils.Player.ShakeCameraOf(Utils.Player.GetLoadedPlayers(false), 1.1, 0.6)
end

--- Starts every match with a couple of plates already on, so Shrapnel isn't dead on spawn.
local function PlateUpExtraInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    task.defer(function()
        local Char = self.OwnerProperties.Character
        if Char and Char.Parent then
            ApplyPlateEffects(self, Char, self.StartingPlates)
        end
    end)
end

--------------------------------------------------------------------------------
-- CHARACTER DEFINITION
--------------------------------------------------------------------------------

local Scrapheap: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Scrapheap",
        Quote = "Built out of everyone who came before you.",

        Role = "Tank",
        Difficulty = 3,
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 1700,

        Origin = {
            TooltipText = "Assembled from whatever was left.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },
    },

    GameplayConfig = {
        Health = 1300,
        BaseSpeed = 10.2,
        SprintSpeedMultiplier = 24.5 / 10.2,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 115,
            StaminaDrain = 10,
            StaminaGain = 20,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://9046319808",
                UseAnimation = "rbxassetid://133504250023139",

                --- With no plates, poor. At eight plates, among the hardest swings here.
                Damage = 24,
                DamagePerPlate = 4,
                Cooldown = 2.3,
                Duration = 0.4,
                Delay = 0.18,
                HitboxSize = Vector3.new(5.5, 6, 5),
                HitboxOffset = CFrame.new(0, 0, -2.6),
                Knockback = 8,

                Behaviour = SlamBehaviour,
            }),

            PlateUp = Ability.New({
                Name = "Plate Up",
                InputName = "FirstAbility",
                Cooldown = 7,
                Duration = 0.6,

                MaxPlates = 8,
                StartingPlates = 2,

                UseSound = "rbxassetid://9083889906",
                DisableSlashOnPerform = false,

                ExtraInit = PlateUpExtraInit,
                Behaviour = PlateUpBehaviour,
            }),

            Shrapnel = Ability.New({
                Name = "Shrapnel",
                InputName = "SecondAbility",
                Cooldown = 6,
                Duration = 0.6,

                Range = 30,
                ConeWidth = 18,
                Damage = 26,
                FragileLevel = 2,
                FragileDuration = 6,

                UseSound = "rbxassetid://9046319808",
                Behaviour = ShrapnelBehaviour,
            }),

            Collapse = Ability.New({
                Name = "Collapse",
                InputName = "ThirdAbility",
                Cooldown = 50,
                Duration = 1.1,

                DamagePerPlate = 16,
                BaseRadius = 12,
                RadiusPerPlate = 2.5,

                UseSound = "rbxassetid://9125402735",
                Behaviour = CollapseBehaviour,
            }),

            Magnet = Ability.New({
                Name = "Magnet",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 20,
                --- Charged instead when it catches nothing. See the behaviour.
                EmptyCooldown = 6,
                Duration = 0.5,

                Radius = 26,
                Damage = 18,
                Pull = 7,

                UseSound = "rbxassetid://9046319808",
                Behaviour = MagnetBehaviour,
            }),

            Salvage = Ability.New({
                Name = "Salvage",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                SalvageRange = 40,

                ExtraInit = SalvageInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(186, 170, 140)\">"..Scrapheap.Config.Name.."</font>"
local Abilities = Scrapheap.GameplayConfig.Abilities

local MaxPlates = Abilities.PlateUp.MaxPlates
local MaxCollapseDamage = Abilities.Collapse.DamagePerPlate * MaxPlates
local MaxCollapseRadius = Abilities.Collapse.BaseRadius + Abilities.Collapse.RadiusPerPlate * MaxPlates
local MaxSpeedPenalty = math.round((1 - math.max(0.5, 1 - 0.05 * MaxPlates)) * 100)

Scrapheap.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Scrapheap.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Scrapheap.Config.Quote.."\""},
    {
        Type = "Text",
        Text = NameLabel.." carries its armour and its ammunition in the same pile, "..
            "which means every plate it bolts on is a shot it hasn't taken yet, and every shot it takes is armour it no longer has. "..
            "Hoard and you become almost impossible to kill and almost impossible to fear. "..
            "Spend and you hit like a truck with nothing left to hide behind. "..
            "Everyone can count your plates by looking at you.",
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Scrapheap.Config.Role,
            "Difficulty: "..string.rep("★", Scrapheap.Config.Difficulty)..string.rep("☆", 5 - Scrapheap.Config.Difficulty),
            "Health: "..tostring(Scrapheap.GameplayConfig.Health),
            "Base Speed: "..tostring(Scrapheap.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Scrapheap.GameplayConfig.BaseSpeed * Scrapheap.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
            "Max Stamina: "..tostring(Scrapheap.GameplayConfig.StaminaProperties.MaxStamina),
            "Stamina Loss per second: "..tostring(Scrapheap.GameplayConfig.StaminaProperties.StaminaDrain),
            "Stamina Gain per second: "..tostring(Scrapheap.GameplayConfig.StaminaProperties.StaminaGain),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "SCRAP SLAM"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage with no plates, plus <b>"..tostring(Abilities.Slash.DamagePerPlate).." per plate</b> — "..tostring(Abilities.Slash.Damage + Abilities.Slash.DamagePerPlate * MaxPlates).." at "..tostring(MaxPlates)..". Every "..tostring(Abilities.Slash.Cooldown).." seconds.",
            "Slow, short, and heavy. It is the one thing it does constantly, so the plate count now matters moment to moment rather than only when it spends them.",
        },
    },

    {Type = "Header", Text = Abilities.PlateUp.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Bolts on one plate, up to "..tostring(MaxPlates)..". It starts each match with "..tostring(Abilities.PlateUp.StartingPlates)..".",
            "Each plate grants a stack of <b>Resistance</b>, reducing all incoming damage.",
            "Each plate also costs movement speed — at "..tostring(MaxPlates).." plates it's about "..tostring(MaxSpeedPenalty).."% slower.",
            "The plates are physically visible on its body. Everyone can see how loaded it is.",
        },
    },

    {Type = "Header", Text = Abilities.Shrapnel.Name:upper()},
    {
        Type = "Text",
        Text = {
            "<b>Spends one plate</b> to fire debris across a "..tostring(Abilities.Shrapnel.Range).." stud cone for "..tostring(Abilities.Shrapnel.Damage).." damage.",
            "Everyone hit is <b>Fragile "..Utils.Math.IntToRoman(Abilities.Shrapnel.FragileLevel).."</b> for "..tostring(Abilities.Shrapnel.FragileDuration).." seconds.",
            "With no plates left it does nothing and refunds its cooldown.",
        },
    },

    {Type = "Header", Text = Abilities.Collapse.Name:upper()},
    {
        Type = "Text",
        Text = {
            "<b>Sheds every plate at once</b> in an explosion centred on itself.",
            tostring(Abilities.Collapse.DamagePerPlate).." damage per plate — up to "..tostring(MaxCollapseDamage).." at "..tostring(MaxPlates).." plates.",
            "The radius grows too: "..tostring(Abilities.Collapse.BaseRadius).." studs empty, up to "..tostring(math.round(MaxCollapseRadius)).." studs fully loaded.",
            "Everyone caught is left <b>Fragile III</b>.",
            "Afterwards it has no armour at all and has to start rebuilding.",
        },
    },

    {Type = "Header", Text = "MAGNET  (F)"},
    {
        Type = "Text",
        Text = {
            "Drags everything metal within "..tostring(Abilities.Magnet.Radius).." studs toward it, in three parts:",
            "<b>Structures are destroyed and become plates.</b> Somebody's sentry, trap, wall or vent is raw material — the only way in the game to turn another player's setup directly into your own armour.",
            "<b>Projectiles are pulled out of the air</b> and destroyed.",
            "<b>Fighters are dragged</b> "..tostring(Abilities.Magnet.Pull).." studs closer, for "..tostring(Abilities.Magnet.Damage).." damage.",
            "Cooldown: "..tostring(Abilities.Magnet.Cooldown).." seconds — only "..tostring(Abilities.Magnet.EmptyCooldown).." if it catches nothing.",
        },
    },

    {Type = "Header", Text = "SALVAGE  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Any structure that breaks within "..tostring(Abilities.Salvage.SalvageRange).." studs of it becomes <b>a plate</b> — whoever broke it.",
            "Magnet is how it takes equipment deliberately. This is how it profits from equipment somebody else destroyed, which is why it wants to be in the middle of other people's arguments.",
        },
    },
}

return Scrapheap
