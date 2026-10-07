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
    SHADOW — Faster than anything else here and it hits like it isn't. The closest thing on the roster to no weakness at all.
]=]

--------------------------------------------------------------------------------
-- ABILITY BEHAVIOURS
--------------------------------------------------------------------------------

--[=[
    CHAOS SPEAR (Q)

    The fastest projectile in the game.
]=]
local function ChaosSpearBehaviour(self: Types.Ability)
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

    local Origin = Root.Position + Root.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)
    local Direction = Root.CFrame.LookVector

    local Shot = CombatUtils.MakePart({
        Name = self.Name.."Projectile",
        Shape = Enum.PartType.Ball,
        Size = Vector3.one * 3,
        CFrame = CFrame.new(Origin),
        Color = self.Colour,
        Material = Enum.Material.Neon,
        Transparency = 0.1,
    })
    Shot.Parent = CombatUtils.GetInGameFolder()
    Debris:AddItem(Shot, 8)

    -- Raw `task.spawn`: the shot has to finish its flight and clean itself up even if the
    -- thrower dies the instant after releasing it.
    task.spawn(function()
        local Travelled = 0

        while Travelled < self.Range and Shot.Parent do
            local Step = task.wait()
            Travelled += self.Speed * Step
            Shot.CFrame += Direction * (self.Speed * Step)

            if #CombatUtils.GetFightersInRadius(Shot.Position, self.Radius, Char) > 0 then
                -- Detonates on contact.
                if not Shot.Parent then
                    return
                end

                CombatUtils.Burst(Shot.Position, self.Radius, self.Colour)

                for _, Target: Model in CombatUtils.GetFightersInRadius(Shot.Position, self.Radius, Char) do
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

                    CombatUtils.ApplyEffectTo(Target, "Fragile", 2, 5)
                end

                Shot:Destroy()
                return
            end
        end

        if Shot.Parent then
            Shot:Destroy()
        end
    end)
end

--[=[
    CHAOS CONTROL (E)

    Stops on the far side of the nearest fighter, ninety studs away if it needs to be.
    Everyone near the landing is rooted and slowed.
]=]
local function ChaosControlBehaviour(self: Types.Ability)
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

    local Target = CombatUtils.GetClosestFighter(Root.Position, self.Range, Char)
    if not Target then
        --[[
            Nothing in range to jump to. Refund the cast rather than eating a long
            cooldown for an ability that did nothing.

            `ChangeCooldown` doesn't exist on `Ability` — the flags `SetOnCooldown` sets
            are `OnCooldown` and `CooldownTimer`, so clearing those two IS the refund.
        ]]
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    local TargetRoot = Utils.Character.GetRootPart(Target)
    if not TargetRoot then
        return
    end

    -- Land just behind them. `CombatUtils.Blink` refuses hops over 400 studs, because the
    -- anti-cheat kills anyone who moves further than that in a single frame.
    CombatUtils.Blink(Char, TargetRoot.Position - TargetRoot.CFrame.LookVector * 5)
    CombatUtils.Burst(TargetRoot.Position, 10, self.Colour)

    for _, Near: Model in CombatUtils.GetFightersInRadius(TargetRoot.Position, 14, Char) do
        local Humanoid = Near:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid then
            continue
        end

        CommonFunctions.DamagePlayer({
            SourcePlayer = self.Owner,
            TargetHumanoid = Humanoid,
            Damage = self.Damage,
            Reason = self.Name,
        })

        CombatUtils.ApplyEffectTo(Near, "Snared", 3, 2.5)
        CombatUtils.ApplyEffectTo(Near, "Slowness", 3, 4)
    end
end

