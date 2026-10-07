local Players = game:GetService("Players")
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
    IMPOSTOR — DECEPTION AND SABOTAGE.

      M1  IMPOSTOR KILL   Very short range, very high damage. Almost a melee execution.
      Q   VENT            Two presses: open a vent, then drop into it and come out elsewhere.
      E   SABOTAGE        One major sabotage at a time. Lights, doors or comms.
      R   DISGUISE        Takes on another fighter's appearance. Attacking breaks it.
      P   SUSPICIOUS      No chase music and quiet footsteps while disguised.

    THE ONE-SABOTAGE RULE
    ---------------------
    The brief was explicit, and `DeployableService`'s per-kind limit enforces it directly: one
    `Sabotage` object at a time, so starting a new one removes the old. Three kinds of
    sabotage on one key means the choice of WHICH is the interesting decision, and it cycles
    publicly so opponents can see what is coming next.

    DISGUISE, AND THE LINE IT DOES NOT CROSS
    ----------------------------------------
    It copies a target's BODY — their colours, scale and name tag — from a fighter who is
    actually in the round. It does NOT fabricate usernames, impersonate accounts, or produce
    anything that could be mistaken for a real player's identity outside the match: the name
    shown is the character name of a fighter already visible in the arena, and the impostor's
    own real username is left on the player list and the scoreboard untouched.

    The counterplay is firm and immediate:
      * ATTACKING BREAKS IT. Any damage he deals ends the disguise instantly.
      * TAKING DAMAGE BREAKS IT. Being hit ends it too.
      * It has a hard duration, and a visible wobble — the copy is never perfect.

    WEAKNESSES
    ----------
    The lowest reach on the roster by a wide margin: four studs. He has no ranged attack and
    nothing that closes distance except the vent, which is a two-stage commitment with a
    visible marker. In an open fight he loses to everybody.
]=]

local IMPOSTOR = Color3.fromRGB(200, 40, 50)
local VENT = Color3.fromRGB(60, 60, 70)

--------------------------------------------------------------------------------
-- M1 — IMPOSTOR KILL
--------------------------------------------------------------------------------

--[=[
    A knife from four studs.

    The shortest reach and the highest basic-attack damage in the game. The trade is total:
    he has to be standing on top of somebody, which for a character with no gap-closer means
    the kill has to be set up by a vent, a sabotage or a disguise.
]=]
local function KillBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.04, Duration = 0.25, Lock = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.6, MinPitch = 1.0, MaxPitch = 1.15})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Impostor",
            ExecuteOnKill = true,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, IMPOSTOR, 14, 20)
                        AbilityFX.Burst(VictimRoot.Position, 4, IMPOSTOR, {Duration = 0.25})
                        AbilityFX.ShakeFor(Victim, 2.5, 0.3)
                    end

                    -- Attacking blows the disguise. Handled here rather than in `Disguise`
                    -- so every source of his damage breaks it, not just this one.
                    if Char then
                        Char:SetAttribute("ImpostorBreakDisguise", os.clock())
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — VENT
--------------------------------------------------------------------------------

