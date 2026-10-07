local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Hitbox = require(ReplicatedStorage.Classes.Hitbox)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

--[=[
    HOLLOWMARK — an original killer, built for the free-for-all specifically.

    Design idea: every other killer picks a target. Hollowmark picks *several*, and gets
    stronger the more of them there are.

    Brand paints people. Reach teleports to whoever is branded. Collect damages every
    branded fighter at once, anywhere on the map, and its damage scales with how many
    are marked — so a lone duel is the worst possible situation for him and a chaotic
    four-way scrap is the best.

    In a game where everybody is fighting everybody, a killer who profits from crowds is
    the one character the mode couldn't have existed without.
]=]

local AbilityClient = require(ReplicatedStorage.Modules.AbilityClient)
local AbilityFX = require(ReplicatedStorage.Modules.AbilityFX)

--- The ledger's colour. One colour for everything this character does.
local LEDGER = Color3.fromRGB(255, 96, 208)

--------------------------------------------------------------------------------
-- ABILITY BEHAVIOURS
--------------------------------------------------------------------------------

--- Everyone currently carrying Hollowmark's brand.
local function GetBranded(exclude: Model?): {Model}
    local Branded = {}

    for _, Char: Model in workspace.Players:GetChildren() do
        if Char == exclude then
            continue
        end

        local Role = Char:FindFirstChild("Role")
        if not Role or Role.Value == "Spectator" or Char:GetAttribute("Dead") == true then
            continue
        end

        local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid or Humanoid.Health <= 0 then
            continue
        end

        if Utils.Instance.FindFirstChild(Char, "Effects.Marked", 0) then
            table.insert(Branded, Char)
        end
    end

    return Branded
end

--[=[
    SIGN (M1)

    Its basic attack, and the reason it is not just a generic swing.

    `Brand` APPLIES marks. This one MAINTAINS them: hitting somebody who is already branded
    renews their brand to full and does bonus damage, while hitting somebody clean does
    ordinary damage and nothing else.

    That closes a loop the character was missing. Before this pass its M1 was the shared
    default, so the only way to keep brands alive was to re-cast `Brand` on a thirteen second
    cooldown — which meant the marks expired during exactly the long multi-way fight the
    character is built to profit from. Now its sword is how it keeps the ledger open, and
    there is a real reason to be in melee on a character whose payoff is at range.

    It deliberately CANNOT create a brand. Only `Brand` does that.
]=]
local function SignBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.3, Lock = 0.6})
        return
    end

    local Root = self.OwnerProperties.HRP

    Sounds.PlaySound(self.UseSound, {Parent = Root, Volume = 0.6, MinPitch = 0.9, MaxPitch = 1.05})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        -- A stroke of ink in the air, rather than a sword flash.
        local Centre = Root.Position + Root.CFrame.LookVector * 3
        AbilityFX.Beam(
            Centre - Root.CFrame.RightVector * 3 + Vector3.new(0, 1, 0),
            Centre + Root.CFrame.RightVector * 3 - Vector3.new(0, 1, 0),
            LEDGER,
            {Width = 0.6, Duration = 0.22, Transparency = 0.1}
        )

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Sign",
            ExecuteOnKill = true,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    if not Victim or not Victim:IsA("Model") then
                        return
                    end

                    local VictimRoot = Utils.Character.GetRootPart(Victim)
                    local Branded = Utils.Instance.FindFirstChild(Victim, "Effects.Marked", 0)

                    if not Branded then
                        -- Clean target. An ordinary hit; the brand has to come from `Brand`.
                        if VictimRoot then
                            AbilityFX.Sparks(VictimRoot.Position, LEDGER, 6, 12)
                        end
                        return
                    end

                    --[[
                        Already branded: RENEW it, and hit harder.

                        Renewed to the brand's full duration rather than extended by a few
                        seconds, because the engine does not expose how long is left on a
                        running effect — the `NumberValue` carries its total `Duration` as an
                        attribute, not a countdown. Reading the total and adding to it would
                        compound on every swing, so renewal is both the honest reading and
                        the safer one: a signed brand goes back to full and no further.
                    ]]
                    local Full = Branded:GetAttribute("Duration") or self.RenewTo
                    CombatUtils.ApplyEffectTo(Victim, "Marked", 1, math.max(Full, self.RenewTo))

                    CommonFunctions.DamagePlayer({
                        SourcePlayer = self.Owner,
                        TargetHumanoid = humanoid,
                        Damage = self.BrandedBonus,
                        Reason = "Signed",
                    })

                    if VictimRoot then
                        AbilityFX.Burst(VictimRoot.Position, 5, LEDGER, {Duration = 0.3})
                        AbilityFX.Text(VictimRoot.Position + Vector3.new(0, 5, 0), "signed", LEDGER, 0.9)
                    end
                end,
            },
        })
    end)
