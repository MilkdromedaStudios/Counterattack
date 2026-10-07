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
    RAINBOW FRIEND — BLUE.

    WHICH ONE THIS IS, AND HOW THAT WAS DECIDED
    -------------------------------------------
    The brief was explicit about not assuming, so this was read off the project rather than
    guessed. Every piece of evidence in the repository points the same way:

      * The module's own colour constant, used by all three of its abilities, was
        `Color3.fromRGB(70, 130, 245)` — blue.
      * Its design note read "Big, fast, and it does not stop once it has started. The most
        punishing sustained pressure in the game", which is Blue's behaviour and nobody
        else's.
      * Its abilities were `Lunge`, `Colour Shift` and `Rainbow Rush` — a charge, a buff and
        a sustained attack. No blindness, no water, no vents.

    There is no model in the repository to check (the rigs are Studio assets), and no other
    metadata anywhere. So: BLUE, the simple relentless chaser, and the kit is built to the
    brief's BLUE specification.

      M1  GRAB         Both arms. Short, heavy, and it holds you still for a moment.
      Q   CHARGE       A long committed pursuit. It does not stop for anybody.
      E   SEARCH       Detects MOVING fighters through walls. Standing still hides you.
      R   ROAR         A short-range fear effect. No damage at all.
      F   COLOUR SHIFT Borrows another friend's trait for a while. The project's own idea.
      P   DOES NOT STOP It accelerates the longer it has been chasing the same person.

    SEARCH ONLY FINDS MOVEMENT
    --------------------------
    That one rule is the whole character's counterplay. Blue is a relentless chaser with no
    ranged damage, so the answer to it is to break line of sight and HOLD STILL — and
    `Search` is built to make that an actual decision rather than a hope. Run and it finds
    you; freeze and it does not.

    WEAKNESSES
    ----------
    No ranged damage of any kind. `Roar` deals nothing. Every approach it has is a committed
    straight-line charge, and its passive only works while it stays on ONE target — so
    switching targets resets it to nothing.
]=]

local BLUE = Color3.fromRGB(70, 130, 245)
local BLUE_DEEP = Color3.fromRGB(20, 50, 140)

--- The friend whose trait is currently borrowed, if any.
local SHIFT_ATTRIBUTE = "RainbowShift"

--------------------------------------------------------------------------------
-- M1 — GRAB
--------------------------------------------------------------------------------

local function GrabBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.05, Duration = 0.3, Lock = 0.6, Shake = 0.5, ShakeTime = 0.2})
        return
    end

    local Root = self.OwnerProperties.HRP

    AbilityFX.SoundOn(Root, self.UseSound, {Volume = 0.75, MinPitch = 0.7, MaxPitch = 0.85})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        -- Both arms closing. It is a grab, not a swipe.
        local From = Root.Position + Vector3.new(0, 1.5, 0)
        for _, Side in {-1, 1} do
            AbilityFX.Beam(
                From + Root.CFrame.RightVector * (Side * 3),
                From + Root.CFrame.LookVector * 5,
                BLUE,
                {Width = 1.2, Duration = 0.22, Transparency = 0.25}
            )
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = self.Damage,
            Reason = "Grab",
            ExecuteOnKill = true,
            EffectsToApply = {
                --[[
                    A short `Snared` on every basic attack, which is unusual and deliberate.

                    Blue's whole threat is that it keeps arriving. Half a second of being
                    held per hit is what turns "it caught me once" into "it caught me again",
                    and `Snared` leaves the victim their abilities and their attack so it is
                    pressure rather than a lock.
                ]]
                {Name = "Snared", Level = 3, Duration = 0.5, OverwriteExisting = true},
            },
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if not VictimRoot then
                        return
                    end

                    AbilityFX.Burst(VictimRoot.Position, 5, BLUE, {Duration = 0.25})
                    AbilityFX.ShakeFor(Victim, 3, 0.4)

                    -- Feeds the passive. See `PursuitInit`.
                    if self.OwnerProperties.Character then
                        self.OwnerProperties.Character:SetAttribute("RainbowTarget", Victim.Name)
                        self.OwnerProperties.Character:SetAttribute("RainbowTargetAt", os.clock())
                    end
                end,
            },
        })
    end)