--[=[
    Two presses: open a vent, then travel to it.

    Mechanically similar to Huggy's and distinct in what it costs: Huggy plants ONE vent and
    the trip is a slow visible arc; the Impostor can have THREE open at once and the trip is
    instant, but he always arrives at the OLDEST one — so a vent network is something he has
    to plan the order of rather than pick from.

    Vents are visible objects with low health. The counterplay is to find them and break them
    while he is not in them.
]=]
local function VentBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.1, Duration = 0.3})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Existing = DeployableService.GetFor(self.Owner, "Vent")

    ----------------------------------------------------------------------------
    -- TRAVEL
    ----------------------------------------------------------------------------

    --[[
        Travel if he is standing on one of his own vents; otherwise open a new one.

        Keying off PROXIMITY rather than a stored state means the ability needs no mode
        toggle and reads correctly: standing on a vent means going down it, standing
        anywhere else means cutting a new one.
    ]]
    local Standing = nil
    for _, Vent in Existing do
        if Vent.Alive and Vent.Root and (Vent.Root.Position - Root.Position).Magnitude <= self.MountRadius then
            Standing = Vent
            break
        end
    end

    if Standing and #Existing >= 2 then
        -- The oldest OTHER vent. `GetFor` returns them in placement order.
        local Destination = nil
        for _, Vent in Existing do
            if Vent ~= Standing and Vent.Alive and Vent.Root and Vent.Root.Parent then
                Destination = Vent
                break
            end
        end

        if not Destination then
            self.OnCooldown = false
            self.CooldownTimer = 0
            return
        end

        local Spot = AbilityFX.GroundAt(Destination.Root.Position, {Char, Destination.Model}, 40)
        if not Spot then
            self.OnCooldown = false
            self.CooldownTimer = 0
            return
        end

        AbilityFX.Sound(self.EnterSound, Root.Position, {Volume = 0.8, MinPitch = 0.9, MaxPitch = 1.05})
        AbilityFX.Smoke(Root.Position, VENT, 10, 2.5)

        CombatUtils.Blink(Char, Spot + Vector3.new(0, 3, 0))

        AbilityFX.Smoke(Spot, VENT, 10, 2.5)
        AbilityFX.Sound(self.EnterSound, Spot, {Volume = 0.8, MinPitch = 0.9, MaxPitch = 1.05})
        AbilityFX.Ring(Spot, 7, IMPOSTOR, {Duration = 0.35})

        return
    end

    ----------------------------------------------------------------------------
    -- OPEN A NEW ONE
    ----------------------------------------------------------------------------

    local Ground = AbilityFX.GroundAt(Root.Position, {Char})
    if not Ground then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.OpenSound, Ground, {Volume = 0.65, MinPitch = 0.85, MaxPitch = 1})

    local Vent = DeployableService.Place({
        SourcePlayer = self.Owner,
        Kind = "Vent",
        Name = "Vent",
        CFrame = CFrame.new(Ground + Vector3.new(0, 0.25, 0)),
        Size = Vector3.new(4.5, 0.5, 4.5),
        Color = VENT,
        Material = Enum.Material.DiamondPlate,
        Solid = false,
        Health = self.VentHealth,
        Lifetime = self.VentLifetime,
        Limit = self.Limit,
        OutlineColor = IMPOSTOR,
    })

    if Vent then
        AbilityFX.Ring(Ground, 5, IMPOSTOR, {Duration = 0.3})
        -- Opening is cheap; the travel is the powerful half.
        self.OnCooldown = false
        self.CooldownTimer = 0
        self:SetOnCooldown(self.OpenCooldown)
    end
end

--------------------------------------------------------------------------------
-- E — SABOTAGE
--------------------------------------------------------------------------------

--[=[
    One sabotage at a time, cycling through three.

      LIGHTS  A wide area where everyone's screen dims. Navigable, never blinding.
      DOORS   A solid barrier across the nearest route. A wall he can place and others break.
      COMMS   Nobody in range can read anybody's aura — including him. Information denial
              that cuts both ways, which is why it is the strongest of the three.

    `DeployableService`'s `Limit = 1` on this kind IS the one-at-a-time rule: placing a new
    sabotage removes the previous one automatically, with no bookkeeping here.
]=]
local SABOTAGES = {"Lights", "Doors", "Comms"}