--[=[
    CHAOS BLAST (R)

    Forty-two studs. One of the largest blasts on the roster.
]=]
local function ChaosBlastBehaviour(self: Types.Ability)
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

        CombatUtils.ApplyEffectTo(Target, "Fragile", 3, 8)
        CombatUtils.ApplyEffectTo(Target, "Blindness", 1, 3)
    end
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Shadow: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Shadow",
        Quote = "this is who i am",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 13000,

        Origin = {
            TooltipText = "Faster than anything else here and it hits like it isn't. Also the thinnest thing in the arena that is not a skeleton — catch him once and he is gone.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },
    },

    GameplayConfig = {
        --[[
            BALANCE PASS — HEALTH, 1420 -> 1100.

            Shadow was simultaneously in the roster's upper quartile for health, footspeed
            AND sustained basic-attack damage, which is the exact "no obvious weakness"
            combination the balance brief rules out.

            Speed is his whole identity — his own tooltip leads with it — and a 26 damage
            swing on a 1.6 second cycle is the "hits like it isn't" half of that sentence,
            so neither of those was the right lever. Durability was. He is now a glass
            cannon: the fastest killer in the game and among the easiest to kill once
            something actually corners him.
        ]]
        Health = 1100,
        BaseSpeed = 12.4,
        SprintSpeedMultiplier = 30 / 12.4,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 100,
            StaminaDrain = 12,
            StaminaGain = 20,
        },

        Abilities = {
            Slash = require(ReplicatedStorage.Classes.Ability.Slash).New({
                Damage = 26,
                Cooldown = 1.6,
                Duration = 0.3,
            }),

            ChaosSpear = Ability.New({
                Name = "Chaos Spear",
                InputName = "FirstAbility",
                Cooldown = 9,
                Duration = 0.5,

                Colour = Color3.fromRGB(70, 70, 90),
                Speed = 160,
                Range = 95,
                Damage = 48,
                Radius = 10,

                UseSound = "rbxassetid://9125402735",
                Behaviour = ChaosSpearBehaviour,
            }),

            ChaosControl = Ability.New({
                Name = "Chaos Control",
                InputName = "SecondAbility",
                Cooldown = 18,
                Duration = 0.5,

                Colour = Color3.fromRGB(70, 70, 90),
                Range = 90,
                Damage = 40,

                UseSound = "rbxassetid://9046319808",
                Behaviour = ChaosControlBehaviour,
            }),

            ChaosBlast = Ability.New({
                Name = "Chaos Blast",
                InputName = "ThirdAbility",
                Cooldown = 50,
                Duration = 0.5,

                Colour = Color3.fromRGB(70, 70, 90),
                Radius = 42,
                Damage = 130,

                UseSound = "rbxassetid://9118823103",
                Behaviour = ChaosBlastBehaviour,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(70, 70, 90)\">"..Shadow.Config.Name.."</font>"
local Abilities = Shadow.GameplayConfig.Abilities

Shadow.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Shadow.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Shadow.Config.Quote.."\""},
    {
        Type = "Text",
        Text = NameLabel.." — Faster than anything else here and it hits like it isn't. The closest thing on the roster to no weakness at all.",
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Difficulty: ★★★★☆",
            "Price: "..tostring(Shadow.Config.Price).."$",
            "Health: "..tostring(Shadow.GameplayConfig.Health),
            "Base Speed: "..tostring(Shadow.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Shadow.GameplayConfig.BaseSpeed * Shadow.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = Abilities.Slash.Name:upper()},
    {
        Type = "Text",
        Text = NameLabel.." strikes for "..tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds.",
    },

    {Type = "Header", Text = Abilities.ChaosSpear.Name:upper()},
    {
        Type = "Text",
        Text = {
            "The fastest projectile in the game.",
            "Cooldown: "..tostring(Abilities.ChaosSpear.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = Abilities.ChaosControl.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Stops on the far side of the nearest fighter, ninety studs away if it needs to be.",
            "Everyone near the landing is rooted and slowed.",
            "Cooldown: "..tostring(Abilities.ChaosControl.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = Abilities.ChaosBlast.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Forty-two studs. One of the largest blasts on the roster.",
            "Cooldown: "..tostring(Abilities.ChaosBlast.Cooldown).." seconds.",
        },
    },
}

return Shadow