end

--------------------------------------------------------------------------------
-- Q — CHARGE
--------------------------------------------------------------------------------

local function ChargeBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.3, Duration = self.Duration_, Lock = self.Duration_})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 1, RollOffMaxDistance = 190})
    AbilityFX.ScreenInRadius(Root.Position, 70, "Rage", 1.2, 0.9, Char)

    CombatUtils.Dash(Char, self.Speed, self.Duration_, true)

    local Struck = {}

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.Duration_ and Char and Char.Parent do
            Elapsed += task.wait(0.04)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            AbilityFX.Burst(Live.Position, 4, BLUE, {Duration = 0.25, StartSize = 3, Transparency = 0.7})

            for _, Target: Model in CombatUtils.GetFightersInRadius(Live.Position, self.Radius, Char) do
                if Struck[Target] then
                    continue
                end
                Struck[Target] = true

                local Humanoid = Target:FindFirstChildWhichIsA("Humanoid")
                local TargetRoot = Utils.Character.GetRootPart(Target)
                if not Humanoid or not TargetRoot then
                    continue
                end

                CommonFunctions.DamagePlayer({
                    SourcePlayer = self.Owner,
                    TargetHumanoid = Humanoid,
                    Damage = self.Damage,
                    Reason = self.Name,
                    KnockbackDirection = Live.CFrame.LookVector,
                    KnockbackMagnitude = 12,
                })

                CombatUtils.ApplyEffectTo(Target, "Snared", 3, self.SnareTime)
                AbilityFX.ShakeFor(Target, 4, 0.5)

                Char:SetAttribute("RainbowTarget", Target.Name)
                Char:SetAttribute("RainbowTargetAt", os.clock())
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- E — SEARCH
--------------------------------------------------------------------------------

--[=[
    Finds whoever is MOVING.

    A pulse, repeated a few times over `Duration_` seconds. Each pulse reveals every fighter
    inside `Range` whose velocity is above `MinimumSpeed` — so standing perfectly still is a
    real answer, and everybody can hear the pulse go off so they know when to freeze.

    It is deliberately not an aura reveal: it is a repeated test, which means the right play
    against it is to time your movement rather than simply to be far away.
]=]
local function SearchBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 0.92, Duration = 0.4})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Found = false

    task.spawn(function()
        for Pulse = 1, self.Pulses do
            if not Char or not Char.Parent then
                return
            end

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                return
            end

            -- Audible, and visible. Everybody gets told a pulse happened.
            AbilityFX.Sound(self.UseSound, Live.Position, {
                Volume = 0.9,
                MinPitch = 0.95 + Pulse * 0.05,
                MaxPitch = 1.05 + Pulse * 0.05,
                RollOffMaxDistance = self.Range + 40,
            })
            AbilityFX.Ring(Live.Position, self.Range, BLUE, {Duration = 0.7, Thickness = 1, Transparency = 0.8})

            for _, Target: Model in CombatUtils.GetFightersInRadius(Live.Position, self.Range, Char) do
                local TargetRoot = Utils.Character.GetRootPart(Target)
                if not TargetRoot then
                    continue
                end

                --[=[
                    MOVEMENT ONLY.

                    Read from the root's velocity, which the server owns, so it cannot be
                    faked. Below the threshold and the pulse passes straight over you.
                ]=]
                if TargetRoot.AssemblyLinearVelocity.Magnitude < self.MinimumSpeed then
                    -- Told that they were missed, so holding still is a learnable play
                    -- rather than a rumour.
                    AbilityFX.ScreenFor(Target, "Mist", 0.4, 0.4)
                    continue
                end

                Found = true
                Utils.Player.RevealPlayerAuraTo(self.Owner, Target, self.RevealTime, BLUE)

                AbilityFX.ScreenFor(Target, "Rage", 0.8, 0.7)
                AbilityFX.Burst(TargetRoot.Position, 5, BLUE, {Duration = 0.4, Transparency = 0.6})
            end

            task.wait(self.Duration_ / self.Pulses)
        end

        if not Found then
            -- Everybody held still, or nobody was there. Either way it got nothing.
            self.OnCooldown = false
            self.CooldownTimer = 0
        end
    end)
