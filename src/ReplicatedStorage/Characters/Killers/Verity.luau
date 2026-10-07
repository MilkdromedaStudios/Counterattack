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
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

--[=[
    VERITY — the thing that knows what you did.

    Design idea: Verity is built entirely around the tension of *looking at it*.

    Its signature ability splits the arena in two by where people's cameras are pointing.
    Look at Verity and you're blinded — you saw something you shouldn't have. Look away
    and you're Marked, painted for the whole lobby. There is no correct answer, only a
    choice of which way you'd rather lose, and that's the whole character.

    Everything else feeds that: Mirrorstep teleports it to whoever it Marked, so looking
    away puts Verity in your face. The Reckoning turns marks into real damage. It plays
    as a killer that farms your instincts rather than your positioning.
]=]

--------------------------------------------------------------------------------
-- ABILITY BEHAVIOURS
--------------------------------------------------------------------------------

--[=[
    CONFESSION (Q)

    A scream that reads where everyone is looking.
      * Facing Verity  -> Blindness. You looked.
      * Facing away    -> Marked. You didn't, so now everyone knows where you are.
]=]
--- Verity's colour. One colour for everything it does.
local VERITY_COLOUR = Color3.fromRGB(255, 96, 208)

local function ConfessionBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        -- Lens punch on the caster so the scream has weight.
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 1.18)
        self:AddConnection(task.delay(0.45, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Origin = self.OwnerProperties.HRP.Position

    Sounds.PlaySound(self.UseSound, {
        Position = Origin,
        Volume = 0.85,
        RollOffMaxDistance = self.Radius + 30,
        RollOffMinDistance = 15,
    })

    local Blinded, MarkedCount = 0, 0

    for _, Target: Model in CombatUtils.GetFightersInRadius(Origin, self.Radius, Char) do
        -- Walls hide you from the scream entirely — it's a line-of-sight ability, so
        -- ducking behind cover is the actual counterplay rather than camera micro.
        local TargetRoot = Utils.Character.GetRootPart(Target)
        if not TargetRoot or not CombatUtils.HasLineOfSight(Origin, TargetRoot.Position, {Char, Target}) then
            continue
        end

        if CombatUtils.IsFacing(Target, Origin, 0.3) then
            CombatUtils.ApplyEffectTo(Target, "Blindness", 1, self.BlindDuration)
            Blinded += 1
        else
            CombatUtils.ApplyEffectTo(Target, "Marked", 1, self.MarkDuration)
            MarkedCount += 1
        end
    end

    Utils.Misc.Print(("[Verity] Confession blinded %d and marked %d"):format(Blinded, MarkedCount))
end

--[=[
    MIRRORSTEP (E)

    Swaps places with a Marked fighter anywhere in range. If nobody is Marked it can
    still be used at knife range on the closest fighter, so it isn't dead weight when
    Confession is on cooldown — just far shorter ranged.

    Whoever gets swapped is left Disoriented, because being somewhere else without
    having moved should cost them something.
]=]
local function MirrorstepBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        self.OwnerProperties.TurnToMoveDirection:AddHeadPreventionFactor(self.Name)
        self:AddConnection(task.delay(0.5, function()
            self.OwnerProperties.TurnToMoveDirection:RemoveHeadPreventionFactor(self.Name)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Origin = self.OwnerProperties.HRP.Position

    -- Prefer the closest Marked target at long range.
    local Chosen
    for _, Target: Model in CombatUtils.GetFightersInRadius(Origin, self.MarkedRange, Char) do
        if Utils.Instance.FindFirstChild(Target, "Effects.Marked", 0) then
            Chosen = Target
            break
        end
    end

    -- Nobody marked: fall back to whoever is close enough to grab.
    if not Chosen then
        Chosen = CombatUtils.GetClosestFighter(Origin, self.UnmarkedRange, Char)
    end

    if not Chosen then
        -- Refund the cooldown — nothing happened, so it shouldn't cost anything.
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    Sounds.PlaySound(self.UseSound, {Position = Origin, Volume = 0.8})

    if not CombatUtils.SwapPositions(Char, Chosen) then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    CombatUtils.ApplyEffectTo(Chosen, "Disoriented", 1, self.DisorientDuration)

    Sounds.PlaySound(self.ArriveSound, {Position = Utils.Character.GetRootPart(Char).Position, Volume = 0.8})
end

--[=[
    THE RECKONING (R)

    A window where Verity's slashes start applying Fragile, so every hit makes the next
    one land harder. Paired with Speed so it can actually reach people during it.

    Implemented as a character attribute the slash reads, rather than by swapping the
    slash's config out and back — attributes replicate, so the client's copy of the
    slash sees the same state the server's does with no extra networking.
]=]
local function ReckoningBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 1.1)
        self:AddConnection(task.delay(self.Duration, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    Char:SetAttribute("VerityReckoning", true)

    CommonFunctions.ApplyEffect({
        TargetHumanoid = self.OwnerProperties.Humanoid,
        EffectSettings = {
            Name = "Speed",
            Level = self.SpeedLevel,
            Duration = self.Duration,
        },
    })

    -- Everyone gets to see it coming. A power window that nobody can react to isn't
    -- a power window, it's an ambush — and Verity already has one of those.
    CombatUtils.RevealToEveryone(Char, self.Duration, Color3.fromRGB(255, 40, 90))

    self:AddConnection(task.delay(self.Duration, function()
        if Char and Char.Parent then
            Char:SetAttribute("VerityReckoning", false)
        end
    end))
end

--[=[
    VERDICT (M1)

    Its basic attack already had its own behaviour; this sharpens it so the swing belongs to
    the same idea as everything else the character does.

    It deals BONUS DAMAGE to anybody who has already been judged -- carrying either
    `Marked` or `Blindness`. Those are precisely the two outcomes of `Confession`, so
    whichever side of that no-win choice you landed on, the swing that follows punishes it.

    That is the character in one line. Confession asks an unanswerable question; Verdict
    collects on the answer. It still stacks `Fragile` during The Reckoning, as it did before.
]=]
local function VeritySlashBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.03, Duration = 0.3, Lock = 0.7})
        return
    end

    local Root = self.OwnerProperties.HRP

    Sounds.PlaySound(self.UseSound, {Parent = Root, Volume = 0.6, MinPitch = 0.9, MaxPitch = 1.05})

    local Empowered = self.OwnerProperties.Character:GetAttribute("VerityReckoning") == true

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        -- A clean vertical stroke, like something being struck off a list.
        local Centre = Root.Position + Root.CFrame.LookVector * 3
        AbilityFX.Beam(
            Centre + Vector3.new(0, 3, 0),
            Centre - Vector3.new(0, 2, 0),
            VERITY_COLOUR,
            {Width = 0.5, Duration = 0.2, Transparency = 0.1}
        )

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Verdict",
            ExecuteOnKill = true,
            EffectsToApply = Empowered and {
                {Name = "Fragile", Level = self.FragileLevel, Duration = self.FragileDuration},
            } or nil,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    if not Victim or not Victim:IsA("Model") then
                        return
                    end

                    local VictimRoot = Utils.Character.GetRootPart(Victim)

                    --[[
                        ALREADY JUDGED.

                        `Marked` and `Blindness` are exactly the two outcomes of
                        `Confession`, so this checks for either and pays out on both. The
                        bonus is a second damage call rather than a changed hitbox value
                        because the hitbox has already resolved by the time this callback
                        runs -- and it shows in the kill feed as its own line, which makes
                        the character legible to whoever just died to it.
                    ]]
                    local Judged = Utils.Instance.FindFirstChild(Victim, "Effects.Marked", 0)
                        or Utils.Instance.FindFirstChild(Victim, "Effects.Blindness", 0)

                    if Judged then
                        CommonFunctions.DamagePlayer({
                            SourcePlayer = self.Owner,
                            TargetHumanoid = humanoid,
                            Damage = self.JudgedBonus,
                            Reason = "Verdict (judged)",
                        })

                        if VictimRoot then
                            AbilityFX.Burst(VictimRoot.Position, 6, VERITY_COLOUR, {Duration = 0.3})
                            AbilityFX.Text(VictimRoot.Position + Vector3.new(0, 5, 0), "GUILTY", VERITY_COLOUR, 1)
                        end
                    elseif VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, VERITY_COLOUR, 6, 12)
                    end
                end,
            },
        })
    end)
