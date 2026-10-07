local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local AbilityClient = require(ReplicatedStorage.Modules.AbilityClient)
local AbilityFX = require(ReplicatedStorage.Modules.AbilityFX)
local CombatUtils = require(ReplicatedStorage.Modules.CombatUtils)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

--[=[
    RAVEL — an original killer. Nothing it does is immediate.

    Design idea: a killer with no burst at all, whose entire damage output is deferred
    into threads it attached several seconds earlier.

    Tether attaches a line to somebody. The line does nothing on its own except stop
    them leaving — walk past its length and it hauls you back. Draw pulls every tethered
    fighter toward Ravel at once. Sever cuts every line for damage that scales with how
    long each one had been attached.

    The result is a killer you have to disengage from *early*, because by the time it
    hurts, it's already too late to run.
]=]

--- Where the live tethers are stashed on the character module's cache.
local function GetTethers(self: Types.Ability): {any}
    local Cache = self.CharModule.GameplayConfig.Cache
    Cache.RavelTethers = Cache.RavelTethers or {}
    return Cache.RavelTethers
end

--- Drops dead, expired or out-of-range tethers from the list.
local function PruneTethers(tethers: {any})
    for index = #tethers, 1, -1 do
        local Tether = tethers[index]
        local Char = Tether.Character

        local Alive = Char
            and Char.Parent
            and Char:GetAttribute("Dead") ~= true
            and Char:FindFirstChildWhichIsA("Humanoid")
            and Char:FindFirstChildWhichIsA("Humanoid").Health > 0

        if not Alive or time() >= Tether.ExpiresAt then
            if Tether.Beam and Tether.Beam.Parent then
                Tether.Beam:Destroy()
            end
            if Tether.Connection then
                Tether.Connection:Disconnect()
            end
            table.remove(tethers, index)
        end
    end
end

--------------------------------------------------------------------------------
-- ABILITY BEHAVIOURS
--------------------------------------------------------------------------------

--[=[
    TETHER (Q)

    Attaches a thread to the closest fighter in front of Ravel.

    The thread deals no damage. It has a maximum length, and crossing that length hauls
    the target back toward Ravel. That's the whole mechanic — it doesn't kill you, it
    just refuses to let you leave.
]=]
--- The thread's colour. One colour for everything this character does.
local THREAD = Color3.fromRGB(190, 170, 220)