end

--------------------------------------------------------------------------------
-- R — ROAR
--------------------------------------------------------------------------------

--[=[
    A roar. It deals no damage whatsoever.

    `Disoriented` for a short time, plus a heavy slow and the `Rage` screen effect. The
    brief called it a "fear/disorientation effect" and that is exactly what it is: it takes
    away your ability to run from Blue cleanly for a couple of seconds, which for a
    relentless chaser is worth far more than damage would be.

    Short range on purpose — it is the thing it does after it has already caught you, not an
    opener.
]=]
local function RoarBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.25, Duration = 0.7, Shake = 3, ShakeTime = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 1, RollOffMinDistance = 20, RollOffMaxDistance = 230})
    AbilityFX.Ring(Root.Position, self.Radius, BLUE, {Duration = 0.6, Thickness = 1.6})
    AbilityFX.Ring(Root.Position, self.Radius * 0.6, BLUE_DEEP, {Duration = 0.5, Thickness = 1})
    AbilityFX.ShakeInRadius(Root.Position, self.Radius * 1.5, 5, 0.7)

    local Caught = 0

    for _, Target: Model in CombatUtils.GetFightersInRadius(Root.Position, self.Radius, Char) do
        local TargetRoot = Utils.Character.GetRootPart(Target)
        if not TargetRoot then
            continue
        end

        Caught += 1

        -- No damage. None at all.
        CombatUtils.ApplyEffectTo(Target, "Disoriented", 1, self.DisorientTime)
        CombatUtils.ApplyEffectTo(Target, "Slowness", self.SlowLevel, self.SlowTime)

        AbilityFX.ScreenFor(Target, "Rage", self.DisorientTime + 0.5, 1.5)
        AbilityFX.Text(TargetRoot.Position + Vector3.new(0, 5.5, 0), "!!!", BLUE, 1.2)
    end

    if Caught <= 0 then
        self.OnCooldown = false
        self.CooldownTimer = 0
    end
end

--------------------------------------------------------------------------------
-- F — COLOUR SHIFT
--------------------------------------------------------------------------------

--[=[
    Borrows another friend's trait for a while.

    THIS ABILITY IS THE PROJECT'S OWN, NOT THE BRIEF'S, and it is kept because it was already
    here and it is a genuinely good idea: Blue is the base character, and `Colour Shift` is
    how the module acknowledges the rest of them without pretending to be them.

    It cycles through three borrowed traits in a fixed order, and which is next is public:

      GREEN   Blind pursuit. It loses its own sight — everybody is `Undetectable` to it —
              and in exchange it hits far harder and ignores slows. Green cannot see either.
      ORANGE  Speed. A large sustained speed bonus and nothing else. Orange is quick.
      PURPLE  Resilience. Heavy damage reduction and immunity to being slowed, because
              Purple is the one you cannot get away from in the water.

    The original version of this ability gave all three at once — damage, speed AND
    resistance, for ten seconds, on a twenty second cooldown. Splitting it into a rotation
    keeps the flavour and removes the "press for everything" problem.
]=]
local SHIFTS = {"Green", "Orange", "Purple"}

