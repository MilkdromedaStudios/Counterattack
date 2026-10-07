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
    PATRICK — Enormous, slow, and takes an absurd amount of punishment. Hits like a dropped rock, because that is essentially what it is.
]=]

--------------------------------------------------------------------------------
-- ABILITY BEHAVIOURS
--------------------------------------------------------------------------------

--[=[
    ROCK SLAM (Q)

    Brings something very heavy down on everyone nearby.
]=]
local function RockSlamBehaviour(self: Types.Ability)
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

        CombatUtils.ApplyEffectTo(Target, "Snared", 2, 2)
    end
end

--[=[
    BELLY FLOP (E)

    Launches up and lands flat. Everything under the landing takes all of it.
]=]
local function BellyFlopBehaviour(self: Types.Ability)
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

    Root.AssemblyLinearVelocity = Root.CFrame.LookVector * self.Power + Vector3.new(0, self.Height, 0)

    -- The landing is the attack. Wait out the arc, then hit everything underneath.
    self:AddStunnableConnection(task.delay(self.Duration, function()
        local LandRoot = Utils.Character.GetRootPart(Char)
        if not LandRoot then
            return
        end

        CombatUtils.Burst(LandRoot.Position, self.Radius, self.Colour)

        for _, Target: Model in CombatUtils.GetFightersInRadius(LandRoot.Position, self.Radius, Char) do
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


        end
    end))
end

--[=[
    UNDER THE ROCK (R)

    Hides. Heals 35% of maximum health and takes far less damage for seven seconds.
    Moves slowly while it lasts.
]=]
local function UnderTheRockBehaviour(self: Types.Ability)
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

    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.SpeedMul)

    CombatUtils.ApplyEffectTo(Char, "Resistance", self.Resist, self.Duration_)

    local SelfHumanoid = Char:FindFirstChildWhichIsA("Humanoid")
    if SelfHumanoid then
        SelfHumanoid.Health = math.min(SelfHumanoid.Health + SelfHumanoid.MaxHealth * self.Heal, SelfHumanoid.MaxHealth)
    end

    --[[
        A raw `task.delay`, NOT `self:AddConnection`. `AddConnection` hands the thread to
        this ability's Janitor, which cancels it when the character is destroyed — so dying
        inside the buff would leave a speed factor attached to a body that no longer exists.
        Cleanup that must happen has to outlive its caller.
    ]]
    task.delay(self.Duration_, function()
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
    end)
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Patrick: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Patrick",
        Quote = "is mayonnaise an instrument",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 3600,

        Origin = {
            TooltipText = "Enormous, slow, and takes an absurd amount of punishment. Hits like a ",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },
    },

    GameplayConfig = {
        Health = 1420,
        BaseSpeed = 9.6,
        SprintSpeedMultiplier = 22 / 9.6,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 100,
            StaminaDrain = 12,
            StaminaGain = 20,
        },

        Abilities = {
            Slash = require(ReplicatedStorage.Classes.Ability.Slash).New({
                Damage = 30,
                Cooldown = 2.3,
                Duration = 0.42,
            }),

            RockSlam = Ability.New({
                Name = "Rock Slam",
                InputName = "FirstAbility",
                Cooldown = 13,
                Duration = 0.5,

                Colour = Color3.fromRGB(255, 140, 170),
                Radius = 20,
                Damage = 42,

                UseSound = "rbxassetid://9125402735",
                Behaviour = RockSlamBehaviour,
            }),

            BellyFlop = Ability.New({
                Name = "Belly Flop",
                InputName = "SecondAbility",
                Cooldown = 20,
                Duration = 0.9,

                Colour = Color3.fromRGB(255, 140, 170),
                Power = 68,
                Height = 42,
                Damage = 48,
                Radius = 18,

                UseSound = "rbxassetid://9046319808",
                Behaviour = BellyFlopBehaviour,
            }),

            UnderTheRock = Ability.New({
                Name = "Under The Rock",
                InputName = "ThirdAbility",
                Cooldown = 48,
                Duration = 0.5,

                Colour = Color3.fromRGB(255, 140, 170),
                Duration_ = 7,
                Resist = 4,
                Heal = 0.35,
                SpeedMul = 0.75,

                UseSound = "rbxassetid://9118823103",
                Behaviour = UnderTheRockBehaviour,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(255, 140, 170)\">"..Patrick.Config.Name.."</font>"
local Abilities = Patrick.GameplayConfig.Abilities

Patrick.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Patrick.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Patrick.Config.Quote.."\""},
    {
        Type = "Text",
        Text = NameLabel.." — Enormous, slow, and takes an absurd amount of punishment. Hits like a dropped rock, because that is essentially what it is.",
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Difficulty: ★☆☆☆☆",
            "Price: "..tostring(Patrick.Config.Price).."$",
            "Health: "..tostring(Patrick.GameplayConfig.Health),
            "Base Speed: "..tostring(Patrick.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Patrick.GameplayConfig.BaseSpeed * Patrick.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = Abilities.Slash.Name:upper()},
    {
        Type = "Text",
        Text = NameLabel.." strikes for "..tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds.",
    },

    {Type = "Header", Text = Abilities.RockSlam.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Brings something very heavy down on everyone nearby.",
            "Cooldown: "..tostring(Abilities.RockSlam.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = Abilities.BellyFlop.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Launches up and lands flat. Everything under the landing takes all of it.",
            "Cooldown: "..tostring(Abilities.BellyFlop.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = Abilities.UnderTheRock.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Hides. Heals 35% of maximum health and takes far less damage for seven seconds.",
            "Moves slowly while it lasts.",
            "Cooldown: "..tostring(Abilities.UnderTheRock.Cooldown).." seconds.",
        },
    },
}

return Patrick