local function SabotageBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.94, Duration = 0.4, Lock = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Cache = self.CharModule.GameplayConfig.Cache

    Cache.SabotageIndex = Cache.SabotageIndex or 1
    local Kind = SABOTAGES[Cache.SabotageIndex]

    local Ground = AbilityFX.GroundAt(Root.Position + Root.CFrame.LookVector * 5, {Char})
    if not Ground then
        self.OnCooldown = false
        self.CooldownTimer = 0
        return
    end

    AbilityFX.Sound(self.UseSound, Ground, {Volume = 0.95, RollOffMaxDistance = 170})
    AbilityFX.Text(Root.Position + Vector3.new(0, 6, 0), "SABOTAGE: "..Kind:upper(), IMPOSTOR, 1.6)

    ----------------------------------------------------------------------------

    if Kind == "Doors" then
        local Facing = CFrame.lookAt(Ground + Vector3.new(0, self.DoorHeight * 0.5, 0), Ground + Root.CFrame.LookVector)

        DeployableService.Place({
            SourcePlayer = self.Owner,
            Kind = "Sabotage",
            Name = "SabotagedDoor",
            CFrame = Facing,
            Size = Vector3.new(self.DoorWidth, self.DoorHeight, 1),
            Color = Color3.fromRGB(120, 30, 35),
            Material = Enum.Material.Metal,
            Solid = true,
            Health = self.DoorHealth,
            Lifetime = self.Duration_,
            Limit = 1,
            OutlineColor = IMPOSTOR,
        })

        AbilityFX.Ring(Ground, self.DoorWidth, IMPOSTOR, {Duration = 0.4})

    else
        -- Lights and Comms are both volumes rather than objects, so they share a shape:
        -- a low-health marker with a radius and a per-tick effect.
        local Radius = Kind == "Lights" and self.LightRadius or self.CommsRadius

        local Marker = DeployableService.Place({
            SourcePlayer = self.Owner,
            Kind = "Sabotage",
            Name = "Sabotaged"..Kind,
            CFrame = CFrame.new(Ground + Vector3.new(0, 1.5, 0)),
            Size = Vector3.new(2.5, 3, 2.5),
            Color = IMPOSTOR,
            Material = Enum.Material.Neon,
            Transparency = 0.3,
            Solid = false,
            --[[
                Deliberately fragile.

                A sabotage that affects a 60 stud radius for twenty seconds needs a physical
                thing to break, and that thing needs to die quickly — otherwise the
                counterplay is "wait". Ten health is two swings from anybody.
            ]]
            Health = self.MarkerHealth,
            Lifetime = self.Duration_,
            Limit = 1,
            TickRate = 0.4,
            OutlineColor = IMPOSTOR,
            OnTick = function(handle)
                if Kind == "Lights" then
                    for _, Target: Model in CombatUtils.GetFightersInRadius(handle.Root.Position, Radius, Char) do
                        AbilityFX.ScreenFor(Target, "Dark", 0.9, 0.85)
                    end
                else
                    --[[
                        COMMS: `Undetectable` on everybody in range, HIM INCLUDED.

                        Cutting both ways is the whole reason this is the strongest option:
                        he gives up his own information to take away everyone else's, and
                        for a character who wins by knowing where people are, that is a real
                        decision rather than a free upgrade.
                    ]]
                    for _, Target: Model in CombatUtils.GetFightersInRadius(handle.Root.Position, Radius, nil) do
                        if not Utils.Instance.FindFirstChild(Target, "Effects.Undetectable", 0) then
                            CombatUtils.ApplyEffectTo(Target, "Undetectable", 1, 2)
                        end
                    end

                    AbilityFX.Ring(handle.Root.Position, Radius, IMPOSTOR, {Duration = 0.6, Transparency = 0.85})
                end
            end,
            OnEnd = function(handle)
                AbilityFX.Burst(handle.Root.Position, 7, IMPOSTOR, {Duration = 0.4})
            end,
        })

        if Marker then
            local Dome = AbilityFX.Part({
                Name = "SabotageDome",
                Shape = Enum.PartType.Ball,
                Size = Vector3.one * Radius * 2,
                CFrame = CFrame.new(Ground),
                Color = IMPOSTOR,
                Material = Enum.Material.Neon,
                Transparency = 0.94,
            })
            Dome.Parent = Marker.Model
        end
    end

    ----------------------------------------------------------------------------
    -- CYCLE
    ----------------------------------------------------------------------------

    Cache.SabotageIndex = (Cache.SabotageIndex % #SABOTAGES) + 1
    local Next = SABOTAGES[Cache.SabotageIndex]

    AbilityFX.Text(Root.Position + Vector3.new(0, 4.5, 0), "next: "..Next, IMPOSTOR, 1.1)
    if Char then
        Char:SetAttribute("NextSabotage", Next)
    end
end

--------------------------------------------------------------------------------
-- R — DISGUISE
--------------------------------------------------------------------------------

--[=[
    Takes on the appearance of a fighter who is actually in the round.

    WHAT IT COPIES: part colours, part transparency and a name tag reading the target's
    CHARACTER name. Nothing else. It does not touch usernames, the player list, the
    scoreboard, chat, or anything that identifies an account — see the header.

    HOW IT BREAKS, and all three are immediate:
      * He deals damage. Any damage, from anything.
      * He takes damage.
      * The timer runs out.

    While it holds he is quiet (see the passive) and visually somebody else. It is an
    APPROACH tool: it gets him into knife range on a character whose knife range is four
    studs, and it ends the instant he uses it.
]=]
local function DisguiseBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.96, Duration = 0.5})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Target = CombatUtils.GetClosestFighter(Root.Position, self.Range, Char)
    if not Target then
        self.OnCooldown = false
        self.CooldownTimer = 0
        AbilityFX.Text(Root.Position + Vector3.new(0, 5, 0), "nobody to copy", IMPOSTOR, 1)
        return
    end

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.75})
    AbilityFX.Burst(Root.Position, 6, IMPOSTOR, {Duration = 0.4})

    ----------------------------------------------------------------------------
    -- COPY
    ----------------------------------------------------------------------------

    --[[
        Original appearance remembered part by part, keyed by the part itself.

        Not by name: a rig can have two parts with the same name, and restoring by name
        would leave one of them the wrong colour permanently.
    ]]
    local Original: {[BasePart]: {Color: Color3, Transparency: number}} = {}

    local TargetParts: {[string]: BasePart} = {}
    for _, Part: Instance in Target:GetDescendants() do
        if Part:IsA("BasePart") then
            TargetParts[Part.Name] = Part
        end
    end

    for _, Part: Instance in Char:GetDescendants() do
        if not Part:IsA("BasePart") then
            continue
        end

        Original[Part] = {Color = Part.Color, Transparency = Part.Transparency}

        local Match = TargetParts[Part.Name]
        if Match then
            Part.Color = Match.Color
            Part.Transparency = Match.Transparency
        end
    end

    -- A name tag reading the TARGET'S CHARACTER NAME. Not a username.
    local Head = Char:FindFirstChild("Head")
    local Tag = nil

    if Head then
        Tag = Instance.new("BillboardGui")
        Tag.Name = "DisguiseTag"
        Tag.Size = UDim2.new(0, 160, 0, 30)
        Tag.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
        Tag.MaxDistance = 110
        Tag.Parent = Head

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.fromScale(1, 1)
        Label.BackgroundTransparency = 1
        Label.Font = Enum.Font.GothamBold
        Label.Text = tostring(Target:GetAttribute("CharacterName") or Target.Name)
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextScaled = true
        Label.Parent = Tag

        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Color3.fromRGB(0, 0, 0)
        Stroke.Thickness = 2
        Stroke.Parent = Label
    end

    Char:SetAttribute("ImpostorDisguised", true)
    Char:SetAttribute("ImpostorBreakDisguise", nil)

    PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.SpeedMultiplier)

    ----------------------------------------------------------------------------
    -- HOLD IT
    ----------------------------------------------------------------------------

    task.spawn(function()
        local Started = os.clock()
        local LastHealth = self.OwnerProperties.Humanoid and self.OwnerProperties.Humanoid.Health or 0

        while os.clock() - Started < self.Duration_ do
            task.wait(0.1)

            if not Char or not Char.Parent then
                break
            end

            -- He dealt damage.
            if Char:GetAttribute("ImpostorBreakDisguise") then
                break
            end

            -- He took damage.
            local Humanoid = Char:FindFirstChildWhichIsA("Humanoid")
            if not Humanoid or Humanoid.Health <= 0 then
                break
            end
            if Humanoid.Health < LastHealth - 0.01 then
                break
            end
            LastHealth = Humanoid.Health

            -- The copy is never perfect. A small flicker, often enough to notice if you are
            -- looking for it and not so often that it is unusable.
            if math.random() < 0.08 then
                AbilityFX.Tint(Char, IMPOSTOR, 0.12, {FillTransparency = 0.88})
            end
        end

        ------------------------------------------------------------------------
        -- RESTORE
        ------------------------------------------------------------------------

        --[[
            Restoration runs on EVERY exit path, which is why the loop breaks rather than
            returning: dying, being hit, attacking, timing out and the round ending all land
            here. A failed restore would leave somebody wearing another character's colours
            for the rest of the round.
        ]]
        for Part, Saved in Original do
            if Part and Part.Parent then
                Part.Color = Saved.Color
                Part.Transparency = Saved.Transparency
            end
        end

        if Tag and Tag.Parent then
            Tag:Destroy()
        end

        if Char then
            Char:SetAttribute("ImpostorDisguised", false)
            Char:SetAttribute("ImpostorBreakDisguise", nil)

            local Live = Utils.Character.GetRootPart(Char)
            if Live then
                AbilityFX.Burst(Live.Position, 6, IMPOSTOR, {Duration = 0.35})
                AbilityFX.Sound(self.BreakSound, Live.Position, {Volume = 0.8})
            end
        end

        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
    end)
