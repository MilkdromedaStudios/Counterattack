local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Hitbox = require(ReplicatedStorage.Classes.Hitbox)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

--[=[
    NUKER — brings down the biggest numbers in the game and cannot aim any of them.

    Design idea: the only killer on the roster whose abilities hurt him too.

    Every explosion he makes damages him as well as everyone else, at a reduced rate.
    That single rule reshapes the whole character: he has the highest burst damage in
    the arena and can never open with it at close range, which means he plays as an
    area-denial killer who forces people out of cover rather than one who dives them.

    Fallout is the follow-up — the ground stays irradiated long after the blast, and
    Irradiated blocks stamina regeneration, so anyone who runs through a crater can't
    sprint away from what comes next.
]=]

--------------------------------------------------------------------------------
-- SHARED
--------------------------------------------------------------------------------

--[=[
    A blast that hurts everyone, including the person who set it off.

    `selfDamageScale` is the fraction of the full damage Nuker takes. Passing 0 would
    make him safe, which is exactly the thing this character is not allowed to be.
]=]
local function Detonate(self: Types.Ability, position: Vector3, radius: number, damage: number, selfDamageScale: number, effects: {any}?)
    local Char = self.OwnerProperties.Character

    -- Visual shockwave that expands out to the real radius, so the danger zone is
    -- honestly telegraphed rather than being a number only the killer knows.
    local Shock = CombatUtils.MakePart({
        Name = "NukeShockwave",
        Shape = Enum.PartType.Ball,
        Size = Vector3.one * 2,
        Color = Color3.fromRGB(255, 170, 40),
        Material = Enum.Material.Neon,
        Transparency = 0.35,
        CFrame = CFrame.new(position),
    })
    Shock.Parent = CombatUtils.GetInGameFolder()
    Debris:AddItem(Shock, 0.6)

    TweenService:Create(Shock, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = Vector3.one * (radius * 2),
        Transparency = 1,
    }):Play()

    Sounds.PlaySound(self.BlastSound, {
        Position = position,
        Volume = 1,
        RollOffMaxDistance = radius + 90,
        RollOffMinDistance = 20,
    })

    -- Everybody in range takes it. `FriendlyFire` is forced on so this can never be
    -- filtered by role, and `IgnoreOwner` is off in the manual loop below.
    Hitbox.New(self.Owner, {
        CFrame = CFrame.new(position),
        Size = Vector3.one * (radius * 2),
        Shape = Enum.PartType.Ball,
        Time = 0.25,
        Damage = damage,
        Knockback = 18,
        HitMultiple = true,
        FriendlyFire = true,
        PredictVelocity = false,
        Reason = "Nuker Blast",
        EffectsToApply = effects,
    })

    -- And so does Nuker, at a discount. The hitbox above always excludes its own
    -- creator, so his share has to be applied by hand.
    local Root = Utils.Character.GetRootPart(Char)
    local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")

    if Root and Humanoid and Humanoid.Health > 0 then
        local Distance = (Root.Position - position).Magnitude
        if Distance <= radius then
            -- Falls off with distance, so standing at the very edge is survivable.
            local Falloff = 1 - (Distance / radius) * 0.5
            Humanoid:TakeDamage(damage * selfDamageScale * Falloff)

            Utils.Player.ShakeCameraOf(self.Owner, 1.4, 0.5)
        end
    end
end

--------------------------------------------------------------------------------
-- ABILITY BEHAVIOURS
--------------------------------------------------------------------------------

--[=[
    PAYLOAD (Q)

    Lobs a charge that lands and detonates after a fuse. The fuse is long enough to
    dodge, which is the point — it's a tool for taking space away, not for killing
    somebody who's paying attention.
]=]
local function PayloadBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Root = self.OwnerProperties.HRP
    local Landing = (Root.CFrame * CFrame.new(0, 0, -self.Distance)).Position

    -- Drop it to the floor so the blast centre isn't floating at chest height.
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {workspace.Players, workspace.TempObjectFolders}

    local Cast = workspace:Raycast(Landing + Vector3.new(0, 10, 0), Vector3.new(0, -60, 0), Params)
    if Cast then
        Landing = Cast.Position
    end

    Sounds.PlaySound(self.UseSound, {Parent = Root, Volume = 0.75})

    -- The charge itself, blinking faster as the fuse runs down.
    local Charge = CombatUtils.MakePart({
        Name = "PayloadCharge",
        Shape = Enum.PartType.Ball,
        Size = Vector3.one * 3,
        Color = Color3.fromRGB(255, 90, 40),
        Material = Enum.Material.Neon,
        Transparency = 0,
        CFrame = CFrame.new(Landing + Vector3.new(0, 1.5, 0)),
    })
    Charge.Parent = CombatUtils.GetInGameFolder()
    Debris:AddItem(Charge, self.FuseTime + 0.2)

    self:AddConnection(task.spawn(function()
        local Elapsed = 0
        while Elapsed < self.FuseTime do
            if not Charge.Parent then
                return
            end

            -- Blink rate ramps up as the fuse burns.
            local Remaining = self.FuseTime - Elapsed
            Charge.Transparency = Charge.Transparency > 0.4 and 0 or 0.7

            Elapsed += task.wait(math.max(0.06, Remaining / 12))
        end

        Detonate(self, Landing, self.Radius, self.Damage, self.SelfDamage, {
            {Name = "Burning", Level = 2, Duration = 4},
        })
    end))