--[=[
    FRAY (M1)

    Its own basic attack, rather than the shared default.

    The damage scales with HOW MANY THREADS ARE OUT -- a flat base plus a bonus per live
    tether. With nothing attached it is the weakest swing on the roster; with four threads
    running it is among the strongest.

    That is the character's thesis written into the one thing it does constantly. Before
    this pass its M1 was the engine default, so the swing had no relationship to the kit at
    all -- and the whole point of Ravel is that everything it does is worth more the longer
    it has been working on you.
]=]
local function FrayBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        AbilityClient.Cast(self, {Scale = 1.03, Duration = 0.3, Lock = 0.6})
        return
    end

    local Root = self.OwnerProperties.HRP
    local Tethers = GetTethers(self)
    PruneTethers(Tethers)

    local Damage = self.Damage + self.DamagePerThread * #Tethers

    Sounds.PlaySound(self.UseSound, {Parent = Root, Volume = 0.6, MinPitch = 0.9, MaxPitch = 1.05})

    task.delay(self.Delay, function()
        if not Root or not Root.Parent then
            return
        end

        -- Threads lashing out ahead of it, one per live tether, so the bonus is visible.
        local Centre = Root.Position + Root.CFrame.LookVector * 3 + Vector3.new(0, 1, 0)
        for Index = 0, #Tethers do
            local Offset = (Index - #Tethers * 0.5) * 1.2
            AbilityFX.Beam(
                Root.Position + Vector3.new(0, 1.5, 0),
                Centre + Root.CFrame.RightVector * Offset,
                THREAD,
                {Width = 0.4, Duration = 0.2, Transparency = 0.25}
            )
        end

        Hitbox.New(self.Owner, {
            CFrameOffset = self.HitboxOffset,
            Size = self.HitboxSize,
            Time = self.Duration,
            Damage = Damage,
            Reason = #Tethers > 0 and "Fray" or "Fray (no threads)",
            ExecuteOnKill = true,
            Connections = {
                Hit = function(_config, humanoid: Humanoid)
                    local Victim = humanoid.Parent
                    local VictimRoot = Victim and Utils.Character.GetRootPart(Victim)
                    if VictimRoot then
                        AbilityFX.Sparks(VictimRoot.Position, THREAD, 7, 13)
                    end
                end,
            },
        })
    end)
end

--[=[
    UNPICKING (PASSIVE)

    Information, and a visible clock.

    Every tethered fighter is revealed to Ravel continuously -- which `Draw` and `Sever`
    already needed to be usable at range, and which was previously only true by accident
    because the tether's beam happens to be visible.

    More importantly, the thread BRIGHTENS as it ages. `Sever`'s damage scales with
    attachment time, so the age of a thread is the single most important number in the
    fight, and both players can now read it off the beam: a faint thread is nearly harmless
    and a bright one is about to hurt a great deal.

    That makes the counterplay legible. The answer to Ravel is to disengage EARLY, and you
    can only act on that if you can see how late it already is.
]=]
local function UnpickingInit(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    if not Char then
        return
    end

    local Abilities = self.CharModule.GameplayConfig.Abilities
    local Tether = Abilities.Tether

    --[[
        Read from `Sever` rather than duplicated as its own number.

        `Sever`'s damage stops growing at `MaxChargeTime`, so that is exactly where the beam
        should stop brightening. Copying the value would mean retuning one of them silently
        makes the other lie.
    ]]
    local Ceiling = (Abilities.Sever and Abilities.Sever.MaxChargeTime) or 14

    self:AddConnection(task.spawn(function()
        while Char and Char.Parent do
            task.wait(0.4)

            local Tethers = GetTethers(Tether)
            PruneTethers(Tethers)

            for _, Entry in Tethers do
                if not Entry.Character or not Entry.Character.Parent then
                    continue
                end

                Utils.Player.RevealPlayerAuraTo(self.Owner, Entry.Character, 1, THREAD)

                --[[
                    The age, written onto the beam.

                    `Sever` clamps its charge at `MaxChargeTime`, and the brightness is read
                    from that same field -- a thread that has stopped getting more dangerous also
                    stops getting brighter, which keeps the visual honest rather than just
                    dramatic.
                ]]
                if Entry.Beam and Entry.Beam.Parent then
                    local Age = math.clamp(time() - Entry.AttachedAt, 0, Ceiling)
                    local Alpha = Age / Ceiling

                    Entry.Beam.Transparency = 0.65 - 0.5 * Alpha
                    Entry.Beam.Color = THREAD:Lerp(Color3.fromRGB(255, 80, 120), Alpha)
                end
            end
        end
    end))
end

local function TetherBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Tethers = GetTethers(self)
    PruneTethers(Tethers)

    if #Tethers >= self.MaxTethers then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    -- Closest fighter roughly in front, within reach.
    local Target
    for _, Candidate: Model in CombatUtils.GetFightersInRadius(Root.Position, self.Range, Char) do
        -- Already tethered? Skip — one thread each.
        local Existing = false
        for _, Tether in Tethers do
            if Tether.Character == Candidate then
                Existing = true
                break
            end
        end
        if Existing then
            continue
        end

        local CandidateRoot = Utils.Character.GetRootPart(Candidate)
        if not CandidateRoot then
            continue
        end

        -- Has to be broadly ahead of Ravel, not behind it.
        if Root.CFrame.LookVector:Dot((CandidateRoot.Position - Root.Position).Unit) < 0.2 then
            continue
        end

        Target = Candidate
        break
    end

    if not Target then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    Sounds.PlaySound(self.UseSound, {Parent = Root, Volume = 0.75})

    -- The visible thread.
    local Beam = CombatUtils.MakePart({
        Name = "RavelThread",
        Size = Vector3.new(0.15, 0.15, 1),
        Color = Color3.fromRGB(220, 60, 90),
        Material = Enum.Material.Neon,
        Transparency = 0.2,
    })
    Beam.Parent = CombatUtils.GetInGameFolder()

    local Tether = {
        Character = Target,
        Beam = Beam,
        AttachedAt = time(),
        ExpiresAt = time() + self.TetherDuration,
        Connection = nil,
    }

    -- Redraw the thread and enforce its length every frame.
    Tether.Connection = RunService.PostSimulation:Connect(function()
        local CurrentRoot = Utils.Character.GetRootPart(Char)
        local CurrentTargetRoot = Target and Target.Parent and Utils.Character.GetRootPart(Target)

        if not (Beam.Parent and CurrentRoot and CurrentTargetRoot) then
            if Tether.Connection then
                Tether.Connection:Disconnect()
            end
            if Beam.Parent then
                Beam:Destroy()
            end
            return
        end

        local Offset = CurrentTargetRoot.Position - CurrentRoot.Position
        local Distance = Offset.Magnitude

        -- Stretch the beam between the two of them.
        Beam.Size = Vector3.new(0.15, 0.15, math.max(Distance, 0.1))
        Beam.CFrame = CFrame.lookAt(CurrentRoot.Position + Offset / 2, CurrentTargetRoot.Position)

        -- Past the leash length, drag them back. Not a teleport — a pull, so they can
        -- still fight it by running at an angle.
        if Distance > self.MaxLength then
            local Pull = -Offset.Unit * self.PullStrength
            CurrentTargetRoot.AssemblyLinearVelocity = Vector3.new(
                Pull.X,
                CurrentTargetRoot.AssemblyLinearVelocity.Y,
                Pull.Z
            )

            -- Redden as it strains, so the target can see they're at the limit.
            Beam.Color = Color3.fromRGB(255, 30, 30)
        else
            Beam.Color = Color3.fromRGB(220, 60, 90)
        end
    end)

    table.insert(Tethers, Tether)

    -- Self-cleanup when the thread times out.
    self:AddConnection(task.delay(self.TetherDuration, function()
        PruneTethers(Tethers)
    end))
end

--[=[
    DRAW (E)

    Reels every tethered fighter toward Ravel at once and Snares them on arrival.

    No damage. It is purely a repositioning tool — its job is to gather everybody into
    one place so that Sever, or a Nuker standing nearby, can do something about it.
]=]
local function DrawBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local Char = self.OwnerProperties.Character
    local Root = self.OwnerProperties.HRP

    local Tethers = GetTethers(self)
    PruneTethers(Tethers)

    if #Tethers <= 0 then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    Sounds.PlaySound(self.UseSound, {Parent = Root, Volume = 0.9})

    for _, Tether in Tethers do
        local TargetRoot = Utils.Character.GetRootPart(Tether.Character)
        if not TargetRoot then
            continue
        end

        local Direction = (Root.Position - TargetRoot.Position)
        if Direction.Magnitude <= 0 then
            continue
        end

        CommonFunctions.RigImpulse(TargetRoot, self.PullMagnitude, Direction.Unit, false)
        CombatUtils.ApplyEffectTo(Tether.Character, "Snared", 3, self.SnareDuration)
    end

    Utils.Player.ShakeCameraOf(Utils.Player.GetLoadedPlayers(false), 0.4, 0.3)
end

--[=[
    SEVER (R)

    Cuts every thread. Each one deals damage based on how long it had been attached,
    capped at `MaxChargeTime` seconds' worth.

    This is where all of Ravel's damage lives. A thread cut immediately is nearly
    worthless; one that's been on for its full duration is the hardest single hit any
    killer lands outside of Ground Zero.
]=]
local function SeverBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        self.OwnerProperties.FOVManager:AddFOVFactor(self.Name, 0.92)
        self:AddConnection(task.delay(0.8, function()
            self.OwnerProperties.FOVManager:RemoveFOVFactor(self.Name)
        end))
        return
    end

    local Tethers = GetTethers(self)
    PruneTethers(Tethers)

    if #Tethers <= 0 then
        self.CooldownTimer = 0
        self.OnCooldown = false
        return
    end

    Sounds.PlaySound(self.UseSound, {Parent = self.OwnerProperties.HRP, Volume = 1})

    for index = #Tethers, 1, -1 do
        local Tether = Tethers[index]
        local Humanoid = Tether.Character and Tether.Character:FindFirstChildWhichIsA("Humanoid")

        if Humanoid and Humanoid.Health > 0 then
            -- Damage grows with attachment time, capped so waiting forever isn't optimal.
            local Charged = math.clamp(time() - Tether.AttachedAt, 0, self.MaxChargeTime)
            local Damage = self.BaseDamage + self.DamagePerSecond * Charged

            CommonFunctions.DamagePlayer({
                SourcePlayer = self.Owner,
                TargetHumanoid = Humanoid,
                Damage = Damage,
                Reason = "Sever",
            })

            CombatUtils.ApplyEffectTo(Tether.Character, "Fragile", 2, 6)

            local TargetRoot = Utils.Character.GetRootPart(Tether.Character)
            if TargetRoot then
                local Cut = CombatUtils.MakePart({
                    Name = "SeverVFX",
                    Shape = Enum.PartType.Ball,
                    Size = Vector3.one * 6,
                    Color = Color3.fromRGB(255, 40, 70),
                    Material = Enum.Material.Neon,
                    Transparency = 0.4,
                    CFrame = TargetRoot.CFrame,
                })
                Cut.Parent = CombatUtils.GetInGameFolder()
                Debris:AddItem(Cut, 0.4)
            end
        end

        -- Tear the thread down whether or not it connected.
        if Tether.Beam and Tether.Beam.Parent then
            Tether.Beam:Destroy()
        end
        if Tether.Connection then
            Tether.Connection:Disconnect()
        end
        table.remove(Tethers, index)
    end
end

--------------------------------------------------------------------------------
-- CHARACTER DEFINITION
--------------------------------------------------------------------------------

local Ravel: Types.Killer = Character.CreateKiller({
    Config = {
        Name = "Ravel",
        Quote = "You've been attached to me for a while now.",

        Role = "Controller",
        Difficulty = 5,
        Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        Price = 2100,

        Origin = {
            TooltipText = "It has been unpicking something for a very long time.",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },
    },

    GameplayConfig = {
        Health = 1100,
        BaseSpeed = 10.4,
        SprintSpeedMultiplier = 25 / 10.4,
        HitboxPriority = 1,

        StaminaProperties = {
            MaxStamina = 108,
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

                --- With nothing tethered, the weakest swing on the roster.
                Damage = 14,
                --- Added per live thread. Four threads nearly triples it.
                DamagePerThread = 9,
                Cooldown = 2,
                Duration = 0.35,
                Delay = 0.12,
                HitboxSize = Vector3.new(5, 6, 5),
                HitboxOffset = CFrame.new(0, 0, -2.6),

                Behaviour = FrayBehaviour,
            }),

            Tether = Ability.New({
                Name = "Tether",
                InputName = "FirstAbility",
                Cooldown = 8,
                Duration = 0.6,

                Range = 40,
                MaxTethers = 4,
                TetherDuration = 20,
                --- Studs the thread can stretch before it starts hauling.
                MaxLength = 45,
                PullStrength = 48,

                UseSound = "rbxassetid://9046319808",
                DisableSlashOnPerform = false,

                Behaviour = TetherBehaviour,
            }),

            Draw = Ability.New({
                Name = "Draw",
                InputName = "SecondAbility",
                Cooldown = 22,
                Duration = 0.8,

                PullMagnitude = 12,
                SnareDuration = 1.8,

                UseSound = "rbxassetid://9118823103",
                Behaviour = DrawBehaviour,
            }),

            Sever = Ability.New({
                Name = "Sever",
                InputName = "ThirdAbility",
                Cooldown = 34,
                Duration = 0.9,

                BaseDamage = 8,
                DamagePerSecond = 4.5,
                --- Attachment time past this stops adding damage.
                MaxChargeTime = 14,

                UseSound = "rbxassetid://9125402735",
                Behaviour = SeverBehaviour,
            }),

            Unpicking = Ability.New({
                Name = "Unpicking",
                Passive = true,
                RenderImage = "rbxassetid://9759886280",

                ExtraInit = UnpickingInit,
            }),
        },
    },
})