end

--------------------------------------------------------------------------------
-- PASSIVE — SUSPICIOUS
--------------------------------------------------------------------------------

--[=[
    Quiet while disguised, and only while disguised.

    No chase music and silent footsteps — the same two mechanisms Creeper and Freddy use,
    because they are the engine's existing hooks for "you cannot hear me coming" and
    inventing a third would be three ways to do one thing.

    Gated on the disguise rather than being always-on, which is what keeps three stealth
    characters distinct: Creeper is quiet until it attacks, Freddy is quiet in the dark, and
    the Impostor is quiet while he is pretending to be you.
]=]
local function SuspiciousInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    self:AddConnection(task.spawn(function()
        local Applied = false

        while Char and Char.Parent do
            task.wait(0.4)

            local Disguised = Char:GetAttribute("ImpostorDisguised") == true

            if Disguised and not Applied then
                Applied = true
                Char:SetAttribute("FootstepVolume", 0)

            elseif not Disguised and Applied then
                Applied = false
                Char:SetAttribute("FootstepVolume", nil)
                CommonFunctions.RemoveEffect(Char, "Undetectable")
            end

            if Disguised and not Utils.Instance.FindFirstChild(Char, "Effects.Undetectable", 0) then
                CombatUtils.ApplyEffectTo(Char, "Undetectable", 1, 3)
            end
        end
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local Impostor: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Impostor",
        Quote = "",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 27000,

        Role = "Stealth",
        Difficulty = 4,

        Origin = {
            TooltipText = "There was one.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://78754179999047",
        },
    },

    GameplayConfig = {
        --[[
            Below-average health and the shortest reach in the game. Everything he has is
            about arriving somewhere unexpected; if a fight starts fairly he loses it.
        ]]
        Health = 1150,
        BaseSpeed = 11.4,
        SprintSpeedMultiplier = 26 / 11.4,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 110,
            StaminaDrain = 10,
            StaminaGain = 22,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://12222216",
                UseAnimation = "rbxassetid://133504250023139",

                --- Highest basic-attack damage on the roster, from the shortest range.
                Damage = 42,
                Cooldown = 2.4,
                Duration = 0.28,
                Delay = 0.1,
                --- Four studs. Enderman reaches twelve.
                HitboxSize = Vector3.new(3.5, 5.5, 4),
                HitboxOffset = CFrame.new(0, 0, -2),

                Behaviour = KillBehaviour,
            }),

            Vent = Ability.New({
                Name = "Vent",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 8,
                --- Short on the opening press. Travelling is the powerful half.
                OpenCooldown = 3,
                Duration = 0.3,

                MountRadius = 6,
                VentHealth = 30,
                VentLifetime = 60,
                Limit = 3,

                OpenSound = "rbxassetid://12222216",
                EnterSound = "rbxassetid://9046319808",
                Behaviour = VentBehaviour,
            }),

            Sabotage = Ability.New({
                Name = "Sabotage",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 26,
                Duration = 0.5,

                Duration_ = 18,
                MarkerHealth = 10,
                LightRadius = 55,
                CommsRadius = 60,
                DoorWidth = 16,
                DoorHeight = 12,
                DoorHealth = 95,

                UseSound = "rbxassetid://9118823103",
                Behaviour = SabotageBehaviour,
            }),

            Disguise = Ability.New({
                Name = "Disguise",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 38,
                Duration = 0.5,

                Range = 90,
                Duration_ = 12,
                SpeedMultiplier = 1.08,

                UseSound = "rbxassetid://9125402735",
                BreakSound = "rbxassetid://9046319808",
                Behaviour = DisguiseBehaviour,
            }),

            Suspicious = Ability.New({
                Name = "Suspicious",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",
                ExtraInit = SuspiciousInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- BREAKING THE DISGUISE ON ANY DAMAGE HE DEALS
--------------------------------------------------------------------------------

--[=[
    Every source of his damage breaks the disguise, not just the knife.

    `OnHit` fires when a hitbox connects WITH HIM, so it covers being hit. The outgoing half
    is marked by the basic attack's own `Hit` callback — and the attribute is the shared
    signal so a future ability only has to set it rather than knowing how the disguise works.
]=]
function Impostor:OnHit(_hitbox, _damage)
    if not RunService:IsServer() then
        return
    end

    local Char = self.Owner and self.Owner.Character
    if Char and Char:GetAttribute("ImpostorDisguised") then
        Char:SetAttribute("ImpostorBreakDisguise", os.clock())
    end
end

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(200, 40, 50)\">"..Impostor.Config.Name.."</font>"
local Abilities = Impostor.GameplayConfig.Abilities

Impostor.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Impostor.Config.Name:upper()},
    {
        Type = "Text",
        Text = {
            NameLabel.." has the hardest-hitting basic attack in the arena and the shortest reach in it by a wide margin.",
            "He has no ranged attack and nothing that closes distance in a fight. Everything he does is about arriving somewhere you were not expecting — through a vent, behind a sabotage, or wearing somebody else's colours.",
            "If a fight starts fairly, he loses it.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Impostor.Config.Role,
            "Difficulty: "..string.rep("★", Impostor.Config.Difficulty)..string.rep("☆", 5 - Impostor.Config.Difficulty),
            "Price: "..tostring(Impostor.Config.Price).."$",
            "Health: "..tostring(Impostor.GameplayConfig.Health),
            "Base Speed: "..tostring(Impostor.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Impostor.GameplayConfig.BaseSpeed * Impostor.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "IMPOSTOR KILL"},
    {
        Type = "Text",
        Text = {
            "<b>"..tostring(Abilities.Slash.Damage).." damage</b> every "..tostring(Abilities.Slash.Cooldown).." seconds — the highest on the roster.",
            "It reaches "..tostring(Abilities.Slash.HitboxSize.Z).." studs. He has to be standing on you.",
        },
    },

    {Type = "Header", Text = "VENT  (Q)"},
    {
        Type = "Text",
        Text = {
            "Press away from a vent to cut a new one. Press while standing on one to drop in and come out of his <b>oldest</b> other vent, instantly.",
            tostring(Abilities.Vent.Limit).." vents at a time, "..tostring(Abilities.Vent.VentHealth).." health each. They are visible objects — break them while he is not in one.",
            "Cooldown: "..tostring(Abilities.Vent.Cooldown).." seconds to travel, "..tostring(Abilities.Vent.OpenCooldown).." to open.",
        },
    },

    {Type = "Header", Text = "SABOTAGE  (E)"},
    {
        Type = "Text",
        Text = {
            "<b>One at a time.</b> Cycles through three, and what is next floats over his head:",
            "<b>Lights</b>: everybody within "..tostring(Abilities.Sabotage.LightRadius).." studs has a dimmed screen. Navigable, never blinding.",
            "<b>Doors</b>: a solid "..tostring(Abilities.Sabotage.DoorWidth).." stud barrier across the route in front of him.",
            "<b>Comms</b>: nobody within "..tostring(Abilities.Sabotage.CommsRadius).." studs can read auras — <b>him included</b>.",
            "Lights and Comms hang off a marker with "..tostring(Abilities.Sabotage.MarkerHealth).." health. Two swings ends either.",
            "Cooldown: "..tostring(Abilities.Sabotage.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "DISGUISE  (R)"},
    {
        Type = "Text",
        Text = {
            "Takes on the colours and character name of a fighter already in the round, for up to "..tostring(Abilities.Disguise.Duration_).." seconds.",
            "<b>It breaks the instant he deals damage, and the instant he takes any.</b> The copy also flickers — it is never quite right.",
            "It changes nothing about names, accounts or the player list. It is a costume.",
            "Cooldown: "..tostring(Abilities.Disguise.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "SUSPICIOUS  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "While disguised: silent footsteps and no chase music.",
            "Only while disguised. Out of costume he is as loud as anybody.",
        },
    },
}

return Impostor