end

--[=[
    WITNESS (PASSIVE)

    It knows who is looking at it.

    One loop at 2 Hz: anybody within `Range` who is FACING Verity with a clear line of sight
    is revealed to it continuously. Looking away stops it immediately.

    This is the character's thesis as a permanent condition rather than a cooldown. Its whole
    design is the tension of whether to look at it, and before this pass that tension only
    existed for the 1.1 seconds `Confession` was being cast. Now it is always true:
    watching Verity tells it where you are, and not watching it means not knowing where it is.

    It takes nothing away and deals no damage. It is purely the information half of the
    choice the character is built around.
]=]
local function WitnessInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    self:AddConnection(task.spawn(function()
        while Char and Char.Parent do
            task.wait(0.5)

            local Root = Utils.Character.GetRootPart(Char)
            if not Root then
                continue
            end

            for _, Target: Model in CombatUtils.GetFightersInRadius(Root.Position, self.Range, Char) do
                local TargetRoot = Utils.Character.GetRootPart(Target)
                if not TargetRoot then
                    continue
                end

                -- Facing it, and able to actually see it. Body facing rather than camera,
                -- because the camera is client-owned and would be trivially spoofable --
                -- the same reasoning as Enderman's stare.
                if not CombatUtils.IsFacing(Target, Root.Position, self.Tolerance) then
                    continue
                end
                if not CombatUtils.HasLineOfSight(TargetRoot.Position, Root.Position, {Target, Char}) then
                    continue
                end

                Utils.Player.RevealPlayerAuraTo(self.Owner, Target, 1.2, VERITY_COLOUR)
            end
        end
    end))