end

--[=[
    THE LEDGER (PASSIVE)

    The character profits from crowds, so the passive pays it for having a crowd branded.

    One stack per live brand, capped at four: +5% speed each, so a Hollowmark in the middle of
    a four-way scrap is 20% faster than one in a duel. That is the character's thesis written
    as a stat — and it is the right shape, because `Collect` already scales with brand count
    and the only thing it was missing was a reason to go and GET the crowd rather than hang
    back waiting for one.

    It also keeps every branded fighter revealed to it continuously. `Marked` already reveals
    its victims to everybody, so this is not new information for anyone else — it is just
    reliable rather than depending on who last applied the mark.

    One loop at 2 Hz. Nothing per frame.
]=]
local function LedgerInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    local PlayerSpeedManager = require(ServerScriptService.Managers.PlayerManager.PlayerSpeedManager)

    self:AddConnection(task.spawn(function()
        local Applied = -1

        while Char and Char.Parent do
            task.wait(0.5)

            local Branded = GetBranded(Char)
            local Stacks = math.min(#Branded, self.MaximumStacks)

            -- Only written when it actually changes: every speed factor write recalculates
            -- the player's walk speed, and doing that twice a second for no reason is waste.
            if Stacks ~= Applied then
                Applied = Stacks
                PlayerSpeedManager.AddSpeedFactor(self.Owner, "Ledger", 1 + self.SpeedPerMark * Stacks)
                Char:SetAttribute("HollowmarkBrands", Stacks)
            end

            for _, Target: Model in Branded do
                Utils.Player.RevealPlayerAuraTo(self.Owner, Target, 1.2, LEDGER)
            end
        end
    end))
end

--[=[
    BRAND (Q)

    A cone that Marks everyone it touches. Almost no damage — the value is entirely in
    what the mark unlocks.
]=]
local function BrandBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.08, Duration = 0.4, Lock = 0.5})
        return
    end

    local Root = self.OwnerProperties.HRP

    Sounds.PlaySound(self.UseSound, {Parent = Root, Volume = 0.8})

    local Sigil = CombatUtils.MakePart({
        Name = "BrandVFX",
        Size = Vector3.new(self.ConeWidth, 6, self.Range),
        Color = Color3.fromRGB(255, 96, 208),
        Material = Enum.Material.Neon,
        Transparency = 0.8,
        CFrame = Root.CFrame * CFrame.new(0, 0, -self.Range / 2),
    })
    Sigil.Parent = CombatUtils.GetInGameFolder()
    Debris:AddItem(Sigil, 0.4)

    Hitbox.New(self.Owner, {
        CFrame = Root.CFrame * CFrame.new(0, 0, -self.Range / 2),
        Size = Vector3.new(self.ConeWidth, 6, self.Range),
        Time = 0.3,
        Damage = self.Damage,
        HitMultiple = true,
        PredictVelocity = false,
        Reason = "Brand",
        EffectsToApply = {
            {Name = "Marked", Level = 1, Duration = self.MarkDuration},
            {Name = "Fragile", Level = self.FragileLevel, Duration = self.MarkDuration},
        },
    })
end

--[=[
    REACH (E)

    Blinks to the branded fighter closest to the reticle, arriving behind them.

    Arriving *behind* matters — landing on top of somebody would just be a free hit,
    while landing behind them gives them a moment to turn and makes the ability a
    repositioning tool that opens a trade rather than winning one outright.
]=]
local function ReachBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Branded = GetBranded(Char)
    if #Branded <= 0 then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    -- Nearest brand wins. Predictable beats clever for a mobility tool.
    local Target, Closest
    for _, Candidate: Model in Branded do
        local CandidateRoot = Utils.Character.GetRootPart(Candidate)
        if not CandidateRoot then
            continue
        end

        local Distance = (CandidateRoot.Position - Root.Position).Magnitude
        if Distance > self.Range then
            continue
        end

        if not Closest or Distance < Closest then
            Closest = Distance
            Target = Candidate
        end
    end

    if not Target then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    local TargetRoot = Utils.Character.GetRootPart(Target)

    Sounds.PlaySound(self.UseSound, {Position = Root.Position, Volume = 0.8})

    -- Arrive behind them, facing their back.
    local Arrival = (TargetRoot.CFrame * CFrame.new(0, 0, self.ArriveOffset)).Position

    if not CombatUtils.Blink(Char, Arrival) then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    -- Face the target properly — `Blink` keeps the old facing, which would leave him
    -- staring away from the person he just teleported to.
    local NewRoot = Utils.Character.GetRootPart(Char)
    if NewRoot then
        Char:PivotTo(CFrame.new(NewRoot.Position, Vector3.new(TargetRoot.Position.X, NewRoot.Position.Y, TargetRoot.Position.Z)))
    end

    Sounds.PlaySound(self.ArriveSound, {Position = Arrival, Volume = 0.8})