end

--[=[
    FALLOUT (E)

    Leaves a lasting irradiated zone. Low damage per tick, but Irradiated stops stamina
    regenerating, so the real cost of walking through it is that you can't sprint out
    of whatever Nuker does next.

    Nuker is immune to his own fallout — the self-damage rule applies to blasts, not to
    lingering radiation, or he'd simply kill himself holding an area.
]=]
local function FalloutBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Root = self.OwnerProperties.HRP
    local Centre = (Root.CFrame * CFrame.new(0, -2.5, -self.Distance)).Position

    Sounds.PlaySound(self.UseSound, {Position = Centre, Volume = 0.8})

    CombatUtils.CreateZone({
        SourcePlayer = self.Owner,
        Position = Centre,
        Radius = self.Radius,
        Lifetime = self.ZoneDuration,
        TickRate = 1,
        Damage = self.TickDamage,
        IgnoreOwner = true,
        Color = Color3.fromRGB(150, 255, 90),
        Material = Enum.Material.Neon,
        Transparency = 0.7,
        Effects = {
            {Name = "Irradiated", Level = self.RadiationLevel, Duration = 3},
        },
    })
end

--[=[
    GROUND ZERO (R)

    The biggest single hit in the game, centred on Nuker himself.

    He takes a much larger share of it than he does from Payload, and there is a wind-up
    during which he can't move. Used correctly it wipes a crowd that cornered him; used
    greedily it kills him outright.
]=]
local function GroundZeroBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 0.8)
        self:AddConnection(task.delay(self.ChargeTime + 0.5, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    Sounds.PlaySound(self.ChargeSound, {Parent = Root, Volume = 0.9})

    -- Growing warning sphere. Everyone nearby gets the full wind-up to leave.
    local Warning = CombatUtils.MakePart({
        Name = "GroundZeroWarning",
        Shape = Enum.PartType.Ball,
        Size = Vector3.one * 2,
        Color = Color3.fromRGB(255, 40, 40),
        Material = Enum.Material.ForceField,
        Transparency = 0.5,
        CFrame = Root.CFrame,
    })
    Warning.Parent = CombatUtils.GetInGameFolder()
    Debris:AddItem(Warning, self.ChargeTime + 0.3)

    TweenService:Create(Warning, TweenInfo.new(self.ChargeTime, Enum.EasingStyle.Linear), {
        Size = Vector3.one * (self.Radius * 2),
    }):Play()

    local FollowConnection
    FollowConnection = RunService.PostSimulation:Connect(function()
        if not (Warning.Parent and Root.Parent) then
            FollowConnection:Disconnect()
            return
        end
        Warning.CFrame = CFrame.new(Root.Position)
    end)
    self:AddConnection(FollowConnection)

    self:AddStunnableConnection(task.delay(self.ChargeTime, function()
        FollowConnection:Disconnect()

        if not (Char and Char.Parent) then
            return
        end

        local BlastRoot = Utils.Character.GetRootPart(Char)
        if not BlastRoot then
            return
        end

        Detonate(self, BlastRoot.Position, self.Radius, self.Damage, self.SelfDamage, {
            {Name = "Irradiated", Level = 3, Duration = 8},
            {Name = "Fragile", Level = 2, Duration = 6},
        })

        Utils.Player.ShakeCameraOf(Utils.Player.GetLoadedPlayers(false), 1.6, 0.8)
    end))
end

--------------------------------------------------------------------------------
-- CHARACTER DEFINITION
--------------------------------------------------------------------------------

local Nuker: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Nuker",
        Quote = "Everyone's in the blast radius. Including me.",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 1750,

        Origin = {
            TooltipText = "Was standing too close, once.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },
    },

    GameplayConfig = {
        -- Bulky, because he's going to be eating his own explosions all match.
        Health = 1350,
        BaseSpeed = 10,
        SprintSpeedMultiplier = 23.5 / 10,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 105,
            StaminaDrain = 11,
            StaminaGain = 19,
        },

        Abilities = {
            Slash = require(ReplicatedStorage.Classes.Ability.Slash).New({
                Damage = 21,
                Cooldown = 2.2,
                Duration = 0.4,
            }),

            Payload = Ability.New({
                Name = "Payload",
                InputName = "FirstAbility",
                Cooldown = 15,
                Duration = 0.8,

                Distance = 26,
                FuseTime = 1.8,
                Radius = 20,
                Damage = 55,
                --- Fraction of the damage Nuker takes from his own blast.
                SelfDamage = 0.35,

                UseSound = "rbxassetid://9046319808",
                BlastSound = "rbxassetid://9083889906",

                Behaviour = PayloadBehaviour,
            }),

            Fallout = Ability.New({
                Name = "Fallout",
                InputName = "SecondAbility",
                Cooldown = 24,
                Duration = 0.8,

                Distance = 18,
                Radius = 22,
                ZoneDuration = 15,
                TickDamage = 4,
                RadiationLevel = 2,

                UseSound = "rbxassetid://9118823103",
                Behaviour = FalloutBehaviour,
            }),

            GroundZero = Ability.New({
                Name = "Ground Zero",
                InputName = "ThirdAbility",
                Cooldown = 70,
                Duration = 2.6,

                ChargeTime = 2.2,
                Radius = 38,
                Damage = 120,
                --- He takes over half of this one. It is not a panic button.
                SelfDamage = 0.55,

                ChargeSound = "rbxassetid://9125402735",
                BlastSound = "rbxassetid://9083889906",

                Behaviour = GroundZeroBehaviour,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(255, 156, 46)\">"..Nuker.Config.Name.."</font>"
local Abilities = Nuker.GameplayConfig.Abilities

--- Worked out rather than written by hand, so retuning the numbers can't make the
--- page lie about how dangerous his own ultimate is to him.
local GroundZeroSelfDamage = math.round(Abilities.GroundZero.Damage * Abilities.GroundZero.SelfDamage)
local PayloadSelfDamage = math.round(Abilities.Payload.Damage * Abilities.Payload.SelfDamage)

Nuker.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Nuker.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Nuker.Config.Quote.."\""},
    {
        Type = "Text",
        Text = NameLabel.." hits harder than anything else in the arena and has never once done it safely. "..
            "Every blast he sets off catches him too. "..
            "He wins by making whole rooms uninhabitable and waiting for people to run out of somewhere else to be — "..
            "and he loses by getting excited and standing in his own crater.",
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Difficulty: ★★★★☆",
            "Health: "..tostring(Nuker.GameplayConfig.Health),
            "Base Speed: "..tostring(Nuker.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Nuker.GameplayConfig.BaseSpeed * Nuker.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
            "Max Stamina: "..tostring(Nuker.GameplayConfig.StaminaProperties.MaxStamina),
            "Stamina Loss per second: "..tostring(Nuker.GameplayConfig.StaminaProperties.StaminaDrain),
            "Stamina Gain per second: "..tostring(Nuker.GameplayConfig.StaminaProperties.StaminaGain),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = Abilities.Slash.Name:upper()},
    {
        Type = "Text",
        Text = NameLabel.." swings for "..tostring(Abilities.Slash.Damage).." damage.",
        Image = "rbxassetid://9759886280",
    },

    {Type = "Header", Text = Abilities.Payload.Name:upper()},
    {
        Type = "Text",
        Text = {
            "A charge is thrown "..tostring(Abilities.Payload.Distance).." studs ahead and detonates after "..tostring(Abilities.Payload.FuseTime).." seconds.",
            tostring(Abilities.Payload.Damage).." damage in a "..tostring(Abilities.Payload.Radius).." stud sphere, plus <b>Burning</b>.",
            "<b>"..NameLabel.." takes up to "..tostring(PayloadSelfDamage).." damage from it himself</b> if he's inside the radius.",
            "It blinks faster the closer it is to going off.",
        },
    },

    {Type = "Header", Text = Abilities.Fallout.Name:upper()},
    {
        Type = "Text",
        Text = {
            "A "..tostring(Abilities.Fallout.Radius).." stud irradiated zone that lingers for "..tostring(Abilities.Fallout.ZoneDuration).." seconds.",
            tostring(Abilities.Fallout.TickDamage).." damage a second and <b>Irradiated "..Utils.Math.IntToRoman(Abilities.Fallout.RadiationLevel).."</b> to anyone inside.",
            "Irradiated fighters cannot regenerate stamina at all — they can't sprint out of what comes next.",
            NameLabel.." is immune to his own fallout.",
        },
    },

    {Type = "Header", Text = Abilities.GroundZero.Name:upper()},
    {
        Type = "Text",
        Text = {
            "After a "..tostring(Abilities.GroundZero.ChargeTime).." second wind-up, everything within "..tostring(Abilities.GroundZero.Radius)..
                " studs of "..NameLabel.." takes "..tostring(Abilities.GroundZero.Damage).." damage, <b>Irradiated III</b> and <b>Fragile II</b>.",
            "<b>"..NameLabel.." takes about "..tostring(GroundZeroSelfDamage).." of that himself.</b> At full health that is survivable. It usually isn't used at full health.",
            "A red sphere grows out to the full radius during the wind-up. Everyone gets to see exactly how much room they have.",
        },
    },
}

return Nuker