end

--------------------------------------------------------------------------------
-- CHARACTER DEFINITION
--------------------------------------------------------------------------------

local Verity: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Verity",
        Quote = "You already know what you did.",

        Role = "Disruptor",
        Difficulty = 4,
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 1450,

        Origin = {
            TooltipText = "A truth that grew teeth.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },
    },

    GameplayConfig = {
        Health = 1150,
        BaseSpeed = 10.8,
        SprintSpeedMultiplier = 26.5 / 10.8,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 105,
            StaminaDrain = 10.5,
            StaminaGain = 20,
        },

        Abilities = {
            Slash = require(ReplicatedStorage.Classes.Ability.Slash).New({
                Damage = 22,
                Duration = 0.35,
                FragileLevel = 3,
                FragileDuration = 6,
                --- Extra against anybody already carrying `Marked` or `Blindness`.
                JudgedBonus = 16,
                Behaviour = VeritySlashBehaviour,
            }),

            Confession = Ability.New({
                Name = "Confession",
                InputName = "FirstAbility",
                Cooldown = 22,
                Duration = 1.1,

                Radius = 45,
                BlindDuration = 2.5,
                MarkDuration = 10,

                UseSound = "rbxassetid://9125402735",
                Behaviour = ConfessionBehaviour,
            }),

            Mirrorstep = Ability.New({
                Name = "Mirrorstep",
                InputName = "SecondAbility",
                Cooldown = 18,
                Duration = 0.6,

                MarkedRange = 90,
                UnmarkedRange = 26,
                DisorientDuration = 3,

                UseSound = "rbxassetid://9046319808",
                ArriveSound = "rbxassetid://9046319808",
                Behaviour = MirrorstepBehaviour,
            }),

            Reckoning = Ability.New({
                Name = "The Reckoning",
                InputName = "ThirdAbility",
                Cooldown = 58,
                Duration = 8,

                SpeedLevel = 2,
                DisableSlashOnPerform = false,

                Behaviour = ReckoningBehaviour,
            }),

            Witness = Ability.New({
                Name = "Witness",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                Range = 85,
                --- Dot product cutoff. 0.45 is roughly a 63 degree cone either side.
                Tolerance = 0.45,

                ExtraInit = WitnessInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(214, 76, 138)\">"..Verity.Config.Name.."</font>"
local Abilities = Verity.GameplayConfig.Abilities

Verity.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Verity.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Verity.Config.Quote.."\""},
    {
        Type = "Text",
        Text = "Nobody agrees on what "..NameLabel.." looked like, only that they recognised it. "..
            "It does not chase so much as arrive, wearing the shape of something you'd rather not remember. "..
            "Meeting its gaze costs you your sight. Refusing to costs you your hiding place. "..
            "There has never been a third option.",
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Verity.Config.Role,
            "Difficulty: "..string.rep("★", Verity.Config.Difficulty)..string.rep("☆", 5 - Verity.Config.Difficulty),
            "Health: "..tostring(Verity.GameplayConfig.Health),
            "Base Speed: "..tostring(Verity.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Verity.GameplayConfig.BaseSpeed * Verity.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
            "Max Stamina: "..tostring(Verity.GameplayConfig.StaminaProperties.MaxStamina),
            "Stamina Loss per second: "..tostring(Verity.GameplayConfig.StaminaProperties.StaminaDrain),
            "Stamina Gain per second: "..tostring(Verity.GameplayConfig.StaminaProperties.StaminaGain),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "VERDICT"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage, and <b>"..tostring(Abilities.Slash.Damage + Abilities.Slash.JudgedBonus).." against anybody already carrying Marked or Blindness</b>.",
            "Those are exactly the two outcomes of <b>Confession</b>. Whichever side of that no-win choice you landed on, this collects on it.",
            "During <b>The Reckoning</b> it also stacks <b>Fragile "..tostring(Abilities.Slash.FragileLevel).."</b>.",
        },
    },

    {Type = "Header", Text = Abilities.Confession.Name:upper()},
    {
        Type = "Text",
        Text = {
            NameLabel.." screams, reaching every fighter within "..tostring(Abilities.Confession.Radius).." studs who it can see.",
            "Anyone <b>looking at it</b> is struck with <b>Blindness</b> for "..tostring(Abilities.Confession.BlindDuration).." seconds.",
            "Anyone <b>looking away</b> is struck with <b>Marked</b> for "..tostring(Abilities.Confession.MarkDuration).." seconds, revealing them to the entire arena.",
            "Walls block it completely. Break line of sight and it never reaches you.",
        },
    },

    {Type = "Header", Text = Abilities.Mirrorstep.Name:upper()},
    {
        Type = "Text",
        Text = {
            NameLabel.." trades places with the nearest <b>Marked</b> fighter within "..tostring(Abilities.Mirrorstep.MarkedRange).." studs.",
            "With nobody Marked, it can only reach as far as "..tostring(Abilities.Mirrorstep.UnmarkedRange).." studs.",
            "Whoever is swapped is left <b>Disoriented</b> for "..tostring(Abilities.Mirrorstep.DisorientDuration).." seconds.",
        },
    },

    {Type = "Header", Text = Abilities.Reckoning.Name:upper()},
    {
        Type = "Text",
        Text = {
            "For "..tostring(Abilities.Reckoning.Duration).." seconds "..NameLabel.." gains <b>Speed "..
                Utils.Math.IntToRoman(Abilities.Reckoning.SpeedLevel).."</b> and its slashes begin stacking <b>Fragile</b>.",
            "Its own aura is revealed to everyone for the duration. Everybody sees it coming.",
        },
    },

    {Type = "Header", Text = "WITNESS  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Anybody within "..tostring(Abilities.Witness.Range).." studs who is <b>facing it</b>, with a clear line of sight, is revealed to it continuously.",
            "Looking away stops it immediately. It takes nothing away and deals no damage — it is the information half of the choice the whole character is built around.",
            "Watching Verity tells it where you are. Not watching it means not knowing where it is.",
        },
    },
}

return Verity