end

--[=[
    COLLECT (R)

    Damages every branded fighter in the arena at once, no matter where they are.

    Damage per target scales with how many are branded, so this is worthless in a duel
    and devastating in a brawl. It also consumes the marks — you have to rebuild.
]=]
local function CollectBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 0.9)
        self:AddConnection(task.delay(1, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Branded = GetBranded(Char)

    if #Branded <= 0 then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    Sounds.PlaySound(self.UseSound, {Parent = self.OwnerProperties.HRP, Volume = 1})

    -- More brands out, more damage on each of them.
    local Damage = self.BaseDamage + self.DamagePerExtraMark * (#Branded - 1)

    for _, Target: Model in Branded do
        local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid then
            continue
        end

        CommonFunctions.DamagePlayer({
            SourcePlayer = self.Owner,
            TargetHumanoid = Humanoid,
            Damage = Damage,
            Reason = "Collect",
        })

        local TargetRoot = Utils.Character.GetRootPart(Target)
        if TargetRoot then
            local Burst = CombatUtils.MakePart({
                Name = "CollectVFX",
                Shape = Enum.PartType.Ball,
                Size = Vector3.one * 8,
                Color = Color3.fromRGB(255, 96, 208),
                Material = Enum.Material.Neon,
                Transparency = 0.4,
                CFrame = TargetRoot.CFrame,
            })
            Burst.Parent = CombatUtils.GetInGameFolder()
            Debris:AddItem(Burst, 0.5)
        end

        -- The brand is spent.
        CommonFunctions.RemoveEffect(Target, "Marked")
    end

    Utils.Misc.Print(("[Hollowmark] Collected %d brands for %d damage each"):format(#Branded, Damage))
end

--------------------------------------------------------------------------------
-- CHARACTER DEFINITION
--------------------------------------------------------------------------------

local Hollowmark: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Hollowmark",
        Quote = "I don't need to find you. I already signed you.",

        Role = "Controller",
        Difficulty = 4,
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 2000,

        Origin = {
            TooltipText = "Every name in the ledger is a debt.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },
    },

    GameplayConfig = {
        Health = 1150,
        BaseSpeed = 10.7,
        SprintSpeedMultiplier = 26 / 10.7,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 110,
            StaminaDrain = 10,
            StaminaGain = 21,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 21,
                Cooldown = 2,
                Duration = 0.35,
                Delay = 0.1,
                HitboxSize = Vector3.new(5, 6, 5),
                HitboxOffset = CFrame.new(0, 0, -2.6),

                --- Seconds a signed brand is renewed to. Matches `Brand.MarkDuration`.
                RenewTo = 14,
                --- Extra damage against somebody already branded.
                BrandedBonus = 9,

                Behaviour = SignBehaviour,
            }),

            Brand = Ability.New({
                Name = "Brand",
                InputName = "FirstAbility",
                Cooldown = 13,
                Duration = 0.7,

                Range = 32,
                ConeWidth = 16,
                Damage = 6,
                MarkDuration = 14,
                FragileLevel = 2,

                UseSound = "rbxassetid://9046319808",
                Behaviour = BrandBehaviour,
            }),

            Reach = Ability.New({
                Name = "Reach",
                InputName = "SecondAbility",
                Cooldown = 17,
                Duration = 0.5,

                Range = 150,
                --- Positive Z is behind the target's facing.
                ArriveOffset = 6,

                UseSound = "rbxassetid://9118823103",
                ArriveSound = "rbxassetid://9125402735",
                Behaviour = ReachBehaviour,
            }),

            Collect = Ability.New({
                Name = "Collect",
                InputName = "ThirdAbility",
                Cooldown = 55,
                Duration = 1.2,

                BaseDamage = 30,
                --- Added to every target's damage for each brand out beyond the first.
                DamagePerExtraMark = 18,

                UseSound = "rbxassetid://9083889906",
                Behaviour = CollectBehaviour,
            }),

            Ledger = Ability.New({
                Name = "The Ledger",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                --- Speed per brand currently out, capped by `MaximumStacks`.
                SpeedPerMark = 0.05,
                MaximumStacks = 4,

                ExtraInit = LedgerInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(255, 120, 214)\">"..Hollowmark.Config.Name.."</font>"
local Abilities = Hollowmark.GameplayConfig.Abilities

--- Damage table worked out from the real numbers so it can't drift.
local function CollectDamageAt(marks: number): number
    return Abilities.Collect.BaseDamage + Abilities.Collect.DamagePerExtraMark * (marks - 1)
end

Hollowmark.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Hollowmark.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Hollowmark.Config.Quote.."\""},
    {
        Type = "Text",
        Text = NameLabel.." keeps a ledger, and everyone in the arena is eventually on it. "..
            "It brands from a distance, steps to whoever it branded, and calls the whole list in at once. "..
            "One-on-one it is the weakest killer here. "..
            "Surrounded by four people who are all busy fighting each other, it is the strongest thing in the building.",
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Hollowmark.Config.Role,
            "Difficulty: "..string.rep("★", Hollowmark.Config.Difficulty)..string.rep("☆", 5 - Hollowmark.Config.Difficulty),
            "Health: "..tostring(Hollowmark.GameplayConfig.Health),
            "Base Speed: "..tostring(Hollowmark.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Hollowmark.GameplayConfig.BaseSpeed * Hollowmark.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
            "Max Stamina: "..tostring(Hollowmark.GameplayConfig.StaminaProperties.MaxStamina),
            "Stamina Loss per second: "..tostring(Hollowmark.GameplayConfig.StaminaProperties.StaminaDrain),
            "Stamina Gain per second: "..tostring(Hollowmark.GameplayConfig.StaminaProperties.StaminaGain),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "SIGN"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds — and "..tostring(Abilities.Slash.Damage + Abilities.Slash.BrandedBonus).." against somebody already <b>Marked</b>.",
            "Hitting a branded fighter <b>renews their brand to full</b>. It is how the ledger stays open without spending <b>Brand</b> again, and the reason to be in melee on a character whose payoff is at range.",
            "It cannot create a brand. Only <b>Brand</b> does that.",
        },
    },

    {Type = "Header", Text = Abilities.Brand.Name:upper()},
    {
        Type = "Text",
        Text = {
            "A "..tostring(Abilities.Brand.Range).." stud cone that deals only "..tostring(Abilities.Brand.Damage).." damage.",
            "Everyone hit is <b>Marked</b> and <b>Fragile "..Utils.Math.IntToRoman(Abilities.Brand.FragileLevel).."</b> for "..tostring(Abilities.Brand.MarkDuration).." seconds.",
            "Marked fighters are visible to the entire arena — including everybody who isn't "..NameLabel..".",
        },
    },

    {Type = "Header", Text = Abilities.Reach.Name:upper()},
    {
        Type = "Text",
        Text = {
            NameLabel.." steps to the nearest <b>Marked</b> fighter within "..tostring(Abilities.Reach.Range).." studs, arriving behind them.",
            "Useless with nobody branded — the cooldown is refunded if there's no target.",
        },
    },

    {Type = "Header", Text = Abilities.Collect.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Every <b>Marked</b> fighter in the arena takes damage at once, wherever they are. Walls don't matter.",
            "Damage scales with the number of brands out: "..tostring(CollectDamageAt(1)).." against one, "..
                tostring(CollectDamageAt(2)).." each against two, "..tostring(CollectDamageAt(3)).." each against three, "..
                tostring(CollectDamageAt(4)).." each against four.",
            "All brands are consumed. They have to be rebuilt from scratch.",
        },
    },

    {Type = "Header", Text = "THE LEDGER  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "+5% speed for every live brand, up to "..tostring(Abilities.Ledger.MaximumStacks)..". In a four-way scrap it is 20% faster than it is in a duel.",
            "Every branded fighter stays revealed to it, reliably, for as long as the brand lasts.",
            "The character profits from crowds, so the passive pays it for going and getting one.",
        },
    },
}

return Hollowmark
