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
    SPONGEBOB — Relentlessly cheerful and completely tireless. Wins by simply not stopping.
]=]

--------------------------------------------------------------------------------
-- ABILITY BEHAVIOURS
--------------------------------------------------------------------------------

--[=[
    BUBBLE BLAST (Q)

    A bubble that traps whoever it bursts on.
]=]
local function BubbleBlastBehaviour(self: Types.Ability)
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

                    CombatUtils.ApplyEffectTo(Target, "Snared", 2, 2.5)
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
    KARATE CHOP (E)

    Eight seconds of very fast, slightly stronger attacks.
]=]
local function KarateChopBehaviour(self: Types.Ability)
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

    Char:SetAttribute("AbilityDamageMultiplier", self.DamageMul)

    Char:SetAttribute("CooldownMultiplier", self.SlashCooldown)

    --[[
        A raw `task.delay`, NOT `self:AddConnection`. `AddConnection` hands the thread to
        this ability's Janitor, which cancels it when the character is destroyed — so dying
        inside the buff would leave a speed factor attached to a body that no longer exists.
        Cleanup that must happen has to outlive its caller.
    ]]
    task.delay(self.Duration_, function()
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
        if Char and Char.Parent then Char:SetAttribute("AbilityDamageMultiplier", nil) end
        if Char and Char.Parent then Char:SetAttribute("CooldownMultiplier", nil) end
    end)
end

--[=[
    JELLYFISH SWARM (R)

    Seven of them, for fourteen seconds. The largest swarm in the game.
]=]
local function JellyfishSwarmBehaviour(self: Types.Ability)
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

    local Folder = CombatUtils.GetInGameFolder()
    local Orbs = {}

    for Index = 1, self.Count do
        local Orb = CombatUtils.MakePart({
            Name = self.Name.."Orb",
            Shape = Enum.PartType.Ball,
            Size = Vector3.one * 2.4,
            Color = self.Colour,
            Material = Enum.Material.Neon,
            Transparency = 0.2,
        })
        Orb.Parent = Folder
        Orbs[Index] = Orb
    end

    --[[
        Raw `task.spawn`, deliberately NOT `AddStunnableConnection`. The orbs must be
        cleaned up even if the caster dies mid-cast; a cancelled thread would leave them
        floating in the arena for the rest of the round.
    ]]
    task.spawn(function()
        local Elapsed = 0
        local LastHit = {}

        while Elapsed < self.Duration_ do
            Elapsed += task.wait(0.15)

            local CurrentRoot = Utils.Character.GetRootPart(Char)
            if not CurrentRoot or not Char.Parent then
                break
            end

            for Index, Orb in Orbs do
                if not Orb.Parent then
                    continue
                end

                local Angle = Elapsed * 3 + (Index / self.Count) * math.pi * 2
                Orb.CFrame = CFrame.new(CurrentRoot.Position + Vector3.new(math.cos(Angle) * 9, 2, math.sin(Angle) * 9))

                for _, Target: Model in CombatUtils.GetFightersInRadius(Orb.Position, 6, Char) do
                    -- Each orb may only hit a given fighter once per second, or seven of
                    -- them at 0.15s intervals would delete somebody instantly.
                    local Key = tostring(Index).."_"..Target.Name
                    if LastHit[Key] and Elapsed - LastHit[Key] < 1 then
                        continue
                    end
                    LastHit[Key] = Elapsed

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
            end
        end

        for _, Orb in Orbs do
            if Orb.Parent then
                Orb:Destroy()
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local SpongeBob: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "SpongeBob",
        Quote = "I'M READY",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 11000,

        Origin = {
            TooltipText = "Relentlessly cheerful and completely tireless. Wins by simply not stop",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },
    },

    GameplayConfig = {
        Health = 1300,
        BaseSpeed = 11.4,
        SprintSpeedMultiplier = 27 / 11.4,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 100,
            StaminaDrain = 12,
            StaminaGain = 20,
        },

        Abilities = {
            Slash = require(ReplicatedStorage.Classes.Ability.Slash).New({
                Damage = 20,
                Cooldown = 1.4,
                Duration = 0.28,
            }),

            BubbleBlast = Ability.New({
                Name = "Bubble Blast",
                InputName = "FirstAbility",
                Cooldown = 9,
                Duration = 0.5,

                Colour = Color3.fromRGB(250, 230, 70),
                Speed = 105,
                Range = 70,
                Damage = 42,
                Radius = 14,

                UseSound = "rbxassetid://9125402735",
                Behaviour = BubbleBlastBehaviour,
            }),

            KarateChop = Ability.New({
                Name = "Karate Chop",
                InputName = "SecondAbility",
                Cooldown = 22,
                Duration = 0.5,

                Colour = Color3.fromRGB(250, 230, 70),
                Duration_ = 8,
                DamageMul = 1.3,
                SpeedMul = 1.25,
                SlashCooldown = 0.5,

                UseSound = "rbxassetid://9046319808",
                Behaviour = KarateChopBehaviour,
            }),

            JellyfishSwarm = Ability.New({
                Name = "Jellyfish Swarm",
                InputName = "ThirdAbility",
                Cooldown = 44,
                Duration = 0.5,

                Colour = Color3.fromRGB(250, 230, 70),
                Count = 7,
                Duration_ = 14,
                Damage = 22,
                Radius = 16,

                UseSound = "rbxassetid://9118823103",
                Behaviour = JellyfishSwarmBehaviour,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(250, 230, 70)\">"..SpongeBob.Config.Name.."</font>"
local Abilities = SpongeBob.GameplayConfig.Abilities

SpongeBob.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = SpongeBob.Config.Name:upper()},
    {Type = "Quote", Text = "\""..SpongeBob.Config.Quote.."\""},
    {
        Type = "Text",
        Text = NameLabel.." — Relentlessly cheerful and completely tireless. Wins by simply not stopping.",
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Difficulty: ★★★☆☆",
            "Price: "..tostring(SpongeBob.Config.Price).."$",
            "Health: "..tostring(SpongeBob.GameplayConfig.Health),
            "Base Speed: "..tostring(SpongeBob.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(SpongeBob.GameplayConfig.BaseSpeed * SpongeBob.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = Abilities.Slash.Name:upper()},
    {
        Type = "Text",
        Text = NameLabel.." strikes for "..tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds.",
    },

    {Type = "Header", Text = Abilities.BubbleBlast.Name:upper()},
    {
        Type = "Text",
        Text = {
            "A bubble that traps whoever it bursts on.",
            "Cooldown: "..tostring(Abilities.BubbleBlast.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = Abilities.KarateChop.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Eight seconds of very fast, slightly stronger attacks.",
            "Cooldown: "..tostring(Abilities.KarateChop.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = Abilities.JellyfishSwarm.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Seven of them, for fourteen seconds. The largest swarm in the game.",
            "Cooldown: "..tostring(Abilities.JellyfishSwarm.Cooldown).." seconds.",
        },
    },
}

return SpongeBob