--------------------------------------------------------------------------------
-- MORE INFO PAGE
--------------------------------------------------------------------------------

local NameLabel = "<font color=\"rgb(232, 84, 116)\">"..Ravel.Config.Name.."</font>"
local Abilities = Ravel.GameplayConfig.Abilities

local MinSever = Abilities.Sever.BaseDamage
local MaxSever = math.round(Abilities.Sever.BaseDamage + Abilities.Sever.DamagePerSecond * Abilities.Sever.MaxChargeTime)
local MaxTotalSever = MaxSever * Abilities.Tether.MaxTethers

Ravel.Config.Description = {
    {Type = "Separator", Text = "GENERAL INFO"},
    {Type = "Header", Text = Ravel.Config.Name:upper()},
    {Type = "Quote", Text = "\""..Ravel.Config.Quote.."\""},
    {
        Type = "Text",
        Text = NameLabel.." has the weakest attack in the arena and the highest ceiling in it. "..
            "It does no burst damage whatsoever — everything it will ever do to you was decided "..
            "the moment it put a thread on you, several seconds ago, while you were busy with somebody else. "..
            "By the time it hurts, cutting the line is no longer an option you have.",
    },
    {Type = "Header", Text = "STATS"},
    {
        Type = "Text",
        Text = {
            "Role: "..Ravel.Config.Role,
            "Difficulty: "..string.rep("★", Ravel.Config.Difficulty)..string.rep("☆", 5 - Ravel.Config.Difficulty),
            "Health: "..tostring(Ravel.GameplayConfig.Health),
            "Base Speed: "..tostring(Ravel.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Ravel.GameplayConfig.BaseSpeed * Ravel.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
            "Max Stamina: "..tostring(Ravel.GameplayConfig.StaminaProperties.MaxStamina),
            "Stamina Loss per second: "..tostring(Ravel.GameplayConfig.StaminaProperties.StaminaDrain),
            "Stamina Gain per second: "..tostring(Ravel.GameplayConfig.StaminaProperties.StaminaGain),
        },
    },
    {Type = "Separator", Text = "ABILITIES"},

    {Type = "Header", Text = "FRAY"},
    {
        Type = "Text",
        Text = {
            tostring(Abilities.Slash.Damage).." damage with nothing attached — the weakest swing on the roster — plus <b>"..tostring(Abilities.Slash.DamagePerThread).." for every live thread</b>.",
            "With a full set out it is "..tostring(Abilities.Slash.Damage + Abilities.Slash.DamagePerThread * Abilities.Tether.MaxTethers).." damage every "..tostring(Abilities.Slash.Cooldown).." seconds.",
            "Everything it does is worth more the longer it has been working on you, and that now includes the thing it does constantly.",
        },
    },

    {Type = "Header", Text = Abilities.Tether.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Attaches a thread to a fighter within "..tostring(Abilities.Tether.Range).." studs in front of "..NameLabel..".",
            "The thread deals <b>no damage</b> and lasts "..tostring(Abilities.Tether.TetherDuration).." seconds.",
            "Move more than "..tostring(Abilities.Tether.MaxLength).." studs away and it hauls you back. The thread turns red when it's straining.",
            "Up to "..tostring(Abilities.Tether.MaxTethers).." threads can be out at once. One per fighter.",
        },
    },

    {Type = "Header", Text = Abilities.Draw.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Reels every tethered fighter toward "..NameLabel.." and <b>Snares</b> them for "..tostring(Abilities.Draw.SnareDuration).." seconds.",
            "Deals no damage. It exists to put everybody in the same place at the same time.",
        },
    },

    {Type = "Header", Text = Abilities.Sever.Name:upper()},
    {
        Type = "Text",
        Text = {
            "Cuts every thread at once. Each one deals damage based on <b>how long it had been attached</b>.",
            "Cut instantly: "..tostring(MinSever).." damage. Cut at "..tostring(Abilities.Sever.MaxChargeTime).." seconds or later: "..tostring(MaxSever).." damage.",
            "Against a full set of "..tostring(Abilities.Tether.MaxTethers).." mature threads that's "..tostring(MaxTotalSever).." damage spread across the arena in one press.",
            "Everyone cut is left <b>Fragile II</b>.",
            "All threads are consumed.",
        },
    },

    {Type = "Header", Text = "UNPICKING  (PASSIVE)"},
    {
        Type = "Text",
        Text = {
            "Everybody tethered is revealed to "..NameLabel.." for as long as the thread lasts.",
            "<b>The thread brightens as it ages</b>, from faint to red, and it stops brightening at exactly the point <b>Sever</b> stops getting stronger.",
            "So the most important number in the fight is written on the beam, for both of you. The answer to Ravel is to disengage early — and you can only act on that if you can see how late it already is.",
        },
    },
}

return Ravel
