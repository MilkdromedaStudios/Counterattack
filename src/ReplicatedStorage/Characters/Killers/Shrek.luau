local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

-- Server-only. This module is required on the client too, for the ability UI, and
-- `ServerScriptService` isn't reachable from there.
local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local PlayerSpeedManager = RunService:IsServer() and require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager) or nil

--[=[
    SHREK — Territorial. Everything it does is about making one piece of the map unbearable to stand in.
]=]

--------------------------------------------------------------------------------
-- ABILITY BEHAVIOURS
--------------------------------------------------------------------------------

--[=[
    OGRE ROAR (Q)

    A roar that blinds and staggers everything in thirty studs.
]=]
local function OgreRoarBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        -- Client half: a short lens punch so the cast has some weight to it.
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 1.1)
        self:AddConnection(task.delay(0.4, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    Sounds.PlaySound(self.UseSound, {Position = Root.Position, Volume = 0.85})

    local Origin = Root.Position
    CombatUtils.Burst(Origin, self.Radius, self.Colour)

    for _, Target: Model in CombatUtils.GetFightersInRadius(Origin, self.Radius, Char) do
        local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid then
            continue
        end

        CommonFunctions.DamagePlayer({
            SourcePlayer = self.Owner,
            TargetHumanoid = Humanoid,
            Damage = self.Damage,
            Reason = self.Name,
        })

        CombatUtils.ApplyEffectTo(Target, "Blindness", 1, 3)
        CombatUtils.ApplyEffectTo(Target, "Disoriented", 2, 4)
    end
end

--[=[
    SWAMP (E)

    Eighteen seconds of ground nobody else can move through properly.
]=]
local function SwampBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        -- Client half: a short lens punch so the cast has some weight to it.
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 1.1)
        self:AddConnection(task.delay(0.4, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    Sounds.PlaySound(self.UseSound, {Position = Root.Position, Volume = 0.85})

    CombatUtils.CreateZone({
        SourcePlayer = self.Owner,
        Position = Root.Position,
        Radius = self.Radius,
        Lifetime = self.Lifetime,
        TickRate = self.Tick,
        Damage = self.Damage,
        Color = self.Colour,
        Effects = {{Name = "Slowness", Level = 3, Duration = 2}, {Name = "Grounded", Level = 1, Duration = 3}},
    })
end

--[=[
    LAYERS (R)

    Fourteen seconds of heavily reduced damage and a 30% heal.
    STACKS with itself — cast it twice and it is very hard to kill.
]=]
local function LayersBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        -- Client half: a short lens punch so the cast has some weight to it.
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 1.1)
        self:AddConnection(task.delay(0.4, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    Sounds.PlaySound(self.UseSound, {Position = Root.Position, Volume = 0.85})

    CombatUtils.ApplyEffectTo(Char, "Resistance", self.Resist, self.Duration_)

    local SelfHumanoid = Char:FindFirstChildWhichIsA("Humanoid")
    if SelfHumanoid then
        SelfHumanoid.Health = math.min(SelfHumanoid.Health + SelfHumanoid.MaxHealth * self.Heal, SelfHumanoid.MaxHealth)
    end
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Shrek: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Shrek",
        Quote = "get out of my swamp",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 12000,

        Origin = {
            TooltipText = "Territorial. Everything it does is about making one piece of the map u",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },
    },

    GameplayConfig = {
        Health = 1650,
        BaseSpeed = 10.2,
        SprintSpeedMultiplier = 24 / 10.2,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 100,
            StaminaDrain = 12,
            StaminaGain = 20,
        },

        Abilities = {
            Slash = require(ReplicatedStorage.Classes.Ability.Slash).New({
                Damage = 34,
                Cooldown = 2.3,
                Duration = 0.42,
            }),

            OgreRoar = Ability.New({
                Name = "Ogre Roar",
                InputName = "FirstAbility",
                Cooldown = 13,
                Duration = 0.5,

                Colour = Color3.fromRGB(140, 190, 80),
                Radius = 30,
                Damage = 44,

                UseSound = "rbxassetid://9125402735",
                Behaviour = OgreRoarBehaviour,
            }),

            Swamp = Ability.New({
                Name = "Swamp",
                InputName = "SecondAbility",
                Cooldown = 26,
                Duration = 0.5,

                Colour = Color3.fromRGB(140, 190, 80),
                Radius = 34,
                Lifetime = 18,
                Tick = 0.9,
                Damage = 22,

                UseSound = "rbxassetid://9046319808",
                Behaviour = SwampBehaviour,
            }),

            Layers = Ability.New({
                Name = "Layers",
                InputName = "ThirdAbility",
                Cooldown = 42,
                Duration = 0.5,

                Colour = Color3.fromRGB(140, 190, 80),
                Duration_ = 14,
                Resist = 5,
                Heal = 0.3,

                UseSound = "rbxassetid://9118823103",
                Behaviour = LayersBehaviour,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(140, 190, 80)\">"..Shrek.Config.Name.."</font>"
local Abilities = Shrek.GameplayConfig.Abilities

Shrek.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Shrek.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Shrek.Config.Quote.."\""},
    {
        Type = "Text",
        Text = NameLabel.." — Territorial. Everything it does is about making one piece of the map unbearable to stand in.",
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Difficulty: ★★☆☆☆",
            "Price: "..tostring(Shrek.Config.Price).."$",
            "Health: "..tostring(Shrek.GameplayConfig.Health),
            "Base Speed: "..tostring(Shrek.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Shrek.GameplayConfig.BaseSpeed * Shrek.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = Abilities.Slash.Name:upper()},
    {
        Type = "Text",
        Text = NameLabel.." strikes for "..tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds.",
    },

    {Type = "Header", Text = Abilities.OgreRoar.Name:upper()},
    {
        Type = "Text",
        Text = {
            "A roar that blinds and staggers everything in thirty studs.",
            "Cooldown: "..tostring(Abilities.OgreRoar.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = Abilities.Swamp.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Eighteen seconds of ground nobody else can move through properly.",
            "Cooldown: "..tostring(Abilities.Swamp.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = Abilities.Layers.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Fourteen seconds of heavily reduced damage and a 30% heal.",
            "STACKS with itself — cast it twice and it is very hard to kill.",
            "Cooldown: "..tostring(Abilities.Layers.Cooldown).." seconds.",
        },
    },
}

return Shrek