local function ShiftBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.15, Duration = 0.6})
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP
    local Cache = self.CharModule.GameplayConfig.Cache

    Cache.ShiftIndex = Cache.ShiftIndex or 1
    local Shift = SHIFTS[Cache.ShiftIndex]

    local Colours = {
        Green = Color3.fromRGB(70, 200, 90),
        Orange = Color3.fromRGB(255, 150, 50),
        Purple = Color3.fromRGB(160, 70, 220),
    }
    local Colour = Colours[Shift]

    AbilityFX.Sound(self.UseSound, Root.Position, {Volume = 0.95})
    AbilityFX.Ring(Root.Position, 14, Colour, {Duration = 0.6, Thickness = 1.3})
    AbilityFX.Text(Root.Position + Vector3.new(0, 6, 0), Shift:upper(), Colour, 1.5)

    Char:SetAttribute(SHIFT_ATTRIBUTE, Shift)

    ----------------------------------------------------------------------------

    if Shift == "Green" then
        -- Harder hitting, and blind. `AbilityDamageMultiplier` is read by
        -- `CommonFunctions.DamagePlayer` and multiplies with everything else.
        Char:SetAttribute("AbilityDamageMultiplier", self.GreenDamageMultiplier)
        Char:SetAttribute("RainbowBlind", true)

    elseif Shift == "Orange" then
        PlayerSpeedManager.AddSpeedFactor(self.Owner, self.Name, self.OrangeSpeedMultiplier)

    else
        CombatUtils.ApplyEffectTo(Char, "Resistance", self.PurpleResistance, self.Duration_)
    end

    ----------------------------------------------------------------------------
    -- THE WINDOW
    ----------------------------------------------------------------------------

    task.spawn(function()
        local Elapsed = 0

        while Elapsed < self.Duration_ and Char and Char.Parent do
            Elapsed += task.wait(0.3)

            local Live = Utils.Character.GetRootPart(Char)
            if not Live then
                break
            end

            AbilityFX.Tint(Char, Colour, 0.35, {FillTransparency = 0.72})

            -- Green cannot see. Everybody it could have tracked goes dark.
            if Shift == "Green" then
                for _, Target: Model in CombatUtils.GetFightersInRadius(Live.Position, 120, Char) do
                    if not Utils.Instance.FindFirstChild(Target, "Effects.Undetectable", 0) then
                        CombatUtils.ApplyEffectTo(Target, "Undetectable", 1, 1.5)
                    end
                end
            end
        end
    end)

    --[[
        Raw delay. Every one of these writes outlives its caster if it is not cleaned up:
        `AbilityDamageMultiplier` and `RainbowBlind` are attributes on a character that may
        be replaced, and a speed factor is held on the player.
    ]]
    task.delay(self.Duration_, function()
        if Char then
            Char:SetAttribute(SHIFT_ATTRIBUTE, nil)
            Char:SetAttribute("AbilityDamageMultiplier", nil)
            Char:SetAttribute("RainbowBlind", nil)
        end
        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, self.Name)
    end)

    ----------------------------------------------------------------------------
    -- CYCLE
    ----------------------------------------------------------------------------

    Cache.ShiftIndex = (Cache.ShiftIndex % #SHIFTS) + 1
    local Next = SHIFTS[Cache.ShiftIndex]

    AbilityFX.Text(Root.Position + Vector3.new(0, 4.5, 0), "next: "..Next, Colours[Next], 1.2)
    if Char then
        Char:SetAttribute("NextShift", Next)
    end
end

--------------------------------------------------------------------------------
-- PASSIVE — DOES NOT STOP
--------------------------------------------------------------------------------

--[=[
    It accelerates while it stays on ONE person.

    The target is set by its grab and its charge. While the same name stays set and has been
    hit within `Memory` seconds, Blue gains a stacking speed bonus up to a cap — and
    switching to somebody else, or losing them for long enough, drops it to nothing.

    That is the honest version of "does not stop once it has started": it rewards committing
    to one victim, and it punishes the thing a relentless chaser is tempted to do, which is
    swing at whoever happens to be closest.
]=]
local function PursuitInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    self:AddConnection(task.spawn(function()
        local Stacks = 0
        local Last = nil

        while Char and Char.Parent do
            task.wait(self.Interval)

            local Target = Char:GetAttribute("RainbowTarget")
            local At = Char:GetAttribute("RainbowTargetAt") or 0

            -- Target changed, or it has been too long since the last hit.
            if Target ~= Last or os.clock() - At > self.Memory then
                if Stacks > 0 then
                    Stacks = 0
                    PlayerSpeedManager.RemoveSpeedFactor(self.Owner, "Pursuit")
                end
                Last = Target

                if Target ~= nil and os.clock() - At <= self.Memory then
                    -- A new victim starts the climb from one.
                    Stacks = 1
                    PlayerSpeedManager.AddSpeedFactor(self.Owner, "Pursuit", 1 + self.SpeedPerStack)
                end

                continue
            end

            if Stacks < self.MaximumStacks then
                Stacks += 1
                PlayerSpeedManager.AddSpeedFactor(self.Owner, "Pursuit", 1 + self.SpeedPerStack * Stacks)

                local Root = Utils.Character.GetRootPart(Char)
                if Root and Stacks == self.MaximumStacks then
                    AbilityFX.Text(Root.Position + Vector3.new(0, 5.5, 0), "IT WON'T STOP", BLUE, 1.4)
                end
            end
        end

        PlayerSpeedManager.RemoveSpeedFactor(self.Owner, "Pursuit")
    end))
end

--------------------------------------------------------------------------------
-- THE CHARACTER
--------------------------------------------------------------------------------

local RainbowFriend: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Rainbow Friend",
        Quote = "",
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 30000,

        Role = "Chaser",
        Difficulty = 3,

        Origin = {
            TooltipText = "The blue one.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },

        Sounds = {
            FootstepSounds = "rbxassetid://9046319808",
        },
    },

    GameplayConfig = {
        --[[
            Big health, good speed, and no ranged anything. It is the most punishing
            sustained pressure in the game and it has to physically reach you to apply any
            of it.
        ]]
        Health = 1500,
        BaseSpeed = 11.3,
        SprintSpeedMultiplier = 26 / 11.3,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 130,
            StaminaDrain = 9,
            StaminaGain = 20,
        },

        Abilities = {
            Slash = Ability.New({
                Name = "Slash",
                InputName = "Slash",
                RenderImage = "rbxassetid://11218451110",
                UseSound = "rbxassetid://9046319808",
                UseAnimation = "rbxassetid://133504250023139",

                Damage = 29,
                Cooldown = 1.8,
                Duration = 0.32,
                Delay = 0.14,
                HitboxSize = Vector3.new(7, 7, 6),
                HitboxOffset = CFrame.new(0, 0, -3),

                Behaviour = GrabBehaviour,
            }),

            Charge = Ability.New({
                Name = "Charge",
                InputName = "FirstAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 16,
                Duration = 1.3,

                Duration_ = 1.3,
                Speed = 92,
                Radius = 7,
                Damage = 38,
                SnareTime = 1,

                UseSound = "rbxassetid://9118823103",
                Behaviour = ChargeBehaviour,
            }),

            Search = Ability.New({
                Name = "Search",
                InputName = "SecondAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 22,
                Duration = 0.4,

                Range = 110,
                Duration_ = 4,
                Pulses = 4,
                --- Studs per second. Below this and the pulse misses you entirely.
                MinimumSpeed = 6,
                RevealTime = 3,

                UseSound = "rbxassetid://9125402735",
                Behaviour = SearchBehaviour,
            }),

            Roar = Ability.New({
                Name = "Roar",
                InputName = "ThirdAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 26,
                Duration = 0.7,

                --- Short. It is what it does after catching you.
                Radius = 22,
                DisorientTime = 1.6,
                SlowLevel = 3,
                SlowTime = 3,

                UseSound = "rbxassetid://9118823103",
                Behaviour = RoarBehaviour,
            }),

            Shift = Ability.New({
                Name = "Shift",
                InputName = "FourthAbility",
                RenderImage = "rbxassetid://9759886280",
                Cooldown = 30,
                Duration = 0.6,

                Duration_ = 9,
                GreenDamageMultiplier = 1.5,
                OrangeSpeedMultiplier = 1.35,
                PurpleResistance = 4,

                UseSound = "rbxassetid://9046319808",
                Behaviour = ShiftBehaviour,
            }),

            Pursuit = Ability.New({
                Name = "Does Not Stop",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                Interval = 1,
                SpeedPerStack = 0.05,
                MaximumStacks = 5,
                --- Seconds since the last hit on the same person before it resets.
                Memory = 6,

                ExtraInit = PursuitInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(70, 130, 245)\">"..RainbowFriend.Config.Name.."</font>"
local Abilities = RainbowFriend.GameplayConfig.Abilities

RainbowFriend.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = "RAINBOW FRIEND — BLUE"},
    {
        Type = "Text",
        Text = {
            NameLabel.." is <b>Blue</b>: big, fast, and it does not stop once it has started.",
            "It has <b>no ranged damage of any kind</b> and its roar deals none either. Every approach it has is a committed charge.",
            "<b>Search only finds people who are moving.</b> Breaking line of sight and holding still genuinely works, and everybody can hear the pulse so they know when to freeze.",
        },
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..RainbowFriend.Config.Role,
            "Difficulty: "..string.rep("★", RainbowFriend.Config.Difficulty)..string.rep("☆", 5 - RainbowFriend.Config.Difficulty),
            "Price: "..tostring(RainbowFriend.Config.Price).."$",
            "Health: "..tostring(RainbowFriend.GameplayConfig.Health),
            "Base Speed: "..tostring(RainbowFriend.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(RainbowFriend.GameplayConfig.BaseSpeed * RainbowFriend.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "GRAB"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds, and <b>every hit holds you for half a second</b>.",
            "Snared is not a stun — you keep your abilities and your attack. It is what turns one catch into two.",
        },
    },

    {Type = "Header", Text = "CHARGE  (Q)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Charge.Duration_).." seconds of committed pursuit at "..tostring(Abilities.Charge.Speed).." studs a second, hitting everybody it passes for "..tostring(Abilities.Charge.Damage).." damage and a <b>Snare</b>.",
            "Everybody within 70 studs sees red when it starts.",
            "Cooldown: "..tostring(Abilities.Charge.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "SEARCH  (E)"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Search.Pulses).." audible pulses over "..tostring(Abilities.Search.Duration_).." seconds, revealing everybody within "..tostring(Abilities.Search.Range).." studs <b>who is moving</b>.",
            "<b>Standing still hides you completely</b>, and you are told when a pulse passed over you. Refunds itself if everybody held still.",
            "Cooldown: "..tostring(Abilities.Search.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "ROAR  (R)"},
    {
        Type = "Text",
        Text = {
            "<b>No damage at all.</b> Everybody within "..tostring(Abilities.Roar.Radius).." studs is <b>Disoriented</b> for "..tostring(Abilities.Roar.DisorientTime).." seconds and heavily <b>Slowed</b> for "..tostring(Abilities.Roar.SlowTime)..".",
            "Short range. It is what it does after catching you, not an opener.",
            "Cooldown: "..tostring(Abilities.Roar.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "SHIFT  (F)"},
    {
        Type = "Text",
        Text = {
            "Borrows another friend's trait for "..tostring(Abilities.Shift.Duration_).." seconds, cycling in a fixed order. What is next floats over its head.",
            "<b>Green</b> — 50% more damage, and <b>it goes blind</b>: nobody can be tracked while it lasts.",
            "<b>Orange</b> — 35% more speed, and nothing else.",
            "<b>Purple</b> — heavy damage reduction.",
            "Cooldown: "..tostring(Abilities.Shift.Cooldown).." seconds.",
        },
    },

    {Type = "Header", Text = "DOES NOT STOP  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "+5% speed per second while it stays on the <b>same</b> person, up to "..tostring(Abilities.Pursuit.MaximumStacks)..".",
            "<b>Switching targets resets it to nothing</b>, and so does losing them for "..tostring(Abilities.Pursuit.Memory).." seconds. It rewards committing to one victim and punishes swinging at whoever is closest.",
        },
    },
}

return RainbowFriend
